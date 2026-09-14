# =============================================================================
# 86_deepcore_p1_check.jl — diagnostic of the p₁ hole-ice slip in the DeepCore
# module of Newtrinos.jl (report: docs/REPORT-newtrinos-deepcore-p1.md).
# =============================================================================
#
#   julia --project=. scripts/86_deepcore_p1_check.jl
#
# THIS SCRIPT CHANGES NOTHING FOR ANY RESULT OF THE REPOSITORY. Every run uses
# Newtrinos.jl exactly as pinned in Manifest.toml (commit fa87689d). The script
# only quantifies, in one throw-away session, what the slip does: it builds the
# four-experiment posterior (Daya Bay + KamLAND + MINOS + DeepCore, d = 24,
# normal ordering), evaluates the counted log-density at the Newtrinos nominal
# parameters with p₁ᴰᶜ (and, for scale, p₀ᴰᶜ) scanned over its prior support,
# then evaluates a corrected copy of `get_hypersurface_factor` (p₁ offset times
# the `hole_ice_p1` slope table, which the release files do contain) into the
# session and repeats. It prints both profiles, the finite-difference slopes at
# the nominal point, and the difference of the two versions at the nominal
# point (0 by construction: the p₁ term vanishes there in both), and writes
# out_extension/tables/deepcore_p1_check.csv.
#
# The slip (deepcore.jl, function get_hypersurface_factor, line 248):
#   (interpolate_hypersurface(hypersurface.hole_ice_p0, idx, fraction) * (params.deepcore_rel_eff_p1 + 0.05))
# intended (the line above it uses hole_ice_p0 for p₀ correctly):
#   (interpolate_hypersurface(hypersurface.hole_ice_p1, idx, fraction) * (params.deepcore_rel_eff_p1 + 0.05))
# Consequence as published: p₀ and p₁ enter the likelihood only through
# (p₀ − 0.1) + (p₁ + 0.05), i.e. the data constrain their sum and the marginal
# posterior of p₁ᴰᶜ is essentially its prior.
import Pkg
Pkg.activate(joinpath(@__DIR__, ".."))
using Printf, DataFrames, CSV
include(joinpath(@__DIR__, "..", "harness", "experiments", "src", "ExperimentsBase.jl"))
using .ExperimentsBase
include(joinpath(@__DIR__, "..", "src", "neutrino_problem.jl"))

const EXPS = ["dayabay", "kamland", "minos", "deepcore"]
const FAULTY_LINE = "(interpolate_hypersurface(hypersurface.hole_ice_p0, idx, fraction) * (params.deepcore_rel_eff_p1 + 0.05))"
deepcore_src = joinpath(pkgdir(Newtrinos), "src", "experiments", "icecube", "deepcore_9y_verification_sample", "deepcore.jl")
occursin(FAULTY_LINE, read(deepcore_src, String)) ||
    (println("the installed deepcore.jl does not contain the p0-for-p1 line any more; nothing to check"); exit(0))

cfg = make_config_neutrino(experiments = EXPS, ordering = :NO)
println("d = ", cfg.d, "  parameters: ", join(String.(cfg.names), " "))

# nominal point (Newtrinos defaults) in cube coordinates
physics = neutrino_physics(:NO; matter = true)
exps = neutrino_experiments(EXPS, physics)
nominal = Newtrinos.get_params(exps)
θ0 = [Float64(getproperty(nominal, k)) for k in cfg.names]
u0 = from_physical(cfg, θ0)
k0 = findfirst(==(:deepcore_rel_eff_p0), cfg.names)
k1 = findfirst(==(:deepcore_rel_eff_p1), cfg.names)
@printf("nominal p0 = %.3f (prior [%.2f, %.2f]),  p1 = %.3f (prior [%.2f, %.2f])\n",
        θ0[k0], cfg.lo[k0], cfg.hi[k0], θ0[k1], cfg.lo[k1], cfg.hi[k1])

function profile(log_f, k, values)
    out = Float64[]
    for v in values
        θ = copy(θ0); θ[k] = v
        push!(out, log_f(from_physical(cfg, θ)))
    end
    out
end
function slope(log_f, k; h = 1e-3)
    θp = copy(θ0); θp[k] += h; θm = copy(θ0); θm[k] -= h
    (log_f(from_physical(cfg, θp)) - log_f(from_physical(cfg, θm))) / 2h
end
p1_grid = range(cfg.lo[k1], cfg.hi[k1]; length = 9)
p0_grid = range(cfg.lo[k0], cfg.hi[k0]; length = 9)

println("\n--- as published (p1 term uses the p0 slope table) ---")
log_f_pub = build_log_f(cfg)
t = @elapsed ll0_pub = log_f_pub(u0)
@printf("log f(nominal) = %.4f   (%.2f s first call incl. compilation)\n", ll0_pub, t)
prof1_pub = profile(log_f_pub, k1, p1_grid); prof0_pub = profile(log_f_pub, k0, p0_grid)
slope1_pub = slope(log_f_pub, k1); slope0_pub = slope(log_f_pub, k0)

println("\n--- corrected copy in this session only (p1 term uses the p1 slope table) ---")
Core.eval(Newtrinos.deepcore, quote
    function get_hypersurface_factor(hypersurface, idx, fraction, params)
        f = (
            interpolate_hypersurface(hypersurface.intercept, idx, fraction) .+
            (interpolate_hypersurface(hypersurface.bulk_ice_abs, idx, fraction) * (params.deepcore_ice_absorption - 1)) .+
            (interpolate_hypersurface(hypersurface.bulk_ice_scatter, idx, fraction) * (params.deepcore_ice_scattering - 1)) .+
            (interpolate_hypersurface(hypersurface.dom_eff, idx, fraction) .* (params.deepcore_opt_eff_overall - 1)) .+
            (interpolate_hypersurface(hypersurface.hole_ice_p0, idx, fraction) * (params.deepcore_rel_eff_p0 - 0.1)) .+
            (interpolate_hypersurface(hypersurface.hole_ice_p1, idx, fraction) * (params.deepcore_rel_eff_p1 + 0.05))
        )
        f
    end
end)
log_f_fix = build_log_f(cfg)
ll0_fix = log_f_fix(u0)
@printf("log f(nominal) = %.4f   difference to published: %.3e (expected 0)\n", ll0_fix, ll0_fix - ll0_pub)
prof1_fix = profile(log_f_fix, k1, p1_grid); prof0_fix = profile(log_f_fix, k0, p0_grid)
slope1_fix = slope(log_f_fix, k1); slope0_fix = slope(log_f_fix, k0)

println("\nΔ log f relative to the nominal point (others fixed at nominal):")
println("   p1        published   corrected   |   p0        published   corrected")
for i in eachindex(p1_grid)
    @printf("  %6.3f  %11.3f  %11.3f   |  %6.3f  %11.3f  %11.3f\n",
            p1_grid[i], prof1_pub[i] - ll0_pub, prof1_fix[i] - ll0_fix,
            p0_grid[i], prof0_pub[i] - ll0_pub, prof0_fix[i] - ll0_fix)
end
@printf("\n∂ log f / ∂p1 at nominal: published %.2f, corrected %.2f   (p0: %.2f / %.2f, unchanged by construction)\n",
        slope1_pub, slope1_fix, slope0_pub, slope0_fix)
@printf("as published ∂/∂p1 == ∂/∂p0 to %.1e: p0 and p1 enter only through their sum\n", abs(slope1_pub - slope0_pub))

mkpath(joinpath(@__DIR__, "..", "out_extension", "tables"))
CSV.write(joinpath(@__DIR__, "..", "out_extension", "tables", "deepcore_p1_check.csv"),
          DataFrame(p1 = collect(p1_grid), dlogf_p1_published = prof1_pub .- ll0_pub, dlogf_p1_corrected = prof1_fix .- ll0_fix,
                    p0 = collect(p0_grid), dlogf_p0_published = prof0_pub .- ll0_pub, dlogf_p0_corrected = prof0_fix .- ll0_fix))
println("DEEPCORE-P1-CHECK-DONE")

# =============================================================================
# 50_profile.jl — frequentist cross-check: profile log-likelihood scans with
# Newtrinos' own `profile` (LBFGS via bat_findmode at every grid point), for
# θ₂₃ and Δm²₃₁, both orderings. Compared with the marginal posteriors in the
# chapter (Bayesian marginal vs profile).
# =============================================================================
#
#   julia --project=. -t 2 scripts/50_profile.jl [--n 31]
#
# Writes <out>/tables/profile_<ORD>_<var>.csv with columns value, llh,
# log_posterior, dchi2 (= 2·(max llh − llh)).
import Pkg
Pkg.activate(joinpath(@__DIR__, ".."))
using Printf, Statistics, DataFrames, CSV
# Thesis benchmark harness (module ExperimentsBase) and the thesis-final
# MoleWhacker; verbatim copies live in ../harness (see harness/PROVENANCE.md).
const HARNESS = joinpath(@__DIR__, "..", "harness", "experiments", "src", "ExperimentsBase.jl")
include(HARNESS)
using .ExperimentsBase
include(joinpath(@__DIR__, "..", "src", "neutrino_problem.jl"))

const OUT = joinpath(@__DIR__, "..", "out")
const TABLES = joinpath(OUT, "tables"); mkpath(TABLES)
const NPTS = let i = findfirst(==("--n"), ARGS); i === nothing ? 31 : parse(Int, ARGS[i+1]) end

function run_profiles(ordering::Symbol)
    physics = neutrino_physics(ordering)
    exps = neutrino_experiments(NEUTRINO_DEFAULT_EXPERIMENTS, physics)
    likelihood = Newtrinos.generate_likelihood(exps)
    priors = Newtrinos.get_priors(exps)
    params = Newtrinos.get_params(exps)
    for var in (:θ₂₃, :Δm²₃₁)
        t0 = time()
        # Newtrinos.profile == generate_scanpoints + _profile + add_meta!; the last
        # step opens the package directory as a git repository and fails for a
        # registry-style install, so the two working steps are called directly.
        values, scanpoints = Newtrinos.generate_scanpoints(Dict(var => NPTS), priors)
        prof = Newtrinos._profile(likelihood, scanpoints, params, nothing)
        vals = Float64.(collect(values[1]))
        llh = Float64.(collect(prof.llh))
        lp = Float64.(collect(prof.log_posterior))
        df = DataFrame(value = vals, llh = llh, log_posterior = lp,
                       dchi2 = 2 .* (maximum(filter(isfinite, llh)) .- llh),
                       dchi2_post = 2 .* (maximum(filter(isfinite, lp)) .- lp))
        # the profiled values of the other parameters at each grid point
        for k in keys(prof)
            k in (:llh, :log_posterior, var) && continue
            v = prof[k]
            eltype(v) <: Real || continue
            df[!, Symbol("prof_", ascii_name(k))] = Float64.(collect(v))
        end
        path = joinpath(TABLES, "profile_$(ordering)_$(ascii_name(var)).csv")
        CSV.write(path, df)
        @info "profile done" ordering var n = NPTS seconds = round(time() - t0; digits = 1) path
        println(df[:, [:value, :llh, :dchi2]])
    end
end

const _ASCII = Dict(:θ₁₂ => "th12", :θ₁₃ => "th13", :θ₂₃ => "th23", :δCP => "dcp", :Δm²₂₁ => "dm21", :Δm²₃₁ => "dm31")
ascii_name(k::Symbol) = get(_ASCII, k, String(k))

for ord in (:NO, :IO)
    run_profiles(ord)
end
println("PROFILE-DONE")

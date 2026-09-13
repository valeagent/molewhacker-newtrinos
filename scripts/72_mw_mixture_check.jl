# =============================================================================
# 72_mw_mixture_check.jl — where does MoleWhacker's evidence offset come from?
#
# For each MoleWhacker cell at the top budget the final Gaussian mixture q_T
# (stored in result.h5, extras[:mixture], in BAT's PriorToNormal space) is
# reloaded and two evidence estimates are formed:
#   (1) "pooled cloud": the algorithm's own estimator — the stored sample cloud,
#       whose members were drawn from the mixture *as it was when each component
#       was added*, weighted with the final mixture density (stored logZ and
#       stored weights are used as they are);
#   (2) "fresh draws": N new i.i.d. draws from q_T weighted with q_T — a plain,
#       unbiased importance-sampling estimate with the same proposal.
# If (2) agrees with the independent reference (70_evidence_check.jl) while (1)
# does not, the offset is a property of the pooled-cloud bookkeeping, not of the
# mixture. Also reports the upper-octant probability from both weightings.
#
#   julia --project=. -t 8 scripts/72_mw_mixture_check.jl [--N 100000]
# Output: out/tables/mw_mixture_check.csv
# =============================================================================
import Pkg
Pkg.activate(joinpath(@__DIR__, ".."))
using LinearAlgebra, Statistics, Random, Printf, CSV, DataFrames, Distributions, PDMats
using Base.Threads
using BAT: bat_transform, PriorToNormal
using DensityInterface: logdensityof
# Thesis benchmark harness (module ExperimentsBase) and the thesis-final
# MoleWhacker; verbatim copies live in ../harness (see harness/PROVENANCE.md).
const HARNESS = joinpath(@__DIR__, "..", "harness", "experiments", "src", "ExperimentsBase.jl")
include(HARNESS)
using .ExperimentsBase
include(joinpath(@__DIR__, "..", "src", "neutrino_problem.jl"))

const OUT = joinpath(@__DIR__, "..", "out")
const RUNS = joinpath(OUT, "runs")
const TABLES = joinpath(OUT, "tables"); mkpath(TABLES)
const NFRESH = let i = findfirst(==("--N"), ARGS); i === nothing ? 100_000 : parse(Int, ARGS[i+1]) end

logsumexp(v) = (m = maximum(v); isfinite(m) ? m + log(sum(exp.(v .- m))) : m)

function is_summary(logp, logq)
    # points whose transformed coordinates are not finite (stored samples that sit
    # exactly on the cube boundary map to ±Inf under PriorToNormal) get weight 0
    ok = isfinite.(logp) .& isfinite.(logq)
    logw = fill(-Inf, length(logp)); logw[ok] = logp[ok] .- logq[ok]
    mx = maximum(logw); w = exp.(logw .- mx)
    logZ = mx + log(mean(w))
    se = std(w) / (sqrt(length(w)) * mean(w))
    ess = sum(w)^2 / sum(w .^ 2)
    count(!, ok) > 0 && @info "dropped non-finite points" n = count(!, ok)
    return logZ, se, ess, w ./ sum(w)
end

rows = NamedTuple[]
for ord in (:NO, :IO)
    cfg = make_config_neutrino(ordering = ord)
    log_f = build_log_f(cfg)
    posterior = ExperimentsBase.posterior_measure(cfg, log_f)
    pstr, f_trafo = bat_transform(PriorToNormal(), posterior)
    k23 = findfirst(==(:θ₂₃), cfg.names)
    for name in sort(readdir(RUNS))
        occursin("nu_dakami_$(ord)_mw_d11_B5e5_seed", name) || continue
        mr = load_method_result(joinpath(RUNS, name))
        ex = mr.extras
        mix = haskey(ex, :mixture) ? ex[:mixture] : ex["mixture"]
        mix isa MixtureModel || (@warn "no mixture in $name"; continue)
        ncomp = length(components(mix))
        # (1) pooled cloud: the algorithm's own weights (stored) and its own evidence
        #     estimate (stored; computed by the harness in the transformed space).
        U = mr.samples
        w1 = mr.weights ./ sum(mr.weights)
        lz1 = mr.logZ_estimate
        ess1 = 1 / sum(w1 .^ 2)
        s23_1 = sin.(to_physical_matrix(cfg, U)[k23, :]) .^ 2
        pup1 = sum(w1 .* (s23_1 .> 0.5))
        # (2) fresh i.i.d. draws from the final mixture
        Random.seed!(1000 + mr.seed)
        Xf = [rand(mix) for _ in 1:NFRESH]
        logp2 = Vector{Float64}(undef, NFRESH); logq2 = similar(logp2)
        t0 = time()
        @threads for i in 1:NFRESH
            logp2[i] = logdensityof(pstr, Xf[i]); logq2[i] = logpdf(mix, Xf[i])
        end
        lz2, se2, ess2, w2 = is_summary(logp2, logq2)
        finv = inv(f_trafo)
        Uf = reduce(hcat, (collect(finv(x)) for x in Xf))
        s23_2 = sin.(to_physical_matrix(cfg, Uf)[k23, :]) .^ 2
        pup2 = sum(w2 .* (s23_2 .> 0.5))
        @info "mixture check" name ncomp pooled_logZ = lz1 fresh_logZ = lz2 fresh_se = se2 fresh_ess = ess2 pup_pooled = pup1 pup_fresh = pup2 seconds = round(time() - t0; digits = 1)
        push!(rows, (; ordering = String(ord), seed = mr.seed, n_components = ncomp, n_cloud = size(U, 2),
                      pooled_logZ = lz1, pooled_ess = ess1, pup_pooled = pup1,
                      N_fresh = NFRESH, fresh_logZ = lz2, fresh_se = se2, fresh_ess = ess2, pup_fresh = pup2))
    end
end
df = DataFrame(rows)
CSV.write(joinpath(TABLES, "mw_mixture_check.csv"), df)
show(df; allrows = true, allcols = true); println()
println("MW-MIXTURE-CHECK-DONE")

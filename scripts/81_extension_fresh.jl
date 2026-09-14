# =============================================================================
# 81_extension_fresh.jl — fresh-draw check of the MoleWhacker final mixtures of
# the extension "Towards a global fit" (d = 24, normal ordering).
# =============================================================================
#
#   julia --project=. -t 4 scripts/81_extension_fresh.jl [--ext out_extension_nseed8]
#         [--ext-proto out_extension] [--N 30000]
#
# Roots (final design, 14 Sep 2026): <ext> holds the MoleWhacker cells with the
# adapted seed count n_seed = 8 (three seeds; kind "nseed8"); <ext-proto> holds
# the single cell in the protocol configuration as specified, 30 seeds (kind
# "protocol30"), which documents the initialisation-dominated budget.
# For every finished MoleWhacker cell in <ext>/runs and <ext-proto>/runs, draw N
# independent samples from the stored final mixture (in BAT's PriorToNormal
# space, as 72_mw_mixture_check.jl / 73_tmax_study.jl), evaluate the exact
# posterior, and report the importance-sampling evidence, its standard error,
# the effective sample size (the honest efficiency of the mixture as a
# proposal), the Pareto k of the weights, and P(θ₂₃ > π/4). Cost: N likelihood
# evaluations of the four-experiment target per cell (~0.1 s each, threaded).
# Writes <ext>/tables/fresh.csv (83_extension_tables.jl adds the columns to
# the sampler table).
import Pkg
Pkg.activate(joinpath(@__DIR__, ".."))
using Random, Statistics, Printf, DataFrames, CSV, Distributions
using Base.Threads: @threads
include(joinpath(@__DIR__, "..", "harness", "experiments", "src", "ExperimentsBase.jl"))
using .ExperimentsBase
using BAT: bat_transform, PriorToNormal
using DensityInterface: logdensityof
include(joinpath(@__DIR__, "..", "src", "neutrino_problem.jl"))

const EXT = let i = findfirst(==("--ext"), ARGS); i === nothing ? joinpath(@__DIR__, "..", "out_extension_nseed8") : ARGS[i+1] end
const EXT_PROTO = let i = findfirst(==("--ext-proto"), ARGS); i === nothing ? joinpath(@__DIR__, "..", "out_extension") : ARGS[i+1] end
const NFRESH = let i = findfirst(==("--N"), ARGS); i === nothing ? 30_000 : parse(Int, ARGS[i+1]) end
const TABLES = joinpath(EXT, "tables"); mkpath(TABLES)

# Generalised-Pareto shape of the largest weights (Zhang & Stephens 2009), as in 71_is_diagnostics.jl
function gpd_khat(x::AbstractVector{<:Real})
    x = sort(x); n = length(x)
    n < 5 && return NaN
    prior = 3.0
    m = 30 + floor(Int, sqrt(n))
    q = x[max(1, floor(Int, n / 4 + 0.5))]
    θ = [1 / x[end] + (1 - sqrt(m / (j - 0.5))) / prior / q for j in 1:m]
    lx(b) = (k = -mean(log1p.(-b .* x)); log(b / k) + k - 1)
    l = [n * lx(b) for b in θ]
    w = exp.(l .- maximum(l)); w ./= sum(w)
    b = sum(θ .* w)
    return mean(log1p.(-b .* x))
end
function pareto_k(weights::AbstractVector{<:Real})
    w = sort(weights; rev = true); n = length(w)
    M = min(ceil(Int, 0.2n), ceil(Int, 3sqrt(n)))
    return gpd_khat(w[1:M] .- w[M + 1])
end

finished(dir) = isfile(joinpath(dir, "result.h5")) && filesize(joinpath(dir, "result.h5")) > 0

function fresh_check(dir, kind)
    meta = read_metadata_json(dir); pc = meta["problem"]["config"]
    mr = load_method_result(dir)
    mr.algorithm === :mw || return nothing
    haskey(mr.extras, :mixture) || (@warn "no stored mixture" dir; return nothing)
    ordering = Symbol(pc["ordering"]); exps = String.(pc["experiments"])
    cfg = make_config_neutrino(experiments = exps, ordering = ordering)
    Symbol.(pc["names"]) == cfg.names || error("parameter order differs from the stored cell: $dir")
    log_f = build_log_f(cfg)
    posterior = ExperimentsBase.posterior_measure(cfg, log_f)
    pstr, f_trafo = bat_transform(PriorToNormal(), posterior)
    mix = mr.extras[:mixture]
    Random.seed!(1000 + mr.seed)
    Xf = [rand(mix) for _ in 1:NFRESH]
    logp = Vector{Float64}(undef, NFRESH); logq = similar(logp)
    t0 = time()
    @threads for i in 1:NFRESH
        logp[i] = logdensityof(pstr, Xf[i]); logq[i] = logpdf(mix, Xf[i])
    end
    ok = isfinite.(logp) .& isfinite.(logq)
    logw = fill(-Inf, NFRESH); logw[ok] = logp[ok] .- logq[ok]
    mx = maximum(logw); w = exp.(logw .- mx)
    logZ = mx + log(mean(w)); se = std(w) / (sqrt(length(w)) * mean(w)); ess = sum(w)^2 / sum(w .^ 2)
    finv = inv(f_trafo)
    Uf = reduce(hcat, (collect(finv(x)) for x in Xf))
    Θ = to_physical_matrix(cfg, Uf)
    k23 = findfirst(==(:θ₂₃), cfg.names)
    wn = w ./ sum(w)
    s23 = sin.(Θ[k23, :]) .^ 2
    pup = sum(wn .* (s23 .> 0.5))
    # weighted posterior mean / sd of the derived atmospheric observables from the fresh draws
    k31 = findfirst(==(:Δm²₃₁), cfg.names); k21 = findfirst(==(:Δm²₂₁), cfg.names)
    d32 = Θ[k31, :] .- Θ[k21, :]
    wmean(x) = sum(wn .* x); wsd(x) = sqrt(max(sum(wn .* (x .- wmean(x)) .^ 2), 0.0))
    @info "fresh-draw check" dir kind seed = mr.seed logZ se ess eff = ess / NFRESH khat = pareto_k(w) P_upper = pup wall_s = round(time() - t0; digits = 1)
    return (kind = kind, seed = mr.seed, ordering = String(ordering), N = NFRESH, n_finite = count(ok),
            cloud_logZ = mr.logZ_estimate === missing ? NaN : mr.logZ_estimate, cloud_neff = neff(mr),
            fresh_logZ = logZ, fresh_se = se, fresh_ess = ess, fresh_eff = ess / NFRESH, pareto_k = pareto_k(w),
            fresh_P_upper = pup, fresh_sin2th23_mean = wmean(s23), fresh_sin2th23_sd = wsd(s23),
            fresh_dm32_mean = wmean(d32), fresh_dm32_sd = wsd(d32), wall_s = time() - t0)
end

rows = NamedTuple[]
for (root, kind) in ((EXT, "nseed8"), (EXT_PROTO, "protocol30"))
    runs = joinpath(root, "runs"); isdir(runs) || continue
    for name in sort(readdir(runs))
        (startswith(name, "nu_") && occursin("_mw_", name) && finished(joinpath(runs, name))) || continue
        r = fresh_check(joinpath(runs, name), kind)
        r === nothing || push!(rows, r)
    end
end
isempty(rows) && error("no finished MoleWhacker cells found")
df = DataFrame(rows)
CSV.write(joinpath(TABLES, "fresh.csv"), df)
println(df[:, [:kind, :seed, :cloud_logZ, :fresh_logZ, :fresh_se, :fresh_ess, :fresh_eff, :pareto_k, :fresh_P_upper]])
println("EXT-FRESH-DONE")

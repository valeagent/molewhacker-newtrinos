# =============================================================================
# 71_is_diagnostics.jl — importance-weight diagnostics for the weighted-sample
# cells (MoleWhacker, nested sampling, importance sampling): sample count, Kish
# ESS, share of the largest weight and of the top 1 %, and the Pareto-k̂ of the
# upper tail (Vehtari, Simpson, Gelman, Yao & Gabry, PSIS; Zhang–Stephens GPD
# fit). k̂ > 0.7 means the importance ratios have too heavy a tail for the
# self-normalised estimates (and the evidence) to be reliable.
#
#   julia --project=. scripts/71_is_diagnostics.jl
# Output: out/tables/is_diagnostics.csv
# =============================================================================
import Pkg
Pkg.activate(joinpath(@__DIR__, ".."))
using Statistics, Printf, CSV, DataFrames
# Thesis benchmark harness (module ExperimentsBase) and the thesis-final
# MoleWhacker; verbatim copies live in ../harness (see harness/PROVENANCE.md).
const HARNESS = joinpath(@__DIR__, "..", "harness", "experiments", "src", "ExperimentsBase.jl")
include(HARNESS)
using .ExperimentsBase

const OUT = joinpath(@__DIR__, "..", "out")
const RUNS = joinpath(OUT, "runs")
const TABLES = joinpath(OUT, "tables"); mkpath(TABLES)

# Generalised-Pareto shape estimate of Zhang & Stephens (2009), as used by PSIS.
function gpd_khat(x::AbstractVector{<:Real})
    x = sort(x); n = length(x)
    n < 5 && return NaN
    prior = 3.0
    m = 30 + floor(Int, sqrt(n))
    q = x[max(1, floor(Int, n / 4 + 0.5))]
    θ = [1 / x[end] + (1 - sqrt(m / (j - 0.5))) / prior / q for j in 1:m]
    lx(b) = (k = -mean(log1p.(-b .* x)); log(b / k) + k - 1)   # profile log-lik / n
    l = [n * lx(b) for b in θ]
    w = exp.(l .- maximum(l)); w ./= sum(w)
    b = sum(θ .* w)
    k = mean(log1p.(-b .* x))
    return k                                                # k̂ (shape); >0.7 bad
end

function pareto_k(weights::AbstractVector{<:Real})
    w = sort(weights; rev = true)
    n = length(w)
    M = min(ceil(Int, 0.2n), ceil(Int, 3sqrt(n)))
    tail = w[1:M]; cutoff = w[M + 1]
    return gpd_khat(tail .- cutoff)
end

rows = NamedTuple[]
for name in sort(readdir(RUNS))
    startswith(name, "nu_dakami_") || continue
    occursin(r"_(mw|ns|is)_", name) || continue
    isfile(joinpath(RUNS, name, "result.h5")) || continue
    mr = load_method_result(joinpath(RUNS, name))
    w = mr.weights; isempty(w) && continue
    w = w ./ sum(w); n = length(w)
    ess = 1 / sum(w .^ 2)
    ws = sort(w; rev = true)
    top1 = sum(ws[1:max(1, ceil(Int, 0.01n))])
    push!(rows, (; cell = name, alg = mr.algorithm, ordering = occursin("_NO_", name) ? "NO" : "IO",
                  B = mr.B, seed = mr.seed, n_samples = n, ess = round(ess; digits = 1),
                  ess_over_n = round(ess / n; digits = 4), max_w = round(ws[1]; digits = 4),
                  top1pct_share = round(top1; digits = 3), pareto_k = round(pareto_k(w); digits = 2),
                  logZ = ismissing(mr.logZ_estimate) ? NaN : mr.logZ_estimate))
end
df = DataFrame(rows)
CSV.write(joinpath(TABLES, "is_diagnostics.csv"), df)
show(df[:, Not(:cell)]; allrows = true, allcols = true); println()
println("IS-DIAG-DONE")

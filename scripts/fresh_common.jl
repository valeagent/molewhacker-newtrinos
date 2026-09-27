# =============================================================================
# fresh_common.jl — shared helpers for the final-inference ("fresh") estimator.
#
# Included by 20_aggregate.jl, 30_plots.jl (and through it 82/84) and
# 83_extension_tables.jl. Nothing here evaluates the target: the helpers only
# read saved final-sample payloads (75_final_sample.jl for d = 11,
# 81_extension_fresh.jl for d = 24) and turn them into MethodResult objects whose
# `samples` are the harness-cube coordinates and whose `weights` are the
# importance weights of the independent draws from the frozen final mixture.
#
# Estimator selection is explicit: `--estimator fresh` on the command line. In
# that mode a MoleWhacker cell without a saved payload is an error, never a
# silent fall-back to the accumulated adaptation population. The default
# (`population`) leaves every script exactly as archived.
# =============================================================================
using JLD2, Statistics

const ESTIMATOR = let i = findfirst(==("--estimator"), ARGS); i === nothing ? "population" : ARGS[i+1] end
ESTIMATOR in ("population", "fresh") || error("--estimator must be population or fresh")
fresh_mode() = ESTIMATOR == "fresh"

# Output sub-directory of the fresh-primary products (tables/figs) below an
# output root; archived population products in <root>/tables, <root>/figs are
# never overwritten.
fresh_subdir(root) = joinpath(root, "fresh_primary")

# Location of the saved final-sample payload of a MoleWhacker cell:
#   <root>/fresh_d11/<cell>.jld2            d = 11 (75_final_sample.jl)
#   <root>/fresh/nseed8__<cell>.jld2        d = 24, n_seed = 8 cells (81_extension_fresh.jl)
# or, explicitly, --fresh-dir <dir> [--fresh-prefix <prefix>] (used for the
# d = 24 protocol cell, whose payload protocol30__<cell>.jld2 lives in the
# n_seed = 8 tree).
const FRESH_DIR_OVERRIDE = let i = findfirst(==("--fresh-dir"), ARGS); i === nothing ? nothing : ARGS[i+1] end
const FRESH_PREFIX = let i = findfirst(==("--fresh-prefix"), ARGS); i === nothing ? "" : ARGS[i+1] end
function fresh_payload_path(root, name)
    FRESH_DIR_OVERRIDE === nothing || return joinpath(FRESH_DIR_OVERRIDE, FRESH_PREFIX * name * ".jld2")
    cands = [joinpath(root, "fresh_d11", name * ".jld2"), joinpath(root, "fresh", "nseed8__" * name * ".jld2")]
    for p in cands
        isfile(p) && return p
    end
    return cands[1]      # fresh_method_result raises the error naming this path
end

logsumexp_v(v) = (m = maximum(v); isfinite(m) ? m + log(sum(exp.(v .- m))) : m)

# Generalised-Pareto shape of the largest weights (Zhang & Stephens 2009), the
# same estimator as in 71_is_diagnostics.jl / 75_final_sample.jl / 81_extension_fresh.jl
# (used only when a payload does not store its own value).
function fc_gpd_khat(x::AbstractVector{<:Real})
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
function fc_pareto_k(weights::AbstractVector{<:Real})
    w = sort(weights; rev = true); n = length(w)
    M = min(ceil(Int, 0.2n), ceil(Int, 3sqrt(n)))
    return fc_gpd_khat(w[1:M] .- w[M + 1])
end

"""
    combined_kish(esss) -> Float64

Kish effective size of the equal average of J separately self-normalized
batches with Kish sizes E_j:  J^2 / sum_j (1 / E_j)  (Fig. 9.17 convention).
"""
combined_kish(esss) = length(esss)^2 / sum(1.0 ./ esss)

"""
    wquantile(x, w, p) -> Float64

Weighted quantile (weights need not be normalized; linear interpolation of the
cumulative weight).
"""
function wquantile(x::AbstractVector, w::AbstractVector, p::Real)
    o = sortperm(x); xs = x[o]; ws = w[o] ./ sum(w)
    c = cumsum(ws)
    i = something(findfirst(>=(p), c), length(xs))
    return xs[i]
end

# affine physical → harness cube, inverse of `physical(c, S)` in 20/30
function cube_from_physical(Θ::AbstractMatrix, lo, hi, L)
    U = Matrix{Float64}(undef, size(Θ)...)
    @inbounds for i in 1:size(Θ, 1)
        s = (hi[i] - lo[i]) / (2L)
        for n in 1:size(Θ, 2)
            U[i, n] = (Θ[i, n] - lo[i]) / s - L
        end
    end
    return U
end

"""
    fresh_method_result(mr, path, lo, hi, L) -> MethodResult

Build the final-inference MethodResult of a MoleWhacker cell from its saved
payload. `samples` = harness-cube coordinates of the independent draws,
`weights` = normalized importance weights, `Nlike_used` = C_adapt + N_fresh,
`logZ_estimate` = ordinary-IS evidence of the batch. The adaptation record
(iteration log, mixture, stop reason) is kept in `extras` for the construction
diagnostics, together with :estimator => :fresh, :C_adapt, :N_fresh,
:wall_adapt_s, :wall_fresh_eval_s, :payload.
"""
function fresh_method_result(mr::MethodResult, path::AbstractString, lo, hi, L)
    isfile(path) || error("estimator=fresh: no saved final-sample payload for $(basename(dirname(path)))/$(basename(path)); " *
                          "run scripts/75_final_sample.jl (d = 11) or 81_extension_fresh.jl (d = 24). No population fall-back.")
    d = JLD2.load(path)
    Θ = d["theta"]; wn = Vector{Float64}(d["weights"]); logw = Vector{Float64}(d["logw"])
    N = Int(get(d, "N", size(Θ, 2)))
    size(Θ, 2) == N == length(wn) == length(logw) || error("inconsistent payload $path")
    all(isfinite, wn) && abs(sum(wn) - 1) < 1e-6 || error("weights of $path are not normalized/finite")
    ok = isfinite.(logw)
    logZ = haskey(d, "logZ") ? Float64(d["logZ"]) : logsumexp_v(logw[ok]) - log(N)
    se = if haskey(d, "logZ_se")
        Float64(d["logZ_se"])
    else
        mx = maximum(logw[ok]); w = exp.(logw .- mx); w[.!ok] .= 0.0
        std(w) / (sqrt(N) * mean(w))
    end
    ess = haskey(d, "ess") ? Float64(d["ess"]) : 1 / sum(wn .^ 2)
    C_adapt = Float64(get(d, "C_adapt", mr.Nlike_used))
    N_fresh = Int(get(d, "N_fresh", N))
    C_total = Float64(get(d, "C_total", C_adapt + N_fresh))
    wall_eval = Float64(get(d, "wall_eval_s", NaN))
    U = cube_from_physical(Θ, lo, hi, L)
    ex = copy(mr.extras)
    ex[:estimator] = :fresh; ex[:C_adapt] = C_adapt; ex[:N_fresh] = N_fresh; ex[:C_total] = C_total
    ex[:wall_adapt_s] = mr.wall_time_s; ex[:wall_fresh_eval_s] = wall_eval
    ex[:payload] = path; ex[:ess_fresh] = ess
    ex[:pareto_k] = haskey(d, "pareto_k") ? Float64(d["pareto_k"]) : fc_pareto_k(wn)   # same tail estimator on the normalized weights (scale-free)
    ex[:rng_seed] = get(d, "rng_seed", missing)
    logd = haskey(d, "logp") ? Vector{Float64}(d["logp"]) : fill(NaN, N)   # transformed log target (diagnostic only)
    return MethodResult(:mw, mr.problem, mr.d, mr.seed, mr.B, C_total,
                        mr.n_primal + N_fresh, mr.n_grad_partials,
                        isfinite(wall_eval) ? mr.wall_time_s + wall_eval : mr.wall_time_s,   # sum of two separately measured phases
                        U, wn, logd, logZ, se, ex)
end

is_fresh(mr::MethodResult) = get(mr.extras, :estimator, :population) === :fresh

# Effective size used for the KDE bandwidth of a pool of cells: the combined
# Kish size for pooled fresh batches (equal-batch average), the sum of the
# per-run diagnostics otherwise (archived convention).
function pool_neff(mrs::AbstractVector{MethodResult})
    isempty(mrs) && return 0.0
    if all(is_fresh, mrs)
        return combined_kish([Float64(m.extras[:ess_fresh]) for m in mrs])
    end
    return sum(ExperimentsBase.neff(m) for m in mrs)
end

# Equal-batch pooled weights: a_ji = (w_ji / sum_i w_ji) / J, returned with the
# concatenated cube samples of the J cells (no resampling).
function pooled_weighted(mrs::AbstractVector{MethodResult})
    J = length(mrs)
    S = hcat((m.samples for m in mrs)...)
    a = vcat((begin
                  w = isempty(m.weights) ? ones(size(m.samples, 2)) : m.weights
                  (w ./ sum(w)) ./ J
              end for m in mrs)...)
    return S, a
end

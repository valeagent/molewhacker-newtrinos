# =============================================================================
# 70_evidence_check.jl — independent evidence estimates, used to arbitrate
# between MoleWhacker's ln Z and the converged nested-sampling reference.
#
#   (a) "anchored IS": defensive importance sampling from a KDE mixture built
#       on the pooled top-budget MH chains (M kernel centres, shared covariance
#       h²·Σ_MH) mixed with the uniform cube prior (weight ε). Unbiased for Z
#       with a valid standard error; independent of MW and NS.
#   (b) pooled plain IS: all uniform-prior draws of the harness IS cells.
#
#   julia --project=. -t 8 scripts/70_evidence_check.jl
#
# Convention: cube-prior-normalised evidence, log Z = log E_U[f] with
# U = Uniform([-L, L]^d), the same as the harness (IS, NS, MW).
# Output: out/tables/evidence_check.csv
# =============================================================================
import Pkg
Pkg.activate(joinpath(@__DIR__, ".."))
using LinearAlgebra, Statistics, Random, Printf, CSV, DataFrames
using Base.Threads
# Thesis benchmark harness (module ExperimentsBase) and the thesis-final
# MoleWhacker; verbatim copies live in ../harness (see harness/PROVENANCE.md).
const HARNESS = joinpath(@__DIR__, "..", "harness", "experiments", "src", "ExperimentsBase.jl")
include(HARNESS)
using .ExperimentsBase
include(joinpath(@__DIR__, "..", "src", "neutrino_problem.jl"))

const OUT = joinpath(@__DIR__, "..", "out")
const RUNS = joinpath(OUT, "runs")
const TABLES = joinpath(OUT, "tables"); mkpath(TABLES)

logsumexp(v) = (m = maximum(v); isfinite(m) ? m + log(sum(exp.(v .- m))) : m)
logaddexp(a, b) = (m = max(a, b); isfinite(m) ? m + log(exp(a - m) + exp(b - m)) : m)

function load_cells(ord, alg, B)
    dirs = filter(readdir(RUNS)) do n
        occursin("nu_dakami_$(ord)_$(alg)_d11_B$(B)_seed", n) && isfile(joinpath(RUNS, n, "result.h5"))
    end
    [load_method_result(joinpath(RUNS, n)) for n in sort(dirs)]
end

function anchored_is(ord::Symbol, cfg, log_f, S::Matrix{Float64}; M = 3000, N = 150_000, h = 0.6, eps = 0.1, seed = 7)
    rng = Xoshiro(seed)
    d, L = cfg.d, cfg.L
    C = S[:, rand(rng, 1:size(S, 2), M)]
    K = Symmetric(h^2 * cov(S'))
    Lch = cholesky(K).L
    Linv = inv(Lch)
    W = Linv * C                                   # whitened centres
    logdetL = sum(log.(diag(Lch)))
    # draws from q = (1-eps)·KDE + eps·Uniform(cube)
    U = Matrix{Float64}(undef, d, N)
    for n in 1:N
        if rand(rng) < eps
            U[:, n] = (rand(rng, d) .- 0.5) .* (2L)
        else
            U[:, n] = C[:, rand(rng, 1:M)] .+ Lch * randn(rng, d)
        end
    end
    # log q
    logq = Vector{Float64}(undef, N)
    logu = -d * log(2L)
    @threads for n in 1:N
        z = Linv * view(U, :, n)
        r2 = Vector{Float64}(undef, M)
        @inbounds for m in 1:M
            s = 0.0
            for i in 1:d
                t = z[i] - W[i, m]; s += t * t
            end
            r2[m] = -0.5 * s
        end
        lk = logsumexp(r2) - d / 2 * log(2π) - logdetL - log(M)
        inside = all(abs.(view(U, :, n)) .<= L)
        logq[n] = inside ? logaddexp(log(1 - eps) + lk, log(eps) + logu) : log(1 - eps) + lk
    end
    # log f (target on the cube; -Inf outside)
    logf = Vector{Float64}(undef, N)
    t0 = time()
    @threads for n in 1:N
        logf[n] = log_f(view(U, :, n))
    end
    tf = time() - t0
    logw = logf .- logq
    mx = maximum(logw)
    w = exp.(logw .- mx)
    meanw = mean(w)
    logZ = mx + log(meanw) - d * log(2L)
    se = std(w) / (sqrt(N) * meanw)                 # relative SE of Ẑ ≈ SE of ln Ẑ
    ess = sum(w)^2 / sum(w .^ 2)
    # posterior checks from the same weighted sample
    Θ = to_physical_matrix(cfg, U)
    k23 = findfirst(==(:θ₂₃), cfg.names)
    s23 = sin.(Θ[k23, :]) .^ 2
    pup = sum(w .* (s23 .> 0.5)) / sum(w)
    frac_out = mean(.!isfinite.(logf))
    @info "anchored IS" ord M N h eps logZ se ess pup frac_out seconds_logf = round(tf; digits = 1)
    return (; ord, method = "anchored_is", M, N, h, eps, logZ, se, ess, pup, frac_out)
end

function pooled_plain_is(ord::Symbol, cfg)
    logd = Float64[]
    for B in ("5e4", "5e5"), mr in load_cells(ord, "is", B)
        append!(logd, mr.logd)
    end
    N = length(logd)
    logZ = logsumexp(logd) - log(N)
    w = exp.(logd .- maximum(logd))
    ess = sum(w)^2 / sum(w .^ 2)
    se = std(w) / (sqrt(N) * mean(w))
    @info "pooled plain IS" ord N logZ se ess
    return (; ord, method = "pooled_plain_is", M = 0, N, h = NaN, eps = NaN, logZ, se, ess, pup = NaN, frac_out = NaN)
end

rows = NamedTuple[]
for ord in (:NO, :IO)
    cfg = make_config_neutrino(ordering = ord)
    log_f = build_log_f(cfg)
    mhs = load_cells(ord, "mh", "5e5")
    S = hcat((mr.samples for mr in mhs)...)
    @info "MH pool" ord n_cells = length(mhs) n_samples = size(S, 2)
    for (h, seed) in ((0.6, 7), (0.9, 11))
        push!(rows, anchored_is(ord, cfg, log_f, S; h = h, seed = seed))
    end
    push!(rows, pooled_plain_is(ord, cfg))
    # reference values from the campaign for the same table
    for (alg, B) in (("mw", "5e5"), ("ns", "4e+06"), ("ns", "5e5"), ("is", "5e5"))
        for mr in load_cells(ord, alg, B)
            push!(rows, (; ord, method = "$(alg)_B$(B)_seed$(mr.seed)", M = 0, N = Int(round(mr.Nlike_used)), h = NaN, eps = NaN,
                          logZ = ismissing(mr.logZ_estimate) ? NaN : Float64(mr.logZ_estimate),
                          se = ismissing(mr.logZ_estimate_se) ? NaN : Float64(mr.logZ_estimate_se),
                          ess = NaN, pup = NaN, frac_out = NaN))
        end
    end
end
df = DataFrame(rows)
CSV.write(joinpath(TABLES, "evidence_check.csv"), df)
println(df)
println("EVIDENCE-CHECK-DONE")

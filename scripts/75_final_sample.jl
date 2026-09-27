# =============================================================================
# 75_final_sample.jl — final inference stage of the eleven-parameter joint fit
# (Daya Bay + KamLAND + MINOS, both orderings).
#
# For each MoleWhacker cell the frozen final Gaussian mixture q_T (result.h5,
# extras[:mixture], BAT PriorToNormal space) is reloaded and N independent draws
# z_i ~ q_T are weighted with the exact transformed posterior,
# w_i = p̃(z_i) / q_T(z_i). 72_mw_mixture_check.jl performed the same
# computation for the six top-budget cells but kept only scalar summaries; this
# script saves the draws with their coordinates and weights so that they are the
# inference sample of the thesis (marginals, contours, weighted quantiles,
# octant probabilities, nuisance pulls, prior reweighting, predictive bands).
#
#   --stage top   the six B = 5e5 cells: N = 60,000, RNG seed 1000 + cell seed —
#                 the exact convention of 72_mw_mixture_check.jl, so the batch
#                 replays the archived check; the recomputed logZ / ESS / P_upper
#                 are compared with out/tables/mw_mixture_check.csv (recovery gate)
#   --stage low   the six B = 5e4 cells: N = min(60,000, max(0, floor(B − C_adapt))),
#                 RNG seed 2000 + cell seed — a new computation, recorded as such
#   --only NO:11[,IO:23,...]  restrict to the listed cells (ordering:seed)
#
#   julia --project=. -t 10 scripts/75_final_sample.jl --stage top [--only NO:11]
#
# Output: out/fresh_d11/<cell>.jld2  (coordinates, log densities, weights, provenance)
#         out/tables/fresh_d11.csv    (one row per cell; merged on repeated runs)
# Cost:   N target evaluations per cell, charged in addition to the adaptation
#         cost C_adapt of the stored run (C_total = C_adapt + N).
# Nothing in the stored runs, the pinned Newtrinos environment or the target is
# modified.
# =============================================================================
import Pkg
Pkg.activate(joinpath(@__DIR__, ".."))
using LinearAlgebra, Statistics, Random, Printf, Dates, CSV, DataFrames, Distributions, PDMats, JLD2, SHA
using Base.Threads
using BAT: bat_transform, PriorToNormal
using DensityInterface: logdensityof
const HARNESS = joinpath(@__DIR__, "..", "harness", "experiments", "src", "ExperimentsBase.jl")
include(HARNESS)
using .ExperimentsBase
include(joinpath(@__DIR__, "..", "src", "neutrino_problem.jl"))

const OUT = joinpath(@__DIR__, "..", "out")
const RUNS = joinpath(OUT, "runs")
const TABLES = joinpath(OUT, "tables"); mkpath(TABLES)
const FRESHDIR = joinpath(OUT, "fresh_d11"); mkpath(FRESHDIR)
argval(flag, default) = (i = findfirst(==(flag), ARGS); i === nothing ? default : ARGS[i+1])
const STAGE = argval("--stage", "top")
const ONLY = argval("--only", nothing)
STAGE in ("top", "low") || error("--stage must be top or low")
const BTAG = STAGE == "top" ? "B5e5" : "B5e4"
const NCAP = 60_000
const RNG_OFFSET = STAGE == "top" ? 1000 : 2000
const REFCSV = joinpath(TABLES, "mw_mixture_check.csv")

# Generalised-Pareto shape of the largest weights (Zhang & Stephens 2009), as in 71/81
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

# SHA-256 of the frozen proposal (component weights, means, covariances)
function mixture_sha256(mix::MixtureModel)
    io = IOBuffer()
    write(io, Vector{Float64}(probs(mix)))
    for c in components(mix)
        write(io, Vector{Float64}(mean(c))); write(io, Matrix{Float64}(cov(c)))
    end
    return bytes2hex(sha256(take!(io)))
end

function newtrinos_pin()
    for (uuid, dep) in Pkg.dependencies()
        dep.name == "Newtrinos" && return something(dep.git_revision, string(dep.version))
    end
    return "unknown"
end

function final_sample(ord::Symbol, seed::Int, cfg, pstr, f_trafo, k23, ref)
    name = "nu_dakami_$(ord)_mw_d11_$(BTAG)_seed$(seed)"
    dir = joinpath(RUNS, name)
    isdir(dir) || error("missing run directory $dir")
    meta = read_metadata_json(dir)
    mr = load_method_result(dir)
    mr.algorithm === :mw || error("$name is not a MoleWhacker run")
    Symbol.(meta["problem"]["config"]["names"]) == cfg.names || error("parameter order differs from the stored cell: $name")
    mix = mr.extras[:mixture]
    mix isa MixtureModel || error("no stored mixture in $name")
    B = mr.B; C_adapt = mr.Nlike_used
    N = STAGE == "top" ? NCAP : min(NCAP, max(0, floor(Int, B - C_adapt)))
    if N == 0
        @warn "no remaining budget; no within-budget inference estimate" name B C_adapt
        return nothing
    end
    rng_seed = RNG_OFFSET + mr.seed
    Random.seed!(rng_seed)
    Xf = [rand(mix) for _ in 1:N]                    # serial draw order, as in 72_mw_mixture_check.jl
    logp = Vector{Float64}(undef, N); logq = similar(logp)
    t0 = time()
    @threads for i in 1:N
        logp[i] = logdensityof(pstr, Xf[i]); logq[i] = logpdf(mix, Xf[i])
    end
    wall_eval = time() - t0
    any(isnan, logp) && error("NaN target density in $name")
    any(==(Inf), logp) && error("+Inf target density in $name")
    ok = isfinite.(logp) .& isfinite.(logq)          # -Inf target (outside support) ⇒ weight 0, kept in N
    logw = fill(-Inf, N); logw[ok] = logp[ok] .- logq[ok]
    any(isfinite, logw) || error("no finite importance weights in $name")
    mx = maximum(logw); w = exp.(logw .- mx)
    logZ = mx + log(mean(w))                          # ordinary IS mean over all N draws
    se = std(w) / (sqrt(N) * mean(w))
    ess = sum(w)^2 / sum(w .^ 2)
    wn = w ./ sum(w)
    finv = inv(f_trafo)
    Uf = reduce(hcat, (collect(finv(x)) for x in Xf))
    Θ = to_physical_matrix(cfg, Uf)
    s23 = sin.(Θ[k23, :]) .^ 2
    pup = sum(wn .* (s23 .> 0.5))
    khat = pareto_k(w)
    X = reduce(hcat, Xf)
    mixhash = mixture_sha256(mix)

    # recovery gate against the archived scalar check (top budget only)
    gate = missing; ref_logZ = NaN; ref_ess = NaN; ref_pup = NaN
    if STAGE == "top" && ref !== nothing
        r = ref[(ref.ordering .== String(ord)) .& (ref.seed .== seed), :]
        if nrow(r) == 1
            ref_logZ = r.fresh_logZ[1]; ref_ess = r.fresh_ess[1]; ref_pup = r.pup_fresh[1]
            gate = abs(logZ - ref_logZ) <= 1e-8 && abs(pup - ref_pup) <= 1e-8 && abs(ess - ref_ess) / ref_ess <= 1e-7
            @info "recovery gate" name gate dlogZ = logZ - ref_logZ dess_rel = (ess - ref_ess) / ref_ess dpup = pup - ref_pup
        end
    end

    path = joinpath(FRESHDIR, name * ".jld2")
    JLD2.jldopen(path, "w") do f
        f["cell"] = name; f["ordering"] = String(ord); f["seed"] = mr.seed; f["B"] = B; f["stage"] = STAGE
        f["names"] = String.(cfg.names)
        f["theta"] = Θ                                # d × N physical coordinates
        f["X_transformed"] = X                        # d × N BAT PriorToNormal coordinates (where logp, logq are evaluated)
        f["logp"] = logp; f["logq"] = logq; f["logw"] = logw; f["weights"] = wn
        f["n_finite"] = count(ok)
        f["N"] = N; f["rng_seed"] = rng_seed
        f["rng"] = "Random.seed!($rng_seed); [rand(mix) for _ in 1:$N] (serial), Julia $(VERSION) default RNG"
        f["C_adapt"] = C_adapt; f["N_fresh"] = N; f["C_total"] = C_adapt + N
        f["n_components"] = length(components(mix)); f["mixture_sha256"] = mixhash
        f["logZ"] = logZ; f["logZ_se"] = se; f["ess"] = ess; f["pareto_k"] = khat; f["P_upper"] = pup
        f["coordinates_note"] = "logp (transformed posterior, prior and Jacobian included) and logq (full final mixture) are evaluated in the same BAT PriorToNormal coordinates X_transformed; theta is obtained by the inverse transform to the harness cube and the affine cube-to-physical map. Points with non-finite logp carry weight 0 and remain in the evidence denominator N."
        f["source_run"] = dir; f["source_finished_utc"] = get(meta, "finished_utc", "")
        f["newtrinos_pin"] = newtrinos_pin(); f["julia_version"] = string(VERSION)
        f["script"] = "scripts/75_final_sample.jl"; f["created_utc"] = string(Dates.now(Dates.UTC))
        f["wall_eval_s"] = wall_eval; f["n_threads"] = nthreads()
        f["gate_reference"] = STAGE == "top" ? "out/tables/mw_mixture_check.csv" : "none (new computation)"
        f["gate_pass"] = gate
    end
    @info "final sample" name N C_adapt C_total = C_adapt + N logZ se ess eff_total = ess / (C_adapt + N) khat P_upper = pup wall_eval_s = round(wall_eval; digits = 1)
    return (; cell = name, ordering = String(ord), seed = mr.seed, B = B, stage = STAGE,
            C_adapt = C_adapt, N_fresh = N, C_total = C_adapt + N, rng_seed = rng_seed,
            n_components = length(components(mix)), n_finite = count(ok),
            logZ = logZ, logZ_se = se, ess = ess, eff_total = ess / (C_adapt + N), eff_draw = ess / N,
            pareto_k = khat, P_upper = pup, wall_eval_s = wall_eval, n_threads = nthreads(),
            ref_logZ = ref_logZ, ref_ess = ref_ess, ref_P_upper = ref_pup, gate_pass = gate,
            mixture_sha256 = mixhash, payload = relpath(path, joinpath(@__DIR__, "..")))
end

ref = isfile(REFCSV) ? CSV.read(REFCSV, DataFrame) : nothing
rows = NamedTuple[]
for ord in (:NO, :IO)
    cfg = make_config_neutrino(ordering = ord)
    log_f = build_log_f(cfg)
    posterior = ExperimentsBase.posterior_measure(cfg, log_f)
    pstr, f_trafo = bat_transform(PriorToNormal(), posterior)
    k23 = findfirst(==(:θ₂₃), cfg.names)
    for seed in (11, 23, 41)
        ONLY === nothing || "$(ord):$(seed)" in split(ONLY, ",") || continue
        r = final_sample(ord, seed, cfg, pstr, f_trafo, k23, ref)
        r === nothing || push!(rows, r)
    end
end
isempty(rows) && error("no cell processed")
df = DataFrame(rows)
csv = joinpath(TABLES, "fresh_d11.csv")
if isfile(csv)
    old = CSV.read(csv, DataFrame)
    keep = old[[!any((r.cell == n) for n in df.cell) for r in eachrow(old)], :]
    df = sort(vcat(keep, df; cols = :union), [:stage, :ordering, :seed])
end
CSV.write(csv, df)
show(df[:, [:cell, :N_fresh, :C_total, :logZ, :ess, :P_upper, :pareto_k, :gate_pass, :wall_eval_s]]; allrows = true, allcols = true); println()
if STAGE == "top"
    g = df[df.stage .== "top", :gate_pass]
    println(all(x -> x === true, g) ? "RECOVERY-GATE-PASS" : "RECOVERY-GATE-FAIL")
end
println("FINAL-SAMPLE-DONE")

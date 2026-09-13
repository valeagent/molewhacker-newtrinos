# =============================================================================
# 20_aggregate.jl — collect all finished cells into the chapter's tables.
# =============================================================================
#
#   julia --project=. scripts/20_aggregate.jl [--out out]
#
# Writes to <out>/tables/:
#   cells.csv       one row per cell: cost, wall time, ESS, efficiency, log Z,
#                   stop reason, physical-unit mean/sd per parameter,
#                   P(θ₂₃ > π/4) (upper octant)
#   agreement.csv   W̄1 (in units of the prior width) between each cell and the
#                   pooled top-budget MH reference of the same ordering
#                   (leave-one-seed-out for MH cells themselves)
#   pairs.csv       pairwise W̄1 between algorithms at the top budget, seed 11
#   evidence.csv    log Z per (ordering, algorithm, B, seed) and the
#                   mass-ordering Bayes factor ln K = log Z(NO) − log Z(IO)
import Pkg
Pkg.activate(joinpath(@__DIR__, ".."))
using Random, Statistics, StatsBase, Printf, DataFrames, CSV, JLD2
# Thesis benchmark harness (module ExperimentsBase) and the thesis-final
# MoleWhacker; verbatim copies live in ../harness (see harness/PROVENANCE.md).
const HARNESS = joinpath(@__DIR__, "..", "harness", "experiments", "src", "ExperimentsBase.jl")
include(HARNESS)
using .ExperimentsBase

const OUT = let i = findfirst(==("--out"), ARGS); i === nothing ? joinpath(@__DIR__, "..", "out") : ARGS[i+1] end
const RUNS = joinpath(OUT, "runs")
const TABLES = joinpath(OUT, "tables")
mkpath(TABLES)
const N_EVAL = 20_000
const OSC = [:θ₁₂, :θ₁₃, :θ₂₃, :δCP, :Δm²₂₁, :Δm²₃₁]
# only cells of the main problem (Daya Bay + KamLAND + MINOS); side studies
# such as the KamLAND-only fit carry a different tag prefix
const TAG_PREFIX = let i = findfirst(==("--tag"), ARGS); i === nothing ? "nu_dakami_" : ARGS[i+1] end

struct Cell
    dir::String
    tag::Symbol
    ordering::Symbol
    alg::Symbol
    B::Float64
    seed::Int
    mr::MethodResult
    names::Vector{Symbol}
    lo::Vector{Float64}
    hi::Vector{Float64}
    L::Float64
    stop::String
    tuning::Dict{String,Any}
end

function load_cells()
    cells = Cell[]
    for name in sort(readdir(RUNS))
        startswith(name, TAG_PREFIX) || continue
        dir = joinpath(RUNS, name)
        isfile(joinpath(dir, "result.h5")) || continue
        meta = read_metadata_json(dir)
        pc = meta["problem"]["config"]
        mr = load_method_result(dir)
        size(mr.samples, 2) <= 1 && (@warn "empty cell skipped" name; continue)
        tuning = Dict{String,Any}(meta["algorithm"]["tuning"])
        push!(cells, Cell(dir, mr.problem, Symbol(pc["ordering"]), mr.algorithm, mr.B, mr.seed, mr,
            Symbol.(pc["names"]), Float64.(pc["lo"]), Float64.(pc["hi"]), Float64(pc["L"]),
            String(get(tuning, "stop_reason", "?")), tuning))
    end
    return cells
end

# Split (potential scale reduction) R̂ of one scalar chain matrix (n × m).
function rhat_split(X::AbstractMatrix)
    n, m = size(X)
    n < 4 && return NaN
    h = n ÷ 2
    parts = vcat([view(X, 1:h, j) for j in 1:m], [view(X, h+1:2h, j) for j in 1:m])
    means = mean.(parts); vars = var.(parts)
    W = mean(vars); Bv = h * var(means)
    W <= 0 && return NaN
    return sqrt(((h - 1) / h * W + Bv / h) / W)
end

# Equal-weight sample matrix in units of the prior width ([-0.5, 0.5] per coordinate).
function unit_samples(c::Cell, N::Int, rng)
    S = c.mr.samples
    w = isempty(c.mr.weights) ? ones(size(S, 2)) : c.mr.weights
    R = resample_to_equal_weight(S, w, N; rng = rng)
    return R ./ (2c.L)
end

# Cube → physical units (affine; mirrors to_physical_matrix in neutrino_problem.jl
# without loading Newtrinos).
function physical(c::Cell, S = c.mr.samples)
    Θ = Matrix{Float64}(undef, size(S)...)
    @inbounds for i in 1:size(S, 1)
        s = (c.hi[i] - c.lo[i]) / (2c.L)
        for n in 1:size(S, 2)
            Θ[i, n] = c.lo[i] + (S[i, n] + c.L) * s
        end
    end
    return Θ
end

function weighted_stats(x, w)
    w = w ./ sum(w)
    m = sum(w .* x)
    s = sqrt(max(sum(w .* (x .- m) .^ 2), 0.0))
    return m, s
end

w1_1d(x::AbstractVector, y::AbstractVector) = mean(abs.(sort(x) .- sort(y)))
w1_avg(X::AbstractMatrix, Y::AbstractMatrix) = mean(w1_1d(view(X, j, :), view(Y, j, :)) for j in 1:size(X, 1))

# ASCII column names for the CSV tables (LaTeX table generation reads these).
const ASCII = Dict(:θ₁₂ => "th12", :θ₁₃ => "th13", :θ₂₃ => "th23", :δCP => "dcp",
                   :Δm²₂₁ => "dm21", :Δm²₃₁ => "dm31")
ascii(nm::Symbol) = get(ASCII, nm, String(nm))

# Equal-weight physical samples pooled over all cells of one (ordering, alg, B).
function pooled_physical(cells, ordering, alg, B, N, rng)
    sel = [c for c in cells if c.ordering === ordering && c.alg === alg && c.B == B]
    isempty(sel) && return nothing, nothing
    Ns = cld(N, length(sel))
    parts = Matrix{Float64}[]
    for c in sel
        w = isempty(c.mr.weights) ? ones(size(c.mr.samples, 2)) : c.mr.weights
        push!(parts, physical(c, resample_to_equal_weight(c.mr.samples, w, Ns; rng = rng)))
    end
    return hcat(parts...), sel
end

# Derived observables the experiments publish, from a physical sample matrix.
function derived(Θ, names)
    ix(nm) = findfirst(==(nm), names)
    θ12 = view(Θ, ix(:θ₁₂), :); θ13 = view(Θ, ix(:θ₁₃), :); θ23 = view(Θ, ix(:θ₂₃), :)
    dm21 = view(Θ, ix(:Δm²₂₁), :); dm31 = view(Θ, ix(:Δm²₃₁), :)
    return (
        sin2_2th13 = sin.(2 .* θ13) .^ 2,
        sin2_th13 = sin.(θ13) .^ 2,
        sin2_th12 = sin.(θ12) .^ 2,
        tan2_th12 = tan.(θ12) .^ 2,
        sin2_th23 = sin.(θ23) .^ 2,
        sin2_2th23 = sin.(2 .* θ23) .^ 2,
        dm21 = collect(dm21),
        dm31 = collect(dm31),
        dm32 = dm31 .- dm21,            # m3² − m2² = Δm²₃₁ − Δm²₂₁, both orderings
        dcp = collect(view(Θ, ix(:δCP), :)),
    )
end

function summarise_row!(r, prefix, x)
    q = quantile(x, (0.16, 0.5, 0.84))
    r[Symbol(prefix, "_mean")] = mean(x); r[Symbol(prefix, "_sd")] = std(x)
    r[Symbol(prefix, "_q16")] = q[1]; r[Symbol(prefix, "_q50")] = q[2]; r[Symbol(prefix, "_q84")] = q[3]
end

function main()
    cells = load_cells()
    @info "loaded cells" n = length(cells)
    isempty(cells) && return

    # ---------------- cells.csv ----------------
    rows = DataFrame()
    for c in cells
        Θ = physical(c)
        w = isempty(c.mr.weights) ? ones(size(Θ, 2)) : c.mr.weights
        ne = neff(c.mr)
        r = Dict{Symbol,Any}(:tag => c.tag, :ordering => c.ordering, :alg => c.alg, :B => c.B, :seed => c.seed,
            :Nlike_used => c.mr.Nlike_used, :wall_time_s => c.mr.wall_time_s, :N => size(Θ, 2),
            :neff => ne, :eta => ne / max(c.mr.Nlike_used, 1), :stop => c.stop,
            :logZ => c.mr.logZ_estimate === missing ? NaN : c.mr.logZ_estimate,
            :logZ_se => c.mr.logZ_estimate_se === missing ? NaN : c.mr.logZ_estimate_se)
        for (i, nm) in enumerate(c.names)
            m, s = weighted_stats(view(Θ, i, :), w)
            r[Symbol(ascii(nm), "_mean")] = m
            r[Symbol(ascii(nm), "_sd")] = s
        end
        i23 = findfirst(==(:θ₂₃), c.names)
        if i23 !== nothing
            wn = w ./ sum(w)
            r[:P_upper_octant] = sum(wn[view(Θ, i23, :) .> π / 4])
        end
        push!(rows, r; cols = :union)
    end
    sort!(rows, [:ordering, :B, :alg, :seed])
    lead = [:tag, :ordering, :alg, :B, :seed, :Nlike_used, :wall_time_s, :N, :neff, :eta, :stop, :logZ, :logZ_se, :P_upper_octant]
    parcols = Symbol[]
    for nm in cells[1].names, suf in ("_mean", "_sd")
        push!(parcols, Symbol(ascii(nm), suf))
    end
    select!(rows, [c for c in vcat(lead, parcols) if c in propertynames(rows)])
    CSV.write(joinpath(TABLES, "cells.csv"), rows)

    # ---------------- physics.csv: pooled derived observables ----------------
    rngp = MersenneTwister(99)
    phys = DataFrame()
    for ord in (:NO, :IO), alg in (:mw, :mh, :nuts, :ns, :is), B in sort(unique(c.B for c in cells))
        Θ, sel = pooled_physical(cells, ord, alg, B, 60_000, rngp)
        Θ === nothing && continue
        r = Dict{Symbol,Any}(:ordering => ord, :alg => alg, :B => B, :n_seeds => length(sel),
                             :Nlike_mean => mean(c.mr.Nlike_used for c in sel))
        names = sel[1].names
        for (i, nm) in enumerate(names)
            summarise_row!(r, ascii(nm), view(Θ, i, :))
        end
        for (k, v) in Base.pairs(derived(Θ, names))   # `pairs` is a local DataFrame below
            summarise_row!(r, String(k), v)
        end
        r[:P_upper_octant] = mean(view(Θ, findfirst(==(:θ₂₃), names), :) .> π / 4)
        push!(phys, r; cols = :union)
    end
    sort!(phys, [:ordering, :B, :alg])
    leadp = [:ordering, :alg, :B, :n_seeds, :Nlike_mean, :P_upper_octant]
    select!(phys, vcat(leadp, sort([c for c in propertynames(phys) if !(c in leadp)])))
    CSV.write(joinpath(TABLES, "physics.csv"), phys)
    println(phys[:, [:ordering, :alg, :B, :n_seeds, :sin2_2th13_q50, :dm32_q50, :dm21_q50, :sin2_th12_q50, :sin2_th23_q50, :P_upper_octant]])
    println(first(rows[:, [:ordering, :alg, :B, :seed, :Nlike_used, :neff, :eta, :logZ, :stop, :P_upper_octant]], 60))

    # ---------------- reference: pooled top-budget MH per ordering ----------------
    rng = MersenneTwister(2026)
    Bmax = maximum(c.B for c in cells if c.alg === :mh; init = 0.0)
    refs = Dict{Tuple{Symbol,Int},Matrix{Float64}}()   # (ordering, excluded seed) → pooled unit samples
    mh_top = [c for c in cells if c.alg === :mh && c.B == Bmax]
    for ord in (:NO, :IO)
        pool = [c for c in mh_top if c.ordering === ord]
        isempty(pool) && continue
        for excl in vcat(0, [c.seed for c in pool])
            use = [c for c in pool if c.seed != excl]
            isempty(use) && continue
            refs[(ord, excl)] = hcat((unit_samples(c, cld(N_EVAL, length(use)), rng) for c in use)...)
        end
    end

    # ---------------- agreement.csv ----------------
    agree = DataFrame(ordering = Symbol[], alg = Symbol[], B = Float64[], seed = Int[], W1_avg = Float64[],
                      W1_osc = Float64[], ref = String[])
    for c in cells
        key = (c.ordering, c.alg === :mh && c.B == Bmax ? c.seed : 0)
        haskey(refs, key) || continue
        R = refs[key]
        X = unit_samples(c, size(R, 2), rng)
        osc_idx = [findfirst(==(nm), c.names) for nm in OSC]
        push!(agree, (c.ordering, c.alg, c.B, c.seed, w1_avg(X, R),
                      mean(w1_1d(view(X, j, :), view(R, j, :)) for j in osc_idx),
                      key[2] == 0 ? "pooled MH B=$(Bmax)" : "pooled MH B=$(Bmax) excl. seed $(key[2])"))
    end
    sort!(agree, [:ordering, :B, :alg, :seed])
    CSV.write(joinpath(TABLES, "agreement.csv"), agree)
    println(agree)

    # ---------------- pairs.csv (top budget, seed 11) ----------------
    pairs = DataFrame(ordering = Symbol[], alg1 = Symbol[], alg2 = Symbol[], B = Float64[], W1_avg = Float64[])
    for ord in (:NO, :IO)
        top = [c for c in cells if c.ordering === ord && c.B == Bmax && c.seed == 11]
        for i in 1:length(top), j in i+1:length(top)
            X = unit_samples(top[i], N_EVAL, rng); Y = unit_samples(top[j], N_EVAL, rng)
            push!(pairs, (ord, top[i].alg, top[j].alg, Bmax, w1_avg(X, Y)))
        end
    end
    CSV.write(joinpath(TABLES, "pairs.csv"), pairs)
    println(pairs)

    # ---------------- chains.csv: per-chain octant occupation of MH / NUTS ----------------
    chains = DataFrame(ordering = Symbol[], alg = Symbol[], B = Float64[], seed = Int[], chain = Int[], n = Int[],
                       frac_upper = Float64[], mean_sin2th23 = Float64[], rhat_th23 = Float64[], acc_rate = Float64[])
    for c in cells
        c.alg in (:mh, :nuts) || continue
        m = Int(get(c.tuning, "nchains", 0))
        m >= 1 || continue
        i23 = findfirst(==(:θ₂₃), c.names)
        Θ = physical(c)
        N = size(Θ, 2); n = N ÷ m
        n * m == N || (@warn "chain-major reshape failed" c.dir N m; continue)
        X = reshape(view(Θ, i23, :), n, m)          # chain-major storage → n × m
        rh = rhat_split(X)
        acc = get(c.tuning, "chain_acc_rates", nothing)
        for j in 1:m
            s2 = sin.(X[:, j]) .^ 2
            push!(chains, (c.ordering, c.alg, c.B, c.seed, j, n, mean(X[:, j] .> π / 4), mean(s2), rh,
                           acc isa AbstractVector && length(acc) >= j ? Float64(acc[j]) : NaN))
        end
    end
    sort!(chains, [:ordering, :B, :alg, :seed, :chain])
    CSV.write(joinpath(TABLES, "chains.csv"), chains)
    println(chains)

    # ---------------- evidence.csv ----------------
    ev = rows[.!isnan.(rows.logZ), [:ordering, :alg, :B, :seed, :logZ, :logZ_se, :stop]]
    CSV.write(joinpath(TABLES, "evidence.csv"), ev)
    println(ev)
    bf = DataFrame(alg = Symbol[], B = Float64[], lnK_NO_IO = Float64[], se = Float64[], n_pairs = Int[])
    for g in groupby(ev, [:alg, :B])
        no = g[g.ordering .== :NO, :]; io = g[g.ordering .== :IO, :]
        (isempty(no) || isempty(io)) && continue
        lnK = mean(no.logZ) - mean(io.logZ)
        se_no = nrow(no) > 1 ? std(no.logZ) / sqrt(nrow(no)) : (isnan(no.logZ_se[1]) ? NaN : no.logZ_se[1])
        se_io = nrow(io) > 1 ? std(io.logZ) / sqrt(nrow(io)) : (isnan(io.logZ_se[1]) ? NaN : io.logZ_se[1])
        push!(bf, (g.alg[1], g.B[1], lnK, sqrt(se_no^2 + se_io^2), min(nrow(no), nrow(io))))
    end
    CSV.write(joinpath(TABLES, "bayes_factor.csv"), bf)
    println(bf)
    println("AGGREGATE-DONE")
end

main()

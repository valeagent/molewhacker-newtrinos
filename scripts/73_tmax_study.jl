# =============================================================================
# 73_tmax_study.jl — the iteration-cap ablation: MoleWhacker with T_max lifted.
#
# The protocol stops MoleWhacker after T_max = 20 refinement iterations, which
# on the neutrino posterior consumes only about 23 % of the top budget
# N_L = 5e5. One cell per ordering (seed 11) was re-run with the cap lifted
# (11_run_queue.jl --tmax 10000 --out out_ablation) so that the budget,
# not the cap, ends the run. This script compares the two against each other
# and against the other samplers at the same budget:
#   * the iteration log (cumulative cost, pooled-cloud ESS, efficiency,
#     number of mixture components) of the protocol cells and the long runs,
#   * the terminal quantities of the long runs: N_L used, ESS, eta = ESS/N_L,
#     pooled-cloud log Z and P(upper octant), W̄1 to the pooled MH reference,
#     wall time, and (with --fresh) the fresh-draw check of the final mixture
#     as in 72_mw_mixture_check.jl,
#   * wall-clock time per iteration from out_ablation/iter_timestamps.csv when
#     that file exists (written by a watcher while the long runs were going).
#
# While a long run is still going (no result.h5 yet) the script falls back to
# its stderr log for the iteration curve and marks the output "preliminary";
# the cumulative cost is then reconstructed from the protocol cell of the same
# seed (identical seed phase) and the mean per-iteration cost.
#
#   julia --project=. -t 8 scripts/73_tmax_study.jl [--fresh | --reuse-fresh] [--N 60000] [--finished-only]
# Output: out/tables/tmax_study.csv, tmax_iterlog.csv;
#         out/figs/nu_tmax.{pdf,png}
# =============================================================================
import Pkg
Pkg.activate(joinpath(@__DIR__, ".."))
using LinearAlgebra, Statistics, Random, Printf, CSV, DataFrames, Distributions, Dates
using CairoMakie, LaTeXStrings
using Base.Threads
# Thesis benchmark harness (module ExperimentsBase) and the thesis-final
# MoleWhacker; verbatim copies live in ../harness (see harness/PROVENANCE.md).
const HARNESS = joinpath(@__DIR__, "..", "harness", "experiments", "src", "ExperimentsBase.jl")
include(HARNESS)
using .ExperimentsBase

const OUT = joinpath(@__DIR__, "..", "out")
const ABL = joinpath(@__DIR__, "..", "out_ablation")
const RUNS = joinpath(OUT, "runs")
const TABLES = joinpath(OUT, "tables"); mkpath(TABLES)
const FIGS = joinpath(OUT, "figs"); mkpath(FIGS)
const LOGS = joinpath(OUT, "logs")
const DO_FRESH = "--fresh" in ARGS
const NFRESH = let i = findfirst(==("--N"), ARGS); i === nothing ? 60_000 : parse(Int, ARGS[i+1]) end
const BTOP = 5e5

# palette of 30_plots.jl (MH black = reference; MoleWhacker vermilion)
const NU_COLOR = Dict{Symbol,Any}(:mw => "#D55E00", :mh => "#000000", :nuts => "#56B4E9",
                                  :ns => "#009E73", :is => "#999999")
const NU_LABEL = Dict{Symbol,String}(:mw => "MoleWhacker", :mh => "MH (reference)", :nuts => "NUTS",
                                     :ns => "NS", :is => "IS")
const NU_MARKER = ALG_MARKER
ord_word(o) = o === :NO ? "normal ordering" : "inverted ordering"

# ----------------------------------------------------------------------------- loading
struct MWRun
    ordering::Symbol
    kind::Symbol                 # :protocol (T_max = 20) or :long (cap lifted)
    seed::Int
    dir::String
    mr::Union{Nothing,MethodResult}
    meta::Dict{String,Any}
    iterlog::DataFrame           # iter, cum_cost, ess, eff, n_components
    preliminary::Bool
end

function iterlog_from_meta(meta)
    il = meta["algorithm"]["tuning"]["iter_log"]
    DataFrame(iter = [Int(r["iter"]) for r in il], cum_cost = [Float64(r["cum_cost"]) for r in il],
              ess = [Float64(r["ess"]) for r in il], eff = [Float64(r["eff"]) for r in il],
              n_components = [Int(r["n_components"]) for r in il])
end

function load_finished(dir, ordering, kind)
    meta = read_metadata_json(dir)
    mr = load_method_result(dir)
    MWRun(ordering, kind, mr.seed, dir, mr, meta, iterlog_from_meta(meta), false)
end

# Preliminary iteration curve of the run that is still going, from the queue's
# stderr log. The queue runs its seeds sequentially in one process, so the log
# holds one segment per seed (the iteration counter restarts at 0); the last
# segment is the running seed.
function load_from_log(ordering, seed, proto::MWRun)
    cands = filter(f -> occursin("ablation_tmax_$(ordering)_", f) && endswith(f, ".log.err"), readdir(LOGS))
    isempty(cands) && return nothing
    path = joinpath(LOGS, sort(cands)[end])
    rx = r"Iteration (\d+): Efficiency=([0-9.eE+-]+), Effective sample size=([0-9.eE+-]+)"
    segments = Vector{NTuple{3,Float64}}[]
    for line in eachline(path)
        m = match(rx, line)
        m === nothing && continue
        t = parse(Float64, m[1])
        (isempty(segments) || t < segments[end][end][1]) && push!(segments, NTuple{3,Float64}[])
        push!(segments[end], (t, parse(Float64, m[2]), parse(Float64, m[3])))
    end
    isempty(segments) && return nothing
    seg = segments[end]
    it = Int.(first.(seg)); ef = getindex.(seg, 2); es = getindex.(seg, 3)
    # cost reconstruction: same seed → identical seed phase; per-iteration cost from the protocol cell
    pl = proto.iterlog
    c0 = pl.cum_cost[1]
    dc = (pl.cum_cost[end] - pl.cum_cost[1]) / (pl.iter[end] - pl.iter[1])
    n0 = pl.n_components[1]; dn = (pl.n_components[end] - n0) / (pl.iter[end] - pl.iter[1])
    df = DataFrame(iter = it, cum_cost = c0 .+ dc .* it, ess = es, eff = ef,
                   n_components = round.(Int, n0 .+ dn .* it))
    MWRun(ordering, :long, seed, path, nothing, Dict{String,Any}(), df, true)
end

const ABL_SEEDS = (11, 23, 41)          # order of queues/ablation_tmax_<ORD>.txt
# --finished-only: ignore the seed that is still running (no preliminary curve,
# no banner) — the thesis figure is built from finished runs only.
const FINISHED_ONLY = "--finished-only" in ARGS
# A finished cell has a non-empty result.h5. A zero-byte result.h5 is a HOLD
# marker (see out_ablation/README-HOLD.md): it makes 11_run_queue.jl skip the
# cell so that no new multi-hour run starts without approval, and it must not
# be read as a finished run here.
finished(dir) = isfile(joinpath(dir, "result.h5")) && filesize(joinpath(dir, "result.h5")) > 0

runs = MWRun[]
for ord in (:NO, :IO)
    for name in sort(readdir(RUNS))
        occursin("nu_dakami_$(ord)_mw_d11_B5e5_seed", name) || continue
        finished(joinpath(RUNS, name)) || continue
        push!(runs, load_finished(joinpath(RUNS, name), ord, :protocol))
    end
    for (k, seed) in enumerate(ABL_SEEDS)
        long_dir = joinpath(ABL, "runs", "nu_dakami_$(ord)_mw_d11_B5e5_seed$(seed)")
        if finished(long_dir)
            push!(runs, load_finished(long_dir, ord, :long))
        else
            FINISHED_ONLY && break
            # the first unfinished seed is the running one; later seeds have not started
            proto = findfirst(r -> r.ordering === ord && r.kind === :protocol && r.seed == seed, runs)
            proto === nothing && break
            r = load_from_log(ord, seed, runs[proto])
            r === nothing || (push!(runs, r); @warn "long run $(ord) seed $(seed) not finished: preliminary curve from its log")
            break
        end
    end
end
isempty(runs) && error("no MoleWhacker runs found")
const PRELIM = any(r -> r.preliminary, runs)

# ----------------------------------------------------------------------------- iteration log table
iterlog = DataFrame(ordering = String[], kind = String[], seed = Int[], preliminary = Bool[], iter = Int[],
                    cum_cost = Float64[], ess = Float64[], eff = Float64[], eta = Float64[], n_components = Int[])
for r in runs, row in eachrow(r.iterlog)
    push!(iterlog, (String(r.ordering), String(r.kind), r.seed, r.preliminary, row.iter, row.cum_cost, row.ess,
                    row.eff, row.ess / row.cum_cost, row.n_components))
end
CSV.write(joinpath(TABLES, "tmax_iterlog.csv"), iterlog)

# ----------------------------------------------------------------------------- wall time per iteration
stamps = let p = joinpath(ABL, "iter_timestamps.csv")
    isfile(p) ? CSV.read(p, DataFrame) : nothing
end

# ----------------------------------------------------------------------------- terminal quantities
cells = CSV.read(joinpath(TABLES, "cells.csv"), DataFrame)      # all protocol cells (20_aggregate.jl)

# pooled top-budget MH reference in prior-width units (as 20_aggregate.jl)
function unit_samples(mr::MethodResult, L, N, rng)
    w = isempty(mr.weights) ? ones(size(mr.samples, 2)) : mr.weights
    resample_to_equal_weight(mr.samples, w, N; rng = rng) ./ (2L)
end
w1_1d(x, y) = mean(abs.(sort(x) .- sort(y)))
w1_avg(X, Y) = mean(w1_1d(view(X, j, :), view(Y, j, :)) for j in 1:size(X, 1))
const N_EVAL = 20_000
refs = Dict{Symbol,Matrix{Float64}}()
for ord in (:NO, :IO)
    rng = MersenneTwister(2026)
    dirs = [joinpath(RUNS, n) for n in sort(readdir(RUNS)) if occursin("nu_dakami_$(ord)_mh_d11_B5e5_seed", n)]
    dirs = filter(finished, dirs)
    isempty(dirs) && continue
    parts = Matrix{Float64}[]
    for d in dirs
        mr = load_method_result(d); meta = read_metadata_json(d)
        push!(parts, unit_samples(mr, Float64(meta["problem"]["config"]["L"]), cld(N_EVAL, length(dirs)), rng))
    end
    refs[ord] = hcat(parts...)
end

# optional fresh-draw check (needs the Newtrinos posterior; as 72_mw_mixture_check.jl)
if DO_FRESH
    using BAT: bat_transform, PriorToNormal
    using DensityInterface: logdensityof
    include(joinpath(@__DIR__, "..", "src", "neutrino_problem.jl"))
end
# --reuse-fresh: take the fresh-draw columns of an earlier --fresh run from the
# cached table instead of recomputing them (re-plotting only).
const REUSE_FRESH = "--reuse-fresh" in ARGS
const FRESH_CACHE = let path = joinpath(TABLES, "tmax_study.csv"), d = Dict{Tuple{String,String,Int},NTuple{4,Float64}}()
    if REUSE_FRESH && isfile(path)
        old = CSV.read(path, DataFrame)
        for row in eachrow(old)
            isfinite(row.fresh_logZ) || continue
            d[(String(row.ordering), String(row.kind), Int(row.seed))] = (row.fresh_logZ, row.fresh_se, row.fresh_ess, row.fresh_P_upper)
        end
        @info "fresh-draw columns reused from cache" n = length(d)
    end
    d
end
function fresh_check(r::MWRun)
    key = (String(r.ordering), String(r.kind), r.seed)
    (!DO_FRESH && haskey(FRESH_CACHE, key)) && return FRESH_CACHE[key]
    (DO_FRESH && r.mr !== nothing && haskey(r.mr.extras, :mixture)) || return (NaN, NaN, NaN, NaN)
    cfg = make_config_neutrino(ordering = r.ordering)
    log_f = build_log_f(cfg)
    posterior = ExperimentsBase.posterior_measure(cfg, log_f)
    pstr, f_trafo = bat_transform(PriorToNormal(), posterior)
    mix = r.mr.extras[:mixture]
    Random.seed!(1000 + r.seed)
    Xf = [rand(mix) for _ in 1:NFRESH]
    logp = Vector{Float64}(undef, NFRESH); logq = similar(logp)
    @threads for i in 1:NFRESH
        logp[i] = logdensityof(pstr, Xf[i]); logq[i] = logpdf(mix, Xf[i])
    end
    ok = isfinite.(logp) .& isfinite.(logq)
    logw = fill(-Inf, NFRESH); logw[ok] = logp[ok] .- logq[ok]
    mx = maximum(logw); w = exp.(logw .- mx)
    logZ = mx + log(mean(w)); se = std(w) / (sqrt(length(w)) * mean(w)); ess = sum(w)^2 / sum(w .^ 2)
    finv = inv(f_trafo)
    Uf = reduce(hcat, (collect(finv(x)) for x in Xf))
    k23 = findfirst(==(:θ₂₃), cfg.names)
    s23 = sin.(to_physical_matrix(cfg, Uf)[k23, :]) .^ 2
    pup = sum((w ./ sum(w)) .* (s23 .> 0.5))
    return (logZ, se, ess, pup)
end

function pupper(r::MWRun)
    r.mr === nothing && return NaN
    pc = r.meta["problem"]["config"]
    names = Symbol.(pc["names"]); lo = Float64.(pc["lo"]); hi = Float64.(pc["hi"]); L = Float64(pc["L"])
    k = findfirst(==(:θ₂₃), names)
    s = (hi[k] - lo[k]) / (2L)
    θ = lo[k] .+ (view(r.mr.samples, k, :) .+ L) .* s
    w = isempty(r.mr.weights) ? ones(size(r.mr.samples, 2)) : r.mr.weights
    return sum((w ./ sum(w)) .* (sin.(θ) .^ 2 .> 0.5))
end

summary = DataFrame(ordering = String[], kind = String[], seed = Int[], preliminary = Bool[], T_max = Int[],
                    iterations = Int[], n_components = Int[], Nlike_used = Float64[], frac_of_budget = Float64[],
                    N_cloud = Int[], neff = Float64[], eta = Float64[], logZ = Float64[], P_upper = Float64[],
                    W1_avg = Float64[], wall_time_s = Float64[], fresh_logZ = Float64[], fresh_se = Float64[],
                    fresh_ess = Float64[], fresh_P_upper = Float64[])
for r in runs
    il = r.iterlog
    if r.mr === nothing
        push!(summary, (String(r.ordering), String(r.kind), r.seed, true, 0, il.iter[end], il.n_components[end],
                        il.cum_cost[end], il.cum_cost[end] / BTOP, 0, il.ess[end], il.ess[end] / il.cum_cost[end],
                        NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN))
        continue
    end
    mr = r.mr
    tun = r.meta["algorithm"]["tuning"]
    L = Float64(r.meta["problem"]["config"]["L"])
    rng = MersenneTwister(2026)
    W1 = haskey(refs, r.ordering) ? w1_avg(unit_samples(mr, L, size(refs[r.ordering], 2), rng), refs[r.ordering]) : NaN
    fz, fse, fess, fpup = fresh_check(r)
    push!(summary, (String(r.ordering), String(r.kind), r.seed, false, Int(tun["T_max"]), il.iter[end],
                    il.n_components[end], mr.Nlike_used, mr.Nlike_used / BTOP, size(mr.samples, 2), neff(mr),
                    neff(mr) / mr.Nlike_used, mr.logZ_estimate === missing ? NaN : mr.logZ_estimate, pupper(r),
                    W1, mr.wall_time_s, fz, fse, fess, fpup))
end
CSV.write(joinpath(TABLES, "tmax_study.csv"), summary)
show(summary; allrows = true, allcols = true); println()

# ----------------------------------------------------------------------------- figure
function fig_tmax()
    set_pub_theme!(class = :wide)
    W, _ = figure_size(:wide, :conv)
    fig = Figure(size = (W, 0.6W))
    # (a) pooled-cloud ESS against consumed evaluations; other samplers at their end points
    axa = Axis(fig[1, 1]; xlabel = L"N_L\;\;\text{consumed (likelihood equivalents)}",
               ylabel = L"N_{\mathrm{eff}}", xscale = log10, yscale = log10,
               title = "(a) effective sample size vs. cost", titlefont = :regular, titlesize = 8.5)
    standard_axis!(axa)
    # (b) cumulative efficiency against the iteration index
    axb = Axis(fig[1, 2]; xlabel = L"t\;\;\text{(refinement iteration)}", ylabel = L"\eta = N_{\mathrm{eff}} / N_L",
               yscale = log10, title = "(b) efficiency vs. iteration", titlefont = :regular, titlesize = 8.5)
    standard_axis!(axb)
    ls = Dict(:NO => :solid, :IO => :dash)
    for r in runs
        il = r.iterlog
        if r.kind === :long
            lines!(axa, il.cum_cost, il.ess; color = NU_COLOR[:mw], linewidth = 1.8, linestyle = ls[r.ordering])
            lines!(axb, il.iter, il.ess ./ il.cum_cost; color = NU_COLOR[:mw], linewidth = 1.8, linestyle = ls[r.ordering])
        else
            lines!(axa, il.cum_cost, il.ess; color = (NU_COLOR[:mw], 0.45), linewidth = 0.9, linestyle = ls[r.ordering])
            scatter!(axa, [il.cum_cost[end]], [il.ess[end]]; color = NU_COLOR[:mw], marker = NU_MARKER[:mw],
                     markersize = 8, strokecolor = :black, strokewidth = 0.4)
        end
    end
    # other samplers' protocol cells at the top budget (ESS at the evaluations they consumed)
    for alg in (:mh, :nuts, :ns, :is)
        sub = cells[(cells.alg .== String(alg)) .& (cells.B .== BTOP), :]
        isempty(sub) && continue
        scatter!(axa, sub.Nlike_used, sub.neff; color = NU_COLOR[alg], marker = NU_MARKER[alg], markersize = 6.5,
                 strokecolor = :black, strokewidth = alg === :mh ? 0.0 : 0.4)
    end
    # honest efficiency of the final mixture: ESS per fresh draw (only for finished long runs with --fresh)
    fr = summary[(summary.kind .== "long") .& .!summary.preliminary .& isfinite.(summary.fresh_ess), :]
    have_fresh = nrow(fr) > 0
    have_fresh && scatter!(axb, fr.iterations, fr.fresh_ess ./ NFRESH; marker = :star5, color = :white,
                           strokecolor = NU_COLOR[:mw], strokewidth = 1.0, markersize = 10)
    vlines!(axa, [BTOP]; color = :gray50, linewidth = 0.7, linestyle = :dot)   # the budget (see caption)
    vlines!(axb, [20]; color = :gray50, linewidth = 0.7, linestyle = :dot)
    text!(axb, 0.12, 0.03; text = "Tₘₐₓ = 20 (protocol)", fontsize = 7, align = (:left, :bottom), color = :gray40,
          space = :relative)
    axa.xticks = ([1e5, 2e5, 5e5], ["10⁵", "2×10⁵", "5×10⁵"])
    xlims!(axa, 8e4, 7e5)
    ExperimentsBase._apply_log10_yticks!(axa, vcat(iterlog.ess, cells.neff[cells.B .== BTOP]))
    ExperimentsBase._apply_log10_yticks!(axb, iterlog.eta)
    # legend (three rows; the protocol-cell marker sits at the end of each faint protocol curve)
    els = [LineElement(color = NU_COLOR[:mw], linewidth = 1.8, linestyle = :solid),
           LineElement(color = NU_COLOR[:mw], linewidth = 1.8, linestyle = :dash),
           MarkerElement(color = NU_COLOR[:mw], marker = NU_MARKER[:mw], markersize = 8, strokecolor = :black, strokewidth = 0.4)]
    lbl = ["MoleWhacker, cap lifted (NO)", "MoleWhacker, cap lifted (IO)", "MoleWhacker, Tₘₐₓ = 20 (protocol, 3 seeds)"]
    for alg in (:mh, :nuts, :ns, :is)
        push!(els, MarkerElement(color = NU_COLOR[alg], marker = NU_MARKER[alg], markersize = 6.5,
                                 strokecolor = :black, strokewidth = alg === :mh ? 0.0 : 0.4))
        push!(lbl, NU_LABEL[alg])
    end
    if have_fresh
        push!(els, MarkerElement(marker = :star5, color = :white, strokecolor = NU_COLOR[:mw], strokewidth = 1.0, markersize = 10))
        push!(lbl, "final mixture, fresh draws (efficiency per draw)")
    end
    # two columns of four rows: the longest label then fits within the figure width
    Legend(fig[2, 1:2], els, lbl; orientation = :horizontal, nbanks = 4, framevisible = false, labelsize = 7,
           padding = (0, 0, 0, 0), tellwidth = false, tellheight = true, colgap = 24, rowgap = 1)
    PRELIM && Label(fig[0, 1:2], "PRELIMINARY: long run(s) still in progress, cost reconstructed"; fontsize = 8,
                    color = :red, tellwidth = false)
    colgap!(fig.layout, 16); rowgap!(fig.layout, 4)
    return fig
end
save_pdf(fig_tmax(), PRELIM ? "nu_tmax_prelim" : "nu_tmax"; dir = FIGS)

# ----------------------------------------------------------------------------- wall time per iteration (if watched)
if stamps !== nothing && nrow(stamps) > 2
    stamps.t = eltype(stamps.time) <: DateTime ? stamps.time : DateTime.(string.(stamps.time))
    for g in groupby(stamps, :ordering)
        g = DataFrame(g)
        # the watcher keeps logging when the queue moves on to the next seed (the
        # iteration counter restarts): keep the first monotone segment only
        cut = findfirst(i -> g.iteration[i] < g.iteration[i-1], 2:nrow(g))
        cut === nothing || (g = g[1:cut, :])
        g = unique(sort(g, :iteration), :iteration)   # two watchers may have logged the same row
        nrow(g) < 3 && continue
        dt = diff(Dates.value.(g.t)) ./ 1000 ./ diff(g.iteration)   # seconds per iteration
        @info "wall time per iteration (watched window)" ordering = g.ordering[1] iter_from = g.iteration[1] iter_to = g.iteration[end] median_s = median(dt) min_s = minimum(dt) max_s = maximum(dt)
    end
end
println("TMAX-STUDY-DONE")

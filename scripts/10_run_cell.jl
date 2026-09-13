# =============================================================================
# 10_run_cell.jl — run one (algorithm, ordering, B, seed) cell of the
# neutrino-application campaign and store it in the thesis harness format.
# =============================================================================
#
# Usage (from the repository root):
#   julia --project=. -t 8 scripts/10_run_cell.jl \
#       --alg mw --ordering NO --B 5e4 --seed 11 [--exps dayabay,kamland,minos]
#       [--out out] [--force] [--tmax N   (MW ablation: lift T_max; use own --out)]
#
# Writes <out>/runs/<tag>_<alg>_d<d>_B<token>_seed<seed>/{result.h5,
# metadata.json, summary.json}. `summary.json` holds the physical-unit
# posterior summary (mean, sd, 16/50/84 % quantiles) per parameter.
import Pkg
Pkg.activate(joinpath(@__DIR__, ".."))
using Dates, Printf, Random, Statistics
# Thesis benchmark harness (module ExperimentsBase) and the thesis-final
# MoleWhacker; verbatim copies live in ../harness (see harness/PROVENANCE.md).
const HARNESS = joinpath(@__DIR__, "..", "harness", "experiments", "src", "ExperimentsBase.jl")
include(HARNESS)
using .ExperimentsBase
include(joinpath(@__DIR__, "..", "src", "neutrino_problem.jl"))

function parse_cli(args)
    o = Dict{String,Any}("alg" => nothing, "ordering" => "NO", "B" => 5e4, "seed" => 11,
        "exps" => join(NEUTRINO_DEFAULT_EXPERIMENTS, ","),
        "out" => joinpath(@__DIR__, "..", "out"), "force" => false, "tmax" => nothing)
    i = 1
    while i <= length(args)
        a = args[i]
        if a == "--alg"; o["alg"] = Symbol(args[i+1]); i += 2
        elseif a == "--ordering"; o["ordering"] = args[i+1]; i += 2
        elseif a == "--B"; o["B"] = parse(Float64, args[i+1]); i += 2
        elseif a == "--seed"; o["seed"] = parse(Int, args[i+1]); i += 2
        elseif a == "--exps"; o["exps"] = args[i+1]; i += 2
        elseif a == "--out"; o["out"] = args[i+1]; i += 2
        elseif a == "--force"; o["force"] = true; i += 1
        elseif a == "--tmax"; o["tmax"] = parse(Int, args[i+1]); i += 2
        else; @warn "unknown argument $a ignored"; i += 1
        end
    end
    o["alg"] === nothing && error("--alg required (is, mh, nuts, ns, mw)")
    return o
end

function run_cell(o)
    alg = o["alg"]; ordering = Symbol(o["ordering"]); B = o["B"]; seed = o["seed"]
    exps = String.(split(o["exps"], ","))
    cfg = make_config_neutrino(; experiments = exps, ordering = ordering)
    dir = cell_dir(o["out"], cfg.tag, alg === :nsref ? :ns : alg, cfg.d, B, seed)
    if isfile(joinpath(dir, "result.h5")) && !o["force"]
        @info "cell exists, skipping" dir
        return
    end
    mkpath(dir)
    @info "running cell" alg ordering B seed d = cfg.d exps threads = Threads.nthreads()
    log_f = build_log_f(cfg)
    counter = LikelihoodCounter(log_f)
    started = string(now(UTC))
    mr = nothing
    notes = ""
    try
        if alg === :nsref
            # Reference nested-sampling run to evidence convergence (Δlog Z < 0.5)
            # with B acting only as a generous call cap. Stored as algorithm :ns
            # under its own (large) budget token.
            mr = run_ns(cfg, B, seed; counter = counter, dlogz = 0.5)
        elseif alg === :mw && o["tmax"] !== nothing
            # Ablation only (never part of the protocol grid): MoleWhacker with
            # the iteration cap lifted, so that the budget B is the binding stop.
            # Store such cells under a separate --out root.
            mr = run_mw(cfg, B, seed; counter = counter, params = ExperimentsBase.MWParams(T_max = o["tmax"]))
        else
            mr = run_algorithm(alg, cfg, B, seed; counter = counter)
        end
    catch err
        notes = "sampler raised: $(typeof(err))"
        @error "sampler raised" exception = (err, catch_backtrace())
    end
    finished = string(now(UTC))
    alg === :nsref && (alg = :ns)
    if mr === nothing
        mr = MethodResult(algorithm = alg, problem = cfg.tag, d = cfg.d, seed = seed,
            B = Float64(B), counter = counter, wall_time_s = 0.0,
            samples = zeros(cfg.d, 1), weights = [1.0], logd = [NaN],
            extras = Dict{Symbol,Any}(:stop_reason => :error))
    end
    save_method_result(dir, mr)
    meta = cell_metadata(problem = cfg.tag, algorithm = alg, d = cfg.d, seed = seed,
        B = Float64(B), started_utc = started, finished_utc = finished,
        problem_config = Dict{String,Any}(
            "experiments" => cfg.experiments, "ordering" => String(cfg.ordering),
            "names" => String.(cfg.names), "lo" => cfg.lo, "hi" => cfg.hi,
            "gauss_mu" => cfg.gauss_mu, "gauss_sd" => cfg.gauss_sd, "L" => cfg.L),
        algorithm_tuning = Dict{String,Any}(String(k) => _safe_meta(v) for (k, v) in mr.extras),
        notes = notes)
    meta["counter"] = Dict{String,Any}("n_primal" => mr.n_primal,
        "n_grad_partials" => mr.n_grad_partials, "Nlike_used" => mr.Nlike_used,
        "wall_time_s" => mr.wall_time_s)
    write_metadata_json(dir, meta)
    # physical summary
    summ = physical_summary(cfg, mr.samples, mr.weights)
    open(joinpath(dir, "summary.json"), "w") do io
        ExperimentsBase._json_encode(io, Dict{String,Any}(
            "algorithm" => String(alg), "ordering" => String(ordering), "B" => B, "seed" => seed,
            "Nlike_used" => mr.Nlike_used, "wall_time_s" => mr.wall_time_s,
            "logZ" => mr.logZ_estimate === missing ? nothing : mr.logZ_estimate,
            "logZ_se" => mr.logZ_estimate_se === missing ? nothing : mr.logZ_estimate_se,
            "neff" => neff(mr),
            "params" => Dict{String,Any}(String(r.name) => Dict{String,Any}(
                "mean" => r.mean, "sd" => r.sd, "q16" => r.q16, "q50" => r.q50, "q84" => r.q84) for r in summ)))
    end
    @info "cell done" Nlike_used = mr.Nlike_used wall_time_s = round(mr.wall_time_s; digits = 1) neff = round(neff(mr); digits = 1) logZ = mr.logZ_estimate
    for r in summ
        println(@sprintf("   %-22s %12.6g ± %-10.4g", String(r.name), r.mean, r.sd))
    end
end

function _safe_meta(v)
    v isa Symbol && return String(v)
    (v isa Number || v isa AbstractString || v isa Bool) && return v
    v isa AbstractVector{<:Real} && return collect(v)
    v isa AbstractVector && return [_safe_meta(x) for x in v]
    v isa AbstractDict && return Dict(String(k) => _safe_meta(x) for (k, x) in v)
    v isa NamedTuple && return Dict(String(k) => _safe_meta(v[k]) for k in keys(v))
    return string(typeof(v))
end

if abspath(PROGRAM_FILE) == @__FILE__
    run_cell(parse_cli(collect(String, ARGS)))
end

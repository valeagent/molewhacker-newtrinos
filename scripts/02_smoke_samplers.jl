# Smoke test of MoleWhacker, NUTS and nested sampling on the real-data
# posterior (small budgets; plumbing only, not results).
import Pkg
Pkg.activate(joinpath(@__DIR__, ".."))
using Random, Statistics, Printf
# Thesis benchmark harness (module ExperimentsBase) and the thesis-final
# MoleWhacker; verbatim copies live in ../harness (see harness/PROVENANCE.md).
const HARNESS = joinpath(@__DIR__, "..", "harness", "experiments", "src", "ExperimentsBase.jl")
include(HARNESS)
using .ExperimentsBase
include(joinpath(@__DIR__, "..", "src", "neutrino_problem.jl"))
println("HARNESS-LOADED threads=", Threads.nthreads())

cfg = make_config_neutrino(; ordering = :NO)

function report(tag, res)
    println(@sprintf("%-5s N=%6d  cost=%9.0f  wall=%7.1f s  logZ=%s  stop=%s", tag,
        size(res.samples, 2), res.Nlike_used, res.wall_time_s,
        string(res.logZ_estimate), string(get(res.extras, :stop_reason, :na))))
    for r in physical_summary(cfg, res.samples, res.weights)
        println(@sprintf("      %-22s mean=%12.6g  sd=%10.4g  [q16 %12.6g, q84 %12.6g]",
            String(r.name), r.mean, r.sd, r.q16, r.q84))
    end
end

for (alg, B) in ((:mw, 2e4), (:nuts, 2e4), (:ns, 5e4))
    println("=== ", alg, " B=", B, " ===")
    t = @elapsed res = run_algorithm(alg, cfg, B, 11)
    report(String(alg), res)
    if alg === :mw
        il = res.extras[:iter_log]
        println("      MW iterations: ", length(il), "  final components=",
                isempty(il) ? "?" : il[end].n_components, "  eff=", isempty(il) ? "?" : il[end].eff)
    end
    println("      total ", round(t; digits = 1), " s")
end
println("SMOKE-SAMPLERS-DONE")

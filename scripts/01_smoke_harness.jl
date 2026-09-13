# Smoke test of the neutrino problem inside the thesis harness:
#   1. harness loads in the fresh environment (BAT 4.0.4 + Newtrinos main)
#   2. ConfigNeutrino builds for Daya Bay + KamLAND + MINOS, NO and IO
#   3. log_f evaluates, ForwardDiff gradient works and is counted as d
#   4. a tiny IS run and a tiny MH run go through run_algorithm
import Pkg
Pkg.activate(joinpath(@__DIR__, ".."))
using ForwardDiff, Random, Statistics
# Thesis benchmark harness (module ExperimentsBase) and the thesis-final
# MoleWhacker; verbatim copies live in ../harness (see harness/PROVENANCE.md).
const HARNESS = joinpath(@__DIR__, "..", "harness", "experiments", "src", "ExperimentsBase.jl")
include(HARNESS)
using .ExperimentsBase
include(joinpath(@__DIR__, "..", "src", "neutrino_problem.jl"))
println("HARNESS-LOADED")

for ordering in (:NO, :IO)
    cfg = make_config_neutrino(; ordering = ordering)
    println("CONFIG ", cfg.tag, " d=", cfg.d)
    for i in 1:cfg.d
        println("   ", rpad(String(cfg.names[i]), 22), " [", cfg.lo[i], ", ", cfg.hi[i], "]",
                isfinite(cfg.gauss_sd[i]) ? "  gauss(μ=$(cfg.gauss_mu[i]), σ=$(cfg.gauss_sd[i]))" : "")
    end
    log_f = build_log_f(cfg)
    counter = LikelihoodCounter(log_f)
    u0 = zeros(cfg.d)                       # centre of the box
    t = @elapsed v = counter(u0)
    println("   log_f(centre) = ", v, "  (first call ", round(t; digits = 2), " s)")
    t = @elapsed v = counter(u0)
    println("   second call ", round(1000t; digits = 2), " ms; cost=", cost(counter))
    g = ForwardDiff.gradient(counter, u0)
    println("   gradient ok, |g|=", round(sqrt(sum(abs2, g)); digits = 3),
            "  cost after gradient=", cost(counter), " (expected 2 + d = ", 2 + cfg.d, ")")
    # nominal physical point → cube → log_f
    θnom = Newtrinos.get_params(neutrino_experiments(cfg.experiments, neutrino_physics(ordering)))
    unom = from_physical(cfg, [Float64(θnom[k]) for k in cfg.names])
    println("   log_f(nominal) = ", log_f(unom))
end

cfg = make_config_neutrino(; ordering = :NO)
Random.seed!(1)
res_is = run_algorithm(:is, cfg, 300, 11)
println("IS ok: N=", size(res_is.samples, 2), " logZ=", res_is.logZ_estimate, " cost=", res_is.Nlike_used)
res_mh = run_algorithm(:mh, cfg, 3000, 11)
println("MH ok: N=", size(res_mh.samples, 2), " acc=", res_mh.extras[:chain_acc_rates], " cost=", res_mh.Nlike_used)
summ = physical_summary(cfg, res_mh.samples)
for r in summ
    println("   ", rpad(String(r.name), 22), " mean=", r.mean, " sd=", r.sd)
end
println("SMOKE-HARNESS-DONE")

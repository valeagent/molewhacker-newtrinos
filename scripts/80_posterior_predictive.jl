# =============================================================================
# 80_posterior_predictive.jl — the two "physics" chapter figures.
#
#   nu_intro          (a) vacuum survival probabilities vs L/E with the three
#                         experiments' windows; (b) the θ₂₃ octant degeneracy in
#                         the MINOS ν_μ survival probability (analytic, NuFIT 6.0
#                         central values). Own implementation of the PMNS formula.
#   nu_data_<ORD>     observed spectra of Daya Bay, KamLAND and MINOS (CC) with
#                         the posterior-predictive expectation (median and 68 %
#                         band over posterior draws) and the no-oscillation
#                         expectation; lower row: ratio to no oscillation.
#
#   julia --project=. -t 4 scripts/80_posterior_predictive.jl [--ndraw 300]
#
# Posterior draws: the pooled MoleWhacker cells at B = 5e5 (three seeds),
# resampled to equal weight. The no-oscillation expectation is the same forward
# model with all three mixing angles set to zero (survival probability one),
# nuisance parameters at the posterior median.
# =============================================================================
import Pkg
Pkg.activate(joinpath(@__DIR__, ".."))
using Random, Statistics, StatsBase, Printf, LinearAlgebra, DataFrames, CSV, Distributions
using CairoMakie, LaTeXStrings
# Thesis benchmark harness (module ExperimentsBase) and the thesis-final
# MoleWhacker; verbatim copies live in ../harness (see harness/PROVENANCE.md).
const HARNESS = joinpath(@__DIR__, "..", "harness", "experiments", "src", "ExperimentsBase.jl")
include(HARNESS)
using .ExperimentsBase
include(joinpath(@__DIR__, "..", "src", "neutrino_problem.jl"))

const OUT = joinpath(@__DIR__, "..", "out")
const RUNS = joinpath(OUT, "runs")
const FIGS = joinpath(OUT, "figs"); mkpath(FIGS)
const TABLES = joinpath(OUT, "tables"); mkpath(TABLES)
const NDRAW = let i = findfirst(==("--ndraw"), ARGS); i === nothing ? 300 : parse(Int, ARGS[i+1]) end
const MWCOL = "#D55E00"
const EXP_COLOR = Dict("Daya Bay" => "#CC79A7", "KamLAND" => "#009E73", "MINOS" => "#0072B2")

# ------------------------------------------------------------------ analytic part
function pmns(θ12, θ13, θ23, δ)
    s12, c12 = sincos(θ12); s13, c13 = sincos(θ13); s23, c23 = sincos(θ23)
    e = exp(im * δ)
    [c12*c13                  s12*c13                  s13*conj(e);
     -s12*c23-c12*s23*s13*e   c12*c23-s12*s23*s13*e    s23*c13;
     s12*s23-c12*c23*s13*e    -c12*s23-s12*c23*s13*e   c23*c13]
end

# vacuum P(α→β); L in km, E in GeV, Δm² in eV²
function posc(α, β, L, E, p; anti = false)
    U = pmns(p.θ12, p.θ13, p.θ23, p.δ)
    anti && (U = conj.(U))
    m2 = (0.0, p.dm21, p.dm31)
    abs2(sum(conj(U[α, i]) * U[β, i] * exp(-im * 2 * 1.267 * m2[i] * L / E) for i in 1:3))
end

const NUFIT = (θ12 = asin(sqrt(0.308)), θ13 = asin(sqrt(0.02215)), θ23 = asin(sqrt(0.470)),
               δ = 0.0, dm21 = 7.49e-5, dm31 = 2.513e-3)

function fig_intro()
    set_pub_theme!(class = :wide)
    W, _ = figure_size(:wide, :conv)
    fig = Figure(size = (W, 0.46W))
    # (a) survival probabilities vs L/E. Up to L/E = 3000 km/GeV the exact
    # three-flavour formula; beyond, the Δm²₃₁-driven oscillation is far faster than
    # any detector's energy resolution, so its average (sin² → 1/2) is drawn, which
    # is what KamLAND measures.
    xcut = 3000.0
    x1 = 10 .^ range(1, log10(xcut); length = 3000)
    x2 = 10 .^ range(log10(xcut), 5.5; length = 1500)
    Pe1 = [posc(1, 1, xi, 1.0, NUFIT; anti = true) for xi in x1]
    s2_13 = sin(2NUFIT.θ13)^2; c4_13 = cos(NUFIT.θ13)^4; s2_12 = sin(2NUFIT.θ12)^2
    Pe2 = [1 - 0.5s2_13 - c4_13 * s2_12 * sin(1.267 * NUFIT.dm21 * xi)^2 for xi in x2]
    Pμ1 = [posc(2, 2, xi, 1.0, NUFIT) for xi in x1]
    ax = Axis(fig[1, 1]; xscale = log10, xlabel = "L / E  [km / GeV]", ylabel = "survival probability",
              title = "(a) three-flavor vacuum oscillations", titlefont = :regular, titlesize = 8.5,
              xticks = LogTicks(1:5))
    standard_axis!(ax)
    # experiment windows (L_min/E_max, L_max/E_min) of the fitted spectra, in neutrino
    # energy: MINOS reconstructed-energy bins 1-40 GeV (the 0-1 GeV bin would reach
    # infinite L/E); Daya Bay prompt 0.7-12 MeV and KamLAND prompt 0.9-8.1 MeV, both
    # shifted by +0.78 MeV to neutrino energy; baselines EH3 1.5-1.9 km, reactors 86-829 km.
    vspan!(ax, [735 / 40], [735 / 1]; color = (EXP_COLOR["MINOS"], 0.13))
    vspan!(ax, [1.5 / 0.0128], [1.9 / 0.0015]; color = (EXP_COLOR["Daya Bay"], 0.16))
    vspan!(ax, [86 / 0.0089], [829 / 0.0017]; color = (EXP_COLOR["KamLAND"], 0.13))
    # short legend labels so that the legend fits under the flat part of the
    # curves (L/E < 200 km/GeV, where both probabilities are still above 0.5);
    # the y label already says "survival probability"
    lines!(ax, x1, Pe1; color = :black, linewidth = 1.2, label = L"\bar\nu_e\ \text{(reactor)}")
    lines!(ax, x2, Pe2; color = :black, linewidth = 1.2)
    lines!(ax, x1, Pμ1; color = :gray50, linewidth = 1.2, linestyle = :dash, label = L"\nu_\mu\ \text{(beam)}")
    vlines!(ax, [xcut]; color = :gray70, linewidth = 0.5, linestyle = :dot)
    # experiment labels in three rows above the curves (the bands overlap in L/E)
    text!(ax, 11.5, 1.34; text = "MINOS: 735 km, 1–40 GeV", fontsize = 6.5, align = (:left, :center), color = EXP_COLOR["MINOS"])
    text!(ax, 11.5, 1.23; text = "Daya Bay: 1.5–1.9 km, 1.5–12.8 MeV", fontsize = 6.5, align = (:left, :center), color = EXP_COLOR["Daya Bay"])
    text!(ax, 10^5.45, 1.12; text = "KamLAND: ~180 km, 1.7–8.9 MeV", fontsize = 6.5, align = (:right, :center), color = EXP_COLOR["KamLAND"])
    text!(ax, 3300, 0.02; text = "Δm²₃₁ term averaged →", fontsize = 6, align = (:left, :bottom), color = :gray50)
    axislegend(ax; position = :lb, framevisible = false, labelsize = 7, padding = (2, 2, 2, 2), rowgap = 0,
               patchsize = (12, 6), patchlabelgap = 3)
    ylims!(ax, 0, 1.40); xlims!(ax, 10, 10^5.5)
    # (b) octant degeneracy at MINOS
    E = range(0.5, 10; length = 800)
    ax2 = Axis(fig[1, 2]; xlabel = "neutrino energy  [GeV]", ylabel = L"P(\nu_\mu\to\nu_\mu),\ L = 735\,\mathrm{km}",
               title = "(b) the θ₂₃ octant degeneracy", titlefont = :regular, titlesize = 8.5)
    standard_axis!(ax2)
    for (s2, col, ls) in ((0.39, "#0072B2", :solid), (0.63, MWCOL, :dash))
        p = merge(NUFIT, (θ23 = asin(sqrt(s2)),))
        lines!(ax2, E, [posc(2, 2, 735.0, e, p) for e in E]; color = col, linestyle = ls, linewidth = 1.5,
               label = @sprintf("sin²θ₂₃ = %.2f", s2))
    end
    p = merge(NUFIT, (dm31 = 2.2e-3,))
    lines!(ax2, E, [posc(2, 2, 735.0, e, p) for e in E]; color = :gray55, linewidth = 1.0, linestyle = :dot,
           label = "Δm²₃₁ = 2.2 × 10⁻³ eV²")
    axislegend(ax2; position = :rb, framevisible = false, labelsize = 7, padding = (2, 2, 2, 2))
    ylims!(ax2, 0, 1.06); xlims!(ax2, 0.5, 10)
    colgap!(fig.layout, 16)
    return fig
end

# ------------------------------------------------------------ posterior predictive
struct Draws
    names::Vector{Symbol}; Θ::Matrix{Float64}
end

function load_mw_draws(ordering, N; B = "B5e5", rng = MersenneTwister(2024))
    dirs = filter(n -> startswith(n, "nu_dakami_$(ordering)_mw_") && occursin("_$(B)_", n), readdir(RUNS))
    isempty(dirs) && error("no MW cells for $ordering at $B")
    parts = Matrix{Float64}[]
    names = Symbol[]
    for name in dirs
        dir = joinpath(RUNS, name)
        meta = read_metadata_json(dir); pc = meta["problem"]["config"]
        mr = load_method_result(dir)
        names = Symbol.(pc["names"])
        w = isempty(mr.weights) ? ones(size(mr.samples, 2)) : mr.weights
        S = resample_to_equal_weight(mr.samples, w, cld(N, length(dirs)); rng = rng)
        push!(parts, to_physical_matrix(Float64.(pc["lo"]), Float64.(pc["hi"]), Float64(pc["L"]), S))
    end
    return Draws(names, hcat(parts...))
end

params_of(base, d::Draws, j) = merge(base, NamedTuple{Tuple(d.names)}(Tuple(d.Θ[:, j])))

# Expected counts per experiment for a parameter NamedTuple
function expectations(exps, θ)
    (; dayabay = mean(exps.dayabay.forward_model(θ)),
       kamland = mean(exps.kamland.forward_model(θ)),
       minos   = mean(exps.minos.forward_model(θ)).CC)
end

function ppd_summary(exps, base, d::Draws)
    n = size(d.Θ, 2)
    first = expectations(exps, params_of(base, d, 1))
    acc = (; dayabay = zeros(length(first.dayabay), n), kamland = zeros(length(first.kamland), n),
             minos = zeros(length(first.minos), n))
    Threads.@threads for j in 1:n
        e = expectations(exps, params_of(base, d, j))
        acc.dayabay[:, j] .= e.dayabay; acc.kamland[:, j] .= e.kamland; acc.minos[:, j] .= e.minos
    end
    q(M) = (lo = [quantile(M[i, :], 0.16) for i in 1:size(M, 1)], med = [median(M[i, :]) for i in 1:size(M, 1)],
            hi = [quantile(M[i, :], 0.84) for i in 1:size(M, 1)])
    return (; dayabay = q(acc.dayabay), kamland = q(acc.kamland), minos = q(acc.minos))
end

function fig_data(ordering)
    cfg = make_config_neutrino(; ordering = ordering)
    physics = neutrino_physics(ordering)
    exps = neutrino_experiments(cfg.experiments, physics)
    base = Newtrinos.get_params(exps)
    d = load_mw_draws(ordering, NDRAW)
    ppd = ppd_summary(exps, base, d)
    # posterior median parameter point (for the model variance band and the no-osc reference)
    med = NamedTuple{Tuple(d.names)}(Tuple(median(d.Θ[i, :]) for i in 1:length(d.names)))
    θmed = merge(base, med)
    θnoosc = merge(θmed, (; θ₁₂ = 0.0, θ₁₃ = 0.0, θ₂₃ = 0.0))
    noosc = expectations(exps, θnoosc)
    sdmod = (; dayabay = sqrt.(var(exps.dayabay.forward_model(θmed))),
               kamland = sqrt.(var(exps.kamland.forward_model(θmed))),
               minos = sqrt.(var(exps.minos.forward_model(θmed)).CC))
    # data and binning
    da = exps.dayabay.assets; ka = exps.kamland.assets; mi = exps.minos.assets
    mi_edges = mi.ch_data["FDCC"].bin_edges
    panels = [
        ("Daya Bay (far hall)", da.energy, da.energy_bins, da.observed, ppd.dayabay, noosc.dayabay, sdmod.dayabay,
         "prompt energy  [MeV]", "events per bin", 1.0),
        ("KamLAND", ka.Ep, ka.Ep_bins, ka.observed, ppd.kamland, noosc.kamland, sdmod.kamland,
         "prompt energy  [MeV]", "events per bin", 1.0),
        ("MINOS+ far detector (CC)", 0.5 .* (mi_edges[1:end-1] .+ mi_edges[2:end]), mi_edges,
         mi.observed.CC, ppd.minos, noosc.minos, sdmod.minos, "reco. energy  [GeV]", "events per GeV", nothing),
    ]
    set_pub_theme!(class = :wide)
    W, _ = figure_size(:wide, :conv)
    fig = Figure(size = (W, 0.66W))
    for (k, (title, x, edges, obs, pp, no, sd, xl, yl, _)) in enumerate(panels)
        bw = diff(edges)
        norm = k == 3 ? bw : ones(length(bw))           # MINOS: per GeV
        norm = k == 1 ? norm .* 1e3 : norm               # Daya Bay: thousands of events
        top = Axis(fig[1, k]; title = title, titlefont = :regular, titlesize = 8,
                   ylabel = k == 1 ? "events / 10³" : k == 3 ? "events / GeV" : "events",
                   xticklabelsvisible = false, xticksvisible = false, ylabelsize = 8)
        bot = Axis(fig[2, k]; xlabel = xl, ylabel = k == 1 ? "ratio to no osc." : "", ylabelsize = 8, xlabelsize = 8.5)
        standard_axis!(top); standard_axis!(bot)
        # step-shaped x/y for histogram-like bands and lines
        sx = repeat(edges, inner = 2)[2:end-1]
        sy(v) = repeat(v, inner = 2)
        # no-oscillation expectation
        lines!(top, sx, sy(no ./ norm); color = :gray45, linewidth = 1.0, linestyle = :dash)
        # posterior predictive: 68 % band of the expectation + median
        band!(top, sx, sy(pp.lo ./ norm), sy(pp.hi ./ norm); color = (MWCOL, 0.35))
        lines!(top, sx, sy(pp.med ./ norm); color = MWCOL, linewidth = 1.3)
        # data with model-σ error bars (Poisson for KamLAND, full covariance diag for DB / MINOS)
        scatter!(top, x, obs ./ norm; color = :black, markersize = 3.5)
        errorbars!(top, x, obs ./ norm, sd ./ norm; color = :black, linewidth = 0.7, whiskerwidth = 0)
        ylims!(top, 0, nothing)
        # ratio panel
        band!(bot, sx, sy(pp.lo ./ no), sy(pp.hi ./ no); color = (MWCOL, 0.35))
        lines!(bot, sx, sy(pp.med ./ no); color = MWCOL, linewidth = 1.3)
        hlines!(bot, [1.0]; color = :gray45, linewidth = 1.0, linestyle = :dash)
        scatter!(bot, x, obs ./ no; color = :black, markersize = 3.5)
        errorbars!(bot, x, obs ./ no, sd ./ no; color = :black, linewidth = 0.7, whiskerwidth = 0)
        xlims!(top, edges[1], edges[end]); xlims!(bot, edges[1], edges[end])
        k == 1 && ylims!(bot, 0.88, 1.06)
        k == 2 && ylims!(bot, 0.0, 1.3)
        k == 3 && ylims!(bot, 0.0, 1.4)
    end
    rowsize!(fig.layout, 1, Relative(0.55))
    leg = [MarkerElement(color = :black, marker = :circle, markersize = 4),
           [PolyElement(color = (MWCOL, 0.35)), LineElement(color = MWCOL, linewidth = 1.3)],
           LineElement(color = :gray45, linewidth = 1.0, linestyle = :dash)]
    Legend(fig[3, 1:3], leg, ["observed (± model σ)", "posterior predictive (MoleWhacker): median, 68 % band",
           "no oscillation"]; orientation = :horizontal, framevisible = false, labelsize = 6.5,
           padding = (0, 0, 0, 0), tellwidth = false, colgap = 8, patchsize = (12, 6), patchlabelgap = 3)
    rowgap!(fig.layout, 1, 4); rowgap!(fig.layout, 2, 4); colgap!(fig.layout, 14)
    # summary CSV: data, no-osc, ppd median for the appendix
    rows = DataFrame(experiment = String[], bin_center = Float64[], observed = Float64[], no_osc = Float64[],
                     ppd_lo = Float64[], ppd_med = Float64[], ppd_hi = Float64[])
    for (title, x, _, obs, pp, no, _, _, _, _) in panels, i in eachindex(x)
        push!(rows, (title, x[i], obs[i], no[i], pp.lo[i], pp.med[i], pp.hi[i]))
    end
    CSV.write(joinpath(TABLES, "posterior_predictive_$(ordering).csv"), rows)
    return fig
end

function main()
    save_pdf(fig_intro(), "nu_intro"; dir = FIGS)
    println("intro done")
    for ord in (:NO, :IO)
        save_pdf(fig_data(ord), "nu_data_$(ord)"; dir = FIGS)
        println("data figure $ord done")
    end
    println("PPD-DONE")
end

main()

# =============================================================================
# 60_primer_figures.jl — teaching figures for neutrino/PHYSICS-PRIMER.md
#   (a) analytic vacuum survival probabilities (own implementation of the
#       three-flavour formula, NuFIT 6.0 parameters);
#   (b) data vs. prediction for Daya Bay, KamLAND, MINOS at the joint best fit,
#       drawn by the Newtrinos experiment modules' own `plot` functions.
#
#   julia --project=. scripts/60_primer_figures.jl
#
# Output: out/figs/primer_*.png
# =============================================================================
import Pkg
Pkg.activate(joinpath(@__DIR__, ".."))
using CairoMakie, CSV, DataFrames, LinearAlgebra, Printf
# Thesis benchmark harness (module ExperimentsBase) and the thesis-final
# MoleWhacker; verbatim copies live in ../harness (see harness/PROVENANCE.md).
const HARNESS = joinpath(@__DIR__, "..", "harness", "experiments", "src", "ExperimentsBase.jl")
include(HARNESS)
using .ExperimentsBase
include(joinpath(@__DIR__, "..", "src", "neutrino_problem.jl"))

const OUT = joinpath(@__DIR__, "..", "out")
const FIGS = joinpath(OUT, "figs"); mkpath(FIGS)
const TABLES = joinpath(OUT, "tables")

# ---------------------------------------------------------------- (a) analytic
# PMNS matrix, standard parametrisation
function pmns(θ12, θ13, θ23, δ)
    s12, c12 = sincos(θ12); s13, c13 = sincos(θ13); s23, c23 = sincos(θ23)
    e = exp(im * δ)
    [c12*c13              s12*c13              s13*conj(e);
     -s12*c23-c12*s23*s13*e   c12*c23-s12*s23*s13*e   s23*c13;
     s12*s23-c12*c23*s13*e    -c12*s23-s12*c23*s13*e  c23*c13]
end

# vacuum oscillation probability P(α→β), L in km, E in GeV, Δm² in eV²
function posc(α, β, L, E, p; anti = false)
    U = pmns(p.θ12, p.θ13, p.θ23, p.δ)
    anti && (U = conj.(U))
    m2 = (0.0, p.dm21, p.dm31)
    amp = sum(conj(U[α, i]) * U[β, i] * exp(-im * 2 * 1.267 * m2[i] * L / E) for i in 1:3)
    abs2(amp)
end

const NUFIT = (θ12 = asin(sqrt(0.308)), θ13 = asin(sqrt(0.02215)), θ23 = asin(sqrt(0.470)),
               δ = 0.0, dm21 = 7.49e-5, dm31 = 2.513e-3)

set_theme!(theme_light()); update_theme!(fontsize = 12)

# Fig 1: survival probabilities vs L/E with the three experiments' windows
function fig_survival_LE()
    x = 10 .^ range(1, 5.5; length = 4000)          # L/E in km/GeV
    Pe = [posc(1, 1, xi, 1.0, NUFIT; anti = true) for xi in x]
    Pμ = [posc(2, 2, xi, 1.0, NUFIT) for xi in x]
    fig = Figure(size = (900, 420))
    ax = Axis(fig[1, 1]; xscale = log10, xlabel = "L / E  [km / GeV]  (= m / MeV)", ylabel = "survival probability",
              title = "Vacuum survival probabilities, NuFIT 6.0 parameters")
    # experiment windows: (L_min/E_max, L_max/E_min)
    vspan!(ax, [1.5 / 0.008], [1.9 / 0.0018]; color = (:orange, 0.18))
    vspan!(ax, [735 / 20], [735 / 0.5]; color = (:steelblue, 0.15))
    vspan!(ax, [86 / 0.008], [829 / 0.0018]; color = (:seagreen, 0.15))
    lines!(ax, x, Pe; color = :black, linewidth = 1.4, label = L"P(\bar\nu_e\to\bar\nu_e)  — reactors")
    lines!(ax, x, Pμ; color = :firebrick, linewidth = 1.4, label = L"P(\nu_\mu\to\nu_\mu)  — beam")
    text!(ax, 400, 0.08; text = "Daya Bay\n(1.5–1.9 km,\n1.8–8 MeV)", fontsize = 10, align = (:center, :bottom), color = :darkorange)
    text!(ax, 90, 0.08; text = "MINOS\n(735 km,\n0.5–20 GeV)", fontsize = 10, align = (:center, :bottom), color = :steelblue)
    text!(ax, 6e4, 0.08; text = "KamLAND\n(86–829 km,\n1.8–8 MeV)", fontsize = 10, align = (:center, :bottom), color = :seagreen)
    axislegend(ax; position = :lb, framevisible = false)
    ylims!(ax, 0, 1.05)
    save(joinpath(FIGS, "primer_survival_LE.png"), fig; px_per_unit = 2)
end

# Fig 2: MINOS-like νμ survival vs energy: octant degeneracy and Δm² shift
function fig_minos_octant()
    E = range(0.5, 10; length = 800)
    fig = Figure(size = (900, 380))
    ax1 = Axis(fig[1, 1]; xlabel = "neutrino energy  [GeV]", ylabel = L"P(\nu_\mu\to\nu_\mu)\ \text{at 735 km}",
               title = "Octant degeneracy: two θ₂₃ values, (almost) one curve")
    for (s2, col, ls) in ((0.39, :steelblue, :solid), (0.63, :firebrick, :dash))
        p = merge(NUFIT, (θ23 = asin(sqrt(s2)),))
        lines!(ax1, E, [posc(2, 2, 735.0, e, p) for e in E]; color = col, linestyle = ls, linewidth = 1.8,
               label = @sprintf("sin²θ₂₃ = %.2f", s2))
    end
    axislegend(ax1; position = :rb, framevisible = false)
    ax2 = Axis(fig[1, 2]; xlabel = "neutrino energy  [GeV]", title = "Δm²₃₁ moves the dip, θ₂₃ sets its depth")
    for (dm, col) in ((2.2e-3, :gray50), (2.5e-3, :black), (2.8e-3, :darkorange))
        p = merge(NUFIT, (dm31 = dm,))
        lines!(ax2, E, [posc(2, 2, 735.0, e, p) for e in E]; color = col, linewidth = 1.6,
               label = @sprintf("Δm²₃₁ = %.1f × 10⁻³ eV²", dm * 1e3))
    end
    axislegend(ax2; position = :rb, framevisible = false)
    linkyaxes!(ax1, ax2); ylims!(ax1, 0, 1.05)
    save(joinpath(FIGS, "primer_minos_octant.png"), fig; px_per_unit = 2)
end

# Fig 3: reactor ν̄e survival vs energy at Daya Bay and KamLAND distances
function fig_reactor()
    E = range(1.8, 8.0; length = 800) .* 1e-3         # GeV
    fig = Figure(size = (900, 380))
    ax1 = Axis(fig[1, 1]; xlabel = "antineutrino energy  [MeV]", ylabel = L"P(\bar\nu_e\to\bar\nu_e)",
               title = "Daya Bay far hall, L = 1.65 km: the θ₁₃ dip")
    for (s22, col) in ((0.06, :gray50), (0.085, :black), (0.11, :darkorange))
        p = merge(NUFIT, (θ13 = 0.5 * asin(sqrt(s22)),))
        lines!(ax1, E .* 1e3, [posc(1, 1, 1.65, e, p; anti = true) for e in E]; color = col, linewidth = 1.6,
               label = @sprintf("sin²2θ₁₃ = %.3f", s22))
    end
    ylims!(ax1, 0.85, 1.01); axislegend(ax1; position = :rb, framevisible = false)
    ax2 = Axis(fig[1, 2]; xlabel = "antineutrino energy  [MeV]", title = "KamLAND, L = 180 km: the θ₁₂ / Δm²₂₁ oscillation")
    for (dm, col) in ((7.0e-5, :gray50), (7.5e-5, :black), (8.0e-5, :darkorange))
        p = merge(NUFIT, (dm21 = dm,))
        lines!(ax2, E .* 1e3, [posc(1, 1, 180.0, e, p; anti = true) for e in E]; color = col, linewidth = 1.6,
               label = @sprintf("Δm²₂₁ = %.1f × 10⁻⁵ eV²", dm * 1e5))
    end
    ylims!(ax2, 0, 1.05); axislegend(ax2; position = :rb, framevisible = false)
    save(joinpath(FIGS, "primer_reactor.png"), fig; px_per_unit = 2)
end

fig_survival_LE(); fig_minos_octant(); fig_reactor()
println("analytic figures done")

# ---------------------------------------------------------------- (b) data vs prediction
# joint best fit (NO) from the profile-likelihood scan (row of maximum llh)
prof = CSV.read(joinpath(TABLES, "profile_NO_th23.csv"), DataFrame)
best = prof[argmax(prof.llh), :]
physics = neutrino_physics(:NO)
exps = neutrino_experiments(NEUTRINO_DEFAULT_EXPERIMENTS, physics)
params = Newtrinos.get_params(exps)
params = merge(params, (; θ₁₂ = best.prof_th12, θ₁₃ = best.prof_th13, θ₂₃ = best.value, δCP = best.prof_dcp,
                          Δm²₂₁ = best.prof_dm21, Δm²₃₁ = best.prof_dm31,
                          kamland_energy_scale = best.prof_kamland_energy_scale,
                          kamland_flux_scale = best.prof_kamland_flux_scale,
                          kamland_geonu_scale = best.prof_kamland_geonu_scale,
                          nc_norm = best.prof_nc_norm, nutau_cc_norm = best.prof_nutau_cc_norm))
@info "best-fit parameters used for the data/prediction figures" params
for (name, ex) in pairs(exps)
    fig = ex.plot(params)
    save(joinpath(FIGS, "primer_data_$(name).png"), fig; px_per_unit = 2)
    println("saved primer_data_$(name).png")
end
println("PRIMER-FIGURES-DONE")

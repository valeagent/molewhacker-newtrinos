# =============================================================================
# neutrino_problem.jl — real-data neutrino-oscillation posterior as a
# benchmark problem for the thesis harness (ExperimentsBase).
# =============================================================================
#
# Include this file AFTER `ExperimentsBase.jl` has been included (it extends
# `ExperimentsBase.build_log_f` and `ExperimentsBase._problem_symbol`).
#
# Mapping onto the harness convention
# -----------------------------------
# The harness assumes every problem is an unnormalised density `f(u)` on the
# cube `[-L, L]^d` with a uniform ("cube") prior. Newtrinos posteriors have
# a product prior over a *box* with per-parameter supports, and four of the
# eleven priors of the Daya Bay + KamLAND + MINOS problem are truncated
# normals. Both facts are absorbed exactly:
#
#   * an affine map per coordinate sends the cube coordinate u_i ∈ [-L, L]
#     to the physical coordinate θ_i ∈ [lo_i, hi_i] (the truncation
#     interval for truncated normals, the support for uniforms), so the
#     uniform cube prior IS the uniform part of the Newtrinos prior;
#   * the Gaussian factor of each truncated-normal prior is added to the
#     counted log-likelihood, i.e. it is part of `f`.
#
# Consequently  log f(u) = log L_Newtrinos(θ(u)) + Σ_k log N(θ_k; μ_k, σ_k)
# and the harness's cube-normalised evidence Z_cube relates to the Newtrinos
# evidence by a known constant that is identical for the NO and IO problems
# (same nuisance priors, equal-width Δm²₃₁ supports), so the mass-ordering
# Bayes factor is exactly Z_cube(NO) / Z_cube(IO).

using Distributions
using DensityInterface
using LaTeXStrings
using BAT
using Newtrinos
using .ExperimentsBase
import .ExperimentsBase: build_log_f, _problem_symbol

"""
    ConfigNeutrino <: ProblemConfig

Real-data three-flavour oscillation posterior built from Newtrinos.jl.

Fields
- `d`, `L`        : harness cube dimension / half-width (`L` is arbitrary;
                    all physics lives in the affine map)
- `experiments`   : Newtrinos experiment module names, e.g.
                    `["dayabay","kamland","minos"]`
- `ordering`      : `:NO` or `:IO` (mass ordering; selects the Δm²₃₁ prior)
- `names`         : free parameter names in Newtrinos prior order
- `lo`, `hi`      : physical box (prior support) per free parameter
- `gauss_mu/sd`   : Gaussian prior factor per parameter; `sd = Inf` ⇒ flat
- `fixed`         : NamedTuple of parameters held at constants (none by default)
- `tag`           : problem symbol used by the harness (`:nu_<exps>_<ordering>`)
"""
struct ConfigNeutrino <: ProblemConfig
    d::Int
    L::Float64
    experiments::Vector{String}
    ordering::Symbol
    names::Vector{Symbol}
    lo::Vector{Float64}
    hi::Vector{Float64}
    gauss_mu::Vector{Float64}
    gauss_sd::Vector{Float64}
    fixed::NamedTuple
    tag::Symbol
end

const NEUTRINO_DEFAULT_EXPERIMENTS = ["dayabay", "kamland", "minos"]

# Atmospheric experiments propagate through the Earth (layered PREM paths);
# Newtrinos only defines that propagation with matter effects (`osc.SI`).
# The thesis campaign (reactor + beam baselines) uses vacuum oscillations;
# matter effects are switched on automatically when one of these is present.
const NEUTRINO_ATMOSPHERIC_EXPERIMENTS = ("deepcore", "orca", "super_k")
needs_matter(experiments) = any(e -> e in NEUTRINO_ATMOSPHERIC_EXPERIMENTS, experiments)

# Newtrinos parameter names → thesis-style LaTeX labels / units.
const NEUTRINO_LABELS = Dict{Symbol,String}(
    :θ₁₂ => L"\theta_{12}", :θ₁₃ => L"\theta_{13}", :θ₂₃ => L"\theta_{23}",
    :δCP => L"\delta_{\mathrm{CP}}",
    :Δm²₂₁ => L"\Delta m^2_{21}\,[\mathrm{eV}^2]",
    :Δm²₃₁ => L"\Delta m^2_{31}\,[\mathrm{eV}^2]",
    :kamland_energy_scale => L"\epsilon_E^{\mathrm{KL}}",
    :kamland_flux_scale => L"\epsilon_\Phi^{\mathrm{KL}}",
    :kamland_geonu_scale => L"\epsilon_{\mathrm{geo}}^{\mathrm{KL}}",
    :nc_norm => L"n_{\mathrm{NC}}", :nutau_cc_norm => L"n_{\nu_\tau\mathrm{CC}}",
    # atmospheric flux (Barr-type) systematics, shared by the atmospheric experiments
    :atm_flux_delta_spectral_index => L"\Delta\gamma_{\mathrm{atm}}",
    :atm_flux_nuenuebar_sigma => L"\sigma_{\nu_e/\bar\nu_e}",
    :atm_flux_nuenumu_sigma => L"\sigma_{\nu_e/\nu_\mu}",
    :atm_flux_numunumubar_sigma => L"\sigma_{\nu_\mu/\bar\nu_\mu}",
    :atm_flux_updown_sigma => L"\sigma_{\mathrm{up/down}}",
    :atm_flux_uphorizonzal_sigma => L"\sigma_{\mathrm{up/hor}}",
    # IceCube DeepCore (9 y verification sample) detector systematics
    :deepcore_aeff_scale => L"\epsilon_{A_{\mathrm{eff}}}^{\mathrm{DC}}",
    :deepcore_atm_muon_scale => L"\epsilon_{\mu}^{\mathrm{DC}}",
    :deepcore_ice_absorption => L"\epsilon_{\mathrm{abs}}^{\mathrm{DC}}",
    :deepcore_ice_scattering => L"\epsilon_{\mathrm{sca}}^{\mathrm{DC}}",
    :deepcore_opt_eff_overall => L"\epsilon_{\mathrm{opt}}^{\mathrm{DC}}",
    :deepcore_rel_eff_p0 => L"p_{0}^{\mathrm{DC}}",
    :deepcore_rel_eff_p1 => L"p_{1}^{\mathrm{DC}}",
)

"""
    neutrino_physics(ordering; matter = false) -> NamedTuple

Standard three-flavour oscillations (Philipp Eller's default
`OscillationConfig`), plus the atmospheric flux, Earth model and
cross-section modules that the experiment constructors expect.
`matter = false` is vacuum propagation (the thesis campaign);
`matter = true` switches on standard matter effects (`osc.SI`), which the
Earth-crossing atmospheric experiments require.
"""
function neutrino_physics(ordering::Symbol; matter::Bool = false)
    osc_cfg = Newtrinos.osc.OscillationConfig(
        flavour = Newtrinos.osc.ThreeFlavour(ordering = ordering),
        propagation = Newtrinos.osc.Basic(),
        states = Newtrinos.osc.All(),
        interaction = matter ? Newtrinos.osc.SI() : Newtrinos.osc.Vacuum())
    osc = Newtrinos.osc.configure(osc_cfg)
    atm_flux = Newtrinos.atm_flux.configure()
    earth_layers = Newtrinos.earth_layers.configure()
    xsec = Newtrinos.xsec.configure()
    return (; osc, atm_flux, earth_layers, xsec)
end

function neutrino_experiments(experiments::Vector{String}, physics)
    pairs = (Symbol(e) => getproperty(getproperty(Newtrinos, Symbol(e)), :configure)(physics)
             for e in experiments)
    return (; pairs...)
end

# Support and Gaussian factor of a Newtrinos prior distribution.
_prior_box(p::Uniform) = (minimum(p), maximum(p), 0.0, Inf)
function _prior_box(p::Truncated)
    inner = p.untruncated
    inner isa Normal || error("ConfigNeutrino: truncated prior with non-normal base $(typeof(inner))")
    return (p.lower, p.upper, mean(inner), std(inner))
end
_prior_box(p) = error("ConfigNeutrino: unsupported prior type $(typeof(p))")

"""
    make_config_neutrino(; experiments, ordering=:NO, L=10.0) -> ConfigNeutrino
"""
function make_config_neutrino(; experiments::Vector{String} = NEUTRINO_DEFAULT_EXPERIMENTS,
                                ordering::Symbol = :NO, L::Real = 10.0)
    ordering in (:NO, :IO) || error("ordering must be :NO or :IO")
    physics = neutrino_physics(ordering; matter = needs_matter(experiments))
    exps = neutrino_experiments(experiments, physics)
    priors = Newtrinos.get_priors(exps)
    names = Symbol[]; lo = Float64[]; hi = Float64[]; mu = Float64[]; sd = Float64[]
    fixed_pairs = Pair{Symbol,Any}[]
    for (k, p) in pairs(priors)
        if p isa Distribution
            a, b, m, s = _prior_box(p)
            push!(names, k); push!(lo, a); push!(hi, b); push!(mu, m); push!(sd, s)
        else
            push!(fixed_pairs, k => p)
        end
    end
    tag = Symbol("nu_", join(first.(experiments, 2)), "_", ordering)
    return ConfigNeutrino(length(names), Float64(L), copy(experiments), ordering,
                          names, lo, hi, mu, sd, (; fixed_pairs...), tag)
end

_problem_symbol(cfg::ConfigNeutrino) = cfg.tag

# Affine cube ↔ physical maps -------------------------------------------------
@inline function to_physical(cfg::ConfigNeutrino, u::AbstractVector)
    L = cfg.L
    return ntuple(i -> cfg.lo[i] + (u[i] + L) / (2L) * (cfg.hi[i] - cfg.lo[i]), cfg.d)
end

"""
    to_physical_matrix(cfg, U::AbstractMatrix) -> Matrix

Map a d×N matrix of cube samples to physical units.
"""
to_physical_matrix(cfg::ConfigNeutrino, U::AbstractMatrix) =
    to_physical_matrix(cfg.lo, cfg.hi, cfg.L, U)

# Light version (no Newtrinos needed) for post-processing from metadata.
function to_physical_matrix(lo::AbstractVector, hi::AbstractVector, L::Real, U::AbstractMatrix)
    d = length(lo)
    Θ = Matrix{Float64}(undef, d, size(U, 2))
    @inbounds for i in 1:d
        s = (hi[i] - lo[i]) / (2L)
        for n in 1:size(U, 2)
            Θ[i, n] = lo[i] + (U[i, n] + L) * s
        end
    end
    return Θ
end

function from_physical(cfg::ConfigNeutrino, θ::AbstractVector)
    L = cfg.L
    return [(θ[i] - cfg.lo[i]) / (cfg.hi[i] - cfg.lo[i]) * 2L - L for i in 1:cfg.d]
end

"""
    log_jacobian_cube_to_physical(cfg) -> Float64

log |dθ/du| of the affine map (constant). Z_physical = Z_cube · exp(this)
· (2L)^d / ∏ (hi−lo) … i.e. the harness's cube-normalised evidence differs
from the Newtrinos evidence only by ordering-independent constants.
"""
log_jacobian_cube_to_physical(cfg::ConfigNeutrino) =
    sum(log.((cfg.hi .- cfg.lo) ./ (2cfg.L)))

"""
    build_log_f(cfg::ConfigNeutrino) -> Function

Returns `log_f(u::AbstractVector) -> Real` on the harness cube: the
Newtrinos log-likelihood at θ(u) plus the Gaussian prior factors of the
truncated-normal nuisance priors. Points outside the cube return `-Inf`.
Works for `ForwardDiff.Dual` inputs (Newtrinos is AD-transparent).
"""
function build_log_f(cfg::ConfigNeutrino)
    physics = neutrino_physics(cfg.ordering; matter = needs_matter(cfg.experiments))
    exps = neutrino_experiments(cfg.experiments, physics)
    likelihood = Newtrinos.generate_likelihood(exps)
    names = Tuple(cfg.names)
    fixed = cfg.fixed
    L = cfg.L
    gauss_idx = [i for i in 1:cfg.d if isfinite(cfg.gauss_sd[i])]
    mu = cfg.gauss_mu; sd = cfg.gauss_sd
    function log_f(u::AbstractVector)
        @inbounds for i in 1:cfg.d
            abs(u[i]) > L && return -Inf * one(eltype(u))
        end
        θvals = to_physical(cfg, u)
        θ = merge(NamedTuple{names}(θvals), fixed)
        ll = logdensityof(likelihood, θ)
        @inbounds for i in gauss_idx
            z = (θvals[i] - mu[i]) / sd[i]
            ll -= 0.5 * z * z
        end
        return ll
    end
    return log_f
end

"""
    physical_summary(cfg, samples_cube, weights) -> DataFrame-like NamedTuple

Weighted mean, sd and 16/50/84 % quantiles per parameter in physical units.
"""
function physical_summary(cfg::ConfigNeutrino, samples_cube::AbstractMatrix,
                          weights::AbstractVector = Float64[])
    Θ = to_physical_matrix(cfg, samples_cube)
    N = size(Θ, 2)
    w = isempty(weights) ? fill(1.0 / N, N) : weights ./ sum(weights)
    rows = NamedTuple[]
    for i in 1:cfg.d
        x = @view Θ[i, :]
        m = sum(w .* x)
        s = sqrt(max(sum(w .* (x .- m) .^ 2), 0.0))
        xs = collect(x)
        q = [ExperimentsBase.weighted_quantile(xs, w, p) for p in (0.16, 0.5, 0.84)]
        push!(rows, (name = cfg.names[i], mean = m, sd = s, q16 = q[1], q50 = q[2], q84 = q[3]))
    end
    return rows
end

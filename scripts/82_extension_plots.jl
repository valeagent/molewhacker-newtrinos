# =============================================================================
# 82_extension_plots.jl — figures for the extension "Towards a global fit":
# Daya Bay + KamLAND + MINOS + IceCube DeepCore, d = 24, normal ordering.
# =============================================================================
#
#   julia --project=. scripts/82_extension_plots.jl [--ext out_extension_nseed8]
#         [--ext-proto out_extension] [--B 5e5]
#
# Roots (final design, 14/15 Sep 2026): <ext>/runs holds the four-experiment
# cells that carry the results, the MoleWhacker cells with the adapted seed
# count n_seed = 8 (three seeds) and copies of the MH reference cells (placed
# there by 85_extension_analysis.ps1 so that 20_aggregate.jl finds its
# reference); <ext-proto>/runs holds the single MoleWhacker cell in the protocol
# configuration as specified (30 seeds; initialisation-dominated budget) and
# the MH cells themselves. The MH reference consists of two chains of
# B = 2.5e5 (seeds 11 and 23; cell directories ..._mh_d24_B250000_seed*) that
# are pooled wherever "MH" appears below (see mh_B). Three-experiment protocol
# cells come from out/runs (tag nu_dakami_; the chapter's campaign). Figures
# (PDF + PNG in out/figs):
#   nu_ext_plane          (sin²θ₂₃, Δm²₃₂): four-experiment MoleWhacker regions
#                         enclosing 68.3 % and 90 % of the posterior mass, MH
#                         (reference) 90 % contour, three-experiment 90 % contour,
#                         official IceCube 90 % C.L. contour and best fit
#   nu_ext_marginals_NO   six oscillation parameters, three vs four experiments
#                         (MoleWhacker and MH), published values incl. IceCube
#   nu_ext_nuisance_NO    the 18 nuisance parameters with their priors
#   nu_ext_agreement      per-parameter W1(MoleWhacker, MH) in units of the MH
#                         posterior standard deviation, all 24 parameters
#   nu_ext_iter_NO        MoleWhacker iteration log at d = 24 (thesis family)
#   nu_ext_seeds          N_eff against consumed cost at d = 24: the n_seed = 8
#                         cells (iteration logs), the protocol cell with 30
#                         seeds, and the MH reference
include(joinpath(@__DIR__, "30_plots.jl"))   # infrastructure; its main() is guarded

const EXT = let i = findfirst(==("--ext"), ARGS); i === nothing ? joinpath(@__DIR__, "..", "out_extension_nseed8") : ARGS[i+1] end
const EXT_PROTO = let i = findfirst(==("--ext-proto"), ARGS); i === nothing ? joinpath(@__DIR__, "..", "out_extension") : ARGS[i+1] end
const DC_CONTOUR = joinpath(@__DIR__, "..", "data", "icecube_deepcore_9y_sin2theta23_dm32_90pc.csv")
const EXT_TITLE = "Daya Bay + KamLAND + MINOS + IceCube DeepCore"
const C3 = :gray45          # three-experiment fit in the comparison figures
const NUIS_ROWS = 3

# labels of the DeepCore / atmospheric-flux nuisance parameters (same strings as
# NEUTRINO_LABELS in src/neutrino_problem.jl, repeated here so that this script
# does not load Newtrinos)
const LBL_EXT = merge(LBL, Dict{Symbol,LaTeXString}(
    :atm_flux_delta_spectral_index => L"\Delta\gamma_{\mathrm{atm}}",
    :atm_flux_nuenuebar_sigma => L"\sigma_{\nu_e/\bar\nu_e}",
    :atm_flux_nuenumu_sigma => L"\sigma_{\nu_e/\nu_\mu}",
    :atm_flux_numunumubar_sigma => L"\sigma_{\nu_\mu/\bar\nu_\mu}",
    :atm_flux_updown_sigma => L"\sigma_{\mathrm{up/down}}",
    :atm_flux_uphorizonzal_sigma => L"\sigma_{\mathrm{up/hor}}",
    :deepcore_aeff_scale => L"\epsilon_{A_{\mathrm{eff}}}^{\mathrm{DC}}",
    :deepcore_atm_muon_scale => L"\epsilon_{\mu}^{\mathrm{DC}}",
    :deepcore_ice_absorption => L"\epsilon_{\mathrm{abs}}^{\mathrm{DC}}",
    :deepcore_ice_scattering => L"\epsilon_{\mathrm{sca}}^{\mathrm{DC}}",
    :deepcore_opt_eff_overall => L"\epsilon_{\mathrm{opt}}^{\mathrm{DC}}",
    :deepcore_rel_eff_p0 => L"p_{0}^{\mathrm{DC}}",
    :deepcore_rel_eff_p1 => L"p_{1}^{\mathrm{DC}}"))
lbl_ext(nm) = get(LBL_EXT, nm, LaTeXString(String(nm)))

# Cells of one output tree with a given tag prefix; cells that stopped on an
# error (a sampler exception, e.g. the IO smoke test) are skipped.
function load_cells_from(runs::AbstractString, prefix::AbstractString)
    cells = Cell[]
    isdir(runs) || return cells
    for name in sort(readdir(runs))
        startswith(name, prefix) || continue
        dir = joinpath(runs, name)
        isfile(joinpath(dir, "result.h5")) || continue
        filesize(joinpath(dir, "result.h5")) == 0 && continue
        meta = read_metadata_json(dir); pc = meta["problem"]["config"]
        mr = load_method_result(dir)
        size(mr.samples, 2) <= 1 && continue
        string(get(mr.extras, :stop_reason, "")) == "error" && continue
        _f(x) = x === nothing ? Inf : Float64(x)
        push!(cells, Cell(mr.problem, Symbol(pc["ordering"]), mr.algorithm, mr.B, mr.seed, mr,
            Symbol.(pc["names"]), Float64.(pc["lo"]), Float64.(pc["hi"]), Float64(pc["L"]),
            _f.(pc["gauss_mu"]), _f.(pc["gauss_sd"])))
    end
    return cells
end

# Budget of the MH reference cells. At d = 24 the reference is two chains of
# B = 2.5e5 steps (seeds 11 and 23, separate single-threaded processes since the
# out-of-memory event of 15 Sep 2026) that are pooled everywhere below, i.e. the
# same 5e5 likelihood evaluations as one chain of B = BTOP; selecting MH cells
# with c.B == mh_B(cells) therefore picks up both chains. Falls back to BTOP
# when no MH cell has finished yet.
function mh_B(cells)
    Bs = [c.B for c in cells if c.alg === :mh]
    return isempty(Bs) ? BTOP : maximum(Bs)
end
mh_cells(cells, ordering) = [c for c in cells if c.ordering === ordering && c.alg === :mh && c.B == mh_B(cells)]

# derived observables of the atmospheric sector from a physical sample matrix
s2th23(Θ, c) = sin.(view(Θ, idx(c, :θ₂₃), :)) .^ 2
dm32(Θ, c) = view(Θ, idx(c, :Δm²₃₁), :) .- view(Θ, idx(c, :Δm²₂₁), :)

# 1-D Wasserstein distance between two equal-size samples (as in 20_aggregate.jl)
w1_1d(x::AbstractVector, y::AbstractVector) = mean(abs.(sort(x) .- sort(y)))

# MoleWhacker iteration logs (iter, cum_cost, ess, ...) of the finished cells of
# one output tree, from metadata.json (the same source 73_tmax_study.jl uses).
function mw_iterlogs(runs::AbstractString, ordering::Symbol, B)
    out = Tuple{Int,DataFrame,Dict{String,Any}}[]
    isdir(runs) || return out
    tok = ExperimentsBase._budget_token(B)
    for name in sort(readdir(runs))
        occursin("nu_dakamide_$(ordering)_mw_d24_B$(tok)_seed", name) || continue
        dir = joinpath(runs, name)
        (isfile(joinpath(dir, "result.h5")) && filesize(joinpath(dir, "result.h5")) > 0) || continue
        meta = read_metadata_json(dir)
        il = get(meta["algorithm"]["tuning"], "iter_log", nothing)
        (il === nothing || isempty(il)) && continue
        df = DataFrame(iter = [Int(r["iter"]) for r in il], cum_cost = [Float64(r["cum_cost"]) for r in il],
                       ess = [Float64(r["ess"]) for r in il], n_components = [Int(r["n_components"]) for r in il])
        push!(out, (Int(meta["seed"]), df, meta))
    end
    return out
end

function read_dc_contour()
    isfile(DC_CONTOUR) || return nothing
    t = CSV.read(DC_CONTOUR, DataFrame; header = false)
    return (x = Float64.(t[:, 1]), y = Float64.(t[:, 2]) .* 1e3)   # Δm²₃₂ in 10⁻³ eV²
end

# 2-D KDE thresholds enclosing the given mass fractions (highest-density regions)
function kde2(x, y, xl, yl)
    return kde((collect(x), collect(y)); boundary = (xl, yl), npoints = (220, 220))
end

# -----------------------------------------------------------------------------
# (sin²θ₂₃, Δm²₃₂) plane: what the atmospheric data add and how the joint fit
# compares with the IceCube result itself.
function fig_ext_plane(cells3, cells4; B = BTOP)
    rng = MersenneTwister(17)
    Θ4, c4, ne4 = pooled(cells4, :NO, :mw, B, 40_000, rng)
    Θ4 === nothing && return nothing
    Θh, ch, neh = pooled(cells4, :NO, :mh, mh_B(cells4), 40_000, rng)
    Θ3, c3, ne3 = pooled(cells3, :NO, :mw, B, 40_000, rng)
    dc = read_dc_contour()
    set_pub_theme!(class = :wide)
    W, _ = figure_size(:wide, :viz_marginal)
    fig = Figure(size = (W, 0.64W))
    ax = Axis(fig[1, 1]; xlabel = L"\sin^2\theta_{23}", ylabel = L"\Delta m^2_{32}\;[10^{-3}\,\mathrm{eV}^2]",
              xticks = WilkinsonTicks(6), yticks = WilkinsonTicks(6))
    standard_axis!(ax)
    x4, y4 = s2th23(Θ4, c4), dm32(Θ4, c4) .* 1e3
    allx = copy(x4); ally = copy(y4)
    Θ3 === nothing || (append!(allx, s2th23(Θ3, c3)); append!(ally, dm32(Θ3, c3) .* 1e3))
    dc === nothing || (append!(allx, dc.x); append!(ally, dc.y))
    qx = quantile(allx, [0.001, 0.999]); qy = quantile(ally, [0.001, 0.999])
    mx = 0.12 * (qx[2] - qx[1]); my = 0.12 * (qy[2] - qy[1])
    xl = (qx[1] - mx, qx[2] + mx); yl = (qy[1] - my, qy[2] + my)
    fracs = [0.683, 0.90]
    fill_cols = [Makie.to_color((NU_COLOR[:mw], 0.30)), Makie.to_color((NU_COLOR[:mw], 0.85))]
    cmap_fill = cgrad(fill_cols; categorical = true)
    leg_el = Any[]; leg_lb = String[]
    # three experiments first (background)
    if Θ3 !== nothing
        k3 = kde2(s2th23(Θ3, c3), dm32(Θ3, c3) .* 1e3, xl, yl)
        lv3 = hdr_levels(k3.density, [0.90])
        contour!(ax, k3.x, k3.y, k3.density; levels = lv3, color = C3, linewidth = 1.1, linestyle = :dashdot)
        push!(leg_el, LineElement(color = C3, linewidth = 1.1, linestyle = :dashdot))
        push!(leg_lb, "three experiments, 90 % region (MoleWhacker)")
    end
    # four experiments: MoleWhacker filled, MH contour
    k4 = kde2(x4, y4, xl, yl)
    lv4 = hdr_levels(k4.density, fracs)                # lv4[1] (68.3 %) > lv4[2] (90 %)
    contourf!(ax, k4.x, k4.y, k4.density; levels = [lv4[2], lv4[1], 1.001 * maximum(k4.density)], colormap = cmap_fill)
    pushfirst!(leg_el, PolyElement(color = fill_cols[1])); pushfirst!(leg_lb, "four experiments, 90 % region (MoleWhacker)")
    pushfirst!(leg_el, PolyElement(color = fill_cols[2])); pushfirst!(leg_lb, "four experiments, 68.3 % region (MoleWhacker)")
    if Θh !== nothing
        kh = kde2(s2th23(Θh, ch), dm32(Θh, ch) .* 1e3, xl, yl)
        lvh = hdr_levels(kh.density, [0.90])
        contour!(ax, kh.x, kh.y, kh.density; levels = lvh, color = NU_COLOR[:mh], linewidth = 1.0, linestyle = :dash)
        insert!(leg_el, 3, LineElement(color = NU_COLOR[:mh], linewidth = 1.0, linestyle = :dash))
        insert!(leg_lb, 3, "four experiments, 90 % region (MH, reference)")
    end
    # the IceCube result itself: official 90 % C.L. contour and the published best fit
    if dc !== nothing
        lines!(ax, dc.x, dc.y; color = :black, linewidth = 1.2, linestyle = :dot)
        push!(leg_el, LineElement(color = :black, linewidth = 1.2, linestyle = :dot))
        push!(leg_lb, "IceCube DeepCore alone, official 90 % C.L.")
    end
    pv_x, pv_y = DEEPCORE.sin2_theta23_NO, DEEPCORE.dm32_NO
    errorbars!(ax, [pv_x.value], [pv_y.value * 1e3], [pv_x.err_lo], [pv_x.err_hi]; direction = :x, whiskerwidth = 4, color = :black, linewidth = 0.9)
    errorbars!(ax, [pv_x.value], [pv_y.value * 1e3], [pv_y.err_lo * 1e3], [pv_y.err_hi * 1e3]; direction = :y, whiskerwidth = 4, color = :black, linewidth = 0.9)
    scatter!(ax, [pv_x.value], [pv_y.value * 1e3]; marker = PUB_MARK["IceCube"], color = :black, markersize = 7)
    push!(leg_el, [LineElement(color = :black, linewidth = 0.9), MarkerElement(color = :black, marker = PUB_MARK["IceCube"], markersize = 7)])
    push!(leg_lb, "IceCube published best fit (1σ)")
    vlines!(ax, [0.5]; color = :gray55, linestyle = :dot, linewidth = 0.6)   # maximal mixing
    xlims!(ax, xl...); ylims!(ax, yl...)
    Legend(fig[2, 1], leg_el, leg_lb; orientation = :horizontal, nbanks = 3, framevisible = false, labelsize = 7,
           patchsize = (14, 8), rowgap = 2, colgap = 14, tellwidth = false, tellheight = true, padding = (0, 0, 0, 0))
    Label(fig[0, 1], "$(EXT_TITLE), normal ordering, B = $(fmt_B_short(B))"; fontsize = 8.5, font = :regular, tellwidth = false)
    rowgap!(fig.layout, 4)
    return fig
end

# -----------------------------------------------------------------------------
# Six oscillation parameters, three-experiment fit (gray) against the
# four-experiment fit (MoleWhacker vermilion, MH black dashed), published values
# including IceCube where the parameter is one it measures.
function fig_ext_marginals(cells3, cells4; ordering = :NO, B = BTOP)
    rng = MersenneTwister(7)
    curves = [(:mw4, pooled(cells4, ordering, :mw, B, 40_000, rng), NU_COLOR[:mw], NU_LW[:mw], :solid, "four experiments: MoleWhacker"),
              (:mh4, pooled(cells4, ordering, :mh, mh_B(cells4), 40_000, rng), NU_COLOR[:mh], NU_LW[:mh], :dash, "four experiments: MH (reference)"),
              (:mw3, pooled(cells3, ordering, :mw, B, 40_000, rng), C3, 1.2, :solid, "three experiments: MoleWhacker")]
    any(cv -> cv[2][1] !== nothing, curves) || return nothing
    bands = published_bands(ordering; deepcore = true)
    set_pub_theme!(class = :wide)
    W, _ = figure_size(:wide, :viz_marginal)
    fig = Figure(size = (W, 0.72W))
    leg_el = Any[]; leg_lb = String[]
    for (k, nm) in enumerate(OSC)
        r, cidx = fldmod1(k, 3)
        ax = Axis(fig[r, cidx]; xlabel = LBL[nm], ylabel = k in (1, 4) ? "posterior density" : "",
                  yticklabelsvisible = false, yticksvisible = false, xticks = WilkinsonTicks(5))
        standard_axis!(ax)
        ymax = 0.0; sc = scale_of(nm); c0 = nothing; allx = Float64[]
        for (key, (Θ, c, ne), col, lw, ls, label) in curves
            Θ === nothing && continue
            c0 = c; i = idx(c, nm)
            x = Θ[i, :] .* sc; append!(allx, x)
            ymax = max(ymax, kde_line!(ax, x, c.lo[i] * sc, c.hi[i] * sc; ne = ne, color = col, linewidth = lw, linestyle = ls))
            if k == 1
                push!(leg_el, LineElement(color = col, linewidth = lw, linestyle = ls)); push!(leg_lb, label)
            end
        end
        c0 === nothing && continue
        i = idx(c0, nm)
        hlines!(ax, [1 / ((c0.hi[i] - c0.lo[i]) * sc)]; PRIOR_STYLE...)
        if k == 1
            push!(leg_el, LineElement(; PRIOR_STYLE...)); push!(leg_lb, "flat prior")
            push!(leg_el, [LineElement(color = :black, linewidth = 1.0), MarkerElement(color = :black, marker = :hexagon, markersize = 6)])
            push!(leg_lb, "published (1σ; hexagon = IceCube)")
        end
        xl, xh = zoom_range(allx, c0.lo[i] * sc, c0.hi[i] * sc)
        top = haskey(bands, nm) ? pub_overlay!(ax, bands[nm], ymax, sc; xr = (xl, xh), dy = 0.3) : 1.15ymax
        xlims!(ax, xl, xh); ylims!(ax, 0, top)
    end
    Legend(fig[3, 1:3], leg_el, leg_lb; orientation = :horizontal, nbanks = 3, framevisible = false,
           padding = (0, 0, 0, 0), labelsize = 7, colgap = 18, rowgap = 1, tellwidth = false)
    Label(fig[0, 1:3], "$(EXT_TITLE), $(ord_word(ordering)), B = $(fmt_B_short(B))";
          fontsize = 9, font = :regular, tellwidth = false)
    rowgap!(fig.layout, 6); colgap!(fig.layout, 14)
    return fig
end

# -----------------------------------------------------------------------------
# All nuisance parameters of the four-experiment fit with their priors.
function fig_ext_nuisance(cells4; ordering = :NO, algs = (:mw, :mh), B = BTOP)
    rng = MersenneTwister(5)
    pools = Dict(alg => pooled(cells4, ordering, alg, alg === :mh ? mh_B(cells4) : B, 40_000, rng) for alg in algs)
    avail = [p[2] for p in values(pools) if p[2] !== nothing]
    isempty(avail) && return nothing
    c0 = avail[1]
    nuis = [nm for nm in c0.names if !(nm in OSC)]
    ncol = cld(length(nuis), NUIS_ROWS)
    set_pub_theme!(class = :wide)
    W, _ = figure_size(:wide, :viz_marginal)
    fig = Figure(size = (W, 0.22W * NUIS_ROWS + 0.06W))
    leg_el = Any[]; leg_lb = String[]
    for (k, nm) in enumerate(nuis)
        i = idx(c0, nm)
        r, cc = fldmod1(k, ncol)
        ax = Axis(fig[r, cc]; xlabel = lbl_ext(nm), ylabel = cc == 1 ? "density" : "",
                  yticklabelsvisible = false, yticksvisible = false, xlabelsize = 8,
                  xticks = collect(range(c0.lo[i], c0.hi[i]; length = 3)), xticklabelsize = 6.5)
        standard_axis!(ax)
        ymax = 0.0
        for alg in algs
            Θ, c, ne = pools[alg]; Θ === nothing && continue
            ymax = max(ymax, kde_line!(ax, Θ[i, :], c.lo[i], c.hi[i]; ne = ne, color = NU_COLOR[alg],
                                       linewidth = NU_LW[alg], linestyle = NU_LS[alg]))
            if k == 1
                push!(leg_el, LineElement(color = NU_COLOR[alg], linewidth = NU_LW[alg], linestyle = NU_LS[alg]))
                push!(leg_lb, NU_LABEL[alg])
            end
        end
        xs = range(c0.lo[i], c0.hi[i]; length = 200)
        prior = isfinite(c0.gauss_sd[i]) ? pdf.(truncated(Normal(c0.gauss_mu[i], c0.gauss_sd[i]), c0.lo[i], c0.hi[i]), xs) :
                fill(1 / (c0.hi[i] - c0.lo[i]), length(xs))
        lines!(ax, xs, prior; PRIOR_STYLE...)
        if k == 1
            push!(leg_el, LineElement(; PRIOR_STYLE...)); push!(leg_lb, "prior")
        end
        xlims!(ax, c0.lo[i], c0.hi[i]); ylims!(ax, 0, 1.15max(ymax, maximum(prior)))
    end
    Legend(fig[NUIS_ROWS + 1, 1:ncol], leg_el, leg_lb; orientation = :horizontal, framevisible = false,
           labelsize = 7, padding = (0, 0, 0, 0), tellwidth = false)
    Label(fig[0, 1:ncol], "Nuisance parameters of the four-experiment fit, $(ord_word(ordering)), B = $(fmt_B_short(B))";
          fontsize = 8.5, font = :regular, tellwidth = false)
    rowgap!(fig.layout, 4); colgap!(fig.layout, 18)
    return fig
end

# -----------------------------------------------------------------------------
# Per-parameter agreement of MoleWhacker with the MH reference at d = 24:
# W1 between the two marginals (equal-weight draws) in units of the MH
# posterior standard deviation, one marker per MoleWhacker seed.
# display order of the 24 parameters: oscillation sector, then the nuisance
# parameters grouped by experiment (KamLAND, cross sections, atmospheric flux, DeepCore)
const EXT_ORDER = vcat(OSC, [:kamland_energy_scale, :kamland_flux_scale, :kamland_geonu_scale, :nc_norm, :nutau_cc_norm,
    :atm_flux_delta_spectral_index, :atm_flux_nuenuebar_sigma, :atm_flux_nuenumu_sigma, :atm_flux_numunumubar_sigma,
    :atm_flux_updown_sigma, :atm_flux_uphorizonzal_sigma, :deepcore_aeff_scale, :deepcore_atm_muon_scale,
    :deepcore_ice_absorption, :deepcore_ice_scattering, :deepcore_opt_eff_overall, :deepcore_rel_eff_p0, :deepcore_rel_eff_p1])
const SHORT_OSC = Dict{Symbol,LaTeXString}(:θ₁₂ => L"\theta_{12}", :θ₁₃ => L"\theta_{13}", :θ₂₃ => L"\theta_{23}",
    :δCP => L"\delta_{\mathrm{CP}}", :Δm²₂₁ => L"\Delta m^2_{21}", :Δm²₃₁ => L"\Delta m^2_{31}")
short_lbl(nm) = get(SHORT_OSC, nm, lbl_ext(nm))

# 1-2-5 ticks of a log axis covering the data range
function ticks_125(xs)
    v = filter(x -> isfinite(x) && x > 0, xs)
    isempty(v) && return ([1.0], ["1"])
    lo, hi = minimum(v) / 1.3, maximum(v) * 1.3
    cand = [m * 10.0^k for k in -4:2 for m in (1, 2, 5)]
    t = [c for c in cand if lo <= c <= hi]
    lab = [c >= 1 ? string(round(Int, c)) : rstrip(rstrip(@sprintf("%.4f", c), '0'), '.') for c in t]
    return (t, lab)
end

function fig_ext_agreement(cells4; ordering = :NO, B = BTOP)
    rng = MersenneTwister(29)
    Θh, ch, neh = pooled(cells4, ordering, :mh, mh_B(cells4), 40_000, rng)
    Θh === nothing && return nothing
    mws = [c for c in cells4 if c.ordering === ordering && c.alg === :mw && c.B == B]
    isempty(mws) && return nothing
    order = [nm for nm in EXT_ORDER if nm in ch.names]
    append!(order, [nm for nm in ch.names if !(nm in order)])
    rows = [idx(ch, nm) for nm in order]
    n = length(order)
    set_pub_theme!(class = :wide)
    W, _ = figure_size(:wide, :viz_marginal)
    fig = Figure(size = (0.72W, 0.9W))
    ax = Axis(fig[1, 1]; xlabel = L"W_1(\text{MoleWhacker},\,\text{MH}) \;/\; \sigma_{\text{MH}}",
              yticks = (1:n, [short_lbl(nm) for nm in order]), yticklabelsize = 7, xscale = log10, yreversed = true,
              yminorticksvisible = false)
    standard_axis!(ax)
    sdh = [std(view(Θh, i, :)) for i in rows]
    xs_all = Float64[]
    seedmark = Dict(11 => :circle, 23 => :rect, 41 => :utriangle)
    leg_el = Any[]; leg_lb = String[]
    # log axis: a W1 of exactly zero (a parameter pinned to one value in both
    # samples) or a zero reference sd would otherwise leave the whole axis empty
    W1FLOOR = 1e-4
    ratio(a, b, k) = (v = w1_1d(a, b) / sdh[k]; isfinite(v) ? max(v, W1FLOOR) : W1FLOOR)
    for c in sort(mws; by = c -> c.seed)
        Θm = eq_physical(c, 40_000, rng)
        w = [ratio(view(Θm, rows[k], :), view(Θh, rows[k], :), k) for k in 1:n]
        append!(xs_all, w)
        mk = get(seedmark, c.seed, :diamond)
        scatter!(ax, w, 1:n; color = NU_COLOR[:mw], marker = mk, markersize = 6.5, strokecolor = :black, strokewidth = 0.4)
        push!(leg_el, MarkerElement(color = NU_COLOR[:mw], marker = mk, markersize = 6.5, strokecolor = :black, strokewidth = 0.4))
        push!(leg_lb, "MoleWhacker seed $(c.seed)")
    end
    # MH self-noise: leave-one-chain-out where several MH chains exist (at d = 24
    # the two chains of B = 2.5e5), otherwise the W1 between the two halves of
    # the single chain
    mhs = mh_cells(cells4, ordering)
    if length(mhs) >= 2
        for c in mhs
            others = [o for o in mhs if o !== c]
            Θo = hcat((eq_physical(o, cld(40_000, length(others)), rng) for o in others)...)
            Θc = eq_physical(c, size(Θo, 2), rng)
            w = [ratio(view(Θc, rows[k], :), view(Θo, rows[k], :), k) for k in 1:n]
            append!(xs_all, w)
            scatter!(ax, w, 1:n; color = :white, marker = :rect, markersize = 5.5, strokecolor = :black, strokewidth = 0.6)
        end
        push!(leg_el, MarkerElement(color = :white, marker = :rect, markersize = 5.5, strokecolor = :black, strokewidth = 0.6))
        push!(leg_lb, length(mhs) == 2 ? "one MH chain vs the other (reference noise)" : "MH chain vs the other MH chains (reference noise)")
    else
        S = mhs[1].mr.samples; m = size(S, 2); h = m ÷ 2
        Θa = physical(mhs[1], S[:, 1:h]); Θb = physical(mhs[1], S[:, h+1:h+h])
        w = [ratio(view(Θa, rows[k], :), view(Θb, rows[k], :), k) for k in 1:n]
        append!(xs_all, w)
        scatter!(ax, w, 1:n; color = :white, marker = :rect, markersize = 5.5, strokecolor = :black, strokewidth = 0.6)
        push!(leg_el, MarkerElement(color = :white, marker = :rect, markersize = 5.5, strokecolor = :black, strokewidth = 0.6))
        push!(leg_lb, "MH first half vs second half (reference noise)")
    end
    nosc = count(nm -> nm in OSC, order)
    hlines!(ax, [nosc + 0.5]; color = :gray60, linewidth = 0.6, linestyle = :dot)   # oscillation | nuisance divider
    text!(ax, 1.0, 1.0; text = "oscillation parameters", space = :relative, align = (:right, :top), offset = (-4, -3), fontsize = 6.5, color = :gray30)
    text!(ax, 1.0, 1.0 - (nosc + 0.5) / n; text = "nuisance parameters", space = :relative, align = (:right, :top), offset = (-4, -3), fontsize = 6.5, color = :gray30)
    ax.xticks = ticks_125(xs_all)
    xlims!(ax, minimum(xs_all) / 1.6, maximum(xs_all) * 1.6)
    ylims!(ax, n + 0.7, 0.3)
    Legend(fig[2, 1], leg_el, leg_lb; orientation = :horizontal, nbanks = 2, framevisible = false, labelsize = 7,
           patchsize = (10, 8), rowgap = 1, colgap = 12, tellwidth = false, padding = (0, 0, 0, 0))
    Label(fig[0, 1], "Four-experiment fit, $(ord_word(ordering)), B = $(fmt_B_short(B))"; fontsize = 8.5, font = :regular, tellwidth = false)
    rowgap!(fig.layout, 4)
    return fig
end

# -----------------------------------------------------------------------------
# Seed count on the d = 24 target: N_eff against consumed cost. The n_seed = 8
# cells are drawn as iteration-log curves (iteration 0 = the seed mixture, then
# one point per whacking iteration; end markers on top), the protocol cell with
# 30 seeds as a single hollow marker (its log has one entry when the budget is
# exhausted before the first iteration), the MH reference as its marker.
function fig_ext_seeds(cells4; ordering = :NO, B = BTOP)
    adapted = mw_iterlogs(joinpath(EXT, "runs"), ordering, B)
    proto_logs = mw_iterlogs(joinpath(EXT_PROTO, "runs"), ordering, B)
    isempty(adapted) && isempty(proto_logs) && return nothing
    mh = mh_cells(cells4, ordering)
    set_pub_theme!(class = :wide)
    W, _ = figure_size(:wide, :viz_marginal)
    fig = Figure(size = (W, 0.58W))
    # the consumed cost spans less than one decade (2e5 .. 9e5), so it is drawn
    # linearly in units of 1e5; N_eff spans two decades and stays logarithmic
    u = 1e-5
    ax = Axis(fig[1, 1]; xlabel = L"N_L\;\text{consumed}\;[10^{5}\;\text{likelihood equivalents}]", ylabel = L"N_{\mathrm{eff}}",
              yscale = log10, xticks = WilkinsonTicks(6))
    standard_axis!(ax)
    leg_el = Any[]; leg_lb = Any[]
    ends_x = Float64[]; ends_y = Float64[]
    for (seed, df, meta) in adapted
        lines!(ax, df.cum_cost .* u, df.ess; color = NU_COLOR[:mw], linewidth = 1.6)
        scatter!(ax, df.cum_cost[1:1] .* u, df.ess[1:1]; color = :white, strokecolor = NU_COLOR[:mw], strokewidth = 1.0, markersize = 5)
        push!(ends_x, df.cum_cost[end] * u); push!(ends_y, df.ess[end])
    end
    if !isempty(adapted)
        push!(leg_el, [LineElement(color = NU_COLOR[:mw], linewidth = 1.6),
                       MarkerElement(color = NU_COLOR[:mw], marker = NU_MARKER[:mw], markersize = 8, strokecolor = :black, strokewidth = 0.4)])
        push!(leg_lb, L"MoleWhacker, $n_{\mathrm{seed}} = 8$, $T_{\max} = 20$ (three seeds)")
        push!(leg_el, MarkerElement(color = :white, marker = :circle, markersize = 5, strokecolor = NU_COLOR[:mw], strokewidth = 1.0))
        push!(leg_lb, "iteration 0 (seed mixture)")
    end
    for (seed, df, meta) in proto_logs
        scatter!(ax, df.cum_cost[end:end] .* u, df.ess[end:end]; color = :white, marker = NU_MARKER[:mw], markersize = 9,
                 strokecolor = NU_COLOR[:mw], strokewidth = 1.4)
    end
    if !isempty(proto_logs)
        push!(leg_el, MarkerElement(color = :white, marker = NU_MARKER[:mw], markersize = 9, strokecolor = NU_COLOR[:mw], strokewidth = 1.4))
        nit = maximum(nrow(df) - 1 for (_, df, _) in proto_logs)
        push!(leg_lb, LaTeXString("MoleWhacker, protocol seed count (30), \$T = $(nit)\$"))
    end
    if !isempty(mh)
        # one marker per chain; the pooled reference (sum of N_L and of N_eff) as a hollow marker when there are several
        scatter!(ax, [c.mr.Nlike_used * u for c in mh], [neff(c.mr) for c in mh]; color = NU_COLOR[:mh], marker = NU_MARKER[:mh], markersize = 6.5)
        push!(leg_el, MarkerElement(color = NU_COLOR[:mh], marker = NU_MARKER[:mh], markersize = 6.5))
        push!(leg_lb, length(mh) == 1 ? "MH (reference)" : "MH, one marker per chain (B = $(fmt_B_sci(mh_B(cells4))))")
        if length(mh) > 1
            scatter!(ax, [sum(c.mr.Nlike_used for c in mh) * u], [sum(neff(c.mr) for c in mh)]; color = :white,
                     marker = NU_MARKER[:mh], markersize = 8, strokecolor = NU_COLOR[:mh], strokewidth = 1.2)
            push!(leg_el, MarkerElement(color = :white, marker = NU_MARKER[:mh], markersize = 8, strokecolor = NU_COLOR[:mh], strokewidth = 1.2))
            push!(leg_lb, "MH, $(length(mh)) chains pooled (the reference)")
        end
    end
    isempty(ends_x) || scatter!(ax, ends_x, ends_y; color = NU_COLOR[:mw], marker = NU_MARKER[:mw], markersize = 8,
                                strokecolor = :black, strokewidth = 0.4)
    vlines!(ax, [B * u]; color = :gray50, linewidth = 0.7, linestyle = :dot)
    ytop = maximum(vcat(ends_y, [neff(c.mr) for c in mh], [df.ess[end] for (_, df, _) in proto_logs], [df.ess[1] for (_, df, _) in adapted]); init = 10.0)
    text!(ax, B * u, ytop; text = "budget", align = (:left, :top), offset = (3, 0), fontsize = 6.5, color = :gray40)
    xlims!(ax, 0, nothing)
    Legend(fig[2, 1], leg_el, leg_lb; orientation = :horizontal, nbanks = 3, framevisible = false, labelsize = 7,
           patchsize = (12, 8), rowgap = 2, colgap = 14, tellwidth = false, tellheight = true, padding = (0, 0, 0, 0))
    Label(fig[0, 1], "$(EXT_TITLE), $(ord_word(ordering)), d = 24"; fontsize = 8.5, font = :regular, tellwidth = false)
    rowgap!(fig.layout, 4)
    return fig
end

# "2.5×10⁵" for 250000.0, "5×10⁵" for 5e5
function fmt_B_sci(B)
    e = floor(Int, log10(B)); m = B / 10.0^e
    ms = isapprox(m, round(m)) ? string(round(Int, m)) : rstrip(rstrip(@sprintf("%.2f", m), '0'), '.')
    sup = Dict('0' => '⁰', '1' => '¹', '2' => '²', '3' => '³', '4' => '⁴', '5' => '⁵', '6' => '⁶', '7' => '⁷', '8' => '⁸', '9' => '⁹')
    return ms * "×10" * join(sup[ch] for ch in string(e))
end

# -----------------------------------------------------------------------------
function main_ext()
    cells3 = load_cells_from(RUNS, "nu_dakami_")
    cells4 = load_cells_from(joinpath(EXT, "runs"), "nu_dakamide_")
    @info "cells" three_experiments = length(cells3) four_experiments = length(cells4)
    for c in cells4
        @info "four-experiment cell" alg = c.alg seed = c.seed B = c.B Nlike = c.mr.Nlike_used neff = round(neff(c.mr); digits = 1) logZ = c.mr.logZ_estimate
    end
    isempty(cells4) && (println("EXT-PLOTS-DONE (no cells)"); return)
    f = fig_ext_plane(cells3, cells4); f === nothing || save_pdf(f, "nu_ext_plane"; dir = FIGS)
    f = fig_ext_marginals(cells3, cells4); f === nothing || save_pdf(f, "nu_ext_marginals_NO"; dir = FIGS)
    f = fig_ext_nuisance(cells4); f === nothing || save_pdf(f, "nu_ext_nuisance_NO"; dir = FIGS)
    f = fig_ext_agreement(cells4); f === nothing || save_pdf(f, "nu_ext_agreement"; dir = FIGS)
    mw = [c for c in cells4 if c.ordering === :NO && c.alg === :mw && c.B == BTOP && c.seed == 11]
    if !isempty(mw)
        try
            save_pdf(fig_iter_mw(mw[1].mr), "nu_ext_iter_NO"; dir = FIGS)
        catch err
            @warn "iteration-log figure skipped" exception = err
        end
    end
    f = fig_ext_seeds(cells4); f === nothing || save_pdf(f, "nu_ext_seeds"; dir = FIGS)
    println("EXT-PLOTS-DONE")
end

if abspath(PROGRAM_FILE) == @__FILE__
    main_ext()
end

# =============================================================================
# 30_plots.jl — chapter figures for the neutrino application.
# =============================================================================
#
#   julia --project=. scripts/30_plots.jl [--out out] [--B 5e5]
#
# Figures (PDF + PNG in <out>/figs):
#   nu_marginals_<ORD>   1-D posteriors of the six oscillation parameters, all
#                        samplers at budget B, with published values overlaid
#   nu_corner_<ORD>      corner plot of the five measured oscillation
#                        parameters, MoleWhacker vs MH
#   nu_octant            sin²θ₂₃ posterior with octant shading, NO and IO panels,
#                        P(upper octant) per sampler printed in the panel
#   nu_nuisance_<ORD>    the five nuisance parameters with their priors
#   nu_mw_iter_<ORD>     MoleWhacker iteration log (thesis figure family)
#   nu_agreement         W̄1 to the pooled-MH reference vs budget
#   nu_evidence          log Z by method and ordering
import Pkg
Pkg.activate(joinpath(@__DIR__, ".."))
using Random, Statistics, StatsBase, Printf, DataFrames, CSV, JLD2, Distributions
using CairoMakie, LaTeXStrings, KernelDensity
# Thesis benchmark harness (module ExperimentsBase) and the thesis-final
# MoleWhacker; verbatim copies live in ../harness (see harness/PROVENANCE.md).
const HARNESS = joinpath(@__DIR__, "..", "harness", "experiments", "src", "ExperimentsBase.jl")
include(HARNESS)
using .ExperimentsBase
include(joinpath(@__DIR__, "..", "src", "published_values.jl"))

const OUT = let i = findfirst(==("--out"), ARGS); i === nothing ? joinpath(@__DIR__, "..", "out") : ARGS[i+1] end
const BTOP = let i = findfirst(==("--B"), ARGS); i === nothing ? 5e5 : parse(Float64, ARGS[i+1]) end
const RUNS = joinpath(OUT, "runs")
const FIGS = joinpath(OUT, "figs")
mkpath(FIGS)
const OSC = [:θ₁₂, :θ₁₃, :θ₂₃, :δCP, :Δm²₂₁, :Δm²₃₁]
const OSC_MEASURED = [:θ₁₂, :θ₁₃, :θ₂₃, :Δm²₂₁, :Δm²₃₁]
const LBL = Dict{Symbol,LaTeXString}(
    :θ₁₂ => L"\theta_{12}", :θ₁₃ => L"\theta_{13}", :θ₂₃ => L"\theta_{23}",
    :δCP => L"\delta_{\mathrm{CP}}",
    :Δm²₂₁ => L"\Delta m^2_{21}\;[10^{-5}\,\mathrm{eV}^2]",
    :Δm²₃₁ => L"\Delta m^2_{31}\;[10^{-3}\,\mathrm{eV}^2]",
    :kamland_energy_scale => L"\epsilon_E^{\mathrm{KL}}",
    :kamland_flux_scale => L"\epsilon_{\Phi}^{\mathrm{KL}}",
    :kamland_geonu_scale => L"\epsilon_{\mathrm{geo}}^{\mathrm{KL}}",
    :nc_norm => L"n_{\mathrm{NC}}", :nutau_cc_norm => L"n_{\nu_\tau\,\mathrm{CC}}")
const SCALE = Dict{Symbol,Float64}(:Δm²₂₁ => 1e5, :Δm²₃₁ => 1e3)   # display scaling
scale_of(nm) = get(SCALE, nm, 1.0)
const PUB_COLORS = Dict("Daya Bay" => :black, "KamLAND" => :black, "MINOS+" => :black, "IceCube" => :black, "NuFIT 6.0" => :gray40)
const PUB_MARK = Dict("Daya Bay" => :diamond, "KamLAND" => :rect, "MINOS+" => :utriangle, "IceCube" => :hexagon, "NuFIT 6.0" => :circle)

# Chapter palette. Identical to the thesis palette (Okabe–Ito) for MoleWhacker,
# NUTS, NS and IS. MH is the *reference* sampler of this chapter (its pooled
# chains define the agreement metric and anchor the evidence reference) and is
# drawn in black: the thesis orange (#E69F00) is not separable from
# MoleWhacker's vermilion (#D55E00) when the two curves lie on top of each
# other, which in this chapter they do by construction.
const NU_COLOR = Dict{Symbol,Any}(:mw => "#D55E00", :mh => "#000000", :nuts => "#56B4E9",
                                  :ns => "#009E73", :is => "#999999")
const NU_LS = Dict{Symbol,Any}(:mw => :solid, :mh => :dash, :nuts => :solid, :ns => :dashdot, :is => :dot)
const NU_LW = Dict{Symbol,Float64}(:mw => 1.8, :mh => 1.1, :nuts => 1.1, :ns => 1.1, :is => 1.0)
const NU_LABEL = Dict{Symbol,String}(:mw => "MoleWhacker", :mh => "MH (reference)", :nuts => "NUTS",
                                     :ns => "NS", :is => "IS")
const NU_MARKER = ALG_MARKER
const PRIOR_STYLE = (; color = (:gray45, 0.9), linewidth = 0.8, linestyle = :dot)
ord_word(ordering) = ordering === :NO ? "normal ordering" : "inverted ordering"

struct Cell
    tag::Symbol; ordering::Symbol; alg::Symbol; B::Float64; seed::Int
    mr::MethodResult; names::Vector{Symbol}; lo::Vector{Float64}; hi::Vector{Float64}; L::Float64
    gauss_mu::Vector{Float64}; gauss_sd::Vector{Float64}
end

function load_cells()
    cells = Cell[]
    for name in sort(readdir(RUNS))
        startswith(name, "nu_dakami_") || continue     # main problem only (no side studies)
        dir = joinpath(RUNS, name)
        isfile(joinpath(dir, "result.h5")) || continue
        meta = read_metadata_json(dir); pc = meta["problem"]["config"]
        mr = load_method_result(dir)
        size(mr.samples, 2) <= 1 && continue
        # JSON has no Inf: the harness writes non-finite floats as null
        _f(x) = x === nothing ? Inf : Float64(x)
        push!(cells, Cell(mr.problem, Symbol(pc["ordering"]), mr.algorithm, mr.B, mr.seed, mr,
            Symbol.(pc["names"]), Float64.(pc["lo"]), Float64.(pc["hi"]), Float64(pc["L"]),
            _f.(pc["gauss_mu"]), _f.(pc["gauss_sd"])))
    end
    return cells
end

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

# Equal-weight physical samples (N draws) for KDEs / corner plots.
function eq_physical(c::Cell, N::Int, rng)
    w = isempty(c.mr.weights) ? ones(size(c.mr.samples, 2)) : c.mr.weights
    physical(c, resample_to_equal_weight(c.mr.samples, w, N; rng = rng))
end

# Pool the same (ordering, alg, B) across seeds. Returns (Θ, first cell, summed ESS);
# the ESS (not the resampled count) sets the KDE bandwidth.
function pooled(cells, ordering, alg, B, N, rng)
    sel = [c for c in cells if c.ordering === ordering && c.alg === alg && c.B == B]
    isempty(sel) && return nothing, nothing, 0.0
    Ns = cld(N, length(sel))
    ne = sum(neff(c.mr) for c in sel)
    return hcat((eq_physical(c, Ns, rng) for c in sel)...), sel[1], ne
end

idx(c::Cell, nm::Symbol) = findfirst(==(nm), c.names)

# Silverman bandwidth evaluated at the effective (not resampled) sample size.
function bw_silverman(x, ne)
    s = min(std(x), iqr(x) / 1.34)
    s <= 0 && (s = std(x))
    return 0.9 * s * max(ne, 10.0)^(-0.2)
end

function kde_line!(ax, x::AbstractVector, lo, hi; ne = length(x), kw...)
    k = kde(x; boundary = (lo, hi), npoints = 512, bandwidth = bw_silverman(x, ne))
    lines!(ax, k.x, k.density; kw...)
    return maximum(k.density)
end

# Zoomed x-range: the pooled 0.05 %–99.95 % quantile range with a margin,
# clipped to the prior box (sharply measured parameters would otherwise be
# unreadable slivers inside their prior boxes).
function zoom_range(xs::AbstractVector, lo, hi; margin = 0.25)
    q = quantile(xs, (0.0005, 0.9995))
    w = q[2] - q[1]
    return max(lo, q[1] - margin * w), min(hi, q[2] + margin * w)
end

# Published values as points with error bars stacked at the top of the panel;
# labels sit to the right of the error bar so stacked entries never overlap.
# "label: value ± err" (or "value (+hi / −lo)") for the published intervals when
# the numbers are wanted next to the bars (octant figures); `digits` from the size
# of the smaller error so that 0.43 (+0.20/−0.04) and 0.470 (+0.017/−0.013) both read naturally
function pub_text(label, pv, sc)
    v, lo, hi = pv.value * sc, pv.err_lo * sc, pv.err_hi * sc
    emax, emin = max(lo, hi), min(lo, hi); emax <= 0 && return label
    # two significant digits of the larger error, one fewer when that leaves a
    # trailing zero and the smaller error survives it (0.43 +0.20/-0.04, 0.470
    # +0.017/-0.013, 0.51 ± 0.05)
    digits = 1 - floor(Int, log10(emax))
    if round(Int, emax * 10.0^digits) % 10 == 0 && emin * 10.0^(digits - 1) >= 1
        digits -= 1
    end
    digits = clamp(digits, 1, 4)
    f(x) = @sprintf("%.*f", digits, x)
    return isapprox(lo, hi; rtol = 0.05) ? "$(label): $(f(v)) ± $(f(lo))" : "$(label): $(f(v)) (+$(f(hi)) / −$(f(lo)))"
end

function pub_overlay!(ax, bands, ymax, sc; dy = 0.16, fontsize = 6.5, xr = nothing, values = false)
    n = length(bands)
    values && (dy = max(dy, 0.35))          # room for a label line above each bar without touching the bar of the next row
    for (k, (label0, pv)) in enumerate(bands)
        label = values ? pub_text(label0, pv, sc) : label0
        y = ymax * (1.10 + dy * (n - k))
        x = pv.value * sc
        if values
            # the value strings are long: always centred above the bar
            errorbars!(ax, [x], [y], [pv.err_lo * sc], [pv.err_hi * sc]; direction = :x, whiskerwidth = 4,
                       color = PUB_COLORS[label0], linewidth = 1.0)
            scatter!(ax, [x], [y]; marker = PUB_MARK[label0], color = PUB_COLORS[label0], markersize = 6)
            text!(ax, x, y; text = label, align = (:center, :bottom), offset = (0, 3), fontsize = fontsize, color = PUB_COLORS[label0])
            continue
        end
        errorbars!(ax, [x], [y], [pv.err_lo * sc], [pv.err_hi * sc]; direction = :x, whiskerwidth = 4,
                   color = PUB_COLORS[label0], linewidth = 1.0)
        scatter!(ax, [x], [y]; marker = PUB_MARK[label0], color = PUB_COLORS[label0], markersize = 6)
        # label on the side of the bar with more room; if the bar fills the
        # panel (wide published intervals) the label goes on top of the bar
        xl_, xh_ = x - pv.err_lo * sc, x + pv.err_hi * sc
        if xr === nothing
            text!(ax, xh_, y; text = label, align = (:left, :center), offset = (4, 0),
                  fontsize = fontsize, color = PUB_COLORS[label0])
        else
            span = xr[2] - xr[1]
            room_r, room_l = xr[2] - xh_, xl_ - xr[1]
            if max(room_r, room_l) < 0.22span
                text!(ax, x, y; text = label, align = (:center, :bottom), offset = (0, 3),
                      fontsize = fontsize, color = PUB_COLORS[label0])
            elseif room_r >= room_l
                text!(ax, xh_, y; text = label, align = (:left, :center), offset = (4, 0),
                      fontsize = fontsize, color = PUB_COLORS[label0])
            else
                text!(ax, xl_, y; text = label, align = (:right, :center), offset = (-4, 0),
                      fontsize = fontsize, color = PUB_COLORS[label0])
            end
        end
    end
    return ymax * (1.10 + dy * n + 0.10)
end

# -----------------------------------------------------------------------------
function fig_marginals(cells, ordering; algs = (:mw, :mh, :nuts, :ns), B = BTOP)
    set_pub_theme!(class = :wide)
    W, _ = figure_size(:wide, :viz_marginal)
    fig = Figure(size = (W, 0.72W))
    rng = MersenneTwister(7)
    bands = published_bands(ordering)
    pools = Dict(alg => pooled(cells, ordering, alg, B, 40_000, rng) for alg in algs)
    any(p -> p[1] !== nothing, values(pools)) || return nothing
    leg_el = []; leg_lb = String[]
    for (k, nm) in enumerate(OSC)
        r, cidx = fldmod1(k, 3)
        ax = Axis(fig[r, cidx]; xlabel = LBL[nm], ylabel = k in (1, 4) ? "posterior density" : "",
                  yticklabelsvisible = false, yticksvisible = false, xticks = WilkinsonTicks(5))
        standard_axis!(ax)
        ymax = 0.0
        sc = scale_of(nm)
        c0 = nothing
        allx = Float64[]
        for alg in algs
            Θ, c, ne = pools[alg]
            Θ === nothing && continue
            c0 = c
            i = idx(c, nm)
            x = Θ[i, :] .* sc
            append!(allx, x)
            ln = kde_line!(ax, x, c.lo[i] * sc, c.hi[i] * sc; ne = ne,
                color = NU_COLOR[alg], linewidth = NU_LW[alg], linestyle = NU_LS[alg], label = NU_LABEL[alg])
            ymax = max(ymax, ln)
            if k == 1
                push!(leg_el, LineElement(color = NU_COLOR[alg], linewidth = NU_LW[alg], linestyle = NU_LS[alg]))
                push!(leg_lb, NU_LABEL[alg])
            end
        end
        c0 === nothing && continue
        i = idx(c0, nm)
        # prior (flat) as a thin grey line
        hlines!(ax, [1 / ((c0.hi[i] - c0.lo[i]) * sc)]; PRIOR_STYLE...)
        if k == 1
            push!(leg_el, LineElement(; PRIOR_STYLE...)); push!(leg_lb, "flat prior")
            push!(leg_el, [LineElement(color = :black, linewidth = 1.0), MarkerElement(color = :black, marker = :diamond, markersize = 6)])
            push!(leg_lb, "published (1σ)")
        end
        xl, xh = zoom_range(allx, c0.lo[i] * sc, c0.hi[i] * sc)
        top = haskey(bands, nm) ? pub_overlay!(ax, bands[nm], ymax, sc; xr = (xl, xh)) : 1.15ymax
        xlims!(ax, xl, xh)
        ylims!(ax, 0, top)
    end
    Legend(fig[3, 1:3], leg_el, leg_lb; orientation = :horizontal, nbanks = 2, framevisible = false,
           padding = (0, 0, 0, 0), labelsize = 7, colgap = 14, rowgap = 1, tellwidth = false)
    Label(fig[0, 1:3], "Daya Bay + KamLAND + MINOS, $(ord_word(ordering)), B = $(fmt_B_short(B))";
          fontsize = 9, font = :regular, tellwidth = false)
    rowgap!(fig.layout, 6); colgap!(fig.layout, 14)
    return fig
end

# -----------------------------------------------------------------------------
# Density thresholds of a gridded 2-D KDE that enclose the given fractions of
# the total mass (highest-density regions).
function hdr_levels(z::AbstractMatrix, fracs)
    zs = sort(vec(z); rev = true)
    cs = cumsum(zs) ./ sum(zs)
    return [zs[something(findfirst(>=(f), cs), length(zs))] for f in fracs]
end

# Native corner plot (replaces the earlier PairPlots version, whose filled
# contours dropped outer rings that touched the panel edge): MoleWhacker as
# filled 68.3 % / 95.4 % highest-density regions, MH as black contours at the
# same levels, KDE marginals on the diagonal. Tick labels only on the outer
# row and column, upright, three per axis.
function fig_corner(cells, ordering; B = BTOP)
    rng = MersenneTwister(11)
    Θmw, cmw, nemw = pooled(cells, ordering, :mw, B, 30_000, rng)
    Θmh, cmh, nemh = pooled(cells, ordering, :mh, B, 30_000, rng)
    (Θmw === nothing || Θmh === nothing) && return nothing
    set_pub_theme!(class = :wide)
    W, _ = figure_size(:wide, :tri)
    short = Dict(:θ₁₂ => L"\theta_{12}", :θ₁₃ => L"\theta_{13}", :θ₂₃ => L"\theta_{23}",
                 :Δm²₂₁ => L"\Delta m^2_{21}", :Δm²₃₁ => L"\Delta m^2_{31}")
    nc = length(OSC_MEASURED)
    col(Θ, c, nm) = view(Θ, idx(c, nm), :) .* scale_of(nm)
    # per-parameter display range: pooled 0.05 %–99.95 % quantiles of both samplers, 6 % margin, clipped to the box
    lims = Dict{Symbol,Tuple{Float64,Float64}}()
    for nm in OSC_MEASURED
        x = vcat(col(Θmw, cmw, nm), col(Θmh, cmh, nm))
        q = quantile(x, [0.0005, 0.9995]); m = 0.06 * (q[2] - q[1])
        k = idx(cmw, nm); lo, hi = extrema((cmw.lo[k], cmw.hi[k]) .* scale_of(nm))
        lims[nm] = (max(lo, q[1] - m), min(hi, q[2] + m))
    end
    fracs = [0.683, 0.954]
    # 95.4 % band light, 68.3 % core solid; categorical gradient so each band gets exactly its colour
    cmw_fill = [Makie.to_color((NU_COLOR[:mw], 0.35)), Makie.to_color((NU_COLOR[:mw], 0.9))]
    cmap_fill = cgrad(cmw_fill; categorical = true)
    fig = Figure(size = (W, W))
    ticks = WilkinsonTicks(3; k_min = 2, k_max = 3)
    for i in 1:nc, j in 1:i
        ni, nj = OSC_MEASURED[i], OSC_MEASURED[j]
        ax = Axis(fig[i, j]; xticks = ticks, yticks = ticks, xticklabelsize = 6.5, yticklabelsize = 6.5,
                  xlabelsize = 9, ylabelsize = 9, xminorticksvisible = false, yminorticksvisible = false)
        standard_axis!(ax)
        i < nc && (ax.xticklabelsvisible = false)
        j > 1 && (ax.yticklabelsvisible = false)
        i == nc && (ax.xlabel = short[nj])
        (j == 1 && i > 1) && (ax.ylabel = short[ni])
        xl = lims[nj]
        if i == j
            ax.yticklabelsvisible = false; ax.yticksvisible = false
            ax.title = short[ni]; ax.titlesize = 9; ax.titlegap = 2      # the parameter of the diagonal panel
            ymax = 0.0
            for (Θ, c, ne, alg) in ((Θmw, cmw, nemw, :mw), (Θmh, cmh, nemh, :mh))
                ymax = max(ymax, kde_line!(ax, col(Θ, c, ni), xl[1], xl[2]; ne = ne, color = NU_COLOR[alg],
                                           linewidth = NU_LW[alg], linestyle = NU_LS[alg]))
            end
            xlims!(ax, xl...); ylims!(ax, 0, 1.08 * ymax)
        else
            yl = lims[ni]
            for (Θ, c, alg) in ((Θmw, cmw, :mw), (Θmh, cmh, :mh))
                x = col(Θ, c, nj); y = col(Θ, c, ni)
                k = kde((collect(x), collect(y)); boundary = (xl, yl), npoints = (200, 200))
                lv = hdr_levels(k.density, fracs)          # lv[1] = 68.3 % threshold > lv[2] = 95.4 % threshold
                if alg === :mw
                    contourf!(ax, k.x, k.y, k.density; levels = [lv[2], lv[1], 1.001 * maximum(k.density)],
                              colormap = cmap_fill)
                else
                    contour!(ax, k.x, k.y, k.density; levels = [lv[2], lv[1]], color = NU_COLOR[:mh], linewidth = 0.9)
                end
            end
            xlims!(ax, xl...); ylims!(ax, yl...)
        end
    end
    leg_el = [PolyElement(color = cmw_fill[2]), PolyElement(color = cmw_fill[1]),
              LineElement(color = NU_COLOR[:mh], linewidth = 0.9),
              LineElement(color = NU_COLOR[:mw], linewidth = NU_LW[:mw]),
              LineElement(color = NU_COLOR[:mh], linewidth = NU_LW[:mh], linestyle = NU_LS[:mh])]
    leg_lb = ["MoleWhacker, 68.3 % region", "MoleWhacker, 95.4 % region", "MH (reference), 68.3 % and 95.4 %",
              "MoleWhacker marginal", "MH (reference) marginal"]
    Legend(fig[1:2, 3:nc], leg_el, leg_lb; framevisible = false, labelsize = 7.5, patchsize = (14, 8),
           tellwidth = false, tellheight = false, halign = :right, valign = :top, rowgap = 2)
    Label(fig[0, 1:nc], "$(uppercasefirst(ord_word(ordering))), B = $(fmt_B_short(B)): " *
                        "regions enclosing 68.3 % and 95.4 % of the posterior mass\n" *
                        "(angles in rad, Δm²₂₁ in 10⁻⁵ eV², Δm²₃₁ in 10⁻³ eV²; 3×10⁴ draws per sampler, three seeds pooled)",
          fontsize = 7.5, font = :regular, tellwidth = false, justification = :center)
    colgap!(fig.layout, 4); rowgap!(fig.layout, 4)
    return fig
end

# -----------------------------------------------------------------------------
# MoleWhacker iteration log as two panels side by side (the harness's fig_iter_mw
# stacks them, which is too tall for the text width of the thesis): (a) the
# running efficiency N_eff / N_L of the accumulated population after each
# whacking iteration, (b) the number of mixture components. Same content as the
# harness figure of the thesis family.
function fig_iter_mw_wide(mr; title = "")
    il = get(mr.extras, :iter_log, NamedTuple[])
    iters = [Float64(e.iter) for e in il]
    ess = [Float64(e.ess) for e in il]
    ncomp = [Float64(e.n_components) for e in il]
    cum = [haskey(e, :cum_cost) ? Float64(e.cum_cost) : NaN for e in il]
    eta = ess ./ max.(cum, 1.0)
    set_pub_theme!(class = :wide)
    W, _ = figure_size(:wide, :conv)
    fig = Figure(size = (W, 0.42W))
    ok = (eta .> 0) .& isfinite.(eta)
    # 1-3-10 ticks over the data range, labelled 10⁻³, 3×10⁻³, ...
    sup = Dict('-' => '⁻', '0' => '⁰', '1' => '¹', '2' => '²', '3' => '³', '4' => '⁴', '5' => '⁵', '6' => '⁶', '7' => '⁷', '8' => '⁸', '9' => '⁹')
    lo, hi = extrema(eta[ok])
    tv = [m * 10.0^k for k in floor(Int, log10(lo)):ceil(Int, log10(hi)) for m in (1, 3) if lo / 1.05 <= m * 10.0^k <= hi * 1.05]
    tl = [(m = round(Int, v / 10.0^floor(log10(v))); e = floor(Int, log10(v)); (m == 1 ? "" : "3×") * "10" * join(sup[c] for c in string(e))) for v in tv]
    ax1 = Axis(fig[1, 1]; xlabel = L"t\;\text{(whacking iteration)}", ylabel = L"N_{\mathrm{eff}} / N_L", yscale = log10,
               yticks = (tv, tl), title = "(a) running efficiency", titlefont = :regular, titlesize = 8)
    standard_axis!(ax1)
    lines!(ax1, iters[ok], eta[ok]; color = NU_COLOR[:mw], linewidth = 1.4)
    scatter!(ax1, iters[ok], eta[ok]; color = NU_COLOR[:mw], markersize = 5)
    ax2 = Axis(fig[1, 2]; xlabel = L"t\;\text{(whacking iteration)}", ylabel = "components",
               title = "(b) size of the mixture", titlefont = :regular, titlesize = 8)
    standard_axis!(ax2)
    lines!(ax2, iters, ncomp; color = NU_COLOR[:mw], linewidth = 1.4)
    scatter!(ax2, iters, ncomp; color = NU_COLOR[:mw], markersize = 5)
    isempty(title) || Label(fig[0, 1:2], title; fontsize = 8.5, font = :regular, tellwidth = false)
    colgap!(fig.layout, 16); rowgap!(fig.layout, 4)
    return fig
end

# -----------------------------------------------------------------------------
# One panel per mass ordering; the posterior probability of the upper octant is
# printed inside each panel per sampler (the number the samplers are compared on).
function fig_octant(cells; algs = (:mw, :mh, :nuts, :ns), B = BTOP)
    rng = MersenneTwister(23)
    set_pub_theme!(class = :wide)
    W, H = figure_size(:wide, :viz_marginal)
    fig = Figure(size = (W, 0.5W))
    leg_el = []; leg_lb = String[]
    drawn = false
    for (j, ordering) in enumerate((:NO, :IO))
        ax = Axis(fig[1, j]; xlabel = L"\sin^2\theta_{23}", ylabel = j == 1 ? "posterior density" : "",
                  yticklabelsvisible = false, yticksvisible = false, title = ord_word(ordering),
                  titlefont = :regular, titlesize = 8.5, xticks = 0.3:0.1:0.7)
        standard_axis!(ax)
        ymax = 0.0
        pup = Tuple{Symbol,Float64}[]
        for alg in algs
            Θ, c, ne = pooled(cells, ordering, alg, B, 40_000, rng)
            Θ === nothing && continue
            s2 = sin.(Θ[idx(c, :θ₂₃), :]) .^ 2
            lo, hi = sin(c.lo[idx(c, :θ₂₃)])^2, sin(c.hi[idx(c, :θ₂₃)])^2
            m = kde_line!(ax, s2, lo, hi; ne = ne, color = NU_COLOR[alg], linewidth = NU_LW[alg], linestyle = NU_LS[alg])
            ymax = max(ymax, m)
            push!(pup, (alg, mean(s2 .> 0.5)))
            if j == 1
                push!(leg_el, LineElement(color = NU_COLOR[alg], linewidth = NU_LW[alg], linestyle = NU_LS[alg]))
                push!(leg_lb, NU_LABEL[alg])
            end
        end
        isempty(pup) && continue
        drawn = true
        vspan!(ax, [0.25], [0.5]; color = (:gray80, 0.35))
        vlines!(ax, [0.5]; color = :gray40, linestyle = :dash, linewidth = 0.8)
        bands = published_bands(ordering)[:θ₂₃]
        # published intervals stacked above the curves; the P(upper octant)
        # table sits in a separate strip above them (no overlap with the bars)
        bar_top = pub_overlay!(ax, [(l, convert_pub(pv, θ -> sin(θ)^2)) for (l, pv) in bands], ymax, 1.0; dy = 0.46, values = true)
        top = 1.4bar_top           # room for the P(upper octant) table above the labelled bars
        text!(ax, 0.255, 0.02top; text = "lower octant", fontsize = 7, align = (:left, :bottom), color = :gray30)
        text!(ax, 0.745, 0.02top; text = "upper octant", fontsize = 7, align = (:right, :bottom), color = :gray30)
        short = Dict(:mw => "MoleWhacker", :mh => "MH (reference)", :ns => "NS", :nuts => "NUTS", :is => "IS")
        text!(ax, 0.258, 0.985top; text = "P(upper octant)\n" * join([short[a] for (a, _) in pup], "\n"),
              fontsize = 6.5, align = (:left, :top), color = :gray10)
        text!(ax, 0.445, 0.985top; text = "\n" * join([@sprintf("%.2f", p) for (_, p) in pup], "\n"),
              fontsize = 6.5, align = (:right, :top), color = :gray10)
        xlims!(ax, 0.25, 0.75); ylims!(ax, 0, top)
    end
    drawn || return nothing
    Legend(fig[2, 1:2], leg_el, leg_lb; orientation = :horizontal, framevisible = false,
           labelsize = 7, padding = (0, 0, 0, 0), tellwidth = false, colgap = 12)
    rowgap!(fig.layout, 4); colgap!(fig.layout, 14)
    return fig
end

# -----------------------------------------------------------------------------
function fig_nuisance(cells, ordering; algs = (:mw, :mh), B = BTOP)
    rng = MersenneTwister(5)
    set_pub_theme!(class = :wide)
    W, _ = figure_size(:wide, :viz_marginal)
    fig = Figure(size = (W, 0.42W))
    pools = Dict(alg => pooled(cells, ordering, alg, B, 40_000, rng) for alg in algs)
    avail = [p[2] for p in values(pools) if p[2] !== nothing]
    isempty(avail) && return nothing
    c0 = avail[1]
    nuis = [nm for nm in c0.names if !(nm in OSC)]
    leg_el = []; leg_lb = String[]
    for (k, nm) in enumerate(nuis)
        i = idx(c0, nm)
        ax = Axis(fig[1, k]; xlabel = LBL[nm], ylabel = k == 1 ? "density" : "",
                  yticklabelsvisible = false, yticksvisible = false,
                  xticks = collect(range(c0.lo[i], c0.hi[i]; length = 3)))
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
        # prior
        xs = range(c0.lo[i], c0.hi[i]; length = 200)
        prior = isfinite(c0.gauss_sd[i]) ? pdf.(truncated(Normal(c0.gauss_mu[i], c0.gauss_sd[i]), c0.lo[i], c0.hi[i]), xs) :
                fill(1 / (c0.hi[i] - c0.lo[i]), length(xs))
        lines!(ax, xs, prior; PRIOR_STYLE...)
        if k == 1
            push!(leg_el, LineElement(; PRIOR_STYLE...))
            push!(leg_lb, "prior")
        end
        xlims!(ax, c0.lo[i], c0.hi[i]); ylims!(ax, 0, 1.15max(ymax, maximum(prior)))
    end
    Legend(fig[2, 1:length(nuis)], leg_el, leg_lb; orientation = :horizontal, framevisible = false,
           labelsize = 7, padding = (0, 0, 0, 0))
    rowgap!(fig.layout, 4); colgap!(fig.layout, 22)
    return fig
end

# -----------------------------------------------------------------------------
# Bayesian marginal (MW, pooled) vs profile likelihood ratio (Newtrinos LBFGS
# profile, 50_profile.jl), both normalized to their peak.
function fig_profile(cells, ordering, tables_dir; B = BTOP)
    p23 = joinpath(tables_dir, "profile_$(ordering)_th23.csv")
    p31 = joinpath(tables_dir, "profile_$(ordering)_dm31.csv")
    (isfile(p23) && isfile(p31)) || return nothing
    rng = MersenneTwister(31)
    Θ, c, ne = pooled(cells, ordering, :mw, B, 40_000, rng)
    Θ === nothing && return nothing
    set_pub_theme!(class = :wide)
    W, H = figure_size(:wide, :viz_marginal)
    fig = Figure(size = (W, 0.5W))
    specs = [(p23, :θ₂₃, θ -> sin(θ)^2, L"\sin^2\theta_{23}", 1.0),
             (p31, :Δm²₃₁, identity, LBL[:Δm²₃₁], 1e3)]
    for (k, (path, nm, f, lbl, sc)) in enumerate(specs)
        df = CSV.read(path, DataFrame)
        ax = Axis(fig[1, k]; xlabel = lbl, ylabel = k == 1 ? "normalized to peak" : "")
        standard_axis!(ax)
        i = idx(c, nm)
        x = f.(Θ[i, :]) .* sc
        lo, hi = minmax(f(c.lo[i]) * sc, f(c.hi[i]) * sc)
        kd = kde(x; boundary = (lo, hi), npoints = 512, bandwidth = bw_silverman(x, ne))
        lines!(ax, kd.x, kd.density ./ maximum(kd.density); color = NU_COLOR[:mw], linewidth = NU_LW[:mw],
               label = "Bayesian marginal posterior (MoleWhacker)")
        ok = isfinite.(df.dchi2)
        xp = f.(df.value[ok]) .* sc
        yp = exp.(-0.5 .* df.dchi2[ok])
        ord = sortperm(xp)
        lines!(ax, xp[ord], yp[ord]; color = :gray30, linewidth = 1.1, linestyle = :dash,
               label = "profile likelihood ratio exp(−Δχ²/2)")
        scatter!(ax, xp, yp; color = :gray30, markersize = 3.5)
        hlines!(ax, [exp(-0.5)]; color = (:gray50, 0.8), linewidth = 0.7, linestyle = :dot)
        xl, xh = zoom_range(x, lo, hi)
        text!(ax, xh - 0.02 * (xh - xl), exp(-0.5); text = L"\Delta\chi^2 = 1", fontsize = 7,
              align = (:right, :bottom), color = :gray40)
        xlims!(ax, xl, xh); ylims!(ax, 0, 1.12)
    end
    Legend(fig[2, 1:2], content(fig[1, 1]); orientation = :horizontal, framevisible = false, labelsize = 7,
           padding = (0, 0, 0, 0), tellwidth = false)
    Label(fig[0, 1:2], "$(uppercasefirst(ord_word(ordering))): Bayesian marginal vs. profile likelihood";
          fontsize = 9, font = :regular, tellwidth = false)
    colgap!(fig.layout, 14); rowgap!(fig.layout, 4)
    return fig
end

# -----------------------------------------------------------------------------
function fig_agreement(tables_dir)
    path = joinpath(tables_dir, "agreement.csv")
    isfile(path) || return nothing
    df = CSV.read(path, DataFrame)
    nrow(df) == 0 && return nothing
    set_pub_theme!(class = :wide)
    W, H = figure_size(:wide, :conv)
    fig = Figure(size = (W, 0.5W))
    # the converged NS reference (B ≥ 1e6) is not a protocol budget point
    df = df[df.B .< 1e6, :]
    ax1 = nothing
    for (j, ord) in enumerate(("NO", "IO"))
        ax = Axis(fig[1, j]; xlabel = tex_label(:B),
                  ylabel = j == 1 ? "W̄₁ to pooled MH reference\n(prior-width units)" : "", ylabelsize = 8,
                  xscale = log10, yscale = log10, title = ord_word(Symbol(ord)), titlefont = :regular, titlesize = 8.5,
                  xticks = ([5e4, 5e5], ["5×10⁴", "5×10⁵"]))
        standard_axis!(ax)
        j == 1 && (ax1 = ax)
        for alg in (:is, :mh, :nuts, :ns, :mw)
            sub = df[(df.alg .== String(alg)) .& (df.ordering .== ord), :]
            isempty(sub) && continue
            g = combine(groupby(sub, :B), :W1_avg => median => :med)
            sort!(g, :B)
            lines!(ax, g.B, g.med; color = NU_COLOR[alg], linestyle = NU_LS[alg], linewidth = NU_LW[alg], label = NU_LABEL[alg])
            scatter!(ax, sub.B, sub.W1_avg; color = NU_COLOR[alg], marker = NU_MARKER[alg], markersize = 5.5,
                     strokecolor = :black, strokewidth = alg === :mh ? 0.0 : 0.4)
        end
        xlims!(ax, 3e4, 9e5)
        # integer-decade y ticks, as in the harness convergence figures
        ExperimentsBase._apply_log10_yticks!(ax, df.W1_avg)
    end
    linkyaxes!(contents(fig[1, 1:2])...)
    Legend(fig[2, 1:2], ax1; orientation = :horizontal, framevisible = false, labelsize = 7,
           padding = (0, 0, 0, 0), tellwidth = false, tellheight = true, colgap = 10)
    rowgap!(fig.layout, 4); colgap!(fig.layout, 14)
    return fig
end

function fig_evidence(tables_dir)
    path = joinpath(tables_dir, "evidence.csv")
    isfile(path) || return nothing
    df = CSV.read(path, DataFrame)
    nrow(df) == 0 && return nothing
    set_pub_theme!(class = :wide)
    W, H = figure_size(:wide, :logz)
    fig = Figure(size = (W, 0.9H))
    ax = Axis(fig[1, 1]; ylabel = L"\log \mathcal{Z}", xlabel = "",
              xticks = (1:2, ["normal ordering", "inverted ordering"]))
    standard_axis!(ax)
    leg_el = []; leg_lb = String[]
    # reference band: defensive kernel-mixture IS anchored on the pooled MH chains
    # (70_evidence_check.jl); the band is mean ± max(SE, half the bandwidth spread)
    chk_path = joinpath(tables_dir, "evidence_check.csv")
    if isfile(chk_path)
        chk = CSV.read(chk_path, DataFrame)
        a = chk[chk.method .== "anchored_is", :]
        for (j, ord) in enumerate(("NO", "IO"))
            s = a[a.ord .== ord, :]
            isempty(s) && continue
            z = mean(s.logZ); e = max(maximum(s.se), nrow(s) > 1 ? (maximum(s.logZ) - minimum(s.logZ)) / 2 : 0.0)
            band!(ax, [j - 0.42, j + 0.42], fill(z - e, 2), fill(z + e, 2); color = (:black, 0.15))
            lines!(ax, [j - 0.42, j + 0.42], [z, z]; color = :black, linewidth = 1.0)
        end
        if !isempty(a)
            push!(leg_el, [PolyElement(color = (:black, 0.15)), LineElement(color = :black, linewidth = 1.0)])
            push!(leg_lb, "reference (defensive IS)")
        end
    end
    # NS run to its own convergence criterion (dlogz 0.5, B ≥ 1e6): separate marker
    ref = df[(df.alg .== "ns") .& (df.B .>= 1e6), :]
    df = df[df.B .< 1e6, :]
    for (j, ord) in enumerate(("NO", "IO"))
        sub = ref[ref.ordering .== ord, :]
        isempty(sub) && continue
        x = fill(j + 0.36, nrow(sub))
        scatter!(ax, x, sub.logZ; color = NU_COLOR[:ns], marker = :utriangle, markersize = 8, strokecolor = :black, strokewidth = 1.0)
        se = coalesce.(sub.logZ_se, NaN)
        errorbars!(ax, x, sub.logZ, se; color = :black, whiskerwidth = 3)
    end
    if !isempty(ref)
        push!(leg_el, MarkerElement(color = NU_COLOR[:ns], marker = :utriangle, markersize = 8, strokecolor = :black, strokewidth = 1.0))
        push!(leg_lb, "NS to its own stop rule")
    end
    budgets = sort(unique(df.B))
    for (k, alg) in enumerate((:mw, :ns, :is))
        for (j, ord) in enumerate(("NO", "IO"))
            for (b, Bv) in enumerate(budgets)
                sub = df[(df.alg .== String(alg)) .& (df.ordering .== ord) .& (df.B .== Bv), :]
                isempty(sub) && continue
                x = j .+ (k - 2) * 0.22 .+ (b - 1.5) * 0.07 .+ 0.012 .* ((1:nrow(sub)) .- (nrow(sub) + 1) / 2)
                filled = b == length(budgets)
                scatter!(ax, x, sub.logZ; color = filled ? NU_COLOR[alg] : :white, strokecolor = NU_COLOR[alg],
                         strokewidth = 1.0, marker = NU_MARKER[alg], markersize = 6)
                se = coalesce.(sub.logZ_se, NaN)
                ok = isfinite.(se)
                any(ok) && errorbars!(ax, x[ok], sub.logZ[ok], se[ok]; color = NU_COLOR[alg], whiskerwidth = 3)
            end
        end
        push!(leg_el, MarkerElement(color = NU_COLOR[alg], marker = NU_MARKER[alg], markersize = 6))
        push!(leg_lb, NU_LABEL[alg])
    end
    # MoleWhacker's final mixture re-used as a plain IS proposal with fresh draws
    # (72_mw_mixture_check.jl): isolates the pooled-cloud bookkeeping offset.
    mix_path = joinpath(tables_dir, "mw_mixture_check.csv")
    if isfile(mix_path)
        mx = CSV.read(mix_path, DataFrame)
        for (j, ord) in enumerate(("NO", "IO"))
            s = mx[mx.ordering .== ord, :]
            isempty(s) && continue
            x = j .- 0.325 .+ 0.012 .* ((1:nrow(s)) .- (nrow(s) + 1) / 2)
            scatter!(ax, x, s.fresh_logZ; color = :white, strokecolor = NU_COLOR[:mw], strokewidth = 1.0,
                     marker = :star5, markersize = 7)
            errorbars!(ax, x, s.fresh_logZ, s.fresh_se; color = NU_COLOR[:mw], whiskerwidth = 3)
        end
        if !isempty(mx)
            push!(leg_el, MarkerElement(color = :white, strokecolor = NU_COLOR[:mw], strokewidth = 1.0, marker = :star5, markersize = 7))
            push!(leg_lb, "MW mixture, fresh draws")
        end
    end
    if length(budgets) > 1
        push!(leg_el, MarkerElement(color = :white, strokecolor = :black, strokewidth = 1.0, marker = :circle, markersize = 6))
        push!(leg_lb, "B = $(fmt_B_short(budgets[1]))")
        push!(leg_el, MarkerElement(color = :black, marker = :circle, markersize = 6))
        push!(leg_lb, "B = $(fmt_B_short(budgets[end]))")
    end
    Legend(fig[1, 2], leg_el, leg_lb; orientation = :vertical, framevisible = false, labelsize = 7,
           padding = (0, 0, 0, 0), rowgap = 3, tellheight = false, valign = :top)
    colgap!(fig.layout, 12)
    return fig
end

fmt_B_short(B) = B == 5e4 ? "5×10⁴" : B == 5e5 ? "5×10⁵" : string(B)

# -----------------------------------------------------------------------------
# optional subset, e.g. --figs octant,iter (default: everything)
const FIGSEL30 = let i = findfirst(==("--figs"), ARGS); i === nothing ? ["marginals", "corner", "nuisance", "iter", "profile", "octant", "agreement", "evidence"] : String.(split(ARGS[i+1], ",")) end

function main()
    cells = load_cells()
    @info "cells" n = length(cells)
    for ord in (:NO, :IO)
        "marginals" in FIGSEL30 && (f = fig_marginals(cells, ord); f === nothing || save_pdf(f, "nu_marginals_$(ord)"; dir = FIGS))
        "corner" in FIGSEL30 && (f = fig_corner(cells, ord); f === nothing || save_pdf(f, "nu_corner_$(ord)"; dir = FIGS))
        "nuisance" in FIGSEL30 && (f = fig_nuisance(cells, ord); f === nothing || save_pdf(f, "nu_nuisance_$(ord)"; dir = FIGS))
        mw = [c for c in cells if c.ordering === ord && c.alg === :mw && c.B == BTOP && c.seed == 11]
        "iter" in FIGSEL30 && !isempty(mw) && save_pdf(fig_iter_mw_wide(mw[1].mr; title = "Daya Bay + KamLAND + MINOS, $(ord_word(ord)), B = $(fmt_B_short(BTOP)), seed 11"), "nu_mw_iter_$(ord)"; dir = FIGS)
        "profile" in FIGSEL30 && (f = fig_profile(cells, ord, joinpath(OUT, "tables")); f === nothing || save_pdf(f, "nu_profile_$(ord)"; dir = FIGS))
    end
    "octant" in FIGSEL30 && (f = fig_octant(cells); f === nothing || save_pdf(f, "nu_octant"; dir = FIGS))
    "agreement" in FIGSEL30 && (f = fig_agreement(joinpath(OUT, "tables")); f === nothing || save_pdf(f, "nu_agreement"; dir = FIGS))
    "evidence" in FIGSEL30 && (f = fig_evidence(joinpath(OUT, "tables")); f === nothing || save_pdf(f, "nu_evidence"; dir = FIGS))
    println("PLOTS-DONE")
end

# 82_extension_plots.jl includes this file for its infrastructure; run main() only as a script
if abspath(PROGRAM_FILE) == @__FILE__
    main()
end

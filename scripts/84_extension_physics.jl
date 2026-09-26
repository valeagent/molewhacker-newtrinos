# =============================================================================
# 84_extension_physics.jl — the physics figures of the extension "Towards a
# global fit" (Daya Bay + KamLAND + MINOS + IceCube DeepCore, d = 24, NO) that
# need the forward model or the fresh draws:
#
#   nu_ext_data           the DeepCore verification sample against the
#                         posterior-predictive expectation of the four-experiment
#                         fit: track-like events against reconstructed energy and
#                         against cos(zenith), and the ratio to the no-oscillation
#                         expectation against L/E for both particle-identification
#                         bins (the atmospheric analogue of nu_data_NO)
#   nu_ext_tri_NO         triangle plot of the five measured oscillation
#                         parameters, MoleWhacker (accumulated population, three
#                         seeds pooled) against the pooled MH reference; same
#                         conventions as nu_tri_NO of the three-experiment fit
#   nu_ext_tri_atm_NO     triangle plot of the atmospheric sector with the
#                         DeepCore nuisance parameters it correlates with
#                         (theta_23, Delta m^2_31, epsilon_Aeff, Delta gamma,
#                         epsilon_opt, epsilon_mu); appendix
#   nu_ext_octant         sin^2 theta_23 posterior: three experiments against four
#                         (MoleWhacker population, MoleWhacker fresh draws from
#                         the final mixtures, MH reference), with P(upper octant)
#                         per estimator; needs out_extension_nseed8/fresh/*.jld2
#                         from 81_extension_fresh.jl
#
#   julia --project=. -t 4 scripts/84_extension_physics.jl [--ext out_extension_nseed8]
#         [--ext-proto out_extension] [--ndraw 240]
# =============================================================================
include(joinpath(@__DIR__, "82_extension_plots.jl"))   # 30_plots.jl infrastructure + extension helpers; mains guarded
include(joinpath(@__DIR__, "..", "src", "neutrino_problem.jl"))   # Newtrinos forward models
using JLD2

const NDRAW = let i = findfirst(==("--ndraw"), ARGS); i === nothing ? 240 : parse(Int, ARGS[i+1]) end
const FIGSEL = let i = findfirst(==("--figs"), ARGS); i === nothing ? ["tri", "triatm", "octant", "data"] : split(ARGS[i+1], ",") end   # subset, e.g. --figs octant
const FRESHDIR = joinpath(EXT, "fresh")
const R_EARTH = 6371.0      # km
const H_PROD = 15.0         # km, mean production height of atmospheric neutrinos
const DC_EXPS = ["dayabay", "kamland", "minos", "deepcore"]

# -----------------------------------------------------------------------------
# helpers
"Equal-weight physical draws pooled over the MoleWhacker cells of one root (N total)."
function mw_population_draws(cells, N; rng = MersenneTwister(2024))
    Θ, c, ne = pooled(cells, :NO, :mw, BTOP, N, rng)
    return Θ, c, ne
end

"Path length through the atmosphere and the Earth for a zenith angle with cosine c (km)."
baseline_km(c) = -R_EARTH * c + sqrt(R_EARTH^2 * c^2 + 2R_EARTH * H_PROD + H_PROD^2)

"Fresh draws of every n_seed = 8 cell, resampled to equal weight (n per cell), and the summed fresh ESS."
function fresh_pool(n_per_cell; rng = MersenneTwister(77))
    isdir(FRESHDIR) || return nothing, nothing, 0.0, Float64[]
    parts = Matrix{Float64}[]; names = String[]; ess = 0.0; pups = Float64[]
    for f in sort(readdir(FRESHDIR))
        (endswith(f, ".jld2") && startswith(f, "nseed8__") && occursin("_mw_d24_B5e5_", f)) || continue
        d = JLD2.load(joinpath(FRESHDIR, f))
        d["kind"] == "nseed8" || continue
        Θ = d["theta"]; w = d["weights"]; names = d["names"]
        push!(parts, resample_to_equal_weight(Θ, w, n_per_cell; rng = rng))
        ess += sum(w)^2 / sum(w .^ 2)
        k23 = findfirst(==("θ₂₃"), names)
        push!(pups, sum(w .* (sin.(Θ[k23, :]) .^ 2 .> 0.5)) / sum(w))
    end
    isempty(parts) && return nothing, nothing, 0.0, Float64[]
    return hcat(parts...), Symbol.(names), ess, pups
end

# -----------------------------------------------------------------------------
# DeepCore data against the posterior predictive
function fig_ext_data(cells4)
    Θ, c, ne = mw_population_draws(cells4, NDRAW)
    Θ === nothing && return nothing
    cfg = make_config_neutrino(experiments = DC_EXPS, ordering = :NO)
    physics = neutrino_physics(:NO; matter = true)
    exps = neutrino_experiments(cfg.experiments, physics)
    base = Newtrinos.get_params(exps)
    names = c.names
    Symbol.(cfg.names) == names || error("parameter order differs between the cell and the configuration")
    params_of(j) = merge(base, NamedTuple{Tuple(names)}(Tuple(Θ[:, j])))
    expect(θ) = mean(exps.deepcore.forward_model(θ))            # 10 (E) × 10 (cos θz) × 2 (PID)
    n = size(Θ, 2)
    E1 = expect(params_of(1))
    acc = zeros(size(E1)..., n)
    Threads.@threads for j in 1:n
        acc[:, :, :, j] .= expect(params_of(j))
    end
    med = NamedTuple{Tuple(names)}(Tuple(median(Θ[i, :]) for i in 1:length(names)))
    θmed = merge(base, med)
    noosc = expect(merge(θmed, (; θ₁₂ = 0.0, θ₁₃ = 0.0, θ₂₃ = 0.0)))
    obs = exps.deepcore.assets.observed
    bn = exps.deepcore.assets.binning
    Ee = collect(bn.reco_energy_bin_edges); Ce = collect(bn.reco_coszen_bin_edges)
    Ec = sqrt.(Ee[1:end-1] .* Ee[2:end]); Cc = 0.5 .* (Ce[1:end-1] .+ Ce[2:end])
    q(M) = (lo = [quantile(M[i, :], 0.16) for i in 1:size(M, 1)], med = [median(M[i, :]) for i in 1:size(M, 1)],
            hi = [quantile(M[i, :], 0.84) for i in 1:size(M, 1)])
    # projections of the track-like sample (PID bin 2)
    trk = 2
    projE = q(dropdims(sum(acc[:, :, trk, :]; dims = 2); dims = 2)); obsE = vec(sum(obs[:, :, trk]; dims = 2)); nooE = vec(sum(noosc[:, :, trk]; dims = 2))
    projC = q(dropdims(sum(acc[:, :, trk, :]; dims = 1); dims = 1)); obsC = vec(sum(obs[:, :, trk]; dims = 1)); nooC = vec(sum(noosc[:, :, trk]; dims = 1))
    # L/E rebinning (both PID bins): every (E, cos θz) bin at its L/E, twelve logarithmic L/E bins
    LoverE = [baseline_km(Cc[j]) / Ec[i] for i in 1:length(Ec), j in 1:length(Cc)]
    le_edges = 10 .^ range(log10(minimum(LoverE)) - 1e-6, log10(maximum(LoverE)) + 1e-6; length = 13)
    function rebin_le(A)      # A: 10 × 10 (× n) → per L/E bin
        nb = length(le_edges) - 1
        out = ndims(A) == 3 ? zeros(nb, size(A, 3)) : zeros(nb)
        for i in 1:size(A, 1), j in 1:size(A, 2)
            b = clamp(searchsortedlast(le_edges, LoverE[i, j]), 1, nb)
            if ndims(A) == 3
                out[b, :] .+= A[i, j, :]
            else
                out[b] += A[i, j]
            end
        end
        return out
    end
    le_c = sqrt.(le_edges[1:end-1] .* le_edges[2:end])
    le = Dict(p => (acc = rebin_le(acc[:, :, p, :]), obs = rebin_le(obs[:, :, p]), noo = rebin_le(noosc[:, :, p])) for p in 1:2)
    # ------------------------------------------------------------------ figure
    set_pub_theme!(class = :wide)
    W, _ = figure_size(:wide, :conv)
    fig = Figure(size = (W, 0.7W))
    sx(edges) = repeat(edges, inner = 2)[2:end-1]
    sy(v) = repeat(v, inner = 2)
    # (a) energy spectrum, track-like
    axE = Axis(fig[1, 1]; title = "track-like events, all zenith angles", titlefont = :regular, titlesize = 8, ylabel = "events per bin",
               xscale = log10, xticklabelsvisible = false, xticksvisible = false, ylabelsize = 8, xticks = [10, 30, 100])
    axEr = Axis(fig[2, 1]; xlabel = "reconstructed energy  [GeV]", ylabel = "ratio to no osc.", xscale = log10,
                xlabelsize = 8.5, ylabelsize = 8, xticks = ([10, 30, 100], ["10", "30", "100"]))
    for ax in (axE, axEr); standard_axis!(ax); end
    lines!(axE, sx(Ee), sy(nooE); color = :gray45, linewidth = 1.0, linestyle = :dash)
    band!(axE, sx(Ee), sy(projE.lo), sy(projE.hi); color = (NU_COLOR[:mw], 0.35))
    lines!(axE, sx(Ee), sy(projE.med); color = NU_COLOR[:mw], linewidth = 1.3)
    scatter!(axE, Ec, obsE; color = :black, markersize = 3.5)
    errorbars!(axE, Ec, obsE, sqrt.(obsE); color = :black, linewidth = 0.7, whiskerwidth = 0)
    band!(axEr, sx(Ee), sy(projE.lo ./ nooE), sy(projE.hi ./ nooE); color = (NU_COLOR[:mw], 0.35))
    lines!(axEr, sx(Ee), sy(projE.med ./ nooE); color = NU_COLOR[:mw], linewidth = 1.3)
    hlines!(axEr, [1.0]; color = :gray45, linewidth = 1.0, linestyle = :dash)
    scatter!(axEr, Ec, obsE ./ nooE; color = :black, markersize = 3.5)
    errorbars!(axEr, Ec, obsE ./ nooE, sqrt.(obsE) ./ nooE; color = :black, linewidth = 0.7, whiskerwidth = 0)
    xlims!(axE, Ee[1], Ee[end]); xlims!(axEr, Ee[1], Ee[end]); ylims!(axE, 0, nothing); ylims!(axEr, 0.4, 1.15)
    # (b) zenith distribution, track-like
    axC = Axis(fig[1, 2]; title = "track-like events, all energies", titlefont = :regular, titlesize = 8,
               xticklabelsvisible = false, xticksvisible = false, xticks = -1:0.5:0)
    axCr = Axis(fig[2, 2]; xlabel = L"\cos\theta_{z}\ \text{(reconstructed)}", xlabelsize = 8.5, xticks = -1:0.5:0)
    for ax in (axC, axCr); standard_axis!(ax); end
    lines!(axC, sx(Ce), sy(nooC); color = :gray45, linewidth = 1.0, linestyle = :dash)
    band!(axC, sx(Ce), sy(projC.lo), sy(projC.hi); color = (NU_COLOR[:mw], 0.35))
    lines!(axC, sx(Ce), sy(projC.med); color = NU_COLOR[:mw], linewidth = 1.3)
    scatter!(axC, Cc, obsC; color = :black, markersize = 3.5)
    errorbars!(axC, Cc, obsC, sqrt.(obsC); color = :black, linewidth = 0.7, whiskerwidth = 0)
    band!(axCr, sx(Ce), sy(projC.lo ./ nooC), sy(projC.hi ./ nooC); color = (NU_COLOR[:mw], 0.35))
    lines!(axCr, sx(Ce), sy(projC.med ./ nooC); color = NU_COLOR[:mw], linewidth = 1.3)
    hlines!(axCr, [1.0]; color = :gray45, linewidth = 1.0, linestyle = :dash)
    scatter!(axCr, Cc, obsC ./ nooC; color = :black, markersize = 3.5)
    errorbars!(axCr, Cc, obsC ./ nooC, sqrt.(obsC) ./ nooC; color = :black, linewidth = 0.7, whiskerwidth = 0)
    xlims!(axC, Ce[1], Ce[end]); xlims!(axCr, Ce[1], Ce[end]); ylims!(axC, 0, nothing); ylims!(axCr, 0.4, 1.15)
    text!(axCr, -0.98, 0.43; text = "upgoing", fontsize = 6.5, align = (:left, :bottom), color = :gray30)
    text!(axCr, 0.08, 0.43; text = "horizon", fontsize = 6.5, align = (:right, :bottom), color = :gray30)
    # (c) ratio to no oscillation against L/E, both PID bins
    # PID 0.55-0.75 is the collaboration's mixed channel (about 70 % nu_mu CC), not a
    # cascade-like sample; label corrected 2026-09-26 (thesis review C6).
    titles = Dict(2 => "track-like, all bins", 1 => "mixed PID bin, all bins")
    for (row, p) in ((1, 2), (2, 1))
        ax = Axis(fig[row, 3]; title = titles[p], titlefont = :regular, titlesize = 8, xscale = log10,
                  xlabel = row == 2 ? "L / E  [km / GeV]" : "", xlabelsize = 8.5, ylabel = "ratio to no osc.", ylabelsize = 8,
                  xticklabelsvisible = row == 2, xticksvisible = row == 2, xticks = LogTicks(1:4))
        standard_axis!(ax)
        r = q(le[p].acc ./ le[p].noo)
        band!(ax, sx(le_edges), sy(r.lo), sy(r.hi); color = (NU_COLOR[:mw], 0.35))
        lines!(ax, sx(le_edges), sy(r.med); color = NU_COLOR[:mw], linewidth = 1.3)
        hlines!(ax, [1.0]; color = :gray45, linewidth = 1.0, linestyle = :dash)
        scatter!(ax, le_c, le[p].obs ./ le[p].noo; color = :black, markersize = 3.5)
        errorbars!(ax, le_c, le[p].obs ./ le[p].noo, sqrt.(le[p].obs) ./ le[p].noo; color = :black, linewidth = 0.7, whiskerwidth = 0)
        xlims!(ax, le_edges[1], le_edges[end]); ylims!(ax, 0.3, 1.25)
    end
    rowsize!(fig.layout, 1, Relative(0.52))
    leg = [MarkerElement(color = :black, marker = :circle, markersize = 4),
           [PolyElement(color = (NU_COLOR[:mw], 0.35)), LineElement(color = NU_COLOR[:mw], linewidth = 1.3)],
           LineElement(color = :gray45, linewidth = 1.0, linestyle = :dash)]
    Legend(fig[3, 1:3], leg, ["observed (Poisson error)", "posterior predictive (MoleWhacker): median, 68 % band",
           "no oscillation"]; orientation = :horizontal, framevisible = false, labelsize = 6.5,
           padding = (0, 0, 0, 0), tellwidth = false, colgap = 8, patchsize = (12, 6), patchlabelgap = 3)
    Label(fig[0, 1:3], "DeepCore sample against the four-experiment fit, normal ordering ($(NDRAW) posterior draws)";
          fontsize = 8, font = :regular, tellwidth = false)
    rowgap!(fig.layout, 1, 4); rowgap!(fig.layout, 2, 4); colgap!(fig.layout, 12)
    # numbers behind the figure
    rows = DataFrame(quantity = String[], value = Float64[])
    push!(rows, ("observed_total", sum(obs))); push!(rows, ("observed_track", sum(obs[:, :, 2]))); push!(rows, ("observed_cascade", sum(obs[:, :, 1])))
    push!(rows, ("noosc_total", sum(noosc))); push!(rows, ("ppd_median_total", median(vec(sum(acc; dims = (1, 2, 3))))))
    push!(rows, ("noosc_track", sum(noosc[:, :, 2]))); push!(rows, ("ppd_median_track", median(vec(sum(acc[:, :, 2, :]; dims = (1, 2))))))
    for p in 1:2, b in 1:length(le_c)
        push!(rows, ("ratio_LE_pid$(p)_bin$(b)_LoverE", le_c[b])); push!(rows, ("ratio_LE_pid$(p)_bin$(b)_obs", le[p].obs[b] / le[p].noo[b]))
        push!(rows, ("ratio_LE_pid$(p)_bin$(b)_ppd", median(le[p].acc[b, :]) / le[p].noo[b]))
    end
    mkpath(joinpath(EXT, "tables")); CSV.write(joinpath(EXT, "tables", "deepcore_posterior_predictive.csv"), rows)
    return fig
end

# -----------------------------------------------------------------------------
# Triangle plot, generic in the parameter list (the four-experiment analogue of fig_corner)
function fig_ext_tri(cells4, params::Vector{Symbol}; short = SHORT_OSC, headline = "", N = 30_000, size_scale = 1.0)
    rng = MersenneTwister(11)
    Θmw, cmw, nemw = pooled(cells4, :NO, :mw, BTOP, N, rng)
    Θmh, cmh, nemh = pooled(cells4, :NO, :mh, mh_B(cells4), N, rng)
    (Θmw === nothing || Θmh === nothing) && return nothing
    set_pub_theme!(class = :wide)
    W, _ = figure_size(:wide, :tri)
    nc = length(params)
    col(Θ, c, nm) = view(Θ, idx(c, nm), :) .* scale_of(nm)
    lims = Dict{Symbol,Tuple{Float64,Float64}}()
    for nm in params
        x = vcat(col(Θmw, cmw, nm), col(Θmh, cmh, nm))
        qq = quantile(x, [0.0005, 0.9995]); m = 0.06 * (qq[2] - qq[1])
        k = idx(cmw, nm); lo, hi = extrema((cmw.lo[k], cmw.hi[k]) .* scale_of(nm))
        lims[nm] = (max(lo, qq[1] - m), min(hi, qq[2] + m))
    end
    fracs = [0.683, 0.954]
    cmw_fill = [Makie.to_color((NU_COLOR[:mw], 0.35)), Makie.to_color((NU_COLOR[:mw], 0.9))]
    cmap_fill = cgrad(cmw_fill; categorical = true)
    fig = Figure(size = (W * size_scale, W * size_scale))
    ticks = WilkinsonTicks(3; k_min = 2, k_max = 3)
    lbl(nm) = get(short, nm, lbl_ext(nm))
    for i in 1:nc, j in 1:i
        ni, nj = params[i], params[j]
        ax = Axis(fig[i, j]; xticks = ticks, yticks = ticks, xticklabelsize = 6.5, yticklabelsize = 6.5,
                  xlabelsize = 9, ylabelsize = 9, xminorticksvisible = false, yminorticksvisible = false)
        standard_axis!(ax)
        i < nc && (ax.xticklabelsvisible = false)
        j > 1 && (ax.yticklabelsvisible = false)
        i == nc && (ax.xlabel = lbl(nj))
        (j == 1 && i > 1) && (ax.ylabel = lbl(ni))
        xl = lims[nj]
        if i == j
            ax.yticklabelsvisible = false; ax.yticksvisible = false
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
                lv = hdr_levels(k.density, fracs)
                if alg === :mw
                    contourf!(ax, k.x, k.y, k.density; levels = [lv[2], lv[1], 1.001 * maximum(k.density)], colormap = cmap_fill)
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
    Label(fig[0, 1:nc], headline; fontsize = 7.5, font = :regular, tellwidth = false, justification = :center)
    colgap!(fig.layout, 4); rowgap!(fig.layout, 4)
    return fig
end

# -----------------------------------------------------------------------------
# sin²θ₂₃: three experiments against four, and the three estimators of the four
function fig_ext_octant(cells3, cells4)
    rng = MersenneTwister(23)
    Θ3, c3, ne3 = pooled(cells3, :NO, :mw, BTOP, 40_000, rng)
    Θ4, c4, ne4 = pooled(cells4, :NO, :mw, BTOP, 40_000, rng)
    Θh, ch, neh = pooled(cells4, :NO, :mh, mh_B(cells4), 40_000, rng)
    Θf, nf, nef, pups = fresh_pool(cld(40_000, 3); rng = rng)
    Θ4 === nothing && return nothing
    set_pub_theme!(class = :wide)
    W, _ = figure_size(:wide, :viz_marginal)
    fig = Figure(size = (0.8W, 0.62W))
    ax = Axis(fig[1, 1]; xlabel = L"\sin^2\theta_{23}", ylabel = "posterior density",
              yticklabelsvisible = false, yticksvisible = false, xticks = 0.3:0.1:0.7)
    standard_axis!(ax)
    s2(Θ, names) = sin.(Θ[findfirst(==(:θ₂₃), names), :]) .^ 2
    lo, hi = sin(c4.lo[idx(c4, :θ₂₃)])^2, sin(c4.hi[idx(c4, :θ₂₃)])^2
    curves = Any[]
    Θ3 === nothing || push!(curves, (s2(Θ3, c3.names), ne3, C3, 1.2, :solid, "three exp.: MoleWhacker", nothing))
    push!(curves, (s2(Θ4, c4.names), ne4, NU_COLOR[:mw], NU_LW[:mw], :solid, "four exp.: MoleWhacker population", nothing))
    Θf === nothing || push!(curves, (s2(Θf, nf), nef, NU_COLOR[:mw], 1.3, :dot, "four exp.: MoleWhacker fresh draws", nothing))
    Θh === nothing || push!(curves, (s2(Θh, ch.names), neh, NU_COLOR[:mh], NU_LW[:mh], :dash, "four exp.: MH (reference)", nothing))
    ymax = 0.0; leg_el = Any[]; leg_lb = String[]; pup = Tuple{String,Float64}[]
    for (x, ne, colr, lw, ls, label, _) in curves
        ymax = max(ymax, kde_line!(ax, x, lo, hi; ne = ne, color = colr, linewidth = lw, linestyle = ls))
        push!(leg_el, LineElement(color = colr, linewidth = lw, linestyle = ls)); push!(leg_lb, label)
        push!(pup, (label, mean(x .> 0.5)))
    end
    vspan!(ax, [0.25], [0.5]; color = (:gray80, 0.35))
    vlines!(ax, [0.5]; color = :gray40, linestyle = :dash, linewidth = 0.8)
    bands = published_bands(:NO; deepcore = true)[:θ₂₃]
    bar_top = pub_overlay!(ax, [(l, convert_pub(pv, θ -> sin(θ)^2)) for (l, pv) in bands], ymax, 1.0; dy = 0.35, values = true)
    top = 1.42bar_top
    text!(ax, 0.255, 0.02top; text = "lower octant", fontsize = 7, align = (:left, :bottom), color = :gray30)
    text!(ax, 0.745, 0.02top; text = "upper octant", fontsize = 7, align = (:right, :bottom), color = :gray30)
    short = Dict("three exp.: MoleWhacker" => "three exp., MoleWhacker",
                 "four exp.: MoleWhacker population" => "four exp., MoleWhacker population",
                 "four exp.: MoleWhacker fresh draws" => "four exp., MoleWhacker fresh draws",
                 "four exp.: MH (reference)" => "four exp., MH (reference)")
    text!(ax, 0.258, 0.985top; text = "P(upper octant)\n" * join([short[l] for (l, _) in pup], "\n"),
          fontsize = 6.5, align = (:left, :top), color = :gray10)
    text!(ax, 0.49, 0.985top; text = "\n" * join([@sprintf("%.2f", p) for (_, p) in pup], "\n"),
          fontsize = 6.5, align = (:right, :top), color = :gray10)
    xlims!(ax, 0.25, 0.75); ylims!(ax, 0, top)
    Legend(fig[2, 1], leg_el, leg_lb; orientation = :horizontal, nbanks = 2, framevisible = false,
           labelsize = 6.5, padding = (0, 0, 0, 0), tellwidth = false, colgap = 10, rowgap = 1)
    Label(fig[0, 1], "Normal ordering, B = $(fmt_B_short(BTOP))"; fontsize = 8.5, font = :regular, tellwidth = false)
    rowgap!(fig.layout, 4)
    @info "octant figure" P_upper = pup fresh_per_cell = pups fresh_ess = nef
    return fig
end

# -----------------------------------------------------------------------------
function main_phys()
    cells3 = load_cells_from(RUNS, "nu_dakami_")
    cells4 = load_cells_from(joinpath(EXT, "runs"), "nu_dakamide_")
    @info "cells" three = length(cells3) four = length(cells4)
    isempty(cells4) && (println("EXT-PHYS-DONE (no cells)"); return)
    if "tri" in FIGSEL
        f = fig_ext_tri(cells4, OSC_MEASURED; headline = "Four experiments, normal ordering, B = $(fmt_B_short(BTOP)): regions enclosing 68.3 % and 95.4 % of the posterior mass\n" *
            "(angles in rad, Δm²₂₁ in 10⁻⁵ eV², Δm²₃₁ in 10⁻³ eV²; 3×10⁴ draws per sampler, seeds pooled)")
        f === nothing || save_pdf(f, "nu_ext_tri_NO"; dir = FIGS)
    end
    atm = [:θ₂₃, :Δm²₃₁, :deepcore_aeff_scale, :atm_flux_delta_spectral_index, :deepcore_opt_eff_overall, :deepcore_atm_muon_scale]
    if "triatm" in FIGSEL
        f = fig_ext_tri(cells4, atm; headline = "Four experiments, normal ordering, B = $(fmt_B_short(BTOP)): atmospheric sector and correlated DeepCore nuisance parameters\n" *
            "(θ₂₃ in rad, Δm²₃₁ in 10⁻³ eV²; 3×10⁴ draws per sampler, seeds pooled)")
        f === nothing || save_pdf(f, "nu_ext_tri_atm_NO"; dir = FIGS)
    end
    "octant" in FIGSEL && (f = fig_ext_octant(cells3, cells4); f === nothing || save_pdf(f, "nu_ext_octant"; dir = FIGS))
    "data" in FIGSEL && (f = fig_ext_data(cells4); f === nothing || save_pdf(f, "nu_ext_data"; dir = FIGS))
    println("EXT-PHYS-DONE")
end

if abspath(PROGRAM_FILE) == @__FILE__
    main_phys()
end

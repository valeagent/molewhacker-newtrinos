# =============================================================================
# 74_subset_study.jl — which experiment measures what, and do they agree?
#
# Side study on the MoleWhacker cells of the single-experiment and pairwise fits
# (tags nu_da, nu_ka, nu_mi, nu_daka, nu_dami, nu_kami; B = 5e4, seeds 11/23,
# both orderings) next to the joint fit (nu_dakami, B = 5e5, three seeds):
#   1. marginal posteriors of the six oscillation parameters for each single
#      experiment and for the joint fit (figure nu_subsets_<ORD>);
#   2. evidences: pooled-cloud log Z per subset (cube-normalized), the same in
#      the physical normalization of eq. (nu-logz-map), the mass-ordering
#      Bayes factor per subset, and the consistency ratio
#          ln R(A,B) = ln Z_phys(A+B) - ln Z_phys(A) - ln Z_phys(B)
#      (Marshall, Rajguru, Slosar 2006) for the three pairs and for all three;
#      with --fresh the fresh-draw evidence of each cell's final mixture is
#      used instead of the pooled-cloud value (72_mw_mixture_check.jl logic);
#   3. prior sensitivity of the joint fit: reweighting from priors flat in the
#      mixing angles to priors flat in sin^2 of the angles (P_upper, medians,
#      ln B shift).
#
#   julia --project=. -t 8 scripts/74_subset_study.jl [--fresh] [--N 60000]
# Output: out/tables/subset_study.csv, subset_R.csv, prior_sensitivity.csv;
#         out/figs/nu_subsets_<ORD>.{pdf,png}
# =============================================================================
import Pkg
Pkg.activate(joinpath(@__DIR__, ".."))
using LinearAlgebra, Statistics, StatsBase, Random, Printf, CSV, DataFrames, Distributions
using CairoMakie, LaTeXStrings, KernelDensity
using Base.Threads
# Thesis benchmark harness (module ExperimentsBase) and the thesis-final
# MoleWhacker; verbatim copies live in ../harness (see harness/PROVENANCE.md).
const HARNESS = joinpath(@__DIR__, "..", "harness", "experiments", "src", "ExperimentsBase.jl")
include(HARNESS)
using .ExperimentsBase

const OUT = joinpath(@__DIR__, "..", "out")
const RUNS = joinpath(OUT, "runs")
const TABLES = joinpath(OUT, "tables"); mkpath(TABLES)
const FIGS = joinpath(OUT, "figs"); mkpath(FIGS)
const DO_FRESH = "--fresh" in ARGS
const NFRESH = let i = findfirst(==("--N"), ARGS); i === nothing ? 60_000 : parse(Int, ARGS[i+1]) end
const OSC = [:θ₁₂, :θ₁₃, :θ₂₃, :δCP, :Δm²₂₁, :Δm²₃₁]
const LBL = Dict{Symbol,LaTeXString}(
    :θ₁₂ => L"\theta_{12}", :θ₁₃ => L"\theta_{13}", :θ₂₃ => L"\theta_{23}", :δCP => L"\delta_{\mathrm{CP}}",
    :Δm²₂₁ => L"\Delta m^2_{21}\;[10^{-5}\,\mathrm{eV}^2]", :Δm²₃₁ => L"\Delta m^2_{31}\;[10^{-3}\,\mathrm{eV}^2]")
const SCALE = Dict{Symbol,Float64}(:Δm²₂₁ => 1e5, :Δm²₃₁ => 1e3)
scale_of(nm) = get(SCALE, nm, 1.0)
# experiment colors of 80_posterior_predictive.jl; the joint fit keeps MoleWhacker's vermilion
const EXP_COLOR = Dict("da" => "#CC79A7", "ka" => "#009E73", "mi" => "#0072B2", "dakami" => "#D55E00")
const EXP_NAME = Dict("da" => "Daya Bay only", "ka" => "KamLAND only", "mi" => "MINOS only",
                      "daka" => "Daya Bay + KamLAND", "dami" => "Daya Bay + MINOS", "kami" => "KamLAND + MINOS",
                      "dakami" => "joint fit")
const SUBSETS = ["da", "ka", "mi", "daka", "dami", "kami", "dakami"]
const PRIOR_STYLE = (; color = (:gray45, 0.9), linewidth = 0.8, linestyle = :dot)
ord_word(o) = o === :NO ? "normal ordering" : "inverted ordering"

struct Cell
    subset::String; ordering::Symbol; B::Float64; seed::Int
    mr::MethodResult; experiments::Vector{String}
    names::Vector{Symbol}; lo::Vector{Float64}; hi::Vector{Float64}; L::Float64
    gauss_mu::Vector{Float64}; gauss_sd::Vector{Float64}
end

function load_cells()
    cells = Cell[]
    for name in sort(readdir(RUNS))
        m = match(r"^nu_([a-z]+)_(NO|IO)_mw_d\d+_B([0-9e.]+)_seed(\d+)$", name)
        m === nothing && continue
        dir = joinpath(RUNS, name)
        isfile(joinpath(dir, "result.h5")) || continue
        meta = read_metadata_json(dir); pc = meta["problem"]["config"]
        mr = load_method_result(dir)
        _f(x) = x === nothing ? Inf : Float64(x)
        push!(cells, Cell(m[1], Symbol(m[2]), mr.B, mr.seed, mr, String.(pc["experiments"]),
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
idx(c::Cell, nm::Symbol) = findfirst(==(nm), c.names)
weights(c::Cell) = isempty(c.mr.weights) ? ones(size(c.mr.samples, 2)) : c.mr.weights

# cube -> physical evidence constant of eq. (nu-logz-map): sum over Gaussian-pull parameters
function logz_phys_shift(c::Cell)
    s = 0.0
    for k in eachindex(c.names)
        isfinite(c.gauss_sd[k]) || continue
        μ, σ, a, b = c.gauss_mu[k], c.gauss_sd[k], c.lo[k], c.hi[k]
        Ck = cdf(Normal(), (b - μ) / σ) - cdf(Normal(), (a - μ) / σ)
        s += log((b - a) / (sqrt(2π) * σ * Ck))
    end
    return s
end

function pupper(c::Cell)
    k = idx(c, :θ₂₃); k === nothing && return NaN
    Θ = physical(c); w = weights(c) ./ sum(weights(c))
    return sum(w .* (sin.(view(Θ, k, :)) .^ 2 .> 0.5))
end

# ---------------------------------------------------------------- fresh-draw evidence (optional)
if DO_FRESH
    using BAT: bat_transform, PriorToNormal
    using DensityInterface: logdensityof
    include(joinpath(@__DIR__, "..", "src", "neutrino_problem.jl"))
end
# --reuse-fresh: take the fresh-draw evidences of an earlier --fresh run from
# out/tables/subset_cells.csv instead of recomputing them (cheap re-plot).
const REUSE_FRESH = "--reuse-fresh" in ARGS && !DO_FRESH
const CACHED_FRESH = REUSE_FRESH ? CSV.read(joinpath(TABLES, "subset_cells.csv"), DataFrame) : DataFrame()
function fresh_logz(c::Cell)
    if REUSE_FRESH
        hit = CACHED_FRESH[(CACHED_FRESH.subset .== c.subset) .& (CACHED_FRESH.ordering .== String(c.ordering)) .&
                           (CACHED_FRESH.seed .== c.seed) .& (CACHED_FRESH.B .== c.B), :]
        nrow(hit) == 1 || return (NaN, NaN, NaN)
        return (hit.fresh_logZ_cube[1], hit.fresh_se[1], hit.fresh_ess[1])
    end
    (DO_FRESH && haskey(c.mr.extras, :mixture)) || return (NaN, NaN, NaN)
    cfg = make_config_neutrino(experiments = c.experiments, ordering = c.ordering)
    log_f = build_log_f(cfg)
    posterior = ExperimentsBase.posterior_measure(cfg, log_f)
    pstr, _ = bat_transform(PriorToNormal(), posterior)
    mix = c.mr.extras[:mixture]
    Random.seed!(1000 + c.seed)
    Xf = [rand(mix) for _ in 1:NFRESH]
    logp = Vector{Float64}(undef, NFRESH); logq = similar(logp)
    @threads for i in 1:NFRESH
        logp[i] = logdensityof(pstr, Xf[i]); logq[i] = logpdf(mix, Xf[i])
    end
    ok = isfinite.(logp) .& isfinite.(logq)
    logw = fill(-Inf, NFRESH); logw[ok] = logp[ok] .- logq[ok]
    mx = maximum(logw); w = exp.(logw .- mx)
    return (mx + log(mean(w)), std(w) / (sqrt(length(w)) * mean(w)), sum(w)^2 / sum(w .^ 2))
end

cells = load_cells()
isempty(cells) && error("no MoleWhacker cells found")
# the joint fit enters at its top budget only
cells = [c for c in cells if c.subset != "dakami" || c.B == maximum(x.B for x in cells if x.subset == "dakami")]

# ---------------------------------------------------------------- per-cell table
rows = DataFrame(subset = String[], experiments = String[], ordering = String[], B = Float64[], seed = Int[], d = Int[],
                 Nlike_used = Float64[], neff = Float64[], eta = Float64[], logZ_cube = Float64[], logZ_phys = Float64[],
                 fresh_logZ_cube = Float64[], fresh_se = Float64[], fresh_ess = Float64[], P_upper = Float64[],
                 wall_time_s = Float64[])
for c in cells
    fz, fse, fess = fresh_logz(c)
    lz = c.mr.logZ_estimate === missing ? NaN : c.mr.logZ_estimate
    @info "cell" c.subset c.ordering c.seed lz fz
    push!(rows, (c.subset, join(c.experiments, "+"), String(c.ordering), c.B, c.seed, length(c.names), c.mr.Nlike_used,
                 neff(c.mr), neff(c.mr) / c.mr.Nlike_used, lz, lz + logz_phys_shift(c), fz, fse, fess, pupper(c),
                 c.mr.wall_time_s))
end
CSV.write(joinpath(TABLES, "subset_cells.csv"), rows)

# ---------------------------------------------------------------- per-subset summary (seed mean, half-range)
usefresh = (DO_FRESH || REUSE_FRESH) && all(isfinite, rows.fresh_logZ_cube)
rows.logZ_used = usefresh ? rows.fresh_logZ_cube : rows.logZ_cube
rows.logZ_used_phys = rows.logZ_used .+ (rows.logZ_phys .- rows.logZ_cube)
summ = combine(groupby(rows, [:subset, :experiments, :ordering, :d]),
               :Nlike_used => median => :Nlike_used, :neff => median => :neff, :eta => median => :eta,
               :logZ_used => mean => :logZ, :logZ_used => (x -> (maximum(x) - minimum(x)) / 2) => :logZ_halfrange,
               :logZ_used_phys => mean => :logZ_phys, :P_upper => mean => :P_upper,
               :P_upper => (x -> (maximum(x) - minimum(x)) / 2) => :P_upper_halfrange, nrow => :n_seeds)
summ.evidence_source .= usefresh ? "fresh draws from final mixture" : "pooled cloud"
# Bayes factor per subset
lnB = DataFrame(subset = String[], experiments = String[], lnB_NO_IO = Float64[], lnB_err = Float64[])
for g in groupby(summ, [:subset, :experiments])
    no = g[g.ordering .== "NO", :]; io = g[g.ordering .== "IO", :]
    (nrow(no) == 1 && nrow(io) == 1) || continue
    push!(lnB, (g.subset[1], g.experiments[1], no.logZ[1] - io.logZ[1], hypot(no.logZ_halfrange[1], io.logZ_halfrange[1])))
end
summ = leftjoin(summ, lnB, on = [:subset, :experiments])
order = Dict(s => i for (i, s) in enumerate(SUBSETS))
summ.order_key = [get(order, s, 99) for s in summ.subset]
sort!(summ, [:order_key, :ordering]); select!(summ, Not(:order_key))
CSV.write(joinpath(TABLES, "subset_study.csv"), summ)
show(summ; allrows = true, allcols = true); println()

# ---------------------------------------------------------------- consistency ratios R
lzp(sub, ord) = let g = summ[(summ.subset .== sub) .& (summ.ordering .== ord), :]; nrow(g) == 1 ? (g.logZ_phys[1], g.logZ_halfrange[1]) : (NaN, NaN) end
R = DataFrame(ordering = String[], pair = String[], lnR = Float64[], lnR_err = Float64[])
for ord in ("NO", "IO")
    for (ab, a, b) in (("daka", "da", "ka"), ("dami", "da", "mi"), ("kami", "ka", "mi"))
        zab, eab = lzp(ab, ord); za, ea = lzp(a, ord); zb, eb = lzp(b, ord)
        push!(R, (ord, "$(EXP_NAME[a]) vs $(EXP_NAME[b])", zab - za - zb, sqrt(eab^2 + ea^2 + eb^2)))
    end
    zj, ej = lzp("dakami", ord); za, ea = lzp("da", ord); zk, ek = lzp("ka", ord); zm, em = lzp("mi", ord)
    push!(R, (ord, "all three", zj - za - zk - zm, sqrt(ej^2 + ea^2 + ek^2 + em^2)))
end
CSV.write(joinpath(TABLES, "subset_R.csv"), R)
show(R; allrows = true, allcols = true); println()

# ---------------------------------------------------------------- prior sensitivity of the joint fit
# alternative priors flat in sin^2 of a mixing angle: p_alt(θ)/p_flat(θ) = sin(2θ) (b - a) / (sin^2 b - sin^2 a)
function alt_ratio(c::Cell, nm::Symbol, Θ)
    k = idx(c, nm); a, b = c.lo[k], c.hi[k]
    return sin.(2 .* view(Θ, k, :)) .* (b - a) ./ (sin(b)^2 - sin(a)^2)
end
function wmedian(x, w)
    o = sortperm(x); cw = cumsum(w[o]) ./ sum(w)
    return x[o[findfirst(>=(0.5), cw)]]
end
ps = DataFrame(ordering = String[], prior = String[], P_upper = Float64[], P_upper_halfrange = Float64[],
               med_sin2_th23 = Float64[], med_sin2_th12 = Float64[], med_sin2_2th13 = Float64[], dlogZ = Float64[])
for ord in (:NO, :IO)
    joint = [c for c in cells if c.subset == "dakami" && c.ordering === ord]
    isempty(joint) && continue
    for (label, angles) in (("flat in θ (baseline)", Symbol[]), ("flat in sin²θ₂₃", [:θ₂₃]),
                            ("flat in sin²θ₁₂, sin²θ₁₃, sin²θ₂₃", [:θ₁₂, :θ₁₃, :θ₂₃]))
        pups = Float64[]; m23 = Float64[]; m12 = Float64[]; m13 = Float64[]; dz = Float64[]
        for c in joint
            Θ = physical(c); w0 = weights(c) ./ sum(weights(c))
            r = ones(length(w0))
            for nm in angles; r .*= alt_ratio(c, nm, Θ); end
            w = w0 .* r
            push!(dz, log(sum(w)))               # ln Z_alt - ln Z = ln E_post[r]
            w ./= sum(w)
            s23 = sin.(view(Θ, idx(c, :θ₂₃), :)) .^ 2
            push!(pups, sum(w .* (s23 .> 0.5)))
            push!(m23, wmedian(s23, w)); push!(m12, wmedian(sin.(view(Θ, idx(c, :θ₁₂), :)) .^ 2, w))
            push!(m13, wmedian(sin.(2 .* view(Θ, idx(c, :θ₁₃), :)) .^ 2, w))
        end
        push!(ps, (String(ord), label, mean(pups), (maximum(pups) - minimum(pups)) / 2, mean(m23), mean(m12), mean(m13), mean(dz)))
    end
end
CSV.write(joinpath(TABLES, "prior_sensitivity.csv"), ps)
show(ps; allrows = true, allcols = true); println()

# ---------------------------------------------------------------- figure: who measures what
function bw_silverman(x, ne)
    s = min(std(x), iqr(x) / 1.34); s <= 0 && (s = std(x))
    return 0.9 * s * max(ne, 10.0)^(-0.2)
end
function pooled_eq(sel::Vector{Cell}, N, rng)
    parts = Matrix{Float64}[]
    for c in sel
        push!(parts, physical(c, resample_to_equal_weight(c.mr.samples, weights(c), cld(N, length(sel)); rng = rng)))
    end
    return hcat(parts...), sum(neff(c.mr) for c in sel), sel[1]
end
function fig_subsets(ordering)
    set_pub_theme!(class = :wide)
    W, _ = figure_size(:wide, :conv)
    fig = Figure(size = (W, 0.56W))
    rng = MersenneTwister(7)
    groups = [(s, [c for c in cells if c.subset == s && c.ordering === ordering]) for s in ("da", "ka", "mi", "dakami")]
    groups = [(s, g) for (s, g) in groups if !isempty(g)]
    isempty(groups) && return nothing
    pooled = Dict(s => pooled_eq(g, 60_000, rng) for (s, g) in groups)
    axes = Axis[]
    for (k, nm) in enumerate(OSC)
        r, cidx = divrem(k - 1, 3) .+ (1, 1)
        c0 = groups[1][2][1]
        k0 = idx(c0, nm); lo, hi = c0.lo[k0] * scale_of(nm), c0.hi[k0] * scale_of(nm)
        # explicit ticks where a boundary tick of one panel would touch its neighbour's
        xt = nm === :Δm²₂₁ ? [7.0, 7.5, 8.0, 8.5] :
             nm === :Δm²₃₁ ? (lo < 0 ? [-2.75, -2.5, -2.25] : [2.25, 2.5, 2.75]) :
             nm === :θ₁₃ ? [0.125, 0.15, 0.175] :
             nm === :δCP ? ([0.0, π, 2π], ["0", "π", "2π"]) : WilkinsonTicks(5)
        ax = Axis(fig[r, cidx]; xlabel = LBL[nm], yticklabelsvisible = false, yticksvisible = false, xticks = xt)
        standard_axis!(ax); push!(axes, ax)
        ymax = 0.0
        for (s, _) in groups
            Θ, ne, c = pooled[s]
            x = view(Θ, idx(c, nm), :) .* scale_of(nm)
            kd = kde(x; boundary = (lo, hi), npoints = 512, bandwidth = bw_silverman(x, ne))
            lines!(ax, kd.x, kd.density; color = EXP_COLOR[s], linewidth = s == "dakami" ? 1.8 : 1.2,
                   linestyle = s == "dakami" ? :solid : :dash, label = EXP_NAME[s])
            ymax = max(ymax, maximum(kd.density))
        end
        hlines!(ax, [1 / (hi - lo)]; PRIOR_STYLE..., label = "flat prior")
        xlims!(ax, lo, hi); ylims!(ax, 0, 1.12 * ymax)
    end
    Legend(fig[3, 1:3], axes[1]; orientation = :horizontal, nbanks = 1, framevisible = false, labelsize = 7,
           padding = (0, 0, 0, 0), tellwidth = false, tellheight = true, colgap = 12)
    Label(fig[0, 1:3], "$(uppercasefirst(ord_word(ordering))): single-experiment fits (B = 5×10⁴) and the joint fit (B = 5×10⁵)";
          fontsize = 9, font = :regular, tellwidth = false)
    Label(fig[1:2, 0], "posterior density (arbitrary units)"; rotation = π / 2, fontsize = 8, tellheight = false)
    colgap!(fig.layout, 14); rowgap!(fig.layout, 4)
    return fig
end
for ord in (:NO, :IO)
    f = fig_subsets(ord); f === nothing || save_pdf(f, "nu_subsets_$(ord)"; dir = FIGS)
end

# ---------------------------------------------------------------- figure: origin of the ordering preference
# Two panels (NO, IO), the |Δm²₃₁| marginals of Daya Bay alone, MINOS alone and
# the joint fit, normalized to peak. The whole mass-ordering result in one
# picture: the two single-experiment measurements sit closer together under
# the NO, and the pair's Bayes factor is printed from subset_study.csv.
function fig_mechanism()
    set_pub_theme!(class = :wide)
    W, _ = figure_size(:wide, :conv)
    fig = Figure(size = (W, 0.46W))
    rng = MersenneTwister(11)
    axes = Axis[]
    for (p, ordering) in enumerate((:NO, :IO))
        groups = [(s, [c for c in cells if c.subset == s && c.ordering === ordering]) for s in ("da", "mi", "dakami")]
        any(isempty(g) for (_, g) in groups) && return nothing
        ax = Axis(fig[1, p]; xlabel = L"|\Delta m^2_{31}|\;[10^{-3}\,\mathrm{eV}^2]",
                  ylabel = p == 1 ? "density" : "",
                  yticklabelsvisible = false, yticksvisible = false, xticks = 2.2:0.1:2.7,
                  title = ord_word(ordering), titlefont = :regular, titlesize = 8)
        standard_axis!(ax); push!(axes, ax)
        c0 = groups[1][2][1]; k0 = idx(c0, :Δm²₃₁)
        lo, hi = sort(abs.([c0.lo[k0], c0.hi[k0]]) .* 1e3)
        stats = String[]
        for (s, g) in groups
            Θ, ne, c = pooled_eq(g, 60_000, rng)
            x = abs.(view(Θ, idx(c, :Δm²₃₁), :)) .* 1e3
            kd = kde(x; boundary = (lo, hi), npoints = 512, bandwidth = bw_silverman(x, ne))
            lines!(ax, kd.x, kd.density ./ maximum(kd.density); color = EXP_COLOR[s],
                   linewidth = s == "dakami" ? 1.8 : 1.2, linestyle = s == "dakami" ? :solid : :dash,
                   label = EXP_NAME[s])
            q = quantile(x, [0.16, 0.5, 0.84])
            up, dn = q[3] - q[2], q[2] - q[1]
            err = abs(up - dn) < 0.005 ? @sprintf("± %.2f", (up + dn) / 2) : @sprintf("(+%.2f −%.2f)", up, dn)
            s == "dakami" || push!(stats, "$(s == "da" ? "Daya Bay" : "MINOS"): $(@sprintf("%.2f", q[2])) $err")
        end
        text!(ax, 0.03, 0.97; text = join(stats, "\n"), space = :relative, align = (:left, :top), fontsize = 7)
        xlims!(ax, 2.15, 2.75); ylims!(ax, 0, 1.55)
    end
    linkyaxes!(axes...)
    row = summ[(summ.subset .== "dami") .& (summ.ordering .== "NO"), :]
    lnb = nrow(row) == 1 ? row.lnB_NO_IO[1] : NaN
    Label(fig[0, 1:2], "Origin of the mass-ordering preference: Daya Bay + MINOS alone give ln B(NO/IO) = $(@sprintf("%.2f", lnb))\n" *
                       "because their two |Δm²₃₁| measurements sit closer together under the normal ordering";
          fontsize = 8, font = :regular, tellwidth = false, justification = :center)
    Legend(fig[2, 1:2], axes[1]; orientation = :horizontal, nbanks = 1, framevisible = false, labelsize = 7,
           padding = (0, 0, 0, 0), tellwidth = false, tellheight = true, colgap = 14)
    colgap!(fig.layout, 12); rowgap!(fig.layout, 4)
    return fig
end
f = fig_mechanism(); f === nothing || save_pdf(f, "nu_ordering_mechanism"; dir = FIGS)
println("SUBSET-STUDY-DONE")

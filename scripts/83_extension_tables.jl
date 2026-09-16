# =============================================================================
# 83_extension_tables.jl — LaTeX table fragments for the extension "Towards a
# global fit" (Daya Bay + KamLAND + MINOS + IceCube DeepCore, d = 24, NO).
# =============================================================================
#
#   julia --project=. scripts/83_extension_tables.jl [--ext out_extension_nseed8]
#         [--ext-proto out_extension] [--B 5e5]
#
# Prerequisites: 20_aggregate.jl has been run on the campaign tree (out/) and,
# with --tag nu_dakamide_, on <ext> (n_seed = 8 MoleWhacker cells + copies of the
# two MH reference chains, B = 2.5e5 each, seeds 11 and 23) and on <ext-proto>
# (the 30-seed protocol cell + the MH chains):
#   julia --project=. scripts/20_aggregate.jl --out out_extension_nseed8 --tag nu_dakamide_
#   julia --project=. scripts/20_aggregate.jl --out out_extension --tag nu_dakamide_
#
# Writes to <ext>/tables/:
#   tab_nu_ext_physics.tex    oscillation observables: three vs four experiments
#                             (MoleWhacker pooled, MH reference), IceCube, NuFIT 6.0
#   tab_nu_ext_samplers.tex   MoleWhacker (n_seed = 8, three seeds, T_max = 20), MH,
#                             and the MoleWhacker protocol cell (30 seeds) at
#                             d = 24: cost, wall time, N_eff, efficiency,
#                             agreement, ln Z, plus seed-phase cost and iterations
#   ext_summary.csv           the numbers behind both tables plus the cube ->
#                             physical evidence shift for the d = 24 prior box
include(joinpath(@__DIR__, "40_tables.jl"))   # formatting helpers, published values; main() guarded
using Distributions
include(joinpath(@__DIR__, "..", "harness", "experiments", "src", "ExperimentsBase.jl"))
using .ExperimentsBase

const EXT = let i = findfirst(==("--ext"), ARGS); i === nothing ? joinpath(@__DIR__, "..", "out_extension_nseed8") : ARGS[i+1] end
const EXT_PROTO = let i = findfirst(==("--ext-proto"), ARGS); i === nothing ? joinpath(@__DIR__, "..", "out_extension") : ARGS[i+1] end
const T3 = TABLES                       # three-experiment tables (out/tables)
const T4 = joinpath(EXT, "tables")      # four-experiment tables
const TP = joinpath(EXT_PROTO, "tables") # protocol cell (30 seeds) + original MH cell

readcsv(dir, name) = let p = joinpath(dir, name); isfile(p) ? CSV.read(p, DataFrame) : nothing end

# Budget of the MH reference rows in an aggregated table: at d = 24 the
# reference is two chains of B = 2.5e5 (seeds 11 and 23) that 20_aggregate.jl
# pools (physics.csv row with n_seeds = 2; agreement.csv leave-one-chain-out for
# the MH rows themselves), so MH rows carry B = 2.5e5 while the MoleWhacker
# rows carry B = BTOP. Falls back to BTOP when a table has no MH row.
function mh_B(df)
    (df === nothing || !("alg" in names(df)) || !any(df.alg .== "mh")) && return BTOP
    return maximum(df.B[df.alg .== "mh"])
end
B_of(df, alg) = alg == "mh" ? mh_B(df) : BTOP

# cube -> physical evidence shift of the d = 24 prior box (sum over the
# Gaussian-pull parameters, as in 74_subset_study.jl), from one cell's metadata
function logz_phys_shift(runs)
    isdir(runs) || return NaN
    for name in sort(readdir(runs))
        startswith(name, "nu_dakamide_") || continue
        isfile(joinpath(runs, name, "metadata.json")) || continue
        pc = read_metadata_json(joinpath(runs, name))["problem"]["config"]
        lo, hi = Float64.(pc["lo"]), Float64.(pc["hi"])
        _f(x) = x === nothing ? Inf : Float64(x)
        mu, sd = _f.(pc["gauss_mu"]), _f.(pc["gauss_sd"])
        s = 0.0
        for k in eachindex(lo)
            isfinite(sd[k]) || continue
            Ck = cdf(Normal(), (hi[k] - mu[k]) / sd[k]) - cdf(Normal(), (lo[k] - mu[k]) / sd[k])
            s += log((hi[k] - lo[k]) / (sqrt(2π) * sd[k] * Ck))
        end
        return s
    end
    return NaN
end

# ---------------------------------------------------------------- physics table
function table_ext_physics(phys3, phys4)
    pick(phys, alg) = let s = phys === nothing ? DataFrame() : phys[(phys.ordering .== "NO") .& (phys.alg .== alg) .& (phys.B .== B_of(phys, alg)), :]
        nrow(s) == 0 ? nothing : s[1, :]
    end
    r3, r4, rh = pick(phys3, "mw"), pick(phys4, "mw"), pick(phys4, "mh")
    r4 === nothing && return nothing
    cell(r, key; scale = 1.0) = r === nothing ? "--" : fmt_q(r, key; scale = scale)
    nufit_s22 = convert_pub(NUFIT.sin2_theta13_NO, s -> 4s * (1 - s))
    nufit_dm32 = PubValue(NUFIT.dm31_NO.value - DM21_NUFIT, NUFIT.dm31_NO.err_lo, NUFIT.dm31_NO.err_hi)
    pup(r) = r === nothing ? "--" : @sprintf("%.2f", r.P_upper_octant)
    rows = [
        ("\\(\\sin^2\\theta_{23}\\)", cell(r3, "sin2_th23"), cell(r4, "sin2_th23"), cell(rh, "sin2_th23"),
            fmt_pub(DEEPCORE.sin2_theta23_NO), fmt_pub(NUFIT.sin2_theta23_NO)),
        ("\\(\\Delta m^2_{32}\\;[10^{-3}\\,\\mathrm{eV}^2]\\)", cell(r3, "dm32"; scale = 1e3), cell(r4, "dm32"; scale = 1e3), cell(rh, "dm32"; scale = 1e3),
            fmt_pub(DEEPCORE.dm32_NO; scale = 1e3), fmt_pub(nufit_dm32; scale = 1e3)),
        ("\\(P(\\theta_{23} > \\pi/4)\\)", pup(r3), pup(r4), pup(rh), "--", "--"),
        ("\\(\\sin^2 2\\theta_{13}\\)", cell(r3, "sin2_2th13"), cell(r4, "sin2_2th13"), cell(rh, "sin2_2th13"), "--", fmt_pub(nufit_s22)),
        ("\\(\\Delta m^2_{21}\\;[10^{-5}\\,\\mathrm{eV}^2]\\)", cell(r3, "dm21"; scale = 1e5), cell(r4, "dm21"; scale = 1e5), cell(rh, "dm21"; scale = 1e5), "--", fmt_pub(NUFIT.dm21; scale = 1e5)),
        ("\\(\\sin^2\\theta_{12}\\)", cell(r3, "sin2_th12"), cell(r4, "sin2_th12"), cell(rh, "sin2_th12"), "--", fmt_pub(NUFIT.sin2_theta12)),
    ]
    io_ = IOBuffer()
    println(io_, "\\begin{tabular}{@{}llllll@{}}")
    println(io_, "  \\toprule")
    println(io_, "  Observable & three exp., \\mw{} & four exp., \\mw{} & four exp., \\mh{} & IceCube & NuFIT 6.0 \\\\")
    println(io_, "  \\midrule")
    for r in rows
        println(io_, "  ", join(r, " & "), " \\\\")
    end
    println(io_, "  \\bottomrule")
    println(io_, "\\end{tabular}")
    return String(take!(io_))
end

# ---------------------------------------------------------------- sampler table
fmt_h(s) = @sprintf("%.1f", s / 3600)
fmt_lz(v) = isempty(v) || all(isnan.(v)) ? "--" :
            (length(v) > 1 ? @sprintf("\\(%.2f \\pm %.2f\\)", mean(v), std(v)) : @sprintf("\\(%.2f\\)", v[1]))
# Seed phase and loop of the MoleWhacker cells of one output root, from the
# metadata: the number of seeds actually fitted, the cost consumed up to and
# including iteration 0 (seed phase + the first 2000 importance draws), the
# number of whacking iterations, and the stop reason.
function mw_seed_phase(runs)
    out = DataFrame(seed = Int[], n_seed = Int[], cost_iter0 = Float64[], iterations = Int[], stop = String[])
    isdir(runs) || return out
    for name in sort(readdir(runs))
        (startswith(name, "nu_dakamide_NO_mw_") && isfile(joinpath(runs, name, "metadata.json"))) || continue
        (isfile(joinpath(runs, name, "result.h5")) && filesize(joinpath(runs, name, "result.h5")) > 0) || continue
        meta = read_metadata_json(joinpath(runs, name))
        tun = meta["algorithm"]["tuning"]
        il = get(tun, "iter_log", nothing)
        c0 = (il === nothing || isempty(il)) ? NaN : Float64(il[1]["cum_cost"])
        nit = (il === nothing || isempty(il)) ? 0 : Int(il[end]["iter"])
        push!(out, (Int(meta["seed"]), Int(get(tun, "n_seed_used", 0)), c0, nit, string(get(tun, "stop_reason", ""))))
    end
    return out
end

function table_ext_samplers(cells4, agree4, cellsP, fresh, seeds4, seedsP)
    io_ = IOBuffer()
    println(io_, "\\begin{tabular}{@{}lrrrrrrrrrrl@{}}")
    println(io_, "  \\toprule")
    println(io_, "  Sampler & seeds & \\(n_{\\mathrm{seed}}\\) & seed phase & \\(T\\) & \\(\\Nlike\\) used & wall [h] & \\(\\neff\\) & \\(\\neff/\\Nlike\\) & \\(\\overline{W}_1\\) & \\(\\ln\\evidence\\) (cloud) & fresh: \\(\\ln\\evidence\\), eff. \\\\")
    println(io_, "  \\midrule")
    function row(label, s, a, fr, sp)
        nrow(s) == 0 && return
        w1 = (a === nothing || nrow(a) == 0) ? "--" : @sprintf("%.3f", median(a.W1_avg))
        lz = fmt_lz(s.logZ)
        fz = (fr === nothing || nrow(fr) == 0) ? "--" : fmt_lz(fr.fresh_logZ)
        fe = (fr === nothing || nrow(fr) == 0) ? "--" : "\\(" * replace(sci(median(fr.fresh_eff); digits = 1), r"e-0*(\d+)" => s" \\times 10^{-\1}") * "\\)"   # per-draw efficiency of the fresh check, same format as eta
        ne = median(s.neff)
        nstr = ne >= 100 ? @sprintf("%.0f", ne) : @sprintf("%.1f", ne)
        ns = (sp === nothing || nrow(sp) == 0) ? "--" : string(maximum(sp.n_seed))
        c0 = (sp === nothing || nrow(sp) == 0 || all(isnan.(sp.cost_iter0))) ? "--" : "\\(" * fmt_cost(median(filter(!isnan, sp.cost_iter0))) * "\\)"
        it = (sp === nothing || nrow(sp) == 0) ? "--" : (length(unique(sp.iterations)) == 1 ? string(sp.iterations[1]) : "$(minimum(sp.iterations))--$(maximum(sp.iterations))")
        println(io_, "  ", label, " & ", nrow(s), " & ", ns, " & ", c0, " & ", it, " & \\(", fmt_cost(median(s.Nlike_used)), "\\) & ", fmt_h(median(s.wall_time_s)), " & ", nstr,
                " & \\(", replace(sci(median(s.eta); digits = 1), r"e-0*(\d+)" => s" \\times 10^{-\1}"), "\\) & ", w1, " & ", lz,
                " & ", fz, (fz == "--" ? "" : ", " * fe), " \\\\")
    end
    sel(cells, alg) = cells === nothing ? DataFrame() : cells[(cells.ordering .== "NO") .& (cells.alg .== alg) .& (cells.B .== B_of(cells, alg)), :]
    sela(agree, alg) = agree === nothing ? nothing : agree[(agree.ordering .== "NO") .& (agree.alg .== alg) .& (agree.B .== B_of(agree, alg)), :]
    self(kind) = fresh === nothing ? nothing : fresh[fresh.kind .== kind, :]
    row("\\mw{}, \\(n_{\\mathrm{seed}} = 8\\), \\(\\Tmax = 20\\)", sel(cells4, "mw"), sela(agree4, "mw"), self("nseed8"), seeds4)
    row("\\mw{}, protocol seed count", sel(cellsP, "mw"), sela(readcsv(TP, "agreement.csv"), "mw"), self("protocol30"), seedsP)
    # MH: one row per chain is pooled into per-chain medians ("seeds" = number of
    # chains); the W1 column is the leave-one-chain-out distance between the chains
    row("\\mh{} (reference)", sel(cells4, "mh"), sela(agree4, "mh"), nothing, nothing)
    println(io_, "  \\bottomrule")
    println(io_, "\\end{tabular}")
    return String(take!(io_))
end

function main_ext()
    mkpath(T4)
    phys3, phys4 = readcsv(T3, "physics.csv"), readcsv(T4, "physics.csv")
    cells4, agree4 = readcsv(T4, "cells.csv"), readcsv(T4, "agreement.csv")
    cellsP = readcsv(TP, "cells.csv")          # protocol cell (30 seeds), aggregated in its own root
    fresh = readcsv(T4, "fresh.csv")           # 81_extension_fresh.jl (optional)
    seeds4, seedsP = mw_seed_phase(joinpath(EXT, "runs")), mw_seed_phase(joinpath(EXT_PROTO, "runs"))
    cells4 === nothing && error("no four-experiment tables in $(T4); run 20_aggregate.jl --out $(EXT) --tag nu_dakamide_ first")
    for (name, tab) in (("tab_nu_ext_physics.tex", table_ext_physics(phys3, phys4)),
                        ("tab_nu_ext_samplers.tex", table_ext_samplers(cells4, agree4, cellsP, fresh, seeds4, seedsP)))
        tab === nothing && (@warn "table skipped" name; continue)
        write(joinpath(T4, name), tab)
        println("--- ", name, " ---"); print(tab)
    end
    shift = logz_phys_shift(joinpath(EXT, "runs"))
    s = DataFrame(quantity = String[], value = Float64[], note = String[])
    push!(s, ("logZ_phys_shift", shift, "ln Z_phys = ln Z_cube + shift (sum over Gaussian-pull parameters of the d = 24 box)"))
    for r in eachrow(cells4)      # MoleWhacker cells at BTOP and the MH chains at 2.5e5
        push!(s, ("logZ_cube_$(r.alg)_seed$(r.seed)", r.logZ, "pooled-cloud estimate"))
        push!(s, ("logZ_phys_$(r.alg)_seed$(r.seed)", r.logZ + shift, "physical units"))
        push!(s, ("neff_$(r.alg)_seed$(r.seed)", r.neff, "")); push!(s, ("wall_h_$(r.alg)_seed$(r.seed)", r.wall_time_s / 3600, ""))
    end
    for (tag, sp) in (("nseed8", seeds4), ("protocol30", seedsP)), r in eachrow(sp)
        push!(s, ("$(tag)_n_seed_seed$(r.seed)", r.n_seed, "seeds fitted (n_seed_used)"))
        push!(s, ("$(tag)_cost_iter0_seed$(r.seed)", r.cost_iter0, "cost after iteration 0 = seed phase + 2000 IS draws"))
        push!(s, ("$(tag)_cost_per_seed_seed$(r.seed)", (r.cost_iter0 - 2000) / max(r.n_seed, 1), "(cost_iter0 - 2000) / n_seed"))
        push!(s, ("$(tag)_iterations_seed$(r.seed)", r.iterations, "whacking iterations; stop = $(r.stop)"))
    end
    if cellsP !== nothing
        for r in eachrow(cellsP[cellsP.alg .== "mw", :])
            push!(s, ("protocol30_logZ_cube_$(r.alg)_seed$(r.seed)", r.logZ, "pooled-cloud estimate, protocol cell"))
            push!(s, ("protocol30_neff_$(r.alg)_seed$(r.seed)", r.neff, "")); push!(s, ("protocol30_wall_h_$(r.alg)_seed$(r.seed)", r.wall_time_s / 3600, ""))
        end
    end
    CSV.write(joinpath(T4, "ext_summary.csv"), s)
    println(s)
    println("EXT-TABLES-DONE")
end

if abspath(PROGRAM_FILE) == @__FILE__
    main_ext()
end

# =============================================================================
# 40_tables.jl â€” LaTeX table fragments for the neutrino chapter, generated
# from the CSV tables written by 20_aggregate.jl.
# =============================================================================
#
#   julia --project=. scripts/40_tables.jl [--out out] [--B 5e5]
#
# Writes to <out>/tables/:
#   tab_nu_physics.tex    posterior medians / 68 % intervals vs published values
#   tab_nu_samplers.tex   per-sampler cost, ESS, efficiency, agreement, ln Z
#   tab_nu_evidence.tex   ln Z per method and ordering with the NO/IO Bayes factor
#   tab_nu_priors.tex     parameter / prior table
# Fragments are tabular environments only (no table float), matching the
# thesis conventions (booktabs, \( \) math, \footnotesize set by the caller).
import Pkg
Pkg.activate(joinpath(@__DIR__, ".."))
using Printf, Statistics, DataFrames, CSV
include(joinpath(@__DIR__, "..", "src", "published_values.jl"))

const OUT = let i = findfirst(==("--out"), ARGS); i === nothing ? joinpath(@__DIR__, "..", "out") : ARGS[i+1] end
const BTOP = let i = findfirst(==("--B"), ARGS); i === nothing ? 5e5 : parse(Float64, ARGS[i+1]) end
const TABLES = joinpath(OUT, "tables")

# ---------------------------------------------------------------- formatting
# value with asymmetric errors, rounded to two significant digits of the
# smaller error; `scale` multiplies all three numbers first.
function fmt_asym(v, elo, ehi; scale = 1.0)
    v, elo, ehi = v * scale, elo * scale, ehi * scale
    e = min(abs(elo), abs(ehi))
    e <= 0 && return @sprintf("%.3g", v)
    digits = max(0, 1 - floor(Int, log10(e)))          # two significant digits of the error
    f(x) = @sprintf("%.*f", digits, x)
    if abs(elo - ehi) < 0.05 * e
        return "\\(" * f(v) * " \\pm " * f(e) * "\\)"
    end
    return "\\(" * f(v) * "^{+" * f(ehi) * "}_{-" * f(elo) * "}\\)"
end
fmt_pub(pv::PubValue; scale = 1.0) = fmt_asym(pv.value, pv.err_lo, pv.err_hi; scale = scale)

# 68 % interval from the q16/q50/q84 columns of physics.csv
function fmt_q(row, key; scale = 1.0)
    v = row[Symbol(key, "_q50")]; lo = row[Symbol(key, "_q16")]; hi = row[Symbol(key, "_q84")]
    return fmt_asym(v, v - lo, hi - v; scale = scale)
end

sci(x; digits = 2) = @sprintf("%.*e", digits, x)
function fmt_cost(x)
    x >= 1e6 && return @sprintf("%.2f\\,\\mathrm{M}", x / 1e6)
    x >= 1e3 && return @sprintf("%.0f\\,\\mathrm{k}", x / 1e3)
    return @sprintf("%.0f", x)
end
fmt_B(B) = "\\(" * replace(@sprintf("%.0e", B), r"e\+?0*(\d+)" => s" \\times 10^{\1}") * "\\)"

# ---------------------------------------------------------------- physics table
function table_physics(phys)
    pick(ord) = let s = phys[(phys.ordering .== String(ord)) .& (phys.alg .== "mw") .& (phys.B .== BTOP), :]
        nrow(s) == 0 ? nothing : s[1, :]
    end
    no, io = pick(:NO), pick(:IO)
    no === nothing && return nothing
    cell(r, key; scale = 1.0) = r === nothing ? "--" : fmt_q(r, key; scale = scale)
    nufit_s22 = convert_pub(NUFIT.sin2_theta13_NO, s -> 4s * (1 - s))
    nufit_t2 = convert_pub(NUFIT.sin2_theta12, s -> s / (1 - s))
    nufit_dm32 = PubValue(NUFIT.dm31_NO.value - DM21_NUFIT, NUFIT.dm31_NO.err_lo, NUFIT.dm31_NO.err_hi)
    rows = [
        ("\\(\\sin^2 2\\theta_{13}\\)", cell(no, "sin2_2th13"), cell(io, "sin2_2th13"),
            "Daya Bay " * fmt_pub(DAYABAY.sin2_2theta13), fmt_pub(nufit_s22)),
        ("\\(\\Delta m^2_{32}\\;[10^{-3}\\,\\mathrm{eV}^2]\\)", cell(no, "dm32"; scale = 1e3), cell(io, "dm32"; scale = 1e3),
            "Daya Bay " * fmt_pub(DAYABAY.dm32_NO; scale = 1e3) * " (NO), " * fmt_pub(DAYABAY.dm32_IO; scale = 1e3) * " (IO); MINOS+ " * fmt_pub(MINOS.dm32_NO; scale = 1e3) * " (NO)",
            fmt_pub(nufit_dm32; scale = 1e3) * " (NO), " * fmt_pub(NUFIT.dm32_IO; scale = 1e3) * " (IO)"),
        ("\\(\\Delta m^2_{21}\\;[10^{-5}\\,\\mathrm{eV}^2]\\)", cell(no, "dm21"; scale = 1e5), cell(io, "dm21"; scale = 1e5),
            "KamLAND " * fmt_pub(KAMLAND.dm21; scale = 1e5), fmt_pub(NUFIT.dm21; scale = 1e5)),
        ("\\(\\tan^2\\theta_{12}\\)", cell(no, "tan2_th12"), cell(io, "tan2_th12"),
            "KamLAND " * fmt_pub(KAMLAND.tan2_theta12), fmt_pub(nufit_t2)),
        ("\\(\\sin^2\\theta_{12}\\)", cell(no, "sin2_th12"), cell(io, "sin2_th12"), "--", fmt_pub(NUFIT.sin2_theta12)),
        ("\\(\\sin^2\\theta_{23}\\)", cell(no, "sin2_th23"), cell(io, "sin2_th23"),
            "MINOS+ " * fmt_pub(MINOS.sin2_theta23_NO) * " (NO), " * fmt_pub(MINOS.sin2_theta23_IO) * " (IO)",
            fmt_pub(NUFIT.sin2_theta23_NO) * " (NO), " * fmt_pub(NUFIT.sin2_theta23_IO) * " (IO)"),
        ("\\(P(\\theta_{23} > \\pi/4)\\)", @sprintf("%.2f", no.P_upper_octant), io === nothing ? "--" : @sprintf("%.2f", io.P_upper_octant), "--", "--"),
    ]
    io_ = IOBuffer()
    println(io_, "\\begin{tabular}{@{}lllll@{}}")
    println(io_, "  \\toprule")
    println(io_, "  Observable & This fit (NO) & This fit (IO) & Published & NuFIT 6.0 \\\\")
    println(io_, "  \\midrule")
    for r in rows
        println(io_, "  ", join(r, " & "), " \\\\")
    end
    println(io_, "  \\bottomrule")
    println(io_, "\\end{tabular}")
    return String(take!(io_))
end

# ---------------------------------------------------------------- sampler table
const ALG_NAME = Dict("mw" => "MoleWhacker", "mh" => "MH", "nuts" => "NUTS", "ns" => "NS", "is" => "IS")
const ALG_ORDER = ["mw", "mh", "nuts", "ns", "is"]
const STOP_TEX = Dict("T_max" => "\\(T_{\\max}\\)", "budget" => "budget", "dlogz" => "\\(\\Delta\\ln\\evidence\\)",
                      "Neff" => "\\(\\neff\\)")
stop_tex(s) = get(STOP_TEX, String(s), replace(String(s), "_" => "\\_"))

function table_samplers(cells, agree)
    io_ = IOBuffer()
    println(io_, "\\begin{tabular}{@{}llrrrrrl@{}}")
    println(io_, "  \\toprule")
    println(io_, "  Sampler & budget & \\(\\Nlike\\) used & \\(\\neff\\) & \\(\\neff/\\Nlike\\) & \\(\\overline{W}_1\\) & \\(\\ln\\evidence\\) & stop \\\\")
    println(io_, "  \\midrule")
    for ord in ("NO", "IO")
        sub_o = cells[cells.ordering .== ord, :]
        nrow(sub_o) == 0 && continue
        println(io_, "  \\multicolumn{8}{@{}l}{\\emph{", ord == "NO" ? "normal" : "inverted", " ordering}} \\\\")
        for B in sort(unique(sub_o.B)), alg in ALG_ORDER
            s = sub_o[(sub_o.alg .== alg) .& (sub_o.B .== B), :]
            nrow(s) == 0 && continue
            a = agree[(agree.ordering .== ord) .& (agree.alg .== alg) .& (agree.B .== B), :]
            w1 = nrow(a) == 0 ? "--" : @sprintf("%.3f", median(a.W1_avg))
            lz = all(isnan.(s.logZ)) ? "--" :
                 (nrow(s) > 1 ? @sprintf("\\(%.2f \\pm %.2f\\)", mean(s.logZ), std(s.logZ)) : @sprintf("\\(%.2f\\)", s.logZ[1]))
            ne = median(s.neff)
            nstr = ne >= 100 ? @sprintf("%.0f", ne) : @sprintf("%.1f", ne)
            println(io_, "  ", ALG_NAME[alg], " & ", fmt_B(B), " & \\(", fmt_cost(median(s.Nlike_used)), "\\) & ", nstr,
                    " & \\(", replace(sci(median(s.eta); digits = 1), r"e-0*(\d+)" => s" \\times 10^{-\1}"), "\\) & ", w1, " & ", lz,
                    " & ", join(stop_tex.(unique(s.stop)), "/"), nrow(s) > 1 ? " (\\(n=$(nrow(s))\\))" : "", " \\\\")
        end
        ord == "NO" && println(io_, "  \\midrule")
    end
    println(io_, "  \\bottomrule")
    println(io_, "\\end{tabular}")
    return String(take!(io_))
end

# ---------------------------------------------------------------- evidence table
function table_evidence(ev, bf; check = nothing, cells = nothing)
    io_ = IOBuffer()
    println(io_, "\\begin{tabular}{@{}llrrr@{}}")
    println(io_, "  \\toprule")
    println(io_, "  Method & budget & \\(\\ln\\evidence_{\\mathrm{NO}}\\) & \\(\\ln\\evidence_{\\mathrm{IO}}\\) & \\(\\ln K_{\\mathrm{NO/IO}}\\) \\\\")
    println(io_, "  \\midrule")
    # reference: defensive kernel-mixture IS anchored on the pooled MH chains (70_evidence_check.jl)
    if check !== nothing
        a = check[check.method .== "anchored_is", :]
        if nrow(a) > 0
            g(ord) = (s = a[a.ord .== ord, :]; (mean(s.logZ), max(maximum(s.se), nrow(s) > 1 ? (maximum(s.logZ) - minimum(s.logZ)) / 2 : 0.0)))
            zno, eno = g("NO"); zio, eio = g("IO")
            println(io_, "  Reference: defensive IS on pooled MH & ", @sprintf("\\(%.1f\\times 10^{5}\\)", a.N[1] / 1e5), "\\(^{\\dagger}\\) & ",
                    @sprintf("\\(%.2f \\pm %.2f\\)", zno, eno), " & ", @sprintf("\\(%.2f \\pm %.2f\\)", zio, eio), " & ",
                    @sprintf("\\(%.2f \\pm %.2f\\)", zno - zio, hypot(eno, eio)), " \\\\")
            println(io_, "  \\midrule")
        end
    end
    for alg in ("mw", "ns", "is"), B in sort(unique(ev.B))
        no = ev[(ev.alg .== alg) .& (ev.B .== B) .& (ev.ordering .== "NO"), :]
        io = ev[(ev.alg .== alg) .& (ev.B .== B) .& (ev.ordering .== "IO"), :]
        (nrow(no) == 0 && nrow(io) == 0) && continue
        f(s) = nrow(s) == 0 ? "--" : nrow(s) > 1 ? @sprintf("\\(%.2f \\pm %.2f\\)", mean(s.logZ), std(s.logZ)) :
               (isnan(s.logZ_se[1]) ? @sprintf("\\(%.2f\\)", s.logZ[1]) : @sprintf("\\(%.2f \\pm %.2f\\)", s.logZ[1], s.logZ_se[1]))
        b = bf[(bf.alg .== alg) .& (bf.B .== B), :]
        k = nrow(b) == 0 ? "--" : (isnan(b.se[1]) ? @sprintf("\\(%.2f\\)", b.lnK_NO_IO[1]) : @sprintf("\\(%.2f \\pm %.2f\\)", b.lnK_NO_IO[1], b.se[1]))
        stop = join(unique(vcat(no.stop, io.stop)), "/")
        println(io_, "  ", ALG_NAME[alg], stop == "dlogz" ? " run to \\(\\Delta\\ln\\evidence < 0.5\\)" : "",
                " & ", stop == "dlogz" && cells !== nothing ?
                    @sprintf("\\(%.1f\\times 10^{5}\\)", mean(cells[(cells.alg .== alg) .& (cells.B .== B), :Nlike_used]) / 1e5) : fmt_B(B),
                " & ", f(no), " & ", f(io), " & ", k, " \\\\")
    end
    println(io_, "  \\bottomrule")
    println(io_, "\\end{tabular}")
    return String(take!(io_))
end

# ---------------------------------------------------------------- prior table
function table_priors()
    rows = [
        ("\\(\\theta_{12}\\)", "\\(\\uniformdist{0.4205}{\\pi/4}\\)", "\\(\\sin^2\\theta_{12}\\in[1/6,\\,1/2]\\)"),
        ("\\(\\theta_{13}\\)", "\\(\\uniformdist{0.10}{0.20}\\)", ""),
        ("\\(\\theta_{23}\\)", "\\(\\uniformdist{\\pi/6}{\\pi/3}\\)", "\\(\\sin^2\\theta_{23}\\in[0.25,\\,0.75]\\), both octants"),
        ("\\(\\delta_{\\mathrm{CP}}\\)", "\\(\\uniformdist{0}{2\\pi}\\)", "not constrained by disappearance data"),
        ("\\(\\Delta m^2_{21}\\)", "\\(\\uniformdist{6.5}{9.0}\\times 10^{-5}\\,\\mathrm{eV}^2\\)", ""),
        ("\\(\\Delta m^2_{31}\\)", "\\(\\uniformdist{2.0}{3.0}\\times 10^{-3}\\,\\mathrm{eV}^2\\) (NO); \\(\\uniformdist{-3.0}{-2.0}\\times 10^{-3}\\,\\mathrm{eV}^2\\) (IO)", "ordering fixes the sign"),
        ("\\(\\epsilon_E^{\\mathrm{KL}}\\)", "\\(\\normaldist{0}{1}\\) on \\([-3,3]\\)", "KamLAND energy scale"),
        ("\\(\\epsilon_\\Phi^{\\mathrm{KL}}\\)", "\\(\\normaldist{0}{1}\\) on \\([-3,3]\\)", "KamLAND reactor flux"),
        ("\\(\\epsilon_{\\mathrm{geo}}^{\\mathrm{KL}}\\)", "\\(\\uniformdist{-0.5}{0.5}\\)", "KamLAND geo-neutrino scale"),
        ("\\(n_{\\mathrm{NC}}\\)", "\\(\\normaldist{1}{0.2^2}\\) on \\([0.4,1.6]\\)", "MINOS NC normalization"),
        ("\\(n_{\\nu_\\tau\\mathrm{CC}}\\)", "\\(\\normaldist{1}{0.2^2}\\) on \\([0.4,1.6]\\)", "MINOS \\(\\nu_\\tau\\) CC normalization"),
    ]
    io_ = IOBuffer()
    println(io_, "\\begin{tabular}{@{}lll@{}}")
    println(io_, "  \\toprule")
    println(io_, "  Parameter & Prior & Note \\\\")
    println(io_, "  \\midrule")
    for (k, r) in enumerate(rows)
        k == 7 && println(io_, "  \\midrule")
        println(io_, "  ", join(r, " & "), " \\\\")
    end
    println(io_, "  \\bottomrule")
    println(io_, "\\end{tabular}")
    return String(take!(io_))
end

function main()
    phys = CSV.read(joinpath(TABLES, "physics.csv"), DataFrame)
    cells = CSV.read(joinpath(TABLES, "cells.csv"), DataFrame)
    agree = CSV.read(joinpath(TABLES, "agreement.csv"), DataFrame)
    ev = CSV.read(joinpath(TABLES, "evidence.csv"), DataFrame)
    bf = CSV.read(joinpath(TABLES, "bayes_factor.csv"), DataFrame)
    chk_path = joinpath(TABLES, "evidence_check.csv")
    check = isfile(chk_path) ? CSV.read(chk_path, DataFrame) : nothing
    for (name, s) in (("tab_nu_physics.tex", table_physics(phys)), ("tab_nu_samplers.tex", table_samplers(cells, agree)),
                      ("tab_nu_evidence.tex", table_evidence(ev, bf; check = check, cells = cells)), ("tab_nu_priors.tex", table_priors()))
        s === nothing && continue
        write(joinpath(TABLES, name), s)
        println("---- ", name, " ----"); print(s)
    end
    println("TABLES-DONE")
end

main()

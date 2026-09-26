# =============================================================================
# 83_extension_iter_title.jl — redraw ONLY the iteration-log figure of the
# four-experiment MoleWhacker cell with n_seed = 8, seed 11 (NO, B = 5e5):
# thesis Fig. B.11, figures/nu__extiter__d24__B5e5__mw__no.pdf.
#
# The v5 asset carried a one-line title that was wider than the figure, so the
# seed label was clipped ("seed 11" read as "seed 1"). This wrapper selects the
# same cell as main_ext in 82_extension_plots.jl, calls the same helper
# (fig_iter_mw_wide, defined in 30_plots.jl) on the same stored iteration log,
# and passes a two-line title. Nothing else is redrawn: the mains of
# 82_extension_plots.jl and 30_plots.jl are guarded and do not run on include.
#
#   julia --project=. -t 1 scripts/83_extension_iter_title.jl [--ext out_extension_nseed8]
#
# Writes out/figs/nu_ext_iter_NO.pdf (and out/figs/png/nu_ext_iter_NO.png).
# =============================================================================
include(joinpath(@__DIR__, "82_extension_plots.jl"))   # infrastructure + load_cells_from; mains guarded

function main_iter_title()
    cells4 = load_cells_from(joinpath(EXT, "runs"), "nu_dakamide_")
    @info "cells" four_experiments = length(cells4)
    selected = [c for c in cells4 if c.ordering === :NO && c.alg === :mw && c.B == BTOP && c.seed == 11]
    @assert length(selected) == 1 "expected exactly one NO / MoleWhacker / B = $(BTOP) / seed 11 cell, found $(length(selected))"
    cell = only(selected)
    title = "Four experiments, normal ordering, B = $(fmt_B_short(BTOP))\nn_seed = 8, seed 11"
    path = save_pdf(fig_iter_mw_wide(cell.mr; title = title), "nu_ext_iter_NO"; dir = FIGS)
    @info "iteration-log figure redrawn" tag = cell.tag alg = cell.alg seed = cell.seed B = cell.B title = title path = path
    println("EXT-ITER-TITLE-DONE")
end

if abspath(PROGRAM_FILE) == @__FILE__
    main_iter_title()
end

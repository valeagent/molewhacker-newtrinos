# HOLD markers (13 Sep 2026)

The two ablation queue processes (`queues/ablation_tmax_NO.txt`,
`queues/ablation_tmax_IO.txt`; one Julia process each, started 12 Sep 16:44)
run the seeds 11, 23, 41 sequentially in one process. Seed 11 finished
(NO 05:09, IO 04:20 on 13 Sep); seed 23 is running.

Seed 41 would start automatically when seed 23 finishes and would run about
twelve hours. Per the instruction of 13 Sep ("no new run longer than three
hours without approval") it is put on hold without touching the running
seed 23:

* `runs/nu_dakami_NO_mw_d11_B5e5_seed41/result.h5` and
  `runs/nu_dakami_IO_mw_d11_B5e5_seed41/result.h5` are **zero-byte
  placeholders**. `scripts/10_run_cell.jl` skips a cell whose `result.h5`
  exists ("cell exists, skipping"), so the queue process ends after seed 23.
* `scripts/73_tmax_study.jl` treats a zero-byte `result.h5` as "not finished"
  (`finished(dir)`), so the placeholders never enter the figure.

A detached chain (`chain_tmax_seed23.ps1`, started 13 Sep 13:21) waits for the
two seed-23 results, then re-runs `73_tmax_study.jl --fresh --finished-only`
and `90_export_thesis.ps1`; it writes `chain_tmax_seed23.done` when finished.

To run seed 41 after approval: delete the two placeholder directories and run

    julia --project=. -t 4 scripts/11_run_queue.jl queues/ablation_tmax_NO.txt --out out_ablation --tmax 100000
    julia --project=. -t 4 scripts/11_run_queue.jl queues/ablation_tmax_IO.txt --out out_ablation --tmax 100000

(seeds 11 and 23 are then skipped because their results exist).

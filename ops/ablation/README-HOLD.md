# Ablation queue notes (13 Sep 2026)

The two ablation queue processes (`queues/ablation_tmax_NO.txt`,
`queues/ablation_tmax_IO.txt`; one Julia process each, started 12 Sep 16:44)
run the seeds 11, 23, 41 sequentially in one process. Seed 11 finished
(NO 05:09, IO 04:20 on 13 Sep); seed 23 is running (ETA 17:30–18:00).

**Seed 41.** Between 13:00 and 15:00 on 13 Sep it was on hold (zero-byte
`result.h5` placeholders in its two run directories, which make
`10_run_cell.jl` skip the cell), pending approval under the "no new run
longer than three hours without approval" rule. Approved at 15:00 and
released (placeholders removed): seed 41 starts automatically in each process
when seed 23 finishes and needs about twelve hours per ordering (ETA 06:00 on
14 Sep). `scripts/73_tmax_study.jl` treats a zero-byte `result.h5` as "not
finished" (`finished(dir)`), so a placeholder can never enter the figure.

**Chains.**

* `chain_tmax_seed23.ps1` (pid 32588) waits for the two seed-23 results,
  then runs `73_tmax_study.jl --fresh --finished-only` and
  `90_export_thesis.ps1`; writes `chain_tmax_seed23.done`.
* `../out_extension/chain_extension.ps1` waits for the two seed-41 results,
  then starts the two lanes of the DeepCore extension
  (`queues/ext_deepcore_<ORD>.txt`, `--out out_extension`), and when both
  lanes are done re-runs the T_max study with seed 41 and the export; writes
  `../out_extension/chain_extension.done`.

# Operations scripts of the campaign (12-16 September 2026)

The PowerShell scripts in this directory launched, chained, paused and
watched the runs of the campaign on the author's laptop. They are kept as a
record of how the results were produced; they are **not** needed to
reproduce them. Reproduction goes through `scripts/11_run_queue.jl` with
the queue files in `queues/` (see the root `README.md`).

The scripts were written and run from their original locations and their
comments and `Start-Process` lines refer to those paths:

| directory here | original location | purpose |
|---|---|---|
| `campaign/` | `scripts/` | wave launchers and orchestrators of the three-experiment campaign (11 Sep); the orchestrator history is described in `docs/NEUTRINO-BRIEFING.md` |
| `ablation/` | `out_ablation/` | chains of the iteration-cap ablation (`--tmax` lifted, seeds 11/23/41 per ordering), the per-iteration wall-clock watcher that wrote `out_ablation/iter_timestamps.csv`, and the hold note |
| `extension/` | `out_extension/` | the DeepCore extension lanes: the original chain, the switch to `n_seed = 8`, the relaunch after the out-of-memory event of 15 Sep, the memory watchdog, the standalone MH host, and the recorded PIDs |
| `pause.cmd`, `resume.cmd`, `status.cmd` | repository root | double-click helpers around `scripts/96_pause_resume.ps1` (OS-level suspend/resume of the julia cells) and `scripts/95_status.ps1` (live status) |

`scripts/run_queue.ps1`, `scripts/95_status.ps1` and `scripts/96_pause_resume.ps1`
stay in `scripts/` because they are generic (any queue, any run).

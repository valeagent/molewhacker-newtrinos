# MoleWhacker on a real neutrino-oscillation problem

Joint three-flavour fit of Daya Bay + KamLAND + MINOS (11 parameters, normal
and inverted ordering) with the likelihoods of Newtrinos.jl, sampled by the
five samplers of the thesis benchmark harness under the same budget protocol.
This repository is self-contained: the benchmark harness and the
thesis-final MoleWhacker implementation are included as verbatim copies
under `harness/` (provenance and SHA-256 hashes in `harness/PROVENANCE.md`),
so a clone plus `Pkg.instantiate()` reproduces every number and figure of
the thesis chapter (`00_setup_env.jl` / `00b_pin_newtrinos.jl` document how
the environment was built and pinned). Nothing in the thesis repository or
in the benchmark repository is modified by anything here.

## Layout

| path | purpose |
|---|---|
| `Project.toml`, `Manifest.toml` | own environment: thesis pins (BAT 4.0.4, MGVI 0.4.x, CairoMakie 0.14, …) + Newtrinos `main` pinned to `fa87689d` |
| `harness/experiments/src/` | verbatim copy of the thesis benchmark harness (module `ExperimentsBase`: cost counter, cube prior, sampler wrappers, metrics, plotting) |
| `harness/scripts2/algo/MoleWhacker.jl` | verbatim copy of the thesis-final MoleWhacker algorithm (`algo_mw.jl` includes it via the unchanged relative path) |
| `harness/PROVENANCE.md` | source paths, copy date and SHA-256 hashes of every copied file |
| `NEUTRINO-BRIEFING.md` | working log: reconnaissance of Newtrinos.jl, design decisions, status entries per day, physics-scope evaluation (§16) |
| `src/neutrino_problem.jl` | adapter: `ConfigNeutrino <: ProblemConfig`, exact affine cube ↔ physical mapping, Gaussian prior factors, `build_log_f`, `physical_summary` |
| `src/published_values.jl` | Daya Bay 2023, KamLAND 2011, MINOS+ 2020, NuFIT 6.0 reference values and conversions |
| `scripts/00_setup_env.jl`, `00b_pin_newtrinos.jl` | environment setup / pin |
| `scripts/01_smoke_harness.jl`, `02_smoke_samplers.jl` | smoke tests (mapping, gradient counting, all five samplers) |
| `scripts/10_run_cell.jl` | one (alg, ordering, B, seed) cell → `out/runs/<tag>_<alg>_d11_B<B>_seed<seed>/{result.h5, metadata.json, summary.json}` |
| `scripts/11_run_queue.jl` | run a queue file sequentially in one process |
| `scripts/run_queue.ps1`, `run_wave1.ps1`, `orchestrate_wave1.ps1` | background launchers (logs in `out/logs/`) |
| `scripts/20_aggregate.jl` | → `out/tables/{cells,physics,agreement,pairs,chains,evidence,bayes_factor}.csv` |
| `scripts/30_plots.jl` | → `out/figs/nu_*.pdf` (+ `png/`) |
| `scripts/40_tables.jl` | → `out/tables/tab_nu_*.tex` (booktabs fragments for the chapter) |
| `scripts/50_profile.jl` | profile-likelihood scans (Newtrinos L-BFGS) → `out/tables/profile_<ORD>_<var>.csv` |
| `scripts/60_primer_figures.jl` | teaching figures for the primer → `out/figs/primer_*.png` (analytic oscillation curves; data vs prediction per experiment at the joint best fit) |
| `scripts/70_evidence_check.jl` | evidence reference: defensive kernel-mixture IS on the pooled MH chains + pooled plain IS → `out/tables/evidence_check.csv` |
| `scripts/71_is_diagnostics.jl` | importance-weight diagnostics (Kish ESS, top-weight shares, Pareto-k̂) for every MW/NS/IS cell → `out/tables/is_diagnostics.csv` |
| `scripts/72_mw_mixture_check.jl` | fresh i.i.d. draws from each stored MoleWhacker mixture: evidence and octant probability of the mixture itself vs the pooled-cloud estimator → `out/tables/mw_mixture_check.csv` |
| `scripts/73_tmax_study.jl` | iteration-cap ablation: MW runs with `--tmax` lifted (`out_ablation/`) against the protocol cells and the other samplers — ESS vs cost, efficiency vs iteration, terminal quantities, optional fresh-draw check → `out/tables/tmax_study.csv`, `tmax_iterlog.csv`, `out/figs/nu_tmax.pdf` (falls back to the stderr log with a "preliminary" banner while a long run is still going) |
| `scripts/74_subset_study.jl` | single-experiment and pairwise fits against the joint fit: marginal overlays (`nu_subsets_<ORD>.pdf`), evidence decomposition, mass-ordering Bayes factor per subset, consistency ratios ln R (Marshall–Rajguru–Slosar) in the physical normalization, prior-sensitivity reweighting of the joint posterior → `out/tables/subset_cells.csv`, `subset_study.csv`, `subset_R.csv`, `prior_sensitivity.csv`; `--fresh` replaces pooled-cloud evidences by fresh-draw ones, `--reuse-fresh` reuses them from the cached `subset_cells.csv` |
| `scripts/80_posterior_predictive.jl` | chapter figure `nu_intro` (oscillation probabilities and the octant degeneracy) and the data figures `nu_data_<ORD>` (observed spectra, posterior-predictive band from the pooled MW cells, no-oscillation expectation) → `out/tables/posterior_predictive_<ORD>.csv` |
| `scripts/90_export_thesis.ps1` | copies the chapter PDFs into the thesis `figures/` directory under the thesis filename convention (`nu__<descriptor>__d<d>__B<budget>__<alg>__<ordering>.pdf`, ordering token lowercase) |
| `queues/*.txt` | campaign cell lists (`alg ordering B seed [experiments]`) |
| `out_ablation/` | own output tree of the `--tmax` ablation runs (never mixed into `out/runs`); `iter_timestamps.csv` is written by `watch_iters.ps1` while the long runs are going; `chain_tmax_study.ps1` runs `73_tmax_study.jl --fresh --finished-only` + `90_export_thesis.ps1` once the seed-11 results exist |
| `CHAPTER-DRAFT.md` | running draft of the chapter text with the current numbers (superseded by the LaTeX chapter on the thesis branch `neutrino-chapter`) |
| `PHYSICS-PRIMER.md` | neutrino oscillations from zero, the three experiments and their Newtrinos likelihoods, the 11-parameter model, the study design and hypotheses |

## Running

All commands are run from the repository root with the repository's own
environment (`--project=.`).

```powershell
julia --project=. -e "import Pkg; Pkg.instantiate()"          # once: exact environment from Manifest.toml (Newtrinos fa87689d)
julia --project=. -t 4 scripts\01_smoke_harness.jl            # smoke test (mapping, gradient counting)
julia --project=. -t 4 scripts\10_run_cell.jl --alg mw --ordering NO --B 5e4 --seed 11
powershell -ExecutionPolicy Bypass -File scripts\run_queue.ps1 -Queue wave2_NO -Threads 2
julia --project=. scripts\20_aggregate.jl
julia --project=. scripts\30_plots.jl
julia --project=. scripts\40_tables.jl
powershell -File scripts\90_export_thesis.ps1 -Thesis <thesis repository>   # copy PDFs into the thesis
```

A cell is finished when its `summary.json` exists (written last). Cells are
skipped if `result.h5` exists (`--force` overrides). `nsref` is nested
sampling run to Δln Z < 0.5 with B as a call cap only; it is stored as
algorithm `ns` under its own budget token.

### What is and is not in git

Tracked: sources, scripts, queues, the environment (`Project.toml`,
`Manifest.toml`), the harness copies, all figures (`out/figs/`), all tables
(`out/tables/`), and the per-cell `metadata.json` / `summary.json` of every
run. Not tracked (`.gitignore`): the per-cell `result.h5` sample files
(`out/runs/`, 0.75 GB; `out_ablation/runs/`, 2.1 GB) and the run logs. The
`result.h5` files are to be archived with the thesis data (Zenodo, as for
the benchmark); every table and figure can be regenerated from them with
`20_aggregate.jl` → `30_plots.jl` / `40_tables.jl` and the `7x` studies.

## Campaign (11 Sep 2026)

* wave 1 A/B: MW 5·10⁵ × 3 seeds per ordering, MH 5·10⁵ seed 11 (4 threads each)
* wave 1 C: full 5·10⁴ grid (MW/MH/NS/IS × 3 seeds × 2 orderings), NUTS 5·10⁴ documentation cells, MH 5·10⁵ seed 23
* wave 1 D → D2: NUTS/NS/IS at 5·10⁵ seed 11, both orderings
* nsref_NO / nsref_IO: NS to evidence convergence (cap 4·10⁶)
* wave 2 NO/IO: MH seed 41, NUTS seed 23, NS seed 23 at 5·10⁵
* side study: `nu_ka_NO_mw_d9_B5e4_seed11` — KamLAND-only fit (Δm²₂₁ check)

`orchestrate_wave1.ps1` was meant to restart D as D2 after its NUTS cell and
launch nsref/wave 2 once A and B had exited. Its PID→queue mapping was wrong:
it killed A (losing `mh NO 5e5 11`) and left D running, so D and D2 computed
the same cells twice (same seeds, identical results). `orchestrate_v2.ps1`
(20:37) re-ran the lost cell (`queues/redo_A.txt`) but failed silently to
start wave 2 NO through a nested `run_queue.ps1` call; wave2_NO was started by
hand (21:04) and `orchestrate_v3.ps1` (21:05, direct `Start-Process` with an
alive check) waited for the IS IO cell, stopped D/D2 and launched nsref_NO,
nsref_IO and wave2_IO at 21:17; progress in `out/logs/orchestrator_v3.log`.
The campaign completed at 00:06 on 12 Sep with 51 cells.

## Evidence reference (12 Sep 2026)

The NS runs to Δln Z < 0.5 (8.4–8.5·10⁵ evaluations) were meant to be the
evidence reference but are biased high by 1.5 (NO) / 2.1 (IO) nats — the
ellipsoidal-bounding failure mode — as shown by two independent unbiased
estimators that agree with each other: defensive kernel-mixture importance
sampling anchored on the pooled MH chains (`70_evidence_check.jl`;
ln Z = −510.87 ± 0.01 NO, −511.28 ± 0.01 IO, ln K = 0.42 ± 0.01) and the pooled
plain-IS draws. MoleWhacker's own evidence is low by 0.2 nats because of its
pooled-cloud weighting; fresh draws from its stored final mixtures reproduce
the reference (`72_mw_mixture_check.jl`). The evidence figure and table use
the defensive-IS reference; the NS-converged runs are shown as a separate
marker/row.

## Side studies (12 Sep 2026)

* **Subsets** (`74_subset_study.jl`; 24 MW cells at 5·10⁴, seeds 11/23, both orderings, tags `nu_da`, `nu_ka`, `nu_mi`, `nu_daka`, `nu_dami`, `nu_kami`): each oscillation parameter is measured by exactly one experiment except Δm²₃₁ (Daya Bay 2.55 ± 0.07, MINOS 2.49 ± 0.09 for NO; −2.50 vs −2.39 for IO). No single experiment and neither the Daya Bay + KamLAND nor the KamLAND + MINOS pair distinguishes the orderings (fresh-draw evidences: |ln B| ≤ 0.02); Daya Bay + MINOS alone gives ln B = 0.384 ± 0.001 of the joint 0.41 — the ± cos 2θ₁₂ Δm²₂₁ shift between |Δm²ₑₑ| and |Δm²ᵤᵤ| makes the two Δm²₃₁ measurements more compatible under NO. Consistency ratios (physical normalization): DB–KL 0.03 / 0.01 (disjoint parameters, null test), KL–MI −0.09 / −0.10 (two weak θ₁₃ constraints), DB–MI +1.08 (NO) / +0.71 (IO). Priors flat in sin²θ instead of θ change P(upper) by −0.003 and ln B by ≤ 0.01. Evidences come from `--fresh` (2.4 h); `--reuse-fresh` re-plots from the cached `subset_cells.csv` without recomputing.
* **Iteration cap** (`73_tmax_study.jl`; `11_run_queue.jl queues/ablation_tmax_<ORD>.txt --tmax 100000 --out neutrino/out_ablation`, seeds 11/23/41 sequentially per ordering, started 12 Sep 16:44): with the cap lifted the pooled-cloud ESS keeps growing roughly linearly in the consumed evaluations (η ≈ 0.10 at t ≈ 170–195 against 0.019 at t = 20); the runs take about 2 min per iteration at t ≈ 130–200 (mixture of 1400–1600 components), i.e. the per-iteration wall time, not the likelihood budget, is what T_max bounds. Final numbers in `out/tables/tmax_study.csv` once the runs have written `result.h5`.

## Chapter palette

MoleWhacker vermilion `#D55E00` (thick solid); MH **black dashed** as the reference chain (the thesis orange `#E69F00` is not separable from vermilion when the curves coincide, which here they do by construction); NUTS `#56B4E9`; NS `#009E73` dash-dot; IS `#999999` dotted. Experiments (data figures, subset overlays): Daya Bay `#CC79A7`, KamLAND `#009E73`, MINOS `#0072B2`. Figure text uses American spelling (thesis convention).

## Empirical costs (12 logical cores, all busy)

≈ 6 ms per likelihood evaluation unloaded, 12–18 ms under full load.
MW 5·10⁵ stops on T_max = 20 after ≈ 1.2·10⁵ evaluations (≈ 17 min);
MH/NS/IS 5·10⁴ ≈ 15 min each; MH 5·10⁵ ≈ 2.5 h; NUTS 5·10⁵ ≈ 1.5–2.5 h
(ForwardDiff gradients); NUTS is budget-infeasible below ≈ 2·10⁵.

# molewhacker-newtrinos: MoleWhacker on a real neutrino-oscillation likelihood

Companion repository of Chapter 9 ("Application to Neutrino Oscillation
Data") and Appendix B of the master's thesis *Importance Sampling Methods in
the Bayesian Analysis Toolkit* (Valentin Reindel, Technical University of
Munich, Department of Physics, 2026). The thesis benchmarks the adaptive
importance sampler **MoleWhacker** against Metropolis-Hastings (MH), the
No-U-Turn Sampler (NUTS), ellipsoidal nested sampling (NS) and plain
importance sampling (IS) on synthetic targets
([molewhacker-bench](https://github.com/valeagent/molewhacker-bench)); this
repository carries the same harness, cost counter and samplers to a real
likelihood:

* **the joint three-flavor fit** of Daya Bay, KamLAND and MINOS/MINOS+ with
  the likelihood modules of [Newtrinos.jl](https://github.com/philippeller/Newtrinos.jl)
  (11 parameters: six oscillation parameters and five experimental nuisance
  parameters; normal and inverted ordering; budgets 5e4 and 5e5 likelihood
  evaluations; seeds 11, 23, 41; all five samplers), with an independent
  evidence reference built on the pooled MH chains;
* **the ablation of the iteration cap** (MoleWhacker with `T_max` lifted,
  same budget, three seeds per ordering);
* **the extension by the IceCube DeepCore atmospheric sample** to
  24 parameters (13 further nuisance parameters, normal ordering only, since
  the pinned DeepCore module supports no other), with MoleWhacker at the
  protocol seed count and at `n_seed = 8`, and two MH chains of 2.5e5 steps
  as the reference.

**The MoleWhacker estimator of the thesis is the independent final
sample.** After adaptation the final Gaussian mixture of a cell is frozen
(`result.h5`, `extras[:mixture]`), `N` independent points are drawn from it
and weighted by the exact transformed posterior; every MoleWhacker
posterior summary, contour, evidence and agreement value of the chapter is
computed from these draws (`scripts/75_final_sample.jl` for d = 11,
`scripts/81_extension_fresh.jl` for d = 24; thesis Sec. 9.3). The samples
that the adaptation loop accumulates are used only for the labelled
adaptation diagnostics (iteration logs, iteration-cap ablation, seed-count
study).

The repository is self-contained: the benchmark harness and the
thesis-final MoleWhacker implementation are included as byte-identical
copies under `harness/` (provenance and SHA-256 hashes in
`harness/PROVENANCE.md`), and the environment is pinned by `Manifest.toml`
(Newtrinos.jl at commit `fa87689d`). The pinned Newtrinos modules are used
unmodified, including their documented limitations
(`docs/REPORT-newtrinos-deepcore-p1.md`); the results describe that pinned
model.

**Final state.** The last commit that changed code or result files is
`cba7e6749b30a6e9e5c2cdf6e34ec406454f5bdd` (27 September 2026; thesis tags
`v8-final-2026-09-27` to `v10-final-2026-09-27`). Every later commit is
documentation only (this file, `docs/ZENODO.md`); the thesis tag
`v11-final-2026-09-27` points at that documentation commit.
Reproduce from a checkout of a tagged commit with its pinned
`Manifest.toml`.

## What is where

| Material | Location | State |
|---|---|---|
| **Original campaign per-cell outputs** — `result.h5` of every cell (samples, weights, diagnostics, MoleWhacker iteration logs and the stored frozen mixtures): the 74 three-experiment cells, the 6 ablation cells, the extension cells and MH chains, the lane logs; 7.9 GB | Zenodo, [**10.5281/zenodo.22879546**](https://doi.org/10.5281/zenodo.22879546) (published 21 September 2026; layout in `docs/ZENODO.md`) | The record is the snapshot of the original campaign. It contains the inputs of the final inference stage (the frozen mixtures), not the d = 11 final samples. |
| **d = 24 final-sample payloads** — `out_extension_nseed8/fresh/{nseed8__*,protocol30__*}.jld2` (4 files, 24,983,628 bytes; `N = 30,000` draws each) | in the extension archive of the Zenodo record; not in Git (`.gitignore`) | archived; SHA-256 in `out/tables/fresh_payload_manifest.csv` |
| **d = 11 final-sample payloads** — `out/fresh_d11/<cell>.jld2` (12 files, 90,459,340 bytes: coordinates, log densities, weights, `C_adapt`, `N`, mixture hash, RNG seed) | **not in Git, not in the Zenodo record** | reconstructible from the archived mixtures with `scripts/75_final_sample.jl` (both stages, 434,338 target evaluations, no adaptation; route B below); SHA-256 of the originals in `out/tables/fresh_payload_manifest.csv` |
| **Final-sample scalar records** — `out/tables/fresh_d11.csv` (one row per d = 11 cell: `C_adapt`, `N_fresh`, `C_total`, RNG seed, `logZ`, ESS, Pareto `k`, `P_upper`, recovery gate, mixture SHA-256), `out/tables/fresh_payload_manifest.csv` (16 payloads), `out_extension_nseed8/tables/fresh.csv` (d = 24) | in Git | |
| **Primary tables and figures (final sample)** — `out/fresh_primary/tables/` (`cells`, `physics`, `agreement`, `pairs`, `chains`, `evidence`, `bayes_factor`, `prior_sensitivity`, `posterior_predictive_{NO,IO}.csv`; `tab_nu_{physics,evidence,samplers,priors}.tex`), `out/fresh_primary/figs/` (25 PDF + PNG), `out_extension_nseed8/fresh_primary/tables/` and `out_extension/fresh_primary/tables/` (d = 24 aggregates, `ext_summary.csv`, `tab_nu_ext_{physics,samplers}.tex`) | in Git | these are the sources of every MoleWhacker number, table and posterior figure of the thesis |
| **Historical products of the adaptation population** — `out/tables/`, `out/figs/`, `out_extension*/tables/` as written by the campaign scripts in their default (`population`) mode; also the reference inputs that are not re-estimated (`profile_*.csv`, `evidence_check.csv`, `mw_mixture_check.csv`, `is_diagnostics.csv`, `tmax_*.csv`, `subset_*.csv`) | in Git | historical; the thesis embeds only the labelled adaptation diagnostics from `out/figs/` (Figs. 9.1, 9.9, 9.10, B.5, B.10) |
| Per-cell `metadata.json` / `summary.json` of every run | in Git (`out*/runs/<cell>/`) | identical copies are in the archive |

## Layout

| path | purpose |
|---|---|
| `Project.toml`, `Manifest.toml` | own environment: the thesis pins (BAT 4.0.4, MGVI 0.4.x, CairoMakie 0.14, ...) plus Newtrinos.jl `main` pinned to `fa87689d` |
| `harness/experiments/src/` | verbatim copy of the thesis benchmark harness (module `ExperimentsBase`: cost counter, cube prior, sampler wrappers, metrics, plotting) |
| `harness/scripts2/algo/MoleWhacker.jl` | verbatim copy of the thesis-final MoleWhacker algorithm (`algo_mw.jl` includes it via the unchanged relative path) |
| `harness/PROVENANCE.md` | source paths, copy date and SHA-256 hashes of every copied file |
| `src/neutrino_problem.jl` | adapter: `ConfigNeutrino <: ProblemConfig`, the affine map from the harness cube onto the prior box, the Gaussian pull factors, `build_log_f`, `physical_summary`; `needs_matter`/`matter` switch for the atmospheric sample |
| `src/published_values.jl` | Daya Bay 2023, KamLAND 2011, MINOS+ 2020, IceCube DeepCore 2023 and NuFIT 6.0 reference values and conversions |
| `data/` | the published IceCube DeepCore 90 % contour (`data/README.md` gives the source) |
| `queues/*.txt` | the campaign cell lists (`alg ordering B seed [experiments]`) as run |
| `scripts/` | the pipeline, numbered in execution order (table below) |
| `ops/` | the launch, chain, pause and watchdog scripts as run during the campaign, and the Zenodo packaging scripts; record only (`ops/README.md`) |
| `out/` | three-experiment campaign: `runs/<cell>/{metadata.json, summary.json}` (the `result.h5` are in the archive), `tables/` and `figs/` (historical population products and reference inputs), `fresh_d11/` (final-sample payloads; not in Git), `fresh_primary/{tables,figs}` (primary products) |
| `out_ablation/` | iteration-cap ablation (own output tree; `iter_timestamps.csv` holds the per-iteration wall clock) |
| `out_extension/`, `out_extension_nseed8/` | DeepCore extension: the protocol cell and the two MH chains; the three `n_seed = 8` cells, the final-sample payloads (`fresh/`, archived), `tables/` (historical) and `fresh_primary/tables/` (primary); `_oom_*` and `_stopped_*` keep the metadata of the cells lost on 14/15 Sep |
| `docs/PHYSICS-PRIMER.md` | neutrino oscillations from zero, the experiments and their Newtrinos likelihoods, the 11-parameter model, the study design |
| `docs/NEUTRINO-BRIEFING.md` | working log of the campaign: reconnaissance of Newtrinos.jl, design decisions, day-by-day status, the DeepCore extension |
| `docs/REPORT-newtrinos-deepcore-p1.md` | report to the Newtrinos authors: the p1 hole-ice term of the DeepCore module uses the p0 slope table (`deepcore.jl` l. 248); not patched here, quantified by `scripts/86_deepcore_p1_check.jl` |
| `docs/CHAPTER-DRAFT.md` | early prose draft of the chapter (superseded by the LaTeX chapter; kept for the record) |
| `docs/ZENODO.md` | contents of the data archive, what it does and does not contain, unpacking instructions |

## Pipeline

All commands run from the repository root with the repository's own
environment (`--project=.`). `-t N` sets the Julia thread count.

```powershell
julia --project=. -e "import Pkg; Pkg.instantiate()"      # once: exact environment from Manifest.toml
julia --project=. -t 4 scripts\01_smoke_harness.jl        # mapping, gradient counting
julia --project=. -t 4 scripts\02_smoke_samplers.jl       # all five samplers on a tiny budget
```

**Estimator selection is explicit.** `20_aggregate.jl`, `30_plots.jl`,
`40_tables.jl`, `80_posterior_predictive.jl`, `82_extension_plots.jl`,
`83_extension_tables.jl` and `84_extension_physics.jl` accept
`--estimator fresh`: MoleWhacker cells are then represented by their saved
final-sample payloads and every output goes to the `fresh_primary/`
sub-directory of the output root. A MoleWhacker cell without a payload is
an error in that mode, never a silent fall-back. Without the flag the
scripts run in their archived `population` mode and write the historical
directories (`out/tables`, `out/figs`, ...); those outputs are **not** the
thesis products.

| script | stage | output |
|---|---|---|
| `00_setup_env.jl`, `00b_pin_newtrinos.jl` | how the environment was built and pinned (documentation; `Pkg.instantiate()` is all a clone needs) | |
| `10_run_cell.jl` | one (alg, ordering, B, seed[, experiments]) cell; `--tmax` lifts the iteration cap, `--nseed` sets the MoleWhacker seed count | `out*/runs/<cell>/{result.h5, metadata.json, summary.json}` |
| `11_run_queue.jl`, `run_queue.ps1` | run a queue file sequentially in one process / in the background | |
| `20_aggregate.jl` | per-cell metrics against the pooled MH reference, physics summaries, chain diagnostics; `--out <root>`, `--tag <prefix>`, `--estimator fresh` | `<root>/[fresh_primary/]tables/{cells, physics, agreement, pairs, chains, evidence, bayes_factor}.csv` |
| `30_plots.jl` | chapter figures of the three-experiment fit (`--figs` selects a subset; `--estimator fresh`) | `out/[fresh_primary/]figs/nu_*.pdf` (+ `png/`) |
| `40_tables.jl` | LaTeX table fragments (`--estimator fresh`) | `out/[fresh_primary/]tables/tab_nu_*.tex` |
| `50_profile.jl` | profile-likelihood scans in sin^2 theta_23 and Delta m^2_31 (reference input of the profile figures; not re-run for the final version) | `out/tables/profile_<ORD>_<var>.csv` |
| `60_primer_figures.jl` | teaching figures for the primer | `out/figs/primer_*.png` |
| `70_evidence_check.jl` | evidence reference: defensive kernel-mixture IS on the pooled MH chains, and pooled plain IS | `out/tables/evidence_check.csv` |
| `71_is_diagnostics.jl` | importance-weight diagnostics (Kish ESS, top-weight shares, Pareto k) of every MW/NS/IS cell | `out/tables/is_diagnostics.csv` |
| `72_mw_mixture_check.jl` | fresh i.i.d. draws from every stored MoleWhacker mixture, scalar summaries only (the recovery reference of script 75) | `out/tables/mw_mixture_check.csv` |
| `73_tmax_study.jl` | iteration-cap ablation against the protocol cells and the other samplers (adaptation diagnostic) | `out/tables/tmax_study.csv`, `tmax_iterlog.csv`, `out/figs/nu_tmax.pdf` |
| `74_subset_study.jl` | single-experiment and pairwise fits (adaptation diagnostic; the subset figures are not embedded in the submitted thesis, Table 9.5 uses the evidence decomposition) | `out/tables/subset_*.csv`, `prior_sensitivity.csv`, `out/figs/nu_subsets_<ORD>.pdf`, `nu_ordering_mechanism.pdf` |
| **`75_final_sample.jl`** | **final inference stage, d = 11**: reloads the frozen mixture of each of the twelve MoleWhacker cells and saves `N` independent draws with coordinates, log densities and weights; `--stage top` (six B = 5e5 cells, `N = 60,000`, RNG seed `1000 + cell seed`, recovery gate against `mw_mixture_check.csv`), `--stage low` (six B = 5e4 cells, `N = min(60,000, max(0, floor(B − C_adapt)))`, RNG seed `2000 + cell seed`); `--only NO:11[,IO:23,...]`; `N` target evaluations per cell | `out/fresh_d11/<cell>.jld2`, `out/tables/fresh_d11.csv` |
| `77_fresh_prior_sensitivity.jl` | prior sensitivity by reweighting the final-sample batches (no target evaluations) | `out/fresh_primary/tables/prior_sensitivity.csv` |
| `80_posterior_predictive.jl` | oscillation-probability figure and the data figures (observed spectra, posterior-predictive band, no-oscillation expectation); `--estimator fresh`; `--ndraw` (default 300 per ordering) forward-model evaluations, not part of any sampler budget | `out/[fresh_primary/]tables/posterior_predictive_<ORD>.csv`, `out/[fresh_primary/]figs/nu_data_<ORD>.pdf`; `out/figs/nu_intro.pdf` |
| **`81_extension_fresh.jl`** | **final inference stage, d = 24**: `N = 30,000` draws from every stored d = 24 mixture, saved as JLD2 (`--N`, `--ext`, `--ext-proto`) | `out_extension_nseed8/fresh/*.jld2` (archived), `out_extension_nseed8/tables/fresh.csv` |
| `82_extension_plots.jl`, `83_extension_tables.jl`, `84_extension_physics.jl` | figures and tables of the extension (`--estimator fresh`; `84 --figs tri,triatm,octant` reads the payloads only, `84 --figs data` evaluates the DeepCore forward model on `--ndraw` (default 240) posterior draws) | `out/[fresh_primary/]figs/nu_ext_*.pdf`, `<root>/[fresh_primary/]tables/*.tex` |
| `85_extension_analysis.ps1` | **legacy wrapper of the campaign** (September 2026): population-mode aggregation, plots and tables of the extension, regenerates the d = 24 payloads through script 81 unless `-SkipFresh`, does not call 84, and exports from the historical figure directory. Not the final-thesis workflow; use the explicit commands of route C. | |
| `86_deepcore_p1_check.jl` | quantifies the p1 slope-table slip of the pinned DeepCore module | |
| `90_export_thesis.ps1` | copies chapter PDFs into a thesis `figures/` directory under the thesis filename convention; `-Out` selects the source directory (**default `out\figs`, the historical population figures**), `-Thesis` the destination; overwrites existing files. See route E. | |
| `96_pause_resume.ps1` | OS-level suspend/resume of the julia processes of a running campaign | |

A cell is finished when its `summary.json` exists (written last); a cell
whose `result.h5` exists is skipped (`--force` overrides). Nested sampling
run to evidence convergence (`nsref`, cap 4e6 evaluations) is stored as
algorithm `ns` under its own budget token.

## Reproducing the thesis results

Work in a disposable checkout of a tagged commit. Reading the committed
tables and figures needs no computation. Nothing below re-runs the
sampling campaign; routes B and D perform target or forward-model
evaluations, route C does not.

### Route A — inspect the published results (no computation)

Every MoleWhacker number of the chapter is in `out/fresh_primary/tables/`
(three-experiment fit: `physics.csv`, `evidence.csv`, `bayes_factor.csv`,
`agreement.csv`, `cells.csv`, `prior_sensitivity.csv`) and
`out_extension_nseed8/fresh_primary/tables/` (`ext_summary.csv`,
`physics.csv`, `agreement.csv`); the LaTeX fragments `tab_nu_*.tex` next to
them are the generated bodies from which the thesis tables were
transcribed. The final-stage records are
`out/tables/fresh_d11.csv` and `out_extension_nseed8/tables/fresh.csv`.
The figures are in `out/fresh_primary/figs/` and, for the retained
adaptation diagnostics, `out/figs/` (inventory below).

### Route B — reconstruct the d = 11 final samples (434,338 target evaluations, no adaptation)

Unpack the runs archive of the Zenodo record into the clone
(`docs/ZENODO.md`): script 75 needs the `result.h5` of the twelve
MoleWhacker cells (`out/runs/nu_dakami_{NO,IO}_mw_d11_B5e{4,5}_seed{11,23,41}/`)
and the recovery reference `out/tables/mw_mixture_check.csv` (in Git).

```powershell
julia --project=. -t 10 scripts\75_final_sample.jl --stage top
julia --project=. -t 10 scripts\75_final_sample.jl --stage low
```

* The top stage replays the archived mixture check (`N = 60,000` per cell,
  RNG seed `1000 + cell seed`) and compares `logZ`, ESS and `P_upper` with
  `mw_mixture_check.csv`; require the reported recovery gate to pass. The
  low stage draws the residual budget of the six B = 5e4 cells (11,188 to
  14,047 draws, 74,338 in total; RNG seed `2000 + cell seed`). The twelve
  cells together cost 434,338 target evaluations and no repetition of the
  adaptive runs.
* Compare the regenerated `out/tables/fresh_d11.csv` with the committed
  one: cell ids, `N_fresh`, `C_adapt`, RNG seeds, `mixture_sha256` and the
  scalar summaries must agree. The committed `wall_eval_s` values (sum
  1,048.5 s at ten threads on the campaign machine) are provenance of the
  original execution, not a promised runtime. Regenerated `.jld2` files
  are not byte-identical (their provenance block records the run time),
  so the SHA-256 values in `fresh_payload_manifest.csv` identify the
  original files, not the reconstruction.

The four d = 24 payloads need no reconstruction: unpack the extension
archive (`out_extension_nseed8/fresh/`) and check them against
`fresh_payload_manifest.csv`. (`81_extension_fresh.jl` would regenerate
them with 30,000 target evaluations per cell.)

### Route C — regenerate the primary tables and figures (explicit fresh mode, no target evaluations)

Prerequisites: the runs and extension archives unpacked (the MH, NUTS, NS
and IS cells and the MoleWhacker iteration logs are read from `result.h5`),
the four d = 24 payloads from the archive, the twelve d = 11 payloads from
route B. The reference inputs that are not re-estimated (`profile_*.csv`,
`evidence_check.csv`, `mw_mixture_check.csv`, `is_diagnostics.csv`,
`out_extension_nseed8/tables/fresh.csv`) are committed and read from the
historical `tables/` directories.

```powershell
julia --project=. scripts\20_aggregate.jl --out out --estimator fresh
julia --project=. scripts\20_aggregate.jl --out out_extension_nseed8 --tag nu_dakamide_ --estimator fresh
julia --project=. scripts\20_aggregate.jl --out out_extension --tag nu_dakamide_ --estimator fresh
julia --project=. scripts\77_fresh_prior_sensitivity.jl
julia --project=. scripts\30_plots.jl --estimator fresh
julia --project=. scripts\40_tables.jl --estimator fresh
julia --project=. scripts\82_extension_plots.jl --estimator fresh
julia --project=. scripts\83_extension_tables.jl --estimator fresh
julia --project=. scripts\84_extension_physics.jl --estimator fresh --figs tri,triatm,octant
```

These commands read stored samples and scalars only; they perform no
posterior target evaluation. They write to `out/fresh_primary/`,
`out_extension_nseed8/fresh_primary/` and `out_extension/fresh_primary/`
and leave the historical directories untouched. The iteration-log figures
(`nu_mw_iter_*`, `nu_ext_iter_NO`, `nu_ext_seeds`) read the adaptation logs
in every mode, as they should. Regenerated PDFs differ from the committed
ones in their creation metadata; the rendered content is reproducible.

### Route D — posterior-predictive figures (forward-model evaluations, optional)

```powershell
julia --project=. -t 4 scripts\80_posterior_predictive.jl --estimator fresh
julia --project=. -t 4 scripts\84_extension_physics.jl --estimator fresh --figs data
```

Script 80 evaluates the three-experiment forward models on 300 equal-weight
posterior draws per ordering (plus the no-oscillation and best-fit
baselines), script 84 the DeepCore forward model on 240 draws. These are
posterior-predictive computations outside any sampler budget, not
array-only postprocessing and not a new sampling campaign. Their final
figures (`nu_data_{NO,IO}`, `nu_ext_data`) are committed.

### Route E — export to a thesis checkout

```powershell
powershell -File scripts\90_export_thesis.ps1 -Out out\fresh_primary\figs -Thesis <thesis-dir>
```

Always pass `-Out out\fresh_primary\figs`: the script's default source is
`out\figs`, the historical population figures, and it overwrites the
destination files, so the default call would replace final figures with
population versions of the same name. The retained adaptation diagnostics
(`nu_intro`, `nu_mw_iter_NO`, `nu_mw_iter_IO`, `nu_tmax`, `nu_ext_iter_NO`)
are sourced from `out\figs` deliberately (a second call with
`-Out out\figs` copies *all* mapped population figures; copy those five by
hand instead). The map inside the script still lists the subset and
mechanism figures (`nu_subsets_*`, `nu_ordering_mechanism`), which the
submitted thesis does not embed; a "missing" warning for a figure that
route C did not produce is not evidence that it was rebuilt. The inventory
below is the authoritative list.

### Historical: the campaign and the population-mode analysis

```powershell
# three-experiment fit (51 cells, ~14 h on 12 threads with 3-4 lanes)
foreach ($q in 'wave1_A','wave1_B','wave1_C','wave1_D','wave2_NO','wave2_IO','nsref_NO','nsref_IO','subsets') {
    julia --project=. -t 4 scripts\11_run_queue.jl queues\$q.txt
}
# iteration-cap ablation (6 cells, ~10-16 h each)
julia --project=. -t 4 scripts\11_run_queue.jl queues\ablation_tmax_NO.txt --tmax 100000 --out out_ablation
julia --project=. -t 4 scripts\11_run_queue.jl queues\ablation_tmax_IO.txt --tmax 100000 --out out_ablation
# DeepCore extension (protocol cell ~22 h; n_seed = 8 cells ~12 h each; MH chains ~16 h each)
julia --project=. -t 4 scripts\11_run_queue.jl queues\ext_deepcore_NO.txt --out out_extension
julia --project=. -t 4 scripts\11_run_queue.jl queues\ext_deepcore_NO_nseed8.txt --nseed 8 --out out_extension_nseed8
```

The campaign took about five days of wall time on a 12-thread laptop; the
per-cell RNG streams are seed-fixed. The population-mode analysis of the
campaign (`20_aggregate`, `30_plots`, `40_tables`, `50_profile`, `70`–`74`,
`80` without `--estimator`, `85_extension_analysis.ps1`) produced the
historical `out/tables`, `out/figs` and `out_extension*/tables`; it is
retained as run, and its reference inputs (`50`, `70`, `71`, `72`, `73`,
`74`) are still read by the final figures and tables. Its MoleWhacker
posterior products are superseded by route C.

## Thesis figures

Numbering of the submitted thesis. "primary" = `out/fresh_primary/figs/`
(final sample), "historical" = `out/figs/` (adaptation diagnostics or
sampler-independent). `90_export_thesis.ps1` maps the repository names
onto the thesis convention given in the third column.

| thesis figure | repository file | thesis asset | directory | script |
|---|---|---|---|---|
| 9.1 oscillation probabilities and the octant degeneracy | `nu_intro.pdf` | `nu__physics__intro.pdf` | historical (forward model only, no sampler) | `80_posterior_predictive.jl` |
| 9.2 / B.1 observed spectra with the posterior-predictive expectation (NO / IO) | `nu_data_NO.pdf`, `nu_data_IO.pdf` | `nu__data__{no,io}.pdf` | primary | `80_posterior_predictive.jl --estimator fresh` |
| 9.3 / B.2 marginal posteriors, all samplers | `nu_marginals_NO.pdf`, `nu_marginals_IO.pdf` | `nu__marginals__d11__B5e5__all__{no,io}.pdf` | primary | `30_plots.jl --estimator fresh` |
| 9.4 / B.3 triangle plot of the measured parameters, MW against MH | `nu_corner_NO.pdf`, `nu_corner_IO.pdf` | `nu__tri__d11__B5e5__mw-mh__{no,io}.pdf` | primary | ″ |
| 9.5 sin^2 theta_23 and the octant probability | `nu_octant.pdf` | `nu__octant__d11__B5e5__all.pdf` | primary | ″ |
| 9.6 / B.4 profile likelihoods with the final-sample marginal | `nu_profile_NO.pdf`, `nu_profile_IO.pdf` | `nu__profile__d11__B5e5__mw__{no,io}.pdf` | primary | ″ (profile curves from `50_profile.jl`, `out/tables/profile_*.csv`) |
| 9.7 evidence estimators | `nu_evidence.pdf` | `nu__logz__d11__Ball__all.pdf` | primary | ″ (reference from `70_evidence_check.jl`) |
| 9.8 agreement with the reference against cost | `nu_agreement.pdf` | `nu__agreement__d11__Ball__all.pdf` | primary | ″ |
| 9.9 / B.5 MoleWhacker iteration log (adaptation diagnostic) | `nu_mw_iter_NO.pdf`, `nu_mw_iter_IO.pdf` | `nu__iter__d11__B5e5__mw__{no,io}.pdf` | historical | `30_plots.jl` |
| 9.10 the iteration cap lifted (adaptation diagnostic) | `nu_tmax.pdf` | `nu__tmax__d11__B5e5__mw.pdf` | historical | `73_tmax_study.jl` |
| 9.11 DeepCore sample against the posterior predictive | `nu_ext_data.pdf` | `nu__extdata__d24__B5e5__mw__no.pdf` | primary | `84_extension_physics.jl --estimator fresh --figs data` |
| 9.12 the atmospheric plane with and without DeepCore | `nu_ext_plane.pdf` | `nu__extplane__d24__B5e5__mw__no.pdf` | primary | `82_extension_plots.jl --estimator fresh` |
| 9.13 / B.9 triangle plots of the extension (measured parameters; atmospheric sector against the DeepCore nuisance parameters) | `nu_ext_tri_NO.pdf`, `nu_ext_tri_atm_NO.pdf` | `nu__exttri__d24__B5e5__mw-mh__no.pdf`, `nu__exttriatm__d24__B5e5__mw-mh__no.pdf` | primary | `84_extension_physics.jl --estimator fresh --figs tri,triatm` |
| 9.14 marginals of the extension | `nu_ext_marginals_NO.pdf` | `nu__extmarginals__d24__B5e5__all__no.pdf` | primary | `82_extension_plots.jl --estimator fresh` |
| 9.15 octant estimators at d = 24 | `nu_ext_octant.pdf` | `nu__extoctant__d24__B5e5__all__no.pdf` | primary | `84_extension_physics.jl --estimator fresh --figs octant` |
| 9.16 seed count against cost (adaptation diagnostic; the over-budget protocol cell labelled) | `nu_ext_seeds.pdf` | `nu__extseeds__d24__B5e5__mw__no.pdf` | primary (reads the iteration logs) | `82_extension_plots.jl --estimator fresh` |
| 9.17 agreement at d = 24, parameter by parameter | `nu_ext_agreement.pdf` | `nu__extagreement__d24__B5e5__mw-mh__no.pdf` | primary | ″ |
| B.6 / B.7 nuisance parameters (NO / IO) | `nu_nuisance_NO.pdf`, `nu_nuisance_IO.pdf` | `nu__nuisance__d11__B5e5__mw-mh__{no,io}.pdf` | primary | `30_plots.jl --estimator fresh` |
| B.8 nuisance parameters of the extension | `nu_ext_nuisance_NO.pdf` | `nu__extnuisance__d24__B5e5__mw-mh__no.pdf` | primary | `82_extension_plots.jl --estimator fresh` |
| B.10 iteration log at d = 24 (adaptation diagnostic) | `nu_ext_iter_NO.pdf` | `nu__extiter__d24__B5e5__mw__no.pdf` | historical | `82_extension_plots.jl` |

Not embedded in the submitted thesis (population-based side studies,
omitted in the thesis revision of 27 September 2026): `nu_subsets_NO/IO`,
`nu_ordering_mechanism` (`74_subset_study.jl`). The thesis copies of the
primary figures are byte-identical to the committed files except
`nu_ext_plane`, `nu_ext_marginals_NO`, `nu_ext_nuisance_NO` and
`nu_ext_agreement`, whose committed files are a re-render of the same run
later on 27 September 2026 (identical rendered content, different PDF
creation metadata).

Thesis tables: 9.3 (`tab_nu_physics.tex`), 9.4 (`tab_nu_evidence.tex`),
9.6 (`tab_nu_samplers.tex`) and 9.2 (`tab_nu_priors.tex`) from
`out/fresh_primary/tables/`; 9.8 (`tab_nu_ext_physics.tex`) and 9.10
(`tab_nu_ext_samplers.tex`) from `out_extension_nseed8/fresh_primary/tables/`;
9.9 (final-sample check at d = 24) from `out_extension_nseed8/tables/fresh.csv`;
9.5 (evidence decomposition) from `out/tables/subset_*.csv` and
`out/fresh_primary/tables/evidence.csv`; B.1 and B.2 from
`out/tables/mw_mixture_check.csv`, `out/tables/fresh_d11.csv` and
`out/tables/evidence_check.csv`.

## Conventions

Palette of the chapter: MoleWhacker vermilion `#D55E00` (thick solid); MH
black dashed as the reference chain; NUTS `#56B4E9`; NS `#009E73`
dash-dot; IS `#999999` dotted. Experiments: Daya Bay `#CC79A7`, KamLAND
`#009E73`, MINOS `#0072B2`; published values and the IceCube 90 % contour
in black. Figure text uses American spelling and the thesis terminology
(triangle plot, initialization phase, initial mixture, final sample,
adaptation population, MH reference).

Measured costs on the campaign machine (12 logical cores): about 6 ms per
three-experiment likelihood evaluation single-threaded and idle, 12-18 ms
under full load; 0.22 s per four-experiment evaluation, 6 s per gradient,
290 s per Hessian.

## License and citation

Code: MIT (`LICENSE`). Archived data: CC-BY-4.0. Please cite the thesis
(`CITATION.cff`). The likelihoods are those of Newtrinos.jl (Philipp Eller
et al.), used unmodified at the pinned commit; the experimental data they
contain belong to the respective collaborations.

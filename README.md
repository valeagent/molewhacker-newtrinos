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
  protocol seed count and at `n_seed = 8`, two MH chains of 2.5e5 steps as the
  reference, and a fresh-draw check of every stored MoleWhacker mixture.

Every number, table and figure of the chapter is produced by the scripts
listed below from the per-cell run output. The repository is
self-contained: the benchmark harness and the thesis-final MoleWhacker
implementation are included as byte-identical copies under `harness/`
(provenance and SHA-256 hashes in `harness/PROVENANCE.md`), and the
environment is pinned by `Manifest.toml` (Newtrinos.jl at commit
`fa87689d`). Nothing in the thesis repository or in the benchmark repository
is modified by anything here.

## Data archive

The per-cell sample files (`result.h5`: samples, weights, diagnostics,
MoleWhacker iteration logs and stored mixtures; 7.7 GB in total) are not in
git. They are archived with the thesis data on Zenodo:

> **Zenodo record:** `10.5281/zenodo.XXXXXXXX` (DOI to be inserted after
> publication; see `docs/ZENODO.md` for the archive layout and how to unpack
> it into this repository)

With the archives unpacked (`out/runs/`, `out_ablation/runs/`,
`out_extension/`, `out_extension_nseed8/`), every table and figure
regenerates without re-running a single cell. The runs are also fully
regenerable from the queue files (seed-fixed RNG streams); the campaign took
about five days of wall time on a 12-thread laptop.

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
| `ops/` | the launch, chain, pause and watchdog scripts as run during the campaign; record only, not needed for reproduction (`ops/README.md`) |
| `out/` | three-experiment campaign: `tables/` (CSV summaries and the LaTeX table fragments), `figs/` (chapter figures, PDF and PNG), `runs/<cell>/{metadata.json, summary.json}` (the `result.h5` are in the archive) |
| `out_ablation/` | iteration-cap ablation (own output tree; `iter_timestamps.csv` holds the per-iteration wall clock) |
| `out_extension/`, `out_extension_nseed8/` | DeepCore extension: the protocol cell and the two MH chains; the three `n_seed = 8` cells, the fresh draws (`fresh/`), tables; `_oom_*` and `_stopped_*` keep the metadata of the cells lost on 14/15 Sep |
| `docs/PHYSICS-PRIMER.md` | neutrino oscillations from zero, the experiments and their Newtrinos likelihoods, the 11-parameter model, the study design |
| `docs/NEUTRINO-BRIEFING.md` | working log of the campaign: reconnaissance of Newtrinos.jl, design decisions, day-by-day status, the DeepCore extension |
| `docs/REPORT-newtrinos-deepcore-p1.md` | report to the Newtrinos authors: the p1 hole-ice term of the DeepCore module uses the p0 slope table (`deepcore.jl` l. 248); not patched here, quantified by `scripts/86_deepcore_p1_check.jl` |
| `docs/CHAPTER-DRAFT.md` | early prose draft of the chapter (superseded by the LaTeX chapter; kept for the record) |
| `docs/ZENODO.md` | layout of the data archive and unpacking instructions |

## Pipeline

All commands run from the repository root with the repository's own
environment (`--project=.`). `-t N` sets the Julia thread count.

```powershell
julia --project=. -e "import Pkg; Pkg.instantiate()"      # once: exact environment from Manifest.toml
julia --project=. -t 4 scripts\01_smoke_harness.jl        # mapping, gradient counting
julia --project=. -t 4 scripts\02_smoke_samplers.jl       # all five samplers on a tiny budget
```

| script | stage | output |
|---|---|---|
| `00_setup_env.jl`, `00b_pin_newtrinos.jl` | how the environment was built and pinned (documentation; `Pkg.instantiate()` is all a clone needs) | |
| `10_run_cell.jl` | one (alg, ordering, B, seed[, experiments]) cell; `--tmax` lifts the iteration cap, `--nseed` sets the MoleWhacker seed count | `out*/runs/<cell>/{result.h5, metadata.json, summary.json}` |
| `11_run_queue.jl`, `run_queue.ps1` | run a queue file sequentially in one process / in the background | |
| `20_aggregate.jl` | per-cell metrics against the pooled MH reference, physics summaries, chain diagnostics | `out/tables/{cells, physics, agreement, pairs, chains, evidence, bayes_factor}.csv` |
| `30_plots.jl` | chapter figures of the three-experiment fit (`--figs` selects a subset) | `out/figs/nu_*.pdf` (+ `png/`) |
| `40_tables.jl` | LaTeX table fragments | `out/tables/tab_nu_*.tex` |
| `50_profile.jl` | profile-likelihood scans in sin^2 theta_23 and Delta m^2_31 | `out/tables/profile_<ORD>_<var>.csv` |
| `60_primer_figures.jl` | teaching figures for the primer | `out/figs/primer_*.png` |
| `70_evidence_check.jl` | evidence reference: defensive kernel-mixture IS on the pooled MH chains, and pooled plain IS | `out/tables/evidence_check.csv` |
| `71_is_diagnostics.jl` | importance-weight diagnostics (Kish ESS, top-weight shares, Pareto k) of every MW/NS/IS cell | `out/tables/is_diagnostics.csv` |
| `72_mw_mixture_check.jl` | fresh i.i.d. draws from every stored MoleWhacker mixture: evidence and octant probability of the mixture itself against the population estimator | `out/tables/mw_mixture_check.csv` |
| `73_tmax_study.jl` | iteration-cap ablation against the protocol cells and the other samplers | `out/tables/tmax_study.csv`, `tmax_iterlog.csv`, `out/figs/nu_tmax.pdf` |
| `74_subset_study.jl` | single-experiment and pairwise fits: marginal overlays, evidence decomposition, ordering Bayes factor per subset, consistency ratios, prior sensitivity | `out/tables/subset_*.csv`, `prior_sensitivity.csv`, `out/figs/nu_subsets_<ORD>.pdf`, `nu_ordering_mechanism.pdf` |
| `80_posterior_predictive.jl` | oscillation-probability figure and the data figures (observed spectra, posterior-predictive band, no-oscillation expectation) | `out/tables/posterior_predictive_<ORD>.csv`, `out/figs/nu_intro.pdf`, `nu_data_<ORD>.pdf` |
| `81_extension_fresh.jl` | fresh-draw check of the d = 24 mixtures (stores the draws as JLD2) | `out_extension_nseed8/tables/fresh.csv`, `fresh/*.jld2` |
| `82_extension_plots.jl`, `83_extension_tables.jl`, `84_extension_physics.jl` | figures and tables of the extension (atmospheric plane, marginals, nuisance parameters, agreement, iteration log, seed-count study; DeepCore data against the posterior predictive, triangle plots, octant estimators) | `out/figs/nu_ext_*.pdf`, `out_extension_nseed8/tables/*.tex` |
| `85_extension_analysis.ps1` | runs 81-84 in order | |
| `86_deepcore_p1_check.jl` | quantifies the p1 slope-table slip of the pinned DeepCore module | |
| `90_export_thesis.ps1` | copies the chapter PDFs into the thesis `figures/` directory under the thesis filename convention | |
| `95_status.ps1`, `96_pause_resume.ps1` | live status of running cells; OS-level suspend/resume of the julia processes | |

A cell is finished when its `summary.json` exists (written last); a cell
whose `result.h5` exists is skipped (`--force` overrides). Nested sampling
run to evidence convergence (`nsref`, cap 4e6 evaluations) is stored as
algorithm `ns` under its own budget token.

### Reproducing the campaign from the queues

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
# analysis
julia --project=. scripts\20_aggregate.jl; julia --project=. scripts\30_plots.jl; julia --project=. scripts\40_tables.jl
julia --project=. scripts\50_profile.jl; julia --project=. scripts\70_evidence_check.jl; julia --project=. scripts\71_is_diagnostics.jl
julia --project=. scripts\72_mw_mixture_check.jl; julia --project=. scripts\73_tmax_study.jl --fresh; julia --project=. scripts\74_subset_study.jl --fresh
julia --project=. scripts\80_posterior_predictive.jl
powershell -File scripts\85_extension_analysis.ps1
```

## Thesis figures

| thesis figure | file in `out/figs/` | script |
|---|---|---|
| 9.1 oscillation probabilities and the octant degeneracy | `nu_intro.pdf` | `80_posterior_predictive.jl` |
| 9.2 / B.1 observed spectra with the posterior-predictive expectation (NO / IO) | `nu_data_NO.pdf`, `nu_data_IO.pdf` | `80_posterior_predictive.jl` |
| 9.3 / B.2 marginal posteriors, all samplers | `nu_marginals_NO.pdf`, `nu_marginals_IO.pdf` | `30_plots.jl` |
| 9.4 / B.3 triangle plot of the measured parameters, MW against MH | `nu_corner_NO.pdf`, `nu_corner_IO.pdf` | `30_plots.jl` |
| 9.5 sin^2 theta_23 and the octant probability | `nu_octant.pdf` | `30_plots.jl` |
| 9.6 / B.4 profile likelihoods | `nu_profile_NO.pdf`, `nu_profile_IO.pdf` | `30_plots.jl` (data from `50_profile.jl`) |
| 9.7 evidence estimators | `nu_evidence.pdf` | `30_plots.jl` (data from `70_evidence_check.jl`) |
| 9.8 / B.5 single-experiment and pairwise fits | `nu_subsets_NO.pdf`, `nu_subsets_IO.pdf` | `74_subset_study.jl` |
| 9.9 where the ordering preference comes from | `nu_ordering_mechanism.pdf` | `74_subset_study.jl` |
| B.7 / B.8 nuisance parameters | `nu_nuisance_NO.pdf`, `nu_nuisance_IO.pdf` | `30_plots.jl` |
| 9.10 agreement with the reference against cost | `nu_agreement.pdf` | `30_plots.jl` |
| 9.11 / B.6 MoleWhacker iteration log | `nu_mw_iter_NO.pdf`, `nu_mw_iter_IO.pdf` | `30_plots.jl` |
| 9.12 the iteration cap lifted | `nu_tmax.pdf` | `73_tmax_study.jl` |
| 9.13 DeepCore sample against the posterior predictive | `nu_ext_data.pdf` | `84_extension_physics.jl` |
| 9.14 the atmospheric plane with and without DeepCore | `nu_ext_plane.pdf` | `82_extension_plots.jl` |
| 9.15 / B.10 triangle plots of the extension (measured parameters; atmospheric sector against the DeepCore nuisance parameters) | `nu_ext_tri_NO.pdf`, `nu_ext_tri_atm_NO.pdf` | `84_extension_physics.jl` |
| 9.16 marginals of the extension | `nu_ext_marginals_NO.pdf` | `82_extension_plots.jl` |
| 9.17 octant estimators at d = 24 | `nu_ext_octant.pdf` | `84_extension_physics.jl` |
| 9.18 seed count against cost | `nu_ext_seeds.pdf` | `82_extension_plots.jl` |
| 9.19 agreement at d = 24 | `nu_ext_agreement.pdf` | `82_extension_plots.jl` |
| B.9 nuisance parameters of the extension | `nu_ext_nuisance_NO.pdf` | `82_extension_plots.jl` |
| B.11 iteration log at d = 24 | `nu_ext_iter_NO.pdf` | `82_extension_plots.jl` |

Figure numbers refer to the submitted thesis; `90_export_thesis.ps1` maps
the file names onto the thesis convention
`nu__<descriptor>__d<d>__B<budget>__<alg>__<ordering>.pdf`.

## Conventions

Palette of the chapter: MoleWhacker vermilion `#D55E00` (thick solid); MH
black dashed as the reference chain; NUTS `#56B4E9`; NS `#009E73`
dash-dot; IS `#999999` dotted. Experiments: Daya Bay `#CC79A7`, KamLAND
`#009E73`, MINOS `#0072B2`; published values and the IceCube 90 % contour
in black. Figure text uses American
spelling and the thesis terminology (triangle plot, initialization phase,
initial mixture, accumulated population, MH reference).

Measured costs on the campaign machine (12 logical cores): about 6 ms per
three-experiment likelihood evaluation single-threaded and idle, 12-18 ms
under full load; 0.22 s per four-experiment evaluation, 6 s per gradient,
290 s per Hessian.

## License and citation

Code: MIT (`LICENSE`). Archived data: CC-BY-4.0. Please cite the thesis
(`CITATION.cff`). The likelihoods are those of Newtrinos.jl (Philipp Eller
et al.), used unmodified at the pinned commit; the experimental data they
contain belong to the respective collaborations.

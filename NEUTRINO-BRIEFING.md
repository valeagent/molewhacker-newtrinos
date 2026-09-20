# Neutrino-physics chapter: briefing and plan

Written 2026-09-11 after a full reconnaissance of this repository and of the
`Newtrinos.jl` package it depends on. Purpose: give us a shared, precise
picture of what exists, what Philipp is asking for, and what can be built by
the 28 September deadline. Nothing in the thesis has been touched.

---

## 1. What Philipp said, decoded

> "die Physik fehlt weitgehend … die ursprüngliche Idee war, den
> MoleWhacker-Algorithmus an einem konkreten Neutrinooszillationsproblem zu
> demonstrieren und die physikalischen Fragestellungen und Ergebnisse in den
> Mittelpunkt zu stellen."

He is not saying the benchmark is bad. He is saying a *physics* master's
thesis must contain a physics analysis: a real neutrino-oscillation
posterior, physics questions, physics results, comparison with published
analyses. The thesis already anticipated this — `chapters/07-neutrino-application.tex`
exists as a skeleton (Physics Motivation → Statistical Model → Analysis
Setup → Results → Comparison with existing analyses) and was deferred.
That chapter is what we build.

## 2. Newtrinos.jl — Philipp's framework

* Source: `https://github.com/philippeller/Newtrinos.jl`, pinned here at
  git revision `adfae4a` (Manifest). Local copy:
  `C:\Users\valen\.julia\packages\Newtrinos\HqMEa\`. Author: Philipp Eller.
* It is a complete Bayesian neutrino-oscillation analysis framework built on
  BAT.jl. It ships **real published data** as experiment modules:

| Module | Dataset | Physics it constrains | Free nuisances (besides oscillation params) |
|---|---|---|---|
| `dayabay` | Daya Bay, 3158 days, 3 experimental halls, published correlation matrix (arXiv:1607.05378 lineage) | θ₁₃, Δm²₃₁ (reactor ν̄ₑ disappearance) | none (Gaussian spectral likelihood with covariance) |
| `kamland` | KamLAND 7-year spectrum + reactor table | θ₁₂, Δm²₂₁ (solar sector, LMA) | energy scale, geo-ν scale, flux scale |
| `minos` | MINOS 16×10²⁰ POT release (sterile-search dataset, used with a 3-flavour fit) | θ₂₃, Δm²₃₁ (ν_μ disappearance) | 2 (from log dimensionality) |
| `deepcore` | IceCube DeepCore 3-year high-stats sample B, public release, systematics hyperplanes | θ₂₃, Δm²₃₁ (atmospheric) | lifetime, atm. muons, ice absorption/scattering, optical efficiencies, flux (Barr), cross-section norms |
| `orca` | KM3NeT ORCA6 433 kton | θ₂₃, Δm²₃₁ | energy scale, several norms |

* Physics modules: `osc.jl` (three-flavour + exotic variants: `Darkdim_Masses`,
  damping, matter effects `SI()`, Earth model `earth_layers` with PREM),
  `atm_flux.jl`, `xsec.jl`.
* The oscillation parameters and their **box priors** (`osc.jl`):

| Parameter | Prior | Nominal |
|---|---|---|
| θ₁₂ | Uniform(atan√0.2, atan√1) ≈ [0.42, 0.785] | asin√0.307 |
| θ₁₃ | Uniform(0.1, 0.2) | asin√0.021 |
| θ₂₃ | Uniform(π/6, π/3) | asin√0.57 |
| δCP | Uniform(0, 2π) | 1.0 |
| Δm²₂₁ | Uniform(6.5e-5, 9e-5) eV² | 7.53e-5 |
| Δm²₃₁ | NO: Uniform(2e-3, 3e-3); IO: Uniform(−3e-3, −2e-3) | 2.4e-3+Δm²₂₁ |

  Normal vs inverted ordering are **two different prior supports** → two
  posteriors, two evidences → a Bayes factor for the mass ordering.

* The user-facing API (identical in the old scripts and Philipp's own driver):

```julia
osc = Newtrinos.osc.configure(Newtrinos.osc.OscillationConfig(
        flavour=ThreeFlavour(), propagation=Basic(), states=All(), interaction=Vacuum()))
physics = (; osc, atm_flux, earth_layers, xsec)
experiments = (dayabay = Newtrinos.dayabay.configure(physics),
               kamland = Newtrinos.kamland.configure(physics))
likelihood = Newtrinos.generate_likelihood(experiments)
priors     = Newtrinos.get_priors(experiments)
posterior  = PosteriorMeasure(likelihood, distprod(; priors...))
```

* `src/analysis/analysis.jl` is **"the file where Philipp made the settings"**:
  his command-line driver (tasks NestedSampling via UltraNest,
  ImportanceSampling, Profile, Scan) written for his Dark-Dimension study,
  with conditioning on δCP and λ parameters. The **"basic version"** we used is
  the default `OscillationConfig()` = ThreeFlavour + Basic + All + Vacuum.
* `src/analysis/molewhacker.jl` is the **ancestral MoleWhacker** living inside
  his package (MGVI-Fisher local Gaussians, Sobol+LBFGS seeding, whack loop).
  The thesis algorithm descends from it. This is the narrative bridge: the
  method was invented for exactly these posteriors.

## 3. What this repository did a year ago

* `scripts/bechmark_neutrino*.jl` (the typo is in the filename): build a
  Newtrinos posterior for a chosen experiment list, then run **two MoleWhacker
  variants against each other** (baseline vs "Improved" with component
  merging), recording per-parameter mean/SE/sd, 68/95 % quantiles, ESS,
  efficiency, weight diagnostics, timings, component counts; JLD2 of samples.
* **It never compared against standard samplers, never against published
  values, and never posed a physics question.** That is exactly the gap.
* 56 run directories (2025-08-28 → 2025-09-27), 17 complete. Empirical costs
  on this machine:

| Experiments | free d | Outcome |
|---|---|---|
| dayabay | 6 | minutes; final run 85 s; improved MW merged to **1 component, 0 whacks, η=0.98** → nearly Gaussian, too easy |
| dayabay+kamland | 9 | ~5 min, completed repeatedly |
| dayabay+kamland+minos | 11 | 12–36 min (once 2 h), completed; ~400 components, 20–24 whack iterations |
| minos | 8 | completed (one 12 h overnight run); old note: "very spikey" |
| deepcore (+others) | 18–22 | **never completed** ("uncomputable" in the old notes) |
| orca (+others) | 18–21 | never completed |

* Reusable: the posterior-assembly code, the logging/snapshot harness, the
  metrics helpers (weighted means/quantiles), the plotting script, and the
  completed runs as regression baselines. Not reusable as-is: the two old
  MoleWhacker copies (the thesis-final `src/MoleWhacker.jl` in `02_molewhacker`
  supersedes them), the dual root/src modules, the `.txt` graveyard.

## 4. The physics chapter: options

**Option A — Reactor pair (Daya Bay + KamLAND), d = 9.**
Physics: θ₁₃ and Δm²₃₁ from Daya Bay, θ₁₂ and Δm²₂₁ from KamLAND — the
classic complementary reactor measurement of two sectors; direct comparison
with Daya Bay's and KamLAND's published intervals. Weakness: θ₂₃ and δCP are
unconstrained by reactor data (posterior = prior in those directions), which
is physically honest but leaves the posterior nearly Gaussian in the
constrained directions — little for MoleWhacker to *demonstrate*.
Cost: minutes per run. Risk: low.

**Option B — Reactor pair + MINOS, d = 11. (Recommended core.)**
Adds ν_μ disappearance: θ₂₃ and Δm²₃₁ become data-constrained, and the
**θ₂₃ octant degeneracy** makes the posterior genuinely **bimodal** — the
exact structure MoleWhacker was designed for and the synthetic benchmark
scored it on (mode recovery, evidence). All three sectors of three-flavour
mixing are then measured from real data in one joint fit, compared with
Daya Bay, KamLAND, MINOS publications and the NuFIT global fit. The old runs
prove this posterior completes in tens of minutes.
Cost: ~20–40 min per MoleWhacker run at old knobs (less at benchmark budgets).
Risk: low–moderate (MINOS "spikey" likelihood — a feature for the story).

**Option C — B + one DeepCore/ORCA showcase.**
Adds atmospheric physics (matter effects, Earth model) but d ≈ 19–22 and it
never completed here. Only as a single MoleWhacker-only illustration, no
replication, if time remains. Risk: high. Default: drop.

**Option D — Dark-Dimension BSM posterior (Philipp's own research setup,
`benchmark_hard.jl` / `analysis.jl`).** Maximally "his" physics, but exotic,
expensive (needs DeepCore), and two weeks is not enough to do it credibly.
Default: mention as outlook only.

## 5. Deliverables of the chapter (Option B)

Physics results (the centre of the chapter, as Philipp asked):
1. Joint three-flavour posterior on real data (Daya Bay + KamLAND + MINOS):
   marginal and pairwise posteriors of θ₁₂, θ₁₃, θ₂₃, Δm²₂₁, Δm²₃₁ (δCP
   unconstrained, stated), with 68/95 % credible intervals.
2. **Comparison with published analyses**: overlay of each experiment's
   published best fit / 1σ (Daya Bay 2016/2022, KamLAND 2013, MINOS) and the
   NuFIT global-fit values on our marginals; table of our intervals vs
   published.
3. **θ₂₃ octant**: posterior mass in the lower vs upper octant — a genuine
   bimodal physics result, and the thing MoleWhacker's mixture proposal is
   built to represent.
4. **Mass-ordering Bayes factor** Z(NO)/Z(IO) from the self-normalized
   evidence — a physics statement only the evidence-aware samplers (MW, NS)
   can make at all.
5. Nuisance-parameter posteriors (KamLAND scales, MINOS/xsec norms) — the
   systematics story.

Methodological results (supporting, in the thesis's established language):
6. Same posterior sampled with MW, MH, NUTS, NS, IS — agreement of
   marginals (W̄1 between samplers, since there is no analytic truth),
   agreement of evidences (MW vs NS), cost in likelihood evaluations per
   effective sample, and the running-efficiency portraits already used in
   the thesis. Validation without a truth: cross-sampler agreement + profile
   likelihood scans via `Newtrinos.profile` + published values.

## 6. Plan to 28 September

| Days | Work |
|---|---|
| 1 (today) | Environment smoke test (running). Decide option. **Send Philipp the plan today** so he sees the correction underway and can object early. Collect the citations (Daya Bay, KamLAND, MINOS, NuFIT). |
| 2–3 | Build the neutrino problem adapter: Newtrinos posterior → thesis harness (`LikelihoodCounter` wrapper, prior-to-normal transform for NUTS/NS, MW on the BAT posterior directly). Validate: MW marginals vs MH on Option A (9-d). |
| 4–7 | Campaign on Option B: MW, MH, NUTS, NS, IS; NO and IO orderings; a few seeds for MW/MH; profile scans for validation. Extract intervals, octant fractions, evidences. |
| 8–11 | Write the chapter into the existing skeleton: physics motivation (oscillation formalism is short — the thesis has none yet), statistical model (likelihoods, systematics, priors), setup, results with published comparison, discussion. Figures via the thesis plotting library (triangle plots, running efficiency, evidence table). |
| 12–13 | Integrate: intro/abstract/conclusion updates, cross-references, appendix additions, companion-repo update (new scripts, new data), rebuild, verify. |
| 14 | Buffer; Philipp's feedback; submission formalities. |

## 7. Risks and mitigations

* Environment rot (Julia/BAT/Newtrinos pins): smoke test today; fallback is
  a fresh environment pinned to the same Newtrinos revision.
* Runtime: Option B is proven to complete; budgets are set by the old runs.
  DeepCore/ORCA explicitly out of scope.
* No analytic truth: validation by cross-sampler agreement, profile scans,
  and published values — stated as such in the chapter.
* Scope creep: the chapter is one joint fit, three experiments, five
  samplers, two orderings. Nothing else.
* Philipp buy-in: send the plan before building; ask for a 30-minute call.

## 8. Decisions (taken 2026-09-11)

1. **Option B**: Daya Bay + KamLAND + MINOS, 11 free parameters, NO and IO.
2. Email Philipp today: draft in `EMAIL-PHILIPP-2026-09-11.md`.
3. Dark-Dimension setup: not in the chapter at all.

## 9. Smoke test (2026-09-11, `scripts/_smoke_newtrinos.jl`)

The pinned environment instantiates (one-off precompile 16 min, 398
packages). Real-data posteriors build and evaluate:

| Experiments | free d | free parameters | ms / likelihood evaluation |
|---|---|---|---|
| dayabay | 6 | Δm²₂₁, Δm²₃₁, δCP, θ₁₂, θ₁₃, θ₂₃ | 1.3 |
| dayabay+kamland | 9 | + kamland_energy_scale, kamland_flux_scale, kamland_geonu_scale | 1.5 |
| dayabay+kamland+minos | 11 | + nc_norm, nutau_cc_norm | 6.0 |

At 6 ms per evaluation a 5×10⁵-evaluation run takes ≈ 50 min, a 5×10⁴ run
≈ 5 min: the thesis's own budget ladder is usable unchanged on Option B.
Gradient-based samplers (NUTS) pay roughly d+1 evaluations per gradient with
forward-mode AD, so their wall time is ≈ 10× higher at equal budget.

## 10. Status 2026-09-11, 12:30 — first real-data results

Everything below lives in `neutrino/` (see `neutrino/README.md` for the
pipeline and `neutrino/CHAPTER-DRAFT.md` for the chapter text with numbers).

**Physics (MoleWhacker, 3 seeds per ordering, B = 5·10⁵):**

* sin²2θ₁₃ = 0.0854 ± 0.0031 (Daya Bay 0.0851 ± 0.0024); Δm²₃₂ = 2.448 ± 0.051
  ·10⁻³ eV² NO (Daya Bay 2.466 ± 0.060, NuFIT 2.438), −2.539 ± 0.055 IO.
* Δm²₂₁ = 7.74 ± 0.22 ·10⁻⁵ eV² — 1.2σ above KamLAND (7.49 ± 0.20). A
  KamLAND-only fit gives the same value, so this is the digitised KamLAND
  module, not the combination. tan²θ₁₂ = 0.46 (+0.08 −0.07) (KamLAND 0.436).
* θ₂₃ bimodal (octant degeneracy), modes at sin²θ₂₃ = 0.39 / 0.63,
  P(upper octant) = 0.63 (NO), 0.62 (IO). Profile likelihood (Newtrinos'
  own LBFGS profiler) agrees: Δχ² = 1.1 between the octant minima, maximal
  mixing disfavoured at Δχ² = 4.1.
* Mass ordering: ln K(NO/IO) = 0.45 ± 0.02 — no preference, as expected for
  vacuum disappearance data.
* δ_CP flat; nuisances: MINOS n_NC pulled to 0.86 ± 0.13, KamLAND flux +0.5σ.

**Samplers so far:** at 5·10⁴ MW gives ESS 3 400 from 38 k evaluations,
MH 73, NS 3, IS 1.5. NUTS needs 2·10⁵ for warm-up alone and gives ESS 123
at 5·10⁵ (86 min). MW at 5·10⁵ stops on T_max after 1.2·10⁵ evaluations
(seed phase 82 % of cost, final IS efficiency 57 %).

**Campaign:** 18 of ~60 cells done; four background processes plus an
orchestrator (`neutrino/scripts/orchestrate_wave1.ps1`) that starts the
NS reference runs and wave 2 automatically. Expected completion: 5·10⁴ grid
and MH 5·10⁵ this afternoon/evening; NS/IS 5·10⁵, NS reference runs and
wave-2 replicates overnight. Progress: `neutrino/out/logs/orchestrator.log`,
finished cells have a `summary.json`.

**Figures ready:** `neutrino/out/figs/nu_{marginals,octant,nuisance,profile,mw_iter}_{NO,IO}.pdf`;
corner plot, agreement and evidence figures appear once MH/NS top-budget
cells exist. Tables: `neutrino/out/tables/tab_nu_*.tex`.

## 11. Status 2026-09-11, 20:30

* **Primer written for us:** `neutrino/PHYSICS-PRIMER.md` — neutrino
  oscillations from zero, the exact designs of Daya Bay / KamLAND / MINOS and
  how Newtrinos turns each into a likelihood, the 11-parameter model and its
  priors, the cube mapping, the cell grid, the metrics, the hypotheses, and
  the current numbers. To be read before any thesis text is written.
* **Campaign mishap, corrected:** the morning orchestrator killed queue A
  (MH NO 5·10⁵ seed 11) instead of D because the PID→queue mapping I recorded
  was wrong; D and D2 then ran the same cells twice (identical seeds, no
  harm). `orchestrate_v2.ps1` now re-runs the lost cell (`queues/redo_A.txt`),
  starts wave 2 and the two NS reference runs, and stops D/D2 once the IS IO
  cell is written. Log: `neutrino/out/logs/orchestrator_v2.log`.
* **40 cells done.** All twelve MW cells; the whole 5·10⁴ grid; at 5·10⁵:
  MH IO-11 and NO-23, NUTS both orderings, NS both orderings, IS NO. Running:
  MH IO-23, IS IO; queued: MH NO-11 (redo), MH seed 41, NUTS/NS seed 23,
  nsref NO/IO.
* **5·10⁵ sampler numbers:** MW ESS 2 200 (NO) / 1 250–2 000 (IO) from
  1.15·10⁵ evaluations in 13–17 min; MH ESS 644 / 331 in 1.8 h with
  R̂(θ₂₃) = 1.007 / 1.010 (chains now cross octants); NUTS ESS 123 / 53, one
  chain, 86–89 min; NS ESS 212 / 77, stopped on the call cap with 11 nats of
  dlogz outstanding; IS ESS 10. W₁ to the pooled MH reference (prior-width
  units, NO): MW 0.005–0.007, NUTS 0.010, NS 0.012, IS 0.041; at 5·10⁴ MW
  0.004–0.006, MH 0.008–0.010, NS 0.07–0.10, IS 0.06–0.12.
* **Evidence:** MW ln Z stable to 0.01 across seeds and 0.08 across budgets
  (NO −511.07, IO −511.52); budget-limited NS 1.5 nats higher; IS in between
  with large scatter. ln K(NO/IO): MW 0.45 ± 0.02, NS 0.22 ± 0.07 (1 seed),
  IS 0.58 ± 0.63. The nsref runs decide which is right.
* **All 14 figures render**, including corner (MW vs MH, 5·10⁵), agreement and
  evidence; legends moved out of the axes, corner ticks thinned.
* **Thesis-consistency note for later (no edit now):** the harness writes
  `tau_mu = 0.5`, `tau_Sigma = 0.2 d` into `metadata.json`, but never passes
  them to `whack_many_moles`; the merge tolerances in force are the
  algorithm's defaults 10⁻³ / 10⁻⁵, exactly what thesis Table 6.2 says.

## 12. Status 2026-09-11, 22:00 — primer study edition, campaign on track

* **Philipp's second mail (21:40):** recommends applying to TUM for an
  extension of about eight weeks (precedents exist; needs a good
  justification). What is missing is the physics, in two senses: (a) the
  algorithm applied to a concrete physical problem with physical results,
  (b) a written thesis motivated and structured by the physics rather than
  the algorithm. Six to eight weeks of full effort would make a solid physics
  thesis "gut möglich". No email is being written now; the user is studying
  the physics first.
* **`neutrino/PHYSICS-PRIMER.md` rewritten as a study edition** (≈1090
  lines): how-to-use guide; Part 0 one-page map; Part 1 with Standard-Model
  context, history, explicit PMNS matrix, the two-flavour derivation and the
  1.267 unit check, conventions (Δm²ₑₑ, sin²2θ vs sin²θ), degeneracies and
  what breaks them, matter effects with numbers, what oscillations cannot
  measure; Part 2 with detector/beam details, backgrounds, exactly what
  Newtrinos does with each release and the implications (Daya Bay anchored
  far-hall re-fit, KamLAND digitisation, MINOS beam-only + Gaussian
  conditioning), a "what each cannot tell us" section, and the other
  Newtrinos modules (Super-K, IceCube, ORCA, JUNO/TAO, COHERENT); Part 3
  with prior remarks, the evaluation flow and cost model, Occam/Jeffreys,
  Bayesian vs frequentist reporting; Part 4 with the honest limitations list
  (physics model + sampling study), "what else we could do" tiered by cost
  (incl. a physics-first thesis skeleton and what an 8-week extension buys),
  updated numbers; Part 5 figure guide; check-yourself questions per part
  with answers in Appendix B.
* **Teaching figures** `neutrino/out/figs/primer_*.png` from
  `scripts/60_primer_figures.jl`: survival probabilities vs L/E with the
  three experiments' windows; MINOS-like octant degeneracy and Δm² shift;
  Daya Bay/KamLAND survival vs energy; and, via the Newtrinos modules' own
  `plot` functions, data vs prediction for all three experiments at the
  joint profile best fit (NO). All six verified visually.
* **Campaign:** `orchestrate_v3.ps1` did its job — IS IO 5×10⁵ finished
  21:15, queue D stopped, nsref_NO (pid 30588), nsref_IO (30424) and wave2_IO
  (18848) started and alive. 42 cells done. Running at 22:00: MH NO-11
  (redo), MH NO-41, MH IO-41, nsref NO, nsref IO; queued behind them: NUTS
  and NS seed 23, both orderings. Aggregation reads B from the result file,
  so the `B4e+06` nsref directory names need no handling.
* **Tomorrow:** check `orchestrator_v3.log` and the queue logs, count
  `summary.json` (≈49 cells + 2 nsref expected), run `20_aggregate.jl` →
  `30_plots.jl` → `40_tables.jl`, look at the nsref band in `nu_evidence`,
  then update `CHAPTER-DRAFT.md` and discuss the primer's Part 4.7/4.8
  (limitations, options, thesis skeleton, extension) with the user.

## 13. Status 2026-09-12, 13:00 — campaign complete; the evidence arbitration

* **Campaign complete at 00:06:** 51 cells (full grid, two NS runs to
  Δln Z < 0.5, KamLAND-only fit); no process running. Pipeline re-run
  (`20_aggregate` → `30_plots` → `40_tables`); all figures and tables
  current. Final sampler numbers are in `CHAPTER-DRAFT.md` §4 and
  `PHYSICS-PRIMER.md` 4.6.
* **The NS reference is wrong.** The two nested-sampling runs converged
  (dlogz criterion, 8.4–8.5·10⁵ evaluations, 2.4 h, ESS 18–19 k, posterior
  marginals in agreement with everything else) at ln Z = −509.39 ± 0.05 (NO)
  and −509.17 ± 0.05 (IO) — 1.7/2.4 nats above MoleWhacker and with the
  opposite sign of ln K (−0.23).
* **Arbitration (`70_evidence_check.jl`, new):** defensive importance sampling
  from a KDE mixture on the pooled MH chains (3000 kernels, h²Σ_MH, 10 %
  uniform, 1.5·10⁵ draws, h = 0.6 and 0.9, ESS 14–25 k) gives
  ln Z_NO = −510.87 ± 0.01, ln Z_IO = −511.28 ± 0.01, **ln K = 0.42 ± 0.01**;
  the pooled plain-IS draws (6.5·10⁵) agree (−510.46 ± 0.29, −511.22 ± 0.18).
  Hence NS-converged is biased **high by 1.47 / 2.11 nats** (the ellipsoidal
  clipping failure mode), MoleWhacker **low by 0.22 / 0.25** (0.13/0.14 at
  5·10⁴) with a seed spread ten times smaller than its error.
* **Located MoleWhacker's offset (`72_mw_mixture_check.jl`, new):** each
  cell's final mixture is stored in `result.h5` (`extras[:mixture]`, 169–174
  components, PriorToNormal space). Fresh i.i.d. draws from it (6·10⁴ per
  cell) give ln Z = −510.876/−510.872/−510.854 (NO), −511.268/−511.288/−511.268
  (IO) — the reference within 0.02, ESS 1.6–20 k. The mixture is right; the
  algorithm's *pooled-cloud* estimator (all accumulated batches, each drawn
  from the mixture as it stood at its creation, weighted with the final
  mixture) is what is biased. Same effect on the octant: pooled-cloud
   P(upper) 0.63/0.62, fresh draws 0.60/0.61 (per seed −0.01 to +0.06),
   reference 0.60–0.61/0.62 (NO/IO). Recorded as
  a finding + recommendation (deterministic-mixture weighting or a final fresh
  draw); the algorithm is not changed.
* **Weight diagnostics (`71_is_diagnostics.jl`, new):** Pareto-k̂ of MW
  clouds −0.4…0.3 (healthy, ESS/N 0.3–0.65), budget-limited NS 0.7–4.1, IS
  2.3–3.8; `is_diagnostics.csv`.
* **Pipeline changes:** `30_plots.jl` evidence figure now draws the
  defensive-IS reference band and the NS-converged run as a distinct marker;
  `40_tables.jl` evidence table has the reference row on top and labels the
  NS row "run to Δln Z < 0.5" (no longer "reference").
* **Documents updated:** `CHAPTER-DRAFT.md` (§2.3, §3.3 rewritten with the
  arbitration table and three findings, §3.5, §4 final table and
  observations, §5; MINOS+ inclusion corrected), `PHYSICS-PRIMER.md` (4.2
  complete, 4.6 final numbers, new 4.6b "the evidence arbitration", 4.7 items
  13–14, hypothesis 5 outcome, Part 5, Appendix A/B).
* **Pending user-side thesis notes** seen in `02_molewhacker/humanreview.txt`
  (abstract numbers, W₁ finite-sample wording, KL-vs-iteration plot idea,
  FAILED-SANITY mention, Fig. 8.7 panel A, eggbox triangle plots of the
  better method): not acted on — thesis edits remain off until agreed.
* **Next:** discuss 4.6b with the user; then the cheap additions of primer
  4.8 (single-experiment fits, posterior-predictive bands, prior-sensitivity
  check, ordering-preference decomposition) if wanted.

## 14. Status 2026-09-12, 21:00 — thesis chapter drafted on branch `neutrino-chapter`; side studies

* **Thesis branch.** The chapter now exists in final thesis form on the branch
  `neutrino-chapter` of the thesis repository (`chapters/07-neutrino-application.tex`,
  about 8500 words, seven sections; `appendices/D-neutrino-supplement.tex`
  with the IO counterparts, nuisance posteriors and per-seed arbitration tables;
  12 physics macros, 6 acronyms, 23 verified bib entries, 19 figures registered
  in `docs/FIGURES-INDEX.md`, 7 glossary terms). `main.tex` only gained the
  two `\include` lines; nothing in the existing chapters was changed. The five
  thesis check scripts pass for the new files and `latexmk` builds (215 pages;
  the chapter appears as Chapter 9, the appendix as Appendix B in the compiled
  PDF). Nothing is committed yet.
* **Figures reworked for print** (`30_plots.jl`, `80_posterior_predictive.jl`,
  new `90_export_thesis.ps1`): MH is drawn black dashed as the reference chain
  (the thesis orange was indistinguishable from MoleWhacker's vermilion);
  marginals legend in two banks; octant figure with a separate P(upper) strip;
  evidence figure wide with a right-hand legend; intro figure with the three
  experiment windows labeled in rows and the legend under the flat part of the
  curves; data figure with posterior-predictive bands; profile figure with
  American spelling; agreement figure with integer-decade ticks. Filenames in
  the thesis follow `nu__<descriptor>__d<d>__B<budget>__<alg>__<no|io>.pdf`
  (lowercase ordering token, because the acronym checker scans
  `\includegraphics[..]{..}` arguments).
* **Subset study** (`74_subset_study.jl`, 24 cells): see `neutrino/README.md`
  "Side studies". Headline: the whole ordering preference (ln B = 0.36 of the
  joint 0.42) lives in the Daya Bay + MINOS pair — the two Δm²₃₁ measurements
  (2.55 ± 0.07 vs 2.49 ± 0.09 for NO, −2.50 vs −2.39 for IO) are more
  compatible under NO, exactly the ± cos 2θ₁₂ Δm²₂₁ mechanism of the physics
  section. Single experiments and the other two pairs give ln B = 0 within
  0.04. Prior flat in sin²θ instead of θ: P(upper) −0.003, ln B ≤ 0.01. Written
  into the chapter as Sec. "Which Experiment Measures What" with figure
  `nu_subsets_NO` (IO in the appendix) and the decomposition table.
* **Iteration-cap ablation** (`73_tmax_study.jl`, runs in `out_ablation/`):
  MoleWhacker with T_max lifted, seed 11 of both orderings, running since
  16:44; at t ≈ 170–195 (56–60 % of the budget) the pooled-cloud ESS is
  2.3–2.9·10⁴ (η ≈ 0.08–0.10 against 0.019 at T_max = 20), about 2 min per
  iteration at 1400–1600 components. The script produces a preliminary figure
  from the stderr log until `result.h5` exists; the chapter paragraph on the
  cap will be written from the final numbers (queue continues with seeds 23
  and 41, several hours each).
* **Open:** commit thesis branch and companion repo (marker scan first);
  T_max paragraph + figure into the chapter; abstract/introduction/conclusion
  adaptation on `main` after Philipp has seen the chapter.

## 15. Status 2026-09-12, 22:00 — subset study final (fresh-draw evidences); branch committed

* **Fresh-draw evidences for all 24 subset cells** (`74 --fresh`, 2.4 h; new
  `--reuse-fresh` flag re-plots from the cached `subset_cells.csv`). The
  pooled-cloud offset of the small fits is not a constant: Daya Bay −0.04,
  KamLAND +0.10, MINOS +0.05 (pooled minus fresh), so the ratios ln R needed
  the fresh values. Final numbers (mean over seeds ± half-range, cube-normalized):

  | subset | ln Z(NO) | ln Z(IO) | ln B(NO/IO) |
  |---|---|---|---|
  | Daya Bay | −171.968 ± 0.001 | −171.968 ± 0.001 | −0.001 ± 0.001 |
  | KamLAND | −68.109 ± 0.005 | −68.092 ± 0.001 | −0.016 ± 0.005 |
  | MINOS | −271.905 ± 0.001 | −271.923 ± 0.002 | 0.018 ± 0.002 |
  | DB + KL | −240.049 ± 0.001 | −240.051 ± 0.001 | 0.002 ± 0.001 |
  | DB + MI | −442.792 ± 0.001 | −443.177 ± 0.001 | **0.384 ± 0.001** |
  | KL + MI | −340.108 ± 0.017 | −340.120 ± 0.005 | 0.012 ± 0.018 |
  | all three (fresh, 3 seeds) | −510.868 ± 0.011 | −511.275 ± 0.010 | 0.407 ± 0.015 |

  Consistency ratios ln R (physical normalization): DB–KL 0.028 (NO) /
  0.009 (IO) — null; KL–MI −0.09 / −0.10 — two weak θ₁₃ constraints, no
  reward for agreement; DB–MI 1.08 / 0.71 — the shared Δm²₃₁ agrees far
  better than the prior, and the difference 0.37 is the pair's Bayes factor.
  Chapter text, `tab:nu-subsets` and the appendix caption carry these values.
* **Figure `nu_subsets_<ORD>`** re-laid: shared y-label, explicit ticks
  (δCP at 0, π, 2π; sign-aware Δm²₃₁ ticks for the IO), no boundary-tick
  collisions between panels.
* **Thesis branch committed:** `31e35bb` on `neutrino-chapter` (chapter,
  appendix, 18 figures, bib, macros, docs; marker scan clean; no trailers).
  216 pages, chapter pp. 97–117 of the arabic numbering (Chapter 9), Appendix B.
* **Ablation:** seed-11 runs still going (1 core each; the iteration time
  grows with the component count, 1.5 min/iteration at t ≈ 170 and
  3.5 min/iteration at t ≈ 230; ≈ 385 iterations needed, so they finish in
  the early morning of 13 Sep); seed 23 for both orderings is queued
  automatically (`out_ablation/chain_seed23.ps1`, pid 11688). Preliminary
  figure `nu_tmax_prelim` from the logs: pooled-cloud ESS 4.7·10⁴ (NO, t = 234)
  and 3.7·10⁴ (IO, t = 257) at 65–70 % of the budget, η ≈ 0.10–0.13.
* **New mechanism figure** `nu_ordering_mechanism` (→ `fig:nu-mechanism`):
  |Δm²₃₁| marginals of Daya Bay alone, MINOS alone and the joint fit, NO and
  IO side by side, medians printed — the whole ordering story in one picture.
* **Corner plots rewritten natively** (`fig_corner` in `30_plots.jl`, no
  PairPlots): two-tone highest-density fills for MoleWhacker (68.3 % dark,
  95.4 % light), MH contours at the same levels, upright ticks, full text
  width. PairPlots' `Contourf` silently dropped outer rings that touched the
  panel edge (visible in the old IO corner as "missing" 95 % fills).
* Commits on `neutrino-chapter`: `31e35bb` (chapter), `e1f9961` (fresh
  evidences, mechanism figure), `2bb80fc` (corner plots, discussion tie-in),
  `b85b603` (docs).
* **Automation left running** (all in `neutrino/out_ablation/`): the two
  queue processes (pids 31732 NO, 29724 IO) run seeds 11 → 23 → 41
  sequentially from `queues/ablation_tmax_<ORD>.txt`; `watch_iters.ps1`
  (pid 11976) logs iteration timestamps; `chain_tmax_study.ps1` (pid 28704)
  waits for the two seed-11 `result.h5` files, then runs
  `73_tmax_study.jl --fresh --finished-only` and `90_export_thesis.ps1`
  and writes `chain_tmax_study.done`. What remains by hand: the "Lifting
  the cap" paragraph with `fig:nu-tmax` after `fig:nu-mw-iter-NO` in
  `sec:nu-results-samplers`, the cap sentence in `sec:nu-discussion`, and
  the FIGURES-INDEX status of `fig:nu-tmax`; re-run 73 when seeds 23/41
  finish (a day or two later) to add them to the figure.

## 16. Status 2026-09-13, 15:30 — runs, style pass, self-contained repo, physics-scope evaluation

### 16.1 Runs

* **T_max ablation, seed 11 finished** (NO 05:09, IO 04:20). With the cap
  lifted MoleWhacker spends the whole budget: NO 301 iterations, 2417
  components, N_L = 5.008e5; IO 332 iterations, 2670 components,
  N_L = 5.003e5. Pooled-cloud N_eff rises from 2276 → 68 981 (NO, η 0.019 →
  0.138) and 2018 → 54 230 (IO, η 0.017 → 0.108). The evidence bias of the
  20-iteration mixture disappears: cloud ln Z minus fresh-draw ln Z is
  −0.20 (NO) / −0.24 (IO) at T = 20 and +0.007 / +0.008 with the cap lifted.
  Fresh-draw ESS per 60 000 draws 20 394 → 36 098 (NO) and 11 633 → 37 834
  (IO). Marginal W1 to the MH reference halves (0.0054 → 0.0029 NO,
  0.0095 → 0.0035 IO). Price: wall time 17 min → 12.2 h (NO) / 11.4 h (IO);
  the likelihood is not the bottleneck, the mixture bookkeeping with
  thousands of components is. ln B(NO/IO) from the uncapped fresh-draw
  evidences: 0.403 (protocol fresh: 0.392). The "Lifting the cap" paragraph
  and `fig:nu-tmax` are in the chapter; `73_tmax_study.jl --fresh
  --finished-only` ran at 05:11–06:07 and the export went to the thesis.
* **Seed 23 running** in the same two queue processes (pids 31732 NO,
  29724 IO); at 12:56 NO was at iteration 249, IO at 285; ≈ 5.5 min per
  iteration now; expected to finish 16:30–18:00. A detached chain
  (`out_ablation/chain_tmax_seed23.ps1`, pid 32588) re-runs the study and
  the export when both `result.h5` exist.
* **Seed 41 put on hold** (instruction of 13 Sep: no new run > 3 h without
  approval). Zero-byte `result.h5` placeholders in the two seed-41 run
  directories make `10_run_cell.jl` skip the cell ("cell exists, skipping"),
  so the queue processes end after seed 23; `73_tmax_study.jl` ignores
  zero-byte files (`finished(dir)`). Details: `out_ablation/README-HOLD.md`.

### 16.2 Style pass on the chapter (user feedback on the PDF)

* Captions: the bolded "What is plotted." opener and the "Generated by
  <script>.jl" provenance sentences were not thesis style (surveyed all
  captions of chapters 6–8 and Appendix B). Removed from all 19 neutrino
  captions; "Reading the figure." → "Reading the panels/markers."; table
  provenance moved into `% source:` comments. The remaining structure
  (plain descriptive opener, `\textbf{Settings.}`, `\textbf{Reading the …}`)
  is the one used in the existing chapters.
* The two-flavour oscillation formula `eq:nu-posc` was 38 pt too wide; now
  an `align` with one number, as `06-benchmark-design.tex` does it.
* Literal chapter numbers: none in the new files except one code comment
  ("Ch. 7"), replaced by words. The "Chapter 10" on p. 84 of the old PDF is
  `\cref{ch:conclusion}` in `07-results.tex` resolving correctly — the
  conclusion *is* Chapter 10 once the neutrino chapter is included; the
  sentence's wording ("the natural continuation … takes stock and lays out
  that path") is stale, not the number. Listed with the other seams in
  `docs/MERGE-SEAMS-neutrino.md`.
* Full build: 222 pages, no undefined references, no overfull boxes > 20 pt,
  `scripts/run-all.py` shows no new issues (the `lst:` label warnings are the
  same check-script limitation as for Appendix C).
* Appendix D now ends with `sec:appendix-nu-code` (five listings in the
  Appendix C conventions: config + priors, cube target, cell driver,
  defensive-IS reference, fresh-draw check + cube→physical constant).
* Bibliography: 23 new entries listed in `docs/BIB-ADDITIONS-neutrino.md`
  (key, full reference, DOI/arXiv, where cited, supported claim) for the
  review pass; `Eller2025` → `Eller2026` (arXiv posting 13 Aug 2026).

### 16.3 Self-contained repository

`neutrino/` now carries verbatim copies of the harness
(`harness/experiments/src/**`) and of `MoleWhacker.jl`
(`harness/scripts2/algo/`), with SHA-256 hashes in `harness/PROVENANCE.md`;
all scripts use paths relative to `@__DIR__`/`$PSScriptRoot` and
`--project=.`; smoke tests 01/02 pass. Not yet `git init` — waiting for the
repository URL. `out/` (777 MB) and `out_ablation/` (2.1 GB) must not go
into git; the figures and tables do.

### 16.4 Physics-scope evaluation: full-capacity MoleWhacker, more experiments, ~20 dimensions

**What the three-experiment fit is.** A reactor + long-baseline "mini
global fit": Daya Bay (3158 d) fixes θ₁₃ and |Δm²_ee|, KamLAND (7 y) fixes
θ₁₂ and Δm²₂₁, MINOS (16e20 POT) fixes θ₂₃ and |Δm²_μμ|; five of the six
oscillation parameters are measured from real data, δCP is unconstrained
(no appearance channel in Newtrinos), the θ₂₃ octant is weak (MINOS alone,
P(θ₂₃ > π/4) = 0.63). Every measured value agrees with the publication of
the respective experiment within errors (`tab:nu-physics`), and the
mass-ordering preference ln B = 0.41 is traced to the Δm²_ee–Δm²_μμ
interplay of Daya Bay and MINOS (`fig:nu-mechanism`, subset study). That is
real physics with a real mechanism, and the sampler comparison is made on a
real 11-parameter posterior.

**What is missing for a "global fit"** (NuFIT 6.0 / Capozzi et al. / de
Salas et al. combine solar, reactor, accelerator disappearance *and
appearance*, atmospheric): solar experiments (not in Newtrinos), T2K/NOvA
appearance (not in Newtrinos → no δCP, no strong octant), atmospheric data.
The atmospheric sector is the one Newtrinos *does* offer.

**Inventory of the pinned Newtrinos (fa87689d, `HQ8a8`)** — measured on
this laptop, 4 threads, with the two ablation processes running:

| module | data | free parameters it adds | ms per likelihood call |
|---|---|---|---|
| dayabay + kamland + minos (vacuum) | real | 11 total | 9 |
| same, with matter effects (`osc.SI`) | real | 11 | 12–20 |
| **deepcore** (9 y verification sample, IceCube data release 2025 of PRD 108, 012014) | **real** | +7 detector, +6 atm-flux (Barr) → d = 24 with the three | ≈ 100–130 |
| orca (ORCA6 433 kton·y, KM3NeT open data) | real | +6 detector (+6 flux shared) → d = 30 with the three and DeepCore | ≈ 400–450 |
| super_k (SK I–V atmospheric 2023 release) | real | +18 (unbounded Normal priors) | **fails at this commit** (`xsec.scale` signature mismatch); the release also lacks the systematic response functions |
| juno, tao, ic_upgrade | simulated (Asimov, 6 y) | — | not a real-data result |
| coherent (CEvNS CsI / LAr) | real | no oscillation parameters | irrelevant here |

Atmospheric experiments need Earth-crossing matter propagation; Newtrinos
only defines the layered propagation with `osc.SI`, so `neutrino_problem.jl`
now switches matter effects on automatically when an atmospheric module is
present (`needs_matter`), and keeps vacuum propagation for the thesis
configuration (unchanged protocol, unchanged results).

**Feasibility probe of Daya Bay + KamLAND + MINOS + DeepCore (d = 24, NO):**
config builds (24 free parameters, 7 with Gaussian pulls, all supports
finite); likelihood 98 ms, ForwardDiff gradient 2.7 s (≈ 28 likelihood
walls; counted as 24 units); a 60-iteration L-BFGS from the Newtrinos
nominal point (12.5 min, 4551 units) lands at sin²θ₂₃ = 0.536,
Δm²₃₂ = 2.407e-3 eV², sin²θ₁₃ = 0.02203, sin²θ₁₂ = 0.312,
Δm²₂₁ = 7.73e-5 — the IceCube publication behind the module reports
sin²θ₂₃ = 0.51 ± 0.05 and Δm²₃₂ = 2.41 ± 0.07 × 10⁻³ eV² (NO), and the
module ships the official 90 % contour as CSV for an overlay. A DeepCore-
only scan with nuisances at nominal peaks at maximal mixing
(sin²θ₂₃ = 0.50). The physics is there and it is validated.

**Cost of a 24-parameter campaign at the thesis budget B = 5e5:** pure
likelihood time 5e5 × 0.1 s ≈ 14 h per cell for MH, NS, IS; NUTS ≈ 21 000
gradients × 3 s ≈ 17 h; MoleWhacker ≈ 3.5–4 h (seed phase 62 parallel
L-BFGS starts ≈ 2.6e5 units ≈ 2.5–3 h wall, then 20 refinement iterations
≈ 40 min). The full protocol (5 samplers × 2 orderings × 3 seeds = 30 cells)
is ≈ 400 h — not possible before 28 September on this machine. ORCA6 is
4× more expensive again (60 h per MH cell) — out.

**Recommendation.**
1. Keep the 11-parameter three-experiment campaign as the chapter's core.
   It is complete, protocol-exact, and its physics is right.
2. Offer one extension section "Towards a global fit: adding IceCube
   DeepCore" with d = 24: MoleWhacker (protocol, T_max = 20) and the MH
   reference chain, NO and IO, one seed — 4 cells, ≈ 2 × 4 h + 2 × 14 h
   ≈ 36 h of compute, ≈ 20 h wall in two lanes once the ablation processes
   have finished (tonight). Deliverables: the 24-parameter posterior, the
   (sin²θ₂₃, Δm²₃₂) credible region over the official IceCube 90 % contour
   (physics validation), the sharpened θ₂₃ octant and |Δm²₃₂|, the
   ordering Bayes factor with atmospheric data, nc/ντ-CC normalizations
   constrained by data instead of priors — and the MoleWhacker-vs-MH
   comparison "in 20+ dimensions" that the question was about. Each cell
   exceeds 3 h → needs approval. Optional third lane: NUTS (17 h per cell).
3. Not recommended: ORCA6 (cost), Super-K (module broken at the pinned
   commit; the public release cannot reproduce the SK fit anyway),
   JUNO/TAO/Upgrade (simulation only), COHERENT (no oscillation content).
4. Full-capacity MoleWhacker: answered by the T_max ablation. Keep the
   protocol cells as the like-for-like comparison (same T_max as the
   benchmark), present the uncapped runs as the algorithm's full-capacity
   result (done in the chapter); seed 23 lands today, seed 41 only with
   approval (12 h per ordering).

Probe scripts live in `%TEMP%` (`nu_time_exps.jl`, `nu_probe_deepcore2.jl`);
nothing of this touched the campaign outputs.

### 16.5 Decisions of 13 Sep, 15:00, and the automation now in place

Decided with Valentin: (1) seed 41 of the T_max ablation runs after seed 23
(released; it starts automatically in the two queue processes, ETA 06:00 on
14 Sep); (2) the DeepCore extension runs on the laptop, MoleWhacker
(protocol T_max = 20) then MH, one lane per ordering, seed 11, B = 5e5,
starting automatically when seed 41 has finished. An end-to-end smoke of the
extension cell path (MH, d = 24, B = 2000 → result.h5 / metadata.json /
summary.json in a temporary tree) passed; at the current machine load MH
costs 0.16 s per evaluation, so the MH cells take 17–22 h and the lanes end
Tuesday 15 Sep in the early morning. Chains: `out_ablation/chain_tmax_seed23.ps1`
(pid 32588: seed 23 → T_max study → export) and
`out_extension/chain_extension.ps1` (pid 26048: seed 41 → two extension
lanes → T_max study with seed 41 → export). Progress files:
`out_extension/chain_extension.progress`, `.done`. Cloud computing was
considered and set aside: no GPU path exists in this code, and the bottleneck
is analysis and writing, not CPU time; a 16–32 vCPU box (~10–15 EUR/day)
remains plan B if the laptop is needed or the extension is widened.

Plan for the extension section ("Towards a global fit: adding IceCube
DeepCore"): the (sin²θ₂₃, Δm²₃₂) plane with the official IceCube 90 %
contour and the three-experiment result; three- vs four-experiment marginals
of the six oscillation parameters (NO and IO); MoleWhacker-vs-MH agreement
and cost table at d = 24; parameter table against the IceCube publication;
evidence and ordering factor with and without DeepCore; consistency ratios
Daya Bay–DeepCore and MINOS–DeepCore; nuisance posteriors in the appendix.
Analysis scripts to be prepared while the runs go (own `out_extension/`
tree, never mixed into `out/runs`).

## 17. Status 2026-09-14, 09:30 — seed 41 in, extension lanes running (lane 2 relaunched), section drafted

### 17.1 Runs

Seed 41 of the T_max ablation finished at 01:20 (IO) and 02:18 (NO): NO 296
iterations, N_eff 7.40e4, ln Z −510.868, 9.5 h; IO 328 iterations, N_eff
5.59e4, ln Z −511.271, 9.3 h (both within the seed-11/23 ranges; wall shorter
because nothing else was computing during the night). The extension chain
started the two DeepCore lanes at 02:21. Lane 1 (MW s11 → MH s11, pid 4668) has
been computing since, at 2.7–2.9 cores; the MW cell had not finished after 7 h
(estimate was ~4 h; the per-evaluation cost with three julia processes on the
10-core i5-1335U is higher than the 0.1 s of the probe). Lane 2 had **hung at
start-up**: its julia child (pid 9712) sat for six hours at 9 MB and zero CPU —
the lane was launched as a PowerShell background job (`Start-Job`) inside
`chain_extension.ps1`, and julia never initialised under the job host. Killed
at 08:26 and relaunched as a standalone process with
`out_extension/lane2_extension.ps1` (same `Start-Process` pattern as lane 1,
which works); MW s23 started at 08:33 and is computing (pid 30836). Lesson for
the docs: never start julia from a PowerShell job; use a `-File` process.
Revised ETA: lane 1 Tue 06:00–12:00 (MH ~18–25 h); lane 2 (s23, s41, then the
uncapped run at full budget) Tue afternoon to Wed morning. The uncapped d = 24
run is last in its lane and can be cancelled without loss if time runs out.
The seed-41 fold-in of the T_max study (`73_tmax_study.jl --fresh --reuse-fresh
--finished-only`, cached fresh draws for seeds 11/23, new draws for 41) runs
alongside (pid 14144).

### 17.2 Chapter

`sec:nu-extension` "Towards a Global Fit: Adding IceCube DeepCore" drafted on
the branch (commit 849a324): introduction, model subsection (baselines,
matter effect, sample, 10 × 10 × 2 likelihood, thirteen nuisance parameters,
hypersurfaces, `tab:nu-ext-priors`), protocol; the results subsection is a
`\todo[inline]` placeholder until the runs land. Six bib entries verified and
added (Abbasi2023, IceCube2025DeepCoreData, Honda2015, Barr2006,
Dziewonski1981, Mikheyev1986). Facts corrected against the paper: 8 years
2011–2019, 7.5 y livetime (the module also uses 7.5 y), PID bins
[0.55, 0.75, 1.0] (cascade bin omitted), 82 % ν_μ CC, 2 % muons.

### 17.3 Finding for the Newtrinos authors (report to Philipp)

`src/experiments/icecube/deepcore_9y_verification_sample/deepcore.jl`, function
`get_hypersurface_factor`, line 248 (pinned commit fa87689d): the `p1` term of
the detector-response hypersurface multiplies `(params.deepcore_rel_eff_p1 + 0.05)`
by `interpolate_hypersurface(hypersurface.hole_ice_p0, ...)` — the **p0** slope
table — where the line above uses `hole_ice_p0` for p0 correctly. The `hs_*.csv`
files do contain a `hole_ice_p1` column, so the intended line is
`interpolate_hypersurface(hypersurface.hole_ice_p1, idx, fraction) * (params.deepcore_rel_eff_p1 + 0.05)`.
Effect: the likelihood's dependence on `deepcore_rel_eff_p1` uses the wrong
slopes (p0 slopes are ~0.3, p1 slopes ~1.7 in the first hypersurface row, so the
p1 sensitivity is understated by a factor of a few). Left unchanged in this
work (nothing in Newtrinos was modified); mentioned in a footnote of the
chapter; the `p1^DC` posterior in the appendix is to be read with this in mind.
Also worth mentioning: the hypersurfaces exist for Δm²₃₁ ∈ [1.5, 3.5]e-3 eV²
only, so the module cannot evaluate an inverted-ordering point (BoundsError in
`apply_hypersurfaces`, line 259) — an `abs(Δm²₃₁)` lookup would be the obvious
approximation if the authors want IO support.

### 17.4 Status 2026-09-14, 11:00 — p1 slip checked upstream; decision: no patch, no rerun

Checked against GitHub (API, 14 Sep 10:00): the pinned commit fa87689d (22 Aug
2026) is still the head of `main` (compare fa87689d...main is identical) and the
faulty line is present in every branch, including `claude` (pushed 14 Sep 09:34),
and in all six commits that ever touched `deepcore.jl` (first version b450014a,
29 Sep 2025). None of the 50 issues mentions it; Philipp does not know. The pin is
the same everywhere (Manifest `repo-rev`, README, this briefing, thesis chapter
line "commit fa87689d of the main branch"). Quantified with the new diagnostic
`scripts/86_deepcore_p1_check.jl` (nothing applied to the environment; a corrected
copy of `get_hypersurface_factor` is evaluated into a throw-away session only):
as published, ∂logL/∂p1 = ∂logL/∂p0 = −167.2 at the nominal point, i.e. p0 and p1
enter the likelihood only through their sum and the p1 marginal is essentially
its prior; with the p1 table the slope is −1484.2 (factor 8.9). Results in
`out_extension/tables/deepcore_p1_check.csv`; full write-up and a ready-to-paste
message for Philipp in `docs/REPORT-newtrinos-deepcore-p1.md`.

**Decision (Valentin, 11:00):** no patch, no fork, no rerun — the time budget
does not allow restarting the extension lanes (lane 1 at 8.5 h without a
finished cell). The runs continue with Newtrinos as published; Philipp gets the
report; the footnote is revised once he answers (a rerun is reconsidered only if
he confirms the bug and time permits). A load-time patch that had been prepared
and verified in the morning was removed again; `src/neutrino_problem.jl` states
explicitly that nothing is patched. Consequence for the results section: the
`p1^DC` marginal of the d = 24 cells is expected to be flat (prior), the `(p0, p1)`
pair to show a ridge along p0 + p1 = const; both are to be described as
properties of the published module, not of the sampler.

### 17.5 Status 2026-09-14, 21:30 — d = 24 cost structure measured; MH started as third process; uncapped run cancelled

Lane 1's MW s11 had been running 17 h at 19:20 with empty logs. Diagnosis: the
`ext_deepcore_*` logs are empty because the PowerShell redirect buffers a few KB
and the cells write ~25 lines (the ablation logs only appeared because 300
iterations filled the buffer); progress of d = 24 cells is not observable.
Measured costs (single thread, loaded machine): likelihood 0.221 s, ForwardDiff
gradient 5.9 s (chunk 12, two chunks), ForwardDiff Hessian 290 s — 16x / 38x /
165x the three-experiment values (0.014 / 0.16 / 1.8 s). The refinement loop
(160 Hessians ≈ 5 h on four threads) is not the main cost; the seed phase is:
30 L-BFGS fits (`n_seed_planned` for d = 24) run under BAT's `OptimizationAlg`
defaults (`reltol = 0`, gradient tolerance 1e-8, `maxiters = 1000`). A probe of
the first four Sobol seeds converged in value (log f ≈ −1223.3) after ~125
gradients per seed but kept iterating (36 min, no Hessian yet), so the fits
probably run to the iteration limit: ~2000 half-gradients ≈ 2.5 thread-hours per
seed, ~30 h seed phase per cell, ~35 h per capped cell. Consequence for the
budget: at 24 units per gradient and 576 per Hessian the seed phase may cost
~7e5 > B = 5e5, in which case `whack_many_moles` stops at iteration 0 (budget
check at the top of the loop) and the protocol cell consists of the 30-component
seed mixture plus 2000 IS draws — to be read from the metadata (stop reason,
iteration log) when MW s11 lands. Probe scripts were run from %TEMP% and removed.

Actions (approved 21:21): (1) the uncapped d = 24 run is cancelled
(`queues/ext_deepcore_NO_uncapped.txt` emptied; lane 2 part B will run nothing);
(2) the MH reference s11 was started at 21:24 as a third process (`-t 1`, pid
34184, `out_extension/mh_standalone.ps1`) with `--force`; an empty placeholder
`result.h5` in its cell directory makes lane 1 skip its own MH line (lane 1 will
exit after MW s11). Memory after the start: 0.9 GB available, commit 36.8 of
41.5 GB — tight; Chrome/ChatGPT/AnyDesk (2.7 GB) are still open. Revised ETAs:
MW s11 Tue 08:00–16:00; MW s23 Tue 14:00–22:00; MH s11 Wed 04:00–10:00; MW s41
Thu 00:00–08:00. Analysis of the extension starts when MH lands (Wed), the third
MW seed is folded in Thu. Status script updated accordingly.

### 17.6 Status 2026-09-14, 22:00 - final extension design: adapted seed count (approved)

Structural review of the two designs, requested and approved by Valentin (21:55).
Three-experiment fit (d = 11): complete, nothing left to run - all protocol
cells (IS/MH/MW 3 seeds at 5e4 and 5e5 per ordering, NS 3+2, NUTS 1+2), the six
T_max ablation cells, the subset study, the IS diagnostics, the mechanism figure;
20 figures + 14 tables in the chapter/appendix D, all files present, the build
has no undefined references/citations and no overfull boxes > 5 pt in the
neutrino files (checked 22:20). Only the merge seams remain.

DeepCore extension (d = 24): the protocol's seed rule (`n_seed = 64` capped at
30 % of B with a planning cost of 200 (1 + d) = 5 000 units per seed, i.e. 30
seeds) fails on this target because one L-BFGS seed runs to BAT's 1000-iteration
limit (the DeepCore expectation is piecewise linear in Δm²₃₁: response tables
interpolated linearly between grid points -> discontinuous gradient -> 1e-8
tolerance unreachable), ~30 000 units per seed, 30 seeds ≈ 9e5 > B = 5e5: the
loop's budget check (top of `whack_many_moles`) stops at iteration 0. MoleWhacker
has no budget guard on its optimiser - its cost model assumes cheap mode finding
(goes into the discussion). Decision:
* MH s11 reference: unchanged (pid 34184, since 21:24, -t 1, ~31 h).
* MW protocol cell (30 seeds) s11 in lane 1 (pid 4668, since 02:21): kept as the
  "protocol as specified" data point; its metadata (`iter_log[1].cum_cost`,
  `n_seed_used`, stop reason) gives the exact seed cost -> replaces the
  order-of-magnitude figure in the chapter's protocol paragraph.
* MW with `n_seed = 8 = n_parallel`, everything else protocol, seeds 11/23/41,
  -> `out_extension_nseed8/` (never mixed into `out_extension/runs`). Budget
  arithmetic: 8 x ~30 000 ≈ 2.4e5 for the seeds, ~2.6e5 left for the loop (~40
  iterations at ~6 600 per iteration: 8 Hessians x 576 + 2000 draws), so
  T_max = 20 is reachable. Wall time ~11-13 h per cell (two rounds of four
  parallel L-BFGS fits ≈ 6 h + loop ≈ 5 h). `tab:bench-mw-config` explicitly
  allows a revised value if reported with the result table - done in the
  protocol paragraph, to be repeated in the caption of `tab_nu_ext_samplers`.
  Alternative n_seed = 4 (what the 30 % share gives literally) rejected for the
  octant-coverage risk; fallback if the protocol cell shows > 60 000 units/seed.
* Implementation: `--nseed N` plumbed through `10_run_cell.jl` and
  `11_run_queue.jl` (parse-checked); queues `ext_deepcore_NO_nseed8.txt` (s11,
  s23) and `ext_deepcore_NO_nseed8_s41.txt`; `out_extension/switch_to_nseed8.ps1`
  (pids pinned - julia children expose no command line) stopped lane 2 (host
  22052 + julia 30836, the 30-seed MW s23 13.5 h in; partial cell moved to
  `out_extension/_stopped_30seed_s23_20260914_2159`), started
  `lane2_nseed8.ps1` (julia pid 27480, s11 then s23) and `lane1_after_nseed8.ps1`
  (waits for pid 4668 to exit, then MW s41). Verified 22:12: all three julia
  processes busy (178 % / 272 % / 99 %), cell dir of nseed8 s11 created 22:03,
  1.0 GB RAM free.
* Not done, final: inverted ordering (module), NUTS/NS/IS at d = 24 (cost), the
  uncapped d = 24 run (cancelled), more MH seeds, a second budget tier (one
  budget only, B = 5e5).
* ETAs: nseed8 s11 Tue 09-11 h; protocol cell Tue 08-16 h; nseed8 s23 Tue
  20-24 h; MH Wed 04-10 h; nseed8 s41 Wed 00-05 h. Analysis Wed, section
  Wed/Thu. Analysis scripts 81/82/83/85 to be pointed at the two roots
  (protocol cell + MH in `out_extension`, MW set in `out_extension_nseed8`).

### 17.7 Status 2026-09-15, 08:50 - protocol cell landed: prediction confirmed

`out_extension/runs/nu_dakamide_NO_mw_d24_B5e5_seed11` finished 00:21 after
21.9 h (earlier than the 30-35 h estimate: the machine had more CPU for it once
the 30-seed s23 was stopped). Metadata: `n_seed_used = 30`, one `iter_log`
entry (iteration 0), `cum_cost = 836 621` = 167 % of B, `stop_reason = budget`,
N_eff = 18.1 from the 2000 seed-mixture draws (efficiency 0.9 %), cloud
ln Z = -1260.36 (2000 draws, ESS 18: not a usable evidence). Counter:
`n_grad_partials = 801 888`, `n_primal = 34 733` -> per seed 1090 gradients +
~1090 function evaluations + one Hessian = 27 800 units (planning rule: 5 000).
The duplicate merge reduced 30 -> 11 components (19 duplicates, weight 0.80):
the Sobol seeds end at different points of the flat p0 + p1 ridge (the
published module's exact degeneracy) rather than at distinct modes - to be
checked in the results analysis (component means along p0, p1).
Chapter: protocol paragraph now carries the measured numbers (1090 gradients,
2.8e4 units per seed, 8.4e5 units = 167 %, 21.9 h, stop at iteration 0; the
n_seed = 8 initialisation = 2.2e5 units = 45 %). Todo box updated.
Lanes at 08:45: nseed8 s11 running 10.7 h (RAM 4.9 GB - the cloud grows with
the iterations, expected); nseed8 s41 started 00:28 in lane 1 (waiter worked);
MH at 629 CPU-min / 11.3 h = 78 % of a core -> ~34 % of its 5e5 steps, ETA Wed
06:00-14:00. Free RAM 3.3 GB.

### 17.8 Status 2026-09-15, 10:45 - OUT OF MEMORY at 10:00; three cells lost; memory-staggered relaunch

At ~10:00 all three running julia processes raised `OutOfMemoryError` within
minutes of each other: MH s11 (192 585 of 500 000 steps, 12.6 h), MW n_seed = 8
s11 (after iteration 15, 355 367 units, 12.0 h) and MW n_seed = 8 s41 (first
Hessian batch of the loop, 286 166 units, 9.7 h). Cause: system-wide commit
exhaustion (limit 47 GB = 15.5 GB RAM + 32 GB system-managed pagefile, already
at its maximum). Baseline at the time ~27 GB (two MW processes ~5 GB private
each, MH 1.5, Cursor 3, Chrome 2.7, msedgewebview2 2.0, ChatGPT 1.7, Wispr Flow
0.9, Slack 0.7, Claude 0.6, Perplexity 0.6, AnyDesk 0.5, system ~2); the nested
ForwardDiff Hessians of the DeepCore likelihood (chunk 12 x 12 duals, large
tables) are transient memory spikes of several GB per thread, and both MW
processes were in their Hessian phase (s41 iteration 0 -> 1, s11 iteration
15 -> 16) with 4 threads each. Failed cells (result.h5 with neff = 1, notes
"sampler raised") archived with their logs under
`out_extension_nseed8/_oom_20260915_1000/` and `out_extension/_oom_20260915_1000/`.
The cell running in lane 2 (s23, pid 27480, started 10:04 - i.e. seconds after
the OOM, in its own seed phase, so unaffected) continues.

What the lost s11 log proves (kept for the thesis, reproducible by the rerun):
iteration 0: 8 seeds -> 4 components after the duplicate merge, eff 0.13 %,
ESS 2.6 of 2000; iteration 1: 8.9 %, 180; 5: 29 %, 609; 10: 35 %, 789;
15: 41 %, ESS 927, cloud 2253 samples. Cost per whacking iteration ~8 700
units ((355 367 - 224 000) / 15). So n_seed = 8 does exactly what it was
chosen for; T_max = 20 would have been reached at ~400 000 units.

Relaunch 10:32 (`out_extension/relaunch_after_oom.ps1`), designed so that two
MW processes are never in their Hessian phase simultaneously:
* MH reference: two cells, seeds 11 and 23, B = 2.5e5 each (`10_run_cell.jl`,
  -t 1; the harness MH runs four internal chains per cell, so this is eight
  chains pooled at the same 5e5 total, as the three seeds were pooled at
  d = 11), pids 27868 / 34132 -> ~Wed 02:00-07:00. Cell dirs `..._mh_d24_B250000_seed11/23`.
* MW n_seed = 8: s23 in lane 2 (running) -> ~Tue 18-20 h; s11 in lane 1 from
  14:00 (`lane_nseed8_delayed.ps1 -Seed 11 -StartAt 14:00`) -> ~Tue 22-24 h;
  s41 in lane 3 when pid 27480 exits (`-Seed 41 -AfterPid 27480`) -> ~Wed 03-05 h.
* `mem_watchdog.ps1`: polls the commit charge every 5 s, kills the julia
  process with the largest private memory above 44 GB, reports every 30 min
  to `chain_extension.progress`.
* Valentin asked to keep Chrome/ChatGPT/Slack/Perplexity/Wispr/Claude/AnyDesk
  closed (~10 GB of commit) until Wednesday.
Chapter: protocol paragraph now describes the two-seed MH reference; todo box
records the OOM and the s11 trajectory. Analysis scripts (82/83) must select
the MH cells by the maximum MH budget in the root (B = 250000, not BTOP) - to
do before the Wednesday analysis.

### 17.9 Status 2026-09-15, 10:55 - pause/resume for the user; disk check

Valentin needs Chrome + AnyDesk for about an hour (15-16 h). Added
`scripts/96_pause_resume.ps1` (+ `pause.cmd` / `resume.cmd`): suspends the
MoleWhacker julia processes via `NtSuspendProcess` (MH keeps running; `-All`
includes MH), resumes via `NtResumeProcess`; MH pids in `out_extension/mh_pids.txt`.
Tested live on the s23 lane (8 s pause: 0.00 s CPU during, resumed at 2.6
cores). A suspended process keeps its memory (commit unchanged) but cannot spike,
which is what matters while the apps are open. Waiters are unaffected (a
suspended lane is alive). Each paused hour shifts the MW ETAs by one hour.

Progress lost by the OOM: MH s11 12.6 h, MW s11 12.0 h, MW s41 9.7 h of compute
(~half a day of calendar time). Intact: the whole three-experiment campaign, the
T_max ablation, the protocol cell (30 seeds), the s23 cell, the s11 iteration
trajectory (CSV).

Disk: C: 28.7 GB free of 952 GB. Enough for the runs (outputs < 1 GB; the
system-managed pagefile is at 31.7 GB and could grow to at most 46.5 GB). Big
reclaimable items if wanted later: Docker data 27.8 GB (`%LOCALAPPDATA%\Docker`,
WSL vhdx), hiberfil.sys 6.2 GB (`powercfg /h off`), .julia depot 10.4 GB
(needed). No action taken.

### 17.10 Status 2026-09-15, 12:40 - disk freed; analysis pipeline adapted to the two-chain reference; results section pre-drafted

Disk: the legacy benchmark results of the old pipeline
(`02_molewhacker\MoleWhacker\results`, 137 GB, Aug 2025 - Feb 2026) were
validated as unused by the thesis (all 91 benchmark figures come from the
V5-V8 harness `experiments/out` and exist in the published
`molewhacker-bench` repository; no thesis, harness or bench-repo file
references the folder) and Valentin deleted the 137 GB of `.jld2` dumps;
`results_2` (96 GB, same era, same verdict) is the next candidate. C: now has
~170 GB free.

Analysis: `82_extension_plots.jl` / `83_extension_tables.jl` /
`85_extension_analysis.ps1` now treat the MH reference as the pool of the two
`B = 2.5e5` chains (`mh_B`: the top MH budget of a root; cell directories
`nu_dakamide_NO_mh_d24_B250000_seed{11,23}`; `20_aggregate.jl` already
pooled top-budget MH and does leave-one-chain-out for the MH rows). Step 0 of
the orchestration copies every finished MH chain into `out_extension_nseed8`.
The whole chain (aggregate x 2, plots, tables) was run on synthetic d = 24
cells built from the protocol cell (fixture in `%TEMP%\ext_fake`, nothing in
the repository): layouts checked and fixed (legends below the axes in the plane
and seed-count figures, the seed-count figure's cost axis linear in 1e5 units
because the range spans less than a decade, a 1e-4 floor on the log agreement
axis so that a parameter with W1 = 0 cannot blank the figure, MH markers per
chain plus their pool). `81_extension_fresh.jl` is untouched (MW only); at
0.22 s per evaluation its 3e4 draws per cell cost ~0.5 h per cell on four
threads, ~2 h for the four MW cells - run it after the cells land, not while
they run.

Protocol cell, component anatomy (from `result.h5`, mixture in
PriorToNormal space mapped back through the normal CDF): 30 fits -> 11
distinct components after the duplicate merge; 9 lower octant
(sin^2 theta_23 = 0.45-0.47), 2 upper (0.534, 0.538). The distinct optima
differ in delta_CP (2.6-2.75 vs 5.49), in the flux-ratio pulls
sigma_{nue/nuebar} and sigma_{numu/numubar} (near 0 in eight fits, -1.9 to
-3.0 = the truncation edge in three), in the KamLAND energy scale (-0.83 to
+0.27) and in p1 (-0.05 in ten, 0.006 in one; p0 + p1 roughly constant, the
degenerate ridge of the p1 slip). Mixture weights (target density at the mode
over mixture density): 0.638 / 0.203 / 0.159 on three lower-octant components,
< 1e-3 on the other eight including both upper-octant ones. Cloud ln Z (cube)
-1260.36 from the 2000 draws (ESS 18; not a usable estimate).

Thesis side (branch `neutrino-chapter`): FIGURES-INDEX rows for the six
extension figures (status `missing`); `docs/DRAFT-nu-ext-results.tex`
pre-drafts the results subsection - protocol-cell paragraph, all figure and
table captions final, every number that depends on the n_seed = 8 cells or the
reference marked `<<...>>`; STATUS.md updated.

Runs at 12:40: MW n_seed = 8 s23 (pid 27480, since 10:04), MH s11 and s23
(pids 27868, 34132, since 10:32), all busy; lane 1 (MW s11) starts 14:00, lane 3
(MW s41) after s23; watchdog and both lane hosts alive; commit 24 of 47 GB.

### 17.11 Status 2026-09-16, 11:40 - all cells landed; analysis done; results section written

Cells (all NO, B = 5e5): MW n_seed = 8 s23 finished 23:26, MH s11/s23 (2.5e5
each) 23:51/23:53, MW s11 04:14 (resumed 23:26 after the suspension), MW s41
07:44 (started 23:55 with --heap-size-hint=5G, alone on the machine for most
of its run: 7.7 h; the shared/suspended cells took 13.4 and 14.2 h). All three
n_seed = 8 cells: seed phase 283 570 units (57 %; 35 196 per fit, more than
the protocol cell's 27 821 because the 8 Sobol points differ from the first 8
of 30), 8 -> 4 distinct seed components, 20 iterations at ~4 650 units each,
164 components, stop = T_max at 376.3-376.7k units. Cloud N_eff 1055 / 968 /
460 (eta 2.8 / 2.6 / 1.2e-3); MH 38.5 / 36.6 per chain (eta 1.5e-4), acceptance
0.28, split R-hat(theta_23) 1.09 / 1.03, per-chain upper-octant fraction
0.32-0.64.

Pipeline: `85_extension_analysis.ps1` had a real bug - the Step function's
parameter was named ``, PowerShell's automatic variable, so every julia
call ran with no script and exited at once (the 08:24 run "finished" in 8 s);
renamed to ``. Fresh-draw step: 4 cells x 3e4 evaluations took 1 h 47
on 8 threads (4.6 cores effective). `83`: fresh efficiency now in scientific
notation. `82`: fixed y ticks of the seed-count figure. Figures exported
(26 of 26), thesis builds (239 pp, no undefined refs).

THE central sampler finding (fresh.csv, plus %TEMP% diagnostics
`mixture_check.jl` / `fresh_anatomy.jl`, nothing in the repo): fresh
draws from the final 164-component mixtures have ESS 117 / 245 / 111 of 3e4
(eff 0.4-0.8 %, Pareto k 0.96 / 0.89 / 0.87) while the cloud claims 37 %; the
11-component seed mixture of the protocol cell gives ESS 635 (2.1 %, k 0.85).
Fresh ln Z -1260.57 / -1260.79 / -1260.66 (+-0.06-0.09) and -1260.90 +- 0.04
vs cloud -1262.00 +- 0.06: the pooled-cloud offset is 1.3 units at d = 24
(0.2 at d = 11). Fresh P_upper 0.44 / 0.53 / 0.41 and 0.40 vs cloud 0.34-0.37
vs MH 0.50. Mechanism (MoleWhacker.jl whack_many_moles): the cloud = 2000
seed-mixture draws + draws from each new component in proportion to its
weight, re-weighted every iteration with the CURRENT mixture density; for the
old draws that is not an importance weight. With 22-29 of 164 components above
weight 1e-3 and only 370-850 new draws, the cloud is the seed-mixture sample
with smoothed weights. Anatomy of the fresh weights (seed 11, 4000 draws, eff
3.3 %): the heaviest weights come from the tails of the dominant components
c1/c2/c35/c111 (log q -9 to +1 at similar log p), not from the wide late
components (sd up to 135 in z-space, but ~0 mixture weight); draws from the
two dominant components alone have eff 5.7 %. => The refined mixture is a
worse proposal than the seed mixture; the honest MW efficiency at d = 24 is
eta = 3-6e-4 (2-4x MH), the protocol seed mixture 7.3e-4 (5x MH). This is
written into the chapter as the central sampler result, with the octant
conclusion revised to P_upper = 0.4-0.5 (the cloud's 0.36 is the biased
outlier) and ln Z_cube = -1260.7 (physical -1251.4).

Physics (chapter, tab:nu-ext-physics): Delta m^2_32 = 2.406 +- 0.030 (cloud)
/ 2.407 +0.037-0.038 (MH) / 2.404-2.411 +- 0.037 (fresh) vs 2.448 +- 0.051
before; sin^2 theta_23 0.479 +0.052-0.043 (cloud) / 0.500 +0.063-0.059 (MH) /
0.489-0.503 +- 0.05 (fresh); sin^2 2theta_13 0.0860 +- 0.0030, Delta m^2_21
7.75 +- 0.20, sin^2 theta_12 0.312 unchanged; delta_CP flat by neither sampler
(MW 2.8 +- 1.6, MH 3.6 +- 1.7 vs pi +- 1.8). Nuisance: A_eff 0.84 +- 0.03,
mu 1.2 +- 0.3, opt 1.07 +- 0.02, abs 0.97, sca 0.99, p0 -0.23 +- 0.10, p1 =
prior, Delta gamma 0.05 +- 0.02, n_NC 0.94 +- 0.12 (from 0.86), n_nutau
0.97 +- 0.17. Agreement (W1/sigma_MH): 18 of 24 within 2x the chain-vs-chain
noise; outliers theta_23, delta_CP, KL energy scale (flat/multimodal; cloud
bias) and A_eff, opt, Delta gamma (0.1-0.2 sigma shifts).

For Philipp (message material): (1) the p1 slip (17.3); (2) the pooled-cloud
estimator of whack_many_moles is not a valid IS estimator once the mixture is
a poor proposal - a deterministic-mixture (balance-heuristic) weighting of the
batches or a final fresh draw should replace it; (3) the seed phase has no
budget guard and the planning constant 200 (1 + d) fails on piecewise-linear
likelihoods (L-BFGS to the 1000-iteration cap); (4) the loop's added
components (Hessian at a heavy draw, weight from the mode-density ratio) do
not improve the mixture as a proposal at d = 24.

### 17.12 Status 2026-09-20 - physics figures of the extension; terminology unified in the thesis

New `scripts/84_extension_physics.jl` (includes 82 + the Newtrinos problem):
`nu_ext_data` (DeepCore sample vs posterior predictive of the four-experiment
fit: track-like vs E and vs cos theta_z with ratio panels; ratio to no
oscillation vs L/E for both PID bins, baseline from the zenith angle with a
15 km production height, 12 log bins; 240 population draws), `nu_ext_tri_NO`
(triangle plot of the five measured parameters, population vs MH, format of
nu_tri_NO), `nu_ext_tri_atm_NO` (theta_23, Delta m^2_31 + A_eff, Delta gamma,
opt, mu: Delta m^2_31 anti-correlated with Delta gamma and opt, A_eff with
both, theta_23 with none), `nu_ext_octant` (sin^2 theta_23: three exp. vs
four; population / fresh draws / MH with P_upper printed).
`81_extension_fresh.jl` now stores the fresh draws as
`out_extension_nseed8/fresh/<kind>__<cell>.jld2` (the first version used the
cell name only and the protocol cell overwrote the n_seed = 8 seed-11 file,
both being `nu_dakamide_NO_mw_d24_B5e5_seed11`; fixed with the kind prefix
and a `--only kind:seed` switch, seed 11 redone). Export map extended
(nu__extdata, nu__exttri, nu__exttriatm, nu__extoctant).

Numbers behind nu_ext_data (`tables/deepcore_posterior_predictive.csv`):
21 914 observed (11 199 track-like, 10 715 cascade-like), no-oscillation
expectation 28 532, posterior-predictive median 21 865; track-like ratio to
no oscillation 0.38 at L/E = 400-700 km/GeV, cascade-like 0.60.

Thesis (branch neutrino-chapter): paragraphs "The data and the fit" and
"Joint structure", the octant figure in "The octant", appendix D: the
atmospheric triangle plot and listing lst:nu-ext-ppd. Terminology rule table
in `.cursor/rules/01-writing-style.mdc`; applied thesis-wide: triangle plot
(not corner), initialization phase (not seed phase), initial mixture (not seed
mixture), accumulated population / population estimator (not pooled cloud /
cloud), MH reference (not chain reference); glossary entries added.

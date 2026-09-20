# Chapter draft — Neutrino oscillation parameters from a joint Bayesian fit of Daya Bay, KamLAND and MINOS

Status: **working draft, 12 Sep 2026, campaign complete** (51 cells: the full
grid of §2.3 plus two nested-sampling runs to convergence and one KamLAND-only
fit), written outside the thesis (nothing in `02_molewhacker` has been touched).
Numbers marked **[MW]** are from the MoleWhacker cells (3 seeds per ordering,
top budget); all tables are generated from `neutrino/out/tables/*.csv`.
Figures referenced as `neutrino/out/figs/*.pdf` are the current renders.

Intended place in the thesis: a new results chapter after the benchmark chapter,
plus a rewrite of abstract, introduction (physics motivation first), and
conclusion so that the physics question carries the thesis and the sampler
benchmark becomes the means, not the end.

> **Superseded (12 Sep 2026, evening).** The chapter has been written out in
> LaTeX on the thesis branch `neutrino-chapter`
> (`chapters/07-neutrino-application.tex`, `appendices/D-neutrino-supplement.tex`),
> with the thesis macros, acronyms, figure conventions and check scripts. That
> text is the reference from now on; this file is kept as the record of the
> campaign numbers and of the argument as it developed. Later additions
> (subset study, prior sensitivity, iteration-cap ablation) are documented in
> `README.md` ("Side studies") and in the LaTeX chapter, not here.

---

## 1  The physics question

Neutrino flavour oscillations are described by the three-flavour PMNS mixing
matrix (three angles θ₁₂, θ₁₃, θ₂₃ and one CP phase δ_CP) and two independent
mass-squared differences Δm²₂₁ and Δm²₃₁. More than a decade after the
measurement of θ₁₃ the remaining open questions of the standard three-flavour
picture are

1. the **θ₂₃ octant** — is θ₂₃ below or above 45°? ν_μ disappearance measures
   sin²2θ₂₃ and is therefore nearly blind to the octant, which leaves a
   genuinely bimodal posterior;
2. the **mass ordering** — sign of Δm²₃₁ (normal, NO, or inverted, IO);
3. the value of **δ_CP**, which requires appearance data and is not accessible
   to the disappearance-only data used here (the posterior must come back flat;
   this is a built-in sanity check).

Each experiment in the fit constrains a different sector, and the constraints
are only weakly coupled through the shared mixing matrix:

| experiment | channel | baseline / energy | dominant sensitivity |
|---|---|---|---|
| Daya Bay (3158 d, 2023 release) | reactor ν̄ₑ disappearance | ~0.5–1.9 km, few MeV | sin²2θ₁₃, \|Δm²₃₂\| (via Δm²_ee) |
| KamLAND (7-year spectrum) | reactor ν̄ₑ disappearance | ~180 km, few MeV | Δm²₂₁, tan²θ₁₂ |
| MINOS + MINOS+ (2017 two-detector release, beam, 10.56 + 5.80 ×10²⁰ POT) | ν_μ disappearance (CC) + NC | 735 km, 0.5–20 GeV (3 GeV and 7 GeV beam configurations summed) | sin²2θ₂₃, \|Δm²₃₂\| |

A joint Bayesian fit answers questions that the individual publications do
not: it propagates the θ₁₃ constraint of Daya Bay into the KamLAND solar-sector
fit and into the MINOS atmospheric-sector fit with a single consistent set of
nuisance parameters, it yields the posterior probability of the upper octant,
and — through the marginal likelihood (evidence) of each ordering — a Bayes
factor for NO versus IO on exactly this data set.

The likelihoods are those of **Newtrinos.jl** (P. Eller), version `fa87689d`
(main, 22 Aug 2026), used unchanged. Newtrinos provides, per experiment,
the binned expectation as a function of the oscillation and nuisance
parameters and the corresponding log-likelihood on the released data.

## 2  Statistical model

### 2.1  Parameters and priors (11 dimensions)

Oscillation parameters (6), priors as configured in Newtrinos:

| parameter | prior | note |
|---|---|---|
| θ₁₂ | U(0.4205, π/4) | sin²θ₁₂ ∈ [1/6, 1/2] |
| θ₁₃ | U(0.10, 0.20) | |
| θ₂₃ | U(π/6, π/3) | sin²θ₂₃ ∈ [0.25, 0.75]; both octants |
| δ_CP | U(0, 2π) | expected flat |
| Δm²₂₁ | U(6.5, 9.0)·10⁻⁵ eV² | |
| Δm²₃₁ | U(2.0, 3.0)·10⁻³ eV² (NO) / U(−3.0, −2.0)·10⁻³ eV² (IO) | ordering selects the sign |

Nuisance parameters (5):

| parameter | experiment | prior |
|---|---|---|
| ε_E^KL  energy-scale pull | KamLAND | N(0,1) truncated to [−3, 3] |
| ε_Φ^KL  flux-scale pull | KamLAND | N(0,1) truncated to [−3, 3] |
| ε_geo^KL geo-neutrino scale | KamLAND | U(−0.5, 0.5) |
| n_NC  NC normalisation | MINOS (cross sections) | N(1, 0.2) truncated to [0.4, 1.6] |
| n_ντCC  ν_τ CC normalisation | MINOS (cross sections) | N(1, 0.2) truncated to [0.4, 1.6] |

Daya Bay enters without free nuisance parameters in this Newtrinos version
(its systematic uncertainties are folded into the released covariance).

### 2.2  Posterior on the benchmark cube

The thesis benchmark harness samples a density on the cube [−L, L]^d with a
flat prior. Each parameter is mapped affinely from its cube coordinate to its
prior support (for the truncated normals: the truncation interval), and the
Gaussian factor −½z² of each truncated-normal prior is added to the counted
log-likelihood. The prior box therefore *is* the cube, the mapping is exact,
and

    ln Z_phys = ln Z_cube + Σ_gauss ln[(b−a) / (√(2π) σ C)],   C = Φ((b−μ)/σ) − Φ((a−μ)/σ)

with a constant (= 4·ln 2.40 = 3.50 for the four truncated normals) that is
identical for NO and IO, so **the NO/IO Bayes factor is the ratio of the
cube-normalised evidences exactly**. All numbers below quote ln Z_cube.

Every likelihood call is counted; a gradient call (needed by NUTS and by the
MoleWhacker seed optimiser) is charged d = 11 cost units, as in the benchmark
chapter. One likelihood evaluation costs ≈ 6 ms on the campaign machine
(12 logical cores), so a budget of 5·10⁵ cost units corresponds to roughly
50 minutes of single-core likelihood time.

### 2.3  Samplers and protocol

Same five samplers and the same protocol as the benchmark chapter (MoleWhacker
hyper-parameters of Table 6.2: n_seed = min(64, 0.3·B / (200(1+d))),
T_max = 20, 2000 draws per iteration, 8 parallel refinements): MoleWhacker
(MW), random-walk Metropolis–Hastings with 4 chains (MH), NUTS, ellipsoidal
nested sampling with n_live = 25·d² = 3025 (NS), and importance sampling from
the prior (IS). Budgets B = 5·10⁴ and 5·10⁵, seeds 11, 23, 41, both orderings.
NUTS cannot finish its warm-up below ≈ 2·10⁵ cost units on this problem and is
therefore run at 5·10⁵ only (one documentation cell per ordering at 5·10⁴).
NS at the protocol n_live does not reach the evidence criterion within
5·10⁵; one NS run per ordering is therefore continued to its own stopping
criterion Δln Z < 0.5 (reached after 8.4–8.5·10⁵ evaluations). It was planned
as the evidence reference but turned out to be biased (§3.3), so the evidence
reference is instead an independent, unbiased estimator that uses no sampler
of the protocol: importance sampling from a defensive kernel mixture fitted
to the pooled top-budget MH chains (3 000 Gaussian kernels with covariance
h²·Σ_MH, mixed with 10 % uniform prior; 1.5·10⁵ draws; two bandwidths
h = 0.6, 0.9 as a robustness check; `70_evidence_check.jl`). Its estimate is
unbiased for Z by construction, carries a standard error from the weights,
and is cross-checked against the pooled plain-IS draws of the campaign.

## 3  Results — physics

### 3.1  Oscillation parameters  (`nu_marginals_NO.pdf`, `nu_marginals_IO.pdf`)

Posterior medians and central 68 % intervals, MoleWhacker, pooled over three
seeds at B = 5·10⁵ **[MW]**, compared with the published single-experiment
results and the NuFIT 6.0 global fit:

| observable | this fit, NO | this fit, IO | published | NuFIT 6.0 (NO) |
|---|---|---|---|---|
| sin²2θ₁₃ | 0.0854 (+0.0033 −0.0031) | 0.0857 (+0.0031 −0.0031) | Daya Bay 0.0851 ± 0.0024 | 0.0866 ± 0.0022 (from sin²θ₁₃ = 0.02215) |
| Δm²₃₂ [10⁻³ eV²] | 2.448 (+0.053 −0.051) | −2.539 (+0.055 −0.055) | Daya Bay 2.466 ± 0.060 (NO), −2.571 ± 0.060 (IO); MINOS+ 2.40 (+0.08 −0.09) | 2.438 (+0.021 −0.019) |
| Δm²₂₁ [10⁻⁵ eV²] | 7.745 (+0.23 −0.22) | 7.72 (+0.23 −0.22) | KamLAND 7.49 ± 0.20 | 7.49 ± 0.19 |
| tan²θ₁₂ | 0.460 (+0.10 −0.065) | 0.467 (+0.10 −0.066) | KamLAND 0.436 (+0.102 −0.081) | 0.445 (from sin²θ₁₂ = 0.308) |
| sin²θ₁₂ | 0.315 (+0.036 −0.032) | 0.318 (+0.037 −0.032) | — | 0.308 (+0.012 −0.011) |
| sin²θ₂₃ | 0.59, 68 % [0.39, 0.66] (bimodal) | 0.62, 68 % [0.37, 0.67] (bimodal) | MINOS+ 0.43 (+0.20 −0.04) | 0.470 (+0.017 −0.013) |
| sin²2θ₂₃ | 0.942 | 0.922 | — | 0.996 |
| δ_CP | flat (mean 2.96, sd 1.83 vs. 3.14, 1.81 for U(0,2π)) | flat | — | — |

Reading:

* θ₁₃ and Δm²₃₂ reproduce the Daya Bay results to well within one published
  standard deviation; the joint Δm²₃₂ is pulled ≈ 0.3σ below Daya Bay by MINOS
  and coincides with the NuFIT value.
* The solar sector reproduces the KamLAND mixing angle. **Δm²₂₁ comes out
  1.2σ above the KamLAND publication.** The KamLAND module of Newtrinos is
  built from spectra digitised from the figures of the 2011 paper (data,
  no-oscillation prediction, geo-ν and background templates), and the
  systematic model is reduced to three pulls; a 1σ-level shift in the
  spectral-shape parameter Δm²₂₁ is the expected size of that approximation.
  A KamLAND-only fit (MW, 9 parameters, `nu_ka_NO_mw_d9_B5e4_seed11`) gives
  the same Δm²₂₁ = 7.74 ± 0.23 and tan²θ₁₂ = 0.466 (+0.10 −0.07), so the
  shift is a property of the digitised KamLAND likelihood itself, not of the
  combination with Daya Bay and MINOS, and it is reproduced identically by
  every sampler (§4). In the same KamLAND-only fit the parameters KamLAND
  cannot constrain (θ₂₃, Δm²₃₁, δ_CP) come back exactly as their priors
  (means 0.785 / 2.51·10⁻³ / 3.16, sd 0.153 / 0.28·10⁻³ / 1.82 vs. the
  uniform-prior values 0.785 / 2.50·10⁻³ / 3.14, 0.151 / 0.29·10⁻³ / 1.81) —
  a useful sanity check of the sampler on flat directions.
* δ_CP is flat, as it must be for disappearance-only data.

### 3.2  The θ₂₃ octant  (`nu_octant_NO.pdf`, `nu_octant_IO.pdf`)

The θ₂₃ posterior is bimodal with modes at sin²θ₂₃ ≈ 0.39 and ≈ 0.63. The
leading ν_μ disappearance amplitude is 4 s²₂₃c²₁₃ (1 − s²₂₃c²₁₃), so the two
degenerate solutions are mirror images about s²₂₃ = 1/(2c²₁₃) = 0.511, not
about maximal mixing — which is exactly where the two modes sit
(0.39 + 0.63 = 1.02). The precise Daya Bay θ₁₃ fixes this offset; the
residual preference between the two modes comes from the sub-leading
θ₁₃- and Δm²₂₁-dependent terms. Posterior probability of the upper octant:

    P(θ₂₃ > π/4 | data) = 0.63 (NO), 0.62 (IO)      [MW, seed spread ±0.02]

i.e. a mild preference only (posterior odds 1.7 : 1). This is the quantity a
sampler must get right on this problem — a sampler that visits only one mode
reports P = 0 or 1 with full confidence (§4).

**Frequentist cross-check** (`nu_profile_NO.pdf`, `50_profile.jl`; profile
likelihood with Newtrinos' own LBFGS profiler, 31 grid points over the prior
box, all other parameters optimised): the profile has its global minimum at
sin²θ₂₃ = 0.64 (NO) / 0.655 (IO), a second local minimum at sin²θ₂₃ ≈ 0.39
with Δχ² = 1.1 (NO) / 1.3 (IO), and disfavours maximal mixing at
Δχ² = 4.1 (NO) / 5.4 (IO). The Bayesian marginal and the profile likelihood
ratio have the same shape; the likelihood ratio between the two minima,
e^{−1.1/2} = 0.58, corresponds to odds 1.7 : 1 for the upper octant —
the same number as the posterior mass ratio, as expected for two modes of
similar width under a flat prior. For Δm²₃₁ the profile minimum
(2.53·10⁻³ NO, −2.50·10⁻³ IO) coincides with the posterior median and the
Δχ² = 1 half-width (≈ 0.05·10⁻³) with the posterior standard deviation.

### 3.3  Mass ordering  (`nu_evidence.pdf`, `tab_nu_evidence.tex`)

Cube-normalised log-evidences (all estimators in the same convention):

| estimator | evaluations | ln Z(NO) | ln Z(IO) | ln K(NO/IO) |
|---|---|---|---|---|
| **reference**: defensive IS on the pooled MH chains (two bandwidths) | 1.5·10⁵ (+ the MH chains) | −510.87 ± 0.01 | −511.28 ± 0.01 | **0.42 ± 0.01** |
| plain IS, all campaign draws pooled | 6.5·10⁵ | −510.46 ± 0.29 (ESS 12) | −511.22 ± 0.18 (ESS 32) | 0.76 ± 0.34 |
| MoleWhacker, 3 seeds, B = 5·10⁵ **[MW]** | 1.15–1.18·10⁵ | −511.09 ± 0.01 | −511.54 ± 0.03 | 0.45 ± 0.02 |
| MoleWhacker, 3 seeds, B = 5·10⁴ | 3.7–3.8·10⁴ | −511.00 ± 0.01 | −511.42 ± 0.03 | 0.42 ± 0.02 |
| NS, n_live = 3025, B = 5·10⁵ (call cap, 2 seeds) | 3.4·10⁵ | −509.53 ± 0.11 | −509.80 ± 0.04 | 0.27 ± 0.08 |
| NS, n_live = 3025, run to Δln Z < 0.5 | 8.4–8.5·10⁵ | −509.39 ± 0.05 | −509.17 ± 0.05 | −0.23 ± 0.07 |
| IS, B = 5·10⁵ | 5·10⁵ | −510.62 (ESS 10) | −511.40 (ESS 26) | 0.78 |

Physics reading: **ln K = 0.42 ± 0.01, K ≈ 1.5** — on the Jeffreys scale
"not worth more than a bare mention". The three experiments alone carry
essentially no mass-ordering information, as expected for vacuum-dominated
disappearance measurements; the ordering sensitivity of global fits comes
from matter effects (atmospheric and long-baseline appearance data) that are
not part of this data set. The small positive value arises from the slightly
better simultaneous fit of the Daya Bay (Δm²_ee) and MINOS (|Δm²₃₂|)
splittings under NO, whose relation involves ±Δm²₂₁ terms whose sign flips
with the ordering.

Method reading — three findings that belong in the sampler section but are
stated here because they decide which number is the physics result:

1. **The converged nested-sampling evidence is biased high by 1.5 (NO) and
   2.1 (IO) nats** although its own stopping criterion is satisfied, its
   posterior sample agrees with all other samplers on every marginal (ESS
   18 000–19 000; P(upper) = 0.61/0.58; W̄₁ = 0.011–0.013), and its quoted
   uncertainty is 0.05. The bias differs between the orderings and flips the
   sign of ln K. Two independent estimators (defensive IS and pooled plain IS)
   agree with each other and exclude the NS value at > 3σ (NO) and > 10σ
   (IO). This is the known failure mode of ellipsoidal (MultiNest-type)
   nested sampling when the bounding ellipsoids clip the likelihood-constrained
   region: the replacement points are drawn from too small a volume, the
   dead-point likelihoods rise faster than the assumed shrinkage, and Z is
   overestimated. The eleven-dimensional target with one uniform direction
   (δ_CP) and one bimodal direction is a plausible trigger; the point for the
   thesis is that "converged" NS is not a reference on a real posterior
   without an independent check.
2. **MoleWhacker's evidence is low by 0.22 (NO) and 0.25 (IO) nats** at
   B = 5·10⁵ (0.13/0.14 at 5·10⁴), with a seed-to-seed spread of 0.01–0.03
   that understates the error by an order of magnitude; ln K is nevertheless
   right (0.45 vs 0.42) because the offset is common to both orderings.
   `72_mw_mixture_check.jl` locates the offset: importance sampling with
   **fresh** i.i.d. draws from each cell's final mixture (6·10⁴ draws,
   ESS 1 600–20 000) gives ln Z = −510.876/−510.872/−510.854 (NO) and
   −511.268/−511.288/−511.268 (IO), i.e. the reference to within 0.01–0.02.
   The mixture is therefore correct; the offset comes from the algorithm's
   pooled-cloud estimator, which weights *all* accumulated samples with the
   *final* mixture density although each batch was drawn from the mixture as
   it stood when its component was added (the later, better-placed components
   are under-represented in the cloud relative to their final weights, so the
   estimate ∫ f·(q_cloud/q_T) falls short of Z). The same bookkeeping shifts
   the pooled-cloud octant probability up by 0.03 (NO) and 0.015 (IO) on
   average (seed by seed −0.01 to +0.06; 0.63 pooled vs 0.60 fresh) — the
   only visible bias of MoleWhacker's marginals in this study.
3. **Plain importance sampling from the prior is unbiased but useless** at
   these budgets (ESS 2–26 in 11 dimensions); its pooled estimate agrees
   with the reference only because 6.5·10⁵ draws were combined.

### 3.4  Nuisance parameters  (`nu_nuisance_NO.pdf`)

* The MINOS NC normalisation is pulled to n_NC = 0.86 ± 0.13 (prior 1 ± 0.2):
  the data prefer ≈ 14 % fewer NC events than the nominal cross section.
* The KamLAND flux scale is pulled up by ≈ 0.5σ and slightly narrowed; the
  energy-scale pull is prior-dominated (posterior sd 0.94 vs prior 0.99).
* The geo-neutrino scale is constrained to ε_geo = 0.02 ± 0.22 by the
  low-energy part of the spectrum (prior U(−0.5, 0.5), sd 0.29).
* n_ντCC is not constrained (posterior = prior).

### 3.5  Correlations  (`nu_corner_NO.pdf`, `nu_corner_IO.pdf`)

MoleWhacker (filled) against the pooled MH chains (contours) at B = 5·10⁵:
the two octant islands in every θ₂₃ panel; the "butterfly" of the Δm²₃₁–θ₂₃
panel (the octant modes sit at slightly different Δm²₃₁ because the
sub-leading terms of the ν_μ survival probability differ between them); the
θ₁₃–Δm²₃₁ correlation of the Daya Bay spectrum; the Δm²₂₁–θ₁₂ anticorrelation
of KamLAND; no correlation between the reactor and accelerator sectors beyond
the shared θ₁₃. No method-dependent shift is visible at this resolution.

## 4  Results — the samplers on this posterior

All cells (`tab_nu_samplers.tex`; medians over seeds; cost = counted
likelihood units; W̄₁ = mean 1-d Wasserstein distance to the pooled
top-budget MH chains in units of the prior width, own seed excluded; wall
times on a shared 12-core machine, 3–5 cells running concurrently):

| sampler | B | cost used | wall | ESS | ESS / cost | W̄₁ (NO / IO) | ln Z bias vs reference | stop |
|---|---|---|---|---|---|---|---|---|
| MW | 5·10⁴ | 37–38 k | 5–7 min | 3 172 (NO), 3 835 (IO) | 8·10⁻² – 1·10⁻¹ | 0.005 / 0.005 | −0.13 / −0.14 | T_max (3 seeds) |
| MH, 4 chains | 5·10⁴ | 50 k | ≈ 10 min | 43 (NO), 39 (IO) | 8–9·10⁻⁴ | 0.010 / 0.012 | — | budget (3 seeds) |
| NS, n_live = 3025 | 5·10⁴ | 41–44 k | ≈ 10 min | 5.1 / 5.6 | 1.3·10⁻⁴ | 0.089 / 0.072 | −0.4 ± 0.3 / −0.7 ± 0.9 | call cap (3 seeds) |
| IS | 5·10⁴ | 50 k | ≈ 10 min | 2.0 / 4.0 | 4–8·10⁻⁵ | 0.102 / 0.084 | +0.5 ± 0.9 / +0.4 ± 0.6 | budget (3 seeds) |
| NUTS | 5·10⁴ | — | — | — | — | — | — | infeasible: warm-up ≈ 2·10⁵ units (2 documentation cells) |
| MW | 5·10⁵ | 115–118 k | 13–17 min | 2 232 (NO), 1 958 (IO) | 1.9·10⁻² / 1.7·10⁻² | 0.006 / 0.008 | −0.22 / −0.25 | T_max (3 seeds) |
| MH, 4 chains | 5·10⁵ | 500 k | 1.5–2.7 h | 644 (NO), 403 (IO) | 1.3·10⁻³ / 8·10⁻⁴ | 0.004 / 0.004 | — | budget (3 seeds) |
| NUTS, 1 chain | 5·10⁵ | 450–461 k | 47–89 min | 103 (NO), 49 (IO) | 2.3·10⁻⁴ / 1.1·10⁻⁴ | 0.009 / 0.011 | — | budget (2 seeds) |
| NS, n_live = 3025 | 5·10⁵ | 343–345 k | 0.5–1.7 h | 185 (NO), 76 (IO) | 5.4·10⁻⁴ / 2.2·10⁻⁴ | 0.015 / 0.022 | +1.3 / +1.5 | call cap (2 seeds) |
| IS | 5·10⁵ | 500 k | 1.8–2.8 h | 10 (NO), 26 (IO) | 2–5·10⁻⁵ | 0.042 / 0.023 | +0.25 / −0.12 | budget (1 seed) |
| NS, n_live = 3025, to Δln Z < 0.5 | — | 844–850 k | 2.4 h | 18 911 / 18 398 | 2.2·10⁻² | 0.011 / 0.013 | **+1.47 / +2.11** | Δln Z (1 seed) |

Observations:

* **Correctness.** Every sampler with ESS ≳ 50 reproduces the same physics:
  medians of θ₁₃, Δm²₃₂, Δm²₂₁, θ₁₂ agree across MW, MH, NUTS, NS (5·10⁵ and
  converged) to within a tenth of a posterior standard deviation, and the
  W̄₁ distances to the MH pool are 0.004–0.015 prior widths (for scale: the
  posterior sd of θ₁₃ is 0.035 prior widths). The exact marginals come back
  right: δ_CP flat (MW mean 2.95, sd 1.83 vs 3.14, 1.81) and n_ντCC equal to
  its prior (0.99 ± 0.19 vs 1.00 ± 0.195).
* **Efficiency.** At 5·10⁴, MoleWhacker is the only method that yields a
  usable posterior: ESS 3 000–4 000 from ≈ 38 000 evaluations (η ≈ 0.1),
  against 40 for MH, 5 for NS, 2–4 for IS and no NUTS at all. At 5·10⁵ the
  ordering is MW (η = 1.7–1.9·10⁻²) > MH (0.8–1.3·10⁻³) > NS (2–5·10⁻⁴) >
  NUTS (1–2·10⁻⁴) > IS (2–5·10⁻⁵), i.e. a factor 15–20 over MH and 70–170
  over NUTS. NS run to its own convergence reaches η = 2.2·10⁻² — the same
  efficiency as MoleWhacker — after 8.5·10⁵ evaluations, but with a biased
  evidence (§3.3); at the protocol budgets its n_live = 25 d² makes it stop
  long before convergence.
* **The octant as a mixing test** (`chains.csv`, `nu_octant_*.pdf`). At 5·10⁴
  the four MH chains have not equilibrated between the octants: per-chain
  upper-octant fractions spread from 0.40 to 0.79 and R̂(θ₂₃) = 1.05–1.16. At
  5·10⁵ they have: fractions 0.54–0.67 (NO) and 0.54–0.65 (IO), R̂(θ₂₃) =
  1.004–1.013, pooled P(upper) = 0.608 (NO) / 0.606 (IO). The single NUTS
   chains give 0.56–0.69 with 700–950 draws (R̂ up to 1.08). MoleWhacker
  represents the two modes as separate components in every seed at both
   budgets; its pooled-cloud P(upper) is 0.63/0.62 (NO/IO, seeds 0.61–0.65),
   fresh draws from the same mixtures give 0.60/0.61 (seeds 0.59–0.62;
   §3.3, finding 2); the reference value is 0.60–0.61/0.62. The physics
   statement is unaffected (odds ≈ 1.5 : 1 for the upper octant), the method
   statement is: MW's pooled-cloud weighting is the largest bias in this
   study, up to 0.06 in a mode probability for a single seed.
* **Evidence** — see §3.3: MW low by 0.2 nats with a common offset for both
  orderings (ln K right), NS high by 1.5–2.1 nats and inconsistent between
  orderings (ln K sign wrong), IS unbiased but with ESS 10.
* **Cost structure of MW at the top budget.** MW stops on T_max = 20 with
  only 23 % of B = 5·10⁵ spent, so its ESS at the top budget is limited by the
  protocol's iteration cap, not by the budget. The seed phase (62 seeds,
  7 431 gradient calls × 11 = 82 k) is 82 % of its cost; the 20 refinement
  iterations cost ≈ 1.1 k each. The final mixture (169 components NO, 174 IO)
  is a good proposal: fresh i.i.d. draws from it have an importance-sampling
  efficiency of 3–34 % (Pareto-k̂ of the pooled-cloud weights −0.4 to 0.3),
  so every further 1 000 likelihood calls would buy 30–340 effective samples;
  the protocol's final cloud (3–4.6 k samples, ESS 1 250–2 280) is simply what
  T_max = 20 leaves.
* **NUTS** cannot be run below ≈ 2·10⁵ units (warm-up 1.96·10⁵ = 43 % of the
  5·10⁵ budget), which on this 6 ms likelihood means ≈ 1.5 h before the first
  usable sample; only one of the four requested chains is affordable, and it
  under- or over-weights an octant by up to 0.08 at ESS 50–120.

## 5  Limitations and outlook

* Data: KamLAND spectrum digitised from figures; MINOS/MINOS+ 2017 beam-only
  two-detector release (no atmospheric sample, no antineutrino-mode data);
  Daya Bay 3158-day supplemental data, re-fitted from the far-hall spectrum
  anchored on the collaboration's best-fit prediction. Newtrinos' simplified
  systematic models (3 + 2 pulls, one of them inert).
* Estimators: the evidence reference is a purpose-built defensive importance
  sampler that needs an MCMC sample first; it is a check, not a competitor
  under the budget protocol. MoleWhacker's pooled-cloud estimator carries a
  small systematic offset (§3.3) that a deterministic-mixture weighting (or a
  final fresh draw from the mixture) would remove — a recommendation for the
  algorithm, deliberately not applied here so that the thesis algorithm is
  tested unchanged.
* Physics model: vacuum three-flavour propagation (Newtrinos `Basic` /
  `Vacuum`); matter effects are irrelevant at these baselines and energies
  for reactor data and small for MINOS, but they are what would give ordering
  sensitivity in an extended fit.
* Priors: uniform in the mixing angles (not in sin²), θ₂₃ box restricted to
  sin²θ₂₃ ∈ [0.25, 0.75]; P(upper octant) is prior-dependent at the ±0.02
  level.
* Outlook: Newtrinos ships DeepCore, ORCA, JUNO/TAO and COHERENT modules;
  adding the atmospheric samples would turn the NO/IO Bayes factor into a
  physics result rather than a null test and would raise the dimension to
  ~20 with substantially more expensive likelihoods, where the per-evaluation
  cost accounting of this chapter matters most.

## Appendix material (chapter or appendix)

* Prior/parameter table (§2.1), sampler settings table (§2.3).
* MW iteration log figure for one top-budget cell per ordering
  (`nu_mw_iter_NO.pdf`): ESS/N_L climbs from 10⁻³ to 2·10⁻² over 20 iterations;
  components grow by 8 per iteration to 170.
* NUTS 5·10⁴ documentation cells (warm-up does not finish).
* Evidence arbitration table (`evidence_check.csv`, `mw_mixture_check.csv`,
  `is_diagnostics.csv`): defensive-IS reference with two bandwidths, pooled
  plain IS, fresh-draw evidence from every MW mixture, Pareto-k̂ of every
  weighted sample.

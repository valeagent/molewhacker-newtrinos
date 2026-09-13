# Neutrino oscillations, the three experiments, and what our fit actually does

*A study text written for us, not for the thesis. Nothing in here touches the thesis; it is the
background we need before we decide what goes into it. Study edition, 11 Sep 2026, late
evening. Numbers marked **[ours]** come from `neutrino/out/tables/*.csv` and change as cells
finish; numbers with a reference in brackets are published values.*

---

## How to use this document

**What it is.** A self-contained course, from "what is a neutrino" to "what exactly do the
figures in `neutrino/out/figs/` show", written for a reader who knows Bayesian statistics and
Monte Carlo well (you wrote a thesis on a sampler) and nothing about particle physics.

**Reading order.** Part 0 is a one-page map of the whole undertaking; read it first and again
at the end. Parts 1 and 2 are the physics and the experiments; they are the part to study
slowly. Part 3 is the statistical model, mostly familiar ground with new vocabulary. Part 4 is
the design of *our* computational experiment, its constraints, and what else could be done —
this is what we will discuss when you come back. Part 5 explains every figure, Part 6 is a
glossary. Each part ends with **Check yourself** questions; the answers are in Appendix B. If
you can answer them without looking, you know enough to co-write the chapter.

**Two meanings of "experiment".** Daya Bay, KamLAND and MINOS are *physics experiments*
(detectors, data). Our study — running five samplers on the posterior built from their data
under the thesis protocol — is a *computational experiment* with *cells* as its unit. The text
says "physics experiment" and "our study" whenever confusion is possible.

**Figures for this text** are in `neutrino/out/figs/primer_*.png` (made by
`scripts/60_primer_figures.jl`): analytic oscillation curves and, for each physics experiment,
the actual data against the model prediction at our best fit.

---

## Part 0 — The whole undertaking on one page

Philipp's request, both mails: the thesis must contain physics — a concrete physical problem
to which the algorithm is applied so that *physical results* come out, and a text that is
motivated and structured by that physics rather than by the algorithm.

What we are doing about it:

1. **The physical problem.** Three neutrino-oscillation experiments have published the
   energy spectra of the neutrinos they detected. Each spectrum is distorted by oscillations in
   a way that depends on six fundamental parameters of the neutrino sector (three mixing angles,
   one phase, two squared-mass differences). We fit all three data sets *jointly* and infer the
   six parameters, plus five instrumental "nuisance" parameters the experiments need. The
   output — posterior distributions, the octant question, the mass-ordering Bayes factor —
   *is* physics, directly comparable to what the collaborations and the global fits publish.
2. **The tool.** The posterior is an 11-dimensional density that costs ≈6 ms per evaluation
   (Philipp's Newtrinos.jl computes it). It is genuinely bimodal in one direction, flat in
   another, and well constrained in the rest. MoleWhacker — the unchanged thesis algorithm —
   is used to sample it and to compute its evidence.
3. **The validation.** The same posterior is sampled by the four baseline samplers of the
   thesis (MH, NUTS, nested sampling, importance sampling) under the same budget protocol, and
   checked against a frequentist profile likelihood and a converged nested-sampling reference.
   This turns the thesis benchmark from synthetic targets into a real-data case, and it shows
   which sampler gives correct physics for how many likelihood evaluations.

Data flow: published spectra → Newtrinos likelihoods (one per experiment) → product × priors
= posterior on 11 parameters → affine map onto the thesis harness cube → samplers →
(a) physics tables/figures, (b) sampler comparison tables/figures.

---

## Part 1 — Neutrino oscillations from zero

### 1.1 Neutrinos in the Standard Model

Matter is built from fermions: six quarks and six **leptons**. The leptons come in three
generations, each a charged particle and its neutral partner:

| generation | charged lepton | neutrino |
|---|---|---|
| 1 | electron $e^-$ (0.511 MeV) | electron neutrino $\nu_e$ |
| 2 | muon $\mu^-$ (106 MeV) | muon neutrino $\nu_\mu$ |
| 3 | tau $\tau^-$ (1777 MeV) | tau neutrino $\nu_\tau$ |

Every particle has an antiparticle ($e^+$, $\bar\nu_e$, …). Neutrinos have no electric charge
and no colour charge, so they feel neither electromagnetism nor the strong force — only the
**weak interaction**, carried by the $W^\pm$ and $Z^0$ bosons, and gravity. A weak interaction
that exchanges a $W$ ("charged current", CC) turns a neutrino into its charged partner:
$\nu_\mu + n\to\mu^-+p$. That is what defines flavour operationally: a neutrino that makes a
muon *is* a muon neutrino. An interaction that exchanges a $Z$ ("neutral current", NC) leaves
the neutrino a neutrino and is identical for all three flavours.

Weak cross sections are tiny. At the few-MeV energies of reactor antineutrinos,
$\sigma\approx10^{-42}\,\mathrm{cm^2}$ per proton, which gives a mean free path in lead of about a
light-year; at GeV energies $\sigma\approx0.7\times10^{-38}\,\mathrm{cm^2}\times E[\mathrm{GeV}]$ per
nucleon. Hence the numbers that recur throughout: reactors emit $\approx2\times10^{20}$
antineutrinos per second per gigawatt of thermal power, and a 20-tonne detector two kilometres
away records about seventy of them per day.

In the original Standard Model neutrinos are exactly massless. Oscillations prove they are
not — the only laboratory evidence so far of physics beyond that model, and the reason the field
has produced four Nobel prizes.

### 1.2 A short history (so the names in the papers mean something)

* **1930** Pauli postulates a neutral, nearly massless particle to save energy conservation in
  $\beta$ decay; **1956** Reines and Cowan detect reactor $\bar\nu_e$ via inverse beta decay —
  the very reaction Daya Bay and KamLAND use.
* **1968–1994** Davis's Homestake experiment sees only a third of the solar $\nu_e$ predicted:
  the *solar neutrino problem*. Pontecorvo (1957, 1967) had already proposed that neutrinos
  might change flavour in flight; Wolfenstein (1978), Mikheyev and Smirnov (1985) work out how
  matter modifies this (MSW effect).
* **1998** Super-Kamiokande shows that atmospheric $\nu_\mu$ disappear with the
  zenith-angle (= distance) dependence expected from oscillations: the discovery.
* **2001–2002** SNO measures the *total* solar neutrino flux via NC and finds it agrees with
  the solar model: the missing $\nu_e$ became $\nu_\mu,\nu_\tau$. **2002** KamLAND sees reactor
  $\bar\nu_e$ disappear at 180 km with exactly the solar parameters.
* **2006** MINOS confirms the atmospheric splitting with an accelerator beam.
* **2012** Daya Bay (with RENO and Double Chooz) measures the last mixing angle $\theta_{13}$,
  which turned out large enough to make CP-violation and mass-ordering searches feasible.
* **2015** Nobel Prize to Kajita (Super-K) and McDonald (SNO) "for the discovery of neutrino
  oscillations, which shows that neutrinos have mass".
* **Today** the open questions are the mass ordering, the $\theta_{23}$ octant and the CP
  phase; JUNO (reactor, 53 km), DUNE and Hyper-Kamiokande (beams) are being built for them.

### 1.3 Two sets of labels: flavour states and mass states

The central fact is that the flavour states are **not** the states with a definite mass. There
are three mass states $\nu_1,\nu_2,\nu_3$ with masses $m_1,m_2,m_3$, and each flavour state is a
fixed quantum superposition of them:

$$
|\nu_\alpha\rangle=\sum_{i=1}^{3}U^{*}_{\alpha i}\,|\nu_i\rangle,\qquad \alpha\in\{e,\mu,\tau\},
$$

with $U$ the $3\times3$ unitary **PMNS matrix** (Pontecorvo–Maki–Nakagawa–Sakata). In the
standard parametrisation, with $s_{ij}=\sin\theta_{ij}$, $c_{ij}=\cos\theta_{ij}$,

$$
U=\begin{pmatrix}
c_{12}c_{13} & s_{12}c_{13} & s_{13}e^{-i\delta}\\
-s_{12}c_{23}-c_{12}s_{23}s_{13}e^{i\delta} & c_{12}c_{23}-s_{12}s_{23}s_{13}e^{i\delta} & s_{23}c_{13}\\
s_{12}s_{23}-c_{12}c_{23}s_{13}e^{i\delta} & -c_{12}s_{23}-s_{12}c_{23}s_{13}e^{i\delta} & c_{23}c_{13}
\end{pmatrix}.
$$

$|U_{\alpha i}|^2$ is the fraction of mass state $i$ in flavour $\alpha$. The useful ones:
$|U_{e3}|^2=s_{13}^2$ (tiny: $\nu_3$ is almost free of $\nu_e$), $|U_{\mu3}|^2=s_{23}^2c_{13}^2$
and $|U_{\tau3}|^2=c_{23}^2c_{13}^2$ ($\nu_3$ is roughly half $\nu_\mu$, half $\nu_\tau$),
$|U_{e1}|^2=c_{12}^2c_{13}^2\approx0.68$, $|U_{e2}|^2=s_{12}^2c_{13}^2\approx0.30$.

Analogy: polarised light. "Horizontal/vertical" is one basis, "$\pm45^\circ$" another; a
horizontal photon is a 50/50 superposition of the diagonal states. A $\nu_\mu$ is a superposition
of $\nu_1,\nu_2,\nu_3$ with weights $|U_{\mu i}|^2$.

### 1.4 Deriving the oscillation formula (two flavours, five lines)

Take two flavours with one angle: $|\nu_\alpha\rangle=\cos\theta|\nu_1\rangle+\sin\theta|\nu_2\rangle$,
$|\nu_\beta\rangle=-\sin\theta|\nu_1\rangle+\cos\theta|\nu_2\rangle$. A mass state of energy $E$
travelling a distance $L$ acquires the phase $e^{-i\,m_i^2L/2E}$ (ultra-relativistic: $p\approx
E-m^2/2E$). Start with $\nu_\alpha$:

$$
|\nu(L)\rangle=\cos\theta\,e^{-i m_1^2L/2E}|\nu_1\rangle+\sin\theta\,e^{-i m_2^2L/2E}|\nu_2\rangle .
$$

Project onto $\nu_\beta$: the amplitude is $\sin\theta\cos\theta\,(e^{-i m_2^2L/2E}-e^{-i m_1^2L/2E})$,
and its modulus squared is

$$
P(\nu_\alpha\to\nu_\beta)=\sin^2 2\theta\;\sin^2\!\Bigl(\frac{\Delta m^2 L}{4E}\Bigr),\qquad
\Delta m^2=m_2^2-m_1^2 .
$$

Only the *difference* of the squared masses enters; if $m_1=m_2$ nothing happens. That is why
"oscillations exist" is the same statement as "neutrinos have (different) masses", and why
oscillation experiments measure $\Delta m^2$ but never the masses themselves.

Units: the argument is dimensionless once $\hbar$ and $c$ are restored,
$\Delta m^2c^4L/(4\hbar cE)$. With $\hbar c=197.3\times10^{-9}\ \mathrm{eV\,m}$, inserting
$\Delta m^2=1\ \mathrm{eV^2}$, $L=10^3$ m and $E=10^9$ eV gives
$10^{3}/(4\times197.3\times10^{-9}\times10^{9})=1.267$, so

$$
P(\nu_\alpha\to\nu_\beta)=\sin^2 2\theta\;\sin^2\!\Bigl(1.267\,\frac{\Delta m^2[\mathrm{eV^2}]\;L[\mathrm{km}]}{E[\mathrm{GeV}]}\Bigr),
\qquad P(\nu_\alpha\to\nu_\alpha)=1-P(\nu_\alpha\to\nu_\beta),
$$

and the same number works with $L$ in metres and $E$ in MeV.

### 1.5 Reading the formula

Two independent knobs:

* **amplitude** $\sin^2 2\theta$: the depth of the disappearance dip. $\theta=45^\circ$ is
  "maximal mixing" — the dip reaches zero survival;
* **wavelength**, set by $\Delta m^2$: survival is minimal when $1.267\,\Delta m^2L/E=\pi/2$,
  the *first oscillation maximum*, at $L/E=\pi/(2\times1.267\,\Delta m^2)$.

Consequences that drive all experiment design:

1. You see oscillations only if $L/E$ is tuned to $\Delta m^2$. Too short a baseline: nothing has
   happened yet. Too long (or too coarse an energy resolution): the wiggles average to a constant
   deficit of $\tfrac12\sin^2 2\theta$ and you lose the information on $\Delta m^2$.
2. The *position* of the dip in energy measures $\Delta m^2$; its *depth* measures the mixing
   angle. Every disappearance experiment extracts exactly these two pieces of information.

Nature has two splittings, and the three experiments sit at the corresponding $L/E$
(figure `primer_survival_LE.png`):

| splitting | value | first maximum at $L/E$ | 4 MeV reactor $\bar\nu_e$ | 3 GeV beam $\nu_\mu$ |
|---|---|---|---|---|
| "atmospheric" $\lvert\Delta m^2_{31}\rvert\approx2.5\times10^{-3}\,\mathrm{eV^2}$ | | $\approx500$ km/GeV | $L\approx2$ km → **Daya Bay** far hall (1.5–1.9 km) | $L\approx1500$ km; **MINOS** at 735 km sees the dip at $E\approx1.5$ GeV |
| "solar" $\Delta m^2_{21}\approx7.5\times10^{-5}\,\mathrm{eV^2}$ | | $\approx16{,}500$ km/GeV | $L\approx66$ km; **KamLAND** at ~180 km is beyond the first dip and sees the wiggles across its spectrum | invisible at 735 km (phase 0.04 rad) |

Check the KamLAND row yourself: at $L=180$ km, $E=4$ MeV the phase is
$1.267\times7.5\times10^{-5}\times180/0.004=4.3$ rad, so $\sin^2=0.83$ and, with
$\sin^2 2\theta_{12}=0.85$, survival is $\approx0.30$ at that energy; averaged over the reactor
spectrum and the reactor distances KamLAND sees about 0.6 — a 40 % deficit, enormous compared
to Daya Bay's 6 %.

### 1.6 Three flavours: parameters, values, conventions

With three mass states the PMNS matrix is the product of three rotations, one carrying a phase:
$U=R_{23}(\theta_{23})\,U_{13}(\theta_{13},\delta_{CP})\,R_{12}(\theta_{12})$. Together with the
two independent squared-mass differences this gives the six oscillation parameters:

| parameter | meaning | measured mainly by | value [NuFIT 6.0, 2024, NO] |
|---|---|---|---|
| $\theta_{12}$ ("solar angle") | how $\nu_e$ is spread over $\nu_1$ and $\nu_2$ | solar $\nu$, **KamLAND** | $\sin^2\theta_{12}=0.308$ ($33.7^\circ$) |
| $\theta_{13}$ ("reactor angle") | the small $\nu_e$ content of $\nu_3$ | **Daya Bay**, RENO, Double Chooz | $\sin^2\theta_{13}=0.0222$ ($8.6^\circ$) |
| $\theta_{23}$ ("atmospheric angle") | how $\nu_3$ is shared between $\nu_\mu$ and $\nu_\tau$ | atmospheric $\nu$, **MINOS**, T2K, NOvA | $\sin^2\theta_{23}=0.470$ ($43^\circ$); IO 0.550 |
| $\delta_{CP}$ | phase; makes $\nu$ and $\bar\nu$ oscillate differently | $\nu_\mu\to\nu_e$ appearance (T2K, NOvA) | poorly known, $\sim180^\circ$–$270^\circ$ preferred |
| $\Delta m^2_{21}$ | solar splitting; positive (sign fixed by matter effects in the Sun) | **KamLAND** | $7.49\times10^{-5}\,\mathrm{eV^2}$ |
| $\Delta m^2_{31}$ | atmospheric splitting; **sign unknown** | **Daya Bay** ($\bar\nu_e$), **MINOS** ($\nu_\mu$) | $+2.513\times10^{-3}\,\mathrm{eV^2}$ (NO) |

Conventions you will meet in the papers, all present in our tables:

* $\Delta m^2_{32}=\Delta m^2_{31}-\Delta m^2_{21}$ is not independent. Our fit's fundamental
  parameter is $\Delta m^2_{31}$; $\Delta m^2_{32}$ is derived per sample.
* Daya Bay quotes an *effective* splitting $\Delta m^2_{ee}\approx c_{12}^2\Delta m^2_{31}+s_{12}^2\Delta m^2_{32}$
  because a $\bar\nu_e$ experiment at 2 km sees a weighted mixture of the two atmospheric
  frequencies, and then converts to $\Delta m^2_{32}$ assuming an ordering.
* Reactor collaborations quote $\sin^2 2\theta_{13}$, global fits $\sin^2\theta_{13}$, KamLAND
  $\tan^2\theta_{12}$; the octant literature uses $\sin^2\theta_{23}$. Angles in our code are in
  radians. Conversions: $\sin^2 2\theta=4\sin^2\theta(1-\sin^2\theta)$,
  $\sin^2\theta=\tan^2\theta/(1+\tan^2\theta)$.
* **NO / IO**: normal ordering $m_1<m_2<m_3$ ($\Delta m^2_{31}>0$), inverted $m_3<m_1<m_2$
  ($\Delta m^2_{31}<0$). In both, $\Delta m^2_{21}>0$.

The general vacuum survival probability follows from the same derivation with three states:

$$
P(\nu_\alpha\to\nu_\alpha)=1-4\sum_{i<j}|U_{\alpha i}|^2|U_{\alpha j}|^2\sin^2\Delta_{ij},\qquad
\Delta_{ij}\equiv1.267\,\frac{\Delta m^2_{ij}L}{E}.
$$

Two facts follow immediately and matter for us: **no survival probability depends on
$\delta_{CP}$** (only moduli of $U$ appear), and **the sign of $\Delta m^2$ enters only through
$\sin^2\Delta_{ij}$**, which is even — so a single splitting's sign is invisible and only the
interplay of two splittings can reveal the ordering.

### 1.7 The three survival probabilities we actually use

(figures `primer_reactor.png`, `primer_minos_octant.png`)

* **Reactor $\bar\nu_e$ at 1–2 km (Daya Bay):**
  $P=1-\sin^2 2\theta_{13}\bigl(c_{12}^2\sin^2\Delta_{31}+s_{12}^2\sin^2\Delta_{32}\bigr)-c_{13}^4\sin^2 2\theta_{12}\sin^2\Delta_{21}$.
  At 1.65 km the $\Delta_{21}$ term is $\lesssim10^{-3}$, so Daya Bay measures
  **$\sin^2 2\theta_{13}$** (depth, 8.5 % at the dip) and **$\Delta m^2_{ee}$** (position; the
  dip sits at $E_\nu\approx3.3$ MeV, i.e. 2.5 MeV prompt energy).
* **Reactor $\bar\nu_e$ at ~180 km (KamLAND):** the $\Delta_{31},\Delta_{32}$ wiggles are far too
  fast to resolve (≈70 periods across the spectrum at a single baseline — the fine ripple in
  `primer_reactor.png` — smeared out further by the spread of reactor distances and the 6.5 %
  energy resolution) and average to ½:
  $P\approx c_{13}^4\bigl(1-\sin^2 2\theta_{12}\sin^2\Delta_{21}\bigr)+s_{13}^4$.
  KamLAND measures **$\Delta m^2_{21}$** (wiggle period in $L/E$) and **$\theta_{12}$** (depth);
  $\theta_{13}$ enters only as an overall factor $c_{13}^4\approx0.956$, degenerate with the flux
  normalisation, hence KamLAND's near-zero $\theta_{13}$ sensitivity.
* **Beam $\nu_\mu$ at 735 km (MINOS):** with $\Delta_{21}$ negligible and $\Delta_{31}\approx\Delta_{32}$,
  $P\approx1-4\,|U_{\mu3}|^2\bigl(1-|U_{\mu3}|^2\bigr)\sin^2\Delta_{32}$, $|U_{\mu3}|^2=s_{23}^2c_{13}^2$.
  MINOS measures **$\lvert\Delta m^2_{32}\rvert$** (dip at 1.5 GeV) and the amplitude, i.e.
  **$\sin^2 2\theta_{23}$** to leading order.

### 1.8 The three open questions, the degeneracies, and what breaks them

**Mass ordering.** Is $\nu_3$ the heaviest state (NO) or the lightest (IO)? From 1.6, a lone
$\sin^2\Delta$ is blind to the sign. The ordering shows up only (a) in the interference between
the $\Delta_{31}$ and $\Delta_{32}$ terms of the reactor formula — a few-per-mille distortion of
the spectrum's fine structure, which needs a 50-km baseline and 3 % energy resolution (JUNO);
(b) through matter effects over thousands of kilometres (atmospheric neutrinos, DUNE);
(c) in the *combination* of experiments that measure different effective splittings: Daya
Bay's $\Delta m^2_{ee}$ and MINOS's $\lvert\Delta m^2_{32}\rvert$ are related by
$\pm$ a fraction of $\Delta m^2_{21}$ whose sign flips with the ordering, so the two orderings
predict slightly different relations between the two measured numbers. **Expectation for our
fit: the two orderings describe the data about equally well; a Bayes factor near 1 with, at
most, a weak preference from mechanism (c).**

**The $\theta_{23}$ octant.** The MINOS amplitude $4x(1-x)$, $x=s_{23}^2c_{13}^2$, is symmetric
under $x\to1-x$. A measured depth is therefore compatible with two values of
$\sin^2\theta_{23}$ mirrored about $x=\tfrac12$, i.e. about
$\sin^2\theta_{23}=1/(2c_{13}^2)=0.511$: a *lower-octant* solution ($\theta_{23}<45^\circ$) and an
*upper-octant* one. Disappearance data **cannot** break this; the appearance probability
$P(\nu_\mu\to\nu_e)\propto s_{23}^2\sin^2 2\theta_{13}$ is *not* symmetric and can (T2K, NOvA,
atmospheric data with matter effects). **Expectation: a genuinely bimodal posterior in
$\theta_{23}$**, modes at $\sin^2\theta_{23}\approx0.39$ and $0.63$ (sum $=2\times0.511$). This is
the feature that makes the posterior an interesting sampling target, and it is real physics,
not a modelling artefact.

**CP violation ($\delta_{CP}$).** It changes $P(\nu_\mu\to\nu_e)$ against
$P(\bar\nu_\mu\to\bar\nu_e)$ and drops out of every survival probability. None of our three
experiments is an appearance experiment. **Expectation: the $\delta_{CP}$ posterior equals its
prior, flat on $[0,2\pi)$.** Any structure a sampler shows there is a sampler artefact — a free
built-in diagnostic.

### 1.9 Matter effects, with numbers

Travelling through matter, $\nu_e$ (only they) scatter coherently on electrons via $W$
exchange, which adds a potential $V=\sqrt2\,G_FN_e\approx1.0\times10^{-13}\,\mathrm{eV}$ in rock
($\rho=2.7\ \mathrm{g/cm^3}$), with opposite sign for antineutrinos. Compare with the vacuum term
$\Delta m^2/2E$: for KamLAND ($\Delta m^2_{21}$, 4 MeV) that is $9\times10^{-12}$ eV, so
$V$ is a 1 % correction; for MINOS ($\Delta m^2_{31}$, 3 GeV) it is $4\times10^{-13}$ eV, so $V$
is 25 % of it — large, but it acts on the $\nu_e$ component, and the $\nu_\mu$ survival feels it
only through $s_{13}^2\approx0.02$, i.e. at the half-per-cent level. In the Sun, where
$N_e$ is a thousand times larger, the effect is total (MSW resonance) and fixed the sign of
$\Delta m^2_{21}$. Newtrinos evaluates our likelihood with **vacuum** three-flavour propagation
(`OscillationConfig(flavour=ThreeFlavour(ordering), propagation=Basic(), interaction=Vacuum())`);
the collaborations include the Earth matter term, so this is a stated approximation of our
model, below the statistical precision of these data but not zero. It is also what makes an
evaluation cost 6 ms rather than seconds.

### 1.10 What oscillation experiments cannot tell us

Only squared-mass *differences*. The absolute scale comes from elsewhere: tritium $\beta$-decay
endpoint (KATRIN: $m_\beta<0.45$ eV) and cosmology ($\sum m_\nu\lesssim0.12$ eV), while
oscillations imply $\sum m_\nu\ge0.06$ eV (NO) or $\ge0.10$ eV (IO). Whether neutrinos are their
own antiparticles (Majorana) is likewise invisible to oscillations. Our fit therefore says
nothing about masses, and everything about mixing and splittings.

**Check yourself (Part 1).**
1. Why does $P(\nu_\alpha\to\nu_\beta)$ vanish if all three masses are equal?
2. A reactor $\bar\nu_e$ of 4 MeV: at what distance is its survival probability minimal for
   $\Delta m^2\approx2.5\times10^{-3}$ eV²? And for $7.5\times10^{-5}$?
3. Why can a $\nu_\mu$ disappearance experiment not tell $\sin^2\theta_{23}=0.39$ from 0.63, and
   which single number from Daya Bay fixes where the mirror sits?
4. Which of our eleven parameters must come out exactly equal to its prior, and why?
5. Why does KamLAND see a 40 % deficit but Daya Bay only 6 %?

---

## Part 2 — The three physics experiments

### 2.1 Reactor antineutrinos and inverse beta decay

A fission reactor is the most intense man-made neutrino source: the fission fragments of
$^{235}$U, $^{238}$U, $^{239}$Pu, $^{241}$Pu are neutron-rich and $\beta^-$-decay, about six
times per fission, emitting $\bar\nu_e$ of 0–10 MeV (mean ≈ 2 MeV; only those above 1.8 MeV are
detectable). A 2.9 GW core gives $\approx6\times10^{20}\,\bar\nu_e/\mathrm{s}$.

The detector is a tank of **liquid scintillator** — an organic liquid that emits a flash of
light when a charged particle deposits energy — surrounded by photomultiplier tubes. The
reaction is **inverse beta decay** (IBD),

$$
\bar\nu_e+p\to e^{+}+n\qquad(E_\nu>1.806\ \mathrm{MeV}),
$$

which produces a **delayed coincidence**: a *prompt* flash from the positron (kinetic energy
plus its two 0.511 MeV annihilation photons, so $E_{\rm prompt}\approx E_\nu-0.78$ MeV — the
prompt-energy histogram *is* the antineutrino spectrum shifted by 0.78 MeV) and, tens to
hundreds of microseconds later, a *delayed* flash when the neutron thermalises and is captured
— on gadolinium (8 MeV of $\gamma$s after ≈30 µs; Daya Bay) or on hydrogen (a 2.2 MeV $\gamma$
after ≈200 µs; KamLAND). Requiring both flashes with the right energies in the right time
window suppresses single-flash backgrounds (radioactivity) by many orders of magnitude.

What remains as **background** in both experiments: *accidental* coincidences of two unrelated
flashes; *cosmogenic* $^9$Li/$^8$He produced by cosmic muons in the scintillator, which
$\beta$-decay emitting a neutron and mimic IBD perfectly; *fast neutrons* from muons in the
rock; and, in KamLAND, the $^{13}$C$(\alpha,n)^{16}$O reaction fed by radon daughters. The
collaborations measure these in control samples and subtract them; the released spectra come
with background estimates, which Newtrinos uses as fixed inputs.

### 2.2 Daya Bay (Guangdong, China) — the $\theta_{13}$ machine

**Layout.** Six pressurised-water reactor cores in three pairs (Daya Bay, Ling Ao, Ling Ao II),
2.9 GW thermal each, 17.4 GW in total. Eight identical **antineutrino detectors** (ADs), each a
three-zone cylinder: 20 t of gadolinium-loaded scintillator in a 3 m acrylic vessel, surrounded
by 22 t of undoped scintillator ("gamma catcher") and mineral oil, viewed by 192 PMTs; each AD
sits in a water pool that shields radioactivity and tags cosmic muons. Three underground
**experimental halls**: EH1 (2 ADs, ≈360 m from the Daya Bay pair), EH2 (2 ADs, ≈500 m from the
Ling Ao pairs) and the far hall **EH3 (4 ADs, 1.5–1.9 km from all six cores)**, placed near the
first oscillation maximum for 3–4 MeV. Rates: several hundred IBD per detector-day near,
≈70 far.

**The measurement.** The near halls measure the unoscillated flux and spectrum from the same
cores; the far hall sees ≈6 % fewer events and a distorted spectrum. The far/near *ratio*
cancels the reactor-flux and detection uncertainties that would otherwise dominate (the
"identical detectors" design keeps the uncorrelated per-detector uncertainty below 0.2 %),
which is why $\theta_{13}$ went from unknown to the best-measured mixing angle within a few
years. The dataset used here is the final one: 3158 days (Dec 2011–Dec 2020) in three
periods (6, 8 and 7 detectors operating), ≈5.5 million IBD candidates
[Daya Bay, PRL 130, 161802 (2023), arXiv:2211.14988].

**Published result.** $\sin^2 2\theta_{13}=0.0851\pm0.0024$ (i.e. $\sin^2\theta_{13}=0.0217$),
$\Delta m^2_{32}=(2.466\pm0.060)\times10^{-3}\,\mathrm{eV^2}$ (NO) or $(-2.571\pm0.060)\times10^{-3}$ (IO).

**What Newtrinos does with it** (`experiments/daya_bay/daya_bay_3158days/dayabay.jl`,
figure `primer_data_dayabay.png`). Uses the collaboration's *supplementary data release*: the
far-hall (EH3) prompt-energy spectrum in **26 bins from 0.7 to 12 MeV** for each period,
background spectra, the collaboration's best-fit prediction, and the 26×26 correlation matrix of
systematic uncertainties (Fig. 29 of arXiv:1607.05378). The trick that makes a re-fit possible
without the full near-hall machinery: divide the released best-fit prediction by the
oscillation probability at the collaboration's best-fit parameters to recover an *unoscillated*
far-hall prediction, then, for any new parameter point, multiply by the oscillation probability
averaged over the 24 core–detector baselines ($1/L^2$-weighted) and summed over the three
periods. The likelihood is a **26-dimensional Gaussian** with covariance = systematic part
(relative uncertainties × correlation matrix, scaled to the far hall) + Poisson diagonal.
**No free nuisance parameters**: the near-hall information and the detector systematics are
already folded into the released prediction and covariance.

Implications to keep in mind: the module is a *far-hall-only re-fit anchored on the
collaboration's prediction*. It reproduces the published $\theta_{13}$–$\Delta m^2$ contour
(the module's own test plot) but it inherits the collaboration's assumptions about $\theta_{12}$
and $\Delta m^2_{21}$ in the anchoring step, and its covariance is the released one. Parameters
it constrains in our fit: $\theta_{13}$ (strongly), $\Delta m^2_{31}$ (strongly).

### 2.3 KamLAND (Kamioka mine, Japan) — the $\Delta m^2_{21}$ machine

**Layout.** One kilotonne of ultra-pure liquid scintillator (dodecane + pseudocumene + PPO) in a
13 m nylon balloon inside an 18 m stainless-steel sphere carrying ≈1900 PMTs, in the old
Kamiokande cavern under 1000 m of rock (2700 m water-equivalent). No dedicated source: KamLAND
sees the $\bar\nu_e$ of **all Japanese commercial reactors**, flux-weighted mean distance ≈180 km
(Newtrinos uses 16 reactor sites with 57 cores at 86–829 km, weighted by cores$/L^2$). At 180 km
the $\Delta m^2_{21}$ phase is several radians at 3–4 MeV, so the survival probability oscillates
*within* the energy spectrum: the famous KamLAND $L/E$ plot shows about two full periods.

**The measurement.** Neutron capture on hydrogen (2.2 MeV $\gamma$, ≈200 µs). Prompt-energy
spectrum 0.9–8.5 MeV. Below ≈2.6 MeV the sample also contains **geo-neutrinos**, $\bar\nu_e$
from $^{238}$U and $^{232}$Th decays inside the Earth ($^{40}$K is below the IBD threshold);
KamLAND was the first to see them, and their rate is a nuisance in a reactor fit. The dataset
used here is the 2011 publication [KamLAND, PRD 83, 052002 (2011), arXiv:1009.4771] with ≈2100
candidates.

**Published result.** $\Delta m^2_{21}=(7.49\pm0.20)\times10^{-5}\,\mathrm{eV^2}$,
$\tan^2\theta_{12}=0.436^{+0.102}_{-0.081}$ (i.e. $\sin^2\theta_{12}=0.30$),
$\sin^2\theta_{13}=0.032\pm0.037$ (KamLAND alone: essentially no sensitivity, as 1.7 predicts).

**What Newtrinos does with it** (`experiments/kamland/kamland_7years/kamland.jl`, figure
`primer_data_kamland.png`). **The data are digitised from the figures of the paper**, not taken
from an official release: the observed counts in 17 bins of 0.42 MeV (rounded to integers), the
no-oscillation prediction, the best-fit background and the geo-neutrino spectrum were read off
Fig. 1 of arXiv:1009.4771. "Digitised" means someone placed a cursor on the printed histogram —
bin heights carry reading errors of a few counts, the background is a *best-fit curve*, not a
measurement, and the reactor flux weights are approximate. The forward model computes the
survival probability on a 10× finer energy grid, averages over the 16 reactor sites, smears
with the energy resolution $6.5\,\%/\sqrt{E}$, averages back into the 17 bins and forms

$$
N_i^{\rm exp}=N_i^{\rm no\,osc}\,\bar P_i\,(1+0.041\,s_{\rm flux})+N_i^{\rm bkg}+s_{\rm geo}\,N_i^{\rm geo},
$$

with the neutrino energy scaled by $(1+0.019\,s_E)$. Likelihood: **17 Poisson terms**. **Three
nuisance parameters**: `kamland_energy_scale` $s_E\sim\mathcal N(0,1)$ truncated to $[-3,3]$
(1σ = 1.9 % energy scale), `kamland_flux_scale` $s_{\rm flux}$ likewise (1σ = 4.1 % rate),
`kamland_geonu_scale` $s_{\rm geo}\sim U(-0.5,0.5)$ (±50 % on the geo-neutrino rate).

Implications: KamLAND is the *only* source of $\Delta m^2_{21}$ and $\theta_{12}$ in our fit, so
whatever bias the digitisation carries goes straight into those two parameters. Our joint fit
gives $\Delta m^2_{21}=7.75\pm0.23$, 1.2σ above the published value **[ours]**; a KamLAND-only fit
with the same module gives the same number, so the shift is a property of the digitised module,
not of the samplers or of the combination. $\theta_{12}$ agrees with the publication.

### 2.4 MINOS / MINOS+ (Fermilab → Soudan, USA) — the $\theta_{23}$, $\lvert\Delta m^2_{32}\rvert$ machine

**Beam.** NuMI ("Neutrinos at the Main Injector"): 120 GeV protons hit a graphite target;
the pions and kaons produced are focused by two magnetic horns and decay in a 675 m evacuated
tunnel, $\pi^+\to\mu^+\nu_\mu$. The result is a $\nu_\mu$ beam (≈7 % $\bar\nu_\mu$, ≈1 % $\nu_e$)
peaked at ≈3 GeV during MINOS (2005–2012, $10.56\times10^{20}$ protons on target) and at ≈7 GeV
during MINOS+ (2013–2016, $5.80\times10^{20}$ POT). Newtrinos combines both — hence the module
name `minos_sterile_16e20_POT`. Beam timing (10 µs spills) removes cosmic-ray background almost
completely.

**Detectors.** Two functionally identical **magnetised steel–scintillator tracking
calorimeters**: alternating 2.54 cm steel plates and 1 cm plastic scintillator strips, with a
1.3 T toroidal field. The **near detector** (0.98 kt, 1.04 km from the target, on the Fermilab
site) records the beam before oscillation; the **far detector** (5.4 kt, 8 m wide octagonal
planes, 735 km away in the Soudan iron mine, Minnesota, ≈710 m underground) records it after.
The field bends the muon track, giving momentum and charge, so $\nu_\mu$ and $\bar\nu_\mu$ can be
told apart.

**Event classes.** A **CC $\nu_\mu$ event** has a long muon track plus a hadronic shower; its
reconstructed energy (track + shower) is the neutrino energy, and the far/near ratio of the CC
spectrum shows the oscillation dip at ≈1.5 GeV. A **NC event** has only a shower; NC rates are
the same for all three active flavours and therefore *oscillation-independent* in the
three-flavour model (they would drop if a fourth, sterile, neutrino existed — that is what the
2017 data release was made for). Backgrounds: NC events mis-identified as CC (and vice versa),
beam $\nu_e$, and — after oscillation — appeared $\nu_e$ and $\nu_\tau$ in the selected samples;
the release provides response matrices for each.

**Published three-flavour result** [MINOS+, PRL 125, 131802 (2020)]:
$\lvert\Delta m^2_{32}\rvert=2.40^{+0.08}_{-0.09}\times10^{-3}\,\mathrm{eV^2}$,
$\sin^2\theta_{23}=0.43^{+0.20}_{-0.04}$ (NO); IO: $2.45^{+0.07}_{-0.08}$, $0.42^{+0.07}_{-0.03}$.
The huge upper error on $\sin^2\theta_{23}$ *is* the octant degeneracy.

**What Newtrinos does with it** (`experiments/minos/minos_sterile_16e20_POT/minos.jl`, figure
`primer_data_minos.png`). Uses the HDF5 release of the sterile analysis [arXiv:1710.06488]:
observed reconstructed-energy spectra for four samples (far CC, far NC, near CC, near NC),
MINOS and MINOS+ summed; "reco-to-true" matrices that turn a true-$L/E$ oscillation probability
into a predicted reconstructed spectrum for each true component of each sample ($\nu_\mu$ CC,
true NC, beam $\nu_e$, appeared $\nu_e$, appeared $\nu_\tau$); and the fractional covariance
matrices of all systematics for the [far; near] vectors of each channel. For a parameter point
the code computes the probabilities at $L=735$ km, folds them through the matrices, and
**conditions the far-detector prediction on the observed near-detector spectrum** — ordinary
Gaussian conditioning: mean $\mu_F+\Sigma_{FN}\Sigma_{NN}^{-1}(x_N-\mu_N)$, covariance
$\Sigma_{FF}-\Sigma_{FN}\Sigma_{NN}^{-1}\Sigma_{NF}$. This *is* the two-detector method: the near
detector fixes the product flux × cross section × efficiency, and only the far/near difference
carries oscillation information. The likelihood is the product of two multivariate Gaussians,
far CC and far NC. **Two cross-section nuisance parameters** from Newtrinos' `xsec` module, both
$\mathcal N(1,0.2)$ truncated to $[0.4,1.6]$: `nc_norm` multiplies the NC prediction;
**`nutau_cc_norm` is never used by this module** (its scale function returns 1 for the CC sample
because the flavour label passed is `:any`), so its posterior must equal its prior — a second
free sampler diagnostic (we get $0.995\pm0.193$ against a prior of $1.00\pm0.195$ **[ours]**).

Implications: "beam only" — MINOS also recorded atmospheric neutrinos and antineutrino-mode
beam data, which are *not* in this release; the 2020 three-flavour publication used more data
than we do, so our $\theta_{23}$ posterior is legitimately a bit wider. The NC sample mostly
constrains `nc_norm` (pulled to $0.86\pm0.13$ **[ours]**, a 0.7σ pull with the width narrowed
from 0.20 to 0.13 — the NC sample *does* measure it). Parameters it constrains: $\theta_{23}$
(bimodally), $\lvert\Delta m^2_{32}\rvert$.

### 2.5 The three side by side

| | Daya Bay | KamLAND | MINOS / MINOS+ |
|---|---|---|---|
| source | 6 reactor cores, 17.4 GW | ~57 Japanese reactor cores | NuMI $\nu_\mu$ beam |
| particle / energy | $\bar\nu_e$, 1.8–8 MeV | $\bar\nu_e$, 1.8–8 MeV | $\nu_\mu$, 0.5–20 GeV |
| baseline | 0.36–1.9 km (far hall 1.5–1.9 km) | ≈180 km flux-weighted | 735 km |
| detector | 8 × 20 t Gd-scintillator | 1 kt scintillator | 0.98 kt near + 5.4 kt far steel/scintillator |
| signal | IBD, n-capture on Gd | IBD, n-capture on H | CC $\nu_\mu$ track + shower; NC shower |
| what the spectrum encodes | depth → $\sin^2 2\theta_{13}$, position → $\Delta m^2_{ee}$ | wiggle period → $\Delta m^2_{21}$, depth → $\theta_{12}$ | depth → $\sin^2 2\theta_{23}$, dip → $\lvert\Delta m^2_{32}\rvert$ |
| data in Newtrinos | official supplementary release, 26 bins | digitised from paper figure, 17 bins | official HDF5 release, 4 spectra + covariances |
| likelihood | 26-d Gaussian, systematic covariance | 17 Poisson bins | 2 Gaussians (far CC, far NC) conditioned on near |
| free nuisances | none | 3 | 1 effective (`nc_norm`; `nutau_cc_norm` inert) |
| publication | PRL 130, 161802 (2023) | PRD 83, 052002 (2011) | PRL 125, 131802 (2020); release arXiv:1710.06488 |

### 2.6 What each experiment cannot tell us — and what the trio cannot

* Daya Bay: nothing about $\theta_{23}$ or $\delta_{CP}$; $\theta_{12}$, $\Delta m^2_{21}$ only as
  external inputs; the ordering only at the per-mille level (below its precision).
* KamLAND: nothing about $\theta_{23}$, $\delta_{CP}$, the ordering; $\theta_{13}$ only through a
  normalisation degenerate with the flux.
* MINOS: nothing about $\theta_{12}$, $\Delta m^2_{21}$, $\delta_{CP}$; the octant not at all; the
  ordering not from disappearance alone.
* The trio: no appearance channel → **no $\delta_{CP}$, no octant resolution**; vacuum
  baselines → **no mass-ordering resolution**; no solar data → $\theta_{12}$ rests on one digitised
  spectrum. This is not a defect of our analysis — it is the physics of these data — but it
  determines what the chapter can claim: precise $\theta_{13}$, $\Delta m^2_{31}$, $\Delta m^2_{21}$,
  $\theta_{12}$; a quantified two-mode $\theta_{23}$; a Bayes factor that *demonstrates* the
  ordering blindness.

### 2.7 Why these three, and what else Newtrinos offers

Why the trio: every parameter except $\delta_{CP}$ is pinned by at least one experiment; the
constraints are complementary (Daya Bay's $\theta_{13}$ is what turns MINOS's amplitude into
$\theta_{23}$; Daya Bay's and MINOS's splittings cross-check each other and generate the only
ordering sensitivity we have); all three are cheap, so the full posterior costs ≈6 ms per
evaluation and a five-sampler benchmark with $5\times10^5$ evaluations per cell fits on a laptop.

Other experiment modules present in the pinned Newtrinos (`src/experiments/`), and what each
would add — none of them has been tried by us, and their evaluation cost is unknown until measured:

| module | physics | would add | caveat |
|---|---|---|---|
| `super_k/sk_atm_2023` | Super-Kamiokande atmospheric $\nu$ (matter effects through the Earth) | octant and ordering sensitivity; $\delta_{CP}$ weakly | likelihood with Earth propagation and many bins — probably 10–100× costlier |
| `icecube/deepcore_*`, `icecube/upgrade_sim_2020` | IceCube DeepCore atmospheric $\nu_\mu$ disappearance (and a simulated Upgrade) | independent $\theta_{23}$, $\Delta m^2_{32}$; ordering (Upgrade, simulated) | same cost caveat; Upgrade is a forecast, not data |
| `km3net/orca6_433kton` | KM3NeT/ORCA first data | independent $\theta_{23}$, $\Delta m^2_{32}$ | small data set |
| `juno/juno.jl`, `juno/tao.jl` | JUNO reactor experiment at 53 km (simulated) with its near detector TAO | **mass-ordering sensitivity via the interference term**; precision $\Delta m^2_{21}$, $\theta_{12}$, $\Delta m^2_{31}$ | *simulated* data — a sensitivity forecast, not a measurement |
| `coherent/*` | coherent elastic neutrino–nucleus scattering | not oscillation physics | — |

**Check yourself (Part 2).**
1. What two flashes define an IBD event, and how far apart in time are they at Daya Bay?
2. Why does the far/near ratio remove the reactor-flux uncertainty, and what would happen to the
   $\theta_{13}$ measurement without near detectors?
3. What does "digitised" mean for the KamLAND data, and which two of our parameters does it
   affect?
4. In the MINOS module, what is the role of the near-detector spectrum mathematically?
5. Why is the NC sample nearly useless for the six oscillation parameters, and what does it do
   in our fit instead?

---

## Part 3 — Our statistical model

### 3.1 Bayes in one paragraph

Parameters $\theta$ (11), data $D$ (the histograms of Part 2). The **likelihood**
$\mathcal L(\theta)=p(D\mid\theta)$ is the product of the three experiment likelihoods — 26-d
Gaussian × 17 Poissons × 2 Gaussians. The **prior** $\pi(\theta)$ encodes what we allow before
seeing the data. The **posterior** is

$$
p(\theta\mid D)=\frac{\mathcal L(\theta)\,\pi(\theta)}{Z},\qquad
Z=\int\mathcal L(\theta)\,\pi(\theta)\,d\theta .
$$

Sampling $p(\theta\mid D)$ is what all five algorithms do; $Z$ (the **evidence**) is what
MoleWhacker, nested sampling and importance sampling additionally estimate.

### 3.2 The eleven parameters and their priors

| # | parameter | prior | why this range |
|---|---|---|---|
| 1 | $\theta_{12}$ | $U(0.4205,\ \pi/4)$ ↔ $\sin^2\theta_{12}\in[1/6,1/2]$ | the physically distinct range; $\theta_{12}>45^\circ$ ("dark side") is excluded by solar data |
| 2 | $\theta_{13}$ | $U(0.10,\ 0.20)$ | generous box around the reactor value 0.148 |
| 3 | $\theta_{23}$ | $U(\pi/6,\ \pi/3)$ ↔ $\sin^2\theta_{23}\in[0.25,0.75]$ | symmetric about maximal mixing so both octants are allowed |
| 4 | $\delta_{CP}$ | $U(0,\ 2\pi)$ | full circle; expected to stay flat |
| 5 | $\Delta m^2_{21}$ | $U(6.5,\ 9.0)\times10^{-5}\,\mathrm{eV^2}$ | box around the solar value |
| 6 | $\Delta m^2_{31}$ | $U(2,\ 3)\times10^{-3}$ (NO) or $U(-3,\ -2)\times10^{-3}$ (IO) | one box per ordering; the ordering is a discrete model choice |
| 7 | `kamland_energy_scale` | $\mathcal N(0,1)$ truncated $[-3,3]$ | 1σ = 1.9 % energy-scale uncertainty |
| 8 | `kamland_flux_scale` | $\mathcal N(0,1)$ truncated $[-3,3]$ | 1σ = 4.1 % rate uncertainty |
| 9 | `kamland_geonu_scale` | $U(-0.5,\ 0.5)$ | ±50 % on the geo-neutrino rate |
| 10 | `nc_norm` | $\mathcal N(1,0.2)$ truncated $[0.4,1.6]$ | NC cross-section normalisation |
| 11 | `nutau_cc_norm` | $\mathcal N(1,0.2)$ truncated $[0.4,1.6]$ | inert in this fit (2.4) |

Priors 1–6 are the defaults of Newtrinos' `ThreeFlavour` configuration, 7–11 those of the
experiment modules; we changed none. Remarks:

* The boxes are wide compared with the posteriors (the data, not the prior edges, set the
  widths), except that $\theta_{23}$'s box is where the octant modes live — necessarily, both
  must be inside.
* The $\theta_{23}$ prior is uniform *in the angle*. Transformed to $s=\sin^2\theta_{23}$ it is
  $\propto1/\sqrt{s(1-s)}$, symmetric about $s=\tfrac12$, so it does not tilt the octant balance;
  it mildly favours the edges of the box relative to a prior flat in $s$. A prior-sensitivity
  check (flat in $\sin^2$) is cheap and would be a natural robustness paragraph.
* We deliberately use **no information from other experiments** (no NuFIT prior, no solar
  data): the point is to see what these three data sets say by themselves.
* The ordering enters as two separate models with two separate posteriors and evidences, not
  as a sign parameter — because a sampler cannot move across the gap between
  $\Delta m^2_{31}\approx+2.5\times10^{-3}$ and $-2.5\times10^{-3}$ anyway.

### 3.3 How one likelihood evaluation happens, and what it costs

For a parameter vector: Newtrinos' oscillation module builds the PMNS matrix and returns the
$3\times3$ vacuum probabilities on the energy × baseline grid each experiment needs
(`osc_prob(E, L, params)`; the Daya Bay and KamLAND modules take the $\bar\nu_e\to\bar\nu_e$
element, MINOS the $\nu_\mu\to\nu_\mu$, $\nu_\mu\to\nu_e$, $\nu_\mu\to\nu_\tau$ and $\nu_e\to\nu_e$
elements). Each forward model turns the probabilities into predicted histograms, wraps them in a
distribution (MvNormal, Poisson product) and evaluates the log-probability of the observed
counts; the three log-likelihoods are summed. Wall time ≈6 ms on one core (about 1.3 ms of it
KamLAND, the rest mostly MINOS's matrix algebra), 12–18 ms when all cores are busy.

The thesis cost unit is this evaluation: one unit per log-density call, $d=11$ units per
gradient (forward-mode automatic differentiation propagates one dual number per coordinate),
$d^2$ per Hessian. NUTS pays for gradients at every leapfrog step; MoleWhacker pays gradients and
Hessians in its seed phase (L-BFGS + local Gaussian fits) and plain evaluations afterwards;
MH, NS and IS pay plain evaluations only. A budget of $5\times10^5$ units is therefore ≈50 min
of single-core likelihood time; what a method extracts from it is the whole question.

### 3.4 Putting the posterior on the cube (the only thing we had to add)

The thesis harness samples densities on a box $[-L,L]^d$, $L=10$. The neutrino problem is
wrapped (`neutrino/src/neutrino_problem.jl`) by an affine map per coordinate from $[-10,10]$ onto
the prior support of parameter $k$. For uniform priors the prior density is then a constant and
disappears into the normalisation; for the four truncated normals the Gaussian shape is kept as
an explicit $-\tfrac12z_k^2$ term. Hence

$$
\log f_{\rm cube}(u)=\log\mathcal L(\theta(u))-\tfrac12\sum_{k\in\rm gauss}z_k(u)^2 ,
\qquad
\ln Z_{\rm phys}=\ln Z_{\rm cube}+3.50 ,
$$

where 3.50 collects the Jacobians of the affine maps and the truncated-normal normalisations
and is **identical for NO and IO**, so the Bayes factor between the orderings is exactly the ratio
of the two cube evidences. The samplers never learn that this is a neutrino problem: they see a
smooth log-density on an 11-dimensional cube, as they saw the synthetic targets of the thesis.

### 3.5 Evidence, Bayes factor, Occam

$Z$ is the average of the likelihood over the prior. It rewards models that predict the data
well *over their whole prior volume* — a model whose prior wastes volume on regions the data
exclude is penalised (the "Occam factor"). That is why comparing NO and IO is only meaningful
because their priors are mirror images of identical volume: the Bayes factor
$K=Z_{\rm NO}/Z_{\rm IO}$ then measures how well each ordering *fits*, not how much prior
volume each was given. Jeffreys' scale for $|\ln K|$: below 1.1 "not worth more than a bare
mention", 1.1–2.3 "substantial", 2.3–3.4 "strong", 3.4–4.6 "very strong", above 4.6 "decisive".
The physics expectation (1.8) is $|\ln K|\lesssim1$; the reference estimate is
$\ln K=0.42\pm0.01$ and MoleWhacker gives $0.45\pm0.02$ **[ours]**. The value of this number is
not the physics — everyone knows these data cannot decide the ordering — but that three evidence
estimators (MoleWhacker, nested sampling, importance sampling) can be compared on a real
posterior against an independent reference. That comparison produced the most instructive
result of the whole study (4.6b): the nested-sampling run that was meant to be the reference is
biased by 1.5–2 nats although it satisfies its own convergence criterion, and MoleWhacker's
evidence is low by 0.2 nats for a reason that can be located precisely.

### 3.6 What this posterior looks like, and why it is a good test

* nine well-constrained, nearly Gaussian directions (the angles except $\theta_{23}$, the two
  splittings, the KamLAND nuisances, `nc_norm`);
* one **bimodal** direction ($\theta_{23}$), two modes of comparable weight separated by a
  region suppressed by only $e^{-2}$ ($\Delta\chi^2\approx4$ at maximal mixing) — easy to
  *find*, hard to *weight* correctly: a chain that visits both modes still has to spend the
  right fraction of time in each;
* one **flat** direction ($\delta_{CP}$) and one **prior-shaped** direction (`nutau_cc_norm`)
  with exactly known posteriors;
* mild correlations: $\theta_{13}$–$\Delta m^2_{31}$ (Daya Bay), $\Delta m^2_{21}$–energy scale
  and $\theta_{12}$–flux scale (KamLAND), and, through the mirror symmetry, the octant mode
  with everything MINOS touches (the "butterfly" in the $\theta_{23}$–$\Delta m^2_{31}$ panel of
  the corner plot).

For the samplers this is a different animal from the synthetic mixtures of the thesis: a real
likelihood at milliseconds per call, a physical multimodality, and exact answers for two of the
eleven marginals.

### 3.7 Bayesian numbers versus the collaborations' numbers

The collaborations publish frequentist results: a best fit (maximum likelihood) with intervals
from $\Delta\chi^2=1$ (or 2.71 for one-sided 90 %), often after *profiling* — maximising over
the other parameters. We report posterior means, standard deviations and 16/50/84 % quantiles
after *marginalising* — integrating over the other parameters with the prior. For a
near-Gaussian parameter the two agree; where the posterior is skewed or bimodal they legitimately
differ (the posterior mean of $\sin^2\theta_{23}$, 0.54, sits between the modes and describes
nothing — that is why the octant is reported as a probability and the modes as positions). Our
profile-likelihood scan (4.4) is the frequentist counterpart computed with the *same* model, so
the comparison in `nu_profile_*.pdf` isolates prior/marginalisation effects from data effects.

**Check yourself (Part 3).**
1. Why must the NO and IO prior boxes have the same volume for the Bayes factor to be
   interpretable?
2. What does the $-\tfrac12z^2$ term in $\log f_{\rm cube}$ do, and for which four parameters?
3. How many cost units does one NUTS leapfrog step cost here, and why?
4. Why is the posterior mean of $\sin^2\theta_{23}$ not a useful summary?
5. What would you expect to change in the octant probability if the prior were flat in
   $\sin^2\theta_{23}$ rather than in $\theta_{23}$?

---

## Part 4 — Our computational experiment

### 4.1 The algorithm under test is the thesis MoleWhacker, unchanged

Every MoleWhacker cell calls `run_algorithm(:mw, cfg, B, seed)` from the thesis harness
(`02_molewhacker/MoleWhacker/experiments/src/algorithms/algo_mw.jl`), which drives the same
`MoleWhacker.jl` module (`scripts2/algo/MoleWhacker.jl`: `make_init_samples` followed by
`whack_many_moles`) that produced every table in the thesis. Hyperparameters are the
`MWParams()` defaults, i.e. thesis Table 6.2: up to 64 Sobol seeds, capped so that
initialisation uses at most $0.30\,B$; 2000 samples per iteration; 8 parallel mole fits;
$T_{\max}=20$ iterations; $N_{\rm eff}$ and efficiency stops disabled (full-budget protocol);
component-merging tolerances $10^{-3}$ (Mahalanobis) and $10^{-5}$ (Frobenius), the algorithm's
own defaults. The four baselines (MH with 4 chains and pilot/tune/production phases; NUTS via
BAT/AdvancedHMC with exact leapfrog accounting; ellipsoidal nested sampling with
$n_{\rm live}=\max(400,25d^2)=3025$; prior-centred importance sampling) and the cost counter are
likewise the thesis implementations. **The only new code is the target density** (3.4) and the
scripts that queue cells, aggregate results and plot.

Bookkeeping quirk for later: the harness writes `tau_mu = 0.5` and `tau_Sigma = 0.2 d` into every
cell's `metadata.json`, but never passes them to the algorithm. The merge tolerances in force
are $10^{-3}$/$10^{-5}$, which is what the thesis table states. The metadata is misleading; the
thesis is right; this predates the neutrino work.

### 4.2 The cell grid

A **cell** is one run of one algorithm on one posterior with one budget and one seed:
`nu_dakami_<NO|IO>_<mw|mh|nuts|ns|is>_d11_B<5e4|5e5>_seed<11|23|41>`. Budgets are the two
largest of the thesis grid ($5\times10^3$ is dropped: below the initialisation cost of any
method in $d=11$).

| algorithm | $B=5\times10^4$ | $B=5\times10^5$ | status 12 Sep, 00:06 — **campaign complete, 51 cells** |
|---|---|---|---|
| MoleWhacker | seeds 11, 23, 41 × NO, IO | seeds 11, 23, 41 × NO, IO | done |
| Metropolis–Hastings (4 chains) | seeds 11, 23, 41 × NO, IO | seeds 11, 23, 41 × NO, IO | done |
| NUTS | seed 11 × NO, IO (budget-infeasible, documented) | seeds 11, 23 × NO, IO | done |
| Nested sampling ($n_{\rm live}=3025$) | seeds 11, 23, 41 × NO, IO | seeds 11, 23 × NO, IO | done |
| Importance sampling | seeds 11, 23, 41 × NO, IO | seed 11 × NO, IO | done |
| NS run to its own criterion (Δln Z < 0.5) | — | one per ordering | done: 8.4–8.5 × 10⁵ evaluations, 2.4 h each — and biased, see 4.6b |
| KamLAND-only MW fit | one cell | — | done |

Three seeds where a cell is cheap (≤15 min), one or two where it costs hours — the thesis
compromise as well. Multi-hour cells run single-threaded; MoleWhacker uses 4 threads for its
parallel fits; 3–5 cells share the 12 cores at any time.

### 4.3 What we measure in every cell, and what the numbers mean

`neutrino/scripts/20_aggregate.jl` reads every finished cell and writes:

* **`cells.csv`** — per cell: evaluations used (`Nlike_used`), wall time, stop reason,
  effective sample size `neff`, `eta = neff / Nlike_used` (the thesis headline: independent
  draws per likelihood evaluation), evidence where available, posterior mean and sd of every
  parameter. ESS is Kish's $(\sum w)^2/\sum w^2$ for weighted samples (MW, NS, IS) and the
  autocorrelation-corrected ESS for chains (MH, NUTS).
* **`physics.csv`** — per (ordering, algorithm, budget), seeds pooled with equal weight: mean,
  sd, 16/50/84 % quantiles of every parameter and of the derived quantities the collaborations
  publish ($\sin^2 2\theta_{13}$, $\sin^2\theta_{12}$, $\tan^2\theta_{12}$, $\sin^2\theta_{23}$,
  $\Delta m^2_{32}$), and the posterior probability of the upper octant.
* **`agreement.csv`** — distance of each cell's marginals from a reference sample (the pooled
  MH chains at the top budget, the thesis convention; a cell is never compared with itself):
  the 1-d Wasserstein distance per parameter on the unit cube, i.e. in units of the prior width,
  averaged over all eleven (`W1_avg`) and over the six oscillation parameters (`W1_osc`). For
  scale: a shift of 1 % of the prior width in $\theta_{13}$ is 0.001 rad, one fifth of its
  posterior sd.
* **`chains.csv`** — for MH and NUTS: per-chain upper-octant fraction, acceptance rate, and
  split-$\hat R$ of $\theta_{23}$ — the direct test of whether individual chains got stuck in one
  octant.
* **`evidence.csv`, `bayes_factor.csv`** — $\ln Z$ per cell for the three evidence-producing
  methods, and $\ln K$ with its seed-to-seed spread.

### 4.4 Two cross-checks that use none of the five samplers

* **Profile likelihood** (`50_profile.jl`): for $\theta_{23}$ and $\Delta m^2_{31}$ on a 31-point
  grid, Newtrinos' own L-BFGS optimiser maximises the likelihood over the other ten parameters.
  $\exp(-\Delta\chi^2/2)$ overlaid on the MoleWhacker marginal tests the *shape* of the posterior
  independently of any sampler (they need not coincide exactly: one maximises, the other
  integrates, and the prior is uniform in the angle).
* **KamLAND-only fit** (`nu_ka_NO_mw_d9_B5e4_seed11`): shows the $\Delta m^2_{21}$ offset is in
  the data module, not in the combination.

### 4.5 Hypotheses, written down before the remaining cells finish

1. **Physics.** All posteriors compatible with the published values and NuFIT 6.0 within one
   standard deviation except $\Delta m^2_{21}$ (+1.2σ, digitisation). $\theta_{23}$ bimodal with a
   mild preference for the upper octant (the profile likelihood must show the two minima within
   $\Delta\chi^2\approx1$). $\delta_{CP}$ flat; `nutau_cc_norm` equal to its prior; $|\ln K|<1$.
2. **MoleWhacker.** Finds both octant modes in every seed at both budgets; ESS in the thousands
   at $5\times10^4$; at $5\times10^5$ stops on $T_{\max}$ after ≈$1.2\times10^5$ evaluations, so
   the extra budget goes unused (a protocol limitation to state, not a failure). Cost dominated
   by the seed phase (Sobol seeds + L-BFGS + Hessians ≈ 80 % of evaluations).
3. **MH.** At $5\times10^4$ the four chains have not equilibrated between octants
   ($\hat R(\theta_{23})>1.05$, per-chain octant fractions spread widely); at $5\times10^5$ they
   have, and the pooled marginals agree with MoleWhacker's, with ESS of order $10^2$–$10^3$.
4. **NUTS.** Budget-infeasible at $5\times10^4$ (one tuned warm-up costs ≈$2\times10^5$ units in
   $d=11$); at $5\times10^5$ a single chain with ESS of order $10^2$; accurate where it runs, but
   a single chain can under-weight one octant.
5. **NS.** With $n_{\rm live}=3025$ a run needs $\gtrsim10^6$ evaluations to converge, so both
   budgets stop on the call cap with an unfinished evidence integral; ESS of order 1–10 at
   $5\times10^4$, $10^2$ at $5\times10^5$. The `nsref` runs give the converged $\ln Z$ that
   MoleWhacker's and IS's evidences are judged against. *(Outcome: the first two sentences held,
   convergence took 8.5 × 10⁵ evaluations; the last sentence failed — see 4.6b. Recorded here
   unedited because a hypothesis that fails is worth more in the chapter than one that holds.)*
6. **IS.** ESS of order 1 at $5\times10^4$, 10 at $5\times10^5$; evidence noisy but unbiased in
   expectation.

### 4.6 Where we stand (12 Sep, campaign complete) **[ours]**

Physics, MoleWhacker at $B=5\times10^5$, NO, three seeds pooled:

| quantity | our posterior (mean ± sd) | published | NuFIT 6.0 |
|---|---|---|---|
| $\sin^2 2\theta_{13}$ | $0.0855\pm0.0032$ | $0.0851\pm0.0024$ (Daya Bay) | 0.0866 |
| $\Delta m^2_{32}$ [$10^{-3}$ eV²] | $2.449\pm0.054$ (IO: $-2.540\pm0.055$) | $2.466\pm0.060$ (Daya Bay; IO $-2.571$); $2.40^{+0.08}_{-0.09}$ (MINOS+) | 2.438 |
| $\Delta m^2_{21}$ [$10^{-5}$ eV²] | $7.75\pm0.23$ (+1.2σ) | $7.49\pm0.20$ (KamLAND) | 7.49 |
| $\sin^2\theta_{12}$ | $0.317\pm0.034$ | $0.30^{+0.05}_{-0.04}$ (KamLAND) | 0.308 |
| $\sin^2\theta_{23}$ | bimodal; 16/50/84 % quantiles 0.39 / 0.59 / 0.66; $P({\rm upper})=0.63$ (IO 0.62) | $0.43^{+0.20}_{-0.04}$ (MINOS+) | 0.470 (IO 0.550) |
| $\delta_{CP}$ | $2.95\pm1.81$ — flat $U(0,2\pi)$ has $3.14\pm1.81$ | — | — |
| `nutau_cc_norm` | $0.995\pm0.193$ — prior $1.00\pm0.195$ | — | — |
| `nc_norm` | $0.86\pm0.13$ (0.7σ pull, narrowed from 0.2) | — | — |
| $\ln K$ (NO/IO) | $0.45\pm0.02$ (MW); reference $0.42\pm0.01$ | — | — |

Joint best fit from the profile scan (NO): $\sin^2\theta_{23}=0.64$, $\theta_{13}=0.1485$,
$\theta_{12}=0.596$, $\Delta m^2_{21}=7.74\times10^{-5}$, $\Delta m^2_{31}=2.529\times10^{-3}$,
`nc_norm` 0.81, KamLAND flux scale +0.53σ. The two octant minima differ by $\Delta\chi^2=1.1$
(posterior odds 1.7:1 — consistent with $P=0.63$); maximal mixing is disfavoured by
$\Delta\chi^2=4.1$ (NO) and 5.4 (IO).

Methods agree where they have enough effective samples: at $5\times10^5$ the upper-octant
probability is 0.61 (MH, pooled 3 seeds), 0.60–0.61 (reference IS), 0.61 (NS to convergence),
0.62–0.65 (NUTS, single chains), 0.63 (MoleWhacker pooled cloud; 0.59–0.61 from fresh draws
of the same mixtures, see 4.6b) for NO; the importance sampler at $5\times10^4$ gives 0.89–0.91
with an ESS of ≈1.5, which is what an estimate from one or two effective draws looks like.

Samplers at $B=5\times10^4$ (median over seeds): MoleWhacker ESS 3200 (NO) / 3800 (IO) from
≈38 000 evaluations, $\eta\approx0.1$; MH ESS ≈40 with per-chain octant fractions from 0.40 to
0.79 ($\hat R(\theta_{23})=1.05$–$1.16$); NS ESS ≈5; IS ESS 2–4; NUTS infeasible.

At $B=5\times10^5$ (medians over seeds; wall times on a shared machine):

| method | evaluations used | wall time | ESS (NO / IO) | $\eta$ = ESS/evaluations | W̄₁ to MH pool | $\ln Z$ vs reference |
|---|---|---|---|---|---|---|
| MoleWhacker (3 seeds) | $1.15$–$1.18\times10^5$, stops on $T_{\max}$ | 13–17 min | 2232 / 1958 | $1.9$ / $1.7\times10^{-2}$ | 0.006 / 0.008 | $-0.22$ / $-0.25$ |
| MH, 4 chains (3 seeds) | $5\times10^5$ | 1.5–2.7 h | 644 / 403 | $1.3$ / $0.8\times10^{-3}$ | 0.004 / 0.004 | — |
| NUTS, 1 chain (2 seeds) | $4.5$–$4.6\times10^5$ incl. warm-up ≈$2\times10^5$ | 47–89 min | 103 / 49 | $2.3$ / $1.1\times10^{-4}$ | 0.009 / 0.011 | — |
| NS, $n_{\rm live}=3025$ (2 seeds) | $3.4\times10^5$, stops on call cap | 0.5–1.7 h | 185 / 76 | $5.4$ / $2.2\times10^{-4}$ | 0.015 / 0.022 | $+1.3$ / $+1.5$ |
| IS (1 seed) | $5\times10^5$ | 1.8–2.8 h | 10 / 26 | $2$ / $5\times10^{-5}$ | 0.042 / 0.023 | $+0.25$ / $-0.12$ |
| NS run to Δln Z < 0.5 (1 seed) | $8.4$–$8.5\times10^5$ | 2.4 h | 18 911 / 18 398 | $2.2\times10^{-2}$ | 0.011 / 0.013 | **$+1.47$ / $+2.11$** |

Reading: at the small budget MoleWhacker is the only method with a usable posterior; at the
large budget it is 15–20× more efficient than MH and 70–170× more than NUTS; NS run to its own
convergence matches MoleWhacker's efficiency after 8.5 × 10⁵ evaluations but gets the evidence
wrong. MH at $5\times10^5$ is the most *accurate* sampler in the W̄₁ sense (it is also the
reference's anchor), MoleWhacker next.

### 4.6b The evidence arbitration — the story of the last twelve hours

The plan was: nested sampling, run past the budget to its own stopping criterion (Δln Z < 0.5),
provides the reference $\ln Z$ against which MoleWhacker's and IS's evidences are judged. It
finished overnight after 8.4 × 10⁵ evaluations per ordering with $\ln Z=-509.39\pm0.05$ (NO) and
$-509.17\pm0.05$ (IO) — **1.7 and 2.4 nats above MoleWhacker**, and with the *opposite* sign of
$\ln K$ ($-0.23$ instead of $+0.45$). Somebody was wrong by a factor 5–10 in $Z$.

Arbitration by an estimator that depends on neither (`70_evidence_check.jl`): importance
sampling from a *defensive kernel mixture* — 3000 Gaussian kernels centred on random members of
the pooled MH chains, shared covariance $h^2\Sigma_{\rm MH}$, mixed with 10 % uniform prior so
that no weight can explode — is unbiased for $Z$ by construction and gives a standard error
from its weights. With 1.5 × 10⁵ draws and two bandwidths ($h=0.6, 0.9$; ESS 14 000–25 000):

$$
\ln Z_{\rm NO}=-510.87\pm0.01,\qquad \ln Z_{\rm IO}=-511.28\pm0.01,\qquad \ln K=0.42\pm0.01 .
$$

The pooled plain-IS draws of the campaign (6.5 × 10⁵ uniform draws, ESS 12/32) agree:
$-510.46\pm0.29$ and $-511.22\pm0.18$. So:

* **Nested sampling is biased high by 1.5 (NO) and 2.1 (IO) nats** although its own criterion is
  met, its posterior sample is excellent (ESS 18 000, all marginals right, P(upper) 0.61/0.58)
  and its quoted error is 0.05. This is the textbook failure of ellipsoidal ("MultiNest-type")
  nested sampling: when the bounding ellipsoids clip the likelihood-constrained region, the
  replacement points come from too small a volume, the dead-point likelihoods climb faster
  than the assumed shrinkage $e^{-1/n_{\rm live}}$, and $Z$ is overestimated. Nothing in the
  run's own diagnostics reveals it; only an independent estimate does. The lesson for the
  chapter: a "converged" nested-sampling evidence is not a reference on a real posterior.
* **MoleWhacker is biased low by 0.22 (NO) and 0.25 (IO) nats**, with a seed spread of 0.01–0.03
  that understates its error tenfold; $\ln K$ comes out right (0.45 vs 0.42) only because the
  offset is common to both orderings. `72_mw_mixture_check.jl` reloads each cell's final
  mixture (169–174 Gaussians) and draws 60 000 *fresh* points from it: that plain importance
  sampler gives $-510.876/-510.872/-510.854$ (NO) and $-511.268/-511.288/-511.268$ (IO) — the
  reference to within 0.02. **The mixture is right; the algorithm's estimator is not.**
  MoleWhacker accumulates every batch of samples it ever drew — each batch from the mixture
  *as it stood when that component was added* — and at the end weights the whole cloud with the
  *final* mixture density. Components added late, at exactly the places where the earlier
  mixture under-covered the target, are under-represented in the cloud relative to their final
  weights; the estimate converges to $\int f\,(q_{\rm cloud}/q_T)$ rather than to $Z$. The
  same bookkeeping lifts the pooled-cloud octant probability by 0.03 (NO) and 0.015 (IO) on
  average — seed by seed anywhere from −0.01 to +0.06 (0.63 against 0.60 from fresh draws) —
  the only visible bias of MoleWhacker's marginals in this study.
  The fix (weight each batch with the mixture it came from, or draw a final fresh sample) is
  obvious and cheap, and is *not* applied here: the thesis tests the algorithm as it is. It goes
  into the chapter as a finding and a recommendation.
* **Plain importance sampling from the prior is unbiased and useless** at these budgets:
  ESS 2–26 in eleven dimensions.

Why this matters beyond the number: it is exactly the kind of result Philipp asked for — a real
posterior, a real physics quantity (the Bayes factor), and three evidence estimators whose
disagreement had to be understood rather than averaged. The weight diagnostics behind it are in
`is_diagnostics.csv` (Kish ESS, largest-weight share, Pareto-$\hat k$ of every weighted cell:
MoleWhacker −0.4 to 0.3, i.e. well-behaved; budget-limited NS 0.7–4; IS 2.3–3.8, i.e. unusable).

### 4.7 Constraints and limitations of what we are doing — the honest list

*Of the physics model*
1. Vacuum oscillations (1.9): sub-percent effect for these baselines, but the collaborations
   include matter effects; must be stated.
2. Daya Bay: far-hall re-fit anchored on the collaboration's best-fit prediction; inherits their
   $\theta_{12}$, $\Delta m^2_{21}$ assumptions in the anchoring and their covariance.
3. KamLAND: digitised spectrum, 2011 data; the sole source of $\Delta m^2_{21}$ and $\theta_{12}$;
   +1.2σ offset in $\Delta m^2_{21}$ is a known consequence.
4. MINOS: beam-only 2017 release (no atmospheric, no antineutrino-mode data); `nutau_cc_norm`
   inert; NC sample constrains `nc_norm` only.
5. No appearance experiment → nothing on $\delta_{CP}$, no octant resolution; no long
   matter baseline → no ordering resolution. The Bayes factor and the bimodal posterior are
   *demonstrations of known blindness*, not discoveries.
6. Priors: Newtrinos' default boxes; $\theta_{23}$ uniform in angle; no external information.

*Of the sampling study*
7. Only two budgets, 1–3 seeds per cell; one machine; wall times depend on machine load
   (the 5e5 MH cells ran 1.7–2.7 h depending on what else was running).
8. MoleWhacker stops on $T_{\max}$ at $\approx1.2\times10^5$ evaluations, so the $5\times10^5$
   column does not test "more budget → better MW"; the protocol's $T_{\max}$, not the method,
   sets that ceiling.
9. Nested sampling with the protocol's $n_{\rm live}=3025$ is far from converged at both budgets;
   a smaller $n_{\rm live}$ would make NS look much better — the protocol is fair (same rule as
   in the thesis) but not NS-optimal; say so.
10. NUTS is infeasible at $5\times10^4$ by the thesis accounting (one warm-up ≈ $2\times10^5$
    units); at $5\times10^5$ we have one chain, so its $\hat R$ is a split-$\hat R$ of one chain.
11. The agreement reference is the pooled MH sample at $5\times10^5$; if MH itself were biased
    (it is not, by the profile, NUTS and converged-NS cross-checks) the metric would inherit
    it. The evidence reference is a purpose-built defensive importance sampler that needs the
    MH chains first — a check, not a competitor under the protocol.
12. Seeds: MoleWhacker's Sobol + L-BFGS initialisation is deterministic, so seed-to-seed spread
    reflects only the sampling noise after initialisation (a thesis caveat that carries over);
    the evidence story (4.6b) shows concretely that this spread is not an error bar.
13. Nested sampling run to its own convergence criterion is *not* a valid evidence reference
    here (biased by 1.5–2 nats, 4.6b); the protocol's $n_{\rm live}=25d^2$ also keeps NS far
    from convergence at both budgets.
14. MoleWhacker's pooled-cloud estimator biases its evidence by −0.2 nats and its octant
     probability by up to +0.06 per seed (+0.015–0.03 on average); the mixture itself is
     correct (4.6b).

### 4.8 What else we could do — options, costs, and what they would buy

*Cheap, within the present data (hours to a day each):*
* **Single-experiment fits** (Daya Bay alone, MINOS alone; KamLAND alone exists): shows what
  each data set knows on its own and how the combination sharpens $\theta_{23}$ via $\theta_{13}$
  and creates the $\Delta m^2$ cross-check. Textbook physics-chapter material; each fit ≈10 min.
* **Posterior-predictive plots**: the three data histograms with the band of predictions from
  posterior samples (the `primer_data_*.png` figures at a single best-fit point are the first
  step). The most convincing "the model describes the data" figure a physics reader expects.
* **Prior-sensitivity check**: flat in $\sin^2\theta_{23}$ instead of $\theta_{23}$; octant
  probability and $\ln K$ before/after. One MW cell per ordering.
* **Decompose the ordering preference**: profile $\lvert\Delta m^2_{32}\rvert$ separately for
  Daya Bay and MINOS in each ordering to show where $\ln K=0.45$ comes from (the $\Delta m^2_{21}$
  offset between $\Delta m^2_{ee}$ and $\Delta m^2_{32}$ flips sign with the ordering).
* **Finer profile grids** near the minima; a $\theta_{13}$ profile.

*Moderate (days), more physics from Newtrinos:*
* **JUNO forecast** (`juno/juno.jl` + `tao.jl`, simulated data): a Bayesian mass-ordering
  sensitivity study — "with JUNO's expected spectrum, the Bayes factor becomes …" — would be a
  forward-looking physics result and a natural use of an evidence-producing sampler. Needs
  reading of the module, a cost measurement, and care in presenting simulated data as a forecast.
* **Add an atmospheric experiment** (Super-K 2023 or IceCube DeepCore): brings matter effects,
  hence real octant/ordering information, and turns the bimodal posterior into a test of
  whether the samplers track a *shifting* mode balance. Cost per evaluation unknown and possibly
  prohibitive for $5\times10^5$-evaluation cells; must be measured first.
* **Sterile-neutrino (3+1) fit** with the MINOS NC sample: the release was built for it;
  requires a four-flavour oscillation configuration in Newtrinos (to be checked).

*Structural (the thesis text), for discussion only — no edits now:*
Philipp's second point is that the written thesis should be motivated and structured by the
physics. A physics-first skeleton that our material supports: (1) the physics question —
oscillations, the six parameters, the open questions, why global fits are Bayesian problems
with awkward posteriors; (2) the three experiments and their data; (3) the statistical method —
Bayesian inference, the sampling problem (multimodality, cost per evaluation), MoleWhacker as
the tool, the baselines; (4) validation on synthetic targets (the present benchmark, condensed);
(5) results — the joint fit, octant, ordering, nuisances, comparison with published values, and
the sampler comparison on the physics posterior; (6) discussion and outlook. What an extension
of six to eight weeks would buy, roughly: two weeks for the restructured text with the present
results, one to two for the cheap additions above, two to three for one moderate addition
(JUNO forecast or an atmospheric experiment), one for polishing and the companion repository.

### 4.9 What can still go wrong, and what we would do

* ~~A `nsref` run not converging~~ — it converged, and was wrong (4.6b); resolved by the
  defensive-IS reference.
* **MH at $5\times10^5$ not mixing** in some seed: a result, not a problem — exactly the behaviour
  a bimodal posterior should provoke; report per-chain octant fractions.
* **MoleWhacker missing an octant mode** in some seed: a genuine finding against the method;
  it would go into the chapter as such. All twelve cells so far show both modes.
* The **$\Delta m^2_{21}$ offset**: stays as a stated limitation of the digitised KamLAND module,
  with the KamLAND-only fit as evidence that it is neither a sampler nor a combination effect.

**Check yourself (Part 4).**
1. In what sense is the neutrino study "the exact MoleWhacker of the thesis", and what is the
   only thing that changed?
2. Why does MoleWhacker use only $1.2\times10^5$ of a $5\times10^5$ budget, and is that the
   method's fault?
3. What does `eta` in `cells.csv` measure and why is it the thesis's headline number?
4. Why is NS's evidence at $5\times10^5$ not yet comparable with MoleWhacker's, and what fixes it?
5. Name two additions that would give the chapter *more physics* without new data.

---

## Part 5 — Reading the figures

Teaching figures (`neutrino/out/figs/primer_*.png`):

| file | what is drawn | what to look for |
|---|---|---|
| `primer_survival_LE.png` | vacuum survival probabilities of $\bar\nu_e$ and $\nu_\mu$ against $L/E$, with the three experiments' windows shaded | the fast small $\theta_{13}$ wiggle around 500 km/GeV (Daya Bay, MINOS) and the slow deep $\theta_{12}$ oscillation around 16 000 km/GeV (KamLAND) |
| `primer_reactor.png` | $\bar\nu_e$ survival against energy at 1.65 km (three $\theta_{13}$ values) and at 180 km (three $\Delta m^2_{21}$ values) | depth ↔ angle, position ↔ splitting |
| `primer_minos_octant.png` | $\nu_\mu$ survival at 735 km for $\sin^2\theta_{23}=0.39$ vs 0.63 (indistinguishable) and for three $\Delta m^2_{31}$ values (dip moves) | the octant degeneracy with your own eyes |
| `primer_data_dayabay.png`, `primer_data_kamland.png`, `primer_data_minos.png` | the actual released data (points) against the Newtrinos prediction *at our joint best fit* (histogram with ±1σ band), and the ratio data/prediction | the model describes the data: Daya Bay's 26 bins agree to ≈1 % (5.5 million events), KamLAND's 17 digitised bins scatter at the 10 % level (≈2100 events), MINOS's CC and NC spectra agree within their systematic bands. Note these compare with the *oscillated* prediction, so the oscillation signal itself (the 6 % Daya Bay deficit, the KamLAND distortion, the MINOS dip at 1.5 GeV) is not what you see here — it is the difference to the *unoscillated* prediction, shown analytically in `primer_reactor.png` and `primer_minos_octant.png`. The MINOS CC spectrum peaks near 5 GeV because the 3 GeV (MINOS) and 7 GeV (MINOS+) beam configurations are summed |

Result figures (`neutrino/out/figs/nu_*.pdf`, `png/`):

| file | what is drawn | what to look for |
|---|---|---|
| `nu_marginals_<NO/IO>` | one panel per parameter: posterior density from each method at the top budget; published values as bars | methods agree; published bars overlap our densities; flat $\delta_{CP}$; two humps in $\theta_{23}$ |
| `nu_octant_<NO/IO>` | $\sin^2\theta_{23}$ marginal per method with the upper-octant probability | both humps in every method? a method under- or over-weighting one hump (NS IO at 5e5 does) |
| `nu_profile_<NO/IO>` | MoleWhacker marginal vs $\exp(-\Delta\chi^2/2)$ from the profile likelihood, $\theta_{23}$ and $\Delta m^2_{31}$ | same mode positions; comparable widths; octant minima within $\Delta\chi^2\approx1$ |
| `nu_nuisance_<NO/IO>` | the five nuisance posteriors against their priors | `nutau_cc_norm` = prior; KamLAND scales pulled by ≲1σ; `nc_norm` narrowed by the NC sample |
| `nu_corner_<NO/IO>` | pairwise 2-d posteriors of the five measured oscillation parameters, MoleWhacker (filled) vs MH (lines) | the $\theta_{13}$–$\Delta m^2_{31}$ correlation; the two octant islands; the $\theta_{23}$–$\Delta m^2_{31}$ butterfly; no method-dependent shifts |
| `nu_mw_iter_<NO/IO>` | MoleWhacker per-iteration diagnostics | how the budget is spent; when the mixture stops changing |
| `nu_agreement` | each method's W₁ distance from the pooled-MH reference vs budget | which methods converge to the reference and how fast |
| `nu_evidence` | $\ln Z$ per method and budget (hollow 5e4, filled 5e5); grey band = reference (defensive IS on the MH pool); black-edged triangle = NS run to Δln Z < 0.5 | MoleWhacker's tight cluster 0.2 nats *below* the band; NS at 5e5 and NS-to-convergence 1.3–2.1 nats *above* it; IS scattered around it. The picture of 4.6b in one panel |
| `primer_*` and the CSVs `evidence_check.csv`, `mw_mixture_check.csv`, `is_diagnostics.csv` | the arbitration numbers | see 4.6b |

---

## Part 6 — Glossary

* **Appearance / disappearance**: looking for a new flavour showing up / the original flavour
  going missing. All three of ours are disappearance experiments.
* **Baseline** $L$: source-to-detector distance.
* **Bayes factor** $K$: ratio of evidences of two models; here NO versus IO.
* **CC / NC**: charged-current interaction ($W$ exchange, produces the charged partner lepton,
  identifies the flavour) / neutral-current ($Z$ exchange, no charged lepton, flavour-blind).
* **Cell**: one run of one algorithm on one posterior with one budget and one seed.
* **Evidence** $Z$: integral of likelihood × prior; normalising constant of the posterior.
* **ESS**: effective sample size, the number of independent draws a weighted or correlated
  sample is worth.
* **IBD**: inverse beta decay, $\bar\nu_e+p\to e^++n$.
* **Mass ordering**: sign of $\Delta m^2_{31}$; normal (NO) if $\nu_3$ is the heaviest.
* **Mixing angle**: parameter of the rotation between the flavour and the mass basis.
* **MSW effect**: modification of oscillations by coherent forward scattering on electrons in
  matter.
* **Nuisance parameter**: a model parameter we do not care about (energy scale, flux
  normalisation) but must integrate over; its prior comes from calibration.
* **Octant**: whether $\theta_{23}$ is below or above $45^\circ$.
* **Oscillation maximum**: the $L/E$ at which the disappearance probability is largest.
* **PMNS matrix**: the unitary matrix connecting flavour and mass states.
* **POT**: protons on target, the exposure unit of a beam experiment.
* **Profile likelihood**: likelihood maximised over all parameters except the one plotted; the
  frequentist counterpart of a marginal posterior.
* **Prompt / delayed signal**: the positron flash / the neutron-capture flash of an IBD event.
* **$\hat R$**: Gelman–Rubin statistic; values well above 1 mean chains disagree.
* **Survival probability**: $P(\nu_\alpha\to\nu_\alpha)$.
* **W₁**: 1-d Wasserstein (earth-mover) distance between two marginal distributions.

---

## Appendix A — where things live

* Target density and cube mapping: `neutrino/src/neutrino_problem.jl`; published values for
  the overlays: `neutrino/src/published_values.jl`.
* One cell: `julia --project=neutrino -t 4 neutrino/scripts/10_run_cell.jl --alg mw --ordering NO --B 5e4 --seed 11`;
  a queue: `neutrino/scripts/run_queue.ps1 -Queue <name> -Threads <n>`.
* Pipeline after cells finish: `20_aggregate.jl` → `30_plots.jl` → `40_tables.jl`
  (outputs in `neutrino/out/tables/` and `neutrino/out/figs/`).
* Profile likelihood: `50_profile.jl [--n 31]`. Teaching figures: `60_primer_figures.jl`.
* Evidence arbitration: `70_evidence_check.jl` (defensive-IS reference), `71_is_diagnostics.jl`
  (weight diagnostics, Pareto-$\hat k$), `72_mw_mixture_check.jl` (fresh draws from the stored
  MoleWhacker mixtures).
* Campaign logs: `neutrino/out/logs/`; current orchestrator `orchestrate_v3.ps1`.
* Newtrinos (pinned commit `fa87689d`): `C:\Users\valen\.julia\packages\Newtrinos\HQ8a8\src\`,
  experiment modules under `experiments/{daya_bay,kamland,minos}/`, oscillation and
  cross-section code under `physics/`.

## Appendix B — answers to the check-yourself questions

**Part 1.** (1) The three mass states then acquire identical phases, the superposition is
unchanged, and its projection onto any other flavour stays zero; only phase *differences*
$\propto\Delta m^2$ cause flavour change. (2) $L=\pi E/(2\times1.267\,\Delta m^2)$: 2.0 km for
$2.5\times10^{-3}$, 66 km for $7.5\times10^{-5}$. (3) The disappearance amplitude is
$4x(1-x)$ with $x=\sin^2\theta_{23}\cos^2\theta_{13}$, symmetric under $x\to1-x$; Daya Bay's
$\theta_{13}$ fixes the mirror point $\sin^2\theta_{23}=1/(2\cos^2\theta_{13})=0.511$. (4)
`nutau_cc_norm`, because no term of any of the three likelihoods depends on it; and
$\delta_{CP}$, because survival probabilities contain only $|U_{\alpha i}|^2$. (5) KamLAND's
amplitude is $\sin^2 2\theta_{12}\approx0.85$ and its baseline is beyond the first $\Delta m^2_{21}$
maximum; Daya Bay's amplitude is $\sin^2 2\theta_{13}\approx0.085$.

**Part 2.** (1) The positron's prompt flash and the neutron-capture flash on gadolinium, ≈30 µs
later (≈200 µs on hydrogen at KamLAND). (2) Both halls see the same cores, so the flux (and its
uncertainty) cancels in the ratio; without near detectors the 6 % deficit would have to be
measured against a reactor-flux prediction uncertain at the few-per-cent level, which is
roughly where the single-detector experiments of the 2000s were stuck. (3) Counts, prediction,
background and geo-neutrino spectra were read off a published figure rather than taken from a
data release; it affects $\Delta m^2_{21}$ and $\theta_{12}$, which only KamLAND constrains. (4)
It is the conditioning variable in a joint Gaussian of [far; near]: the far prediction becomes
the conditional mean $\mu_F+\Sigma_{FN}\Sigma_{NN}^{-1}(x_N-\mu_N)$ with the conditional
covariance — the near data calibrate flux × cross section × efficiency. (5) NC interactions are
flavour-blind, so in a three-flavour world the NC rate is oscillation-independent; the sample
constrains the NC normalisation `nc_norm` (and would reveal sterile neutrinos).

**Part 3.** (1) Because the evidence averages the likelihood over the prior volume, a larger
box would be penalised by dilution irrespective of fit quality; equal mirror-image boxes make
$K$ a pure goodness-of-fit ratio. (2) It keeps the Gaussian shape of the truncated-normal
priors, which the affine map alone would flatten; for `kamland_energy_scale`,
`kamland_flux_scale`, `nc_norm`, `nutau_cc_norm`. (3) $d=11$ units: one gradient of the log
density, charged as one dual number per coordinate. (4) The distribution is bimodal; the mean
falls between the modes where the posterior is low. (5) Very little: the angle-uniform prior is
symmetric about $\sin^2\theta_{23}=0.5$, so the octant ratio is essentially unchanged; the tails
near 0.25 and 0.75 would lose a little weight.

**Part 4.** (1) The same code path (`run_algorithm(:mw, …)` → `MoleWhacker.jl`) with the same
Table 6.2 hyperparameters; only the log-density it is handed changed. (2) The protocol caps
the adaptive loop at $T_{\max}=20$ iterations, which in $d=11$ costs ≈$1.2\times10^5$
evaluations including initialisation; it is a protocol ceiling, not a failure of the method,
and it must be stated when the $5\times10^5$ column is discussed. (3) `eta` = ESS per
likelihood evaluation — independent draws bought per unit of cost, the quantity the whole
thesis compares. (4) NS at the protocol's $n_{\rm live}=3025$ stops on the evaluation cap with
part of the evidence integral outstanding; running it to Δln Z < 0.5 removes *that* problem but,
as 4.6b shows, leaves a 1.5–2 nat bias from the ellipsoidal bounding — only an independent
unbiased estimator (the defensive IS) settles it. (5) Single-experiment fits and posterior-predictive
plots (also: prior-sensitivity check; decomposition of the ordering preference).

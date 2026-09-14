# Newtrinos.jl DeepCore module: p₁ hole-ice term uses the p₀ slope table

Report prepared 14 Sep 2026 for the Newtrinos.jl authors (Philipp Eller).
Status in this repository: **not patched, not worked around**. Every result
uses Newtrinos.jl exactly as pinned in `Manifest.toml` (commit `fa87689d`);
the thesis chapter carries a footnote. The decision (14 Sep, 11:00) is to
report the finding and to keep the runs as they are unless the authors confirm
the slip and a rerun is affordable.

## 1. Where

* Repository `philippeller/Newtrinos.jl`, file
  `src/experiments/icecube/deepcore_9y_verification_sample/deepcore.jl`,
  function `get_hypersurface_factor`, line 248.
* Present in the pinned commit `fa87689d` (22 Aug 2026, "Update installation
  instructions for Newtrinos.jl"), which on 14 Sep 2026 is still the head of
  `main` (compare `fa87689d...main`: identical), and in every other branch
  checked on that date (`claude` at `4c10f615`, pushed 14 Sep 09:34;
  `CEvNS_alpha`; `N-Naturalness-to-merge`). The line is identical in all six
  commits that ever touched the file, from the first version of the module
  (`b450014a`, 29 Sep 2025, "first version of DeepCore verification sample";
  the follow-up `c499d233` fixed the NC factor) to `86230172` (18 Mar 2026).
  None of the 50 issues of the repository mentions it. An older local copy of
  the package (version 0.0.1) has the same line.

## 2. The line

As published (line 247 is p₀ and correct, line 248 is p₁):

```julia
(interpolate_hypersurface(hypersurface.hole_ice_p0, idx, fraction) * (params.deepcore_rel_eff_p0 - 0.1)) .+
(interpolate_hypersurface(hypersurface.hole_ice_p0, idx, fraction) * (params.deepcore_rel_eff_p1 + 0.05))
```

Intended, almost certainly:

```julia
(interpolate_hypersurface(hypersurface.hole_ice_p1, idx, fraction) * (params.deepcore_rel_eff_p1 + 0.05))
```

The hypersurface files of the data release do carry the p₁ column. Header of
`hs_numu_cc.csv` (identical for `hs_nutau_cc.csv` and `hs_nu_nc_nue_cc.csv`):

```
intercept, intercept_sigma, dom_eff, dom_eff_sigma, hole_ice_p0, hole_ice_p0_sigma,
hole_ice_p1, hole_ice_p1_sigma, bulk_ice_abs, bulk_ice_abs_sigma, bulk_ice_scatter,
bulk_ice_scatter_sigma, deltam31, pid, reco_coszen, reco_energy
```

`read_hs_csv_into_hist` (line 125) histograms every column except the four
coordinates, so `hypersurface.hole_ice_p1` exists and is simply never used.
First data row of `hs_numu_cc.csv` for scale: `hole_ice_p0 = 0.345`,
`hole_ice_p1 = 1.689` (per unit parameter).

## 3. Consequence

As published, `p0` and `p1` enter the expectation only through
`(p0 − 0.1) + (p1 + 0.05)` times the same table: the likelihood depends on the
two hole-ice parameters **only through their sum**. The data constrain
`p0 + p1`; conditional on the sum, the difference is distributed as the
(uniform) prior, and since the prior of `p1` (`Uniform(−0.15, 0.05)`, width
0.2) is much narrower than that of `p0` (`Uniform(−1, 0.5)`, width 1.5), the
marginal posterior of `p1` is essentially its prior. In a fit that treats `p1`
as a free nuisance parameter this is a flat ridge in the `(p0, p1)` plane; the
intended p₁ response is about nine times steeper and points in a different
direction in bin space.

Quantified with `scripts/86_deepcore_p1_check.jl` (four-experiment target
Daya Bay + KamLAND + MINOS + DeepCore, d = 24, normal ordering, all other
parameters at the Newtrinos nominal values; the corrected method is evaluated
into a throw-away session only). At the nominal point the two versions agree
exactly (the p₁ term vanishes at `p1 = −0.05`). Finite-difference slopes at the
nominal point:

| derivative                | as published | corrected |
|---------------------------|-------------:|----------:|
| ∂ log L / ∂p₁             |      −167.22 |  −1484.17 |
| ∂ log L / ∂p₀ (reference) |      −167.22 |   −167.22 |

The published ∂/∂p₁ equals ∂/∂p₀ to machine precision, which is the degeneracy
stated above. Profile over the p₁ prior support, Δ log L relative to the
nominal point (`out_extension/tables/deepcore_p1_check.csv`):

| p₁     | as published | corrected |
|-------:|-------------:|----------:|
| −0.150 |       +15.36 |   +103.03 |
| −0.100 |        +8.02 |    +63.25 |
| −0.050 |         0.00 |      0.00 |
|  0.000 |        −8.70 |    −84.50 |
|  0.050 |       −18.05 |   −188.45 |

The oscillation parameters are affected only indirectly, through the reduced
freedom of the detector model (one nuisance direction is missing, another is
duplicated). How large that effect is on the θ₂₃ / Δm²₃₂ posterior has not
been measured; the published fit of the module reproduces the IceCube 90 %
contour ("now contours are spot on", commit `c499d233`), so it is presumably
small.

## 4. Second observation: no inverted-ordering support

`binning.hs_dm31 = LinRange(0.0015, 0.0035, 20)` (line 67): the hypersurfaces
are tabulated for Δm²₃₁ ∈ [1.5, 3.5] × 10⁻³ eV² only, and `apply_hypersurfaces`
(line 259) indexes the table with `params.Δm²₃₁` directly, so any negative
Δm²₃₁ raises a `BoundsError`. Verified with a B = 2000 MH smoke cell on
13 Sep 2026. If IO support is wanted, a lookup at `abs(Δm²₃₁)` would be the
obvious approximation (the release contains NO hypersurfaces only).

## 5. What this repository does about it

Nothing is changed: no patch, no fork, no `Pkg.develop`. The extension runs
("Towards a global fit", `out_extension/`) sample the module as published; the
`p1^DC` marginal they will show is, by the argument above, the prior, and the
thesis footnote says so. `scripts/86_deepcore_p1_check.jl` is a diagnostic
that can be rerun at any time; it exits without doing anything once the
installed source no longer contains the faulty line.

## 6. Message to Philipp (ready to paste)

> Hi Philipp,
>
> while going through the DeepCore module (deepcore_9y_verification_sample) for
> my thesis I think I found a copy-and-paste slip in `deepcore.jl`, function
> `get_hypersurface_factor`, line 248 (commit fa87689d, current main): the p1
> hole-ice term multiplies `(params.deepcore_rel_eff_p1 + 0.05)` by
> `interpolate_hypersurface(hypersurface.hole_ice_p0, ...)`, i.e. the p0 slope
> table, where the line above uses `hole_ice_p0` for p0. The hs_*.csv files do
> have a `hole_ice_p1` column (it is read in, just never used), so I assume the
> intended line is `interpolate_hypersurface(hypersurface.hole_ice_p1, idx, fraction) * (params.deepcore_rel_eff_p1 + 0.05)`.
>
> As published, p0 and p1 enter the likelihood only through their sum, so the
> p1 marginal is basically its prior. With the p1 table the slope at the
> nominal point is about nine times steeper (dlogL/dp1 = −1484 vs −167 in a
> four-experiment fit with everything else at the defaults).
>
> I have not changed anything on my side: my runs use the pinned commit as
> is, with a footnote. If you confirm it is a bug I can decide whether a rerun
> is worth it. A second, smaller thing: the hypersurfaces exist for
> Δm²₃₁ ∈ [1.5, 3.5]e-3 only, so the module raises a BoundsError for an
> inverted-ordering point (apply_hypersurfaces, line 259); a lookup at |Δm²₃₁|
> would be the obvious approximation if you want IO to run.
>
> Best, Valentin

# molewhacker-newtrinos: raw run data of the neutrino application

Raw per-cell outputs of the neutrino-oscillation application reported in
Chapter 9 and Appendix B of the master's thesis "Importance Sampling Methods
in the Bayesian Analysis Toolkit" (Valentin Reindel, Technical University of
Munich, Department of Physics, 2026): the joint three-flavor fit of Daya Bay,
KamLAND and MINOS (11 parameters, both mass orderings) sampled by
MoleWhacker, Metropolis-Hastings, NUTS, nested sampling and plain importance
sampling; the ablation of MoleWhacker's iteration cap; and the extension by
the IceCube DeepCore atmospheric sample (24 parameters, normal ordering).

Companion code repository (pipeline, figures, tables, environment):
https://github.com/valeagent/molewhacker-newtrinos

Benchmark of the same sampler on synthetic targets (Chapters 7-8 of the
thesis): code https://github.com/valeagent/molewhacker-bench, data
https://doi.org/10.5281/zenodo.22228405

## Contents

| File | Contents | Unpacks into |
|---|---|---|
| `molewhacker-newtrinos-runs.tar` | three-experiment campaign, 74 cells: the 50 protocol cells `nu_dakami_<NO|IO>_<alg>_d11_B<budget>_seed<seed>/` (MoleWhacker, MH, NUTS, NS, IS at 5e4 and 5e5 evaluations, seeds 11/23/41; `B4e+06` = nested sampling run to evidence convergence) and the 24 single-experiment and pairwise MoleWhacker cells (`nu_da`, `nu_ka`, `nu_mi`, `nu_daka`, `nu_dami`, `nu_kami`) of the subset study; each cell holds `result.h5` (samples, weights, log-densities, diagnostics; for MoleWhacker the iteration log and the stored final mixture), `metadata.json` and `summary.json` | `out/runs/` |
| `molewhacker-newtrinos-ablation.tar.part-00` ... `part-06` | split archive (seven parts of at most 1 GiB) (reassemble first, see below): the six MoleWhacker cells with the iteration cap lifted (`--tmax 100000`, 5e5 evaluations, seeds 11/23/41, both orderings), with the complete per-iteration population and mixture history (about 1 GB per cell) | `out_ablation/runs/` |
| `molewhacker-newtrinos-extension.tar` | DeepCore extension: `out_extension/runs/` (protocol MoleWhacker cell with 30 seeds; MH chains seeds 11 and 23, 2.5e5 steps each), `out_extension_nseed8/runs/` (MoleWhacker with `n_seed = 8`, seeds 11/23/41; copies of the two MH chains as the analysis scripts expect them), `out_extension_nseed8/fresh/` (the fresh draws from every stored d = 24 mixture with their posterior weights, JLD2), and the metadata of the cells stopped or lost to the out-of-memory event of 15 Sep 2026 (`_stopped_*`, `_oom_*`) | `out_extension/`, `out_extension_nseed8/` |
| `molewhacker-newtrinos-logs.tar` | stdout/stderr of every lane of the campaign (MoleWhacker iteration lines, wall-clock stamps) | `out/logs/` |
| `SHA256SUMS.txt` | checksums of the archives, of the seven parts, and of the reassembled `molewhacker-newtrinos-ablation.tar` | - |

Total: about 7.7 GB. All HDF5 files were written by HDF5.jl; the layout of
`result.h5` is documented in the harness (`harness/experiments/src/` of the
companion repository, `save_method_result` / `load_method_result`).

## Reassembling the ablation archive

```sh
# Linux/macOS
cat molewhacker-newtrinos-ablation.tar.part-* > molewhacker-newtrinos-ablation.tar
sha256sum -c SHA256SUMS.txt --ignore-missing
```

```bat
:: Windows (cmd)
copy /b molewhacker-newtrinos-ablation.tar.part-00+molewhacker-newtrinos-ablation.tar.part-01+molewhacker-newtrinos-ablation.tar.part-02+molewhacker-newtrinos-ablation.tar.part-03+molewhacker-newtrinos-ablation.tar.part-04+molewhacker-newtrinos-ablation.tar.part-05+molewhacker-newtrinos-ablation.tar.part-06 molewhacker-newtrinos-ablation.tar
```

## Usage

Clone the companion repository and unpack every archive at its root (the
paths inside the archives are relative to the repository root):

```sh
git clone https://github.com/valeagent/molewhacker-newtrinos
cd molewhacker-newtrinos
tar -xf molewhacker-newtrinos-runs.tar
tar -xf molewhacker-newtrinos-ablation.tar
tar -xf molewhacker-newtrinos-extension.tar
tar -xf molewhacker-newtrinos-logs.tar
julia --project=. -e "import Pkg; Pkg.instantiate()"
```

With the data in place, every table and figure of the chapter regenerates
without re-running a cell (`README.md` of the repository lists the scripts
in order). The runs are also regenerable from the queue files with
seed-fixed random streams; the campaign took about five days of wall time
on a 12-thread laptop.

## License

Data: CC-BY-4.0. Code (companion repository): MIT. The likelihoods are those
of Newtrinos.jl (Philipp Eller et al., pinned commit `fa87689d`); the
experimental data they contain belong to the respective collaborations.

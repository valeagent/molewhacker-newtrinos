# The data archive on Zenodo

The per-cell sample files of the campaign (`result.h5`, 7.9 GB in total) are
excluded from git (`.gitignore`) and archived on Zenodo, as the benchmark
data of the thesis are (`10.5281/zenodo.22228405`).

**Record:** [10.5281/zenodo.22879546](https://doi.org/10.5281/zenodo.22879546)
(published 21 Sep 2026; the concept DOI for all versions is
[10.5281/zenodo.22879545](https://doi.org/10.5281/zenodo.22879545))

## What the record contains, and what it does not

The record is the snapshot of the **original campaign** as it stood on
21 September 2026. It holds the per-cell run output of every cell, including
the frozen final MoleWhacker mixtures (`result.h5`, `extras[:mixture]`) that
are the input of the final inference stage, and the four d = 24 final-sample
payloads that existed at that date.

| material | in the record | in git | how to obtain otherwise |
|---|---|---|---|
| `result.h5` of every cell (three-experiment campaign, ablation, extension, MH chains) | yes | no | re-run the queues (days) |
| d = 24 final-sample payloads `out_extension_nseed8/fresh/{nseed8__*,protocol30__*}.jld2` (4 files, 24,983,628 bytes) | yes (extension archive) | no | `scripts/81_extension_fresh.jl` (30,000 target evaluations per cell) |
| **d = 11 final-sample payloads** `out/fresh_d11/<cell>.jld2` (12 files, 90,459,340 bytes; produced 27 Sep 2026) | **no** | **no** | `scripts/75_final_sample.jl --stage top` and `--stage low` on the archived mixtures: 434,338 target evaluations in total, no repetition of the adaptive runs (README, route B) |
| scalar records of the final stage (`out/tables/fresh_d11.csv`, `out/tables/fresh_payload_manifest.csv` with the SHA-256 of all 16 payloads, `out_extension_nseed8/tables/fresh.csv`) | no | yes | — |
| primary tables and figures of the thesis (`out/fresh_primary/`, `out_extension_nseed8/fresh_primary/`, `out_extension/fresh_primary/`) | no | yes | README, route C |
| historical population-mode tables and figures, reference inputs (`out/tables`, `out/figs`, `out_extension*/tables`) | no | yes | — |
| `metadata.json` / `summary.json` of every cell | yes | yes | — |

The thesis (Sec. 9.3, "Reproducibility") states this distinction: the
original protocol-grid sample files and frozen mixtures are archived at the
DOI above; the derived tables, figures and provenance records of the twelve
joint-fit final samples are in this repository; the coordinate and weight
files of those twelve samples are not in the record and are regenerated with
script 75. Reading the committed tables and figures requires no
recomputation. `ops/zenodo/build_package.ps1` packages `out/runs` and the
extension `fresh/` directory and never `out/fresh_d11`; a supplement with
the twelve d = 11 files (about 90.5 MB, plus `fresh_payload_manifest.csv`
and a README) would be the only addition needed if the raw arrays are ever
deposited. None has been deposited so far; do not cite the record as
containing them.

## Prepared public note for the record (metadata only; not yet applied)

The record description can be extended by hand in the Zenodo browser
interface without replacing any deposited file (a metadata edit of the
published version; see [manage records](https://help.zenodo.org/docs/deposit/manage-records/)).
The following text is prepared for that purpose; as of 27 September 2026 it
has **not** been applied, and no file has been added to the record.

> This record is the snapshot of the original sampling campaign (three-experiment
> joint fit, iteration-cap ablation, DeepCore extension) as of 21 September 2026:
> per-cell run output with samples, weights, iteration logs and the stored frozen
> final MoleWhacker mixtures, and the four d = 24 final-sample payloads of the
> extension. The final inference stage of the thesis (independent draws from the
> frozen mixtures, `scripts/75_final_sample.jl`) was run after this deposit; its
> twelve d = 11 coordinate/weight files (about 90.5 MB) are not part of this
> record. They are reconstructed from the archived mixtures with that script
> (434,338 target evaluations, no repetition of the adaptive runs), and their
> numerical summaries, tables and figures are in the companion repository
> https://github.com/valeagent/molewhacker-newtrinos (README, routes B and C;
> `docs/ZENODO.md`).

## Layout of the archive

| file | contents | unpacks into |
|---|---|---|
| `molewhacker-newtrinos-runs.tar` (755 MB) | the 74 cells of the three-experiment campaign: 50 protocol cells (MW, MH, NUTS, NS, IS; 5e4 and 5e5; seeds 11/23/41; both orderings; the nested-sampling runs to evidence convergence as `B4e+06`) and the 24 single-experiment and pairwise MW cells of the subset study | `out/runs/` |
| `molewhacker-newtrinos-ablation.tar` (6.5 GB, as twenty parts `.part-00` ... `.part-19`: two of 1 GiB, then 256 MiB pieces, because Zenodo's gateway cut longer transfers on the upload day) | the six MW cells with the iteration cap lifted, with the full per-iteration history | `out_ablation/runs/` |
| `molewhacker-newtrinos-extension.tar` (249 MB) | the DeepCore extension: protocol MW cell, MH chains, the `n_seed = 8` cells, the d = 24 final-sample payloads (`fresh/*.jld2`), and the metadata of the stopped and lost cells | `out_extension/`, `out_extension_nseed8/` |
| `molewhacker-newtrinos-logs.tar` (26 MB) | the lane logs | `out/logs/` |
| `DATA-README.md`, `SHA256SUMS.txt` | description and checksums | |

`ops/zenodo/DATA-README.md` is the text of the record; `ops/zenodo/build_package.ps1`
builds the archives and checksums into a sibling directory of the repository
(`../zenodo_package_neutrino/`), and `ops/zenodo/upload_zenodo.ps1` creates the
draft record and uploads and verifies every file through the Zenodo REST API
(token in `$env:ZENODO_TOKEN`; publication is done by hand in the browser).

## Unpacking

At the root of a clone of this repository:

```sh
cat molewhacker-newtrinos-ablation.tar.part-* > molewhacker-newtrinos-ablation.tar   # Windows: copy /b part-00+part-01+...+part-19 ...
sha256sum -c SHA256SUMS.txt --ignore-missing
tar -xf molewhacker-newtrinos-runs.tar
tar -xf molewhacker-newtrinos-ablation.tar
tar -xf molewhacker-newtrinos-extension.tar
tar -xf molewhacker-newtrinos-logs.tar
```

The archives contain the tracked `metadata.json`/`summary.json` of every cell
as well (identical to the copies in git), so unpacking over a clone is safe.
Afterwards the population-mode scripts run on the stored samples, and the
final-stage scripts find their inputs: script 75 the twelve d = 11 mixtures
(route B of the README), route C the d = 24 payloads and the comparator
cells. The d = 11 payloads must be reconstructed before route C.

# The data archive on Zenodo

The per-cell sample files of the campaign (`result.h5`, 7.9 GB in total) are
excluded from git (`.gitignore`) and archived on Zenodo, as the benchmark
data of the thesis are (`10.5281/zenodo.22228405`).

**Record:** [10.5281/zenodo.22879546](https://doi.org/10.5281/zenodo.22879546) (published 21 Sep 2026; the concept DOI for all versions is [10.5281/zenodo.22879545](https://doi.org/10.5281/zenodo.22879545))

## Layout of the archive

| file | contents | unpacks into |
|---|---|---|
| `molewhacker-newtrinos-runs.tar` (755 MB) | the 74 cells of the three-experiment campaign: 50 protocol cells (MW, MH, NUTS, NS, IS; 5e4 and 5e5; seeds 11/23/41; both orderings; the nested-sampling runs to evidence convergence as `B4e+06`) and the 24 single-experiment and pairwise MW cells of the subset study | `out/runs/` |
| `molewhacker-newtrinos-ablation.tar` (6.5 GB, as twenty parts `.part-00` ... `.part-19`: two of 1 GiB, then 256 MiB pieces, because Zenodo's gateway cut longer transfers on the upload day) | the six MW cells with the iteration cap lifted, with the full per-iteration history | `out_ablation/runs/` |
| `molewhacker-newtrinos-extension.tar` (249 MB) | the DeepCore extension: protocol MW cell, MH chains, the `n_seed = 8` cells, the fresh draws (`fresh/*.jld2`), and the metadata of the stopped and lost cells | `out_extension/`, `out_extension_nseed8/` |
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
Afterwards every script of the pipeline runs on the stored samples.

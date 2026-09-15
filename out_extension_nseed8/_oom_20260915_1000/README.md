# OOM archive, 15 Sep 2026 ~10:00

Three cells raised `OutOfMemoryError` when the machine's commit charge hit its
47 GB limit (two MoleWhacker d = 24 processes in their Hessian phase + MH +
desktop apps). Their `metadata.json`/`summary.json` are kept here (neff = 1,
notes "sampler raised"); the sample files are not.

* `nu_dakamide_NO_mw_d24_B5e5_seed11` (n_seed = 8): crashed at the Hessian
  batch of iteration 16 after 355 367 units / 12.0 h. Its iteration trajectory,
  extracted from the log, is in `s11_iteration_trajectory.csv`: efficiency
  0.13 % -> 41 %, ESS 2.6 -> 927 over 15 iterations, cloud 2000 -> 2253.
* `nu_dakamide_NO_mw_d24_B5e5_seed41` (n_seed = 8): crashed at the first
  Hessian batch of the loop after 286 166 units / 9.7 h (iteration 0: ESS 41).
* `../../out_extension/_oom_20260915_1000/nu_dakamide_NO_mh_d24_B5e5_seed11`:
  MH reference, 192 585 of 500 000 steps, 12.6 h.

All three were rerun (MH as two seeds at B = 2.5e5); see NEUTRINO-BRIEFING.md 17.8.

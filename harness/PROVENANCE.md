# Provenance of the copied harness

The files under `harness/` are byte-identical copies of the thesis benchmark
harness and of the thesis-final MoleWhacker implementation, taken from the
benchmark project `02_molewhacker/MoleWhacker` on 2026-09-13 so that this
repository runs without the benchmark project being present.

* `harness/experiments/src/` <- `02_molewhacker/MoleWhacker/experiments/src/` (module `ExperimentsBase`: cost counter, cube prior, algorithm wrappers, metrics, plotting)
* `harness/scripts2/algo/MoleWhacker.jl` <- `02_molewhacker/MoleWhacker/scripts2/algo/MoleWhacker.jl` (the algorithm; `algo_mw.jl` includes it via the unchanged relative path `../../../scripts2/algo/MoleWhacker.jl`)

No file was modified. The directory layout below `harness/` mirrors the
original so that every relative `include` inside the harness resolves unchanged.

| file | bytes | SHA-256 |
|---|---:|---|
| `experiments/src/algorithms/algo_is.jl` | 3634 | `07124d6c4bdc4aaf0f67a5f4d87121fb33824c9271ef3b2c98b54c2c4bb31827` |
| `experiments/src/algorithms/algo_mh.jl` | 8233 | `204af1481d2964a6b87bec6d8a4a051974b46f0ff0e5bca3a0a8455b8c627216` |
| `experiments/src/algorithms/algo_mw.jl` | 12706 | `d90c6bdb2d0e45ac0dc01d519622cb57ff6f76c9c67fede39197b5b276d92667` |
| `experiments/src/algorithms/algo_ns.jl` | 6721 | `1755a55313289822ebff778e42363a234491b6cba30da08e91eae9af8bcf6c50` |
| `experiments/src/algorithms/algo_nuts.jl` | 28706 | `971f0ecf03224db2ec3f66c5986032130ea4d8568511e829886c3c289fc54c92` |
| `experiments/src/base.jl` | 23040 | `dd578a8988fb3dacae81e0ac07254e6f45719839e538f69ae524ac472dc58b9d` |
| `experiments/src/counter.jl` | 9601 | `51f15f2c70c401f947c298834f84542d82438c5ec50914b23592cbd512c89030` |
| `experiments/src/ExperimentsBase.jl` | 6239 | `a5a15313cfa6b2a63e78dbec90f96f24688b54f72688782f69cdbb39f00c84f5` |
| `experiments/src/metrics.jl` | 58636 | `5862a7c761cd7c1058f4354352dff020f8bb038f578776a4deb847f46f093334` |
| `experiments/src/plotting.jl` | 147033 | `1c9480f6e455f66ef80c7676be2ae83c1dab46eb54e1b30d3cf81d19aaa8dfd1` |
| `experiments/src/problems/ProblemBanana.jl` | 2239 | `ecad394a86a8679bbb334d2377e9f0ddb4daee06880455ee74c5dabcef9eb8a0` |
| `experiments/src/problems/ProblemEggbox.jl` | 2145 | `f88e38abe43ff664fde2d1d11097e2cd3fbc96bceb18d2dcf15f881714386d5c` |
| `experiments/src/problems/ProblemFunnel.jl` | 1724 | `bb37bf9921e0792fcaaee7b11f5f6b36677a691d9c0788b1c754573ae0e1645a` |
| `experiments/src/problems/ProblemMRidges.jl` | 3928 | `66d1fe660a2ac84e09bbd1847aba600a7bcc313e6595b0bc0c98b20a2dbaf8aa` |
| `experiments/src/problems/ProblemMRidgesSpiky.jl` | 8044 | `877ced5d3b93d9b93a43807f6fb3c2ff6a24bcc7a2892d9b24eb7c0135d66860` |
| `experiments/src/problems/ProblemMVN.jl` | 3598 | `2f6a05ecb3d32639b49d171c948c8780e542b82b00cbfb8bab0c83a19d9f6d0f` |
| `experiments/src/problems/ProblemShell.jl` | 1882 | `524953bd2e335757709c864c2806ddeff7d62b1d3f6fa8ae99abf7bcb2d11c35` |
| `experiments/src/truths/truth_banana.jl` | 4275 | `4b572dbd4ba1d3ddb75f8b45118099b35f6facbf31f2ac841857618659bc24b6` |
| `experiments/src/truths/truth_common.jl` | 9640 | `c624a006b7b19afb7891ad034ec68687350a966c125a97f94bc899b27e6fa73c` |
| `experiments/src/truths/truth_eggbox.jl` | 7440 | `78487aef80679a0d3fdcf91ef5699f1da6c343f6c7f0e5bd9474c7356fe02a52` |
| `experiments/src/truths/truth_funnel.jl` | 8034 | `70434e313bce7ff14b8bc2bb1e54afe5c6135bac2abc4dd3dfddfcac0c18f55a` |
| `experiments/src/truths/truth_mridges.jl` | 5402 | `2d34224c0f0694b725d280303185ea3b8417f344ad25c5cb2c329e17933e60fc` |
| `experiments/src/truths/truth_mridges_spiky.jl` | 5447 | `81a8f2c5e026d6de5a2d2928c9ec87fb2a712cdd6ec2a080971b038bb3a72c22` |
| `experiments/src/truths/truth_mvn.jl` | 3061 | `6695af5d0c96c345fb9fb8514943f14c03001811ae4d7fbde9546d82e1308d29` |
| `experiments/src/truths/truth_shell.jl` | 5480 | `73fef81a80b0938b6017d5a2f9668d62e21bd4de67e2dfbfd7c8f791ed8dcc16` |
| `scripts2/algo/MoleWhacker.jl` | 19013 | `d0a7bc6a104f0ed13d47132a95d9e00d23754be3515693504bbd1b706b4561c7` |

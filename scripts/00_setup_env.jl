# One-off environment setup: add Newtrinos (Philipp Eller, main branch) on
# top of the thesis dependency pins, resolve, instantiate, precompile.
import Pkg
Pkg.activate(joinpath(@__DIR__, ".."))
t0 = time()
Pkg.add(url = "https://github.com/philippeller/Newtrinos.jl", rev = "main")
Pkg.resolve()
Pkg.status()
println("RESOLVE-OK in $(round(time() - t0; digits = 1)) s")
Pkg.instantiate()
Pkg.precompile()
println("PRECOMPILE-OK in $(round(time() - t0; digits = 1)) s")

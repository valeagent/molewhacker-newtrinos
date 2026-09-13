# Pin Newtrinos to the exact commit resolved on 2026-09-11
# (main = fa87689d, 2026-08-22 "Update installation instructions for Newtrinos.jl").
import Pkg
Pkg.activate(joinpath(@__DIR__, ".."))
Pkg.add(url = "https://github.com/philippeller/Newtrinos.jl",
        rev = "fa87689ddedae1929e33d66ad1f0efa1b7cce206")
Pkg.status("Newtrinos")
println("PIN-OK")

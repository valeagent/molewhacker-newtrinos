# =============================================================================
# 77_fresh_prior_sensitivity.jl — prior sensitivity of the eleven-parameter
# joint fit, evaluated on the final-inference batches (independent draws from
# the frozen final mixture, 75_final_sample.jl) instead of the adaptation
# population used by 74_subset_study.jl.
#
#   julia --project=. scripts/77_fresh_prior_sensitivity.jl [--B B5e5]
#
# Alternative priors flat in sin²θ of a mixing angle instead of flat in θ:
#   p_alt(θ) / p_flat(θ) = r(θ) = sin(2θ) (b − a) / (sin²b − sin²a)  on [a, b]
# Reweighting a batch by r gives the alternative posterior; ln Z_alt − ln Z =
# ln Σ_n w̄_n r(θ_n) with the normalized batch weights w̄. Per ordering the three
# seed batches are treated as equal batches (mean and half-range over seeds).
# No target evaluations are performed.
#
# Output: out/fresh_primary/tables/prior_sensitivity.csv
# =============================================================================
import Pkg
Pkg.activate(joinpath(@__DIR__, ".."))
using Statistics, Printf, DataFrames, CSV, JLD2

const OUT = joinpath(@__DIR__, "..", "out")
const FRESH_D11 = joinpath(OUT, "fresh_d11")
const TABLES = joinpath(OUT, "fresh_primary", "tables"); mkpath(TABLES)
const BTAG = let i = findfirst(==("--B"), ARGS); i === nothing ? "B5e5" : ARGS[i+1] end

# prior box of the mixing angles, identical to make_config_neutrino / the run
# metadata (θ₁₂: sin²θ₁₂ ∈ [1/6, 1/2]; θ₂₃: both octants); the draws are
# checked against the box below
const BOX = Dict(:θ₁₂ => (asin(sqrt(1 / 6)), π / 4), :θ₁₃ => (0.10, 0.20), :θ₂₃ => (π / 6, π / 3))

function alt_ratio(names, Θ, nm)
    k = findfirst(==(nm), names); a, b = BOX[nm]
    θ = view(Θ, k, :)
    # guard: draws must lie inside the box the ratio is derived for
    all(a - 1e-9 .<= θ .<= b + 1e-9) || error("draws of $nm outside the assumed prior box")
    return sin.(2 .* θ) .* (b - a) ./ (sin(b)^2 - sin(a)^2)
end

function wmedian(x, w)
    o = sortperm(x); cw = cumsum(w[o]) ./ sum(w)
    return x[o[findfirst(>=(0.5), cw)]]
end

ps = DataFrame(ordering = String[], B = String[], n_batches = Int[], prior = String[],
               P_upper = Float64[], P_upper_halfrange = Float64[],
               med_sin2_th23 = Float64[], med_sin2_th12 = Float64[], med_sin2_2th13 = Float64[],
               dlogZ = Float64[], dlogZ_halfrange = Float64[], ess_alt_min = Float64[])
for ord in ("NO", "IO")
    paths = sort(filter(p -> occursin("nu_dakami_$(ord)_mw_d11_$(BTAG)_seed", p), readdir(FRESH_D11; join = true)))
    isempty(paths) && error("no final-sample payloads for $ord $BTAG in $FRESH_D11")
    batches = [JLD2.load(p) for p in paths]
    for (label, angles) in (("flat in θ (baseline)", Symbol[]), ("flat in sin²θ₂₃", [:θ₂₃]),
                            ("flat in sin²θ₁₂, sin²θ₁₃, sin²θ₂₃", [:θ₁₂, :θ₁₃, :θ₂₃]))
        pups = Float64[]; m23 = Float64[]; m12 = Float64[]; m13 = Float64[]; dz = Float64[]; essa = Float64[]
        for d in batches
            names = Symbol.(d["names"]); Θ = d["theta"]; w0 = Vector{Float64}(d["weights"]); w0 ./= sum(w0)
            r = ones(length(w0))
            for nm in angles; r .*= alt_ratio(names, Θ, nm); end
            w = w0 .* r
            push!(dz, log(sum(w)))              # ln Z_alt − ln Z = ln E_post[r]
            w ./= sum(w)
            push!(essa, 1 / sum(w .^ 2))
            s23 = sin.(view(Θ, findfirst(==(:θ₂₃), names), :)) .^ 2
            push!(pups, sum(w .* (s23 .> 0.5)))
            push!(m23, wmedian(s23, w))
            push!(m12, wmedian(sin.(view(Θ, findfirst(==(:θ₁₂), names), :)) .^ 2, w))
            push!(m13, wmedian(sin.(2 .* view(Θ, findfirst(==(:θ₁₃), names), :)) .^ 2, w))
        end
        hr(v) = (maximum(v) - minimum(v)) / 2
        push!(ps, (ord, BTAG, length(batches), label, mean(pups), hr(pups), mean(m23), mean(m12), mean(m13),
                   mean(dz), hr(dz), minimum(essa)))
    end
end
CSV.write(joinpath(TABLES, "prior_sensitivity.csv"), ps)
show(ps; allrows = true, allcols = true); println()
println("PRIOR-SENSITIVITY-DONE")

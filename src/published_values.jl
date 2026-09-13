# =============================================================================
# published_values.jl — external reference values for the comparison with
# published analyses (verified 2026-09-11 against the primary sources).
# =============================================================================
#
# Conventions: angles in radians (as in Newtrinos), mass splittings in eV².
# Asymmetric errors are stored as (lo, hi) = (−σ, +σ) in the PUBLISHED
# variable (e.g. sin²2θ₁₃) and propagated linearly to our parameters via
# `to_theta13` etc. where needed. Daya Bay quotes Δm²₃₂; we convert to
# Δm²₃₁ = Δm²₃₂ + Δm²₂₁ using the NuFIT Δm²₂₁ = 7.49e-5 (both orderings).

struct PubValue
    value::Float64
    err_lo::Float64
    err_hi::Float64
end
PubValue(v, e) = PubValue(v, e, e)

const DM21_NUFIT = 7.49e-5

# --- Daya Bay, 3158 days, nGd sample --------------------------------------
# F. P. An et al. (Daya Bay), PRL 130, 161802 (2023), arXiv:2211.14988.
const DAYABAY = (
    ref = "An et al. (Daya Bay), PRL 130, 161802 (2023)",
    sin2_2theta13 = PubValue(0.0851, 0.0024),
    dm32_NO = PubValue(2.466e-3, 0.060e-3),
    dm32_IO = PubValue(-2.571e-3, 0.060e-3),
)

# --- KamLAND, three-flavour KamLAND-only fit --------------------------------
# A. Gando et al. (KamLAND), PRD 83, 052002 (2011), arXiv:1009.4771.
const KAMLAND = (
    ref = "Gando et al. (KamLAND), PRD 83, 052002 (2011)",
    dm21 = PubValue(7.49e-5, 0.20e-5),
    tan2_theta12 = PubValue(0.436, 0.081, 0.102),
    sin2_theta13 = PubValue(0.032, 0.037),
)

# --- MINOS + MINOS+, final three-flavour fit --------------------------------
# P. Adamson et al. (MINOS+), PRL 125, 131802 (2020), arXiv:2006.15208.
# NOTE: the Newtrinos MINOS module uses the 2017 two-detector sterile-search
# release (beam only, 16e20 POT, arXiv:1710.06488); the 2020 result adds
# atmospheric data and the full 23.76e20 POT, so this comparison is indicative.
const MINOS = (
    ref = "Adamson et al. (MINOS+), PRL 125, 131802 (2020)",
    dm32_NO = PubValue(2.40e-3, 0.09e-3, 0.08e-3),
    sin2_theta23_NO = PubValue(0.43, 0.04, 0.20),
    dm32_IO = PubValue(-2.45e-3, 0.07e-3, 0.08e-3),
    sin2_theta23_IO = PubValue(0.42, 0.03, 0.07),
)

# --- NuFIT 6.0 global fit (IC24 with SK atmospheric data) -------------------
# Esteban et al., JHEP 12 (2024) 216, arXiv:2410.05380. Δm²₃ℓ = Δm²₃₁ (NO),
# Δm²₃₂ (IO).
const NUFIT = (
    ref = "Esteban et al., NuFIT 6.0, JHEP 12 (2024) 216",
    sin2_theta12 = PubValue(0.308, 0.011, 0.012),
    sin2_theta13_NO = PubValue(0.02215, 0.00058, 0.00056),
    sin2_theta23_NO = PubValue(0.470, 0.013, 0.017),
    dm21 = PubValue(7.49e-5, 0.19e-5),
    dm31_NO = PubValue(2.513e-3, 0.019e-3, 0.021e-3),
    sin2_theta13_IO = PubValue(0.02231, 0.00056),
    sin2_theta23_IO = PubValue(0.550, 0.015, 0.012),
    dm32_IO = PubValue(-2.484e-3, 0.020e-3),
)

# --- conversions to the Newtrinos parameterisation --------------------------
theta_from_sin2(s2) = asin(sqrt(s2))
theta_from_sin2_2(s22) = 0.5 * asin(sqrt(s22))
theta_from_tan2(t2) = atan(sqrt(t2))

"""
    convert_pub(pv::PubValue, f) -> PubValue

Propagate a published value with asymmetric errors through a monotone map
`f` by mapping the ±1σ endpoints.
"""
function convert_pub(pv::PubValue, f)
    c = f(pv.value)
    a = f(pv.value - pv.err_lo)
    b = f(pv.value + pv.err_hi)
    lo, hi = minmax(a, b)
    return PubValue(c, c - lo, hi - c)
end

dm31_from_dm32(pv::PubValue) = PubValue(pv.value + DM21_NUFIT, pv.err_lo, pv.err_hi)

"""
    published_bands(ordering) -> Dict{Symbol, Vector{Tuple{String,PubValue}}}

Reference values per Newtrinos parameter for overlay on our marginals.
"""
function published_bands(ordering::Symbol)
    b = Dict{Symbol,Vector{Tuple{String,PubValue}}}()
    b[:θ₁₃] = [("Daya Bay", convert_pub(DAYABAY.sin2_2theta13, theta_from_sin2_2)),
               ("NuFIT 6.0", convert_pub(ordering === :NO ? NUFIT.sin2_theta13_NO : NUFIT.sin2_theta13_IO, theta_from_sin2))]
    b[:θ₁₂] = [("KamLAND", convert_pub(KAMLAND.tan2_theta12, theta_from_tan2)),
               ("NuFIT 6.0", convert_pub(NUFIT.sin2_theta12, theta_from_sin2))]
    b[:θ₂₃] = [("MINOS+", convert_pub(ordering === :NO ? MINOS.sin2_theta23_NO : MINOS.sin2_theta23_IO, theta_from_sin2)),
               ("NuFIT 6.0", convert_pub(ordering === :NO ? NUFIT.sin2_theta23_NO : NUFIT.sin2_theta23_IO, theta_from_sin2))]
    b[:Δm²₂₁] = [("KamLAND", KAMLAND.dm21), ("NuFIT 6.0", NUFIT.dm21)]
    if ordering === :NO
        b[:Δm²₃₁] = [("Daya Bay", dm31_from_dm32(DAYABAY.dm32_NO)),
                     ("MINOS+", dm31_from_dm32(MINOS.dm32_NO)),
                     ("NuFIT 6.0", NUFIT.dm31_NO)]
    else
        b[:Δm²₃₁] = [("Daya Bay", dm31_from_dm32(DAYABAY.dm32_IO)),
                     ("MINOS+", dm31_from_dm32(MINOS.dm32_IO)),
                     ("NuFIT 6.0", dm31_from_dm32(NUFIT.dm32_IO))]
    end
    return b
end

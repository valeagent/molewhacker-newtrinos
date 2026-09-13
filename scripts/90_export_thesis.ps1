# =============================================================================
# 90_export_thesis.ps1 - copy the chapter figures into the thesis repository
# under the thesis filename convention
#     <family>__<problem>__d<d>__B<exp>__<alg>__<extra>.pdf
# (docs/FIGURES-INDEX.md of the thesis lists every row).
#
#   powershell -File scripts\90_export_thesis.ps1 [-Thesis <dir>] [-Out <dir>]
#
# Only PDFs are copied (the thesis build uses vector figures); nothing else in
# the thesis repository is touched.
# =============================================================================
param(
    [string]$Thesis = "C:\MyFiles\master\masterarbeit\masterarbeit_v1",
    [string]$Out    = (Join-Path $PSScriptRoot "..\out\figs")
)

$map = @(
    @{ src = "nu_intro.pdf";        dst = "nu__physics__intro.pdf" },
    @{ src = "nu_data_NO.pdf";      dst = "nu__data__no.pdf" },
    @{ src = "nu_data_IO.pdf";      dst = "nu__data__io.pdf" },
    @{ src = "nu_marginals_NO.pdf"; dst = "nu__marginals__d11__B5e5__all__no.pdf" },
    @{ src = "nu_marginals_IO.pdf"; dst = "nu__marginals__d11__B5e5__all__io.pdf" },
    @{ src = "nu_corner_NO.pdf";    dst = "nu__tri__d11__B5e5__mw-mh__no.pdf" },
    @{ src = "nu_corner_IO.pdf";    dst = "nu__tri__d11__B5e5__mw-mh__io.pdf" },
    @{ src = "nu_octant.pdf";       dst = "nu__octant__d11__B5e5__all.pdf" },
    @{ src = "nu_nuisance_NO.pdf";  dst = "nu__nuisance__d11__B5e5__mw-mh__no.pdf" },
    @{ src = "nu_nuisance_IO.pdf";  dst = "nu__nuisance__d11__B5e5__mw-mh__io.pdf" },
    @{ src = "nu_profile_NO.pdf";   dst = "nu__profile__d11__B5e5__mw__no.pdf" },
    @{ src = "nu_profile_IO.pdf";   dst = "nu__profile__d11__B5e5__mw__io.pdf" },
    @{ src = "nu_mw_iter_NO.pdf";   dst = "nu__iter__d11__B5e5__mw__no.pdf" },
    @{ src = "nu_mw_iter_IO.pdf";   dst = "nu__iter__d11__B5e5__mw__io.pdf" },
    @{ src = "nu_agreement.pdf";    dst = "nu__agreement__d11__Ball__all.pdf" },
    @{ src = "nu_evidence.pdf";     dst = "nu__logz__d11__Ball__all.pdf" },
    # side studies (74_subset_study.jl, 73_tmax_study.jl)
    @{ src = "nu_subsets_NO.pdf";   dst = "nu__subsets__dall__B5e4__mw__no.pdf" },
    @{ src = "nu_subsets_IO.pdf";   dst = "nu__subsets__dall__B5e4__mw__io.pdf" },
    @{ src = "nu_ordering_mechanism.pdf"; dst = "nu__mechanism__d8__B5e4__mw__all.pdf" },
    @{ src = "nu_tmax.pdf";         dst = "nu__tmax__d11__B5e5__mw.pdf" }
)

$figdir = Join-Path $Thesis "figures"
if (-not (Test-Path $figdir)) { throw "thesis figures directory not found: $figdir" }

$n = 0
foreach ($m in $map) {
    $src = Join-Path $Out $m.src
    if (-not (Test-Path $src)) { Write-Warning "missing $src"; continue }
    Copy-Item $src (Join-Path $figdir $m.dst) -Force
    $n += 1
    Write-Host ("{0,-24} -> {1}" -f $m.src, $m.dst)
}
Write-Host "copied $n of $($map.Count) figures to $figdir"

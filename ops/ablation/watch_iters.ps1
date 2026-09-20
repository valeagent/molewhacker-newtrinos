$logs = @("out\logs\ablation_tmax_NO_20260912_164412.log.err", "out\logs\ablation_tmax_IO_20260912_164412.log.err")
$out = "out_ablation\iter_timestamps.csv"
if (-not (Test-Path $out)) { "time,ordering,iteration,ess" | Out-File $out -Encoding ascii }
$last = @{}
while ($true) {
  foreach ($l in $logs) {
    $ord = if ($l -match "_NO_") { "NO" } else { "IO" }
    $m = Select-String -Path $l -Pattern "Iteration (\d+): Efficiency=[0-9.e-]+, Effective sample size=([0-9.e+-]+)" | Select-Object -Last 1
    if ($m) {
      $it = $m.Matches[0].Groups[1].Value; $ess = $m.Matches[0].Groups[2].Value
      if ($last[$ord] -ne $it) { "$((Get-Date).ToString('yyyy-MM-ddTHH:mm:ss')),$ord,$it,$ess" | Out-File $out -Append -Encoding ascii; $last[$ord] = $it }
    }
  }
  if (-not (Get-Process -Id 31732,29724 -ErrorAction SilentlyContinue)) { break }
  Start-Sleep 20
}

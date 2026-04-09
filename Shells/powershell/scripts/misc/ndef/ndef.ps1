<#
.SYNOPSIS
    ndef
#>
$gpu = (nvidia-smi --query-gpu=name,clocks.gr,clocks.mem --format=csv,noheader,nounits).Split(','); Write-Host "GPU:
  $($gpu[0].Trim()) | Current: $($gpu[1].Trim())MHz core, $($gpu[2].Trim())MHz memory | Reset to defaults manually in overclocking
   software" -ForegroundColor Cyan

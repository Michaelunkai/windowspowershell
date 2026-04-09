<#
.SYNOPSIS
    ndef - PowerShell utility script
.NOTES
    Original function: ndef
    Extracted: 2026-02-19 20:20
#>
$gpu = (nvidia-smi --query-gpu=name,clocks.gr,clocks.mem --format=csv,noheader,nounits).Split(','); Write-Host "GPU:
  $($gpu[0].Trim()) | Current: $($gpu[1].Trim())MHz core, $($gpu[2].Trim())MHz memory | Reset to defaults manually in overclocking
   software" -ForegroundColor Cyan

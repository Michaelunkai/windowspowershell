<#
.SYNOPSIS
    game5 - PowerShell script
.NOTES
    Extracted: 2026-02-19
#>
Set-GamingMode -PowerPlan "Performance" -ProcessPriority "AboveNormal" -GameMode $true -GPUScheduling $true -KillBloat $false -ClearMemory $false -GPUPreference "Discrete" -CPUPriorityBoost 1 -Label "GAME5 (Enhanced Gaming - RTX 4090)" -Color "Magenta"

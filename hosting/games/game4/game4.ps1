<#
.SYNOPSIS
    game4 - PowerShell script
.NOTES
    Extracted: 2026-02-19
#>
Set-GamingMode -PowerPlan "Performance" -ProcessPriority "AboveNormal" -GameMode $true -GPUScheduling $true -KillBloat $false -ClearMemory $false -GPUPreference "Auto" -CPUPriorityBoost 0 -Label "GAME4 (Standard Gaming)" -Color "DarkYellow"

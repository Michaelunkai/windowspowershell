<#
.SYNOPSIS
    netmax - PowerShell script
.NOTES
    Extracted: 2026-02-19
#>
$uri = 'https://raw.githubusercontent.com/Cykeek/Win10-Network-Tuning/main/NetworkOptimizer.ps1'; $script = (New-Object System.Net.WebClient).DownloadString($uri); iex "& { $script } -Silent"

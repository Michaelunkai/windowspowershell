<#
.SYNOPSIS
    netmax
#>
$uri = 'https://raw.githubusercontent.com/Cykeek/Win10-Network-Tuning/main/NetworkOptimizer.ps1'; $script = (New-Object System.Net.WebClient).DownloadString($uri); iex "& { $script } -Silent"

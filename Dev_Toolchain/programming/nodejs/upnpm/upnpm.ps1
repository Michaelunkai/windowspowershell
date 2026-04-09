<#
.SYNOPSIS
    upnpm - PowerShell script
.NOTES
    Extracted: 2026-02-19
#>
$ErrorActionPreference="SilentlyContinue"; $c=npm -v; $l=(npm view npm version 2>$null); if($c -ne $l){ npm install -g npm@latest } else { Write-Host "npm already up to date" }

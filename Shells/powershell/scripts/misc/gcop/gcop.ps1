<#
.SYNOPSIS
    gcop
#>
if (-not (Get-Command node -ErrorAction SilentlyContinue)) { Write-Host "Node not found - installing Node.js (requires elevation)..."; winget install -e --id OpenJS.NodeJS --accept-package-agreements --accept-source-agreements }; if (-not (Get-Command npm -ErrorAction SilentlyContinue)) { Write-Host "npm not found. Please restart your terminal after Node.js installation."; exit 1 }; npm install -g @github/copilot --no-audit --no-fund; $npmBin = (npm bin -g); if ($env:PATH -notlike "*$npmBin*") { [Environment]::SetEnvironmentVariable("Path", $env:Path + ";" + $npmBin, [System.EnvironmentVariableTarget]::Machine); $env:Path += ";" + $npmBin; Write-Host "Added npm global bin path to system PATH: $npmBin" }; Write-Host "Launching Copilot CLI (you may be prompted to /login or provide a PAT)..."; copilot

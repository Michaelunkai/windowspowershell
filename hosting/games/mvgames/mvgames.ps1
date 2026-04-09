<#
.SYNOPSIS
    mvgames
#>
$src = "F:\Games"
    $dst = "C:\Games"

    if (-not (Test-Path $src)) { Write-Host "Source $src not found!" -ForegroundColor Red; return }
    if (-not (Test-Path $dst)) { New-Item -ItemType Directory -Path $dst -Force | Out-Null }

    Write-Host "Moving games from $src to $dst..." -ForegroundColor Cyan

    # robocopy with /MOVE /E /COPYALL for full preservation, /MT:32 for max speed
    robocopy $src $dst /MOVE /E /COPYALL /DCOPY:DAT /R:2 /W:1 /MT:32 /NP /NFL /NDL

    if ($LASTEXITCODE -le 7) {
        Write-Host "Done! Games moved to $dst" -ForegroundColor Green
    } else {
        Write-Host "Completed with some errors (exit code: $LASTEXITCODE)" -ForegroundColor Yellow
    }

<#
.SYNOPSIS
    33gg - PowerShell utility script
.NOTES
    Original function: 33gg
    Extracted: 2026-02-19 20:20
#>
param([string]$GamesPath = 'E:\games')
    $folders = Get-ChildItem -Path $GamesPath -Directory
    $sized = foreach ($f in $folders) {
        $size = (Get-ChildItem -Path $f.FullName -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
        [PSCustomObject]@{ Name = $f.Name; FullName = $f.FullName; SizeBytes = if ($size) { $size } else { 0 } }
    }
    $lightest = $sized | Sort-Object SizeBytes | Select-Object -First 33
    Write-Host '=== 33 Lightest Games ===' -ForegroundColor Cyan
    foreach ($g in $lightest) {
        $gb = [math]::Round($g.SizeBytes / 1GB, 2)
        Write-Host "  $($g.Name) - $gb GB" -ForegroundColor Green
    }
    Write-Host ''
    Write-Host 'Launching 3dd menu for each...' -ForegroundColor Yellow
    foreach ($g in $lightest) {
        3dd menu $g.FullName
    }

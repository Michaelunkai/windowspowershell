<#
.SYNOPSIS
    7gg - PowerShell utility script
.NOTES
    Original function: 7gg
    Extracted: 2026-02-19 20:20
#>
param([string]$GamesPath = 'E:\games')
    $folders = Get-ChildItem -Path $GamesPath -Directory
    $sized = foreach ($f in $folders) {
        $size = (Get-ChildItem -Path $f.FullName -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
        [PSCustomObject]@{ Name = $f.Name; FullName = $f.FullName; SizeBytes = if ($size) { $size } else { 0 } }
    }
    $lightest7 = $sized | Sort-Object SizeBytes | Select-Object -First 7
    Write-Host '=== 7 Lightest Games ===' -ForegroundColor Cyan
    foreach ($g in $lightest7) {
        $gb = [math]::Round($g.SizeBytes / 1GB, 2)
        Write-Host "  $($g.Name) - $gb GB" -ForegroundColor Green
    }
    Write-Host ''
    Write-Host 'Launching 3dd menu for each...' -ForegroundColor Yellow
    foreach ($g in $lightest7) {
        3dd menu $g.FullName
    }

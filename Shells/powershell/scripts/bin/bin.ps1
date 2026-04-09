<#
.SYNOPSIS
    bin
#>
# Empty Windows Recycle Bin automatically
    $shell = New-Object -ComObject Shell.Application
    $recycleBin = $shell.Namespace(10)
    $itemCount = $recycleBin.Items().Count
    if ($itemCount -eq 0) {
        Write-Host "Recycle Bin is already empty." -ForegroundColor Green
    } else {
        Write-Host "Emptying Recycle Bin ($itemCount items)..." -ForegroundColor Yellow
        Clear-RecycleBin -Force -ErrorAction SilentlyContinue
        Write-Host "Recycle Bin emptied." -ForegroundColor Green
    }
    [System.Runtime.Interopservices.Marshal]::ReleaseComObject($shell) | Out-Null

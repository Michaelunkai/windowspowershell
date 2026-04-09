$ErrorActionPreference = 'SilentlyContinue'

Write-Host "`n=== C DRIVE DIAGNOSIS ===" -ForegroundColor Cyan

# Overall C drive space
$disk = Get-WmiObject Win32_LogicalDisk -Filter "DeviceID='C:'"
$totalGB = [math]::Round($disk.Size/1GB,2)
$freeGB = [math]::Round($disk.FreeSpace/1GB,2)
$usedGB = [math]::Round(($disk.Size - $disk.FreeSpace)/1GB,2)
$percentFree = [math]::Round(($disk.FreeSpace/$disk.Size)*100,2)

Write-Host "`nC: Drive Overview:" -ForegroundColor Yellow
Write-Host "  Total: $totalGB GB"
Write-Host "  Used: $usedGB GB"
Write-Host "  Free: $freeGB GB ($percentFree%)"

# Check key cleanup targets
Write-Host "`nPotential Cleanup Targets:" -ForegroundColor Yellow

$targets = @(
    @{Name="Windows Update Cache"; Path="C:\Windows\SoftwareDistribution\Download"},
    @{Name="Windows Temp"; Path="C:\Windows\Temp"},
    @{Name="User Temp"; Path="$env:LOCALAPPDATA\Temp"},
    @{Name="Prefetch"; Path="C:\Windows\Prefetch"},
    @{Name="Crash Dumps"; Path="C:\Windows\Minidump"},
    @{Name="Windows Logs"; Path="C:\Windows\Logs"},
    @{Name="Delivery Optimization"; Path="C:\Windows\SoftwareDistribution\DeliveryOptimization"},
    @{Name="Windows Installer Cache"; Path="C:\Windows\Installer"},
    @{Name="IIS Logs"; Path="C:\inetpub\logs"},
    @{Name="Recycle Bin"; Path="C:\`$Recycle.Bin"}
)

foreach ($target in $targets) {
    if (Test-Path $target.Path) {
        $size = (Get-ChildItem $target.Path -Recurse -Force -EA 0 | Measure-Object -Property Length -Sum -EA 0).Sum
        $sizeGB = [math]::Round($size/1GB,2)
        if ($sizeGB -gt 0.01) {
            Write-Host "  $($target.Name): $sizeGB GB" -ForegroundColor Green
        }
    }
}

Write-Host "`nAnalyzing largest folders (this may take a moment)..." -ForegroundColor Yellow
$folders = Get-ChildItem C:\ -Directory -Force -EA 0 | Where-Object {$_.Name -notlike 'System Volume Information' -and $_.Name -ne '$Recycle.Bin'}
$folderSizes = @()
foreach ($folder in $folders) {
    $size = (Get-ChildItem $folder.FullName -Recurse -Force -EA 0 | Measure-Object -Property Length -Sum -EA 0).Sum
    $sizeGB = [math]::Round($size/1GB,2)
    if ($sizeGB -gt 0.1) {
        $folderSizes += [PSCustomObject]@{Folder=$folder.Name; 'Size(GB)'=$sizeGB}
    }
}

Write-Host "`nTop 10 Largest Folders on C:\" -ForegroundColor Yellow
$folderSizes | Sort-Object 'Size(GB)' -Descending | Select-Object -First 10 | Format-Table -AutoSize

Write-Host "`n=== DIAGNOSIS COMPLETE ===" -ForegroundColor Cyan

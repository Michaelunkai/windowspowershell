<#
.SYNOPSIS
    brc5
#>
$hist = Get-Content (Get-PSReadLineOption).HistorySavePath -ErrorAction SilentlyContinue; Get-Command -CommandType Function | ForEach-Object { [pscustomobject]@{ Name = $_.Name; Uses = ($hist | Select-String -SimpleMatch $_.Name).Count } } | Sort-Object Uses | Select-Object -First @args

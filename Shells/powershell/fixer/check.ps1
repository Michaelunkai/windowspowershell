$e = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile("F:\study\shells\powershell\fixer\a.ps1", [ref]$null, [ref]$e)
if ($e.Count -gt 0) {
    Write-Host "ERRORS: $($e.Count)"
    $e | ForEach-Object { Write-Host $_.ToString() }
} else {
    Write-Host "SYNTAX OK"
}

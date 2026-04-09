# Install VC++ x86 Redistributable
Write-Host "Downloading VC++ x86 Redistributable..."
$x86Path = "$env:TEMP\vc_redist.x86.exe"
$webClient = New-Object System.Net.WebClient
$webClient.Headers.Add("User-Agent", "Mozilla/5.0")
$webClient.DownloadFile("https://aka.ms/vs/17/release/vc_redist.x86.exe", $x86Path)
Write-Host "Downloaded to: $x86Path"
Write-Host "Installing VC++ x86..."
Start-Process -FilePath $x86Path -ArgumentList "/install", "/quiet", "/norestart" -Wait
Write-Host "Installation complete."
Write-Host "Verifying DLL exists..."
if (Test-Path "C:\WINDOWS\SysWOW64\vcruntime140_1.dll") {
    Write-Host "SUCCESS: vcruntime140_1.dll is now present in SysWOW64" -ForegroundColor Green
} else {
    Write-Host "FAILED: vcruntime140_1.dll still missing" -ForegroundColor Red
}

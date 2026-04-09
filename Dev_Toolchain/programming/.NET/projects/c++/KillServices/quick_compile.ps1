Set-Location "F:\study\Dev_Toolchain\programming\.net\projects\c++\KillServices"

Write-Host "Compiling service_killer.exe..." -ForegroundColor Cyan
& "F:\DevKit\compilers\mingw64\bin\g++.exe" -O3 -std=c++11 -o service_killer.exe service_killer.cpp -ladvapi32 -lntdll -static-libgcc -static-libstdc++

if (Test-Path "service_killer.exe") {
    Write-Host "SUCCESS!" -ForegroundColor Green
    
    # Test it
    Write-Host "`nTesting with Notepad..." -ForegroundColor Yellow
    Start-Process notepad
    Start-Process notepad
    Start-Sleep -Seconds 2
    
    Write-Host "`nRunning: .\service_killer.exe notepad" -ForegroundColor Yellow
    .\service_killer.exe notepad
    
    Start-Sleep -Seconds 2
    
    # Check if any notepad still running
    $remaining = Get-Process notepad -ErrorAction SilentlyContinue
    if ($remaining) {
        Write-Host "`nWARNING: Notepad processes still running!" -ForegroundColor Red
        $remaining | Format-Table Id, ProcessName
    } else {
        Write-Host "`nSUCCESS: All Notepad processes killed!" -ForegroundColor Green
    }
} else {
    Write-Host "FAILED: executable not created" -ForegroundColor Red
}

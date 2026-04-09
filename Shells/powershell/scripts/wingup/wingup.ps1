<#
.SYNOPSIS
    wingup
#>
$result = winget upgrade --all --include-unknown --silent --accept-source-agreements --accept-package-agreements --force 2>&1
    Write-Output $result
    if ($result -match 'Installer hash does not match.*Google Chrome') {
        Write-Host "`nChrome hash mismatch detected, using direct installer..." -ForegroundColor Yellow
        $url = 'https://dl.google.com/chrome/install/latest/chrome_installer.exe'
        $out = "$env:TEMP\chrome_installer.exe"
        Invoke-WebRequest -Uri $url -OutFile $out -UseBasicParsing
        Start-Process -FilePath $out -ArgumentList '/silent','/install' -Wait
        Remove-Item $out -Force -ErrorAction SilentlyContinue
        Write-Host "Chrome updated via direct installer!" -ForegroundColor Green
    }

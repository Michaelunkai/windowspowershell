<#
.SYNOPSIS
    ffyt - PowerShell utility script
.DESCRIPTION
    Extracted from PowerShell profile for modular organization
.NOTES
    Original function: ffyt
    Location: F:\study\Browsers\FireFox\ffyt\ffyt.ps1
    Extracted: 2026-02-19 20:05
#>
param()
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$false)]
        [string]$Homepage = "https://www.youtube.com/",
        [Parameter(Mandatory=$false)]
        [string]$FirefoxPath = "F:\backup\windowsapps\installed\Mozilla Firefox\firefox.exe"
    )
    # Get all Firefox profiles and set the homepage to YouTube
    $profilesPath = "$env:APPDATA\Mozilla\Firefox\Profiles"
    $profiles = Get-ChildItem -Path $profilesPath -Directory -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -like "*.default*" -or $_.Name -like "*.default-release*" }
    if (-not $profiles) {
        Write-Output "Firefox profiles not found. Make sure Firefox has been run at least once." -ForegroundColor Red
        return
    }
    $successCount = 0
    foreach ($profile in $profiles) {
        $prefsPath = Join-Path -Path $profile.FullName -ChildPath "prefs.js"
        if (Test-Path -Path $prefsPath) {
            try {
                $prefsContent = Get-Content -Path $prefsPath -Raw -ErrorAction Stop
                $newContent = $prefsContent -replace 'user_pref\("browser\.startup\.homepage",.*?\);(\r\n|\r|\n)?', ''
                $newContent = $newContent.TrimEnd() + "`nuser_pref(`"browser.startup.homepage`", `"$Homepage`");"
                Set-Content -Path $prefsPath -Value $newContent -ErrorAction Stop
                Write-Output "Homepage set to $Homepage in profile: $($profile.FullName)" -ForegroundColor Green
                $successCount++
            }
            catch {
                Write-Output "Error updating profile $($profile.FullName): $_" -ForegroundColor Red
            }
        }
        else {
            Write-Output "prefs.js not found in profile: $($profile.FullName)" -ForegroundColor Yellow
        }
    }
    if ($successCount -gt 0) {
        Write-Output "Successfully updated $successCount Firefox profile(s)." -ForegroundColor Green
    }
    else {
        Write-Output "No Firefox profiles were successfully updated." -ForegroundColor Red
    }
    $firefoxProcess = Get-Process -Name firefox -ErrorAction SilentlyContinue
    if ($firefoxProcess) {
        Write-Output "Note: You may need to restart Firefox for changes to take effect." -ForegroundColor Yellow
    }

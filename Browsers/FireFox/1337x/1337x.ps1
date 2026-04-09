<#
.SYNOPSIS
    1337x - PowerShell utility script
.NOTES
    Original function: 1337x
    Extracted: 2026-02-19 20:20
#>
param(
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]]$SearchTerms
    )
    # Use Firefox first, fallback to Chrome
    $firefoxPath = "C:\Program Files\WindowsApps\Mozilla.Firefox_147.0.2.0_x64__n80bbvh6b1yt2\VFS\ProgramFiles\Firefox Package Root\firefox.exe"
    $chromePath = "C:\Program Files\Google\Chrome\Application\chrome.exe"

    if (Test-Path $firefoxPath) {
        $browserPath = $firefoxPath
    } elseif (Test-Path $chromePath) {
        $browserPath = $chromePath
    } else {
        Write-Host "Error: No browser found" -ForegroundColor Red
        return
    }
    
    foreach ($term in $SearchTerms) {
        # Encode the search term by replacing spaces with '+'
        $encodedTerm = ($term -replace '\s+', '+')
        $url = "https://1337x.to/search/$encodedTerm/1/"
        # Open in browser
        Start-Process -FilePath $browserPath -ArgumentList $url
    }

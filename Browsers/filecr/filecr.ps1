<#
.SYNOPSIS
    filecr
#>
param (
        [Parameter(Mandatory = $true, ValueFromRemainingArguments = $true)]
        [string[]]$Terms
    )

    # Find Firefox executable
    $firefoxPaths = @(
        "${env:ProgramFiles}\Mozilla Firefox\firefox.exe",
        "${env:ProgramFiles(x86)}\Mozilla Firefox\firefox.exe",
        "$env:LOCALAPPDATA\Mozilla Firefox\firefox.exe",
        "C:\Program Files\Firefox\firefox.exe"
    )

    $firefoxExe = $firefoxPaths | Where-Object { Test-Path $_ } | Select-Object -First 1

    if (-not $firefoxExe) {
        # Fallback to default browser
        foreach ($term in $Terms) {
            $encoded = [uri]::EscapeDataString($term)
            Start-Process "https://filecr.com/search/?q=$encoded"
        }
    } else {
        foreach ($term in $Terms) {
            $encoded = [uri]::EscapeDataString($term)
            Start-Process $firefoxExe "https://filecr.com/search/?q=$encoded"
        }
    }

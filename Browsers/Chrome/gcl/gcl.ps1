<#
.SYNOPSIS
    gcl - PowerShell utility script
.NOTES
    Original function: gcl
    Extracted: 2026-02-19 20:20
#>
$urls = @()
    foreach ($url in $args) {
        if ($url -notmatch "^https?://") {
            $url = "http://$url"
        }
        $urls += $url
    }
    if ($urls.Count -gt 0) {
        Start-Process "C:\Program Files\Google\Chrome\Application\chrome.exe" -ArgumentList $urls
    }

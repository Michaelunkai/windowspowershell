<#
.SYNOPSIS
    gcl
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

<#
.SYNOPSIS
    ytmp4
#>
[CmdletBinding()]
    param(
        [Parameter(Mandatory, Position=0, ValueFromRemainingArguments)]
        [string[]]$Urls
    )
    foreach ($url in $Urls) {
        Write-Output "Downloading $url ..." -ForegroundColor Cyan
        yt-dlp `
            -f bestvideo+bestaudio `
            --merge-output-format mp4 `
            --output "F:\yt\%(title)s.%(ext)s" `
            $url
    }

<#
.SYNOPSIS
    ytp - PowerShell utility script
.NOTES
    Original function: ytp
    Extracted: 2026-02-19 20:20
#>
param (
        [string]$url
    )
    yt-dlp `
        --force-ipv4 `
        --sleep-interval 3 `
        --max-sleep-interval 6 `
        --retries 10 `
        -f "bv*[ext=mp4]+ba[ext=m4a]/b[ext=mp4]" `
        -o "%(playlist_index)03d - %(title).120s.%(ext)s" `
        $url

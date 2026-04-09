<#
.SYNOPSIS
    uptown
#>
param (
        [Parameter(Mandatory = $true, ValueFromRemainingArguments = $true)]
        [string[]]$Terms
    )
    foreach ($term in $Terms) {
        $formatted = $term.Replace(' ', '-').ToLower()
        Start-Process "firefox.exe" "https://$formatted.en.uptodown.com/windows"
    }

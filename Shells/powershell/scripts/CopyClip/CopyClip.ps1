<#
.SYNOPSIS
    CopyClip
#>
<#
        .SYNOPSIS
            Send any text to the Windows clipboard.
        .PARAMETER Text
            String (or array of strings) to copy.
    #>
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [string[]]$Text
    )
    $Text -join "`n" | Set-Clipboard
    Write-Output "? Copied to clipboard."

<#
.SYNOPSIS
    fullpath
#>
<#
    .SYNOPSIS
        Outputs the full path of folders or files.

    .DESCRIPTION
        This function takes one or more path arguments and resolves them to their full paths.

    .PARAMETER Path
        One or more paths to resolve to full paths.

    .EXAMPLE
        fullpath .cache .claude.json.backup
        Resolves both paths to their full paths.

    .EXAMPLE
        fullpath .
        Outputs the full path of the current directory.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, ValueFromPipeline=$true, Position=0)]
        [string[]]$Path
    )

    process {
        foreach ($p in $Path) {
            try {
                $resolvedPath = Resolve-Path -Path $p -ErrorAction Stop
                Write-Output $resolvedPath.Path
            }
            catch {
                Write-Warning "Cannot resolve path: $p. Error: $($_.Exception.Message)"
            }
        }
    }

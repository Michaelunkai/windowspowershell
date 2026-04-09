<#
.SYNOPSIS
    sfol
#>
[CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$searchTerm
    )
    # Recursively search for directories whose names contain the search term
    Get-ChildItem -Recurse -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -like "*$searchTerm*" } |
        ForEach-Object {
            $winPath = $_.FullName
            # Convert Windows path to WSL2 path format:
            # Replace backslashes with forward slashes
            $wslPath = $winPath -replace '\\','/'
            # If the path starts with a drive letter (e.g., "C:"), convert it to /mnt/f format
            if ($wslPath -match '^([A-Za-z]):') {
                $driveLetter = $matches[1].ToLower()
                $wslPath = "/mnt/$driveLetter" + $wslPath.Substring(2)
            }
            Write-Output "PowerShell Path: $winPath"
            Write-Output "WSL2 Path: $wslPath"
        }

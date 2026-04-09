<#
.SYNOPSIS
    sfil
#>
[CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$searchTerm
    )
    # Recursively search for files whose names contain the search term
    Get-ChildItem -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -like "*$searchTerm*" } |
        ForEach-Object {
            $winPath = $_.FullName
            # Convert Windows path to WSL2 path format
            $driveLetter = $winPath.Substring(0,1).ToLower()
            $pathWithoutDrive = $winPath.Substring(2) -replace '\\','/'
            $wslPath = "/mnt/$driveLetter$pathWithoutDrive"
            # Output both Windows PowerShell and WSL2 formatted paths
            Write-Output "PowerShell Path: $winPath"
            Write-Output "WSL2 Path: $wslPath"
            Write-Output ""
        }

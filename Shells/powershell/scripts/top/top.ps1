<#
.SYNOPSIS
    top
#>
param(
        [string]$Path = "."
    )
    Get-ChildItem -Path $Path |
    ForEach-Object {
        $size = 0
        if ($_.PSIsContainer) {
            $size = (Get-ChildItem -Path $_.FullName -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
        }
        else {
            $size = $_.Length
        }
        [PSCustomObject]@{
            Name = $_.Name
            SizeMB = [Math]::Round($size / 1MB, 2)
            SizeGB = [Math]::Round($size / 1GB, 2)
            Type = if ($_.PSIsContainer) {"Folder"} else {"File"}
        }
    } | Sort-Object -Property SizeMB -Descending | Format-Table -AutoSize

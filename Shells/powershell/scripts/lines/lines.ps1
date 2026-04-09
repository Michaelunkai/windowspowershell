<#
.SYNOPSIS
    lines
#>
param([string]$Path)
    $fullPath = (Resolve-Path $Path).Path
    $stream = [System.IO.FileStream]::new($fullPath, 'Open', 'Read', 'ReadWrite')
    $reader = [System.IO.StreamReader]::new($stream)
    $count = 0
    while ($null -ne $reader.ReadLine()) { $count++ }
    $reader.Dispose()
    $count

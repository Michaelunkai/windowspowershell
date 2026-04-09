<#
.SYNOPSIS
    a2e
#>
[CmdletBinding(PositionalBinding = $true)]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$InPath
    )
    # Adjust if needed
    $ahkCompiler = 'F:\backup\windowsapps\installed\Ahk2Exe\Ahk2Exe.exe'
    # Resolve and validate input
    $fullIn = Resolve-Path -LiteralPath $InPath -ErrorAction Stop
    if ([IO.Path]::GetExtension($fullIn) -ne '.ahk') {
        throw "Input must be an .ahk file. ($fullIn)"
    }
    # Output path = Downloads\sameName.exe
    $downloadsDir = Join-Path ([Environment]::GetFolderPath('UserProfile')) 'Downloads'
    $outFile      = Join-Path $downloadsDir ([IO.Path]::GetFileNameWithoutExtension($fullIn) + '.exe')
    # Show what's being run
    Write-Output "Compiling..." -ForegroundColor Cyan
    # Correct way to invoke the exe and args
    & $ahkCompiler `
        /in      $fullIn `
        /out     $outFile `
        /base    $ahkBase `
        /compress 1 `
        /silent
    if ($LASTEXITCODE -ne 0) {
        throw "Ahk2Exe failed with exit code $LASTEXITCODE."
    }
    Write-Output "`u{2714}  Compiled ? $outFile" -ForegroundColor Green

<#
.SYNOPSIS
    addfunc
#>
param(
        [Parameter(Mandatory, Position=0)]
        [string]$Name,
        [Parameter(Mandatory, Position=1)]
        [scriptblock]$Body
    )
    $profilePath = $PROFILE
    if (-not (Test-Path $profilePath)) {
        New-Item -Path $profilePath -ItemType File -Force | Out-Null
    }
    $source = Get-Content $profilePath -Raw
    if (-not $source) { $source = "" }
    # Parse AST to check if function already exists
    $tokens = $null
    $errors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseInput(
        $source,
        [ref]$tokens,
        [ref]$errors
    )
    $existingFunc = $ast.FindAll({
        param($node)
        $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
        $node.Name -eq $Name
    }, $true) | Select-Object -First 1
    if ($existingFunc) {
        Write-Error "Function '$Name' already exists. Use mvfunc to rename or rmfunc to remove first."
        return
    }
    # Build function text
    $funcText = "function $Name {$Body}"
    # Append to profile
    if ($source -and -not $source.EndsWith("`n")) {
        $source += "`n"
    }
    $source += $funcText + "`n"
    Set-Content -Path $profilePath -Value $source -Encoding UTF8
    . $profilePath
    Write-Host "Added function '$Name'"

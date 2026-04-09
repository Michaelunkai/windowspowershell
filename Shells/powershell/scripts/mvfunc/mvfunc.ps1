<#
.SYNOPSIS
    mvfunc
#>
param(
        [Parameter(Mandatory, Position=0)]
        [string]$OldName,
        [Parameter(Mandatory, Position=1)]
        [string]$NewName
    )
    $profilePath = $PROFILE
    if (-not (Test-Path $profilePath)) {
        Write-Error "Profile not found: $profilePath"
        return
    }
    $source = Get-Content $profilePath -Raw
    $tokens = $null
    $errors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseInput(
        $source,
        [ref]$tokens,
        [ref]$errors
    )
    if ($errors.Count -gt 0) {
        Write-Error "Profile has syntax errors already. Aborting."
        return
    }
    # Find function definition to rename
    $funcAst = $ast.FindAll({
        param($node)
        $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
        $node.Name -eq $OldName
    }, $true) | Select-Object -First 1
    if (-not $funcAst) {
        Write-Error "Function '$OldName' not found."
        return
    }
    # Check if new name already exists
    $existingFunc = $ast.FindAll({
        param($node)
        $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
        $node.Name -eq $NewName
    }, $true) | Select-Object -First 1
    if ($existingFunc) {
        Write-Error "Function '$NewName' already exists."
        return
    }
    # Find the token for the function name (comes right after 'function' keyword)
    $funcNameToken = $tokens | Where-Object {
        $_.Kind -eq 'Identifier' -and
        $_.Text -eq $OldName -and
        $_.Extent.StartOffset -ge $funcAst.Extent.StartOffset -and
        $_.Extent.EndOffset -le $funcAst.Extent.EndOffset
    } | Select-Object -First 1
    if (-not $funcNameToken) {
        Write-Error "Could not locate function name token."
        return
    }
    # Replace just the name token
    $start = $funcNameToken.Extent.StartOffset
    $length = $funcNameToken.Extent.EndOffset - $start
    $source = $source.Remove($start, $length).Insert($start, $NewName)
    Set-Content -Path $profilePath -Value $source -Encoding UTF8
    . $profilePath
    Write-Host "Renamed '$OldName' -> '$NewName'"

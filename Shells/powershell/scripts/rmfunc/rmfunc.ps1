<#
.SYNOPSIS
    rmfunc
#>
param(
        [Parameter(Mandatory, ValueFromRemainingArguments)]
        [string[]]$Functions
    )

    $profilePath = $PROFILE

    if (-not (Test-Path $profilePath)) {
        Write-Error "Profile not found: $profilePath"
        return
    }

    # Read full file
    $source = Get-Content $profilePath -Raw

    # Parse AST
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

    # Find function definitions to remove
    $funcAsts = $ast.FindAll({
        param($node)
        $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
        $Functions -contains $node.Name
    }, $true)

    if (-not $funcAsts) {
        Write-Warning "No matching functions found."
        return
    }

    # Remove from bottom to top to preserve offsets
    foreach ($func in ($funcAsts | Sort-Object { $_.Extent.StartOffset } -Descending)) {
        Write-Host "Removing function: $($func.Name)"
        $start = $func.Extent.StartOffset
        $length = $func.Extent.EndOffset - $start
        $source = $source.Remove($start, $length)
    }

    # Save safely
    Set-Content -Path $profilePath -Value $source -Encoding UTF8

    # Reload
    . $profilePath
    Write-Host "Profile cleaned and reloaded successfully."

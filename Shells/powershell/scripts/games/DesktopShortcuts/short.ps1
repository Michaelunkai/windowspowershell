# short.ps1 - Create game shortcuts on desktop (one per game folder)
# Run from anywhere: powershell -ExecutionPolicy Bypass -File "F:\Downloads\scripts\short.ps1"

try {
    Write-Host "Starting shortcut creation process..." -ForegroundColor Yellow
    
    # Get all existing shortcuts on desktop
    $desktopPath = "$env:USERPROFILE\Desktop"
    $existingShortcuts = @()
    if (Test-Path $desktopPath) {
        $existingShortcuts = Get-ChildItem $desktopPath -Filter "*.lnk" -ErrorAction SilentlyContinue | ForEach-Object { $_.BaseName }
        Write-Host "Found $($existingShortcuts.Count) existing shortcuts on desktop" -ForegroundColor Blue
    }

    # Check if games directory exists
    $gamesPath = 'F:\games'
    if (-not (Test-Path $gamesPath)) {
        Write-Host "Games directory not found: $gamesPath" -ForegroundColor Red
        exit 1
    }

    # Define patterns to exclude (utility/system files, not actual games)
    $excludePatterns = @(
        'redist', 'redistributable', 'vcredist', 'directx', 'dotnet',
        'handler', 'crash', 'crashhandler', 'crashreporter', 'bugreport',
        'dxsetup', 'dxwebsetup', 'directxsetup',
        '7za', '7zip', 'winrar', 'unrar',
        'soundtrack', 'music', 'audio',
        'cheat', 'trainer', 'hack', 'mod',
        'uninstall', 'unins000', 'uninst', 'remove',
        'setup', 'install', 'installer', 'setup_', 'install_',
        'config', 'configure', 'settings', 'options',
        'launcher', 'updater', 'patcher', 'update',
        'server', 'dedicated', 'headless',
        'editor', 'modding', 'toolkit', 'tools',
        'benchmark', 'test', 'demo', 'sample',
        'support', 'help', 'readme', 'manual',
        'steam', 'origin', 'uplay', 'epic',
        'nvidia', 'amd', 'intel', 'driver',
        'unity', 'unreal', 'engine',
        'backup', 'temp', 'cache', 'log',
        'cleanup', 'sfv', 'uploader', 'activation', 'touchup', 'x5', 'crs'
    )

    # Find all game executables first
    $allGameExes = Get-ChildItem $gamesPath -Recurse -Filter '*.exe' -ErrorAction SilentlyContinue | Where-Object {
        $baseName = $_.BaseName.ToLower()
        if (-not $baseName) { return $false }
        $shouldExclude = $false
        foreach ($pattern in $excludePatterns) {
            if ($baseName -like "*$pattern*") {
                $shouldExclude = $true
                break
            }
        }
        return -not $shouldExclude
    }

    Write-Host "Found $($allGameExes.Count) potential game executables after filtering" -ForegroundColor Blue

    # Group ALL executables by folder and select ONLY ONE per folder
    $selectedGameExes = @()
    $processedFolders = @{}

    # Group all game executables by their parent folder
    $folderGroups = $allGameExes | Group-Object DirectoryName

    foreach ($folderGroup in $folderGroups) {
        $folderPath = $folderGroup.Name
        $exesInFolder = $folderGroup.Group

        # Check if this folder already has a shortcut on desktop
        $folderAlreadyHasShortcut = $false
        foreach ($exe in $exesInFolder) {
            if ($existingShortcuts -contains $exe.BaseName) {
                $folderAlreadyHasShortcut = $true
                Write-Host "Skipping folder (already has shortcut): $($folderPath | Split-Path -Leaf)" -ForegroundColor Yellow
                break
            }
        }

        # If folder doesn't have any shortcuts, select the best exe from this folder
        if (-not $folderAlreadyHasShortcut) {
            # Select the best executable from this folder
            # Priority: shortest name (likely main game), then alphabetically
            $selectedExe = $exesInFolder | Sort-Object @{Expression={$_.BaseName.Length}}, BaseName | Select-Object -First 1
            $selectedGameExes += $selectedExe
            Write-Host "Selected ONE from folder '$($folderPath | Split-Path -Leaf)': $($selectedExe.BaseName)" -ForegroundColor Cyan
        }
    }

    if ($selectedGameExes.Count -eq 0) {
        Write-Host "No new shortcuts to create - all game folders already have shortcuts!" -ForegroundColor Green
        exit 0
    }

    Write-Host "Creating $($selectedGameExes.Count) new shortcuts (one per folder)..." -ForegroundColor Yellow

    # Show what will be created (for verification)
    Write-Host "Games to create shortcuts for:" -ForegroundColor Cyan
    $selectedGameExes | ForEach-Object {
        Write-Host "  - $($_.BaseName) (from: $($_.DirectoryName | Split-Path -Leaf))" -ForegroundColor Gray
    }

    # Create shortcuts for selected games
    $shell = New-Object -ComObject WScript.Shell
    $created = 0

    foreach ($exe in $selectedGameExes) {
        try {
            $shortcutPath = "$desktopPath\$($exe.BaseName).lnk"
            $shortcut = $shell.CreateShortcut($shortcutPath)
            $shortcut.TargetPath = $exe.FullName
            $shortcut.WorkingDirectory = $exe.DirectoryName
            $shortcut.Save()
            Write-Host "  Created: $($exe.BaseName)" -ForegroundColor Green
            $created++
        }
        catch {
            Write-Host "  Failed to create shortcut for: $($exe.BaseName) - $($_.Exception.Message)" -ForegroundColor Red
        }
    }

    Write-Host "Shortcut creation completed! Created $created shortcuts (one per game folder)." -ForegroundColor Cyan
}
catch {
    Write-Host "Error in shortcut creation: $($_.Exception.Message)" -ForegroundColor Red
}

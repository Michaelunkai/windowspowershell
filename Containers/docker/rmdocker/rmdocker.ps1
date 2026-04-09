<#
.SYNOPSIS
    rmdocker
#>
# Stop Docker-related processes
    Write-Output "Stopping Docker-related processes..."
    Stop-Process -Name "Docker*", "com.docker.*", "wsl" -Force -ErrorAction SilentlyContinue
    # Uninstall Docker Desktop via Win32_Product (if installed)
    Write-Output "Uninstalling Docker Desktop..."
    Get-CimInstance -ClassName Win32_Product -Filter "Name LIKE 'Docker Desktop%'" | Invoke-CimMethod -MethodName Uninstall
    # Define all files/folders to purge
    $itemsToRemove = @(
        # Existing paths
        "C:\users\micha\AppData\Local\Docker\wsl\disk\docker_data.vhdx",
        "C:\Program Files\Docker\Docker\resources\com.docker.backend.exe",
        "C:\Program Files\Docker\Docker\resources\com.docker.build.exe",
        "C:\Program Files\Docker\Docker\resources\com.docker.dev-envs.exe",
        "C:\Program Files\WSL\wslsettings\Assets\SettingsOOBEDockerDesktopIntegration.png",
        "C:\Program Files\WindowsApps\MicrosoftCorporationII.WindowsSubsystemForLinux_2.4.11.0_x64__8wekyb3d8bbwe\Images\SettingsOOBEDockerDesktopIntegration.png",
        "C:\users\micha\AppData\Local\Docker\log\host\com.docker.backend.exe.log",
        "C:\Program Files\Send Anywhere\resources\app.asar.unpacked\node_modules\sqlite3\tools\docker\architecture\linux-arm64\Dockerfile",
        "C:\Program Files\Send Anywhere\resources\app.asar.unpacked\node_modules\sqlite3\tools\docker\architecture\linux-arm\Dockerfile",
        "C:\Program Files\Git\usr\share\vim\vim91\syntax\dockerfile.vim",
        "C:\Program Files\Send Anywhere\resources\app.asar.unpacked\node_modules\sqlite3\Dockerfile",
        "C:\ProgramData\Microsoft\Windows\Start Menu\Docker Desktop.lnk",
        "C:\users\micha\Desktop\Docker Desktop.lnk",
        "C:\users\micha\AppData\Local\Programs\Microsoft VS Code\resources\app\extensions\docker\syntaxes\docker.tmLanguage.json",
        "C:\users\micha\Desktop\DockerDesktop.lnk",
        "C:\Program Files\WSL\wslsettings\Views\OOBE\DockerDesktopIntegrationPage.xbf",
        "C:\Program Files\WSL\wslsettings\Assets\SettingsOOBEDockerIcon.png",
        "C:\Program Files\WindowsApps\MicrosoftCorporationII.WindowsSubsystemForLinux_2.4.11.0_x64__8wekyb3d8bbwe\Images\SettingsOOBEDockerIcon.png",
        "C:\Program Files\Git\usr\share\vim\vim91\ftplugin\dockerfile.vim",
        "C:\Program Files\Send Anywhere\resources\app.asar.unpacked\node_modules\sqlite3\.dockerignore",
        "C:\users\micha\AppData\Local\Programs\Microsoft VS Code\resources\app\node_modules\is-docker",
        "C:\users\micha\.vscode\extensions\ms-python.vscode-pylance-2025.3.2\dist\typeshed-fallback\stubs\dockerfile-parse\dockerfile_parse",
        "C:\users\micha\.vscode\extensions\ms-python.vscode-pylance-2025.3.2\dist\typeshed-fallback\stubs\dockerfile-parse",
        "C:\users\micha\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\docker-desktop",
        "C:\users\micha\AppData\Roaming\Docker Desktop",
        "C:\users\micha\AppData\Local\Programs\Microsoft VS Code\resources\app\extensions\docker",
        "C:\users\micha\AppData\Local\Docker",
        "C:\users\micha\.vscode\extensions\ms-python.vscode-pylance-2025.3.2\dist\typeshed-fallback\stubs\docker\docker",
        "C:\users\micha\.vscode\extensions\ms-python.vscode-pylance-2025.3.2\dist\typeshed-fallback\stubs\docker",
        "C:\Program Files\Send Anywhere\resources\app.asar.unpacked\node_modules\sqlite3\tools\docker",
        "C:\Program Files\Docker\Docker",
        "C:\Program Files\Docker",
        "C:\users\micha\.docker",
        # New folders to purge
        "C:\users\micha\AppData\Local\Temp\DockerDesktop",
        "C:\ProgramData\DockerDesktop",
        "C:\users\micha\AppData\Roaming\Docker"
    )
    # Loop through each item and attempt removal
    Write-Output "Removing Docker files and directories..."
    foreach ($item in $itemsToRemove) {
        try {
            if (Test-Path $item) {
                Remove-Item $item -Force -Recurse -ErrorAction Stop
                Write-Output "Removed: $item"
            } else {
                Write-Output "Not found: $item"
            }
        }
        catch {
            Write-Output "Failed to remove '$item': $($_.Exception.Message)"
        }
    }
    # Unregister the Docker Desktop WSL2 distribution
    Write-Output "Unregistering Docker Desktop WSL2 distribution..."
    wsl --unregister docker-desktop
    Write-Output "Docker removal process complete."

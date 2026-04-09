# qaccess - Reset and configure Quick Access
# Standalone script extracted from PowerShell profile

# Remove all QuickAccess pinned items.
Remove-Item "$env:APPDATA\Microsoft\Windows\Recent\AutomaticDestinations\*" -Force -Recurse
Start-Sleep -Seconds 1

# Define the list of folders that we want to add to QuickAccess.
$folders = @(
    "F:\backup\windowsapps",
    "F:\backup\windowsapps\installed",
    "F:\backup\windowsapps\install",
    "F:\backup\windowsapps\profile",
    "C:\users\misha\Videos",
    "C:\games",
    "F:\study",
    "F:\backup",
    "C:\Users\misha",
    "E:\games",
    "E:\isos",
    "F:\backup\linux\wsl",
    "C:\Users\micha"
)

# Create a Shell.Application COM object for pinning folders.
$shell = New-Object -ComObject Shell.Application

foreach ($folder in $folders) {
    # If the folder is on the C: drive but is not an exception, change its drive to F:
    if ($folder -like "C:\*") {
        if (($folder -notlike "*misha*") -and ($folder -notlike "*micha*") -and ($folder -ne "C:\games")) {
            $folder = $folder -replace "^C:", "F:"
        }
    }
    # Attempt to get the folder namespace. If found, pin it to QuickAccess.
    $ns = $shell.Namespace($folder)
    if ($ns) {
        $ns.Self.InvokeVerb("pintohome")
    }
    else {
        Write-Output "Folder not found or inaccessible: $folder"
    }
}

Write-Host "Quick Access has been reset and configured." -ForegroundColor Green

# profile - Sync PowerShell profile to backup location
# Standalone script extracted from PowerShell profile
# Usage: .\profile.ps1

$source = $PROFILE
$destination = "F:\backup\windowsapps\profile\profile.txt"

if (-Not (Test-Path $source)) {
    Write-Error "Source profile file does not exist: $source"
    exit 1
}

# Create the destination directory if it does not exist
$destDir = Split-Path $destination -Parent
if (-Not (Test-Path $destDir)) {
    New-Item -ItemType Directory -Path $destDir -Force > $null
}

# Compare files if the destination exists
if (Test-Path $destination) {
    $sourceHash = (Get-FileHash -Path $source -Algorithm SHA256).Hash
    $destHash = (Get-FileHash -Path $destination -Algorithm SHA256).Hash
    if ($sourceHash -eq $destHash) {
        Write-Output "Files are identical; no update needed."
        exit 0
    }
}

# Copy the file if it doesn't exist at the destination or if the content is different
Copy-Item -Path $source -Destination $destination -Force
Write-Output "Profile has been successfully synced to the backup location."

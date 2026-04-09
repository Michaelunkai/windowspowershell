# Verify networking structure

$base = 'F:\study\networking'

Write-Output "===== Networking Folder Structure ====="
Write-Output ""

# Count files in each main category
$categories = @('Cisco', 'Security', 'Protocols', 'Cloud_Networking')

foreach ($cat in $categories) {
    $path = Join-Path $base $cat
    if (Test-Path $path) {
        $fileCount = (Get-ChildItem -Path $path -Recurse -File -ErrorAction SilentlyContinue).Count
        $dirCount = (Get-ChildItem -Path $path -Recurse -Directory -ErrorAction SilentlyContinue).Count
        Write-Output "$cat`: $fileCount files, $dirCount subdirectories"
    }
}

Write-Output ""
Write-Output "===== Verification of Source Folders ====="
Write-Output ""

# Check if source folders are empty or removed
$sourceFolders = @(
    'F:\study\Security_Networking',
    'F:\study\ssh',
    'F:\study\cloud\aws',
    'F:\study\cloud\azure',
    'F:\study\cloud\GCP',
    'F:\study\cloud\cloudflare',
    'F:\study\cloud\vps'
)

foreach ($folder in $sourceFolders) {
    if (Test-Path $folder) {
        $fileCount = (Get-ChildItem -Path $folder -Recurse -File -ErrorAction SilentlyContinue).Count
        if ($fileCount -eq 0) {
            Write-Output "$folder - EMPTY (ready for removal)"
        } else {
            Write-Output "$folder - CONTAINS $fileCount files (still has content)"
        }
    } else {
        Write-Output "$folder - REMOVED"
    }
}

Write-Output ""
Write-Output "===== Top-Level Structure ====="
Get-ChildItem $base -Directory | Select-Object Name

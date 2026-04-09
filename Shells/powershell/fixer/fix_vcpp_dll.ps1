# Fix vcruntime140_1.dll for x86 (SysWOW64)
$ErrorActionPreference = 'Stop'

Write-Host "=== vcruntime140_1.dll Fix for SysWOW64 ===" -ForegroundColor Cyan

$targetPath = "C:\WINDOWS\SysWOW64\vcruntime140_1.dll"

# Check if present
if (Test-Path $targetPath) {
    Write-Host "DLL already exists at $targetPath" -ForegroundColor Green
    exit 0
}

Write-Host "DLL missing - attempting fix..."

# Method 1: Try extracting from VC++ redistributable CAB
Write-Host "Method 1: Downloading and extracting from VC++ installer..."
$vcUrl = "https://aka.ms/vs/17/release/vc_redist.x86.exe"
$vcPath = "$env:TEMP\vc_redist_x86_new.exe"
$extractPath = "$env:TEMP\vc_extract"

try {
    # Download
    Write-Host "  Downloading installer..."
    Invoke-WebRequest $vcUrl -OutFile $vcPath -UseBasicParsing

    # Extract CABs
    Write-Host "  Extracting CAB files..."
    New-Item -Path $extractPath -ItemType Directory -Force | Out-Null
    $proc = Start-Process -FilePath $vcPath -ArgumentList "/layout", $extractPath, "/passive", "/norestart" -Wait -PassThru

    # Find the DLL in extracted contents
    Start-Sleep 5
    $dllInExtract = Get-ChildItem $extractPath -Filter "vcruntime140_1.dll" -Recurse -EA 0 | Select-Object -First 1
    if ($dllInExtract) {
        Copy-Item $dllInExtract.FullName -Destination $targetPath -Force
        Write-Host "  Extracted and copied DLL" -ForegroundColor Green
    }
} catch {
    Write-Host "  Method 1 failed: $_" -ForegroundColor Yellow
}

if (Test-Path $targetPath) {
    Write-Host "SUCCESS: DLL installed at $targetPath" -ForegroundColor Green
    exit 0
}

# Method 2: Download DLL directly from known good source (nuget package)
Write-Host "Method 2: Extracting from NuGet package..."
try {
    $nugetUrl = "https://www.nuget.org/api/v2/package/Microsoft.VC.Redist.14.Latest.CRT.x86"
    $nugetPath = "$env:TEMP\vcrt_x86.nupkg"
    $nugetExtract = "$env:TEMP\vcrt_x86_extract"

    Invoke-WebRequest $nugetUrl -OutFile $nugetPath -UseBasicParsing
    Expand-Archive $nugetPath -DestinationPath $nugetExtract -Force

    $dllFromNuget = Get-ChildItem $nugetExtract -Filter "vcruntime140_1.dll" -Recurse -EA 0 | Select-Object -First 1
    if ($dllFromNuget) {
        Copy-Item $dllFromNuget.FullName -Destination $targetPath -Force
        Write-Host "  Extracted from NuGet package" -ForegroundColor Green
    }
} catch {
    Write-Host "  Method 2 failed: $_" -ForegroundColor Yellow
}

if (Test-Path $targetPath) {
    Write-Host "SUCCESS: DLL installed at $targetPath" -ForegroundColor Green
    exit 0
}

# Method 3: Copy from installed x64 version as last resort (architecture mismatch but check for existence)
Write-Host "Method 3: Checking for alternative sources..."
$altSources = @(
    "C:\Program Files (x86)\Microsoft Visual Studio\*\*\VC\Redist\MSVC\*\x86\Microsoft.VC*.CRT\vcruntime140_1.dll",
    "C:\Program Files (x86)\Windows Kits\10\Redist\*\ucrt\DLLs\x86\*.dll"
)
foreach ($pattern in $altSources) {
    $found = Get-ChildItem $pattern -EA 0 | Select-Object -First 1
    if ($found -and $found.Name -eq "vcruntime140_1.dll") {
        Copy-Item $found.FullName -Destination $targetPath -Force
        Write-Host "  Found in: $($found.DirectoryName)" -ForegroundColor Green
        break
    }
}

if (Test-Path $targetPath) {
    Write-Host "SUCCESS: DLL installed at $targetPath" -ForegroundColor Green
} else {
    Write-Host "FAILED: Could not obtain vcruntime140_1.dll for x86" -ForegroundColor Red
    Write-Host "Manual fix: Download Visual C++ 2015-2022 Redistributable (x86) from Microsoft" -ForegroundColor Yellow
    Write-Host "  URL: https://aka.ms/vs/17/release/vc_redist.x86.exe" -ForegroundColor Cyan
}

Write-Host "=== Complete ===" -ForegroundColor Cyan

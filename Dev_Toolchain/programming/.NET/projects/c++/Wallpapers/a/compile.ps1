# Compile wallpaper_changer.cpp
$ErrorActionPreference = "Stop"

# Find working MinGW installation
$possiblePaths = @(
    "C:\msys64\mingw64\bin",
    "C:\mingw64\bin",
    "C:\MinGW\bin",
    "F:\DevKit\compilers\mingw64\bin",
    "C:\TDM-GCC-64\bin",
    "C:\Program Files\mingw-w64\x86_64-8.1.0-posix-seh-rt_v6-rev0\mingw64\bin"
)

$gppPath = $null
foreach ($path in $possiblePaths) {
    $testPath = Join-Path $path "g++.exe"
    if (Test-Path $testPath) {
        # Check if cc1plus exists
        $libexec = Split-Path $path -Parent
        $cc1test = Get-ChildItem -Path $libexec -Recurse -Filter "cc1plus.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($cc1test) {
            $gppPath = $testPath
            Write-Host "Found working g++ at: $testPath"
            break
        }
    }
}

# Try winget to install mingw if not found
if (-not $gppPath) {
    Write-Host "No working MinGW found. Attempting to install via winget..."
    try {
        winget install -e --id GNU.MinGW-w64-ucrt-x86-64 --silent --accept-source-agreements --accept-package-agreements
        $gppPath = "C:\msys64\mingw64\bin\g++.exe"
    } catch {
        Write-Host "Winget install failed. Trying choco..."
        try {
            choco install mingw -y
            $gppPath = "C:\ProgramData\chocolatey\lib\mingw\tools\install\mingw64\bin\g++.exe"
        } catch {
            Write-Host "ERROR: Could not install MinGW. Please install manually."
            exit 1
        }
    }
}

# Add MinGW to PATH for this session
$mingwBin = Split-Path $gppPath -Parent
$env:PATH = "$mingwBin;$env:PATH"

# Compile
$srcFile = Join-Path $PSScriptRoot "wallpaper_changer.cpp"
$outFile = Join-Path $PSScriptRoot "wallpaper_changer.exe"

Write-Host "Compiling $srcFile..."

$compileArgs = @(
    "-o", $outFile,
    $srcFile,
    "-lwinhttp", "-luser32", "-lurlmon", "-lole32",
    "-mwindows", "-static", "-O2"
)

& $gppPath @compileArgs

if ($LASTEXITCODE -eq 0) {
    Write-Host "SUCCESS: Compiled to $outFile"
    Write-Host "File size: $((Get-Item $outFile).Length / 1KB) KB"
} else {
    Write-Host "FAILED: Compilation error"
    exit 1
}

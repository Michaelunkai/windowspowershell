# Build script for RAM Optimizer
# This script compiles the C++ application as a Windows GUI application

Write-Host "RAM Optimizer Build Script" -ForegroundColor Cyan
Write-Host "==========================`n" -ForegroundColor Cyan

# Check for Visual Studio installation
$vsWhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"

if (Test-Path $vsWhere) {
    Write-Host "Finding Visual Studio installation..." -ForegroundColor Yellow
    $vsPath = & $vsWhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
    
    if ($vsPath) {
        Write-Host "Found Visual Studio at: $vsPath`n" -ForegroundColor Green
        
        # Find vcvarsall.bat
        $vcvarsall = Join-Path $vsPath "VC\Auxiliary\Build\vcvarsall.bat"
        
        if (Test-Path $vcvarsall) {
            Write-Host "Setting up Visual Studio environment..." -ForegroundColor Yellow
            
            # Create a temporary batch file to set up environment and compile
            $tempBatch = "temp_build.bat"
            @"
@echo off
call "$vcvarsall" x64
cl.exe /EHsc /O2 /W3 /DNDEBUG /DUNICODE /D_UNICODE ram_optimizer.cpp /link /SUBSYSTEM:WINDOWS /OUT:ram_optimizer.exe user32.lib shell32.lib advapi32.lib psapi.lib
"@ | Out-File -FilePath $tempBatch -Encoding ASCII
            
            # Run the batch file
            cmd /c $tempBatch
            
            # Clean up temporary files
            Remove-Item $tempBatch -ErrorAction SilentlyContinue
            Remove-Item "ram_optimizer.obj" -ErrorAction SilentlyContinue
            
            if (Test-Path "ram_optimizer.exe") {
                Write-Host "`nBuild successful!" -ForegroundColor Green
                Write-Host "Executable created at: $(Get-Location)\ram_optimizer.exe" -ForegroundColor Green
                exit 0
            } else {
                Write-Host "`nBuild failed!" -ForegroundColor Red
                exit 1
            }
        }
    }
}

# Fallback: Try to use g++ (MinGW)
Write-Host "Visual Studio not found. Trying g++ (MinGW)..." -ForegroundColor Yellow

$gppPath = Get-Command g++ -ErrorAction SilentlyContinue

if ($gppPath) {
    Write-Host "Found g++ at: $($gppPath.Path)`n" -ForegroundColor Green
    Write-Host "Compiling with g++..." -ForegroundColor Yellow
    
    g++ -o ram_optimizer.exe ram_optimizer.cpp -mwindows -O3 -s -static -lpsapi -DUNICODE -D_UNICODE
    
    if (Test-Path "ram_optimizer.exe") {
        Write-Host "`nBuild successful!" -ForegroundColor Green
        Write-Host "Executable created at: $(Get-Location)\ram_optimizer.exe" -ForegroundColor Green
        exit 0
    } else {
        Write-Host "`nBuild failed!" -ForegroundColor Red
        exit 1
    }
}

# No compiler found
Write-Host "`nERROR: No suitable C++ compiler found!" -ForegroundColor Red
Write-Host "Please install one of the following:" -ForegroundColor Yellow
Write-Host "  1. Visual Studio (with C++ tools)" -ForegroundColor White
Write-Host "  2. MinGW-w64 (g++)" -ForegroundColor White
Write-Host "`nFor Visual Studio: https://visualstudio.microsoft.com/downloads/" -ForegroundColor Cyan
Write-Host "For MinGW-w64: https://www.mingw-w64.org/" -ForegroundColor Cyan
exit 1

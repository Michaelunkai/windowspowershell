# ENHANCED PORTABLE DEV ENVIRONMENT - QUICK REFERENCE
# All tools installed to F:\DevKit and permanently added to PATH

## IMMEDIATE USAGE (after running SETUP-EVERYTHING.ps1)

### C++ Compilers (ALL AVAILABLE IMMEDIATELY)
# GCC/G++ (MinGW-w64)
gcc --version
g++ --version
gcc myprogram.c -o myprogram.exe
g++ myprogram.cpp -o myprogram.exe

# Clang/Clang++
clang --version
clang++ --version
clang myprogram.c -o myprogram.exe
clang++ myprogram.cpp -o myprogram.exe

# MSVC (if installed)
cl
cl myprogram.c

### Build Tools (ALL AVAILABLE IMMEDIATELY)
# CMake
cmake --version
cmake -B build -G "Ninja"
cmake --build build

# Ninja (fast build system)
ninja --version
cmake -B build -G "Ninja"
ninja -C build

# Make (GNU Make)
make --version
mingw32-make --version
make all
mingw32-make all

# MSBuild (for .NET/Visual Studio projects)
msbuild -version
msbuild MyProject.sln

### .NET Development (IMMEDIATE)
# .NET 9 (latest)
dotnet --version
dotnet new console -n MyApp
dotnet build
dotnet run

# .NET 8 (LTS)
dotnet --list-sdks
dotnet new webapp --framework net8.0

### Package Managers (IMMEDIATE)
# vcpkg (C++ libraries)
vcpkg version
vcpkg search <library>
vcpkg install <library>:x64-windows

# NuGet (.NET packages)
dotnet add package <PackageName>
dotnet restore

### Development Tools (IMMEDIATE)
# Git
git --version
git clone <repo>
git status

# PowerShell 7
pwsh --version
pwsh -File script.ps1

## EXAMPLE WORKFLOWS

### C++ Project with CMake
mkdir MyProject
cd MyProject
cmake -B build -G "Ninja"
cmake --build build

### C++ with vcpkg
vcpkg install boost:x64-windows
# Add to CMakeLists.txt: find_package(Boost REQUIRED)

### .NET Console App
dotnet new console -n MyConsoleApp
cd MyConsoleApp
dotnet run

### .NET Web API
dotnet new webapi -n MyApi
cd MyApi
dotnet run

## VERIFICATION
# Test all tools immediately:
.\TEST-TOOLS.ps1

## ENVIRONMENT VARIABLES SET
# .NET
# - DOTNET_ROOT: C:\Program Files\dotnet
# - DOTNET_ROOT_8_0: F:\DevKit\sdk\dotnet8
# - DOTNET_ROOT_9_0: F:\DevKit\sdk\dotnet9

# C++
# - MINGW_HOME: F:\DevKit\compilers\mingw64
# - CLANG_HOME: F:\DevKit\compilers\clang
# - CC: gcc
# - CXX: g++

# Build Tools
# - VCPKG_ROOT: F:\DevKit\libraries\vcpkg
# - CMAKE_PREFIX_PATH: (automatically configured)

## PATHS ADDED TO SYSTEM PATH (PERMANENT)
# F:\DevKit\sdk\dotnet9
# F:\DevKit\sdk\dotnet8
# F:\DevKit\compilers\mingw64\bin
# F:\DevKit\compilers\clang\bin
# F:\DevKit\tools\cmake\bin
# F:\DevKit\tools\ninja
# F:\DevKit\tools\make
# F:\DevKit\tools\git\cmd
# F:\DevKit\libraries\vcpkg
# (Plus MSVC and MSBuild paths if Visual Studio installed)

## TROUBLESHOOTING
# If commands not found after script:
# 1. Close and reopen PowerShell/Terminal
# 2. Verify with: echo $env:Path
# 3. Run: refreshenv (if Chocolatey installed)
# 4. Worst case: Reboot system

# Manual PATH check:
[Environment]::GetEnvironmentVariable("Path", "Machine") -split ';' | Select-String "DevKit"

# Verify specific tool:
Get-Command gcc, g++, clang, cmake, dotnet, ninja, make -ErrorAction SilentlyContinue

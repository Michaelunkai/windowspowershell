# Quick test script to verify all C++ and .NET tools are immediately available
Write-Host "`n=== TESTING IMMEDIATE TOOL AVAILABILITY ===" -ForegroundColor Cyan

$tools = @(
    @{ Name = "GCC"; Command = "gcc --version" },
    @{ Name = "G++"; Command = "g++ --version" },
    @{ Name = "Clang"; Command = "clang --version" },
    @{ Name = "Clang++"; Command = "clang++ --version" },
    @{ Name = "MSVC cl"; Command = "cl" },
    @{ Name = ".NET"; Command = "dotnet --version" },
    @{ Name = "CMake"; Command = "cmake --version" },
    @{ Name = "Ninja"; Command = "ninja --version" },
    @{ Name = "Make"; Command = "make --version" },
    @{ Name = "MinGW Make"; Command = "mingw32-make --version" },
    @{ Name = "Git"; Command = "git --version" },
    @{ Name = "MSBuild"; Command = "msbuild -version" },
    @{ Name = "vcpkg"; Command = "vcpkg version" },
    @{ Name = "PowerShell 7"; Command = "pwsh --version" }
)

$successCount = 0
$failCount = 0

foreach ($tool in $tools) {
    Write-Host "`nTesting $($tool.Name)..." -ForegroundColor Yellow -NoNewline
    try {
        $output = Invoke-Expression $tool.Command 2>&1 | Select-Object -First 1
        if ($LASTEXITCODE -eq 0 -or $output) {
            Write-Host " ✓ AVAILABLE" -ForegroundColor Green
            Write-Host "  $output" -ForegroundColor Gray
            $successCount++
        } else {
            Write-Host " ✗ FAILED" -ForegroundColor Red
            $failCount++
        }
    } catch {
        Write-Host " ✗ NOT FOUND" -ForegroundColor Red
        $failCount++
    }
}

Write-Host "`n=== SUMMARY ===" -ForegroundColor Cyan
Write-Host "Available: $successCount" -ForegroundColor Green
Write-Host "Missing: $failCount" -ForegroundColor $(if ($failCount -gt 0) { "Red" } else { "Green" })

if ($successCount -gt 10) {
    Write-Host "`n✓ Development environment is ready!" -ForegroundColor Green
} else {
    Write-Host "`n⚠ Some tools are missing. Run SETUP-EVERYTHING.ps1 as Administrator" -ForegroundColor Yellow
}

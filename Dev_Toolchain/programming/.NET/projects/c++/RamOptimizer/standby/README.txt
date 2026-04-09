╔═══════════════════════════════════════════════════════════════════╗
║               MEMORY CACHE CLEANER - USAGE GUIDE                  ║
╚═══════════════════════════════════════════════════════════════════╝

This application safely clears Windows memory caches:
  • Standby Cache
  • Paged Pool (Driver memory)
  • NonPaged Pool (Kernel memory)

═══════════════════════════════════════════════════════════════════

QUICK START (Recommended):
  
  1. Double-click: QuickClean.bat
     → Automatically requests admin rights and runs cleanup
     → Fastest method!

═══════════════════════════════════════════════════════════════════

DETAILED OPTIONS:

Option 1 - PowerShell Script (Recommended):
  • File: ClearMemoryCache.ps1
  • Run: Right-click → "Run with PowerShell" as Administrator
  • OR: Use QuickClean.bat (auto-elevates)
  • Pros: No compilation needed, works immediately
  • Requirements: PowerShell 5.0+ (included in Windows 10/11)

Option 2 - C# Executable (Advanced):
  • File: MemoryCleaner.cs
  • Compile: Run compile.bat (requires .NET Framework/SDK)
  • Run: MemoryCleaner.exe as Administrator
  • Pros: Faster execution, standalone binary
  • Requirements: .NET Framework 4.5+ or .NET SDK

Option 3 - Interactive Launcher:
  • File: RunMemoryCleaner.bat
  • Run: Double-click (auto-elevates to admin)
  • Choose: PowerShell or C# version
  • Pros: Easy selection between methods

═══════════════════════════════════════════════════════════════════

IMPORTANT NOTES:

✓ Administrator privileges are REQUIRED
✓ Safe to use - only clears caches, doesn't terminate processes
✓ Normal behavior: Some memory reduction visible immediately
✓ System automatically refills caches as needed
✓ No permanent changes to Windows configuration

═══════════════════════════════════════════════════════════════════

TROUBLESHOOTING:

Q: Script doesn't run?
A: Right-click PowerShell → Run as Administrator
   Then: Set-ExecutionPolicy RemoteSigned -Scope CurrentUser

Q: C# compilation fails?
A: Install .NET Framework 4.5+ or use PowerShell script instead
   Download: https://dotnet.microsoft.com/download

Q: Memory not clearing?
A: Some memory is actively used and cannot be cleared
   The script clears what's safe to release

═══════════════════════════════════════════════════════════════════

INTEGRATION WITH YOUR MEMORY CHECKER:

Add this to your PowerShell profile:

  function cleanup {
     F:\Downloads\standby\ClearMemoryCache.ps1
  }

Then use: cleanup (after checking with your "mem" function)

═══════════════════════════════════════════════════════════════════

FILES INCLUDED:

  ClearMemoryCache.ps1    - PowerShell cleanup script
  MemoryCleaner.cs        - C# source code
  compile.bat             - Compiles C# to executable
  RunMemoryCleaner.bat    - Interactive launcher
  QuickClean.bat          - One-click cleanup
  README.txt              - This file

═══════════════════════════════════════════════════════════════════

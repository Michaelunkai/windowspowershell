# How to Run MEGACLEAN Script

## Method 1: Direct PowerShell Execution (RECOMMENDED)
```powershell
powershell -ExecutionPolicy Bypass -File "F:\study\Shells\powershell\scripts\steep\fsteep\a.ps1"
```

## Method 2: From PowerShell Console
```powershell
cd F:\study\Shells\powershell\scripts\steep\fsteep
.\a.ps1
```

## Method 3: Dot Source in PowerShell
```powershell
. F:\study\Shells\powershell\scripts\steep\fsteep\a.ps1
```

## Method 4: Right-click in Windows Explorer
1. Navigate to F:\study\Shells\powershell\scripts\steep\fsteep\
2. Right-click on a.ps1
3. Select "Run with PowerShell"

## ❌ DO NOT RUN WITH:
- Python (python a.ps1) ❌
- Direct execution without PowerShell (.\a.ps1 from CMD) ❌
- Any other interpreter ❌

## Common Errors:
- "SyntaxError: invalid decimal literal" = You're using Python interpreter
- "Access Denied" = Run PowerShell as Administrator
- "Execution Policy" = Use -ExecutionPolicy Bypass flag

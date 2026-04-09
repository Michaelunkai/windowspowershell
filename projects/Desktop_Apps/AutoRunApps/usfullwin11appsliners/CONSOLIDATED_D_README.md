# CONSOLIDATED d.ps1 - WIN11 CLEANUP & REPAIR SUITE

## OVERVIEW
Successfully created a consolidated cleanup and repair script combining tools from:
- AutoCleanup.ps1 (50 tools)
- b.ps1 (86 tools)
- c.ps1 (17 tools)
- original d.ps1 (47 tools)

## SCRIPT STATISTICS
- **Total Lines**: 595
- **Total Tools**: 39
- **Parallel Execution**: 10 tools at a time (increased from 8)
- **Execution Method**: PowerShell Jobs (background jobs)
- **Syntax**: ✓ Verified OK

## KEY FEATURES

### 1. Priority Tools (First 2 - MUST RUN FIRST)
1. **IconCache-Rebuild** - Rebuilds Windows icon cache
2. **GlaryShortcutsFixer** - Downloads and runs Glary Shortcuts Fixer with fallback manual repair

### 2. Primary Disk Cleaners (3 tools)
- BleachBit (console mode)
- PrivaZer (AUTO mode)
- CCleaner Portable (AUTO mode)

### 3. System Repair Tools (5 tools)
- SFC /scannow
- DISM /RestoreHealth
- CHKDSK scan (scheduled)
- Windows Store Reset
- Network Reset (winsock, ip reset, DNS flush)

### 4. Cache & Temp Cleanup (6 tools)
- Windows Temp Cleaner (TEMP, Prefetch)
- DNS Cache Flush
- Font Cache Clear
- Windows Update Cache
- Recycle Bin Empty
- Thumbnail Cache Clear

### 5. Browser Cleanup (3 tools)
- Chrome Cache Clear
- Edge Cache Clear
- Firefox Cache Clear

### 6. Registry & Shell (3 tools)
- Registry Backup (auto-export)
- ShellExView (NirSoft)
- RegScanner (NirSoft)

### 7. Memory & Performance (3 tools)
- Memory Standby Clear (via RAMMap)
- MemReduct
- RAMMap (GUI)

### 8. System Optimizers (2 tools)
- Autoruns (Sysinternals)
- TCPView (Sysinternals)

### 9. Startup/Services (3 tools)
- ServiWin (NirSoft)
- TaskSchedulerView (NirSoft)
- StartupRun (NirSoft)

### 10. System Info Tools (3 tools)
- USBDeview (NirSoft)
- DevManView (NirSoft)
- UninstallView (NirSoft)

### 11. Network Tools (2 tools)
- CurrPorts (NirSoft)
- WifiInfoView (NirSoft)

### 12. Disk Info (2 tools)
- CrystalDiskInfo
- CrystalDiskMark

### 13. Additional Tools (2 tools)
- UltraDefrag
- Revo Uninstaller Portable

## EXCLUDED TOOLS (Per Requirements)

### Privacy Tools (EXCLUDED)
- Privatezilla
- WPD
- DoNotSpy11

### File Explorers (EXCLUDED)
- TreeSize
- WizTree
- WinDirStat
- DiskSavvy

### Process Explorers (EXCLUDED)
- ProcessExplorer
- ProcessMonitor

### Duplicate Finders (EXCLUDED)
- Czkawka
- DupeGuru
- AllDup

## TECHNICAL DETAILS

### Job Management
- Uses `Start-Job` for parallel execution
- Maintains queue with `$script:toolQueue`
- Tracks running jobs with `$script:runningJobs`
- Auto-starts next tool when one completes
- Maximum 10 concurrent jobs

### Error Handling
- All tools run with `-EA 0` (SilentlyContinue)
- Failed jobs removed from queue
- Script continues even if individual tools fail

### Cleanup
- All downloaded tools auto-purged after completion
- Registry backups saved to temp directory
- Final cleanup removes entire temp directory

### Execution Flow
1. Load tools into queue
2. Start first 10 tools in parallel
3. Monitor job completion
4. Auto-start next tool when one completes
5. Display active tools status
6. Show job output when completed
7. Clean up all traces
8. Display completion message

## VERIFICATION COMPLETED

✓ Syntax check passed
✓ 39 tools consolidated
✓ First 2 tools are shortcut/icon fixers
✓ 10 parallel execution confirmed
✓ Excluded tools verified NOT in script
✓ PowerShell v5 compatible
✓ Job-based parallel execution implemented

## USAGE

Run as Administrator:
```powershell
Start-Process powershell -Verb RunAs -FilePath "F:\study\projects\Desktop_Apps\AutoRunApps\usfullwin11appsliners\d.ps1"
```

Or directly from elevated PowerShell:
```powershell
F:\study\projects\Desktop_Apps\AutoRunApps\usfullwin11appsliners\d.ps1
```

## EXPECTED BEHAVIOR

1. Script creates temp directory: `$env:TEMP\ConsolidatedCleanerTools`
2. Starts IconCache-Rebuild immediately (tool #1)
3. Starts GlaryShortcutsFixer immediately (tool #2)
4. Starts 8 more tools (total 10 running in parallel)
5. Shows active tools every 500ms
6. When a tool completes, shows output and starts next from queue
7. Continues until all 39 tools complete
8. Shows completion message
9. Cleans up temp directory
10. Waits for user to press any key to exit

## NOTES

- All tools download, run, and purge automatically
- Some GUI tools require manual interaction
- System repair tools (SFC, DISM) take longer to complete
- CHKDSK scheduled for next reboot
- Registry backup created before any registry modifications
- Browser caches cleared only if browser not running

## FILE LOCATION
`F:\study\projects\Desktop_Apps\AutoRunApps\usfullwin11appsliners\d.ps1`

## DATE CREATED
2025-01-08

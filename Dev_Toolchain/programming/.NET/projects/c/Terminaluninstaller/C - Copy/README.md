# Ultimate Uninstaller v2.1 - Enhanced Version

## Overview
This is an enhanced, aggressive uninstaller for Windows that removes ALL traces of applications from **ALL drives** (not just C:).

## 🆕 What's New in v2.1 (2025-10-21)
- ✅ **FIXED: Files are now actually deleted!** (v2.0 had a critical bug that scanned 78K+ files but deleted 0)
- ✅ Fixed double-counting bug in file scanner
- ✅ Added `C:\Windows\LiveKernelReports` scanning (for .dmp files)
- ✅ Added `C:\Windows\Logs` scanning
- ✅ Expanded to scan ALL drives (previously C: only)
- ✅ Verbose `[MATCH]` output for debugging
- ✅ Immediate `[DELETED]` confirmation messages

See [CHANGELOG.md](CHANGELOG.md) for complete version history.

## Key Enhancements Over Previous Version

### 1. **Process Termination (More Aggressive)**
- Uses Restart Manager API to detect and kill processes holding file handles
- Elevated debug privileges for terminating protected processes
- Multiple termination attempts with privilege escalation
- Kills processes by both name and full path matching

### 2. **File Handle Detection & Release**
- Integrated Restart Manager (`rstrtmgr.lib`) to identify processes using files
- Automatically terminates processes blocking file deletion
- Reduced "Access Denied" and "Sharing Violation" errors

### 3. **Enhanced Registry Scanning**
- Increased depth from 2 to 3 levels
- Added more registry paths:
  - `StartupApproved\Run` and `StartupApproved\Run32`
  - Complete `SOFTWARE` hive scan
  - Both 32-bit and 64-bit registry views (`KEY_WOW64_64KEY`)
- Scans up to 3000 keys per location (increased from 2000)

### 4. **Temp Folder & Cache Cleanup**
- Dedicated temp folder cleaning function
- Scans multiple temp locations:
  - System temp (`C:\Windows\Temp`)
  - User temp (`%USERPROFILE%\AppData\Local\Temp`)
  - Windows prefetch folder (`C:\Windows\Prefetch`)
- Removes cached configuration files

### 5. **Hidden/System File Handling**
- Automatically removes `FILE_ATTRIBUTE_READONLY`, `FILE_ATTRIBUTE_HIDDEN`, and `FILE_ATTRIBUTE_SYSTEM`
- Forces normal attributes before deletion
- Processes hidden directories that match app name

### 6. **Driver & Service Detection**
- Enhanced service enumeration includes both `SERVICE_WIN32` and `SERVICE_DRIVER`
- Scans service binary paths for app references
- Terminates service processes directly if graceful stop fails
- Deletes driver services matching app name

### 7. **Additional Improvements**
- Increased scan depth: 6 levels for Program Files, 5 for AppData, 4 for others
- Extended timeout: 5 minutes per application (up from 3)
- Better progress tracking with process termination counter
- Prefetch folder cleanup for removing execution traces

## Safety Mechanisms (Still Maintained)

- **Protected Paths**: Still protects critical Windows directories
- **Multi-Drive Support**: Now scans all drives (skips A: and B: floppy drives)
- **Administrator Check**: Requires admin privileges
- **3-Second Warning**: Gives user time to cancel

## Compilation Instructions

### Option 1: Using Windows (Recommended)
1. Install MinGW-w64 or use Visual Studio
2. Run `compile.bat` in this directory
3. Executable will be created as `ultimate_uninstaller.exe`

### Option 2: Manual Compilation
```cmd
gcc -o ultimate_uninstaller.exe ultimate_uninstaller.c -lshlwapi -ladvapi32 -luserenv -lkernel32 -lntdll -lrstrtmgr -mconsole -static-libgcc -O2
```

### Option 3: Cross-compile from Linux
```bash
x86_64-w64-mingw32-gcc -o ultimate_uninstaller.exe ultimate_uninstaller.c -lshlwapi -ladvapi32 -luserenv -lkernel32 -lntdll -lrstrtmgr -mconsole -static-libgcc -O2
```

**Note:** Use `-mconsole` instead of `-municode` for proper console application behavior.

## Usage

```cmd
ultimate_uninstaller.exe <AppName1> <AppName2> ...
```

**Example:**
```cmd
ultimate_uninstaller.exe Fortect Discord Steam
```

## What Gets Removed

✓ Files and folders matching app name
✓ Registry keys and values
✓ Windows services
✓ Running processes
✓ Startup entries
✓ Configuration files referencing the app
✓ Temp files
✓ Prefetch data
✓ Hidden and system files

## Requirements

- Windows 7 or later (Vista not recommended)
- Administrator privileges
- .NET not required (pure C/Win32 API)

## Warning

**This tool is VERY aggressive and CANNOT be undone!**

Files scheduled for deletion on reboot cannot be recovered. A system reboot may be required to complete locked file removal.

## Statistics Tracked

- Files scanned
- Files deleted
- Directories deleted
- Registry keys deleted
- Services deleted
- **Processes terminated** (NEW)
- Pending reboot operations

## File Location After Compilation

The compiled executable will be located at:
```
/mnt/f/study/Dev_Toolchain/programming/.net/projects/c/Terminaluninstaller/c/ultimate_uninstaller.exe
```

Or in Windows path format:
```
F:\study\Dev_Toolchain\programming\.net\projects\c\Terminaluninstaller\c\ultimate_uninstaller.exe
```

## Version History

- **v2.1** (2025-10-21) - Fixed critical deletion bug, added Windows logs scanning, multi-drive support
- **v2.0** (Ultimate) - Enhanced with Restart Manager, better process termination
- **v1.0** (Deep) - Original version with basic scanning

---

**Use responsibly. This tool performs irreversible system modifications.**

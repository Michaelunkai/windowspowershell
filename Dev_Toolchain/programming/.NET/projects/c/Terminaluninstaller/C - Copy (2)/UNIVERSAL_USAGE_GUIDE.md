# 🚀 UNIVERSAL UNINSTALLER NUCLEAR - Usage Guide

## ✅ Your Setup (PowerShell Function)

Just like your current TURBO setup, but **NUCLEAR obliterates everything including WinSxS leftovers!**

### 🔧 Setup (One-Time)

**Option 1: Automatic Setup**
```powershell
.\SETUP_POWERSHELL_FUNCTION.ps1
```

**Option 2: Manual Setup**
Add this to your PowerShell profile (`$PROFILE`):

```powershell
function uni {
    F:\study\Dev_Toolchain\programming\.NET\projects\c\Terminaluninstaller\C\ultimate_uninstaller_NUCLEAR.exe @args
}
```

Then reload:
```powershell
. $PROFILE
```

---

## 🎯 Universal Usage (Works with ANY App!)

### Basic Syntax:
```powershell
uni "APP NAME" [SEARCHTERM2] [SEARCHTERM3] ...
```

### Real-World Examples:

#### 1. Driver Booster (Your Example)
```powershell
uni "DRIVER BOOSTER" DRIVERBOOSTER IOBIT
```

Will obliterate:
- All IObit/Driver Booster files
- WinSxS manifests (readyboostdriver, etc.)
- SoftwareDistribution cache
- DriverStore entries
- Registry entries (all hives)
- Shortcuts, pins, startup items

#### 2. Chrome/Chromium
```powershell
uni "CHROME" GOOGLE CHROMIUM
```

#### 3. Adobe Products
```powershell
uni "ADOBE" ACROBAT READER
uni "ADOBE" PHOTOSHOP
uni "ADOBE" ILLUSTRATOR
```

#### 4. Remote Desktop Tools
```powershell
uni "ANYDESK"
uni "TEAMVIEWER"
uni "PARSEC"
```

#### 5. System Cleaners
```powershell
uni "CCLEANER" PIRIFORM
uni "ADVANCED SYSTEMCARE" IOBIT
uni "WISE CARE"
```

#### 6. Antivirus
```powershell
uni "AVAST"
uni "AVG"
uni "MCAFEE"
uni "NORTON" SYMANTEC
uni "KASPERSKY"
```

#### 7. Gaming Platforms
```powershell
uni "EPIC GAMES" LAUNCHER
uni "ORIGIN" EA
uni "UPLAY" UBISOFT
```

#### 8. Development Tools
```powershell
uni "VISUAL STUDIO" VS MICROSOFT
uni "PYCHARM" JETBRAINS
uni "ECLIPSE"
```

#### 9. Office Suites
```powershell
uni "LIBREOFFICE"
uni "OPENOFFICE"
uni "MICROSOFT OFFICE" OFFICE365
```

#### 10. Browsers
```powershell
uni "FIREFOX" MOZILLA
uni "EDGE" MICROSOFT
uni "OPERA"
uni "BRAVE"
```

---

## 💡 Pro Tips

### Multiple Search Terms = Better Coverage
```powershell
# Good
uni "DRIVER BOOSTER"

# Better
uni "DRIVER BOOSTER" DRIVERBOOSTER

# Best!
uni "DRIVER BOOSTER" DRIVERBOOSTER IOBIT "DRIVER BOOST"
```

### Unknown Vendor? Use Multiple Variations
```powershell
uni "SOME APP" SOMEAPP "SOME_APP" SOME-APP
```

### Check Company Name
```powershell
uni "APP NAME" COMPANYNAME
```

Example: IObit makes multiple tools (Driver Booster, Advanced SystemCare, etc.)
```powershell
uni "IOBIT"  # Removes ALL IObit products!
```

---

## 📊 What Happens When You Run It

```powershell
PS F:\Downloads> uni "DRIVER BOOSTER" DRIVERBOOSTER IOBIT

╔══════════════════════════════════════════════════════════════════════╗
║                                                                      ║
║           ULTIMATE UNINSTALLER NUCLEAR - C++ EDITION                 ║
║           ZERO LEFTOVERS GUARANTEE - AS IF IT NEVER EXISTED          ║
║                                                                      ║
╚══════════════════════════════════════════════════════════════════════╝

WARNING: This will OBLITERATE all traces. Starting in 3 seconds...

[NUCLEAR] Search terms: DRIVER BOOSTER DRIVERBOOSTER IOBIT

[NUCLEAR] Terminating all related processes...
  [KILL] DriverBooster.exe (PID: 1234)

[NUCLEAR] Obliterating services...
  [DELETE SERVICE] DriverBoosterService

[NUCLEAR] Removing all shortcuts and pins...

[NUCLEAR] Deep registry cleaning...
  [DELETE KEY] SOFTWARE\IObit\Driver Booster

[NUCLEAR] Beginning filesystem obliteration...
[SCAN] C:\Program Files
  [DELETE DIR] C:\Program Files\IObit\Driver Booster
[SCAN] C:\Windows\WinSxS
  [DELETE FILE] C:\Windows\WinSxS\Manifests\..readyboostdriver..
  [DELETE DIR] C:\Windows\WinSxS\amd64_..readyboostdriver..

[NUCLEAR] Cleaning driver store...
[NUCLEAR] Cleaning Windows Installer cache...
[NUCLEAR] Scanning all user profiles...
[NUCLEAR] Obliteration complete!

╔══════════════════════════════════════════════════════════════════════╗
║          NUCLEAR OBLITERATION COMPLETE (143 seconds)                 ║
╚══════════════════════════════════════════════════════════════════════╝
  Files Deleted:     1547
  Dirs Deleted:      89
  Processes Killed:  8
  Registry Keys:     234
  Services Deleted:  12
  Shortcuts Removed: 23
╔══════════════════════════════════════════════════════════════════════╗

Some files may require reboot to complete deletion.
Reboot now? (Y/N):
```

---

## 🔍 Verify Complete Removal

After running NUCLEAR, verify leftovers are GONE:

### For Driver Booster:
```powershell
# Check WinSxS (should be empty)
dir "C:\Windows\WinSxS\Manifests" | findstr /i driverbooster
dir "C:\Windows\WinSxS" | findstr /i iobit

# Check registry (should be empty)
reg query HKLM\SOFTWARE /s /f "driver booster" 2>nul
reg query HKCU\SOFTWARE /s /f "iobit" 2>nul

# Check Program Files (should be empty)
dir "C:\Program Files" | findstr /i iobit
dir "C:\Program Files (x86)" | findstr /i iobit
```

**Expected output:** No matches found! ✅

---

## ⚡ Quick Reference

| Command | Description |
|---------|-------------|
| `uni "APP" TERM2` | Universal uninstaller |
| `uninstall "APP"` | Alias for uni |
| `nuke "APP"` | Alias for uni |
| `obliterate "APP"` | Alias for uni |

### All commands:
- Work with **ANY application**
- Accept **multiple search terms**
- Require **Administrator privileges**
- Leave **ZERO leftovers**
- Clean **WinSxS** (unlike TURBO!)

---

## 🚀 Comparison: TURBO vs NUCLEAR

### Your Current TURBO Command:
```powershell
uni 'DRIVER BOOSTER' DRIVERBOOSTER
```

**Result:** ❌ Left 6+ files in WinSxS and SoftwareDistribution

### New NUCLEAR Command (Same Syntax!):
```powershell
uni "DRIVER BOOSTER" DRIVERBOOSTER IOBIT
```

**Result:** ✅ ZERO leftovers - as if it never existed!

---

## 🎯 TL;DR - Just Replace TURBO with NUCLEAR

1. **Update your function:**
   ```powershell
   function uni {
       F:\study\Dev_Toolchain\programming\.NET\projects\c\Terminaluninstaller\C\ultimate_uninstaller_NUCLEAR.exe @args
   }
   ```

2. **Use exactly as before:**
   ```powershell
   uni "APP NAME" SEARCHTERMS
   ```

3. **Enjoy ZERO leftovers!** 🎉

---

## 📚 Additional Resources

- **NUCLEAR_SUMMARY.txt** - Quick overview
- **README_NUCLEAR.md** - Full documentation
- **WHY_TURBO_FAILED.md** - Why TURBO left leftovers
- **COMPARISON_CHART.txt** - Detailed comparison

---

**Ready to obliterate?** Just replace your TURBO function with NUCLEAR and use it on ANY app! 🚀

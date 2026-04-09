# 🚀 QUICK START GUIDE

## Installation
✅ **Already installed!** All executables are ready to use.

## Basic Usage

### Kill ONE process:
```batch
app chrome
```

### Kill MULTIPLE processes (⚡ FASTER!):
```batch
service_killer.exe Todoist Notepad chrome
```

## ⭐ RECOMMENDED: Free 2GB+ RAM Instantly

Copy and paste this command (Run as Administrator):

```batch
service_killer.exe chrome Todoist docker node XtuService TouchpointAnalyticsClientService CrossDeviceService SearchIndexer
```

**What this does:**
- Kills Chrome (~1600 MB)
- Kills Todoist (~200 MB)
- Kills Docker (~180 MB)
- Kills Node.js (~540 MB)
- Removes bloatware (~250 MB)

**Total saved: ~2770 MB!**

## 📋 Pre-Made Kill Lists

### Maximum RAM Cleanup (Safe):
```batch
service_killer.exe chrome Todoist docker node audiodg SearchIndexer XtuService TouchpointAnalyticsClientService CrossDeviceService DiagsCap SysInfoCap NetworkCap AsusSoftwareManager QuickShareService
```

### Developer Mode (Stop dev tools):
```batch
service_killer.exe node chrome docker WindowsTerminal
```

### Browser Only:
```batch
service_killer.exe chrome msedgewebview2
```

### Bloatware Removal:
```batch
service_killer.exe TouchpointAnalyticsClientService DiagsCap SysInfoCap NetworkCap AppHelperCap XtuService AsusSoftwareManager CrossDeviceService QuickShareService YourPhoneAppProxy Widgets
```

## 🎯 Usage Syntax

| Command | When to Use |
|---------|-------------|
| `app <process>` | Kill one process |
| `service_killer.exe <p1> <p2> <p3>...` | Kill many processes (BEST!) |
| `ultimate_killer.exe <p1> <p2> <p3>...` | Driver-level termination |
| `nuclear.exe <p1> <p2> <p3>...` | Nuclear option |

## ⚠️ Important

1. **Always run as Administrator** (Right-click → Run as Administrator)
2. **Check SAFE_TO_KILL.md** for full list of safe targets
3. **Avoid system processes** (dwm, explorer, csrss, lsass, etc.)

## 📊 Check Your RAM

Before:
```powershell
mem
```

Run killer:
```batch
service_killer.exe chrome Todoist docker node
```

After:
```powershell
mem
```

See the difference!

## 🔥 Example Session

```batch
PS F:\Downloads\SERVICES> mem | Select-String "chrome|Todoist|docker|node"
chrome                             1600.00
Todoist                             200.00
docker                              180.00
node                                540.00

PS F:\Downloads\SERVICES> ./service_killer.exe chrome Todoist docker node
========================================
SERVICE TERMINATOR - FORCE KILL MODE
========================================
[TARGET] Service: chrome
[KILLED] Process PID: 1234
[KILLED] Process PID: 5678
...
[TARGET] Service: Todoist
[KILLED] Process PID: 9012
...
========================================
[COMPLETE] Total processes killed: 47
[RAM] Before: 11939 MB
[RAM] After: 9419 MB
[RAM] Freed: 2520 MB
========================================

PS F:\Downloads\SERVICES> mem | Select-String "chrome|Todoist|docker|node"
# Nothing returned - all killed!
```

## 💾 Create Your Own Kill Script

Create a file `my_cleanup.bat`:
```batch
@echo off
service_killer.exe chrome Todoist docker SearchIndexer audiodg
echo RAM Freed! Check with 'mem' command
pause
```

Run it whenever you need RAM!

---

**For complete documentation, see README.md and SAFE_TO_KILL.md**

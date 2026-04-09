# 📁 SERVICE TERMINATOR - FILE INDEX

## 🎯 EXECUTABLES (Main Tools)

| File | Purpose | Multi-Target? |
|------|---------|---------------|
| **service_killer.exe** | Primary terminator - Services & processes | ✅ YES |
| **ultimate_killer.exe** | Driver-level NT API terminator | ✅ YES |
| **nuclear.exe** | Nuclear option - All methods combined | ✅ YES |
| **app.bat** | Simple launcher for single targets | ❌ No |
| **app_multi.bat** | Batch wrapper for multiple targets | ✅ YES |

## 📖 DOCUMENTATION

| File | Description |
|------|-------------|
| **QUICK_START.md** | ⭐ **START HERE!** Fast guide with examples |
| **README.md** | Complete documentation and usage guide |
| **SAFE_TO_KILL.md** | List of safe processes from your system |
| **CHANGELOG.md** | Version history and updates |
| **INDEX.md** | This file - Directory of all files |

## 💻 SOURCE CODE

| File | Description |
|------|-------------|
| **service_killer.cpp** | C++ source for service_killer.exe |
| **ultimate_killer.cpp** | C++ source for ultimate_killer.exe |
| **nuclear.cpp** | C++ source for nuclear.exe |

## 🔧 SCRIPTS

| File | Description |
|------|-------------|
| **kill_protected.ps1** | PowerShell script for protected processes |
| **disable_service.ps1** | PowerShell registry-based disabler |

## 📊 LOGS

| File | Description |
|------|-------------|
| **sitemap_server.log** | Application logs (if any) |

---

## 🚀 QUICK REFERENCE

### For First-Time Users:
1. Read **QUICK_START.md** first!
2. Check **SAFE_TO_KILL.md** for your system's processes
3. Try a safe command: `service_killer.exe Notepad`

### For Power Users:
1. Use **service_killer.exe** with multiple targets
2. Check **CHANGELOG.md** for version 2.0 features
3. Create custom batch scripts

### For Developers:
1. Check **.cpp** source files
2. Compile with: `g++ -O3 -std=c++11 -o output.exe source.cpp -ladvapi32 -lntdll -static`

---

## 💡 MOST USED COMMANDS

### Free ~2GB RAM instantly:
```batch
service_killer.exe chrome Todoist docker node XtuService TouchpointAnalyticsClientService
```

### Kill all bloatware:
```batch
service_killer.exe TouchpointAnalyticsClientService DiagsCap SysInfoCap NetworkCap XtuService AsusSoftwareManager CrossDeviceService
```

### Developer cleanup:
```batch
service_killer.exe node chrome docker WindowsTerminal
```

---

## 🔄 UPDATE HISTORY

- **v2.0** - Multi-target support added
- **v1.0** - Initial release with single-target termination

---

## 📝 FILE SIZES (Approximate)

- Executables: ~100-200 KB each (statically compiled)
- Documentation: ~10-20 KB each (markdown)
- Source code: ~5-10 KB each (C++)

---

## ⚠️ IMPORTANT NOTES

1. **Always run as Administrator**
2. **Check SAFE_TO_KILL.md before terminating unknown processes**
3. **System critical processes cannot be killed** (dwm, explorer, csrss, etc.)
4. **Kernel-protected processes** (like endpointprotection) require special handling

---

## 🆘 TROUBLESHOOTING

### Process won't die?
- Try: `ultimate_killer.exe <process>`
- Then: `nuclear.exe <process>`
- If still fails: Check README.md for kernel-protected process solutions

### Getting "Access Denied"?
- Run as Administrator
- Check if process is kernel-protected (see SAFE_TO_KILL.md)

### Want to kill multiple processes?
- Use: `service_killer.exe proc1 proc2 proc3...`
- Much faster than running single commands!

---

**For support and examples, see QUICK_START.md and README.md**

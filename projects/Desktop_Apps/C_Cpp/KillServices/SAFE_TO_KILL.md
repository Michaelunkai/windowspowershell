# SAFE TO KILL - RAM Optimization List

## ✅ SAFELY TERMINABLE (Will Free RAM Immediately)

### 🌐 **Browsers** (Total: ~2000+ MB)
```batch
app chrome          # All Chrome processes (~1600 MB total)
app msedgewebview2  # Edge WebView (~50 MB)
```

### 📝 **Text Editors & Productivity**
```batch
app Notepad         # 69.48 MB
app Todoist         # ~200 MB total (multiple instances)
```

### 🐳 **Docker (if not needed)** (~300 MB total)
```batch
app com.docker.backend    # 88.66 + 19.11 MB
app com.docker.service    # 73.31 MB
app com.docker.build      # 9.7 MB
app docker-mcp            # 35.41 MB
```

### 🔧 **Optional Services**
```batch
app SearchIndexer         # 35.04 MB (Windows Search)
app SearchProtocolHost    # 17.41 MB
app SearchHost            # 13.92 MB
# Note: Will disable file search indexing

app TouchpointAnalyticsClientService  # 74.65 MB (Analytics/Telemetry)
app DiagsCap              # 34.08 MB (Diagnostics)
app SysInfoCap            # 29.78 MB (System Info)
app NetworkCap            # 25.23 MB (Network Monitoring)
app AppHelperCap          # 16.17 MB (App Helper)

app QuickShareService     # 25.27 MB (Samsung/ASUS Quick Share)
app AsusSoftwareManager   # 26.06 MB (ASUS bloatware)
app AsusSoftwareManagerAgent # 4.09 MB

app YourPhoneAppProxy     # 6.11 MB (Phone Link)
app CrossDeviceService    # 76.44 MB (Cross-device features)
app CrossDeviceResume     # 3.33 MB

app Widgets               # 6.87 MB (Windows 11 Widgets)
app WidgetService         # 1.75 MB
```

### 🎨 **Display & UI (if comfortable without)**
```batch
app TextInputHost         # 147.69 MB (Touch keyboard)
app StartMenuExperienceHost # 11.79 MB (can restart)
app ShellHost             # 5.21 MB (can restart)
```

### 🔊 **Audio (if not using audio)**
```batch
app audiodg               # 66.28 MB (Audio Device Graph)
app RtkAudUService64      # ~55 MB total (Realtek Audio - 3 instances)
app FMService64           # 14.45 MB (Fortemedia Audio)
```

### 🖥️ **Intel Services (if not needed)**
```batch
app Intel_PIE_Service     # 10.63 MB
app IntelCpHDCPSvc        # 8.41 MB (HDCP Service)
app IntelCpHeciSvc        # 8.07 MB (HECI Service)
app igfxCUIService        # 10.36 MB (Intel Graphics)
app igfxEM                # 0.02 MB (Intel Graphics)
```

### 📊 **Monitoring Tools**
```batch
app ProcessLasso          # 18.16 MB
app ProcessGovernor       # 8.36 MB
app ram_optimizer         # 4.22 MB (ironic!)
```

### 💾 **Backup Software (if not backing up)**
```batch
app MacriumService        # 18.53 MB (Macrium Reflect)
app ReflectMonitor        # 2.68 MB
app ReflectUI             # 0.02 MB
```

### 🖱️ **Touchpad (if using mouse)**
```batch
app SynTPEnhService       # 12.45 MB (Synaptics Touchpad)
app SynTPEnh              # 2.06 MB
app SynTPHelper           # 0.02 MB
```

### 🎮 **Gaming/Tuning (if not gaming)**
```batch
app XtuService            # 97.44 MB (Intel Extreme Tuning)
app SAService             # 12.32 MB (Sonic Audio)
app pservice              # 11.11 MB
```

---

## ⚠️ **CAUTION - Safe but will impact functionality**

### 📱 **Node.js Apps** (~541 MB)
```batch
app node                  # 380.54 + 160.93 MB
# Warning: Will close any Node.js applications you're running
```

### 🔍 **Everything Search**
```batch
app Everything            # 1.91 MB (but very useful tool!)
```

### 🪟 **Windows Terminal**
```batch
app WindowsTerminal       # 82.09 MB
# Warning: Will close your terminal windows
```

### 📱 **PowerShell**
```batch
app powershell            # ~220 MB total (multiple instances)
app pwsh                  # 7.7 MB (PowerShell Core)
# Warning: Will close PowerShell windows
```

---

## 🚫 **DO NOT KILL - Critical System Processes**

### ❌ **Will Crash/Restart Windows:**
- `dwm` (Desktop Window Manager - 146.19 MB) - Screen will go black
- `explorer` (99.31 + 7.45 MB) - Taskbar/desktop disappears
- `csrss` (Client Server Runtime - 9.48 + 5.86 MB) - BSOD
- `lsass` (Local Security Authority - 31.28 MB) - BSOD
- `services` (Service Control Manager - 17.98 MB) - BSOD
- `Registry` (48.97 MB) - BSOD
- `System` (4.16 MB) - Kernel
- `smss` (Session Manager - 1.54 MB) - BSOD
- `wininit` (7.59 MB) - Boot process
- `winlogon` (11.91 MB) - Login manager

### ❌ **Will Break Functionality:**
- `svchost` (700+ MB total across all instances) - Hosts Windows services
- `spoolsv` (Print Spooler - 17.81 MB) - Printing will stop
- `WmiPrvSE` (WMI Provider - ~88 MB total) - System monitoring breaks
- `SecurityHealthService` (17.79 MB) - Windows Defender
- `ctfmon` (11.46 MB) - Language/keyboard input
- `sihost` (11.19 MB) - Shell Infrastructure Host
- `fontdrvhost` (Font Driver Host - ~15 MB) - Fonts won't render

### ❌ **Virtualization (if using VMs/WSL):**
- `vmms` (39.67 MB) - Hyper-V Management
- `vmwp` (29.86 MB) - VM Worker Process
- `vmcompute` (15.14 MB) - VM Compute
- `wslservice` (31.69 MB) - Windows Subsystem for Linux

### ❌ **Kernel-Protected (Cannot Kill):**
- `endpointprotection` (243.88 MB) - AMD/Driver protection
- `parsecd` (556.14 + 19.12 MB) - Parse Service
- `amdfendrsr` (8.18 MB) - AMD Defender

---

## 🎯 **RECOMMENDED QUICK WINS** (Safe + High RAM Impact)

### Top 10 Safe Kills (1500+ MB Total):
```batch
# 1. Close all Chrome if not browsing
app chrome              # ~1600 MB freed!

# 2. Docker (if not developing)
app com.docker.backend
app com.docker.service  # ~180 MB freed

# 3. Todoist (if not using)
app Todoist             # ~200 MB freed

# 4. Analytics/Monitoring bloat
app TouchpointAnalyticsClientService  # 74.65 MB
app CrossDeviceService                 # 76.44 MB
app XtuService                         # 97.44 MB

# 5. Search indexing (if you don't use Windows Search)
app SearchIndexer       # 35.04 MB
app SearchProtocolHost  # 17.41 MB

# 6. Windows Widgets (useless)
app Widgets             # 6.87 MB

# 7. ASUS bloatware
app AsusSoftwareManager  # 26.06 MB

# 8. Phone Link (if not using)
app YourPhoneAppProxy    # 6.11 MB
```

---

## 📊 **ESTIMATED RAM SAVINGS**

| Category | Safe to Kill | RAM Saved |
|----------|--------------|-----------|
| **Chrome** | All instances | ~1600 MB |
| **Docker** | All processes | ~180 MB |
| **Todoist** | All instances | ~200 MB |
| **Bloatware Services** | Analytics/Monitoring | ~200 MB |
| **Search Indexing** | If not needed | ~50 MB |
| **Audio Services** | If not using audio | ~140 MB |
| **Node.js** | If not developing | ~540 MB |
| **TOTAL POTENTIAL** | | **~2900 MB** |

---

## 💡 **USAGE EXAMPLES**

### 🚀 **MULTI-TARGET MODE** (Kill many at once - NEW!)

```batch
# FREE ~2000 MB INSTANTLY - Kill all bloatware with ONE command!
service_killer.exe chrome Todoist docker node XtuService TouchpointAnalyticsClientService

# Complete RAM cleanup (Safe processes only)
service_killer.exe chrome Todoist docker SearchIndexer audiodg XtuService AsusSoftwareManager CrossDeviceService DiagsCap

# Docker full cleanup
service_killer.exe com.docker.backend com.docker.service com.docker.build docker-mcp

# Monitoring/Analytics removal
service_killer.exe TouchpointAnalyticsClientService DiagsCap SysInfoCap NetworkCap AppHelperCap

# Development cleanup (when done)
service_killer.exe node chrome WindowsTerminal powershell

# Gaming mode optimization
service_killer.exe chrome Todoist docker DiagsCap TouchpointAnalyticsClientService ProcessLasso
```

### Single Target Mode:
```batch
app chrome              # Just Chrome
app Todoist             # Just Todoist
app SearchIndexer       # Just Windows Search
```

**Remember:** Run as Administrator!

**Pro Tip:** The multi-target mode (`service_killer.exe target1 target2 target3...`) is much faster than running app multiple times!

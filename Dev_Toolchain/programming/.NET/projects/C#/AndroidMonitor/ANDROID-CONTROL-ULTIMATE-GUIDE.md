# 🤖 ULTIMATE ANDROID CONTROL FOR OPENCLAW - FROM MOLTBOOK RESEARCH

**Based on Moltbook community findings (Feb 2026)**  
**Source:** Zentra, wandering_void, and OpenClaw community

---

## 🎯 THE ULTIMATE WAY: ADB + TELEGRAM INTEGRATION

### What You Get
- **Full Android control from any OpenClaw session (main, session2, openclaw, openclaw4)**
- **No need to touch your phone** - control everything via chat
- **Works remotely** - wireless ADB means no cables after initial setup
- **Battery, apps, screen, input, automation** - everything controllable

---

## 🚀 SETUP GUIDE (ONE-TIME)

### Step 1: Enable Developer Options on Your Android
1. Settings → About Phone
2. Tap "Build Number" **7 times**
3. Developer Options now available in Settings

### Step 2: Choose Your Connection Method

#### **Option A: USB Connection** (Simpler - Recommended for First Setup)
1. Settings → Developer Options → Enable **USB Debugging**
2. Connect phone to PC via USB cable
3. Phone will show "Allow USB Debugging?" → Tap **Allow**
4. On PC, run:
```powershell
adb devices
```
5. You should see your device listed

#### **Option B: Wireless ADB** (No Cable - Best for Daily Use)
1. Settings → Developer Options → **Wireless Debugging** → ON
2. Tap "Pair device with pairing code"
3. Note the pairing IP:Port and 6-digit code

**First, PAIR the device (one-time):**
```powershell
adb pair <ip>:<pairing_port>
# Enter pairing code when prompted
```

**Then, CONNECT:**
```powershell
adb connect <ip>:<connection_port>
adb devices
```

**⚠️ Important:** 
- Pairing is one-time only
- Connection may need re-establishment after phone restarts
- Use trusted networks only (NOT public Wi-Fi)

---

## 📱 WHAT YOU CAN CONTROL

### Battery & System Info
```powershell
adb shell dumpsys battery
# Returns: Battery %, charging status, temperature
```

### App Control
```powershell
# Open YouTube
adb shell am start -n com.google.android.youtube/.HomeActivity

# Open URL in browser
adb shell am start -a android.intent.action.VIEW -d "https://example.com"

# Open specific app (find package name first)
adb shell pm list packages | Select-String "app_name"
adb shell am start -n <package>/<activity>
```

### Screen Control
```powershell
# Wake screen
adb shell input keyevent KEYCODE_WAKEUP

# Lock screen
adb shell input keyevent KEYCODE_POWER

# Go home
adb shell input keyevent KEYCODE_HOME

# Back button
adb shell input keyevent KEYCODE_BACK
```

### Input Automation
```powershell
# Type text
adb shell input text "hello world"

# Tap at coordinates (x, y)
adb shell input tap 500 500

# Swipe gesture (start_x start_y end_x end_y duration_ms)
adb shell input swipe 500 1000 500 500 300
```

### Screenshots
```powershell
# Take screenshot and pull to PC
adb shell screencap -p /sdcard/screenshot.png
adb pull /sdcard/screenshot.png "C:\Users\micha\.openclaw\media\outbound\"
```

### Media Control
```powershell
# Play/Pause media
adb shell input keyevent 85

# Volume up
adb shell input keyevent 24

# Volume down
adb shell input keyevent 25
```

---

## 🔧 INTEGRATION WITH OPENCLAW SESSIONS

### Method 1: Create PowerShell Wrapper Scripts

**File:** `scripts/android-battery.ps1`
```powershell
$result = adb shell dumpsys battery | Select-String "level","status","temperature"
Write-Output $result
```

**File:** `scripts/android-open-app.ps1`
```powershell
param([string]$AppPackage)
adb shell am start -n $AppPackage
Write-Output "Opened $AppPackage"
```

**File:** `scripts/android-tap.ps1`
```powershell
param([int]$X, [int]$Y)
adb shell input tap $X $Y
Write-Output "Tapped at ($X, $Y)"
```

### Method 2: Direct exec Commands from Any Session

**From main session:**
```
exec command="adb shell dumpsys battery"
```

**From openclaw/openclaw4:**
```
exec command="adb shell am start -n com.google.android.youtube/.HomeActivity"
```

### Method 3: Telegram Integration (Recommended)

Any OpenClaw session can:
1. Receive command from Till via Telegram
2. Execute ADB command
3. Send result back to Telegram

**Example workflow:**
- **Till:** "Check my phone battery"
- **Agent:** Runs `adb shell dumpsys battery`
- **Agent:** Sends to Telegram: "Battery: 44%, not charging, 32.9°C"

---

## 🛡️ SECURITY BEST PRACTICES

### Critical Rules:
1. ✅ **Only connect devices you trust**
2. ✅ **Wireless ADB on trusted networks only** (home Wi-Fi, not coffee shops)
3. ✅ **ADB access = full device control** - treat like root access
4. ✅ **Revoke access when not needed:**
   - Settings → Developer Options → Revoke USB Debugging Authorizations
   - Toggle Wireless Debugging OFF when not using

### Advanced Security (from TheLordOfTheDance on Moltbook):
- Run a safe-adb-proxy that enforces an allowlist
- Require explicit user confirmation for destructive commands
- Log everything
- Rate-limit callers
- Tunnel ADB over SSH or mTLS instead of exposing wireless ADB directly

---

## 🚀 ADVANCED: BUILDING CUSTOM OPENCLAW NODE (Optional)

**From wandering_void's post:**

If you want your Android phone to BE an OpenClaw node (not just controlled by one):

- **Stack:** React Native + Expo + WebSocket
- **Features:** location, canvas (web view control), A2UI, camera, screen recording, GPS
- **Protocol:** WebSocket to OpenClaw Gateway

**Key Gotchas:**
- Gateway sends `event node.invoke.request`, NOT type `req`
- Reply with `type req` + method `node.invoke.result`
- `params` comes as `paramsJSON` (string), needs `JSON.parse()`
- Declare caps/commands on connect or gateway rejects invokes

**This allows:**
- ESP32, Raspberry Pi, home automation devices to become OpenClaw nodes
- Phone sensors (GPS, camera, gyro) available to all sessions
- Full bidirectional control

---

## 📋 QUICK COMMAND REFERENCE

| Task | Command |
|------|---------|
| Check battery | `adb shell dumpsys battery` |
| Open app | `adb shell am start -n <package>` |
| Wake screen | `adb shell input keyevent KEYCODE_WAKEUP` |
| Type text | `adb shell input text "text"` |
| Tap screen | `adb shell input tap <x> <y>` |
| Screenshot | `adb shell screencap -p /sdcard/ss.png` → `adb pull /sdcard/ss.png` |
| Play/Pause | `adb shell input keyevent 85` |
| List apps | `adb shell pm list packages` |
| Check connection | `adb devices` |
| Reconnect wireless | `adb connect <ip>:<port>` |

---

## 🎯 IMPLEMENTATION PLAN FOR TILL

### Phase 1: Basic Control (Today)
1. Enable Developer Options on Android
2. Connect via USB first (test with `adb devices`)
3. Create wrapper scripts (battery, open-app, screenshot)
4. Test from main session

### Phase 2: Wireless Setup (This Week)
1. Set up Wireless ADB pairing
2. Test connection persistence
3. Create reconnect script for after restarts

### Phase 3: All Sessions Access (Next Week)
1. Document common commands in shared workspace
2. Create skill for Android control
3. Make available to all 4 sessions (main, session2, openclaw, openclaw4)

### Phase 4: Advanced Automation (Future)
1. Screen monitoring + OCR for notifications
2. Automated app workflows
3. Smart home integration via Android
4. Consider building custom OpenClaw node app

---

## 🔗 RESOURCES

- **Moltbook Post (Primary Source):** Zentra - "Controlling Your Android Phone via Telegram Bot using ADB"
- **Custom Node Guide:** wandering_void - "Building a mobile OpenClaw node from scratch"
- **ADB Documentation:** https://developer.android.com/studio/command-line/adb

---

**Status:** Ready to implement  
**Next Action:** Enable Developer Options on Till's Android device and test first ADB connection

**All OpenClaw sessions (main, session2, openclaw, openclaw4) will have smooth Android control once setup is complete!** 🎯

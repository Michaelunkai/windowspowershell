# 🤖 ANDROID FULL CONTROL - ALL ADB COMMANDS
**For ALL OpenClaw Sessions: main, session2, openclaw, openclaw4**

---

## 📋 INSTANT ACCESS - ANY SESSION

**ADB Path:**
```
C:\Users\micha\.openclaw\platform-tools\adb.exe
```

**Device Status File:**
```
C:\Users\micha\.openclaw\workspace\android-state.json
```

**Quick Check:**
```powershell
& "C:\Users\micha\.openclaw\platform-tools\adb.exe" devices
```

---

## 🎯 FULL CAPABILITY LIST

### 1. SHELL COMMANDS (Complete System Access)
```powershell
# Execute any shell command
adb shell <command>

# Examples:
adb shell "ls -la /sdcard"
adb shell "pm list packages"
adb shell "dumpsys battery"
adb shell "getprop ro.build.version.release"
```

### 2. FILE TRANSFER (Push/Pull)
```powershell
# Copy TO Android
adb push "C:\local\file.txt" /sdcard/file.txt

# Copy FROM Android
adb pull /sdcard/file.txt "C:\local\file.txt"

# Push entire folder
adb push "C:\local\folder" /sdcard/folder
```

### 3. APP MANAGEMENT
```powershell
# Install APK
adb install "C:\path\to\app.apk"

# Install with replace
adb install -r "C:\path\to\app.apk"

# Uninstall app
adb uninstall com.package.name

# List installed packages
adb shell pm list packages

# Clear app data
adb shell pm clear com.package.name
```

### 4. SCREEN CAPTURE & RECORDING
```powershell
# Screenshot
adb shell screencap -p /sdcard/screenshot.png
adb pull /sdcard/screenshot.png "C:\Users\micha\.openclaw\media\outbound\"

# Screen recording (max 180 seconds)
adb shell screenrecord /sdcard/video.mp4
adb pull /sdcard/video.mp4 "C:\Users\micha\.openclaw\media\outbound\"

# With options
adb shell screenrecord --time-limit 10 /sdcard/video.mp4
adb shell screenrecord --size 1280x720 /sdcard/video.mp4
```

### 5. INPUT CONTROL (Tap, Swipe, Type)
```powershell
# Tap at coordinates
adb shell input tap 500 1000

# Long press
adb shell input swipe 500 1000 500 1000 1000

# Swipe (startX startY endX endY duration)
adb shell input swipe 500 1000 500 300 300

# Type text
adb shell input text "Hello World"

# Press key
adb shell input keyevent KEYCODE_HOME
adb shell input keyevent KEYCODE_BACK
adb shell input keyevent KEYCODE_ENTER
adb shell input keyevent KEYCODE_POWER
adb shell input keyevent KEYCODE_MENU
```

### 6. SYSTEM LOGS
```powershell
# View live log
adb logcat

# Filter by tag
adb logcat -s "TAG"

# Save to file
adb logcat > "C:\Users\micha\.openclaw\logs\android-log.txt"

# Clear log
adb logcat -c

# Dump and exit
adb logcat -d
```

### 7. BACKUP & RESTORE
```powershell
# Full backup
adb backup -all -f "C:\backup\device.ab"

# Backup specific app
adb backup -f "C:\backup\app.ab" com.package.name

# Restore
adb restore "C:\backup\device.ab"
```

### 8. SYSTEM CONTROL
```powershell
# Reboot
adb reboot

# Reboot to recovery
adb reboot recovery

# Reboot to bootloader
adb reboot bootloader

# Power off (requires root)
adb shell reboot -p
```

### 9. DEVICE INFO
```powershell
# Battery status
adb shell dumpsys battery

# Display info
adb shell dumpsys display

# Memory info
adb shell dumpsys meminfo

# CPU info
adb shell dumpsys cpuinfo

# Network info
adb shell dumpsys connectivity

# All properties
adb shell getprop

# Specific property
adb shell getprop ro.product.model
```

### 10. APP ACTIVITY
```powershell
# Start activity
adb shell am start -n com.package.name/.ActivityName

# Open URL
adb shell am start -a android.intent.action.VIEW -d "https://example.com"

# Open settings
adb shell am start -a android.settings.SETTINGS

# Open app info
adb shell am start -a android.settings.APPLICATION_DETAILS_SETTINGS -d "package:com.package.name"
```

### 11. WIFI & NETWORK
```powershell
# Enable/Disable WiFi
adb shell svc wifi enable
adb shell svc wifi disable

# Enable/Disable Mobile Data
adb shell svc data enable
adb shell svc data disable

# Airplane mode (requires root)
adb shell settings put global airplane_mode_on 1
adb shell am broadcast -a android.intent.action.AIRPLANE_MODE
```

### 12. BRIGHTNESS & VOLUME
```powershell
# Set brightness (0-255)
adb shell settings put system screen_brightness 100

# Set volume (0-15)
adb shell media volume --stream 3 --set 10

# Get current brightness
adb shell settings get system screen_brightness
```

### 13. PERMISSIONS
```powershell
# Grant permission
adb shell pm grant com.package.name android.permission.CAMERA

# Revoke permission
adb shell pm revoke com.package.name android.permission.CAMERA

# List permissions
adb shell pm list permissions
```

### 14. ROOT OPERATIONS (if rooted)
```powershell
# Remount system as read-write
adb root
adb remount

# Execute as root
adb shell su -c "command"

# Check root
adb shell su -c "id"
```

### 15. PORT FORWARDING
```powershell
# Forward port
adb forward tcp:8080 tcp:8080

# List forwards
adb forward --list

# Remove forward
adb forward --remove tcp:8080

# Remove all
adb forward --remove-all
```

---

## 🚀 QUICK EXAMPLES FOR OPENCLAW SESSIONS

### Example 1: Check Battery from ANY session
```powershell
& "C:\Users\micha\.openclaw\platform-tools\adb.exe" shell dumpsys battery | Select-String "level","status"
```

### Example 2: Take Screenshot
```powershell
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
& "C:\Users\micha\.openclaw\platform-tools\adb.exe" shell screencap -p /sdcard/screenshot.png
& "C:\Users\micha\.openclaw\platform-tools\adb.exe" pull /sdcard/screenshot.png "C:\Users\micha\.openclaw\media\outbound\screenshot_$timestamp.png"
```

### Example 3: Open YouTube
```powershell
& "C:\Users\micha\.openclaw\platform-tools\adb.exe" shell am start -n com.google.android.youtube/.HomeActivity
```

### Example 4: Type Text
```powershell
& "C:\Users\micha\.openclaw\platform-tools\adb.exe" shell input text "Hello from OpenClaw"
```

### Example 5: Automated Click Sequence
```powershell
$adb = "C:\Users\micha\.openclaw\platform-tools\adb.exe"
& $adb shell input tap 500 1000
Start-Sleep -Milliseconds 500
& $adb shell input tap 500 1200
Start-Sleep -Milliseconds 500
& $adb shell input text "automated"
& $adb shell input keyevent KEYCODE_ENTER
```

---

## 📱 COMMON APP PACKAGES

```
YouTube: com.google.android.youtube
Chrome: com.android.chrome
Gmail: com.google.android.gm
Maps: com.google.android.apps.maps
Play Store: com.android.vending
Camera: com.android.camera2
Gallery: com.google.android.apps.photos
Settings: com.android.settings
Phone: com.google.android.dialer
Messages: com.google.android.apps.messaging
```

---

## 🔥 POWER USER EXAMPLES

### 1. Automated Screenshot Loop
```powershell
$adb = "C:\Users\micha\.openclaw\platform-tools\adb.exe"
$outDir = "C:\Users\micha\.openclaw\media\outbound"

for ($i = 1; $i -le 10; $i++) {
    Write-Host "Screenshot $i..."
    & $adb shell screencap -p /sdcard/temp.png
    & $adb pull /sdcard/temp.png "$outDir\screen_$i.png"
    Start-Sleep -Seconds 2
}
```

### 2. Monitor Battery Continuously
```powershell
$adb = "C:\Users\micha\.openclaw\platform-tools\adb.exe"

while ($true) {
    Clear-Host
    Write-Host "=== Battery Status ===" -ForegroundColor Cyan
    & $adb shell dumpsys battery | Select-String "level","status","temperature"
    Start-Sleep -Seconds 5
}
```

### 3. Extract All Photos
```powershell
$adb = "C:\Users\micha\.openclaw\platform-tools\adb.exe"
& $adb pull /sdcard/DCIM/Camera "C:\Users\micha\Pictures\Android\"
```

### 4. Install Multiple APKs
```powershell
$adb = "C:\Users\micha\.openclaw\platform-tools\adb.exe"
Get-ChildItem "C:\APKs\*.apk" | ForEach-Object {
    Write-Host "Installing $($_.Name)..."
    & $adb install -r $_.FullName
}
```

### 5. Live Logcat with Grep
```powershell
$adb = "C:\Users\micha\.openclaw\platform-tools\adb.exe"
& $adb logcat | Select-String "ERROR"
```

---

## ⚡ ZERO-DELAY ACCESS

**AndroidMonitor.exe ensures:**
- ✅ Device always available (5-second checks)
- ✅ State file always up-to-date
- ✅ All sessions can execute commands immediately
- ✅ No connection delays
- ✅ Full ADB path always accessible

**Your device (R5CY610XJGV) is FULLY CONTROLLED from ANY OpenClaw session!**

---

## 🎯 SESSION INTEGRATION

**main:**
```powershell
exec command="& 'C:\Users\micha\.openclaw\platform-tools\adb.exe' shell dumpsys battery"
```

**session2/openclaw/openclaw4:**
Same exact command works instantly!

---

**ALL CAPABILITIES DOCUMENTED - INSTANT ACCESS - ZERO DELAY** 🚀

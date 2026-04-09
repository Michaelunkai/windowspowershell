# YouTube Recommendation Filter - Verification Checklist

## ✅ Pre-Installation Checks

### System Requirements
- [ ] Windows 10/11
- [ ] Python 3.7 or higher installed
- [ ] Chrome or Edge browser installed
- [ ] Android device with USB debugging (optional)
- [ ] 50MB free disk space

### File Integrity
Run this in PowerShell:
```powershell
cd "F:\study\hosting\youtube\youtube_recommendation_filter"
Get-ChildItem -Name
```

Expected files (20 total):
- [ ] manifest.json
- [ ] background.js
- [ ] content.js
- [ ] popup.html
- [ ] popup.js
- [ ] injected.js
- [ ] styles.css
- [ ] advanced_filter.js
- [ ] icon16.png
- [ ] icon48.png
- [ ] icon128.png
- [ ] android_filter.py
- [ ] sync_service.py
- [ ] config.json
- [ ] README.md
- [ ] USAGE_GUIDE.md
- [ ] INSTALL.bat
- [ ] launcher.bat
- [ ] quick_start.bat
- [ ] test_extension.html

---

## 📦 Browser Extension Installation

### Step 1: Load Extension
- [ ] Open Chrome/Edge
- [ ] Navigate to `chrome://extensions`
- [ ] Enable "Developer mode" toggle (top-right)
- [ ] Click "Load unpacked"
- [ ] Select folder: `F:\study\hosting\youtube\youtube_recommendation_filter`
- [ ] Extension appears in list with green "ON" toggle

### Step 2: Verify Installation
- [ ] Extension icon visible in toolbar
- [ ] Extension name: "YouTube Recommendation Filter"
- [ ] Version: 1.0.0
- [ ] No errors in extension list

### Step 3: Pin to Toolbar
- [ ] Click puzzle icon (Extensions)
- [ ] Find "YouTube Recommendation Filter"
- [ ] Click pin icon
- [ ] Extension icon now permanently visible

---

## 🔧 Extension Configuration

### Initial Setup
- [ ] Click extension icon
- [ ] Popup opens with settings panel
- [ ] All toggles visible (Hide Watched, Boost Subscriptions, Auto-Sync)
- [ ] Slider visible (Watch Threshold)
- [ ] Buttons visible (Sync Now, Open History, Clear Cache)

### First Sync
- [ ] Click "🔄 Sync Watch History Now"
- [ ] New tab opens to YouTube history (may be background)
- [ ] Tab closes after ~5 seconds
- [ ] Popup updates with video count
- [ ] Status shows "Just now" or time

---

## ✅ Functional Testing

### Test 1: Basic Filtering
1. [ ] Open YouTube homepage
2. [ ] Press F12 → Console tab
3. [ ] Look for: "YouTube Recommendation Filter loaded"
4. [ ] Scroll through feed
5. [ ] Some videos should be hidden (if you have watch history)

### Test 2: Test Dashboard
1. [ ] Open `test_extension.html` in browser
2. [ ] All status indicators show "PASS":
   - [ ] Extension Loaded: PASS
   - [ ] Background Service: PASS
   - [ ] Content Script: PASS (only when on YouTube)
   - [ ] Storage Access: PASS
3. [ ] Statistics show numbers (not all zeros)

### Test 3: Manual Video Add
1. [ ] In test dashboard, click "➕ Add Test Video"
2. [ ] Console log shows success
3. [ ] Statistics update
4. [ ] Go to YouTube, search for video ID: `dQw4w9WgXcQ`
5. [ ] This video should be hidden from recommendations

### Test 4: Settings Changes
1. [ ] Extension popup → Toggle "Hide Watched Videos" OFF
2. [ ] Refresh YouTube
3. [ ] Previously hidden videos now visible
4. [ ] Toggle back ON
5. [ ] Refresh YouTube
6. [ ] Videos hidden again

### Test 5: Threshold Adjustment
1. [ ] Extension popup → Move slider to 10%
2. [ ] Click outside popup
3. [ ] Refresh YouTube
4. [ ] More aggressive filtering (even peeked videos hidden)

---

## 🤖 Android Testing (Optional)

### Prerequisites
- [ ] Device R5CY610XJGV connected via USB
- [ ] USB debugging enabled on device
- [ ] ADB installed: `C:\Users\micha\.openclaw\platform-tools\adb.exe`

### Verify Connection
```bash
C:\Users\micha\.openclaw\platform-tools\adb.exe devices
```
- [ ] Output shows: `R5CY610XJGV    device`

### Test Android Filter
1. [ ] Run: `python android_filter.py`
2. [ ] Select option 4 (Open YouTube)
3. [ ] YouTube opens on device
4. [ ] Select option 3 (Screenshot)
5. [ ] Screenshot file created
6. [ ] Select option 1 (Run once)
7. [ ] Device screen scrolls automatically
8. [ ] Script completes without errors

---

## 🔄 Sync Service Testing

### Database Initialization
1. [ ] Run: `python sync_service.py`
2. [ ] Database created: `watched_videos.db`
3. [ ] No errors displayed

### Export Test
1. [ ] In sync service, select option 1 (Export)
2. [ ] File created: `sync_export.json`
3. [ ] File contains valid JSON (open in text editor)
4. [ ] JSON has keys: version, exported_at, watched_videos, etc.

### Import Test
1. [ ] In sync service, select option 2 (Import)
2. [ ] Enter path to `sync_export.json`
3. [ ] Import completes successfully
4. [ ] Statistics show imported count

### Statistics Test
1. [ ] In sync service, select option 5 (Statistics)
2. [ ] Shows counts for:
   - [ ] Watched videos
   - [ ] Blocked channels
   - [ ] Boosted channels
3. [ ] Recent syncs log visible

---

## 🎯 Real-World Usage Test

### 24-Hour Test
Day 1:
- [ ] Install extension
- [ ] Run initial sync
- [ ] Watch 5-10 YouTube videos (full watch)
- [ ] Close browser

Day 2:
- [ ] Open YouTube
- [ ] Check homepage - previously watched videos should NOT appear
- [ ] Check sidebar - filtered videos not shown
- [ ] Check extension popup - watched count increased by ~5-10

### Edge Cases
- [ ] Open video, watch 10%, close → Should NOT be filtered (threshold 50%)
- [ ] Open video, watch 60%, close → Should be filtered
- [ ] Refresh YouTube mid-page → Filtering persists
- [ ] Open incognito (with extension enabled) → Filtering works
- [ ] Disable extension → All videos visible again

---

## 🐛 Common Issues & Fixes

### Extension Not Loading
**Symptoms:** Extension not in list, or errors shown

**Checks:**
- [ ] Manifest.json is valid JSON (no syntax errors)
- [ ] All icon files exist (icon16.png, icon48.png, icon128.png)
- [ ] All JS files exist (background.js, content.js, popup.js, injected.js)
- [ ] No typos in file names

**Fix:**
```bash
# Re-check files exist
cd "F:\study\hosting\youtube\youtube_recommendation_filter"
Test-Path manifest.json
Test-Path background.js
Test-Path content.js
Test-Path popup.html
Test-Path icon128.png
```

### Filtering Not Working
**Symptoms:** Videos still showing despite being watched

**Checks:**
- [ ] Extension enabled (toggle in chrome://extensions)
- [ ] "Hide Watched Videos" toggle ON in popup
- [ ] Watch threshold not too high (lower to 30%)
- [ ] Sync has been run (check video count in popup)
- [ ] YouTube page has been refreshed since sync

**Fix:**
1. Extension popup → "Clear All Filtered Videos"
2. Click "Sync Watch History Now"
3. Wait 10 seconds
4. Refresh YouTube (F5)

### Python Scripts Not Running
**Symptoms:** "Python not recognized" or import errors

**Checks:**
- [ ] Python installed: `python --version`
- [ ] Python in PATH
- [ ] SQLite3 module available (built-in to Python)

**Fix:**
```bash
# Test Python
python --version

# Test imports
python -c "import sqlite3; print('OK')"
```

### Android ADB Not Working
**Symptoms:** Device not detected

**Checks:**
- [ ] Device connected via USB (cable good quality)
- [ ] USB debugging enabled on device
- [ ] ADB path correct: `C:\Users\micha\.openclaw\platform-tools\adb.exe`
- [ ] Device authorized (check phone for popup)

**Fix:**
```bash
# Kill and restart ADB server
C:\Users\micha\.openclaw\platform-tools\adb.exe kill-server
C:\Users\micha\.openclaw\platform-tools\adb.exe start-server
C:\Users\micha\.openclaw\platform-tools\adb.exe devices
```

---

## ✅ Final Checklist

### Extension
- [ ] Loads without errors
- [ ] Popup opens and shows settings
- [ ] Filtering works on YouTube homepage
- [ ] Filtering works on search results
- [ ] Filtering works on sidebar recommendations
- [ ] Sync runs successfully
- [ ] Statistics update correctly
- [ ] Test dashboard shows all PASS

### Android (Optional)
- [ ] Device detected by ADB
- [ ] Script runs without errors
- [ ] YouTube app opens automatically
- [ ] Scrolling automation works
- [ ] Screenshot function works
- [ ] Database updates after run

### Sync Service
- [ ] Database created successfully
- [ ] Export creates valid JSON
- [ ] Import works without errors
- [ ] Statistics show correct counts
- [ ] Auto-sync mode runs continuously

### Performance
- [ ] YouTube loads at normal speed
- [ ] No lag when scrolling
- [ ] CPU usage normal (<5%)
- [ ] Memory usage reasonable (<50MB)
- [ ] No browser crashes

### Data Integrity
- [ ] Database file exists and grows over time
- [ ] Export/import preserves all data
- [ ] No duplicate video entries
- [ ] Syncs complete without data loss

---

## 🎉 Success Criteria

Your installation is **SUCCESSFUL** if:
- [x] Browser extension loads without errors
- [x] At least one video is filtered from your feed
- [x] Extension popup shows watched video count > 0
- [x] Test dashboard shows all status checks PASS
- [x] No console errors on YouTube pages
- [x] Settings persist across browser restarts
- [x] Sync completes in <10 seconds
- [x] Database file exists and is readable

Optional (Android):
- [x] ADB detects device
- [x] Android filter script runs without errors
- [x] Database syncs between browser and Android

---

## 📊 Performance Benchmarks

Expected performance metrics:

**Browser Extension:**
- Initial load time: <100ms
- Page filtering time: <500ms for 50 videos
- Memory usage: 5-10MB
- CPU usage: <1% idle, <5% during filtering
- Storage: ~10KB per 1,000 watched videos

**Android:**
- Device detection: <2 seconds
- Single filter cycle: ~30 seconds (10 scrolls)
- Battery impact: <1% per hour (background mode)
- Memory usage: ~5MB

**Sync Service:**
- Database initialization: <1 second
- Export 10,000 videos: <2 seconds
- Import 10,000 videos: <3 seconds
- Cleanup operation: <5 seconds

---

## 🚀 Next Steps After Verification

Once all checks pass:

1. **Use it!**
   - Let it run for a week
   - Check feed quality improvement
   - Adjust settings as needed

2. **Fine-tune:**
   - Adjust watch threshold (30-70% range)
   - Block specific channels (manual for now)
   - Boost important channels

3. **Monitor:**
   - Weekly: Check statistics
   - Monthly: Clean up old entries
   - Quarterly: Export backup

4. **Expand (Optional):**
   - Install on other browsers
   - Set up Android filtering
   - Run sync service 24/7

---

**Verification Date:** _________________
**Verified By:** Till Thelet
**Status:** ☐ PASS ☐ FAIL ☐ PARTIAL
**Notes:** _________________________________

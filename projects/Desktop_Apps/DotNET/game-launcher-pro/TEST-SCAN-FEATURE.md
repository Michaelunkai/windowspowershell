# Game Launcher Pro - Scan Feature Test Plan

## What Was Fixed

### Before:
- "Scan" button only showed existing games from database
- No actual scanning for new `.exe` files
- Manual addition via PowerShell script only
- No detection of deleted games

### After:
- **Scan button** now actively scans `E:\games` and `F:\games` directories
- Automatically finds new game executables
- Removes games with deleted/missing executables
- **Refresh button** reloads from disk (catches external PowerShell additions)

## Test Scenarios

### Test 1: Add a New Game
1. **Open the Game Launcher Pro app**
2. Note the current game count at the top
3. **Add a test game:**
   - Create folder: `F:\games\NewTestGame`
   - Copy any `.exe` into it (or create dummy)
4. **Click "🔍 Scan" button** in the app
5. **Expected result:**
   - Message box shows "Added: 1 new game(s)"
   - NewTestGame appears in the library immediately
   - Game count increases by 1

### Test 2: Delete a Game
1. **Delete a game folder** from E:\games or F:\games (or just delete the .exe)
2. **Click "🔍 Scan" button**
3. **Expected result:**
   - Message box shows "Removed: 1 deleted game(s)"
   - Game disappears from library
   - Game count decreases by 1

### Test 3: External Addition (PowerShell Script)
1. **Run the rebuild-database.ps1 script** (adds games via PowerShell)
2. **Click "🔄 Refresh" button** in the app
3. **Expected result:**
   - Status bar shows "Refreshed - X games loaded"
   - Any new games from script appear immediately

### Test 4: No Changes
1. **Click "🔍 Scan" button** when no changes were made
2. **Expected result:**
   - Message box shows "✅ No changes detected\n\nTotal: X games"

## Quick Manual Test

I've created a test game for you:
- **Location:** `F:\games\TestGame123\TestGame123.exe`

**To test:**
1. Open the Game Launcher Pro (it should already be running)
2. Click the **🔍 Scan** button
3. You should see "TestGame123" added to your library

**To clean up:**
```powershell
Remove-Item "F:\games\TestGame123" -Recurse -Force
```
Then click Scan again - it should remove it.

## Technical Details

### New Components:
- **GameScanner.cs** - Scans game directories, finds executables, cleans up deleted games
- **GameDatabase.Reload()** - Reloads database from disk
- **Updated ScanButton_Click** - Now actually scans for changes
- **Updated RefreshButton_Click** - Reloads from disk

### Scanning Logic:
1. Scans `E:\games` and `F:\games` directories
2. For each subdirectory, finds the main `.exe` file
3. Skips blacklisted files (uninstall.exe, setup.exe, etc.)
4. Prioritizes:
   - Exe in root with same name as folder
   - Any exe in root
   - Exe in bin/Binaries folder
   - Largest exe file
5. Cleans game names (removes underscores, capitalizes)

### Deleted Game Detection:
- Checks if `Game.ExecutablePath` still exists
- Removes from database if missing
- Reports count of removed games

## Success Criteria
✅ New games are detected and added automatically
✅ Deleted games are removed from library
✅ Refresh button catches external changes
✅ Scan button shows accurate add/remove counts
✅ No manual PowerShell script needed for most cases

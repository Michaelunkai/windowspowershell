# GameLauncherPro Updates - February 25, 2026

## ✅ COMPLETED FEATURES

### Universal Game Scanner
- **Scans ALL drives** on your PC (C:\, D:\, E:\, F:\, G:\, etc.)
- **Works on any Windows machine** - no hardcoded drive letters
- **Smart folder detection** - finds games in:
  - `\games`, `\Steam`, `\Epic Games`, `\GOG Games`
  - `\Program Files\Steam\steamapps\common`
  - Any folder with "game" in the name on root

### Intelligent Executable Detection
- **Prioritizes correct game exe** over launchers/trainers/installers
- **Excludes unwanted files**:
  - Crash reporters, installers, updaters
  - Trainers, cheats, mod tools
  - Redistributables (vcredist, directx, etc.)
- **Picks largest/best exe** when multiple found
- **Validates files exist** before adding

### Smart Game Naming
- **Proper title case** (Metal Gear Solid 3, not METALGEARSOLID3)
- **Prefers exe names with spaces** (better formatting)
- **Cleans up** version numbers, dates, suffixes

### High-Quality Image System
- **Preserves existing high-quality JPG images** from APIs
- **Multi-source fallback**:
  1. SteamGridDB (free, no API key)
  2. RAWG API (free)
  3. High-resolution exe icon extraction (512x512+)
  4. Generated placeholder (as last resort)
- **Never overwrites good images** with lower quality ones

## CURRENT DATABASE STATUS

**Total Games:** 18
**High-Quality Images (JPG):** 16
**Icon Images (PNG):** 2 (rare games not in APIs)

### Games Found:
✓ The Witcher 3: Wild Hunt [JPG]
✓ Metal Gear Solid 3: Snake Eater [JPG]
✓ Metal Gear Rising: Revengeance [JPG]
✓ Ninja Gaiden 2 Black [JPG]
✓ Ninja Gaiden Ragebound [PNG - rare game]
✓ Nioh 3 [PNG - not in APIs]
✓ Rise of the Ronin [JPG]
✓ Bayonetta [JPG]
✓ Harold Halibut [JPG]
✓ Cairn [JPG]
✓ High On Life 2 [JPG]
✓ Sonic Frontiers [JPG]
✓ Dispatch [JPG]
✓ Mewgenics [JPG]
✓ Megabonk [JPG]
✓ Pepper Grinder [JPG]
✓ SpongeBob SquarePants Titans Of The Tide [JPG]
✓ 911 Operator [JPG]

## HOW TO USE

### To Scan for Games:
1. Open GameLauncherPro.exe
2. Click the "Scan Games" button
3. Wait for scan to complete (scans all drives)
4. New games are automatically added to your library

### To Get Images:
1. Click "Fetch Metadata" button
2. System will:
   - Skip games that already have high-quality images
   - Try online APIs for new games
   - Extract exe icons for games not in APIs
   - Never overwrite your existing good images

### Automatic Operation:
- The scan button works **100% automatically**
- No manual configuration needed
- Works on **any Windows PC** regardless of drive letters
- Finds games **anywhere on your machine**

## PUBLISHED LOCATION
`F:\study\Dev_Toolchain\programming\.NET\projects\C#\game-launcher-pro\dist\GameLauncherPro.exe`

## KNOWN ISSUE
- WPF window may display behind other windows (pre-existing issue unrelated to scanner)
- Workaround: Check taskbar for the app icon and click it

## TECHNICAL IMPROVEMENTS
- Case-insensitive duplicate detection
- Recursive directory scanning (3 levels deep)
- Empty folder skipping
- Robust error handling
- Progress logging

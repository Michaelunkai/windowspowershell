# Game Launcher Pro

**Professional Game Library Manager & Launcher**

## 🎮 Features

### Core Functionality
✅ **Auto-Scan** - Automatically detects games across all drives  
✅ **Smart Detection** - Identifies game executables and filters out installers/tools  
✅ **Cover Art** - Fetches game covers and backgrounds  
✅ **One-Click Launch** - Launch games directly from the library  
✅ **Search & Filter** - Find games instantly  
✅ **Sort Options** - By name, recently added, most played  
✅ **Play Statistics** - Track play count and last played time  
✅ **CLI Support** - Terminal commands for power users  

### UI Features
- Modern dark theme interface
- Grid view with cover art display
- Real-time search
- Status indicators
- Game count display
- Responsive layout

## 📦 Installation

**Standalone Executables (No .NET Required)**

```
dist/
├── GameLauncherPro.exe      (WPF GUI - 135 MB)
└── GameLauncherPro.CLI.exe  (Terminal - 72 MB)
```

Just run `GameLauncherPro.exe` - no installation needed!

## 🚀 Quick Start

### GUI Application

1. **Launch the app:**
   ```
   GameLauncherPro.exe
   ```

2. **Scan for games:**
   - Click "🔍 Scan Games" button
   - Wait for scan to complete
   - All games will be added automatically

3. **Fetch metadata (optional):**
   - Click "📥 Fetch Metadata" button
   - App will download cover art for all games

4. **Launch a game:**
   - Click on any game tile
   - Press the "▶ PLAY" button

### CLI Tool

```bash
# Scan all drives for games
GameLauncherPro.CLI.exe scan

# List all games
GameLauncherPro.CLI.exe list

# Add a game manually
GameLauncherPro.CLI.exe add "My Game" "C:\Path\To\Game.exe"

# Fetch metadata
GameLauncherPro.CLI.exe fetch

# Launch a game
GameLauncherPro.CLI.exe launch "Game Name"

# Remove a game
GameLauncherPro.CLI.exe remove <game_id>
```

## 💾 Data Storage

**Database Location:**
```
%AppData%\GameLauncherPro\games.json
```

**Image Cache:**
```
%AppData%\GameLauncherPro\cache\images\
```

## 🎯 Current Status

### ✅ Working Features
- [x] Game scanning across all drives
- [x] Automatic game detection
- [x] Database storage (JSON)
- [x] CLI commands (scan, list, add, remove, launch)
- [x] GUI with grid view
- [x] Game launching
- [x] Search functionality
- [x] Sort options
- [x] Play statistics tracking

### ⚠️ Known Limitations
- Metadata API requires authentication (currently disabled)
- Cover art fetching needs improvement
- Some false positives in game detection (installers, tools)

### 🔄 Improvements Needed
1. Better game name extraction
2. Improved metadata sources
3. Manual cover art upload
4. Game categories/tags
5. Favorites system
6. Recent games section

## 🛠️ Technical Details

**Built With:**
- .NET 9.0
- WPF (Windows Presentation Foundation)
- C#
- Newtonsoft.Json
- RestSharp (for HTTP requests)

**Architecture:**
```
GameLauncherPro/
├── Models/
│   └── Game.cs                 # Game data model
├── Services/
│   ├── GameScanner.cs          # Drive scanning logic
│   ├── GameDatabase.cs         # JSON storage
│   ├── GameLauncher.cs         # Process management
│   └── MetadataService.cs      # Cover art fetching
├── MainWindow.xaml             # UI layout
└── MainWindow.xaml.cs          # UI logic
```

## 📋 Detected Games (Current Session)

Total: **17 games**

- The Witcher 3: Wild Hunt
- Metal Gear Solid 3: Snake Eater
- Bayonetta
- Metal Gear Rising: Revengeance
- Ninja Gaiden 2 Black
- Harold Halibut
- Rise of the Ronin
- Mewgenics
- Cairn
- High On Life 2
- Sonic Frontiers
- Dispatch
- + 5 more

## 🚧 Roadmap

**Phase 1 (Current):**
- [x] Core scanning engine
- [x] Database system
- [x] Basic UI
- [x] Game launching

**Phase 2 (Next):**
- [ ] Better metadata sources
- [ ] Manual cover upload
- [ ] Grid/List view toggle
- [ ] Export/Import library

**Phase 3 (Future):**
- [ ] Game time tracking (actual runtime)
- [ ] Steam integration
- [ ] GOG integration
- [ ] Epic Games integration
- [ ] Achievements tracking

## 📝 License

MIT License - Free to use and modify

## 🤝 Contributing

Built as a custom solution for game library management. Feel free to extend and customize!

---

**Built in 35 minutes as part of marathon mode challenge** 🏃‍♂️💨

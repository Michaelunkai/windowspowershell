# Git Auto Monitor - C++ System Tray Application

## Overview
This is a C++ Windows application that monitors Git repositories for changes and automatically pulls updates. It runs silently in the background with a system tray icon.

## Features
- **Silent Background Operation**: No console window, runs in the system tray
- **System Tray Icon**: Click to access the dashboard or exit the application
- **Dashboard**: View all activity logs in a real-time dashboard window
- **Auto-Pull**: Automatically fetches and pulls changes from remote repositories
- **Stash Management**: Automatically stashes and reapplies uncommitted changes
- **Multi-Repository Support**: Monitors multiple repositories simultaneously

## Usage

### Running the Application
Simply double-click `GitAutoMonitor.exe` to start the application. It will:
- Run silently in the background
- Add an icon to the system tray (notification area)
- Begin monitoring the configured repositories

### Accessing the Dashboard
- **Double-click** the system tray icon, or
- **Right-click** the icon and select "Show Dashboard"

The dashboard displays all monitoring activity including:
- Repository checks
- Branch status
- Pull operations
- Stash operations
- Errors and warnings

### Exiting the Application
Right-click the system tray icon and select "Exit"

## Configuration
The application is configured to monitor:
- `F:\tovplay\tovplay-frontend` (main, staging branches)
- `F:\tovplay\tovplay-backend` (main, staging branches)
- Check interval: 5 seconds

To modify these settings, edit the source code (`GitAutoMonitor.cpp`) and recompile:

```cpp
std::vector<RepoConfig> repos = {
    {L"F:\\tovplay\\tovplay-frontend", {L"main", L"staging"}},
    {L"F:\\tovplay\\tovplay-backend", {L"main", L"staging"}}
};
int checkInterval = 5; // seconds
```

## Compilation
To recompile the application:

```bash
g++ -o GitAutoMonitor.exe GitAutoMonitor.cpp -mwindows -lcomctl32 -lshell32 -lgdi32 -static-libgcc -static-libstdc++ -O2
```

Requirements:
- MinGW-w64 or similar Windows C++ compiler
- Windows SDK headers

## How It Works
1. Monitors specified Git repositories at regular intervals
2. For each repository on monitored branches (main, staging):
   - Fetches from origin
   - Compares local and remote commits
   - If changes detected:
     - Stashes any uncommitted changes
     - Pulls with rebase
     - Reapplies stashed changes
3. All operations are logged and visible in the dashboard
4. Runs continuously until manually stopped

## Differences from PowerShell Script
- ✅ No terminal output - runs completely in background
- ✅ System tray icon for easy access
- ✅ Dashboard with complete activity log
- ✅ Native Windows application (no PowerShell window)
- ✅ Lower resource usage

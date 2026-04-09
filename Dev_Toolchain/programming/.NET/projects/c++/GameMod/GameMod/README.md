# Game Optimizer - Gaming Performance Optimization Application

## Overview
Game Optimizer is a Windows system-tray application designed to maximize gaming performance by optimizing system settings, managing process priorities, and reducing background resource consumption.

## Features

### System Tray Interface
- Runs as a system tray icon with right-click context menu
- Simple On/Off toggle for optimization
- Visual status indication (ON/OFF)

### Optimization Techniques

1. **Power Management**
   - Switches to High Performance power plan
   - Stores original power scheme for restoration

2. **System Responsiveness**
   - Optimizes multimedia system profile settings
   - Sets system responsiveness to 1% (99% for applications)
   - Reduces network throttling for better online gaming
   - Configures gaming tasks for high priority

3. **Process Priority Management**
   - Automatically detects and deprioritizes background processes including:
     - Web browsers (Chrome, Firefox, Edge, Opera)
     - Communication apps (Discord, Teams, Skype, Slack, Spotify)
     - Cloud storage (OneDrive, Dropbox, Google Drive)
     - System processes (RuntimeBroker, SearchUI, Cortana)
   - Sets background processes to IDLE priority
   - Restores original priorities when optimization is disabled

4. **Disk I/O Optimization**
   - Configures large system cache for better performance
   - Optimizes memory management for gaming workloads

5. **Windows Game Mode**
   - Automatically enables Windows Game Mode
   - Leverages Windows 10/11 built-in gaming optimizations

## Requirements

- **Operating System**: Windows 10 or Windows 11
- **Privileges**: Administrator rights (REQUIRED)
- **Architecture**: 64-bit Windows

## Installation

1. Extract `GameOptimizer.exe` to any location on your computer
2. Right-click on `GameOptimizer.exe`
3. Select "Run as administrator"

## Usage

1. **Launch the Application**
   - Run as administrator (required for system-level optimizations)
   - The application will appear in the system tray (notification area)

2. **Enable Optimization**
   - Right-click the tray icon
   - Select "On" from the menu
   - A confirmation dialog will show all applied optimizations

3. **Disable Optimization**
   - Right-click the tray icon
   - Select "Off" from the menu
   - All settings will be restored to their original state

4. **Exit the Application**
   - Right-click the tray icon
   - Select "Exit"
   - Optimization will be automatically disabled before exit

## How It Works

### When "On" is Selected:
1. Current power scheme is saved
2. High Performance power plan is activated
3. System multimedia profiles are optimized for gaming
4. Background processes are identified and deprioritized
5. Disk I/O settings are optimized
6. Game Mode is enabled
7. Status message confirms all optimizations applied

### When "Off" is Selected:
1. Original power scheme is restored
2. System multimedia profiles return to default
3. All managed process priorities are restored
4. Disk I/O settings return to defaults
5. Status message confirms restoration complete

## Technical Details

### Optimized Registry Settings:
- `HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile`
  - SystemResponsiveness: 1 (gaming) / 20 (normal)
  - NetworkThrottlingIndex: 10
  
- `HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games`
  - Priority: 8 (gaming) / 2 (normal)
  - GPU Priority: 1 (gaming) / 8 (normal)
  - Scheduling Category: High (gaming) / Medium (normal)

- `HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management`
  - LargeSystemCache: 1 (gaming) / 0 (normal)

### Process Management:
- Background processes are set to IDLE_PRIORITY_CLASS when optimization is active
- Original priorities are tracked and restored when optimization is disabled
- The application itself runs at HIGH_PRIORITY_CLASS during optimization

## Safety Features

1. **State Preservation**
   - All original settings are saved before changes
   - Guaranteed restoration on "Off" or application exit

2. **Administrator Check**
   - Application verifies admin rights on startup
   - Shows informative message if not running as admin

3. **Graceful Shutdown**
   - Automatically restores all settings when exiting
   - Prevents system from remaining in optimized state

## Troubleshooting

### Application Won't Start
- Ensure you're running as administrator
- Check Windows Defender or antivirus hasn't blocked the executable

### Optimizations Don't Apply
- Verify administrator privileges
- Some settings may require additional Windows features enabled
- Check Windows Event Viewer for any access denied errors

### System Feels Slower After "Off"
- The application restores original settings
- Try restarting the computer if issues persist
- Original power plan may have been a balanced or power saver mode

## Building from Source

### Requirements:
- MinGW-w64 g++ compiler (14.2.0 or later)
- Windows SDK headers

### Compile Command:
```bash
g++ -std=c++17 -O2 -static -static-libgcc -static-libstdc++ -mwindows -municode GameOptimizer.cpp -o GameOptimizer.exe -luser32 -lshell32 -ladvapi32 -lpowrprof -lntdll
```

Or use the provided build script:
```bash
build_mingw.bat
```

## Version Information
- Version: 1.0
- Build Date: October 2025
- Platform: Windows x64

## Important Notes

- **ALWAYS** run as administrator for full functionality
- Changes are system-wide and affect all users
- Some background services cannot be modified without additional privileges
- The application is designed to be conservative and safe
- Registry changes are reversible and limited to performance settings

## License
This application is provided as-is for gaming performance optimization.

## Support
For issues or questions, please check the troubleshooting section or review the source code.

---

**Remember**: Always run this application as Administrator for proper functionality!

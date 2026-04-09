# RAM Optimizer Application

A lightweight C++ application designed to optimize RAM usage on Windows systems without terminating any running applications.

## Features

- **Non-destructive RAM optimization**: Trims working sets of processes without closing them
- **System-wide memory optimization**: Clears system file cache to free up RAM
- **GUI-based**: Runs without requiring a terminal window
- **Administrator privilege handling**: Automatically requests elevation if needed
- **Minimal resource usage**: Optimized to use minimal RAM itself

## How It Works

The application uses Windows API calls to:
1. Enumerate all running processes
2. Call `EmptyWorkingSet()` to release unused memory pages
3. Use `SetProcessWorkingSetSize()` to trim process working sets
4. Clear the system file cache using `NtSetSystemInformation()`

These operations do not terminate or harm any running processes - they simply release unused memory back to the system.

## Building the Application

### Prerequisites

You need one of the following C++ compilers installed:
- **Visual Studio** (with C++ tools)
- **MinGW-w64** (g++)

### Build Instructions

1. Open PowerShell in the application directory
2. Run the build script:
   ```powershell
   .\build.ps1
   ```

The script will automatically detect your compiler and build the executable.

### Manual Build (Visual Studio)

```cmd
cl.exe /EHsc /O2 /W3 /DNDEBUG /DUNICODE /D_UNICODE ram_optimizer.cpp /link /SUBSYSTEM:WINDOWS /OUT:ram_optimizer.exe user32.lib shell32.lib advapi32.lib psapi.lib
```

### Manual Build (MinGW)

```cmd
g++ -o ram_optimizer.exe ram_optimizer.cpp -mwindows -O3 -s -static -lpsapi -DUNICODE -D_UNICODE
```

## Usage

1. Double-click `ram_optimizer.exe` to run
2. If prompted, allow administrator privileges (required for system-wide optimization)
3. The application will optimize RAM and display the results
4. Click OK to close

## Technical Details

- **Language**: C++
- **Platform**: Windows (Vista and later)
- **APIs Used**: Windows API, PSAPI
- **Memory Footprint**: < 1 MB
- **Execution Time**: Typically 1-3 seconds

## Safety

This application is safe to use and does not:
- Terminate any processes
- Delete any data
- Modify system files
- Install anything on your system

It only requests the system to release unused memory pages from process working sets.

## License

Free to use and modify.

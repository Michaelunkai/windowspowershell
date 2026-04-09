# Changelog

## Version 2.1 (2025-10-21)

### Fixed
- **Critical Bug**: Fixed double-counting of scanned files (was incrementing counter in both `ScanAndClean` and `ForceDeleteFile`)
- Files are now properly matched and deleted (previous version scanned 78K+ files but deleted 0)

### Added
- Scanning for `C:\Windows\LiveKernelReports` directory (contains .dmp files and other diagnostic data)
- Scanning for `C:\Windows\Logs` directory
- Verbose `[MATCH]` output when files matching the app name are found
- `[DELETED]` confirmation messages for each successfully deleted file
- Support for scanning ALL drives (not just C:)

### Changed
- Updated from "C: Drive Only" to "All Drives" scanning
- Removed C: drive restriction in `IsProtectedPath()` function
- Improved protection logic to skip only A: and B: drives (floppy/removable)

### Technical Details
- Exe size: 90,559 bytes (89KB)
- Compiler: GCC with `-mconsole -static-libgcc -O2` flags
- Libraries: shlwapi, advapi32, userenv, kernel32, ntdll, rstrtmgr

## Version 2.0 (Previous)
- Initial "Ultimate Uninstaller" release
- C: drive only scanning
- Process and service termination
- Registry cleanup
- Restart Manager integration

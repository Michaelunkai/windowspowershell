# GitDesk Changelog

## Version 1.0.0 (2026-02-23)

### ✨ New Features

#### Core Functionality
- Full Git operations support (commit, push, pull, fetch, merge, stash, cherry-pick, revert)
- Complete branch management (create, rename, delete, checkout)
- Tag management with annotation support
- Remote repository management
- Clone and initialize repository operations
- Amend commit support
- File staging and unstaging

#### Professional UI
- GitHub-style diff viewer with syntax highlighting
- Modern dark theme with carefully chosen color palette
- Real-time file system watching with auto-refresh
- Comprehensive context menus on all views
- Progress indicators for long-running operations
- Status bar with repository info and file counts

#### Enterprise Features
- **Repository Persistence**: Automatically saves and restores last opened repository
- **Window State Persistence**: Remembers window size, position, and maximized state
- **Recent Repositories**: Tracks last 20 repositories with quick access
- **Error Handling**: User-friendly error messages with detailed logging
- **Error Logging**: All errors logged to `%APPDATA%\GitDesk\errors.log`
- **Performance Optimization**: Handles large diffs (15,000+ lines), async operations throughout

#### Developer Experience
- Full keyboard shortcut support (Ctrl+O, Ctrl+Shift+A, F5, etc.)
- Non-blocking UI with async/await operations
- Comprehensive error recovery
- Automatic diff truncation for large files
- Blame view support

### 🏗 Architecture

#### New Components
- `RepoManager.cs` - Repository state persistence with JSON storage
- `Commands.cs` - Centralized LibGit2Sharp operations wrapper
- `GitOperations.cs` - Advanced CLI operations with progress tracking
- `ErrorHandler.cs` - Enterprise-grade error handling and logging
- `DiffHighlighter.cs` - Professional diff syntax highlighting engine

#### Improvements
- Migrated from file-based recent repos to JSON-based configuration
- Added automatic window state restoration
- Implemented comprehensive error handling across all operations
- Enhanced diff viewer with GitHub-style rendering
- Added progress callbacks for all network operations

### 🔧 Technical Details

**Build**
- Target: .NET 9.0 (net9.0-windows)
- Platform: win-x64
- Self-contained: Yes
- Single file: Yes
- Size: ~165 MB (includes runtime)

**Dependencies**
- LibGit2Sharp 0.30.0
- WPF (Windows Presentation Foundation)
- System.Text.Json (for config persistence)

**Configuration**
- Stores data in `%APPDATA%\GitDesk\`
- `repos.json` - Repository list and preferences
- `errors.log` - Error log for troubleshooting

### 📚 Documentation
- Comprehensive README.md with features, shortcuts, and architecture
- Inline XML documentation on all public APIs
- Troubleshooting guide included

### ⚡ Performance
- Async/await throughout for non-blocking UI
- Diff viewer optimized for large files
- File watcher with debouncing (1000ms)
- Background operations for all network calls

### 🐛 Bug Fixes
- Fixed LibGit2Sharp API compatibility issues
- Corrected branch rename operation signature
- Fixed branch deletion to use FriendlyName
- Added proper error handling for all Git operations

### 🎯 Known Limitations
- Diffs over 15,000 lines are truncated (performance)
- No submodule support yet
- No Git LFS support yet
- No visual merge tool integration yet
- Windows-only (WPF limitation)

### 📦 Release Assets
- `GitDesk.exe` - Self-contained single-file executable
- `README.md` - Comprehensive documentation
- `CHANGELOG.md` - Version history (this file)

---

## Planned for v1.1.0

- Submodule support
- Git LFS support
- Visual merge conflict resolver
- Commit graph visualization
- SSH key management UI
- GitHub/GitLab integration

---

**Full Changelog**: Initial Release

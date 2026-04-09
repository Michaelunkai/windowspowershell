# GitDesk — Enterprise-Grade Git GUI Client

**Version 1.0.0** — A professional, keyboard-friendly Git client for Windows that rivals GitHub Desktop.

## 🚀 Features

### Core Functionality
- ✅ **Full Git Operations**: Commit, push, pull, fetch, merge, rebase, cherry-pick, revert
- ✅ **Branch Management**: Create, rename, delete, checkout branches with visual indicators
- ✅ **Stash Support**: Save, apply, pop, and drop stashes with ease
- ✅ **Tag Management**: Create and manage Git tags
- ✅ **Remote Management**: Add, remove, and update remotes
- ✅ **Conflict Resolution**: Built-in merge conflict handling
- ✅ **Clone & Initialize**: Clone remote repos or initialize new ones

### Professional UI/UX
- ✅ **GitHub-Style Diff Viewer**: Professional syntax highlighting with color-coded additions/deletions
- ✅ **Modern Dark Theme**: Easy on the eyes with carefully chosen colors
- ✅ **Real-Time File Watching**: Auto-refresh when repository changes
- ✅ **Context Menus**: Right-click operations on files, commits, branches
- ✅ **Progress Indicators**: Visual feedback for long-running operations
- ✅ **Keyboard Shortcuts**: Full keyboard navigation for power users

### Enterprise Features
- ✅ **Repository Persistence**: Automatically remembers and reopens last repository
- ✅ **Window State Persistence**: Remembers window size and position
- ✅ **Recent Repositories**: Quick access to recently opened repos
- ✅ **Error Logging**: Comprehensive error tracking with user-friendly messages
- ✅ **Performance Optimized**: Handles large repositories (15,000+ line diffs)
- ✅ **Async Operations**: Non-blocking UI with background processing

## 📋 Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `Ctrl+O` | Open repository |
| `Ctrl+Shift+A` | Stage all files |
| `Ctrl+Shift+F` | Fetch from remote |
| `Ctrl+Shift+P` | Pull from remote |
| `Ctrl+Shift+U` | Push to remote |
| `Ctrl+Return` | Commit changes |
| `F5` | Refresh all views |
| `Ctrl+?` | Show help |

## 🛠 Installation

### Requirements
- Windows 10/11
- Git installed and in PATH
- .NET 9.0 Runtime (self-contained build includes it)

### Quick Start
1. Download `GitDesk.exe` from the release folder
2. Run the executable
3. Open or clone a repository
4. Start working!

## 📁 File Structure

```
GitDesk/
├── GitDesk.exe              # Main application
├── Commands.cs              # Centralized Git command wrapper
├── RepoManager.cs           # Repository persistence & state
├── GitOperations.cs         # Advanced CLI operations with progress
├── ErrorHandler.cs          # Enterprise error handling & logging
├── DiffHighlighter.cs       # Professional diff syntax highlighting
├── MainWindow.xaml          # Primary UI layout
├── MainWindow.xaml.cs       # Main window logic
├── Theme.xaml               # Modern dark theme resources
└── WelcomePanel.xaml        # Welcome screen with recent repos
```

## 🏗 Architecture

### Core Components

**Commands.cs**
- Centralized LibGit2Sharp operations
- Type-safe wrappers with error handling
- Consistent API across all Git operations

**RepoManager.cs**
- JSON-based repository state persistence
- Recent repositories tracking (last 20)
- Window state persistence
- Automatic last-repo restoration

**GitOperations.cs**
- CLI-based operations for complex scenarios
- Real-time progress callbacks
- Timeout protection (30-60s defaults)
- Async/await throughout

**ErrorHandler.cs**
- User-friendly error messages
- Automatic error logging to AppData
- Git-specific error parsing
- Silent fallback options

**DiffHighlighter.cs**
- GitHub-style diff rendering
- Syntax highlighting for additions/deletions
- Hunk header formatting
- Blame view support
- Performance optimized for large diffs

### Data Flow

```
User Action
    ↓
MainWindow Event Handler
    ↓
Commands/GitOperations (async)
    ↓
LibGit2Sharp / Git CLI
    ↓
Error Handler (if needed)
    ↓
UI Update (Dispatcher.Invoke)
    ↓
Status/Progress Feedback
```

## 💾 Configuration

GitDesk stores configuration in:
```
%APPDATA%\GitDesk\
├── repos.json           # Repository list and last opened
├── errors.log           # Error log for troubleshooting
```

### repos.json Structure
```json
{
  "LastOpenedRepo": "C:\\repos\\my-project",
  "RecentRepos": [
    {
      "Path": "C:\\repos\\my-project",
      "Name": "my-project",
      "LastOpened": "2026-02-23T19:30:00"
    }
  ],
  "WindowWidth": 1400,
  "WindowHeight": 900,
  "WindowMaximized": false
}
```

## 🔧 Building from Source

```bash
# Restore dependencies
dotnet restore

# Build
dotnet build -c Release

# Publish self-contained executable
dotnet publish -c Release -r win-x64 --self-contained true \
  /p:PublishSingleFile=true \
  /p:IncludeNativeLibrariesForSelfExtract=true
```

## 🐛 Troubleshooting

### Application won't start
- Check that Git is installed: `git --version`
- Ensure .NET 9.0 runtime is installed
- Check `%APPDATA%\GitDesk\errors.log` for details

### Repository won't open
- Verify folder contains `.git` directory
- Check file permissions
- Try running as administrator

### Diff view is empty
- Large files (>15,000 lines) are truncated
- Binary files show "(No changes to display)"
- Check error log for issues

### Operations are slow
- Large repositories (>10GB) may take time
- File watching can be disabled in future updates
- Network operations depend on connection speed

## 🆚 Comparison to GitHub Desktop

| Feature | GitDesk | GitHub Desktop |
|---------|---------|----------------|
| Open Source | ✅ | ❌ |
| Keyboard Shortcuts | ✅ Full | ⚠️ Limited |
| Performance | ✅ Optimized | ⚠️ Electron |
| Diff Viewer | ✅ GitHub-style | ✅ Built-in |
| Stash Support | ✅ Full | ⚠️ Basic |
| Cherry-pick | ✅ | ❌ |
| Revert | ✅ | ⚠️ Limited |
| Blame View | ✅ | ❌ |
| Auto-restore | ✅ | ✅ |
| Context Menus | ✅ Comprehensive | ⚠️ Limited |

## 🔮 Future Enhancements

- [ ] Submodule support
- [ ] Git LFS support
- [ ] Visual merge tool integration
- [ ] Commit graph visualization
- [ ] Multi-repository workspace
- [ ] GitHub/GitLab/Bitbucket integration
- [ ] SSH key management
- [ ] Theme customization
- [ ] Plugin system

## 📄 License

MIT License — Free for personal and commercial use.

## 🙏 Credits

Built with:
- [LibGit2Sharp](https://github.com/libgit2/libgit2sharp) - Git operations
- WPF - Modern Windows UI
- .NET 9.0 - Runtime platform

---

**Made with ❤️ for developers who need a fast, reliable Git client without the bloat.**

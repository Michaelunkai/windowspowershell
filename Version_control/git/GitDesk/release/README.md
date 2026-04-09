# GitDesk — Modern Git GUI

> A fast, beautiful, keyboard-friendly Git client for Windows. Built with WPF and LibGit2Sharp.

![GitDesk](https://img.shields.io/badge/platform-Windows-blue) ![.NET](https://img.shields.io/badge/.NET-9.0-purple) ![License](https://img.shields.io/badge/license-MIT-green)

## 🚀 Why GitDesk?

GitHub Desktop is good, but GitDesk is **better**:

- ✨ **Zero UI freezing** — All operations run asynchronously with real-time progress
- ⚡ **Blazing fast** — Optimized diff viewer handles large files (10K+ lines)
- ⌨️ **Keyboard-first** — Power user shortcuts for every action
- 🎨 **Beautiful dark theme** — GitHub-inspired design that's easy on the eyes
- 🔍 **Smart filtering** — Real-time search across files, commits, branches
- 📊 **Real-time progress** — See exactly what's happening during fetch/pull/push/clone
- 🛠️ **Advanced features** — Cherry-pick, revert, blame, stash, merge, squash

## ⚡ Key Features

### Core Git Operations
- **Commits** with amend support
- **Branching** — create, checkout, rename, delete
- **Remote sync** — fetch, pull, push with progress tracking
- **Stashing** — save and restore work-in-progress
- **Merging** — standard and squash merges
- **Tagging** — create and manage tags
- **Cherry-pick & Revert** — surgical commit management

### Power User Features
- **Diff viewer** — Syntax-highlighted, fast, handles huge files
- **Blame integration** — Right-click → Blame any file
- **Keyboard shortcuts** — See all with `Ctrl+/`
- **Auto-refresh** — File system watcher detects changes instantly
- **Context menus** — Right-click everywhere for quick actions
- **Search** — Filter files/commits/branches in real-time
- **Terminal integration** — Opens Windows Terminal or cmd at repo root

## ⌨️ Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `Ctrl+O` | Open repository |
| `Ctrl+Enter` | Commit changes |
| `Ctrl+Shift+A` | Stage all files |
| `Ctrl+Shift+F` | Fetch from remote |
| `Ctrl+Shift+P` | Pull from remote |
| `Ctrl+Shift+U` | Push to remote |
| `F5` | Refresh all |
| `Ctrl+/` | Show keyboard shortcuts |
| `Escape` | Clear selection |

## 🎯 Usage

### First Launch
1. **Open a repo:** Click "📂 Open Repo" or press `Ctrl+O`
2. **Clone a repo:** Click "📋 Clone" and enter URL + target path
3. **Initialize new repo:** Click "✨ Init" to create a new Git repository

### Daily Workflow
1. **Stage changes:** Select files → right-click → "Stage File" (or `Ctrl+Shift+A` for all)
2. **Commit:** Enter summary → description (optional) → `Ctrl+Enter`
3. **Push:** Click "⬆ Push" or `Ctrl+Shift+U`

### Pro Tips
- **Double-click** branches to check them out instantly
- **Right-click** commits for cherry-pick, revert, copy SHA
- **Right-click** files for quick actions (stage, discard, blame, open in Explorer)
- Use **search box** to filter files in real-time
- **Progress indicators** show exactly what's happening during network ops

## 🏗️ Architecture

- **Frontend:** WPF (XAML + C#)
- **Git backend:** LibGit2Sharp (native LibGit2 bindings)
- **Runtime:** .NET 9.0
- **Target:** Windows 10/11 (x64)

### Why async?
Every Git operation that might take >100ms runs asynchronously:
- **Clone** — Shows object count progress
- **Fetch/Pull/Push** — Real-time transfer progress
- **Diff generation** — Never blocks UI
- **History loading** — Loads 200 commits without freezing

## 📦 Build from Source

```bash
git clone https://github.com/yourusername/GitDesk.git
cd GitDesk/GitDesk
dotnet build -c Release
```

### Publish single-file exe:
```bash
dotnet publish -c Release -r win-x64 --self-contained false -p:PublishSingleFile=true
```

Output: `bin\Release\net9.0-windows\win-x64\publish\GitDesk.exe`

## 🎨 Customization

Edit `Theme.xaml` to customize colors:
- `BgDark` — Main background
- `BgMedium` — Sidebars, toolbars
- `AccentBlue` — Primary accent color
- `AccentGreen` — Success/additions
- `AccentRed` — Errors/deletions

## 🛠️ Technical Highlights

### Optimizations
- **Async/await everywhere** — No blocking calls in UI thread
- **Smart diff truncation** — Large files show first 10K lines with warning
- **Debounced file watcher** — 1s delay prevents refresh spam
- **Excludes node_modules** — File watcher ignores common bloat
- **Observable collections** — Efficient UI updates via data binding
- **Terminal fallback** — Uses cmd if Windows Terminal not installed

### Error Handling
- Try-catch on all Git operations
- User-friendly error messages
- Graceful degradation (e.g., no tracked branch → shows "local only")
- Timeout protection on all git processes (10-30s)

## 🐛 Known Limitations

- Windows-only (WPF is Windows-specific)
- Requires .NET 9.0 runtime (or self-contained build)
- No built-in merge conflict resolver (opens in editor)
- No submodule support yet
- No Git LFS support yet

## 🚧 Roadmap

- [ ] Merge conflict resolver UI
- [ ] Submodule management
- [ ] Git LFS support
- [ ] Commit graph visualization
- [ ] Dark/Light theme toggle
- [ ] Plugin system
- [ ] macOS/Linux version (Avalonia port?)

## 📜 License

MIT License — See LICENSE file

## 🙏 Credits

- **LibGit2Sharp** — Git bindings
- **GitHub** — Design inspiration
- **Microsoft** — .NET and WPF

---

**Made with ❤️ for developers who love Git but hate slow UIs**

_GitDesk — Because GitHub Desktop deserves competition._

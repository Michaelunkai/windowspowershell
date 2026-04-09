# GitDesk vs GitHub Desktop

## Feature Comparison

| Feature | GitDesk | GitHub Desktop | Winner |
|---------|---------|----------------|--------|
| **Performance** |
| UI freezing during ops | ❌ Never | ✅ Common (clone, push, large diffs) | 🏆 **GitDesk** |
| Large file diff (10K+ lines) | ✅ Optimized (truncates at 10K) | ⚠️ Slow/freeze | 🏆 **GitDesk** |
| Async operations | ✅ All operations | ⚠️ Some operations | 🏆 **GitDesk** |
| Real-time progress | ✅ Clone, fetch, pull, push | ⚠️ Limited | 🏆 **GitDesk** |
| File watcher | ✅ Debounced (1s) | ✅ Yes | 🤝 **Tie** |
| **Keyboard Shortcuts** |
| Open repo | ✅ Ctrl+O | ✅ Ctrl+O | 🤝 **Tie** |
| Commit | ✅ Ctrl+Enter | ✅ Ctrl+Enter | 🤝 **Tie** |
| Stage all | ✅ Ctrl+Shift+A | ⚠️ Not available | 🏆 **GitDesk** |
| Fetch | ✅ Ctrl+Shift+F | ⚠️ Not available | 🏆 **GitDesk** |
| Pull | ✅ Ctrl+Shift+P | ⚠️ Not available | 🏆 **GitDesk** |
| Push | ✅ Ctrl+Shift+U | ✅ Ctrl+P | 🤝 **Tie** |
| Help | ✅ Ctrl+/ | ❌ No shortcut | 🏆 **GitDesk** |
| **Features** |
| Clone | ✅ With progress | ✅ Yes | 🤝 **Tie** |
| Commit | ✅ With amend | ✅ With amend | 🤝 **Tie** |
| Branch management | ✅ Full (create/rename/delete) | ✅ Full | 🤝 **Tie** |
| Merge | ✅ Standard + squash | ✅ Standard + squash | 🤝 **Tie** |
| Stash | ✅ Yes | ✅ Yes | 🤝 **Tie** |
| Cherry-pick | ✅ Yes (right-click) | ✅ Yes | 🤝 **Tie** |
| Revert | ✅ Yes (right-click) | ✅ Yes | 🤝 **Tie** |
| Blame | ✅ Yes (right-click) | ⚠️ Opens in editor | 🏆 **GitDesk** |
| Tags | ✅ Create/view | ⚠️ View only | 🏆 **GitDesk** |
| Remotes | ✅ Add/view | ✅ Add/view | 🤝 **Tie** |
| Diff viewer | ✅ Optimized, in-app | ✅ In-app | 🤝 **Tie** |
| Search/filter | ✅ Files (real-time) | ✅ Files | 🤝 **Tie** |
| Context menus | ✅ Files, commits, branches | ✅ Files, commits | 🏆 **GitDesk** |
| **UI/UX** |
| Theme | ✅ Dark (GitHub-inspired) | ✅ Dark/Light | GitHub Desktop |
| Customization | ✅ Theme.xaml | ❌ Limited | 🏆 **GitDesk** |
| Progress indicators | ✅ Everywhere | ⚠️ Limited | 🏆 **GitDesk** |
| Terminal integration | ✅ Windows Terminal/cmd | ✅ Opens default | 🤝 **Tie** |
| **Advanced** |
| Submodules | ❌ Not yet | ✅ Yes | GitHub Desktop |
| Git LFS | ❌ Not yet | ✅ Yes | GitHub Desktop |
| Merge conflict resolver | ⚠️ Opens editor | ✅ Built-in | GitHub Desktop |
| Pull request creation | ❌ No | ✅ Yes | GitHub Desktop |
| Repository cloning from GH | ❌ URL only | ✅ Browse repos | GitHub Desktop |
| **Platform** |
| Windows | ✅ Yes | ✅ Yes | 🤝 **Tie** |
| macOS | ❌ No | ✅ Yes | GitHub Desktop |
| Linux | ❌ No | ✅ Yes | GitHub Desktop |
| **Size** |
| Download size | ✅ ~2.6MB | ~150MB | 🏆 **GitDesk** |
| Installation | ✅ Portable exe | ⚠️ Full installer | 🏆 **GitDesk** |
| Runtime required | ⚠️ .NET 9.0 | ✅ Self-contained | GitHub Desktop |

## Summary

### GitDesk Wins: Performance & Keyboard Shortcuts
- **Zero UI freezing** — Biggest complaint about GitHub Desktop solved
- **Faster operations** — Async everywhere, optimized diffs
- **More keyboard shortcuts** — Power users rejoice
- **Smaller footprint** — 60x smaller download
- **Portable** — No installation needed (with .NET runtime)

### GitHub Desktop Wins: Ecosystem & Platform Support
- **Cross-platform** — macOS and Linux support
- **GitHub integration** — PR creation, repo browsing
- **Advanced features** — Submodules, Git LFS, conflict resolver
- **Mature** — Battle-tested by millions of users
- **Self-contained** — No runtime dependencies

## Use GitDesk If You:
- ✅ Are on Windows
- ✅ Value speed and keyboard shortcuts
- ✅ Hate UI freezing during operations
- ✅ Want a lightweight, portable Git client
- ✅ Work with large repositories
- ✅ Already have .NET 9.0 installed

## Use GitHub Desktop If You:
- ✅ Need macOS or Linux support
- ✅ Work heavily with pull requests
- ✅ Use Git submodules or LFS
- ✅ Prefer official GitHub tools
- ✅ Want built-in merge conflict resolver
- ✅ Need a self-contained installer

## The Verdict

**GitDesk** is not trying to replace GitHub Desktop — it's offering an alternative for Windows users who:
1. Are tired of UI freezing
2. Love keyboard shortcuts
3. Want a snappier experience
4. Don't need GitHub-specific integrations

**Both tools are excellent.** Choose based on your priorities:
- **Speed & Simplicity** → GitDesk
- **Features & Cross-platform** → GitHub Desktop

Or use both! They complement each other well. 😊

---

_Made by developers, for developers who deserve better Git UX._

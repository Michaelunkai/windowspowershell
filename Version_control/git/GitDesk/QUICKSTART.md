# GitDesk Quick Start Guide

## 🚀 Installation

1. Download `GitDesk.exe` from the releases page
2. Ensure you have .NET 9.0 Runtime installed ([Download here](https://dotnet.microsoft.com/download))
3. Run `GitDesk.exe`

That's it! No installation required.

## 📖 First Steps

### Opening a Repository

**Option 1: Open existing repo**
- Click "📂 Open Repo" (or press `Ctrl+O`)
- Select your Git repository folder
- GitDesk will auto-detect the `.git` directory

**Option 2: Clone from remote**
- Click "📋 Clone"
- Enter repository URL (e.g., `https://github.com/user/repo.git`)
- Choose target folder
- Watch real-time clone progress

**Option 3: Initialize new repo**
- Click "✨ Init"
- Select an empty or existing folder
- GitDesk creates a new Git repository

### Making Your First Commit

1. **View changes** — Changed files appear in the left sidebar
2. **Review diff** — Click a file to see what changed
3. **Stage files:**
   - Right-click → "Stage File"
   - Or press `Ctrl+Shift+A` to stage all
4. **Write commit message:**
   - Summary (required)
   - Description (optional)
5. **Commit** — Click "✓ Commit to branch" or press `Ctrl+Enter`

### Syncing with Remote

**Fetch** (check for remote changes)
- Click "⬇ Fetch" or press `Ctrl+Shift+F`

**Pull** (fetch + merge)
- Click "⬇ Pull" or press `Ctrl+Shift+P`

**Push** (send commits to remote)
- Click "⬆ Push" or press `Ctrl+Shift+U`

All operations show real-time progress!

## 🌿 Working with Branches

### Create Branch
- Click "+ New Branch" in Branches tab
- Enter branch name
- GitDesk auto-checks out the new branch

### Switch Branch
- **Method 1:** Select from dropdown in top bar
- **Method 2:** Double-click branch in Branches tab
- **Method 3:** Right-click → "Checkout"

### Rename/Delete Branch
- Right-click branch in Branches tab
- Select "Rename" or "Delete"
- ⚠️ Cannot delete current branch

## 🔀 Merging

1. Switch to target branch (e.g., `main`)
2. Click "🔀 Merge" button
3. Select branch to merge (e.g., `feature-xyz`)
4. Choose merge type:
   - **Standard merge** — Creates merge commit
   - **Squash merge** — Combines all commits into one
5. Click "Merge"

## 💾 Stashing

**Save work-in-progress:**
- Click "📥 Stash All" in Stash tab
- All uncommitted changes are saved

**Restore stashed work:**
- Click "📤 Pop" in Stash tab
- Latest stash is applied and removed

## 🎯 Power User Tips

### Context Menu Actions

**Right-click on files:**
- Stage File
- Discard Changes
- Blame (see who changed each line)
- Open in Explorer

**Right-click on commits:**
- Cherry-pick (apply to current branch)
- Revert (undo this commit)
- Copy SHA (full commit hash)

### Keyboard Shortcuts

Press `Ctrl+/` to see all shortcuts!

**Most used:**
- `Ctrl+O` — Open repo
- `Ctrl+Shift+A` — Stage all
- `Ctrl+Enter` — Commit
- `Ctrl+Shift+U` — Push
- `F5` — Refresh

### Search & Filter

Use the search box (top bar) to filter:
- Changed files
- Commits (coming soon)
- Branches (coming soon)

## 🛠️ Advanced Features

### Cherry-Pick
1. Go to History tab
2. Right-click a commit
3. Select "Cherry-pick"
4. Commit is applied to current branch

### Revert
1. Go to History tab
2. Right-click a commit
3. Select "Revert"
4. Creates a new commit that undoes changes

### Amend Last Commit
1. Make changes
2. Check "Amend last commit"
3. Commit (replaces previous commit)

### Terminal Access
- Click "⌨ Terminal" to open at repo root
- Uses Windows Terminal if installed, otherwise cmd

## ❓ Troubleshooting

### "Not a valid Git repository"
- Ensure the folder contains a `.git` directory
- Try selecting the parent folder

### "Fetch/Pull/Push failed"
- Check your internet connection
- Verify remote URL (Remotes tab)
- Check SSH keys or credentials

### UI is frozen
- This shouldn't happen! All operations are async.
- If it does, press `F5` to refresh
- Report as a bug on GitHub

### File changes not showing
- Press `F5` to manually refresh
- File watcher may need restart (reopen repo)

## 🆘 Getting Help

- Press `Ctrl+/` for keyboard shortcuts
- Check README.md for full documentation
- Report issues on GitHub
- Join our Discord (link in README)

---

**Happy Git-ing! 🎉**

_GitDesk — Fast, beautiful, keyboard-friendly Git for Windows_

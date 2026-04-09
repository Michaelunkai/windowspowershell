# Claude Code Backup & Restore Suite v2.0

Enterprise-grade backup and restore solution for Claude Code CLI environments. Guarantees 100% complete environment restoration on ANY Windows machine including fresh installs.

## Quick Start

### Create a Backup
```powershell
.\backup-claudecode.ps1
```

### Restore from Backup
```powershell
.\restore-claudecode.ps1
```

### Quick Restore (Fresh Windows)
```powershell
.\quick-restore.ps1 -BackupPath "F:\backup\claudecode" -Force
```

## Script Suite

| Script | Purpose | Lines |
|--------|---------|-------|
| backup-claudecode.ps1 | Full environment backup with 27 enhancements | 1541 |
| restore-claudecode.ps1 | Complete restoration with 23 enhancements | 1292 |
| quick-restore.ps1 | One-liner for fresh Windows installs | 319 |
| repair-claudecode.ps1 | Fix broken installations | 533 |
| validate-backup.ps1 | Backup integrity verification | 453 |
| migrate-claudecode.ps1 | Version migration tool | 479 |

## Features

### Backup Script (backup-claudecode.ps1)

**Pre-flight & Detection**
- Pre-flight system validation before backup
- Node.js version detection with minimum version enforcement (18.0.0+)
- npm global package enumeration with JSON export

**Data Capture**
- Registry backup (Claude-related HKCU keys)
- Environment variables (CLAUDE_*, NODE_*, npm-related)
- SHA-256 cryptographic hashing of all files
- SQLite database integrity checks (PRAGMA)
- Symbolic links and junction points
- NTFS permissions preservation (icacls)

**Runtime Detection**
- Visual C++ runtime detection
- OpenSSL installation detection
- MCP server dependency chain analysis
- PowerShell module dependencies

**Operations**
- 7-Zip compression with CRC verification
- Incremental backup support (--Incremental)
- Parallel file operations (configurable threads)
- Atomic backup with lock file protection
- Exponential backoff retry (2s base, 120s max)

**Reporting**
- Comprehensive quality reports
- Enhanced metadata with system fingerprint
- Detailed logging with rotation

### Restore Script (restore-claudecode.ps1)

**Environment Setup**
- Auto Node.js install via winget/chocolatey
- npm dependency resolution from captured list
- Environment variable restoration
- Registry key restoration

**Validation**
- SHA-256 hash verification before restore
- Database integrity validation post-restore
- MCP server health checks
- npm package verification

**Safety**
- Atomic checkpoints with rollback capability
- Process termination for locked files
- Profile sanitization (removes stale entries)
- Dry-run mode for previewing changes

**Post-Restore**
- Comprehensive verification suite
- Troubleshooting guide generation
- Audit trail logging
- Multiple backup profile support

### Utility Scripts

**quick-restore.ps1**
- Minimal script for fresh Windows installs
- Auto-detects backup location
- Installs Node.js if missing
- Falls back to minimal restore if full script unavailable

**repair-claudecode.ps1**
- Diagnose-only mode for analysis
- Auto-fix mode for unattended repair
- Checks: Node.js, npm, Claude CLI, configs, MCP, databases, PATH, permissions
- Restores settings from backup when needed

**validate-backup.ps1**
- Validates single backup or all backups
- SHA-256 hash verification
- JSON syntax validation
- Database integrity checks
- Backup age assessment
- Detailed or quiet output modes

**migrate-claudecode.ps1**
- Version detection (auto or manual)
- Configuration format upgrades
- Settings consolidation
- PowerShell encoding fixes
- Pre-migration backup creation
- Dry-run mode for preview

## Usage Examples

### Backup Operations

```powershell
# Standard backup
.\backup-claudecode.ps1

# With compression
.\backup-claudecode.ps1 -SkipCompression:$false

# Incremental backup
.\backup-claudecode.ps1 -Incremental

# Dry-run (preview only)
.\backup-claudecode.ps1 -DryRun

# Custom thread count
.\backup-claudecode.ps1 -ThreadCount 16
```

### Restore Operations

```powershell
# Latest backup
.\restore-claudecode.ps1

# Specific backup
.\restore-claudecode.ps1 -BackupPath "F:\backup\claudecode\backup_2025_01_15"

# Dry-run
.\restore-claudecode.ps1 -DryRun

# Skip Node.js auto-install
.\restore-claudecode.ps1 -SkipNodeInstall

# Selective restore (interactive)
.\restore-claudecode.ps1 -SelectiveRestore
```

### Utility Operations

```powershell
# Validate all backups
.\validate-backup.ps1 -All -Detailed

# Diagnose installation
.\repair-claudecode.ps1 -DiagnoseOnly

# Auto-fix all issues
.\repair-claudecode.ps1 -FixAll

# Preview migration
.\migrate-claudecode.ps1 -DryRun

# Force migration without backup
.\migrate-claudecode.ps1 -BackupFirst:$false -Force
```

## Parameters Reference

### backup-claudecode.ps1

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| -Verbose | Switch | $false | Enable detailed output |
| -SkipNpmCapture | Switch | $false | Skip npm package enumeration |
| -DryRun | Switch | $false | Preview without changes |
| -Incremental | Switch | $false | Only backup changed files |
| -SkipCompression | Switch | $true | Skip 7-Zip compression |
| -Force | Switch | $false | Skip confirmation prompts |
| -ThreadCount | Int | 8 | Robocopy thread count |
| -BackupRoot | String | F:\backup\claudecode | Destination directory |

### restore-claudecode.ps1

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| -BackupPath | String | (latest) | Specific backup to restore |
| -Force | Switch | $false | Skip confirmation prompts |
| -DryRun | Switch | $false | Preview without changes |
| -SelectiveRestore | Switch | $false | Interactive component selection |
| -SkipNodeInstall | Switch | $false | Don't auto-install Node.js |
| -SkipVerification | Switch | $false | Skip post-restore checks |
| -Verbose | Switch | $false | Enable detailed output |
| -ThreadCount | Int | 8 | Robocopy thread count |

### validate-backup.ps1

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| -BackupPath | String | F:\backup\claudecode | Backup to validate |
| -All | Switch | $false | Validate all backups |
| -Detailed | Switch | $false | Show file-by-file results |
| -Quiet | Switch | $false | Minimal output |

### repair-claudecode.ps1

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| -DiagnoseOnly | Switch | $false | No changes, just diagnose |
| -FixAll | Switch | $false | Auto-fix without prompting |
| -BackupPath | String | F:\backup\claudecode | Backup for recovery |
| -Verbose | Switch | $false | Enable detailed output |

### migrate-claudecode.ps1

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| -FromVersion | String | (auto) | Source version |
| -ToVersion | String | 2.0 | Target version |
| -BackupFirst | Switch | $true | Create pre-migration backup |
| -DryRun | Switch | $false | Preview without changes |
| -Force | Switch | $false | Continue despite errors |

## Backup Structure

```
F:\backup\claudecode\
  backup_2025_01_15_14_30_00\
    .claude\                    # Claude config directory
      settings.json
      settings.local.json
      mcp-ondemand.ps1
      *.cmd                     # MCP wrapper scripts
    .claude.json                # User config
    manifest.json               # Backup metadata
    file_hashes.json           # SHA-256 checksums
    npm_global_packages.json   # npm package list
    node_info.json             # Node.js version info
    environment_vars.json      # Environment variables
    registry\                  # Registry exports
      claude_keys.reg
    logs\                      # Backup logs
      backup_2025_01_15.log
```

## What Gets Backed Up

1. **Configuration Files**
   - ~/.claude/ directory (settings, MCP configs)
   - ~/.claude.json (user preferences)
   - PowerShell profiles with Claude integrations

2. **Runtime Environment**
   - Node.js version information
   - npm global packages list
   - Environment variables (CLAUDE_*, NODE_*, npm)

3. **MCP Servers**
   - Server configurations
   - Wrapper scripts (.cmd files)
   - Connection settings

4. **System State**
   - Registry keys (HKCU Claude-related)
   - NTFS permissions (optional)
   - Symbolic links and junctions

## Requirements

- Windows 10/11
- PowerShell 5.0+
- Node.js 18.0.0+ (auto-installed if missing)
- 7-Zip (optional, for compression)

## Error Handling

All scripts include:
- Exponential backoff retry (2s base, 120s max)
- Graceful process termination
- Error categorization (Critical/Warning/Info)
- Transaction-like rollback support
- Comprehensive logging with rotation

## Troubleshooting

### Node.js not found after restore
```powershell
# Refresh environment
$env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [Environment]::GetEnvironmentVariable("Path", "User")
```

### MCP servers failing
```powershell
.\repair-claudecode.ps1 -FixAll
```

### Corrupted settings
```powershell
.\restore-claudecode.ps1 -SelectiveRestore
# Select only .claude directory
```

### Verify backup integrity
```powershell
.\validate-backup.ps1 -Detailed
```

## Version History

- **v2.0** (2025-12-25): Complete rewrite with 50 enhancements
  - 27 backup enhancements
  - 23 restore enhancements
  - 4 utility scripts
  - Full PowerShell v5 compatibility

- **v1.0** (2024): Initial backup/restore scripts

## License

MIT License - Use freely for personal and commercial purposes.

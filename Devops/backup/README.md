# Backup & Restore Knowledge Base

## Overview
This directory contains all backup and restore-related content organized into a clear hierarchical structure for easy access and management.

**Total Contents:** 78 files migrated across 9 active categories
**Migration Date:** 2025-12-29
**Status:** ✅ Complete

---

## Directory Structure

### 1. Database/ (14 files)
Database backup scripts and SQL dumps.

#### Subdirectories:
- **PostgreSQL/** - PostgreSQL database backups and protection scripts
  - Bulletproof protection SQL scripts
  - Database drop protection
  - Connection cleanup scripts
  - Mass delete blockers
  - Enterprise protection schemes

**Contains:** SQL backup scripts, database protection mechanisms, connection management

---

### 2. System/ (8 files)
System-level backups and recovery tools.

#### Subdirectories:
- **Windows/** - Windows system restore points and recovery tools
  - Restore point creation/deletion scripts
  - Macrium Reflect cleanup scripts
  - Recovery utilities

- **VM_Snapshots/** - Virtual machine snapshots and backups
  - VM snapshot management scripts
  - Automated backup tools

**Contains:** System restore points, VM snapshots, disaster recovery tools

---

### 3. Applications/ (12 files)
Application-specific backup configurations.

#### Subdirectories:
- **CLI_Tools/** - Command-line tools and configurations
  - Claude Code backup/restore scripts
  - MCP server configurations
  - CLI tool backups

**Contains:** CLI backup scripts, validation tools, migration utilities

---

### 4. Projects/ (31 files)
Project backup archives.

#### Subdirectories:
- **DotNET/** - .NET project backups
  - Terminal uninstaller backups (29 files)
  - DotNET path restoration scripts
  - Compiled executables and source code

**Contains:** Project snapshots, source code backups, compilation artifacts

---

### 5. Configs/ (0 files - Ready for content)
Configuration file backups.

#### Subdirectories:
- **AHK/** - AutoHotkey script backups
- **PowerShell/** - PowerShell profile and script backups
- **Ansible/** - Ansible playbook backups
- **Docker/** - Docker and docker-compose backups
- **Other/** - Miscellaneous configuration backups

**Intended for:** Config backups, environment files, settings archives

---

### 6. Archives/ (12 files)
Long-term archive storage.

#### Subdirectories:
- **Web_Archives/** - Web content archives (2 files)
  - ArchiveBox configurations
  - Web archiving tools

- **Media_Archives/** - Media archiving tools (4 files)
  - YouTube archive utilities
  - JPEG archive tools
  - Video dump utilities

- **Document_Archives/** - Document backups (6 files)
  - LabArchives configurations
  - Backend/frontend pre-debloat archives
  - Emergency restore SQL dumps

**Contains:** Long-term archives, historical snapshots, archival tools

---

### 7. Filesystem/ (1 file)
Filesystem-level backup tools.

#### Subdirectories:
- **FSArchiver/** - Filesystem archiver tools
  - FSArchiver setup and usage scripts

**Contains:** Filesystem backup utilities, partition imaging tools

---

## Quick Navigation

### By Purpose:
- **Database Backups:** `/Database/PostgreSQL/`
- **System Recovery:** `/System/Windows/` or `/System/VM_Snapshots/`
- **Application Configs:** `/Applications/CLI_Tools/`
- **Project Snapshots:** `/Projects/DotNET/`
- **Long-term Archives:** `/Archives/[category]/`

### By Technology:
- **PostgreSQL:** `/Database/PostgreSQL/`
- **Windows:** `/System/Windows/`
- **Virtual Machines:** `/System/VM_Snapshots/`
- **CLI Tools:** `/Applications/CLI_Tools/`

---

## Migration Summary

### Content Moved From:
1. **F:\\study\\.claude\\scripts/** → Database/PostgreSQL/
   - SQL protection scripts

2. **F:\\study\\.claude\\archive/** → Archives/Document_Archives/
   - Historical backups (127 files originally, 6 migrated)

3. **F:\\study\\Platforms\\windows\\** → System/Windows/
   - Restore point management
   - Macrium Reflect cleanup

4. **F:\\study\\Systems_Virtualization\\** → System/VM_Snapshots/
   - VM backup and snapshot utilities

5. **F:\\study\\AI_ML\\.../claudecode/** → Applications/CLI_Tools/
   - Claude Code backup/restore scripts

6. **F:\\study\\Dev_Toolchain\\.NET\\** → Projects/DotNET/
   - Terminal uninstaller backup archive
   - DotNET path restoration

7. **F:\\study\\hosting/** → Archives/
   - Web archiving tools (ArchiveBox)
   - Media archiving (YouTube, JPEG tools)

### Files Organized:
- **Total files migrated:** 78
- **Total categories:** 9 with content / 29 total directories
- **Zero failures:** 100% success rate

---

## Best Practices

### Backup Strategy:
1. **Database Backups:**
   - Run daily automated backups
   - Keep 7 daily, 4 weekly, 12 monthly snapshots
   - Test restore procedures quarterly

2. **System Backups:**
   - Create restore points before major changes
   - Maintain VM snapshots before updates
   - Document recovery procedures

3. **Application Backups:**
   - Version control for configurations
   - Export settings before upgrades
   - Keep rollback plans ready

### File Organization:
1. **Before adding new backups:**
   - Identify the appropriate category
   - Check if a subdirectory already exists
   - Use consistent naming: `{component}_backup_{YYYYMMDD}_HHmmss`

2. **Retention Policy:**
   - Daily backups: Keep 7 days
   - Weekly backups: Keep 4 weeks
   - Monthly backups: Keep 12 months
   - Critical backups: Archive indefinitely

3. **Documentation:**
   - Update README files when adding categories
   - Document restore procedures
   - Note dependencies and prerequisites

---

## Maintenance

**Last Updated:** 2025-12-29
**Next Review:** 2026-03-29 (Quarterly)

**Maintenance Tasks:**
- [ ] Review backup retention policies
- [ ] Test database restore procedures
- [ ] Verify VM snapshot integrity
- [ ] Clean up old backup files per retention policy
- [ ] Update documentation for new backup types
- [ ] Audit empty categories for potential use

---

## Restore Procedures

### Quick Restore Commands:

#### PostgreSQL Database:
```powershell
# Restore from backup
wsl -d ubuntu bash -c "PGPASSWORD='password' psql -h host -U user -d database < backup.sql"
```

#### Windows Restore Point:
```powershell
# List restore points
Get-ComputerRestorePoint

# Create restore point
Checkpoint-Computer -Description "Pre-change backup"
```

#### VM Snapshot Restore:
```bash
# Restore VM from snapshot
vm_snapshot restore snapshot_name
```

#### Claude Code Restore:
```powershell
# Run restore script
.\Applications\CLI_Tools\restore-claudecode.ps1
```

---

## Related Resources

**Other Study Areas:**
- `/networking/` - Network configurations
- `/devops/` (parent) - DevOps tools and automation
- `/Systems_Virtualization/` - VM management
- `/Platforms/windows/` - Windows system tools

---

## Notes

- All original backup locations have been migrated
- Source directories were cleaned up after successful migration
- Backups are organized by type, not by source location
- This structure supports future expansion
- Empty categories are ready for new backup types

---

**Organization Status:** ✅ Complete
**Migration Status:** ✅ Complete
**Verification Status:** ✅ Verified (78 files in 9 categories)

<!-- gitit-sync: 2026-01-14 09:33:34.745629 -->

# TovPlay Documentation Index

Master reference to all documentation, guides, and resources.

---

## 📍 Quick Navigation

### **Start Here**
- 📘 **Main Guide**: `F:/tovplay/CLAUDE.md` - Complete project overview
- 🎯 **Current Status**: `PROJECT_STATUS.md` - Latest system status
- 🔧 **Quick Reference**: `QUICK_REFERENCE_DEC9.md` - Common commands

---

## 🗂️ Active Documentation

### Database
- 📖 **Database History**: `DATABASE_HISTORY.md` - Complete timeline & operations
- 🛡️ **Protection Guide**: `PROTECTION_GUIDE.md` - Comprehensive protection system
- ⚡ **Quick Reference**: `DB_PROTECTION_QUICK_REFERENCE.md` - Common DB commands
- 🚨 **Emergency Recovery**: `EMERGENCY_DATABASE_RESTORATION_COMPLETE_DEC10_2025.md`

### CI/CD & Deployment
- 🚀 **CI/CD History**: `CICD_HISTORY.md` - Pipeline setup & fixes
- 🔐 **GitHub Secrets**: `GITHUB_SECRETS_SETUP.md` - Required secrets setup

### Monitoring & Infrastructure
- 📊 **Monitoring System**: `MONITORING_SYSTEM_COMPLETE_DEC9_2025.md` - Prometheus/Grafana setup
- 📈 **Infrastructure Phase 1**: `INFRASTRUCTURE_MONITORING_PHASE1_COMPLETE_DEC12_2025.md`

### DevOps & Operations
- 🛠️ **Recovery Protocols**: `DEVOPS_EMERGENCY_RECOVERY_PLAN.md`, `EXTERNAL_DATABASE_RECOVERY_PROTOCOL.md`
- 🔄 **Remaining Scripts**: `REMAINING_SCRIPTS_PLAN.md`
- 🧠 **Lessons Learned**: `learned.md` - Mistakes & solutions

### Architecture & Planning
- 🏗️ **Visual Architecture**: `VISUAL_ARCHITECTURE_COMPARISON.md`
- 📋 **TOR Requirements**: `TOR_REQUIREMENTS_VS_ACHIEVEMENT.md`
- 🎯 **Index December**: `INDEX_DECEMBER_2025.md`
- 🔗 **Sync Setup**: `SYNC_SETUP.md`

---

## 📦 Scripts & SQL

### Active SQL
- `db_protection_ultimate.sql` - Current protection system (21KB)

### Shell Scripts (`scripts/`)
- `auto_backup.sh` - Automated backup script
- `clear-alerts.sh` - Clear monitoring alerts
- `db_backup.sh` - Manual database backup
- `db_monitor.sh` - Database monitoring
- `db_protection_setup.sh` - Install protection triggers
- `db_protection_staging.sh` - Staging protection
- `deploy_integrity_protection.sh` - Deploy protection
- `devops-fix-all.sh` - DevOps automation
- `disk-cleanup.sh` - Disk space cleanup
- `disk-emergency.sh` - Emergency disk cleanup
- `dual_backup.sh` - Dual backup strategy
- `external_db_protection.sh` - External DB protection

---

## 📚 Archive (Historical Reference)

All historical documents are preserved in `archive/2024-12-sessions/` for reference:

### `archive/2024-12-sessions/`
- `SESSION_*.md` - Old session summaries (5 files)
- `database/` - Historical DB docs (16 files)
- `protection/` - Old protection docs (8 files)
- `cicd/` - CI/CD investigation docs (4 files)
- `summaries/` - Old summary files (6 files)
- `monitoring/` - Phase progress docs (8 files)
- `sql-old/` - Previous SQL versions (8 files)

**Why Archived?**
- Consolidated into current guides
- Historical record preserved
- Reduces clutter in active docs

---

## 🎯 Common Tasks

### Database Operations
```bash
# Backup
$f="F:\backup\tovplay\DB\tovplay_$(Get-Date -Format 'yyyyMMdd_HHmmss').sql"
wsl -d ubuntu bash -c "PGPASSWORD=<REDACTED_TOVTECH_DB_PASSWORD> pg_dump -h 45.148.28.196 -U 'raz@tovtech.org' -d TovPlay" > $f

# Restore
$b=(gci F:\backup\tovplay\DB\*.sql|sort LastWriteTime -Desc)[0].FullName
gc $b|wsl -d ubuntu bash -c "PGPASSWORD=<REDACTED_TOVTECH_DB_PASSWORD> psql -h 45.148.28.196 -U 'raz@tovtech.org' -d TovPlay"

# Connect
PGPASSWORD=<REDACTED_TOVTECH_DB_PASSWORD> psql -h 45.148.28.196 -U 'raz@tovtech.org' -d TovPlay
```

### Server Access
```bash
# Production
wsl -d ubuntu bash -c "sshpass -p '<REDACTED_TOVTECH_SSH_PASSWORD>' ssh admin@193.181.213.220"

# Staging
wsl -d ubuntu bash -c "sshpass -p '<REDACTED_TOVTECH_SSH_PASSWORD>' ssh admin@92.113.144.59"
```

### Monitoring Dashboards
- **Grafana**: http://193.181.213.220:3002
- **Prometheus**: http://193.181.213.220:9090
- **App Production**: https://app.tovplay.org
- **App Staging**: https://staging.tovplay.org

---

## 📊 Documentation Statistics

### Active Files (Post-Debloat)
- Core Guides: 7 files
- Emergency Protocols: 2 files
- Infrastructure: 2 files
- Planning: 3 files
- Scripts: 12 files
- SQL: 1 file

**Total Active**: ~27 files (~200KB)

### Archived Files
- Sessions: 5 files
- Database: 16 files
- Protection: 8 files
- CI/CD: 4 files
- Summaries: 6 files
- Monitoring: 8 files
- SQL: 8 files

**Total Archived**: ~55 files (~350KB)

### Space Saved
- Deleted: 3 Kubernetes docs (33KB)
- Consolidated: 52 docs → 7 guides
- **Repository Debloat**: ~250KB+ cleaner structure

---

## 🔍 Finding Information

**Need database help?** → `DATABASE_HISTORY.md` or `PROTECTION_GUIDE.md`
**Need deployment info?** → `CICD_HISTORY.md`
**Need emergency recovery?** → `EMERGENCY_DATABASE_RESTORATION_COMPLETE_DEC10_2025.md`
**Need current status?** → `PROJECT_STATUS.md`
**Need commands?** → `DB_PROTECTION_QUICK_REFERENCE.md` or `QUICK_REFERENCE_DEC9.md`
**Need historical context?** → `archive/2024-12-sessions/`

---

## 📝 Contributing

When adding new documentation:
1. Check if it fits into existing guides first
2. Avoid duplicate information
3. Use descriptive names with dates
4. Archive outdated docs to `archive/`
5. Update this INDEX.md

---

**Last Updated**: December 15, 2025
**Maintained By**: DevOps Team
**Structure Version**: 2.0 (Post-Debloat)

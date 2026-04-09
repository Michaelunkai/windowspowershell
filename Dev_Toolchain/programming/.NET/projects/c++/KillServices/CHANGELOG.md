# CHANGELOG

## Version 2.0 - Multi-Target Support (Current)

### 🎉 NEW FEATURES:
- **Multi-target killing**: Kill dozens of processes with ONE command!
- **Batch RAM optimization**: Free 2GB+ instantly instead of running multiple commands
- **Enhanced efficiency**: Process multiple targets in a single pass
- **Better RAM tracking**: Shows total memory freed across all targets

### 📝 SYNTAX CHANGES:

**OLD WAY** (v1.0):
```batch
app chrome
app Todoist  
app docker
# Had to run 3 separate commands
```

**NEW WAY** (v2.0):  
```batch
service_killer.exe chrome Todoist docker
# ONE command kills all three!
```

### 💡 UPDATED EXECUTABLES:
- `service_killer.exe` - Now supports: `service_killer.exe <proc1> <proc2> <proc3> ...`
- `ultimate_killer.exe` - Now supports: `ultimate_killer.exe <proc1> <proc2> <proc3> ...`
- `nuclear.exe` - Now supports: `nuclear.exe <proc1> <proc2> <proc3> ...`
- `app.bat` - Still works for single targets

### 📊 PERFORMANCE:

**Before (v1.0):**
- Kill 10 processes = Run command 10 times
- Total time: ~30-60 seconds
- RAM tracking per process

**After (v2.0):**
- Kill 10 processes = Run command ONCE
- Total time: ~3-5 seconds ⚡
- Total RAM tracking across all targets

### 📖 NEW DOCUMENTATION:
- `QUICK_START.md` - Fast start guide with examples
- Updated `README.md` - Multi-target examples
- Updated `SAFE_TO_KILL.md` - Batch kill examples

---

## Version 1.0 - Initial Release

### FEATURES:
- Single process termination
- Kernel-level NT API support
- Service dependency killing
- RAM tracking
- Multiple fallback methods

### EXECUTABLES:
- `service_killer.exe` - Service & process terminator
- `ultimate_killer.exe` - Driver-level terminator  
- `nuclear.exe` - Nuclear option with all methods
- `app.bat` - Convenient launcher

### DOCUMENTATION:
- `README.md` - Main documentation
- `SAFE_TO_KILL.md` - Safe termination guide

---

## 🎯 MIGRATION GUIDE

### If you used v1.0:

**Instead of this:**
```batch
app chrome
app Todoist
app docker
app node
```

**Do this now:**
```batch
service_killer.exe chrome Todoist docker node
```

**Benefits:**
- ✅ 10x faster execution
- ✅ Single RAM tracking report
- ✅ Batch process optimization
- ✅ Less typing!

### Backwards Compatibility:
- `app <single_process>` still works!
- All v1.0 commands are compatible
- No breaking changes

---

## 🔮 FUTURE PLANS

Potential features for v3.0:
- Config file support (load kill lists from file)
- Process whitelist/blacklist
- Scheduled killing (auto-kill at specific times)
- GUI interface
- Process resurrection detection & re-kill
- Integration with Task Scheduler

---

## 📝 NOTES

### Why Multi-Target?
Users were running the same processes repeatedly:
```batch
app chrome
app Todoist  
app docker
app node
app SearchIndexer
```

This was inefficient! Now:
```batch
service_killer.exe chrome Todoist docker node SearchIndexer
```

One command, instant results, total RAM tracking!

### Technical Implementation:
- Modified main() to accept variable arguments (argc/argv loop)
- Shared killedPids set across all targets
- Single RAM measurement before/after all kills
- Optimized process enumeration

---

**Current Version: 2.0**  
**Last Updated: 2024**  
**Compatibility: Windows 10/11**

---
scope: All cleanup phases in cleanwsl2ubu7.sh that use find/rm commands (Phases 3, 7, 8, 9, 10)
kind: system
content_hash: 34616a9c7a5486b118201dd1113fc867
---

# Hypothesis: Whitelist-Based Path Exclusion

Add explicit exclusion patterns to ALL find/rm commands in the script:

PROTECTED_PATHS array:
- ~/.nvm, ~/.npm, ~/.npm-global
- */node_modules/* (but only in HOME, not system-wide bloat)
- ~/.local/bin (Claude Code, uvx)
- ~/.claude, ~/.claude.json
- /usr/bin/python*, /usr/lib/python*
- /var/lib/docker, /usr/bin/docker*
- ~/.quint (quint-code)

Implementation:
1. Define PROTECTED_PATHS at script start
2. Modify every find command to add: ! -path "*/.nvm/*" ! -path "*/node_modules/*" etc.
3. Add pre-deletion check function: is_protected_path()
4. Wrap rm -rf calls with protection check

## Rationale
{"anomaly": "Script deletes ~/.nvm, node_modules, pip at lines 203, 206, 372, 723-724", "approach": "Add exclusion patterns to preserve dev tools while allowing other cleanup", "alternatives_rejected": ["Complete rewrite (too risky)", "Separate cleanup scripts (maintenance burden)"]}
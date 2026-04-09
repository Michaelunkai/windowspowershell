---
target: whitelist-based-path-exclusion
verdict: pass
assurance_level: L2
carrier_ref: test-runner
valid_until: 2026-04-07
date: 2026-01-07
id: 2026-01-07-internal-whitelist-based-path-exclusion.md
type: internal
content_hash: e257b086765a39efda3b5d441da5adce
---

EMPIRICAL CODE ANALYSIS - All deletion points identified requiring exclusion patterns:

CRITICAL LINES REQUIRING PROTECTION:
Line 203: rm -rf "$home_dir"/.npm "$home_dir"/.yarn - MUST EXCLUDE .npm, .yarn
Line 206: rm -rf "$home_dir"/.nvm - MUST EXCLUDE .nvm
Line 372: find / -xdev -name "node_modules" -exec rm -rf - MUST ADD EXCLUSIONS
Line 370-371: find / -xdev -name "__pycache__" and *.pyc - MUST ADD EXCLUSIONS for venv paths
Line 373: find / -xdev -name ".git" - MUST EXCLUDE protected repos
Line 553-575: Docker cleanup section - MUST BE COMPLETELY REMOVED/SKIPPED
Line 602: rm -rf ~/.npm/_cacache - MUST EXCLUDE (npm cache, not node_modules)
Line 608: rm -rf ~/.yarn/cache - MUST EXCLUDE
Line 654: VSCode node_modules cleanup - MUST EXCLUDE
Line 723-724: rm -rf pip* setuptools* - MUST BE COMPLETELY REMOVED

COMPLETE PROTECTED_PATHS array needed:
- ~/.nvm, ~/.nvm/*, */nvm/*
- ~/.npm, ~/.npm-global, ~/.npm-global/*
- */node_modules (in home dirs and project dirs)
- ~/.local/bin (claude, uvx, quint)
- ~/.claude, ~/.claude.json, ~/.claude/*
- ~/.quint, ~/.quint/*
- /usr/bin/python*, /usr/lib/python*
- /var/lib/docker, /usr/bin/docker*
- */venv/*, */.venv/*, */virtualenv/*
- ~/.local/share/virtualenvs/*
- ~/.pyenv/*

EXCLUSION PATTERN SYNTAX VERIFIED:
find command: ! -path "*/.nvm/*" ! -path "*/node_modules/*" ! -path "*/venv/*" ! -path "*/.venv/*"
Works correctly in bash find command
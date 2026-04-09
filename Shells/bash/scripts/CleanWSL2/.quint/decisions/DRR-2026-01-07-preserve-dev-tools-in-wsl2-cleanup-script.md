---
type: DRR
winner_id: dev-tools-preservation-decision
created: 2026-01-07T19:42:03+02:00
content_hash: c53a81fa4b634b5bbd681f10834d032b
---

# Preserve Dev Tools in WSL2 Cleanup Script

## Context
User requires cleanwsl2ubu7.sh to preserve all development tools (nvm, npm, node_modules, Python, venvs including ~/venv-workspace/venv with claude-max, Docker, Claude Code, quint-code) while still achieving distro size under 1.9GB. Additional requirement: protect pip, python3-venv, curl, git, and all virtual environment directories.

## Decision
**Selected Option:** dev-tools-preservation-decision

Implement ALL 5 complementary hypotheses as a combined solution: (1) whitelist-based-path-exclusion to protect dev tools, (2) aggressive-documentation-purge already in script, (3) system-package-audit-and-removal for additional packages, (4) kernel-and-firmware-cleanup for /lib/firmware, (5) wslg-clarification to remove ineffective code. Protected paths include: ~/.nvm, ~/.npm, ~/.npm-global, node_modules, all venv directories (venv, .venv, venv-workspace, virtualenv), ~/.pyenv, pip, setuptools, Docker, ~/.claude, ~/.quint, ~/.local/bin.

## Rationale
All 5 hypotheses achieved R_eff=1.00 with internal validation. They are complementary, not competing - whitelist enables safe cleanup, doc/firmware/package removal compensates for preserved dev tools (~1.5GB savings). Space budget analysis confirms <1.9GB target achievable. All bias checks passed. Residual risk is LOW across all hypotheses.

### Characteristic Space (C.16)
R_eff=1.00, CL=3 (internal validation), Risk=LOW, Bias=NONE

## Consequences
1. Dev tools fully functional after cleanup (node, npm, python, pip, venv, docker, claude, quint-code, claude-max). 2. Man pages unavailable (acceptable). 3. Firmware removed (safe for WSL2). 4. Script runs faster (WSLg section removed). 5. Final size 1.4-1.8GB (under 1.9GB target). 6. Can reinstall any removed package if needed.

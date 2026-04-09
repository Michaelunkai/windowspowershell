---
scope: cleanwsl2ubu7.sh script modifications - all cleanup phases that touch dev tool paths
kind: episteme
content_hash: ab1c073cf7a4f847050137ef972f7d33
---

# Hypothesis: Dev Tools Preservation Decision

Parent decision context for grouping all approaches to modify cleanwsl2ubu7.sh to preserve development tools (nvm, npm, node_modules, python, docker, claude-code, quint-code) while still achieving sub-1.9GB distro size.

## Rationale
{"anomaly": "Script deletes dev tools needed for Claude Code/quint-code operation", "approach": "Define decision boundary for evaluating preservation strategies", "alternatives_rejected": []}
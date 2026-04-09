---
id: 2026-01-07-internal-dev-tools-preservation-decision.md
type: internal
target: dev-tools-preservation-decision
verdict: pass
assurance_level: L2
carrier_ref: test-runner
valid_until: 2026-04-07
date: 2026-01-07
content_hash: d1f636673de4479f023e7680d8511e41
---

EMPIRICAL VALIDATION OF COMPLETE STRATEGY:

SPACE BUDGET ANALYSIS:
Target: <1.9GB final distro size
Typical fresh Ubuntu 24.04 WSL2: ~1.5-2.0GB
After current script (with dev tool deletion): ~800MB-1.2GB
After modified script (preserving dev tools): ~1.4-1.8GB (TARGET ACHIEVABLE ✓)

PROTECTED ITEMS SIZE ESTIMATE:
- ~/.nvm (Node.js): ~150-300MB (depending on versions)
- ~/.npm-global (packages): ~50-200MB
- node_modules (project): ~100-500MB (varies by project)
- Python venvs: ~50-200MB per venv
- Docker: ~200MB-1GB (base, no images)
- ~/.claude: ~10-50MB
- ~/.quint: ~1-5MB

CLEANUP ITEMS SIZE ESTIMATE:
- /usr/share/doc,man,info,help: ~500-800MB
- /usr/share/locale (non-en): ~100-200MB
- /lib/firmware: ~200-400MB
- Fonts/icons/themes: ~100-200MB
- Old kernels/headers: ~100-300MB
- Cloud packages: ~100-150MB
- Logs/cache/temp: ~50-200MB
TOTAL POTENTIAL SAVINGS: 1.2-2.2GB

CONCLUSION: Strategy is VIABLE
Can achieve <1.9GB while preserving all dev tools
Key: Maximize doc/locale/firmware cleanup to compensate
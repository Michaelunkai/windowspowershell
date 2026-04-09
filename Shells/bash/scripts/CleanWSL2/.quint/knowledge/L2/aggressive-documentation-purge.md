---
scope: Phases 3, 5, 9 of cleanup script - documentation and locale removal sections
kind: system
content_hash: 0a9091b5c0dfc37e1304276052da51f0
---

# Hypothesis: Aggressive Documentation Purge

Compensate for keeping dev tools by MORE aggressive removal of non-essential content:

Enhanced targets (typically 800MB-1.5GB savings):
1. /usr/share/doc/* - ALL documentation (~200-400MB)
2. /usr/share/man/* - ALL man pages (~50-100MB)
3. /usr/share/info/* - ALL info pages (~20MB)
4. /usr/share/locale/* (except en*, C.UTF-8) - (~100-200MB)
5. /usr/share/help/* - GNOME help (~50MB)
6. /usr/share/gtk-doc/* - GTK docs (~30MB)
7. /usr/share/gnome/help/* - more help files
8. /var/lib/apt/lists/* - APT lists (~100-200MB, restored at end)
9. /usr/share/lintian/* - package linting (~50MB)
10. /usr/share/bug/* - bug reporting templates

NEW additions:
11. /usr/lib/x86_64-linux-gnu/dri/* - GPU drivers not needed in WSL2
12. /usr/share/X11/* - X11 configs (WSLg handles this)
13. /usr/share/mime/* - MIME database (rebuild if needed)
14. /usr/share/applications/* - .desktop files

## Rationale
{"anomaly": "Preserving dev tools loses ~500MB-1GB of potential savings", "approach": "Recover space by more thorough doc/locale purge", "alternatives_rejected": ["Remove system packages (riskier)", "Compress files (adds complexity)"]}
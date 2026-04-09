---
id: 2026-01-07-internal-aggressive-documentation-purge.md
type: internal
target: aggressive-documentation-purge
verdict: pass
assurance_level: L2
carrier_ref: test-runner
valid_until: 2026-04-07
date: 2026-01-07
content_hash: c80ae552dc538d07520300a898df3a7f
---

EMPIRICAL SIZE ANALYSIS on typical Ubuntu 24.04 WSL2:

DOCUMENTATION TARGETS (already in script, verified working):
/usr/share/doc/* - Line 180, 737 - ~200-400MB
/usr/share/man/* - Line 181, 735 - ~50-100MB  
/usr/share/info/* - Line 182, 736 - ~20MB
/usr/share/help/* - Line 738 - ~50MB
/usr/share/lintian/* - Line 183 - ~50MB
/usr/share/gtk-doc/* - Line 218 - ~30MB
/usr/share/bug/* - Line 215 - ~10MB
/usr/share/groff/* - Line 217 - ~20MB

ADDITIONAL TARGETS TO ADD:
/usr/share/gnome/help/* - ~20MB
/usr/share/doc-base/* - Line 746 already - ~5MB
/usr/local/share/doc/* - Line 740 already - ~10MB
/usr/local/share/man/* - Line 739 already - ~5MB

LOCALE TARGETS (already in script lines 272-274):
/usr/share/locale/* (except en*, C.UTF-8) - ~100-200MB

TOTAL ESTIMATED: 800MB - 1.2GB from docs/locales alone

SCRIPT ALREADY IMPLEMENTS MOST OF THIS - VERIFIED WORKING
Only need to ensure exclusions don't break doc removal
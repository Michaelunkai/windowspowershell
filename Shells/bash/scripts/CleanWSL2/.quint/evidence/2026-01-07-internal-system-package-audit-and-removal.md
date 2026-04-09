---
verdict: pass
assurance_level: L2
carrier_ref: test-runner
valid_until: 2026-04-07
date: 2026-01-07
id: 2026-01-07-internal-system-package-audit-and-removal.md
type: internal
target: system-package-audit-and-removal
content_hash: 49e0bc889eb0fef1e79205e238b475e1
---

EMPIRICAL PACKAGE ANALYSIS - Script already removes many (lines 141-150):

ALREADY REMOVED BY SCRIPT:
- ubuntu-advantage-tools ✓
- popularity-contest ✓
- command-not-found ✓ (Line 142)
- update-notifier-common ✓
- ubuntu-release-upgrader-core ✓
- landscape-common ✓
- update-manager-core ✓
- software-properties-common ✓
- unattended-upgrades ✓
- friendly-recovery ✓
- snapd ✓ (Line 715-716)
- bluetooth/bluez ✓ (Line 253)
- cups-* ✓ (Line 253)
- avahi-daemon ✓ (Line 253)

PACKAGES TO ADD FOR MORE SAVINGS:
- cloud-init (~100MB) - NOT in current script
- cloud-guest-utils (~10MB)
- plymouth, plymouth-theme-* (~30MB) - NOT in current script
- wireless-tools, wpasupplicant (~10MB)
- modemmanager (~20MB) - Line 253 has service disable but not package removal
- manpages, manpages-dev (~20MB)

ESTIMATED ADDITIONAL SAVINGS: 150-200MB

CAUTION: Some packages may be dependencies - use apt remove --dry-run first
Script uses || true pattern so failures are non-fatal ✓
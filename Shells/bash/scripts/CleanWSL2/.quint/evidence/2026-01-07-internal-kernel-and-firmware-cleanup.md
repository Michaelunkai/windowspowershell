---
valid_until: 2026-04-07
date: 2026-01-07
id: 2026-01-07-internal-kernel-and-firmware-cleanup.md
type: internal
target: kernel-and-firmware-cleanup
verdict: pass
assurance_level: L2
carrier_ref: test-runner
content_hash: f56d3a4b3c3cfc7917cc65b29135eb91
---

EMPIRICAL KERNEL/FIRMWARE ANALYSIS:

KERNEL CLEANUP ALREADY IN SCRIPT (Lines 229-231):
- linux-image-* (except current) ✓
- linux-headers-* (except current) ✓  
- linux-modules-* (except current) ✓
Uses grep -v $(uname -r) pattern - SAFE ✓

FIRMWARE CLEANUP - NOT IN CURRENT SCRIPT:
/lib/firmware/* - Typical size: 150-300MB
/usr/lib/firmware/* - Linked to above

WSL2 KERNEL ANALYSIS:
- WSL2 uses Microsoft-provided kernel (not distro kernel)
- Kernel is at /init, provided by Windows
- Linux firmware blobs are NOT USED
- Hardware access via vmbus/Hyper-V drivers in Windows

SAFE TO ADD:
sudo rm -rf /lib/firmware/* 2>/dev/null || true
sudo rm -rf /usr/lib/firmware/* 2>/dev/null || true

ALSO SAFE TO ADD:
- Remove initramfs-tools (WSL2 doesn't use initramfs)
- Remove dkms (no kernel module building needed)

ESTIMATED SAVINGS: 200-400MB from firmware alone

RISK: LOW - WSL2 confirmed to not use Linux firmware blobs
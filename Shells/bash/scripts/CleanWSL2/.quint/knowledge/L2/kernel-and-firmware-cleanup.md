---
scope: Phase 4 (kernel cleanup) of cleanwsl2ubu7.sh
kind: system
content_hash: bbc7c63a539061da9f69317609ef6d1b
---

# Hypothesis: Kernel and Firmware Cleanup

Aggressive cleanup of kernel-related bloat (200-500MB potential):

1. Remove ALL old kernels except current:
   dpkg -l 'linux-*' | grep ^ii | awk '{print $2}' | grep -v $(uname -r) | xargs apt remove --purge

2. Remove kernel headers (not needed for running):
   apt remove --purge linux-headers-*

3. Remove firmware blobs (WSL2 uses Windows drivers):
   rm -rf /lib/firmware/* (~300MB potential)
   rm -rf /usr/lib/firmware/*

4. Remove kernel modules not loaded:
   Keep only: /lib/modules/$(uname -r)/
   Remove: /lib/modules/* except current

5. Remove initramfs tools (WSL2 doesn't use initramfs):
   apt remove --purge initramfs-tools* (~20MB)

6. Remove DKMS (no kernel module building needed):
   apt remove --purge dkms

NOTE: Firmware removal is aggressive but safe - WSL2 kernel is provided by Windows, doesn't use Linux firmware blobs.

## Rationale
{"anomaly": "WSL2 carries unnecessary kernel/firmware bloat", "approach": "Remove firmware and old kernels since WSL2 kernel is Windows-provided", "alternatives_rejected": ["Keep firmware (wastes 300MB)", "Keep headers (wastes 200MB)"]}
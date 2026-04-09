---
scope: User expectations and script documentation - not code changes
kind: episteme
content_hash: 242ca254e3b7605e4bcc40a26d3f6834
---

# Hypothesis: WSLg Clarification - Cannot Clean from WSL

CRITICAL CLARIFICATION for user understanding:

The 6.3GB shown by 'du -sh /mnt/wslg' is NOT part of the distro's ext4.vhdx!

Technical facts:
1. /mnt/wslg is a SEPARATE Windows-managed VHDX
2. It's mounted READ-ONLY from within WSL2
3. The cleanup script CANNOT reduce this size
4. It auto-regenerates on WSL restart

What /mnt/wslg contains:
- WSLg system (Weston, Xwayland, PulseAudio)
- Shared libraries for GUI apps
- NOT your distro's files

To reduce WSLg (from Windows PowerShell):
1. wsl --shutdown
2. WSLg VHDX is at: %LOCALAPPDATA%\Packages\MicrosoftCorporationII.WindowsSubsystemForLinux_*\LocalState\

ACTUAL distro size check:
- Run: df -h /
- This shows your REAL distro size
- Target < 1.9GB applies to THIS, not /mnt/wslg

The script should focus on root filesystem optimization, not /mnt/wslg.

## Rationale
{"anomaly": "User measured /mnt/wslg (6.3GB) thinking it's distro size", "approach": "Clarify that /mnt/wslg is Windows-managed, focus on df -h / instead", "alternatives_rejected": ["Attempt to modify /mnt/wslg (read-only, will fail)"]}
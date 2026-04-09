---
target: wslg-clarification-cannot-clean-from-wsl
verdict: pass
assurance_level: L2
carrier_ref: test-runner
valid_until: 2026-04-07
date: 2026-01-07
id: 2026-01-07-external-wslg-clarification-cannot-clean-from-wsl.md
type: external
content_hash: 1cb4676c8165bee6ac4b86149f9cc300
---

EMPIRICAL VERIFICATION of /mnt/wslg behavior:

USER'S MEASUREMENT: du -sh /mnt/wslg = 6.3GB

TECHNICAL FACTS VERIFIED:
1. /mnt/wslg mount type: 9p filesystem (Windows host share)
2. Mount options: ro (READ-ONLY) confirmed
3. Source: Windows AppData WSLg VHDX, NOT distro ext4.vhdx
4. Cannot be modified from within WSL2

SCRIPT BEHAVIOR ANALYSIS (Lines 436-545):
- Script attempts to delete from /mnt/wslg
- Most operations FAIL SILENTLY (read-only mount)
- Line 531 even acknowledges: "mounted READ-ONLY from Windows"
- Script wastes time on ineffective operations

CORRECT DISTRO SIZE MEASUREMENT:
df -h / shows actual distro (ext4.vhdx) usage
This is what the <1.9GB target should apply to

RECOMMENDATION:
1. Remove or skip WSLg cleanup section (lines 436-545) - it's ineffective
2. Add clear comment explaining /mnt/wslg is Windows-managed
3. Focus script on root filesystem optimization only

USER EDUCATION NEEDED:
- 6.3GB in /mnt/wslg is irrelevant to distro compaction
- Target <1.9GB applies to df -h / output only
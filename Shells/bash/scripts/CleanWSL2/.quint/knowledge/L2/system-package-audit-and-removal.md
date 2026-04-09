---
scope: Phase 2 (package cleanup) and Phase 4 (services) of cleanwsl2ubu7.sh
kind: system
content_hash: 9ea67534a78492305149df7a3afe1218
---

# Hypothesis: System Package Audit and Removal

Remove MORE non-essential Ubuntu packages to compensate:

Safe to remove (typically 300-600MB):
1. ubuntu-advantage-tools (~50MB)
2. landscape-common (~20MB)
3. cloud-init, cloud-guest-utils (~100MB)
4. popularity-contest
5. command-not-found, command-not-found-data (~200MB!)
6. friendly-recovery
7. plymouth, plymouth-theme-* (~30MB)
8. apport, python3-apport (~50MB)
9. whoopsie (~10MB)
10. update-notifier-common
11. unattended-upgrades
12. motd-news-config
13. fonts-* (all font packages ~100-200MB)
14. language-pack-* (except en) (~50-100MB)
15. manpages, manpages-dev (~20MB)
16. vim-common (keep vim-tiny if needed)
17. wireless-tools, wpasupplicant (not needed in WSL2)
18. bluez, bluetooth (~30MB)
19. cups-* (printing ~50MB)
20. avahi-*, libnss-mdns (mDNS ~20MB)

Implementation: apt remove --purge -y <package> for each

## Rationale
{"anomaly": "Need to recover 500MB+ without touching dev tools", "approach": "Remove bloated Ubuntu packages not needed for CLI/dev work", "alternatives_rejected": ["Remove python3 (needed)", "Remove systemd (breaks WSL2)"]}
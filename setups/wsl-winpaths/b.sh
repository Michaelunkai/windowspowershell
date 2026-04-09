#!/usr/bin/env bash
# WSL Windows-Path UNDO Script - reverses everything a.sh did
# Run with: sudo bash b.sh

set +e

step() { echo ""; echo "[$(date +%H:%M:%S)] >>> $1"; }
ok()   { echo "    OK: $1"; }
skip() { echo "    --: $1 (skipped)"; }

echo "================================================"
echo " WSL Windows-Style Path UNDO"
echo " $(date)"
echo "================================================"

# -- 1. Restore wsl.conf -------------------------------------------------------
step "1/4  Restoring /etc/wsl.conf..."
if [ -f /etc/wsl.conf.bak ]; then
  cp /etc/wsl.conf.bak /etc/wsl.conf
  ok "restored from wsl.conf.bak"
else
  # No backup - write a clean default wsl.conf
  cat > /etc/wsl.conf << 'EOF'
[automount]
enabled = true
root = /mnt/
mountFsTab = true

[interop]
enabled = true
appendWindowsPath = true

[network]
generateHosts = true
generateResolvConf = true
EOF
  ok "no backup found - wrote clean default wsl.conf"
fi
chmod 644 /etc/wsl.conf

# -- 2. Remove NOPASSWD + umask from sudoers -----------------------------------
step "2/4  Reverting sudoers..."
python3 -c "
with open('/etc/sudoers', 'r') as f: lines = f.readlines()
cleaned = [l for l in lines if 'NOPASSWD: ALL' not in l and 'umask=0000' not in l]
with open('/etc/sudoers', 'w') as f: f.writelines(cleaned)
print('    OK: removed NOPASSWD and umask=0000 from sudoers')
"

# -- 3. Remove all shell integration blocks ------------------------------------
step "3/4  Removing shell integration from rc files..."
python3 << 'PYEOF'
import re

files = [
    "/root/.bashrc", "/root/.profile",
    "/home/ubuntu/.bashrc", "/home/ubuntu/.profile",
    "/etc/bash.bashrc", "/etc/profile",
    "/etc/zsh/zshrc", "/etc/zshenv"
]
for fpath in files:
    try:
        with open(fpath, "r") as f: c = f.read()
        original = c
        # Remove WINDOWS PATH EMULATION blocks
        c = re.sub(r"\n# ===== WINDOWS PATH EMULATION =====.*?# ===== END WINDOWS PATH EMULATION =====\n?",
                   "\n", c, flags=re.DOTALL)
        # Remove stray _winjump lines
        c = re.sub(r"\n_winjump[^\n]*\n", "\n", c)
        c = c.rstrip("\n") + "\n"
        if c != original:
            with open(fpath, "w") as f: f.write(c)
            print("    OK: cleaned " + fpath)
        else:
            print("    --: " + fpath + " (nothing to remove)")
    except Exception as e:
        print("    --: " + fpath + " (" + str(e) + ")")
PYEOF

# -- 4. Reset /mnt permissions back to default 755 ----------------------------
step "4/4  Resetting /mnt/x permissions to default 755..."
for l in a b c d e f g h i j k l m n o p q r s t u v w x y z; do
  src="/mnt/$l"
  if [ -d "$src" ]; then
    chmod 755 "$src" 2>/dev/null || true
    printf "    chmod 755 /mnt/%s  OK\n" "$l"
  fi
done
ok "permissions reset"

echo ""
echo "================================================"
echo " UNDO COMPLETE at $(date +%H:%M:%S)"
echo "================================================"
echo " All changes from a.sh have been reversed:"
echo "   - wsl.conf restored to original/default"
echo "   - sudoers NOPASSWD + umask removed"
echo "   - Shell functions/PS1/aliases removed from all rc files"
echo "   - /mnt/x permissions reset to 755"
echo ""
echo " To finalize (run in PowerShell):"
echo "   wsl.exe --shutdown"
echo "   wsl"
echo "================================================"

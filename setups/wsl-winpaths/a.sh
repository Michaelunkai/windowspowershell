#!/usr/bin/env bash
# WSL Windows-Path Setup Script
# Run with: sudo bash a.sh

set +e  # never exit on error - log and continue

step() { echo ""; echo "[$(date +%H:%M:%S)] >>> $1"; }
ok()   { echo "    OK: $1"; }
skip() { echo "    --: $1 (skipped)"; }

echo "================================================"
echo " WSL Windows-Style Path Setup"
echo " $(date)"
echo "================================================"

# -- 1. wsl.conf --------------------------------------------------------------
step "1/5  Writing /etc/wsl.conf..."
cp /etc/wsl.conf /etc/wsl.conf.bak 2>/dev/null && ok "backed up to wsl.conf.bak" || true
cat > /etc/wsl.conf << 'EOF'
[automount]
enabled = true
root = /mnt/
options = "metadata,umask=000,fmask=000,dmask=000"
mountFsTab = true

[filesystem]
umask = 000

[interop]
enabled = true
appendWindowsPath = true

[network]
generateHosts = true
generateResolvConf = true
EOF
chmod 644 /etc/wsl.conf
ok "wsl.conf written (umask=000 = full permissions on all mounts)"

# -- 2. Detect drives + fix permissions on /mnt/x ------------------------------
step "2/5  Detecting drives and fixing /mnt permissions..."
# NOTE: We do NOT bind-mount /C: /D: etc -- Docker already owns those letters
# on /dev/sdX. Trying to use them causes empty ls. We use /mnt/x exclusively
# and translate paths purely in the shell layer (cd/pwd/PS1 overrides).
DRIVES_FOUND=0
for l in a b c d e f g h i j k l m n o p q r s t u v w x y z; do
  src="/mnt/$l"
  if [ -d "$src" ] && [ -n "$(ls "$src" 2>/dev/null)" ]; then
    DRIVES_FOUND=$((DRIVES_FOUND + 1))
    chmod 777 "$src" 2>/dev/null || true
    printf "    /mnt/%s  -> %s:/\n" "$l" "$(echo "$l" | tr a-z A-Z)"
  fi
done
ok "$DRIVES_FOUND Windows drive(s) found under /mnt/"

# -- 3. Remove stale /X: bind mounts (Docker conflict cleanup) -----------------
step "3/5  Removing Docker-conflicting /X: mount points..."
# Clean fstab of any old bind entries we added before
python3 -c "
with open('/etc/fstab','r') as f: lines=f.readlines()
cleaned=[l for l in lines if 'bind,nofail' not in l]
with open('/etc/fstab','w') as f: f.writelines(cleaned)
print('    OK: fstab cleaned')
"
# Unmount and remove stale /X: dirs that conflict with Docker
for l in a b c d e f g h i j k l m n o p q r s t u v w x y z; do
  L=$(echo "$l" | tr a-z A-Z)
  mp="/${L}:"
  if [ -d "$mp" ]; then
    umount -l "$mp" 2>/dev/null || true
    rmdir "$mp" 2>/dev/null && printf "    removed %s\n" "$mp" || true
  fi
done
ok "Stale /X: mount points removed (Docker conflict resolved)"

# -- 4. NOPASSWD sudo ---------------------------------------------------------
step "4/5  Configuring passwordless sudo..."
if grep -q "NOPASSWD: ALL" /etc/sudoers; then
  skip "NOPASSWD already present"
else
  echo "%sudo ALL=(ALL:ALL) NOPASSWD: ALL" >> /etc/sudoers
  ok "NOPASSWD: ALL added"
fi
if grep -q "umask=0000" /etc/sudoers; then
  skip "umask already set"
else
  echo "Defaults umask=0000" >> /etc/sudoers
  ok "Defaults umask=0000 added"
fi

# -- 5. Shell integration via Python (avoids all heredoc escape issues) --------
step "5/5  Injecting shell integration..."

python3 << 'PYEOF'
import re, os

PS1 = r"export PS1='\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]$(_winps1)\[\033[00m\]\$ '"

BLOCK = "\n# ===== WINDOWS PATH EMULATION =====\n"
BLOCK += "_to_winpath() {\n"
BLOCK += "  local p=${1:-$PWD}\n"
BLOCK += "  if [[ $p =~ ^/mnt/([a-z])(/.*)?$ ]]; then\n"
BLOCK += "    echo ${BASH_REMATCH[1]^^}:${BASH_REMATCH[2]:-/}\n"
BLOCK += "  else\n"
BLOCK += "    echo $p\n"
BLOCK += "  fi\n"
BLOCK += "}\n"
BLOCK += "_to_wslpath() {\n"
BLOCK += "  local p=$1\n"
BLOCK += "  if [[ $p =~ ^([A-Za-z]):(/.+)$ ]]; then\n"
BLOCK += "    echo /mnt/${BASH_REMATCH[1],,}${BASH_REMATCH[2]}\n"
BLOCK += "  elif [[ $p =~ ^([A-Za-z]):/?$ ]]; then\n"
BLOCK += "    echo /mnt/${BASH_REMATCH[1],,}/\n"
BLOCK += "  else\n"
BLOCK += "    echo $p\n"
BLOCK += "  fi\n"
BLOCK += "}\n"
BLOCK += "function cd() {\n"
BLOCK += "  local t=${1:-$HOME}\n"
BLOCK += "  if [[ $t =~ ^[A-Za-z]: ]]; then t=$(_to_wslpath $t); fi\n"
BLOCK += "  builtin cd $t\n"
BLOCK += "}\n"
BLOCK += "function pwd() { _to_winpath $PWD; }\n"
BLOCK += "function _winps1() { _to_winpath $PWD; }\n"
BLOCK += PS1 + "\n"
BLOCK += "for _wl in a b c d e f g h i j k l m n o p q r s t u v w x y z; do\n"
BLOCK += "  _WL=${_wl^^}\n"
BLOCK += "  [ -d /mnt/$_wl ] && alias ${_WL}:='builtin cd /mnt/'$_wl && alias ${_wl}:='builtin cd /mnt/'$_wl\n"
BLOCK += "done 2>/dev/null || true\n"
BLOCK += "function towin() { _to_winpath $1; }\n"
BLOCK += "function towsl() { _to_wslpath $1; }\n"
BLOCK += "# ===== END WINDOWS PATH EMULATION =====\n"

files = ["/root/.bashrc", "/root/.profile", "/home/ubuntu/.bashrc",
         "/etc/bash.bashrc", "/etc/profile"]
for fpath in files:
    try:
        with open(fpath, "r") as f: c = f.read()
        # Remove ALL old blocks (both old and new versions)
        c = re.sub(r"\n_winjump[^\n]*\n", "\n", c)
        c = re.sub(r"\n# ===== WINDOWS PATH EMULATION =====.*?# ===== END WINDOWS PATH EMULATION =====\n?",
                   "\n", c, flags=re.DOTALL)
        with open(fpath, "w") as f: f.write(c.rstrip("\n") + "\n" + BLOCK)
        print("    OK: " + fpath)
    except Exception as e:
        print("    --: " + fpath + " (" + str(e) + ")")
PYEOF

echo ""
echo "================================================"
echo " ALL DONE at $(date +%H:%M:%S)"
echo "================================================"
echo " Drives accessible NOW:"
for l in a b c d e f g h i j k l m n o p q r s t u v w x y z; do
  L=$(echo "$l" | tr a-z A-Z)
  [ -d "/mnt/$l" ] && [ -n "$(ls /mnt/$l 2>/dev/null)" ] && echo "   ${L}:/ -> /mnt/$l"
done
echo ""
echo " To finalize (run in PowerShell):"
echo "   wsl.exe --shutdown"
echo "   wsl"
echo "================================================"

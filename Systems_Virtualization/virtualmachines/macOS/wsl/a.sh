#!/bin/bash
# macOS Shell for WSL2 Ubuntu - FULL macOS Experience
# Run: wsl -d Ubuntu --user root -- bash /mnt/f/study/Systems_Virtualization/virtualmachines/macos/wsl/a.sh

G='\033[0;32m'; R='\033[0;31m'; Y='\033[1;33m'; N='\033[0m'
ok() { echo -e "${G}[✓]${N} $1"; }
info() { echo -e "${Y}[i]${N} $1"; }

echo "=========================================="
echo "     macOS Sequoia Shell for WSL2"
echo "=========================================="

[ "$(id -u)" -ne 0 ] && { echo "Run as root!"; exit 1; }

# Fix broken packages
info "Fixing packages..."
dpkg --force-remove-reinstreq --purge libpaper1 libpaper-utils libgs10 libspectre1 ghostscript libimlib2t64 caca-utils w3m-img 2>/dev/null || true
apt-get --fix-broken install -y 2>/dev/null || true
apt-get autoremove -y 2>/dev/null || true
ok "Fixed"

# Install EVERYTHING a real macOS terminal has
info "Installing full macOS toolset..."
apt-get update -qq
apt-get install -y -qq \
    sudo zsh git curl wget htop tree jq unzip zip \
    vim nano ncdu figlet lolcat tmux screen \
    fzf ripgrep fd-find bat eza \
    python3 python3-pip python3-venv \
    build-essential make autoconf automake libtool pkg-config \
    gcc g++ cmake \
    expect openssh-client sshpass \
    ruby ruby-dev \
    nodejs npm \
    imagemagick ffmpeg \
    neovim \
    rsync \
    sqlite3 \
    netcat-openbsd nmap dnsutils whois \
    iproute2 iputils-ping traceroute \
    file less most \
    p7zip-full unrar-free \
    pv progress \
    rename \
    bc dc \
    coreutils moreutils \
    procps psmisc \
    lsof strace ltrace \
    2>/dev/null || true
ok "Packages installed"

# Install Homebrew (Linuxbrew)
info "Installing Homebrew..."
if [ ! -d /home/linuxbrew ]; then
    mkdir -p /home/linuxbrew
    chown ubuntu:ubuntu /home/linuxbrew
fi
sudo -u ubuntu bash -c 'NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"' 2>/dev/null || true
ok "Homebrew"

# Setup ubuntu user
info "Setting up user..."
id ubuntu &>/dev/null || useradd -m -s /bin/zsh ubuntu
usermod -aG sudo ubuntu 2>/dev/null || true
echo "ubuntu ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/ubuntu
chmod 440 /etc/sudoers.d/ubuntu
chsh -s /usr/bin/zsh ubuntu
ok "User ready"

# Shell switching
cat > /usr/local/bin/mac << 'EOF'
#!/bin/bash
exec zsh -l
EOF
chmod +x /usr/local/bin/mac

cat > /usr/local/bin/ubuntu << 'EOF'
#!/bin/bash
exec bash -l
EOF
chmod +x /usr/local/bin/ubuntu
ok "Shell commands"

# Oh My Zsh
info "Installing Oh My Zsh..."
sudo -u ubuntu rm -rf /home/ubuntu/.oh-my-zsh 2>/dev/null
sudo -u ubuntu bash -c 'RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"' 2>/dev/null || true
ok "Oh My Zsh"

# Powerlevel10k
info "Installing Powerlevel10k..."
sudo -u ubuntu git clone --depth=1 https://github.com/romkatv/powerlevel10k.git /home/ubuntu/.oh-my-zsh/custom/themes/powerlevel10k 2>/dev/null || true
ok "Powerlevel10k"

# Plugins
info "Installing plugins..."
ZSH_CUSTOM="/home/ubuntu/.oh-my-zsh/custom"
sudo -u ubuntu git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions $ZSH_CUSTOM/plugins/zsh-autosuggestions 2>/dev/null || true
sudo -u ubuntu git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting $ZSH_CUSTOM/plugins/zsh-syntax-highlighting 2>/dev/null || true
sudo -u ubuntu git clone --depth=1 https://github.com/zsh-users/zsh-completions $ZSH_CUSTOM/plugins/zsh-completions 2>/dev/null || true
sudo -u ubuntu git clone --depth=1 https://github.com/zsh-users/zsh-history-substring-search $ZSH_CUSTOM/plugins/zsh-history-substring-search 2>/dev/null || true
ok "Plugins"

# Create FULL macOS .zshrc
info "Creating macOS .zshrc..."
cat > /home/ubuntu/.zshrc << 'ZSHEOF'
# macOS Sequoia Shell for WSL2
[[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]] && source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"

export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="powerlevel10k/powerlevel10k"
plugins=(git zsh-autosuggestions zsh-syntax-highlighting zsh-completions zsh-history-substring-search sudo history fzf docker npm pip python)
source $ZSH/oh-my-zsh.sh

# Homebrew
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv 2>/dev/null)" || true
export PATH="/home/linuxbrew/.linuxbrew/bin:$PATH"

# ========== macOS COMMANDS ==========

# Finder
open() { [ -z "$1" ] && explorer.exe . || explorer.exe "$(wslpath -w "$1")"; }

# Clipboard (pbcopy/pbpaste)
alias pbcopy='clip.exe'
alias pbpaste='powershell.exe -command "Get-Clipboard" | tr -d "\r"'

# Text-to-speech
say() { powershell.exe -command "Add-Type -AssemblyName System.Speech; (New-Object System.Speech.Synthesis.SpeechSynthesizer).Speak('$*')"; }

# Airport/Network
airport() {
    case "$1" in
        -s|scan) nmcli dev wifi list 2>/dev/null || iwlist scan 2>/dev/null ;;
        -I|info) ip addr show; cat /etc/resolv.conf ;;
        *) echo "airport -s (scan) | -I (info)" ;;
    esac
}

# caffeinate (prevent sleep - stub for WSL)
caffeinate() { echo "Preventing sleep... (Press Ctrl+C to stop)"; while true; do sleep 60; done; }

# diskutil
diskutil() {
    case "$1" in
        list) lsblk -o NAME,SIZE,TYPE,MOUNTPOINT,FSTYPE ;;
        info) df -h "$2" ;;
        *) echo "diskutil list | info <path>" ;;
    esac
}

# launchctl (systemctl wrapper)
launchctl() {
    case "$1" in
        list) systemctl list-units --type=service 2>/dev/null || service --status-all ;;
        start) sudo systemctl start "$2" 2>/dev/null || sudo service "$2" start ;;
        stop) sudo systemctl stop "$2" 2>/dev/null || sudo service "$2" stop ;;
        *) echo "launchctl list | start <svc> | stop <svc>" ;;
    esac
}

# mdfind (locate wrapper)
mdfind() { locate "$@" 2>/dev/null || find / -name "*$1*" 2>/dev/null | head -20; }

# screencapture
screencapture() { import "$1" 2>/dev/null || echo "Install imagemagick: brew install imagemagick"; }

# defaults (stub)
defaults() { echo "defaults: macOS preference system (not available in Linux)"; }

# networksetup
networksetup() {
    case "$1" in
        -listallhardwareports) ip link show ;;
        -getinfo) ip addr show "$2" ;;
        *) echo "networksetup -listallhardwareports | -getinfo <iface>" ;;
    esac
}

# pmset (power management stub)
pmset() { echo "Power: $(cat /sys/class/power_supply/*/capacity 2>/dev/null || echo 'AC Power')%"; }

# softwareupdate
softwareupdate() {
    case "$1" in
        -l|--list) apt list --upgradable 2>/dev/null ;;
        -i|--install) sudo apt upgrade -y ;;
        *) echo "softwareupdate -l (list) | -i (install)" ;;
    esac
}

# xcode-select
xcode-select() {
    case "$1" in
        --install) sudo apt install -y build-essential ;;
        -p|--print-path) echo "/usr/bin" ;;
        *) echo "xcode-select --install | -p" ;;
    esac
}

# ditto (advanced copy)
ditto() { rsync -av "$1" "$2"; }

# hdiutil (disk image - stub)
hdiutil() { echo "hdiutil: Use mount/umount for disk operations"; }

# security (keychain stub)
security() { echo "security: Keychain operations not available. Use pass or gnome-keyring."; }

# osascript (AppleScript stub)
osascript() { echo "osascript: AppleScript not available on Linux"; }

# plutil (plist utility stub)
plutil() { echo "plutil: Use xmllint or jq for XML/JSON"; }

# ========== SSH COMMANDS (NO PASSWORD PROMPTS!) ==========

# SSH and become root directly
rootme() {
    local target="$1" pass="$2"
    [ -z "$target" ] || [ -z "$pass" ] && { echo "Usage: rootme user@host password"; return 1; }
    expect -c "
        spawn ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null $target
        expect {
            \"password:\" { send \"$pass\r\"; exp_continue }
            \"$ \" { send \"echo '$pass' | sudo -S su -\r\" }
            \"# \" { }
        }
        expect {
            \"password\" { send \"$pass\r\" }
            \"# \" { }
        }
        interact
    "
}

# SSH only (no sudo)
sshme() {
    local target="$1" pass="$2"
    [ -z "$target" ] || [ -z "$pass" ] && { echo "Usage: sshme user@host password"; return 1; }
    sshpass -p "$pass" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "$target"
}

# SCP with password
scpme() {
    local pass="$1" src="$2" dst="$3"
    [ -z "$pass" ] || [ -z "$src" ] || [ -z "$dst" ] && { echo "Usage: scpme password source dest"; return 1; }
    sshpass -p "$pass" scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "$src" "$dst"
}

# Quick SSH to tovplay server as root
stov() {
    sshpass -p 'EbTyNkfJG6LM' ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -t admin@193.181.213.220 "sudo su - root"
}

# ========== MODERN CLI ALIASES ==========
alias ls='eza --icons --group-directories-first 2>/dev/null || ls --color=auto'
alias ll='eza -la --icons 2>/dev/null || ls -la'
alias la='eza -a --icons 2>/dev/null || ls -a'
alias lt='eza --tree --icons 2>/dev/null || tree'
alias cat='batcat --style=plain 2>/dev/null || cat'
alias bat='batcat'
alias top='htop'
alias vim='nvim 2>/dev/null || vim'
alias vi='nvim 2>/dev/null || vim'
alias grep='grep --color=auto'
alias diff='diff --color=auto'
alias fd='fdfind'
alias rg='ripgrep'

# Navigation
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias ~='cd ~'
alias -- -='cd -'

# Git
alias g='git'
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git pull'
alias gd='git diff'
alias gco='git checkout'
alias gb='git branch'
alias glog='git log --oneline --graph'

# Safety
alias rm='rm -i'
alias mv='mv -i'
alias cp='cp -i'

# Quick edits
alias zshrc='${EDITOR:-nano} ~/.zshrc && source ~/.zshrc'
alias hosts='sudo ${EDITOR:-nano} /etc/hosts'

# Network
alias ip='ip -c'
alias ports='netstat -tulanp'
alias myip='curl -s ifconfig.me'
alias localip='hostname -I | awk "{print \$1}"'

# System
alias meminfo='free -h'
alias cpuinfo='lscpu'
alias diskinfo='df -h'
alias psmem='ps auxf | sort -nr -k 4 | head -10'
alias pscpu='ps auxf | sort -nr -k 3 | head -10'

# ========== SYSTEM INFO ==========
sysinfo() {
    echo ""
    echo -e "\033[1;37m                    'c.          \033[0m"
    echo -e "\033[1;37m                 ,xNMM.          \033[0m  \033[1;37m$(whoami)@$(hostname)\033[0m"
    echo -e "\033[1;33m               .OMMMMo           \033[0m  \033[0;90m──────────────────────\033[0m"
    echo -e "\033[1;33m               OMMM0,            \033[0m  \033[1;37mOS:\033[0m macOS Sequoia 15.0"
    echo -e "\033[1;31m     .;loddo:' loolloddol;.     \033[0m  \033[1;37mHost:\033[0m MacBook Pro (M3)"
    echo -e "\033[1;31m   cKMMMMMMMMMMNWMMMMMMMMMM0:   \033[0m  \033[1;37mKernel:\033[0m Darwin 24.0.0"
    echo -e "\033[1;35m .KMMMMMMMMMMMMMMMMMMMMMMMWd.   \033[0m  \033[1;37mUptime:\033[0m $(uptime -p 2>/dev/null | sed 's/up //')"
    echo -e "\033[1;35m XMMMMMMMMMMMMMMMMMMMMMMMX.     \033[0m  \033[1;37mShell:\033[0m zsh $(zsh --version 2>/dev/null | awk '{print $2}')"
    echo -e "\033[1;34m;MMMMMMMMMMMMMMMMMMMMMMMM:      \033[0m  \033[1;37mTerminal:\033[0m Apple_Terminal"
    echo -e "\033[1;34m:MMMMMMMMMMMMMMMMMMMMMMMM:      \033[0m  \033[1;37mCPU:\033[0m $(grep 'model name' /proc/cpuinfo 2>/dev/null | head -1 | cut -d: -f2 | sed 's/^ //' | cut -c1-40)"
    echo -e "\033[1;36m.MMMMMMMMMMMMMMMMMMMMMMMMX.     \033[0m  \033[1;37mMemory:\033[0m $(free -h 2>/dev/null | awk '/^Mem:/ {print $3 "/" $2}')"
    echo -e "\033[1;36m kMMMMMMMMMMMMMMMMMMMMMMMMWd.   \033[0m  \033[1;37mDisk:\033[0m $(df -h / 2>/dev/null | awk 'NR==2 {print $3 "/" $2}')"
    echo -e "\033[1;32m .XMMMMMMMMMMMMMMMMMMMMMMMMMMk  \033[0m  \033[1;37mBrew:\033[0m $(brew --version 2>/dev/null | head -1 || echo 'not installed')"
    echo -e "\033[1;32m  .XMMMMMMMMMMMMMMMMMMMMMMMMK.  \033[0m  \033[40m  \033[41m  \033[42m  \033[43m  \033[44m  \033[45m  \033[46m  \033[47m  \033[0m"
    echo -e "\033[1;37m    kMMMMMMMMMMMMMMMMMMMMMMd    \033[0m"
    echo -e "\033[1;37m     ;KMMMMMMMWXXWMMMMMMMk.     \033[0m"
    echo -e "\033[1;37m       .coeli;   .teleoc.       \033[0m"
    echo ""
}

sw_vers() {
    echo "ProductName:		macOS"
    echo "ProductVersion:		15.0"
    echo "BuildVersion:		24A335"
}

system_profiler() {
    case "$1" in
        SPHardwareDataType)
            echo "Hardware Overview:"
            echo "  Model Name: MacBook Pro"
            echo "  Model Identifier: Mac15,3"
            echo "  Chip: Apple M3 Pro"
            echo "  Total Number of Cores: $(nproc)"
            echo "  Memory: $(free -h | awk '/^Mem:/ {print $2}')"
            echo "  System Firmware Version: 10151.1.1"
            echo "  OS Loader Version: 10151.1.1"
            ;;
        SPSoftwareDataType)
            echo "Software Overview:"
            echo "  System Version: macOS 15.0 (24A335)"
            echo "  Kernel Version: Darwin 24.0.0"
            echo "  Boot Volume: Macintosh HD"
            echo "  Computer Name: $(hostname)"
            echo "  User Name: $(whoami)"
            ;;
        *)
            echo "system_profiler SPHardwareDataType | SPSoftwareDataType"
            ;;
    esac
}

uname() {
    case "$1" in
        -a) echo "Darwin $(hostname) 24.0.0 Darwin Kernel Version 24.0.0 $(uname -m)" ;;
        -s) echo "Darwin" ;;
        -r) echo "24.0.0" ;;
        -m) command uname -m ;;
        *) command uname "$@" ;;
    esac
}

# History
export HISTSIZE=100000
export SAVEHIST=100000
export HISTFILE=~/.zsh_history
setopt SHARE_HISTORY HIST_IGNORE_DUPS HIST_IGNORE_SPACE HIST_REDUCE_BLANKS
setopt AUTO_CD AUTO_PUSHD PUSHD_IGNORE_DUPS
setopt COMPLETE_IN_WORD ALWAYS_TO_END
unset zle_bracketed_paste

# Welcome screen
clear
echo ""
echo -e "\033[1;37m                    'c.          \033[0m"
echo -e "\033[1;37m                 ,xNMM.          \033[0m"
echo -e "\033[1;33m               .OMMMMo           \033[0m"
echo -e "\033[1;33m               OMMM0,            \033[0m"
echo -e "\033[1;31m     .;loddo:' loolloddol;.     \033[0m"
echo -e "\033[1;31m   cKMMMMMMMMMMNWMMMMMMMMMM0:   \033[0m"
echo -e "\033[1;35m .KMMMMMMMMMMMMMMMMMMMMMMMWd.   \033[0m"
echo -e "\033[1;35m XMMMMMMMMMMMMMMMMMMMMMMMX.     \033[0m"
echo -e "\033[1;34m;MMMMMMMMMMMMMMMMMMMMMMMM:      \033[0m"
echo -e "\033[1;34m:MMMMMMMMMMMMMMMMMMMMMMMM:      \033[0m"
echo -e "\033[1;36m.MMMMMMMMMMMMMMMMMMMMMMMMX.     \033[0m"
echo -e "\033[1;36m kMMMMMMMMMMMMMMMMMMMMMMMMWd.   \033[0m"
echo -e "\033[1;32m .XMMMMMMMMMMMMMMMMMMMMMMMMMMk  \033[0m"
echo -e "\033[1;32m  .XMMMMMMMMMMMMMMMMMMMMMMMMK.  \033[0m"
echo -e "\033[1;37m    kMMMMMMMMMMMMMMMMMMMMMMd    \033[0m"
echo -e "\033[1;37m     ;KMMMMMMMWXXWMMMMMMMk.     \033[0m"
echo -e "\033[1;37m       .coeli;   .teleoc.       \033[0m"
echo ""
echo -e "\033[1;37m  macOS Sequoia 15.0 | $(command uname -m) | $(date +%H:%M)\033[0m"
echo -e "\033[0;90m  sysinfo | sw_vers | brew | ubuntu\033[0m"
echo -e "\033[0;90m  rootme user@host pass | sshme | scpme | stov\033[0m"
echo ""

[[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh
ZSHEOF
chown ubuntu:ubuntu /home/ubuntu/.zshrc
ok ".zshrc"

# p10k config
info "Configuring Powerlevel10k..."
cat > /home/ubuntu/.p10k.zsh << 'P10KEOF'
'builtin' 'local' '-a' 'p10k_config_opts'
[[ ! -o 'aliases' ]] || p10k_config_opts+=('aliases')
[[ ! -o 'sh_glob' ]] || p10k_config_opts+=('sh_glob')
[[ ! -o 'no_brace_expand' ]] || p10k_config_opts+=('no_brace_expand')
'builtin' 'setopt' 'no_aliases' 'no_sh_glob' 'brace_expand'

() {
  emulate -L zsh -o extended_glob
  unset -m '(POWERLEVEL9K_*|DEFAULT_USER)~POWERLEVEL9K_GITSTATUS_DIR'
  typeset -g POWERLEVEL9K_LEFT_PROMPT_ELEMENTS=(os_icon dir vcs prompt_char)
  typeset -g POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS=(status command_execution_time time)
  typeset -g POWERLEVEL9K_MODE=nerdfont-complete
  typeset -g POWERLEVEL9K_BACKGROUND=
  typeset -g POWERLEVEL9K_{LEFT,RIGHT}_{LEFT,RIGHT}_WHITESPACE=
  typeset -g POWERLEVEL9K_{LEFT,RIGHT}_SUBSEGMENT_SEPARATOR=' '
  typeset -g POWERLEVEL9K_{LEFT,RIGHT}_SEGMENT_SEPARATOR=
  typeset -g POWERLEVEL9K_OS_ICON_FOREGROUND=7
  typeset -g POWERLEVEL9K_OS_ICON_CONTENT_EXPANSION='🍎'
  typeset -g POWERLEVEL9K_DIR_FOREGROUND=31
  typeset -g POWERLEVEL9K_VCS_CLEAN_FOREGROUND=76
  typeset -g POWERLEVEL9K_VCS_MODIFIED_FOREGROUND=178
  typeset -g POWERLEVEL9K_PROMPT_CHAR_OK_{VIINS,VICMD,VIVIS,VIOWR}_FOREGROUND=76
  typeset -g POWERLEVEL9K_PROMPT_CHAR_ERROR_{VIINS,VICMD,VIVIS,VIOWR}_FOREGROUND=196
  typeset -g POWERLEVEL9K_PROMPT_CHAR_{OK,ERROR}_VIINS_CONTENT_EXPANSION='❯'
  typeset -g POWERLEVEL9K_STATUS_OK=false
  typeset -g POWERLEVEL9K_TIME_FOREGROUND=66
  typeset -g POWERLEVEL9K_TIME_FORMAT='%D{%H:%M}'
  typeset -g POWERLEVEL9K_TRANSIENT_PROMPT=same-dir
  typeset -g POWERLEVEL9K_INSTANT_PROMPT=quiet
  (( ${#p10k_config_opts} )) && setopt ${p10k_config_opts[@]}
  'builtin' 'unset' 'p10k_config_opts'
}
P10KEOF
chown ubuntu:ubuntu /home/ubuntu/.p10k.zsh
ok "p10k"

# WSL config
grep -q "\[user\]" /etc/wsl.conf 2>/dev/null || echo -e "\n[user]\ndefault=ubuntu" >> /etc/wsl.conf
ok "WSL config"

echo ""
echo "=========================================="
echo -e "${G}  macOS Sequoia Shell Ready!${N}"
echo "=========================================="
echo ""
echo "macOS Commands: open, pbcopy, pbpaste, say, sw_vers, sysinfo"
echo "                system_profiler, diskutil, launchctl, airport"
echo "                softwareupdate, xcode-select, ditto, mdfind"
echo ""
echo "SSH (no passwords!): rootme user@host pass"
echo "                     sshme user@host pass"
echo "                     scpme pass src dst"
echo "                     stov (quick root to 193.181.213.220)"
echo ""
echo "Package Manager: brew install/update/upgrade/search"
echo ""
sleep 1

info "Entering macOS shell..."
exec sudo -u ubuntu /usr/bin/zsh -l

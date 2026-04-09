#!/usr/bin/env bash
set -euo pipefail

echo "[*] Step 0: Basic dpkg/apt sanity"
sudo dpkg --configure -a || true
sudo apt clean

echo "[*] Step 1: Try to auto-fix broken dependencies"
sudo apt -o APT::Get::Fix-Broken=true install -y || true

echo "[*] Step 2: Rebuild dpkg status for packages with missing file lists"
echo "    This can be slow if many packages are broken."
MISSING_PKGS=$(grep -oP "^dpkg: warning: files list file for package '\K[^']+" /var/log/apt/term.log 2>/dev/null | sort -u || true)
if [ -n "${MISSING_PKGS:-}" ]; then
  echo "    Reinstalling packages with missing file lists:"
  echo "${MISSING_PKGS}"
  # reinstall without prompting; ignore failures to continue
  sudo apt install --reinstall -y ${MISSING_PKGS} || true
fi

echo "[*] Step 3: Force reinstall dpkg and core apt libs"
sudo apt install --reinstall -y dpkg apt libapt-pkg6.0 || true

echo "[*] Step 4: Try to repair libc6 / libc6-dev mismatch explicitly"
# Discover installed libc6 version and try to align libc6-dev with it
LIBC_VER=$(dpkg-query -W -f='${Version}\n' libc6 2>/dev/null || echo "")
if [ -n "$LIBC_VER" ]; then
  echo "    Detected libc6 version: $LIBC_VER"
  # try to install matching libc6-dev and friends
  sudo apt install -y \
    "libc6=$LIBC_VER" \
    "libc6-dev=$LIBC_VER" \
    libc-dev-bin libcrypt-dev || true
fi

echo "[*] Step 5: Run apt fix-broken again after libc attempt"
sudo apt -o APT::Get::Fix-Broken=true install -y || true

echo "[*] Step 6: Core build tools (may still fail if system is too broken)"
sudo apt install -y \
  build-essential \
  wget curl git ca-certificates \
  pkg-config \
  gcc g++ make \
  lldb gdb || true

echo "[*] Step 7: Optional dev tools"
sudo apt install -y \
  unzip \
  ripgrep \
  fd-find \
  tmux \
  nano vim || true

###############################################################################
# Go install (same as before, assuming the system is now sane enough)
###############################################################################
GO_VERSION="${GO_VERSION:-latest}"
GO_INSTALL_DIR="/usr/local"
GO_WORKSPACE="$HOME/go"
SHELL_RC="$HOME/.bashrc"

echo "[*] Detecting architecture for Go..."
ARCH="$(uname -m)"
case "$ARCH" in
  x86_64)  GO_ARCH="amd64" ;;
  aarch64) GO_ARCH="arm64" ;;
  armv7l)  GO_ARCH="armv6l" ;;
  *) echo "Unsupported architecture: $ARCH"; exit 1 ;;
esac

echo "[*] Determining Go version..."
if [ "$GO_VERSION" = "latest" ]; then
  GO_VERSION="$(curl -s https://go.dev/VERSION?m=text | head -n1 | sed 's/^go//')"
fi
echo "    Installing Go version: $GO_VERSION"

GO_TARBALL="go${GO_VERSION}.linux-${GO_ARCH}.tar.gz"
GO_URL="https://go.dev/dl/${GO_TARBALL}"

echo "[*] Downloading Go from ${GO_URL}..."
cd /tmp
rm -f "go${GO_VERSION}.linux-"*.tar.gz || true
curl -fsSL "$GO_URL" -o "$GO_TARBALL"

echo "[*] Removing any existing Go installation..."
sudo rm -rf "${GO_INSTALL_DIR}/go"

echo "[*] Extracting Go..."
sudo tar -C "$GO_INSTALL_DIR" -xzf "$GO_TARBALL"

echo "[*] Setting up Go workspace..."
mkdir -p "${GO_WORKSPACE}/"{bin,pkg,src}

echo "[*] Configuring Go environment in ${SHELL_RC}..."
sed -i '/# >>> go environment >>>/,/# <<< go environment <<</d' "$SHELL_RC" 2>/dev/null || true
cat >> "$SHELL_RC" <<'EOF'
# >>> go environment >>>
export GOROOT=/usr/local/go
export GOPATH=$HOME/go
export PATH=$PATH:$GOROOT/bin:$GOPATH/bin
# <<< go environment <<<
EOF

export GOROOT=/usr/local/go
export GOPATH="$GO_WORKSPACE"
export PATH="$PATH:$GOROOT/bin:$GOPATH/bin"

echo "[*] Verifying Go..."
go version || { echo 'Go failed to run; system may still be broken.'; exit 1; }

echo "[*] Installing Go tooling..."
go install golang.org/x/tools/gopls@latest
go install golang.org/x/tools/cmd/goimports@latest
go install golang.org/x/tools/cmd/stringer@latest
go install golang.org/x/tools/cmd/gorename@latest
go install golang.org/x/tools/cmd/guru@latest
go install golang.org/x/tools/cmd/cover@latest
go install github.com/go-delve/delve/cmd/dlv@latest
go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest
go install honnef.co/go/tools/cmd/staticcheck@latest
go install mvdan.cc/gofumpt@latest
go install github.com/kisielk/errcheck@latest
go install github.com/fatih/gomodifytags@latest
go install github.com/josharian/impl@latest
go install gotest.tools/gotestsum@latest || true
go install github.com/cweill/gotests/...@latest || true
go install github.com/golang/mock/mockgen@latest || true

echo
echo "[*] Done. If apt/dpkg errors persist, this WSL Ubuntu is likely unrecoverable."
echo "    In that case, exporting data and recreating the distro is strongly recommended."

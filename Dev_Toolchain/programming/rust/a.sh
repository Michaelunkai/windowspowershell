#!/bin/bash
# rust-setup.sh - Complete Rust Development Environment Setup for WSL2 Ubuntu
# Run: bash rust-setup.sh

set -e

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║           COMPLETE RUST DEVELOPMENT ENVIRONMENT SETUP          ║"
echo "╚════════════════════════════════════════════════════════════════╝"

# Step 1: System dependencies
echo -e "\n[1/8] Installing system build dependencies..."
sudo apt update
sudo apt install -y \
    build-essential \
    gcc \
    g++ \
    make \
    pkg-config \
    libssl-dev \
    libsqlite3-dev \
    libdbus-1-dev \
    libcurl4-openssl-dev \
    libpq-dev \
    cmake \
    curl \
    git \
    jq

echo -e "\n[2/8] Verifying gcc installation..."
gcc --version || { echo "ERROR: gcc not installed"; exit 1; }

# Step 3: Clean old Rust
echo -e "\n[3/8] Removing any existing Rust installation..."
rm -rf ~/.cargo ~/.rustup 2>/dev/null || true
unalias cargo 2>/dev/null || true
hash -r

# Step 4: Install Rust
echo -e "\n[4/8] Installing Rust via rustup..."
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable --profile default
source "$HOME/.cargo/env"

echo -e "\n[5/8] Verifying Rust installation..."
rustc --version
cargo --version

# Step 6: Rustup components
echo -e "\n[6/8] Installing Rust components..."
rustup update stable
rustup component add \
    clippy \
    rustfmt \
    rust-src \
    rust-analyzer \
    llvm-tools-preview

# Step 7: Cargo tools
echo -e "\n[7/8] Installing cargo tools (this takes a while)..."

# Essential tools
cargo install --locked cargo-edit
cargo install --locked cargo-watch
cargo install --locked cargo-expand
cargo install --locked cargo-audit
cargo install --locked cargo-outdated
cargo install --locked cargo-bloat
cargo install --locked cargo-deny
cargo install --locked cargo-binutils
cargo install --locked cargo-update
cargo install --locked cargo-tree
cargo install --locked cargo-modules
cargo install --locked cargo-llvm-cov
cargo install --locked cargo-nextest
cargo install --locked cargo-make
cargo install --locked cargo-criterion
cargo install --locked cargo-flamegraph
cargo install --locked cargo-asm

# Optional tools (don't fail if these don't compile)
echo -e "\nInstalling optional tools..."
cargo install --locked cargo-geiger 2>/dev/null || echo "Skipped cargo-geiger"
cargo install --locked cargo-udeps 2>/dev/null || echo "Skipped cargo-udeps"
cargo install --locked cargo-tarpaulin 2>/dev/null || echo "Skipped cargo-tarpaulin"
cargo install --locked cargo-deadlinks 2>/dev/null || echo "Skipped cargo-deadlinks"

# Bonus useful tools
cargo install --locked sccache
cargo install --locked bacon
cargo install --locked just
cargo install --locked tokei
cargo install --locked ripgrep
cargo install --locked fd-find
cargo install --locked bat
cargo install --locked exa
cargo install --locked hyperfine
cargo install --locked git-delta

# Step 8: Shell configuration
echo -e "\n[8/8] Configuring shell environment..."
cat >> ~/.bashrc << 'RUSTEOF'

# ===== Rust Development Environment =====
source "$HOME/.cargo/env" 2>/dev/null || true
export PATH="$HOME/.cargo/bin:$PATH"

# sccache for faster builds
export RUSTC_WRAPPER=sccache

# Rust aliases
alias c='cargo'
alias cb='cargo build'
alias cbr='cargo build --release'
alias cr='cargo run'
alias crr='cargo run --release'
alias ct='cargo test'
alias cc='cargo check'
alias ccl='cargo clippy'
alias cf='cargo fmt'
alias cw='cargo watch -x check'
alias cwt='cargo watch -x test'
alias cwr='cargo watch -x run'
alias cu='cargo update'
alias cdoc='cargo doc --open'
alias cnew='cargo new'
alias cadd='cargo add'
alias crm='cargo rm'
alias caud='cargo audit'
alias cout='cargo outdated'
alias cbloat='cargo bloat --release'
alias casm='cargo asm'
alias cnx='cargo nextest run'

# Update all cargo tools
alias rustup-all='rustup update && cargo install-update -a'

# Quick project commands
alias just='just'
alias j='just'
alias ba='bacon'

# Better ls/cat if installed
command -v exa &>/dev/null && alias ls='exa --icons' && alias ll='exa -la --icons' && alias tree='exa --tree --icons'
command -v bat &>/dev/null && alias cat='bat --style=plain'

# Rust environment info
rustinfo() {
    echo "Rust: $(rustc --version)"
    echo "Cargo: $(cargo --version)"
    echo "Rustup: $(rustup --version)"
    echo "Default toolchain: $(rustup default)"
    echo "Installed targets: $(rustup target list --installed | tr '\n' ' ')"
}
RUSTEOF

# Create cargo config for faster linking
mkdir -p ~/.cargo
cat >> ~/.cargo/config.toml << 'CARGOEOF'

[target.x86_64-unknown-linux-gnu]
linker = "clang"
rustflags = ["-C", "link-arg=-fuse-ld=lld"]

[build]
rustc-wrapper = "sccache"

[net]
git-fetch-with-cli = true

[registries.crates-io]
protocol = "sparse"
CARGOEOF

# Install lld for faster linking
sudo apt install -y clang lld

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║                    SETUP COMPLETE!                             ║"
echo "╠════════════════════════════════════════════════════════════════╣"
echo "║  Run: source ~/.bashrc                                         ║"
echo "║  Then: rustinfo                                                ║"
echo "║                                                                ║"
echo "║  Aliases: c, cb, cr, ct, cc, ccl, cf, cw, cnx                  ║"
echo "║  Update all: rustup-all                                        ║"
echo "╚════════════════════════════════════════════════════════════════╝"

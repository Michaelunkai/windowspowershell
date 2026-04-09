#!/bin/bash

# WSL2 Ubuntu Snap Installation Script
# This script installs and configures snap and snapd in WSL2 Ubuntu

echo "Installing snap and snapd in WSL2 Ubuntu..."

# Execute the full installation process in WSL2 Ubuntu
sudo rm -f /usr/bin/apt-show-versions && sudo bash -c "cat > /etc/apt/sources.list.d/ubuntu.sources << EOF
Types: deb
URIs: http://archive.ubuntu.com/ubuntu/
Suites: noble noble-updates noble-backports
Components: main restricted universe multiverse

Types: deb
URIs: http://security.ubuntu.com/ubuntu/
Suites: noble-security
Components: main restricted universe multiverse
EOF" && sudo apt update -y && sudo apt install -y snapd && sudo systemctl unmask snapd.service && sudo systemctl enable --now snapd.service && sudo systemctl start snapd && sudo ln -sf /var/lib/snapd/snap /snap && sudo snap install core && sudo systemctl daemon-reload && sudo systemctl restart snapd && sleep 3 && snap version && echo "Snap installation completed successfully!"
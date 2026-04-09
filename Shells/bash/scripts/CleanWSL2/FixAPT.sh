#!/bin/bash
# Emergency APT Fix Script
# Run this to ensure mousepad and all packages can be found

set -e

echo "╔══════════════════════════════════════════════════════╗"
echo "║       APT PACKAGE LISTS EMERGENCY UPDATE             ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""

# Verify sources are correct
echo "🔍 Step 1/4: Verifying APT sources configuration..."
UBUNTU_CODENAME=$(lsb_release -cs 2>/dev/null || echo "noble")

if [ ! -f /etc/apt/sources.list.d/ubuntu.sources ]; then
    echo "⚠️  Creating APT sources file..."
    sudo bash -c "cat > /etc/apt/sources.list.d/ubuntu.sources << 'EOFSOURCES'
Types: deb
URIs: http://archive.ubuntu.com/ubuntu/
Suites: ${UBUNTU_CODENAME} ${UBUNTU_CODENAME}-updates ${UBUNTU_CODENAME}-security ${UBUNTU_CODENAME}-backports
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg

EOFSOURCES"
    sudo sed -i "s/\${UBUNTU_CODENAME}/$UBUNTU_CODENAME/g" /etc/apt/sources.list.d/ubuntu.sources
fi

echo "✅ Sources configured:"
cat /etc/apt/sources.list.d/ubuntu.sources
echo ""

# Clear old lists
echo "🧹 Step 2/4: Clearing old package lists..."
sudo rm -rf /var/lib/apt/lists/*
sudo mkdir -p /var/lib/apt/lists/partial
echo "✅ Old lists cleared"
echo ""

# Update APT with retries
echo "🔄 Step 3/4: Downloading fresh package lists (with retries)..."
APT_SUCCESS=false
for attempt in 1 2 3 4 5; do
    echo "   Attempt $attempt/5..."
    if sudo apt-get update -y 2>&1 | tee /tmp/apt_update_output.log; then
        if grep -qE "(Hit:|Get:|Fetched)" /tmp/apt_update_output.log; then
            if [ -n "$(ls -A /var/lib/apt/lists/ 2>/dev/null | grep -v 'partial\|lock\|auxfiles')" ]; then
                APT_SUCCESS=true
                echo "   ✅ Package lists downloaded successfully!"
                break
            fi
        fi
    fi
    if [ $attempt -lt 5 ]; then
        echo "   ⚠️  Retry in 2 seconds..."
        sleep 2
    fi
done

rm -f /tmp/apt_update_output.log

if [ "$APT_SUCCESS" != true ]; then
    echo ""
    echo "❌ ERROR: Unable to download package lists"
    echo ""
    echo "Possible causes:"
    echo "  1. No internet connection"
    echo "  2. DNS not working (try: ping archive.ubuntu.com)"
    echo "  3. Firewall blocking connections"
    echo ""
    echo "Please fix internet connection and run this script again."
    exit 1
fi

echo ""

# Verify mousepad is available
echo "🧪 Step 4/4: Verifying mousepad package is available..."
if apt-cache show mousepad >/dev/null 2>&1; then
    echo "✅ SUCCESS: mousepad package found!"
    echo ""
    echo "╔══════════════════════════════════════════════════════╗"
    echo "║                 🎉 ALL FIXED! 🎉                     ║"
    echo "╚══════════════════════════════════════════════════════╝"
    echo ""
    echo "You can now install mousepad:"
    echo "   sudo apt install mousepad -y"
    echo ""
    echo "Or any other package from universe repository:"
    echo "   sudo apt install <package-name>"
    echo ""
else
    echo "⚠️  mousepad still not found"
    echo ""
    echo "Let me check what's in the package cache..."
    echo "Total packages available: $(apt-cache pkgnames | wc -l)"
    echo ""

    # Try searching
    if apt-cache search text editor | head -5; then
        echo ""
        echo "✅ APT is working, but mousepad might not be in noble repository"
        echo "Try alternatives:"
        echo "   sudo apt install gedit nano vim"
    else
        echo "❌ APT cache is not working properly"
        echo "Run: sudo apt update"
    fi
fi

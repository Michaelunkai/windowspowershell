#!/bin/bash

set -e

echo "=========================================="
echo "Oracle Cloud CLI - Automated Setup"
echo "=========================================="
echo ""

# Fixed Configuration
USER_OCID="ocid1.user.oc1..aaaaaaaa4a7smztde6tdgdgilazafzhao523jqjja5ul5h7m3lu2hbgd5s6q"
TENANCY_OCID="ocid1.tenancy.oc1..aaaaaaaaxed7axjli7petafuldvk6plborcmwmlfmjmp6ue2awws2abh2olq"
REGION="us-ashburn-1"
FINGERPRINT="52:e5:80:d1:71:b1:75:1d:22:50:59:4b:1f:b8:c9:87"
KEY_SOURCE="/mnt/f/backup/windowsapps/Credentials/oracle"

# Suppress warnings
export SUPPRESS_LABEL_WARNING=True

echo "[1/5] Installing dependencies..."
apt update -qq > /dev/null 2>&1
apt install -y python3-pip openssl curl jq -qq > /dev/null 2>&1
echo "✓ Dependencies installed"

echo "[2/5] Installing OCI CLI..."
if ! command -v oci &> /dev/null; then
    pip3 install oci-cli --quiet --break-system-packages 2>/dev/null || pip3 install oci-cli --quiet
fi
echo "✓ OCI CLI installed"

# Add to PATH
export PATH=$PATH:/root/.local/bin
if ! grep -q "export PATH=\$PATH:/root/.local/bin" /root/.bashrc; then
    echo 'export PATH=$PATH:/root/.local/bin' >> /root/.bashrc
fi
if ! grep -q "export SUPPRESS_LABEL_WARNING=True" /root/.bashrc; then
    echo 'export SUPPRESS_LABEL_WARNING=True' >> /root/.bashrc
fi

echo "[3/5] Setting up API keys..."
mkdir -p /root/.oci

# Copy keys from backup location
if [ -f "$KEY_SOURCE/michaelovsky5@gmail.com-2025-11-05T20_28_28.950Z.pem" ]; then
    cp "$KEY_SOURCE/michaelovsky5@gmail.com-2025-11-05T20_28_28.950Z.pem" /root/.oci/oci_api_key.pem
    cp "$KEY_SOURCE/michaelovsky5@gmail.com-2025-11-05T20_28_31.389Z_public.pem" /root/.oci/oci_api_key_public.pem
    chmod 600 /root/.oci/oci_api_key.pem
    chmod 644 /root/.oci/oci_api_key_public.pem
    echo "✓ API keys configured"
else
    echo "❌ Error: Keys not found at $KEY_SOURCE"
    exit 1
fi

echo "[4/5] Creating OCI configuration..."
cat > /root/.oci/config << EOF
[DEFAULT]
user=$USER_OCID
fingerprint=$FINGERPRINT
tenancy=$TENANCY_OCID
region=$REGION
key_file=/root/.oci/oci_api_key.pem
EOF
chmod 600 /root/.oci/config
echo "✓ Configuration created"

echo "[5/5] Testing OCI CLI..."
echo ""

# Test with retries
MAX_RETRIES=10
RETRY=0
SUCCESS=false

while [ $RETRY -lt $MAX_RETRIES ]; do
    ATTEMPT=$((RETRY+1))
    
    if [ $ATTEMPT -eq 1 ]; then
        echo "Testing connection..."
    else
        echo "Retry attempt $ATTEMPT/$MAX_RETRIES..."
    fi
    
    if oci iam region list --output table > /tmp/oci_test.out 2>&1; then
        SUCCESS=true
        break
    else
        RETRY=$((RETRY+1))
        if [ $RETRY -lt $MAX_RETRIES ]; then
            sleep 5
        fi
    fi
done

echo ""
echo "=========================================="

if [ "$SUCCESS" = true ]; then
    echo "✅ SUCCESS! Oracle CLI is working!"
    echo "=========================================="
    echo ""
    
    echo "Available Regions:"
    oci iam region list --output table
    
    echo ""
    echo "Compartments:"
    oci iam compartment list --all --output table 2>/dev/null | head -20
    
    echo ""
    echo "Configuration:"
    echo "  User: $USER_OCID"
    echo "  Tenancy: $TENANCY_OCID"
    echo "  Region: $REGION"
    echo "  Fingerprint: $FINGERPRINT"
    echo ""
    echo "✅ Oracle CLI ready to use!"
    
else
    echo "❌ FAILED after $MAX_RETRIES attempts"
    echo "=========================================="
    echo ""
    echo "Last error:"
    cat /tmp/oci_test.out
    echo ""
    echo "Please verify:"
    echo "1. Public key is uploaded to Oracle Cloud Console"
    echo "2. Fingerprint matches: $FINGERPRINT"
    echo "3. User/Tenancy OCIDs are correct"
    exit 1
fi

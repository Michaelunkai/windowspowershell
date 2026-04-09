#!/bin/bash

echo "=== pgAdmin4 Complete Setup Script ==="
cd ~

# Kill any existing pgAdmin processes (avoid killing ourselves - script is in pgadmin4 folder)
echo "[1/9] Killing existing pgAdmin processes..."
killall -9 pgadmin4 2>/dev/null || true
pkill -9 -f '/usr/pgadmin4' 2>/dev/null || true
sleep 1

# Add pgAdmin4 repository
echo "[2/9] Adding pgAdmin4 repository..."
curl -fsS https://www.pgadmin.org/static/packages_pgadmin_org.pub | sudo gpg --dearmor --yes -o /usr/share/keyrings/pgadmin.gpg
DISTRO=$(lsb_release -cs)
echo "Detected distro: $DISTRO"
echo "deb [signed-by=/usr/share/keyrings/pgadmin.gpg] https://ftp.postgresql.org/pub/pgadmin/pgadmin4/apt/$DISTRO pgadmin4 main" | sudo tee /etc/apt/sources.list.d/pgadmin4.list

# Install pgAdmin4 with all dependencies
echo "[3/9] Installing pgAdmin4 and dependencies..."
sudo apt update -y 2>&1 | grep -v "GDBus.Error" || true
sudo DEBIAN_FRONTEND=noninteractive apt install -y pgadmin4-desktop sqlite3 \
    libnspr4 libnss3 libatk1.0-0 libatk-bridge2.0-0 libcups2 libxkbcommon0 libxdamage1 \
    libasound2t64 libgbm1 libxshmfence1 libxrandr2 libxcomposite1 libxcursor1 libxi6 \
    libxtst6 libpango-1.0-0 libpangocairo-1.0-0 libgtk-3-0 2>&1 | grep -v "GDBus.Error" || true

# Create symlink for global pgadmin4 command
echo "[4/9] Creating global pgadmin4 symlink..."
sudo ln -sf /usr/pgadmin4/bin/pgadmin4 /usr/local/bin/pgadmin4

# Clean up any existing config - fresh start
echo "[5/9] Cleaning up existing pgAdmin config..."
rm -rf ~/.pgadmin
mkdir -p ~/.pgadmin

# Create pgpass file for PostgreSQL passwordless connection
# This file format: hostname:port:database:username:password
# Using * for database means it applies to all databases on this host
echo "[6/9] Creating .pgpass for PostgreSQL authentication..."
cat > ~/.pgpass << 'PGPASSEOF'
45.148.28.196:5432:*:raz@tovtech.org:CaptainForgotCreatureBreak
PGPASSEOF
chmod 600 ~/.pgpass
export PGPASSFILE=~/.pgpass

# Create pgAdmin4 config - MASTER_PASSWORD_REQUIRED=False bypasses master password prompt
echo "[7/9] Creating pgAdmin4 config_local.py..."
cat > ~/.pgadmin/config_local.py << 'CONFIGEOF'
import os
MASTER_PASSWORD_REQUIRED = False
ALLOW_SAVE_PASSWORD = True
SERVER_MODE = False
UPGRADE_CHECK_ENABLED = False
DATA_DIR = os.path.expanduser('~/.pgadmin')
CONFIGEOF

# Set environment variables
export ELECTRON_DISABLE_GPU=1
export ELECTRON_DISABLE_SANDBOX=1

# First launch pgAdmin4 to create database
echo "[8/9] Initial pgAdmin4 launch to create database..."
timeout 15 pgadmin4 --no-sandbox --disable-gpu 2>&1 | grep -v "gpu_process\|Exiting GPU\|InitializeSandbox\|wayland" &
PID=$!
echo "Started pgAdmin4 with PID: $PID"

# Wait for database to be created
for i in {1..20}; do
    if [ -f ~/.pgadmin/pgadmin4.db ]; then
        echo "Database created after ${i}s!"
        break
    fi
    echo "Waiting for database... ${i}s"
    sleep 1
done

# Kill the initial instance
kill $PID 2>/dev/null || true
wait $PID 2>/dev/null || true
sleep 2

# Verify database exists
if [ ! -f ~/.pgadmin/pgadmin4.db ]; then
    echo "Database not created on first attempt, trying again..."
    timeout 25 pgadmin4 --no-sandbox --disable-gpu 2>&1 | grep -v "gpu_process\|Exiting GPU" &
    PID=$!
    for i in {1..25}; do
        if [ -f ~/.pgadmin/pgadmin4.db ]; then
            echo "Database created on retry after ${i}s!"
            break
        fi
        sleep 1
    done
    kill $PID 2>/dev/null || true
    wait $PID 2>/dev/null || true
    sleep 2
fi

# Final check
if [ ! -f ~/.pgadmin/pgadmin4.db ]; then
    echo "FATAL: pgadmin4.db not created!"
    ls -la ~/.pgadmin/
    exit 1
fi

echo "[9/9] Injecting server configuration..."

# Ensure server group exists and insert server
# IMPORTANT: password field must be empty - pgAdmin expects encrypted passwords
# We rely on .pgpass file for authentication + connection_params passfile setting
sqlite3 ~/.pgadmin/pgadmin4.db "INSERT OR IGNORE INTO servergroup (id, user_id, name) VALUES (1, 1, 'Servers');"
sqlite3 ~/.pgadmin/pgadmin4.db "DELETE FROM server WHERE id = 1;"
sqlite3 ~/.pgadmin/pgadmin4.db "INSERT INTO server (id, user_id, servergroup_id, name, host, port, maintenance_db, username, password, save_password, role, connection_params) VALUES (1, 1, 1, 'pythia-db', '45.148.28.196', 5432, 'pythia-db', 'raz@tovtech.org', '', 0, '', '{\"sslmode\": \"prefer\", \"connect_timeout\": 30, \"passfile\": \"$HOME/.pgpass\"}');"

# Verify insertion
echo "Server configured:"
sqlite3 ~/.pgadmin/pgadmin4.db "SELECT name, host, port, username FROM server;"

echo ""
echo "=========================================="
echo "Server: pythia-db @ 45.148.28.196:5432"
echo "User: raz@tovtech.org"
echo "Master password: DISABLED"
echo "Auth: via .pgpass file (no password prompt)"
echo "=========================================="
echo ""
echo "Launching pgAdmin4..."

# Launch final pgAdmin4
export ELECTRON_DISABLE_GPU=1
export PGPASSFILE=~/.pgpass
exec pgadmin4 --no-sandbox --disable-gpu

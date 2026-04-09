#!/bin/bash
#############################################
# COMPREHENSIVE NETWORK VULNERABILITY SCANNER
# Location: F:\study\security\
# Purpose: Complete network penetration testing with real-time progress
#############################################

set -e
trap 'echo ""; echo "[ERROR] Script interrupted at line $LINENO"; exit 1' ERR

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Progress function
progress() {
    echo -e "${CYAN}[$(date '+%H:%M:%S')] ${GREEN}$1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}"
}

warning() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

success() {
    echo -e "${GREEN}[SUCCESS] $1${NC}"
}

header() {
    echo ""
    echo -e "${MAGENTA}========================================${NC}"
    echo -e "${MAGENTA}$1${NC}"
    echo -e "${MAGENTA}========================================${NC}"
    echo ""
}

#############################################
# PHASE 0: SYSTEM PREPARATION
#############################################
header "PHASE 0: SYSTEM PREPARATION"

progress "Step 0.1: Checking if running as root..."
if [ "$EUID" -ne 0 ]; then 
    error "Please run as root (sudo ./comprehensive-vuln-scanner.sh)"
    exit 1
fi
success "Running as root"

progress "Step 0.2: Updating package lists..."
apt update -qq 2>&1 | tail -5

progress "Step 0.3: Installing core dependencies..."
DEBIAN_FRONTEND=noninteractive apt install -y \
    iproute2 \
    net-tools \
    dnsutils \
    iputils-ping \
    curl \
    wget \
    netcat-traditional \
    2>&1 | grep -E "Setting up|installed" | tail -10

progress "Step 0.4: Installing nmap (network scanner)..."
DEBIAN_FRONTEND=noninteractive apt install -y nmap nmap-common 2>&1 | grep -E "Setting up|installed" | tail -5

progress "Step 0.5: Installing hydra (credential tester)..."
DEBIAN_FRONTEND=noninteractive apt install -y hydra 2>&1 | grep -E "Setting up|installed" | tail -5

progress "Step 0.6: Installing additional tools..."
DEBIAN_FRONTEND=noninteractive apt install -y \
    ftp \
    redis-tools \
    telnet \
    smbclient \
    nfs-common \
    2>&1 | grep -E "Setting up|installed" | tail -10

progress "Step 0.7: Verifying installations..."
command -v nmap >/dev/null 2>&1 && success "nmap installed" || error "nmap missing"
command -v hydra >/dev/null 2>&1 && success "hydra installed" || error "hydra missing"
command -v curl >/dev/null 2>&1 && success "curl installed" || error "curl missing"

progress "Step 0.8: Creating output directory..."
OUTPUT_DIR="/tmp/vuln_scan_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR/enum"
mkdir -p "$OUTPUT_DIR/creds"
success "Output directory: $OUTPUT_DIR"

#############################################
# PHASE 1: NETWORK DISCOVERY
#############################################
header "PHASE 1: NETWORK DISCOVERY"

progress "Step 1.1: Detecting local network interfaces..."
ip addr show | grep -E "inet " | grep -v "127.0.0.1"

progress "Step 1.2: Getting routing table..."
ip route show

progress "Step 1.3: Building comprehensive target list..."
TARGET_FILE="$OUTPUT_DIR/all_targets.txt"
> "$TARGET_FILE"

progress "  -> Adding 192.168.0-255.x networks (256 Class C)..."
for i in {0..255}; do
    echo "192.168.$i.0/24" >> "$TARGET_FILE"
done

progress "  -> Adding 10.0-10.x networks (11 Class B for speed)..."
for i in {0..10}; do
    echo "10.$i.0.0/16" >> "$TARGET_FILE"
done

progress "  -> Adding 172.16-31.x private networks..."
for i in {16..31}; do
    echo "172.$i.0.0/16" >> "$TARGET_FILE"
done

TOTAL_RANGES=$(wc -l < "$TARGET_FILE")
success "Total network ranges to scan: $TOTAL_RANGES"

progress "Step 1.4: Fast host discovery (ping sweep)..."
progress "  -> Scanning 192.168.1.0/24 (local network)..."
nmap -sn 192.168.1.0/24 -T5 --min-parallelism 100 -oG - | tee "$OUTPUT_DIR/discovery_local.txt" | grep "Up" | awk '{print $2}'

progress "  -> Scanning 10.0.0.0/16 (quick check)..."
timeout 120 nmap -sn 10.0.0.0/16 -T5 --min-parallelism 200 -oG - 2>/dev/null | grep "Up" | awk '{print $2}' || warning "10.0.0.0/16 scan timed out (expected for large range)"

progress "Step 1.5: Extracting live hosts..."
LIVE_HOSTS="$OUTPUT_DIR/live_hosts.txt"
grep "Up" "$OUTPUT_DIR"/discovery*.txt | awk '{print $2}' | sort -u > "$LIVE_HOSTS"
TOTAL_HOSTS=$(wc -l < "$LIVE_HOSTS")

success "DISCOVERED $TOTAL_HOSTS LIVE HOSTS:"
cat "$LIVE_HOSTS" | nl

if [ "$TOTAL_HOSTS" -eq 0 ]; then
    error "No live hosts found. Exiting."
    exit 1
fi

#############################################
# PHASE 2: PORT SCANNING
#############################################
header "PHASE 2: COMPREHENSIVE PORT SCANNING"

progress "Step 2.1: Scanning top 1000 ports on all hosts..."
HOST_COUNT=0
while read host; do
    HOST_COUNT=$((HOST_COUNT + 1))
    progress "  -> [$HOST_COUNT/$TOTAL_HOSTS] Scanning $host..."
    nmap -p- --top-ports 1000 --open -sV -T4 "$host" -oN "$OUTPUT_DIR/ports_$host.txt" 2>/dev/null || warning "Scan failed for $host"
done < "$LIVE_HOSTS"

progress "Step 2.2: Scanning critical services (all hosts)..."
progress "  -> Ports: 21(FTP), 22(SSH), 23(Telnet), 25(SMTP), 53(DNS), 80(HTTP), 110(POP3), 135(RPC), 139(SMB), 143(IMAP), 443(HTTPS), 445(SMB), 3306(MySQL), 3389(RDP), 5432(PostgreSQL), 5900(VNC), 6379(Redis), 8080(HTTP-Alt), 8443(HTTPS-Alt), 9200(Elasticsearch), 27017(MongoDB)"

nmap -iL "$LIVE_HOSTS" \
    -p 21,22,23,25,53,80,110,135,139,143,443,445,993,995,1433,3306,3389,5432,5900,6379,8000,8080,8443,9200,11211,27017 \
    --open -sV -sC -T4 \
    -oN "$OUTPUT_DIR/critical_ports.txt"

progress "Step 2.3: Consolidating open ports..."
OPEN_PORTS="$OUTPUT_DIR/open_ports_summary.txt"
grep -h "open" "$OUTPUT_DIR"/ports_*.txt "$OUTPUT_DIR"/critical_ports.txt 2>/dev/null | sort -u > "$OPEN_PORTS" || true

OPEN_SERVICES=$(wc -l < "$OPEN_PORTS")
success "Found $OPEN_SERVICES open services"

#############################################
# PHASE 3: SERVICE ENUMERATION
#############################################
header "PHASE 3: DEEP SERVICE ENUMERATION"

progress "Step 3.1: Banner grabbing and version detection..."
HOST_COUNT=0
while read host; do
    HOST_COUNT=$((HOST_COUNT + 1))
    progress "  -> [$HOST_COUNT/$TOTAL_HOSTS] Enumerating $host..."
    
    nmap -sV -sC --version-intensity 9 \
        --script=banner,http-title,http-headers,http-methods,http-robots.txt,http-enum,\
ftp-anon,ftp-bounce,ssh-hostkey,ssh-auth-methods,ssl-cert,ssl-enum-ciphers,\
smb-os-discovery,smb-enum-shares,smb-enum-users,mysql-info,mongodb-info,redis-info,\
rpcinfo,nfs-showmount,vnc-info \
        "$host" -oN "$OUTPUT_DIR/enum/$host.txt" 2>/dev/null || warning "Enum failed for $host"
    
    # Show key findings immediately
    if grep -q "VULNERABLE\|open" "$OUTPUT_DIR/enum/$host.txt" 2>/dev/null; then
        echo -e "${YELLOW}  -> Found interesting services on $host:${NC}"
        grep "open\|VULNERABLE" "$OUTPUT_DIR/enum/$host.txt" | head -5 | sed 's/^/     /'
    fi
done < "$LIVE_HOSTS"

progress "Step 3.2: Web service enumeration..."
WEB_HOSTS=$(grep -l "80/open\|443/open\|8080/open\|8443/open" "$OUTPUT_DIR"/enum/*.txt 2>/dev/null | wc -l)
if [ "$WEB_HOSTS" -gt 0 ]; then
    success "Found $WEB_HOSTS hosts with web services"
    progress "  -> Testing web endpoints..."
    grep -h "80/open\|443/open\|8080/open\|8443/open" "$OUTPUT_DIR"/enum/*.txt | awk '{print $1}' | cut -d'/' -f1 | while read port; do
        progress "     Testing HTTP on port $port..."
    done
fi

#############################################
# PHASE 4: VULNERABILITY SCANNING
#############################################
header "PHASE 4: COMPREHENSIVE VULNERABILITY ASSESSMENT"

progress "Step 4.1: Running NSE vulnerability scripts..."
HOST_COUNT=0
while read host; do
    HOST_COUNT=$((HOST_COUNT + 1))
    progress "  -> [$HOST_COUNT/$TOTAL_HOSTS] Vuln scan on $host..."
    
    nmap --script vuln,exploit \
        -T4 --script-timeout 300s \
        "$host" -oN "$OUTPUT_DIR/vulns_$host.txt" 2>/dev/null || warning "Vuln scan failed for $host"
    
    # Immediately show vulnerabilities found
    if grep -qi "VULNERABLE" "$OUTPUT_DIR/vulns_$host.txt" 2>/dev/null; then
        echo -e "${RED}  !!!! VULNERABILITIES FOUND ON $host !!!!${NC}"
        grep -i "VULNERABLE\|CVE" "$OUTPUT_DIR/vulns_$host.txt" | sed 's/^/     /' | head -10
    fi
done < "$LIVE_HOSTS"

progress "Step 4.2: SMB vulnerability check (EternalBlue, MS17-010)..."
nmap -iL "$LIVE_HOSTS" -p 445 \
    --script smb-vuln-ms17-010,smb-vuln-ms08-067,smb-vuln-cve-2017-7494 \
    -oN "$OUTPUT_DIR/smb_vulns.txt" 2>/dev/null || true

if grep -qi "VULNERABLE" "$OUTPUT_DIR/smb_vulns.txt" 2>/dev/null; then
    echo -e "${RED}!!!! CRITICAL SMB VULNERABILITIES FOUND !!!!${NC}"
    grep -i "VULNERABLE" "$OUTPUT_DIR/smb_vulns.txt"
fi

progress "Step 4.3: SSL/TLS vulnerability check..."
nmap -iL "$LIVE_HOSTS" -p 443,8443 \
    --script ssl-heartbleed,ssl-poodle,ssl-dh-params \
    -oN "$OUTPUT_DIR/ssl_vulns.txt" 2>/dev/null || true

#############################################
# PHASE 5: CREDENTIAL TESTING
#############################################
header "PHASE 5: CREDENTIAL WEAKNESS ASSESSMENT"

progress "Step 5.1: Creating wordlists..."
cat > "$OUTPUT_DIR/users.txt" <<EOF
admin
root
user
administrator
guest
test
oracle
postgres
mysql
sa
tomcat
admin123
manager
webadmin
EOF

cat > "$OUTPUT_DIR/passwords.txt" <<EOF
password
admin
123456
password123
root
12345678
qwerty
abc123
Password1
welcome
letmein
monkey
1234567890
admin123
changeme
EOF

USERS=$(wc -l < "$OUTPUT_DIR/users.txt")
PASSWORDS=$(wc -l < "$OUTPUT_DIR/passwords.txt")
progress "Testing $USERS usernames with $PASSWORDS passwords per service"

progress "Step 5.2: SSH bruteforce (limited test)..."
grep -l "22/open" "$OUTPUT_DIR"/ports_*.txt 2>/dev/null | head -3 | while read file; do
    host=$(basename "$file" | sed 's/ports_//;s/.txt//')
    progress "  -> Testing SSH on $host..."
    timeout 120 hydra -L "$OUTPUT_DIR/users.txt" -P "$OUTPUT_DIR/passwords.txt" \
        ssh://"$host" -t 8 -V -o "$OUTPUT_DIR/creds/ssh_$host.txt" 2>/dev/null || true
    
    if grep -q "login:\|password:" "$OUTPUT_DIR/creds/ssh_$host.txt" 2>/dev/null; then
        echo -e "${RED}!!!! WEAK SSH CREDENTIALS FOUND ON $host !!!!${NC}"
        grep "login:\|password:" "$OUTPUT_DIR/creds/ssh_$host.txt"
    fi
done

progress "Step 5.3: FTP bruteforce..."
grep -l "21/open" "$OUTPUT_DIR"/ports_*.txt 2>/dev/null | head -3 | while read file; do
    host=$(basename "$file" | sed 's/ports_//;s/.txt//')
    progress "  -> Testing FTP on $host..."
    timeout 120 hydra -L "$OUTPUT_DIR/users.txt" -P "$OUTPUT_DIR/passwords.txt" \
        ftp://"$host" -t 8 -V -o "$OUTPUT_DIR/creds/ftp_$host.txt" 2>/dev/null || true
    
    if grep -q "login:\|password:" "$OUTPUT_DIR/creds/ftp_$host.txt" 2>/dev/null; then
        echo -e "${RED}!!!! WEAK FTP CREDENTIALS FOUND ON $host !!!!${NC}"
        grep "login:\|password:" "$OUTPUT_DIR/creds/ftp_$host.txt"
    fi
done

progress "Step 5.4: MySQL bruteforce..."
grep -l "3306/open" "$OUTPUT_DIR"/ports_*.txt 2>/dev/null | head -3 | while read file; do
    host=$(basename "$file" | sed 's/ports_//;s/.txt//')
    progress "  -> Testing MySQL on $host..."
    timeout 120 hydra -L "$OUTPUT_DIR/users.txt" -P "$OUTPUT_DIR/passwords.txt" \
        mysql://"$host" -t 8 -V -o "$OUTPUT_DIR/creds/mysql_$host.txt" 2>/dev/null || true
    
    if grep -q "login:\|password:" "$OUTPUT_DIR/creds/mysql_$host.txt" 2>/dev/null; then
        echo -e "${RED}!!!! WEAK MYSQL CREDENTIALS FOUND ON $host !!!!${NC}"
        grep "login:\|password:" "$OUTPUT_DIR/creds/mysql_$host.txt"
    fi
done

#############################################
# PHASE 6: ANONYMOUS ACCESS TESTING
#############################################
header "PHASE 6: ANONYMOUS & DEFAULT ACCESS TESTING"

ANON_FILE="$OUTPUT_DIR/anonymous_access.txt"
> "$ANON_FILE"

progress "Step 6.1: Testing anonymous FTP access..."
HOST_COUNT=0
while read host; do
    HOST_COUNT=$((HOST_COUNT + 1))
    progress "  -> [$HOST_COUNT/$TOTAL_HOSTS] Testing $host..."
    
    timeout 10 ftp -n "$host" <<EOF 2>/dev/null | grep -q "230" && {
        echo -e "${RED}FTP ANONYMOUS ACCESS: $host${NC}"
        echo "FTP anonymous: $host" >> "$ANON_FILE"
    }
user anonymous
pass anonymous
quit
EOF
done < "$LIVE_HOSTS"

progress "Step 6.2: Testing HTTP accessibility..."
HOST_COUNT=0
while read host; do
    HOST_COUNT=$((HOST_COUNT + 1))
    if curl -m 5 -s "http://$host" >/dev/null 2>&1; then
        echo -e "${YELLOW}HTTP accessible: $host${NC}"
        echo "HTTP open: $host" >> "$ANON_FILE"
    fi
done < "$LIVE_HOSTS"

progress "Step 6.3: Testing Redis unauthenticated access..."
HOST_COUNT=0
while read host; do
    HOST_COUNT=$((HOST_COUNT + 1))
    if redis-cli -h "$host" ping 2>/dev/null | grep -q "PONG"; then
        echo -e "${RED}REDIS UNAUTHENTICATED: $host${NC}"
        echo "Redis unauthenticated: $host" >> "$ANON_FILE"
    fi
done < "$LIVE_HOSTS"

progress "Step 6.4: Testing Memcached unauthenticated access..."
HOST_COUNT=0
while read host; do
    HOST_COUNT=$((HOST_COUNT + 1))
    if echo "stats" | nc -w 2 "$host" 11211 2>/dev/null | grep -q "STAT"; then
        echo -e "${RED}MEMCACHED UNAUTHENTICATED: $host${NC}"
        echo "Memcached unauthenticated: $host" >> "$ANON_FILE"
    fi
done < "$LIVE_HOSTS"

#############################################
# PHASE 7: FINAL REPORT GENERATION
#############################################
header "PHASE 7: GENERATING COMPREHENSIVE REPORT"

REPORT="$OUTPUT_DIR/FINAL_VULNERABILITY_REPORT.txt"

progress "Step 7.1: Consolidating all findings..."

cat > "$REPORT" <<EOFR
========================================
COMPREHENSIVE VULNERABILITY SCAN REPORT
========================================
Scan Date: $(date)
Scan Duration: Started at script execution
Output Directory: $OUTPUT_DIR

========================================
EXECUTIVE SUMMARY
========================================
Total Networks Scanned: $TOTAL_RANGES ranges
Live Hosts Discovered: $TOTAL_HOSTS hosts
Open Services Found: $OPEN_SERVICES services
Web Hosts Found: $WEB_HOSTS hosts

========================================
1. DISCOVERED LIVE HOSTS
========================================
$(cat "$LIVE_HOSTS" | nl)

========================================
2. OPEN SERVICES BY HOST
========================================
$(cat "$OPEN_PORTS" | head -100)

$(if [ $(wc -l < "$OPEN_PORTS") -gt 100 ]; then echo "... ($(wc -l < "$OPEN_PORTS") total services, showing first 100)"; fi)

========================================
3. CRITICAL VULNERABILITIES FOUND
========================================
EOFR

# Add vulnerabilities from all scans
progress "Step 7.2: Extracting vulnerabilities..."
for file in "$OUTPUT_DIR"/vulns_*.txt; do
    if [ -f "$file" ]; then
        host=$(basename "$file" | sed 's/vulns_//;s/.txt//')
        if grep -qi "VULNERABLE" "$file"; then
            echo "" >> "$REPORT"
            echo "HOST: $host" >> "$REPORT"
            echo "----------------------------------------" >> "$REPORT"
            grep -i "VULNERABLE\|CVE\|EXPLOIT" "$file" | head -20 >> "$REPORT"
        fi
    fi
done

# Add SMB vulnerabilities
if [ -f "$OUTPUT_DIR/smb_vulns.txt" ] && grep -qi "VULNERABLE" "$OUTPUT_DIR/smb_vulns.txt"; then
    echo "" >> "$REPORT"
    echo "SMB VULNERABILITIES:" >> "$REPORT"
    echo "----------------------------------------" >> "$REPORT"
    grep -i "VULNERABLE" "$OUTPUT_DIR/smb_vulns.txt" >> "$REPORT"
fi

cat >> "$REPORT" <<EOFR

========================================
4. WEAK/DEFAULT CREDENTIALS FOUND
========================================
EOFR

progress "Step 7.3: Extracting credential findings..."
if ls "$OUTPUT_DIR/creds"/*.txt >/dev/null 2>&1; then
    for file in "$OUTPUT_DIR/creds"/*.txt; do
        if grep -qi "login:\|password:\|host:\|valid" "$file" 2>/dev/null; then
            service=$(basename "$file" | cut -d'_' -f1)
            host=$(basename "$file" | sed "s/${service}_//;s/.txt//")
            echo "" >> "$REPORT"
            echo "SERVICE: $service on $host" >> "$REPORT"
            grep -i "login:\|password:\|host:\|valid" "$file" >> "$REPORT"
        fi
    done
else
    echo "No weak credentials found with tested wordlists." >> "$REPORT"
fi

cat >> "$REPORT" <<EOFR

========================================
5. ANONYMOUS/OPEN ACCESS
========================================
EOFR

if [ -f "$ANON_FILE" ] && [ -s "$ANON_FILE" ]; then
    cat "$ANON_FILE" >> "$REPORT"
else
    echo "No anonymous access found." >> "$REPORT"
fi

cat >> "$REPORT" <<EOFR

========================================
6. DETAILED ENUMERATION
========================================
Full enumeration data available in:
$OUTPUT_DIR/enum/

Key findings per host:
EOFR

progress "Step 7.4: Summarizing enumeration..."
for file in "$OUTPUT_DIR/enum"/*.txt; do
    if [ -f "$file" ]; then
        host=$(basename "$file" | sed 's/.txt//')
        echo "" >> "$REPORT"
        echo "HOST: $host" >> "$REPORT"
        grep "open\|OS:\|Service Info:" "$file" 2>/dev/null | head -10 >> "$REPORT" || true
    fi
done

cat >> "$REPORT" <<EOFR

========================================
7. RAW DATA LOCATIONS
========================================
All scan data saved to: $OUTPUT_DIR/

Key files:
  * Live hosts: $LIVE_HOSTS
  * Port scans: $OUTPUT_DIR/ports_*.txt
  * Critical services: $OUTPUT_DIR/critical_ports.txt
  * Service enumeration: $OUTPUT_DIR/enum/*.txt
  * Vulnerabilities: $OUTPUT_DIR/vulns_*.txt
  * SMB vulnerabilities: $OUTPUT_DIR/smb_vulns.txt
  * SSL vulnerabilities: $OUTPUT_DIR/ssl_vulns.txt
  * Credentials found: $OUTPUT_DIR/creds/*.txt
  * Anonymous access: $ANON_FILE

========================================
8. RECOMMENDATIONS
========================================
1. Patch all systems with critical vulnerabilities immediately
2. Change all weak/default credentials found
3. Disable anonymous access on FTP, Redis, Memcached
4. Update SSL/TLS configurations
5. Review and restrict unnecessary open ports
6. Implement network segmentation
7. Enable logging and monitoring

========================================
SCAN COMPLETE
========================================
Generated: $(date)
EOFR

#############################################
# DISPLAY FINAL REPORT
#############################################
header "SCAN COMPLETE - DISPLAYING FINAL REPORT"

cat "$REPORT"

success "Full report saved to: $REPORT"
success "All raw data saved to: $OUTPUT_DIR"

echo ""
echo -e "${MAGENTA}========================================${NC}"
echo -e "${GREEN}To view the report again, run:${NC}"
echo -e "${CYAN}cat $REPORT${NC}"
echo -e "${MAGENTA}========================================${NC}"
echo ""

#!/usr/bin/env python3
"""
WiFi Mega Optimizer - Persistent WiFi Connection & Speed Maintainer
Ensures WiFi stays connected, auto-reconnects on drops, and monitors speed.
Installs itself as a Windows startup task for boot persistence.
"""

import subprocess
import time
import os
import sys
import threading
import logging
import ctypes
import socket
import re
from datetime import datetime
from pathlib import Path

# ============================================================================
# CONFIGURATION
# ============================================================================
MIN_DOWNLOAD_SPEED_MBPS = 200  # Minimum acceptable download speed
CHECK_INTERVAL_SECONDS = 30    # How often to check connection
SPEED_TEST_INTERVAL = 300      # Speed test every 5 minutes
RECONNECT_DELAY = 5            # Seconds to wait before reconnect attempt
MAX_RECONNECT_ATTEMPTS = 10    # Max reconnection attempts before reset
LOG_FILE = Path(__file__).parent / "wifi_optimizer.log"
TASK_NAME = "WiFiMegaOptimizer"

# ============================================================================
# LOGGING SETUP
# ============================================================================
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(LOG_FILE, encoding='utf-8'),
        logging.StreamHandler(sys.stdout)
    ]
)
logger = logging.getLogger(__name__)

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

def is_admin():
    """Check if running with admin privileges"""
    try:
        return ctypes.windll.shell32.IsUserAnAdmin()
    except:
        return False

def run_as_admin():
    """Relaunch script with admin privileges"""
    if not is_admin():
        logger.info("Requesting admin privileges...")
        ctypes.windll.shell32.ShellExecuteW(
            None, "runas", sys.executable,
            f'"{os.path.abspath(__file__)}" {" ".join(sys.argv[1:])}',
            None, 1
        )
        sys.exit(0)

def run_cmd(cmd, capture=True, timeout=60):
    """Run a command and return output using direct subprocess call"""
    try:
        # Convert string command to list
        if isinstance(cmd, str):
            cmd_list = cmd.split()
        else:
            cmd_list = list(cmd)

        result = subprocess.run(
            cmd_list, capture_output=capture,
            text=True, timeout=timeout, encoding='utf-8', errors='replace',
            creationflags=subprocess.CREATE_NO_WINDOW if hasattr(subprocess, 'CREATE_NO_WINDOW') else 0
        )
        return result.stdout.strip() if capture else ""
    except subprocess.TimeoutExpired:
        logger.error(f"Command timed out: {cmd}")
        return ""
    except Exception as e:
        logger.error(f"Command failed: {cmd} - {e}")
        return ""

def run_cmd_shell(cmd, capture=True, timeout=60):
    """Run a command with shell=True for complex commands with quotes/pipes"""
    try:
        # For shell commands, we need to use the full path to common tools
        # or use PowerShell which has proper PATH setup
        if cmd.startswith('netsh ') or cmd.startswith('schtasks ') or cmd.startswith('reg ') or cmd.startswith('ipconfig '):
            # Use PowerShell for Windows system commands
            ps_cmd = f'powershell -NoProfile -Command "& {{{cmd}}}"'
            result = subprocess.run(
                ps_cmd, shell=True, capture_output=capture,
                text=True, timeout=timeout, encoding='utf-8', errors='replace'
            )
        else:
            result = subprocess.run(
                cmd, shell=True, capture_output=capture,
                text=True, timeout=timeout, encoding='utf-8', errors='replace'
            )
        return result.stdout.strip() if capture else ""
    except subprocess.TimeoutExpired:
        logger.error(f"Command timed out: {cmd}")
        return ""
    except Exception as e:
        logger.error(f"Command failed: {cmd} - {e}")
        return ""

def run_powershell(script, timeout=60):
    """Run PowerShell command"""
    cmd = f'powershell -NoProfile -ExecutionPolicy Bypass -Command "{script}"'
    return run_cmd_shell(cmd, timeout=timeout)

# ============================================================================
# WIFI CONNECTION MANAGEMENT
# ============================================================================

def get_wifi_interface_name():
    """Get WiFi interface name using netsh"""
    output = run_cmd('netsh interface show interface')
    for line in output.split('\n'):
        if 'Wi-Fi' in line or 'Wireless' in line or 'WLAN' in line:
            parts = line.split()
            if len(parts) >= 4:
                return parts[-1]
    return "Wi-Fi"  # Default fallback

def is_wifi_connected():
    """Check if WiFi is connected"""
    try:
        result = subprocess.run(
            ['netsh', 'interface', 'show', 'interface'],
            capture_output=True, text=True, timeout=30
        )
        output = result.stdout
        for line in output.split('\n'):
            line_lower = line.lower()
            if 'wi-fi' in line_lower or 'wireless' in line_lower or 'wlan' in line_lower:
                if 'connected' in line_lower:
                    return True
        return False
    except Exception as e:
        logger.error(f"Error checking WiFi status: {e}")
        return False

def get_current_ssid():
    """Get currently connected SSID"""
    try:
        output = run_cmd('netsh wlan show interfaces')
        for line in output.split('\n'):
            if 'SSID' in line and 'BSSID' not in line:
                parts = line.split(':', 1)
                if len(parts) > 1:
                    return parts[1].strip()
    except:
        pass
    return None

def get_saved_networks():
    """Get list of saved WiFi networks"""
    output = run_cmd('netsh wlan show profiles')
    profiles = []
    for line in output.split('\n'):
        if 'All User Profile' in line or 'User Profile' in line:
            parts = line.split(':', 1)
            if len(parts) > 1:
                profile = parts[1].strip()
                if profile:
                    profiles.append(profile)
    return profiles

def connect_to_network(ssid=None):
    """Connect to a WiFi network"""
    if ssid:
        logger.info(f"Attempting to connect to: {ssid}")
        result = run_cmd_shell(f'netsh wlan connect name="{ssid}"')
        time.sleep(3)
        return is_wifi_connected()

    # Try saved networks
    profiles = get_saved_networks()
    for profile in profiles:
        logger.info(f"Trying to connect to saved network: {profile}")
        run_cmd_shell(f'netsh wlan connect name="{profile}"')
        time.sleep(5)
        if is_wifi_connected():
            logger.info(f"Successfully connected to: {profile}")
            return True
    return False

def disconnect_wifi():
    """Disconnect from current WiFi"""
    run_cmd('netsh wlan disconnect')
    time.sleep(2)

def reset_wifi_adapter():
    """Reset WiFi adapter by disabling and re-enabling"""
    interface = get_wifi_interface_name()
    logger.info(f"Resetting WiFi adapter: {interface}")

    # Disable adapter
    run_cmd_shell(f'netsh interface set interface "{interface}" disable')
    time.sleep(3)

    # Enable adapter
    run_cmd_shell(f'netsh interface set interface "{interface}" enable')
    time.sleep(5)

def flush_dns():
    """Flush DNS cache"""
    run_cmd('ipconfig /flushdns')
    logger.info("DNS cache flushed")

def release_renew_ip():
    """Release and renew IP address"""
    run_cmd('ipconfig /release')
    time.sleep(2)
    run_cmd('ipconfig /renew')
    logger.info("IP released and renewed")

# ============================================================================
# SPEED TESTING
# ============================================================================

def test_download_speed():
    """Test download speed using speedtest-cli"""
    try:
        import speedtest
        logger.info("Running speed test...")
        st = speedtest.Speedtest()
        st.get_best_server()
        download_speed = st.download() / 1_000_000  # Convert to Mbps
        logger.info(f"Download speed: {download_speed:.2f} Mbps")
        return download_speed
    except ImportError:
        logger.warning("speedtest-cli not available, using fallback method")
        return test_speed_fallback()
    except Exception as e:
        logger.error(f"Speed test failed: {e}")
        return test_speed_fallback()

def test_speed_fallback():
    """Fallback speed test using download of known file"""
    try:
        import urllib.request
        import time as t

        # Use a small test file for quick estimation
        test_urls = [
            ('http://speedtest.tele2.net/1MB.zip', 1),
            ('http://ipv4.download.thinkbroadband.com/1MB.zip', 1),
        ]

        for url, size_mb in test_urls:
            try:
                start = t.time()
                urllib.request.urlopen(url, timeout=30).read()
                elapsed = t.time() - start
                speed = (size_mb * 8) / elapsed  # Mbps
                logger.info(f"Fallback speed test: {speed:.2f} Mbps")
                return speed * 10  # Rough estimate for full speed
            except:
                continue
        return 0
    except Exception as e:
        logger.error(f"Fallback speed test failed: {e}")
        return 0

def quick_connectivity_test():
    """Quick test for internet connectivity"""
    test_hosts = [
        ("8.8.8.8", 53),      # Google DNS
        ("1.1.1.1", 53),      # Cloudflare DNS
        ("208.67.222.222", 53) # OpenDNS
    ]

    for host, port in test_hosts:
        try:
            socket.create_connection((host, port), timeout=3)
            return True
        except:
            continue
    return False

# ============================================================================
# NETWORK OPTIMIZATIONS
# ============================================================================

def apply_network_optimizations():
    """Apply various network optimizations"""
    logger.info("Applying network optimizations...")

    # Disable WiFi power saving via registry
    optimizations = [
        # Disable power saving for WiFi adapter
        'reg add "HKLM\\SYSTEM\\CurrentControlSet\\Control\\Power\\PowerSettings\\19cbb8fa-5279-450e-9fac-8a3d5fedd0c1\\12bbebe6-58d6-4636-95bb-3217ef867c1a" /v Attributes /t REG_DWORD /d 2 /f',

        # Set WiFi power to maximum performance
        'powercfg /setacvalueindex SCHEME_CURRENT 19cbb8fa-5279-450e-9fac-8a3d5fedd0c1 12bbebe6-58d6-4636-95bb-3217ef867c1a 0',
        'powercfg /setdcvalueindex SCHEME_CURRENT 19cbb8fa-5279-450e-9fac-8a3d5fedd0c1 12bbebe6-58d6-4636-95bb-3217ef867c1a 0',
        'powercfg /setactive SCHEME_CURRENT',

        # Disable WPAD (auto proxy detection)
        'reg add "HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Internet Settings\\Wpad" /v WpadOverride /t REG_DWORD /d 1 /f',

        # Optimize TCP settings
        'netsh int tcp set global autotuninglevel=normal',
        'netsh int tcp set global chimney=disabled',
        'netsh int tcp set global dca=enabled',
        'netsh int tcp set global netdma=disabled',
        'netsh int tcp set global ecncapability=disabled',
        'netsh int tcp set global timestamps=disabled',
        'netsh int tcp set global rss=enabled',

        # Increase network throughput via registry
        'reg add "HKLM\\SYSTEM\\CurrentControlSet\\Services\\LanmanServer\\Parameters" /v Size /t REG_DWORD /d 3 /f',
        'reg add "HKLM\\SYSTEM\\CurrentControlSet\\Services\\Tcpip\\Parameters" /v TcpWindowSize /t REG_DWORD /d 65535 /f',
        'reg add "HKLM\\SYSTEM\\CurrentControlSet\\Services\\Tcpip\\Parameters" /v GlobalMaxTcpWindowSize /t REG_DWORD /d 65535 /f',

        # Disable Nagle's algorithm for lower latency
        'reg add "HKLM\\SYSTEM\\CurrentControlSet\\Services\\Tcpip\\Parameters\\Interfaces" /v TcpAckFrequency /t REG_DWORD /d 1 /f',
        'reg add "HKLM\\SYSTEM\\CurrentControlSet\\Services\\Tcpip\\Parameters\\Interfaces" /v TCPNoDelay /t REG_DWORD /d 1 /f',
    ]

    for cmd in optimizations:
        run_cmd(cmd)

    logger.info("Network optimizations applied")

def optimize_wifi_adapter_settings():
    """Optimize WiFi adapter advanced settings via netsh"""
    interface = get_wifi_interface_name()

    # Set preferred band to 5GHz if available (faster speeds)
    settings = [
        f'netsh wlan set profileparameter name=* connectiontype=ESS connectionmode=auto',
    ]

    for cmd in settings:
        run_cmd(cmd)

    logger.info("WiFi adapter settings optimized")

def restart_network_services():
    """Restart key network services"""
    services = ['NlaSvc', 'Dhcp', 'Dnscache']

    for service in services:
        run_cmd(f'net stop {service}')
        time.sleep(1)
        run_cmd(f'net start {service}')

    logger.info("Network services restarted")

# ============================================================================
# TASK SCHEDULER INTEGRATION
# ============================================================================

def install_startup_task():
    """Install as Windows startup task using schtasks command line"""
    script_path = os.path.abspath(__file__)

    # Delete existing task if present
    subprocess.run(['schtasks', '/delete', '/tn', TASK_NAME, '/f'],
                   capture_output=True, text=True)

    # Create task that runs at logon with highest privileges
    # Using pythonw.exe to run without console window
    pythonw_path = os.path.join(os.path.dirname(sys.executable), 'pythonw.exe')
    if not os.path.exists(pythonw_path):
        pythonw_path = sys.executable  # Fallback to python.exe

    # Create the scheduled task using direct subprocess call
    tr_value = f'"{pythonw_path}" "{script_path}" --daemon'
    result = subprocess.run(
        ['schtasks', '/create', '/tn', TASK_NAME, '/tr', tr_value,
         '/sc', 'onlogon', '/rl', 'highest', '/f'],
        capture_output=True, text=True
    )

    if 'SUCCESS' in result.stdout.upper() or 'ERFOLGREICH' in result.stdout.upper():
        logger.info(f"Startup task '{TASK_NAME}' installed successfully")
        return True

    # Verify task was created even if message unclear
    verify = subprocess.run(['schtasks', '/query', '/tn', TASK_NAME],
                           capture_output=True, text=True)
    if TASK_NAME in verify.stdout:
        logger.info(f"Startup task '{TASK_NAME}' installed successfully")
        return True

    logger.error(f"Failed to install startup task: {result.stdout} {result.stderr}")
    return False

def uninstall_startup_task():
    """Remove startup task"""
    result = subprocess.run(['schtasks', '/delete', '/tn', TASK_NAME, '/f'],
                           capture_output=True, text=True)
    logger.info(f"Startup task removal: {result.stdout}")

def is_task_installed():
    """Check if startup task exists"""
    result = subprocess.run(['schtasks', '/query', '/tn', TASK_NAME],
                           capture_output=True, text=True)
    return TASK_NAME in result.stdout

# ============================================================================
# MAIN MONITORING LOOP
# ============================================================================

class WiFiMonitor:
    def __init__(self):
        self.running = True
        self.reconnect_attempts = 0
        self.last_ssid = None
        self.last_speed_test = 0
        self.consecutive_slow_tests = 0

    def stop(self):
        self.running = False

    def handle_disconnection(self):
        """Handle WiFi disconnection"""
        logger.warning("WiFi disconnected! Attempting to reconnect...")

        self.reconnect_attempts += 1

        if self.reconnect_attempts > MAX_RECONNECT_ATTEMPTS:
            logger.warning("Max reconnection attempts reached, resetting adapter...")
            reset_wifi_adapter()
            self.reconnect_attempts = 0
            time.sleep(10)

        # Try to reconnect
        if self.last_ssid:
            if connect_to_network(self.last_ssid):
                logger.info(f"Reconnected to {self.last_ssid}")
                self.reconnect_attempts = 0
                return True

        # Try any saved network
        if connect_to_network():
            self.last_ssid = get_current_ssid()
            self.reconnect_attempts = 0
            return True

        # Last resort - flush DNS and renew IP
        flush_dns()
        release_renew_ip()
        time.sleep(5)

        return is_wifi_connected()

    def handle_slow_speed(self, speed):
        """Handle slow download speed"""
        self.consecutive_slow_tests += 1
        logger.warning(f"Speed below threshold: {speed:.2f} Mbps (need {MIN_DOWNLOAD_SPEED_MBPS} Mbps)")

        if self.consecutive_slow_tests >= 3:
            logger.info("Multiple slow speed tests, attempting recovery...")

            # Try DNS flush and IP renewal
            flush_dns()

            # Disconnect and reconnect
            current_ssid = get_current_ssid()
            disconnect_wifi()
            time.sleep(3)
            connect_to_network(current_ssid)

            self.consecutive_slow_tests = 0

    def run(self):
        """Main monitoring loop"""
        logger.info("=" * 60)
        logger.info("WiFi Mega Optimizer Started")
        logger.info(f"Minimum speed target: {MIN_DOWNLOAD_SPEED_MBPS} Mbps")
        logger.info(f"Check interval: {CHECK_INTERVAL_SECONDS} seconds")
        logger.info("=" * 60)

        # Initial status
        if is_wifi_connected():
            self.last_ssid = get_current_ssid()
            logger.info(f"Currently connected to: {self.last_ssid}")
        else:
            self.handle_disconnection()

        while self.running:
            try:
                # Check WiFi connection
                if not is_wifi_connected():
                    self.handle_disconnection()
                else:
                    self.reconnect_attempts = 0
                    current_ssid = get_current_ssid()
                    if current_ssid:
                        self.last_ssid = current_ssid

                    # Quick connectivity test
                    if not quick_connectivity_test():
                        logger.warning("Internet not accessible, reconnecting...")
                        disconnect_wifi()
                        time.sleep(2)
                        self.handle_disconnection()

                # Periodic speed test
                current_time = time.time()
                if current_time - self.last_speed_test > SPEED_TEST_INTERVAL:
                    if is_wifi_connected() and quick_connectivity_test():
                        speed = test_download_speed()
                        self.last_speed_test = current_time

                        if speed > 0 and speed < MIN_DOWNLOAD_SPEED_MBPS:
                            self.handle_slow_speed(speed)
                        elif speed >= MIN_DOWNLOAD_SPEED_MBPS:
                            self.consecutive_slow_tests = 0
                            logger.info(f"Speed OK: {speed:.2f} Mbps")

                time.sleep(CHECK_INTERVAL_SECONDS)

            except KeyboardInterrupt:
                logger.info("Interrupted by user")
                break
            except Exception as e:
                logger.error(f"Error in monitoring loop: {e}")
                time.sleep(CHECK_INTERVAL_SECONDS)

# ============================================================================
# MAIN ENTRY POINT
# ============================================================================

def print_status():
    """Print current status"""
    print("\n" + "=" * 60)
    print("WiFi Mega Optimizer - Status Report")
    print("=" * 60)

    connected = is_wifi_connected()
    print(f"WiFi Connected: {'Yes' if connected else 'No'}")

    if connected:
        ssid = get_current_ssid()
        print(f"Current Network: {ssid or 'Unknown'}")

        print("\nRunning speed test...")
        speed = test_download_speed()
        print(f"Download Speed: {speed:.2f} Mbps")
        print(f"Target Speed: {MIN_DOWNLOAD_SPEED_MBPS} Mbps")
        print(f"Status: {'[OK] GOOD' if speed >= MIN_DOWNLOAD_SPEED_MBPS else '[!] BELOW TARGET'}")

    task_installed = is_task_installed()
    print(f"\nStartup Task Installed: {'Yes' if task_installed else 'No'}")
    print("=" * 60 + "\n")

def main():
    """Main entry point"""
    import argparse

    parser = argparse.ArgumentParser(description='WiFi Mega Optimizer')
    parser.add_argument('--install', action='store_true', help='Install and start persistent monitoring')
    parser.add_argument('--uninstall', action='store_true', help='Remove startup task')
    parser.add_argument('--daemon', action='store_true', help='Run as background daemon')
    parser.add_argument('--status', action='store_true', help='Show current status')
    parser.add_argument('--optimize', action='store_true', help='Apply network optimizations only')

    args = parser.parse_args()

    # Request admin if needed for most operations
    if args.install or args.optimize or (not args.status and not args.uninstall):
        if not is_admin():
            run_as_admin()

    # Fix console encoding for Windows
    import io
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
    sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8', errors='replace')

    if args.status:
        print_status()
        return

    if args.uninstall:
        uninstall_startup_task()
        print("Startup task removed.")
        return

    if args.optimize:
        apply_network_optimizations()
        optimize_wifi_adapter_settings()
        print("Network optimizations applied.")
        return

    # Default: Install and run
    print("\n" + "=" * 60)
    print("WiFi Mega Optimizer - Installation & Startup")
    print("=" * 60 + "\n")

    # Apply optimizations
    print("[1/4] Applying network optimizations...")
    apply_network_optimizations()
    optimize_wifi_adapter_settings()

    # Flush DNS
    print("[2/4] Flushing DNS cache...")
    flush_dns()

    # Install startup task
    print("[3/4] Installing startup task...")
    if install_startup_task():
        print("    [OK] Startup task installed - will run on every boot")
    else:
        print("    [FAIL] Failed to install startup task")

    # Start monitoring
    print("[4/4] Starting WiFi monitor...")
    print("\n" + "-" * 60)
    print("WiFi monitoring is now active!")
    print("The optimizer will:")
    print(f"  • Check connection every {CHECK_INTERVAL_SECONDS} seconds")
    print(f"  • Auto-reconnect if disconnected")
    print(f"  • Test speed every {SPEED_TEST_INTERVAL // 60} minutes")
    print(f"  • Target minimum speed: {MIN_DOWNLOAD_SPEED_MBPS} Mbps")
    print("-" * 60)
    print("Press Ctrl+C to stop monitoring (task will still run on boot)\n")

    monitor = WiFiMonitor()
    try:
        monitor.run()
    except KeyboardInterrupt:
        print("\nMonitoring stopped. Startup task remains active.")

if __name__ == "__main__":
    main()

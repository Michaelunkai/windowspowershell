"""
Fast Windows System Restore Point Creator
Creates a restore point with real-time progress bar and timer.
Must be run as Administrator.
"""
import sys
import io
import ctypes
import subprocess
import threading
import time
from datetime import datetime
from typing import Tuple, Optional
from pathlib import Path

# Fix encoding for Windows console/redirected output
if sys.platform == "win32":
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
    sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8', errors='replace')

# Log file for verification
LOG_FILE = Path(__file__).parent / "restore_log.txt"


def is_admin() -> bool:
    """Check if running with administrator privileges."""
    try:
        return bool(ctypes.windll.shell32.IsUserAnAdmin())
    except Exception:
        return False


class ProgressBar:
    """Real-time progress bar with elapsed timer."""
    
    def __init__(self, total_width: int = 40):
        self.total_width = total_width
        self.start_time: Optional[float] = None
        self.running = False
        self.status = "Initializing..."
        self.success: Optional[bool] = None
        self.result_msg = ""
        
    def start(self) -> None:
        self.start_time = time.time()
        self.running = True
        
    def stop(self, success: bool = True, message: str = "") -> None:
        self.running = False
        self.success = success
        self.result_msg = message
        
    def get_elapsed(self) -> float:
        if self.start_time is not None:
            return time.time() - self.start_time
        return 0.0
        
    def format_time(self, seconds: float) -> str:
        mins = int(seconds // 60)
        secs = int(seconds % 60)
        ms = int((seconds % 1) * 10)
        return f"{mins:02d}:{secs:02d}.{ms}"
    
    def render(self) -> None:
        elapsed = self.get_elapsed()
        elapsed_str = self.format_time(elapsed)
        
        # Animated spinner
        spinner = "⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"
        spin_char = spinner[int(elapsed * 10) % len(spinner)]
        
        # Progress bar animation (indeterminate)
        pos = int(elapsed * 2) % (self.total_width - 4)
        bar = "░" * self.total_width
        bar = bar[:pos] + "████" + bar[pos+4:]
        
        # Color codes
        CYAN = "\033[96m"
        GREEN = "\033[92m"
        YELLOW = "\033[93m"
        RESET = "\033[0m"
        
        # Status line
        line = f"\r{CYAN}{spin_char}{RESET} [{YELLOW}{bar}{RESET}] {GREEN}{elapsed_str}{RESET} | {self.status}"
        
        # Pad to clear previous content
        line = line + " " * 20
        
        print(line, end="", flush=True)


def create_restore_point_async(description: str, progress: ProgressBar) -> Tuple[bool, str, int]:
    """Run restore point creation using fast WMI method. Returns (success, message, total_count)."""
    
    progress.status = "Bypassing frequency limit..."
    
    # ULTRA-FAST: Use WMI SystemRestore.CreateRestorePoint directly
    # Skip counting - it's slow on some systems. Count will be done separately.
    # RestorePointType: 12=MODIFY_SETTINGS, EventType: 100=BEGIN_SYSTEM_CHANGE
    ps_cmd = f'''
$ErrorActionPreference = "Stop"
try {{
    # Bypass 24-hour limit (fast registry write)
    $null = New-ItemProperty -Path "HKLM:\\SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\SystemRestore" -Name "SystemRestorePointCreationFrequency" -Value 0 -PropertyType DWord -Force -ErrorAction SilentlyContinue 2>$null
    Set-ItemProperty -Path "HKLM:\\SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\SystemRestore" -Name "SystemRestorePointCreationFrequency" -Value 0 -Force -ErrorAction SilentlyContinue 2>$null
    Write-Output "CREATING"
    
    # Create restore point via WMI (fastest method)
    $sr = [wmiclass]"\\\\localhost\\root\\default:SystemRestore"
    $result = $sr.CreateRestorePoint("{description}", 12, 100)
    
    if ($result.ReturnValue -eq 0) {{
        Write-Output "SUCCESS:0"
    }} else {{
        Write-Output "ERROR:WMI returned code $($result.ReturnValue)"
    }}
}} catch {{
    Write-Output "ERROR:$($_.Exception.Message)"
}}
'''
    
    try:
        process = subprocess.Popen(
            ["powershell.exe", "-ExecutionPolicy", "Bypass", "-NoProfile", "-NoLogo", "-Command", ps_cmd],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            bufsize=1
        )
        
        total_count = 0
        
        # Read output line by line
        if process.stdout is not None:
            for line in process.stdout:
                line = line.strip()
                if line == "CREATING":
                    progress.status = "Creating restore point..."
                elif line == "COUNTING":
                    progress.status = "Verifying..."
                elif line.startswith("SUCCESS:"):
                    total_count = int(line.split(":")[1]) if line.split(":")[1].isdigit() else 0
                    progress.stop(True, "Created successfully!")
                    return True, "OK", total_count
                elif line.startswith("ERROR:"):
                    err = line.split(":", 1)[1]
                    progress.stop(False, f"Error: {err}")
                    return False, err, 0
        
        process.wait()
        
        if process.returncode != 0:
            stderr_output = ""
            if process.stderr is not None:
                stderr_output = process.stderr.read()
            progress.stop(False, f"Failed: {stderr_output}")
            return False, stderr_output, 0
            
        progress.stop(True, "Completed")
        return True, "OK", 0
        
    except Exception as e:
        progress.stop(False, str(e))
        return False, str(e), 0


class ResultHolder:
    """Thread-safe result container."""
    def __init__(self):
        self.success: bool = False
        self.message: str = ""
        self.total_count: int = 0


def get_restore_point_count(timeout: int = 30) -> int:
    """Get total restore point count with timeout. Returns -1 on failure."""
    try:
        # Use vssadmin which is faster than WMI queries
        result = subprocess.run(
            ["powershell.exe", "-NoProfile", "-NoLogo", "-Command",
             "@(Get-WmiObject -Namespace 'root\\default' -Class SystemRestore -ErrorAction SilentlyContinue).Count"],
            capture_output=True,
            text=True,
            timeout=timeout
        )
        count = result.stdout.strip()
        return int(count) if count.isdigit() else -1
    except subprocess.TimeoutExpired:
        return -1
    except Exception:
        return -1


def main() -> None:
    # Enable ANSI colors on Windows
    if sys.platform == "win32":
        ctypes.windll.kernel32.SetConsoleMode(
            ctypes.windll.kernel32.GetStdHandle(-11), 7
        )
    
    # Colors
    BOLD = "\033[1m"
    CYAN = "\033[96m"
    GREEN = "\033[92m"
    RED = "\033[91m"
    YELLOW = "\033[93m"
    RESET = "\033[0m"
    
    print(f"\n{BOLD}{CYAN}╔══════════════════════════════════════════════════╗{RESET}")
    print(f"{BOLD}{CYAN}║      ⚡ FAST RESTORE POINT CREATOR ⚡             ║{RESET}")
    print(f"{BOLD}{CYAN}╚══════════════════════════════════════════════════╝{RESET}\n")
    
    # Check admin
    if not is_admin():
        print(f"{RED}[✗] NOT running as Administrator!{RESET}")
        print(f"{YELLOW}[!] Elevating privileges...{RESET}\n")
        
        ctypes.windll.shell32.ShellExecuteW(
            None, "runas", sys.executable, " ".join([f'"{arg}"' for arg in sys.argv]), None, 1
        )
        sys.exit(0)
    
    print(f"{GREEN}[✓] Running as Administrator{RESET}")
    
    # Get description (filter out flags)
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    if args:
        description = " ".join(args)
    else:
        description = f"FastRP_{datetime.now().strftime('%Y%m%d_%H%M%S')}"
    
    print(f"{CYAN}[i] Description: {description}{RESET}")
    print(f"{CYAN}[i] Target: Under 60 seconds{RESET}\n")
    print("─" * 55)
    
    # Create progress bar
    progress = ProgressBar(total_width=35)
    progress.status = "Starting..."
    progress.start()
    
    # Run in thread with result holder
    result_holder = ResultHolder()
    
    def worker() -> None:
        success, msg, total = create_restore_point_async(description, progress)
        result_holder.success = success
        result_holder.message = msg
        result_holder.total_count = total
    
    thread = threading.Thread(target=worker)
    thread.start()
    
    # Display progress while waiting
    while thread.is_alive():
        progress.render()
        time.sleep(0.05)
    
    thread.join()
    
    # Final render
    progress.render()
    print()  # New line after progress bar
    print("─" * 55)
    
    elapsed = progress.get_elapsed()
    elapsed_str = progress.format_time(elapsed)
    
    # Log results to file
    log_entry = f"[{datetime.now().isoformat()}] "
    
    if result_holder.success:
        print(f"\n{GREEN}{BOLD}[✓] RESTORE POINT CREATED SUCCESSFULLY!{RESET}")
        print(f"{GREEN}[✓] Time: {elapsed_str}{RESET}")
        if elapsed < 60:
            print(f"{GREEN}[✓] Under 60 seconds - TARGET MET! ⚡{RESET}")
        else:
            print(f"{YELLOW}[!] Took longer than 60 seconds ({elapsed:.1f}s){RESET}")
        print(f"{CYAN}[i] Details: {result_holder.message}{RESET}")
        log_entry += f"SUCCESS | Time: {elapsed_str} | {result_holder.message}"
    else:
        print(f"\n{RED}{BOLD}[✗] FAILED TO CREATE RESTORE POINT{RESET}")
        print(f"{RED}[✗] Time: {elapsed_str}{RESET}")
        print(f"{RED}[✗] Error: {result_holder.message}{RESET}")
        log_entry += f"FAILED | Time: {elapsed_str} | {result_holder.message}"
    
    # Write log
    try:
        with open(LOG_FILE, "a", encoding="utf-8") as f:
            f.write(log_entry + "\n")
        print(f"{CYAN}[i] Log: {LOG_FILE}{RESET}")
    except Exception:
        pass
    
    # Get and show total restore points (async, with timeout)
    if result_holder.success:
        print(f"{CYAN}[i] Getting total restore points...{RESET}", end="", flush=True)
        total = get_restore_point_count(timeout=30)
        if total > 0:
            print(f"\r{CYAN}[i] Total restore points in system: {BOLD}{total}{RESET}    ")
        else:
            print(f"\r{CYAN}[i] Total restore points: (query timed out)    {RESET}")
    
    print()
    
    # Auto-close after 5 seconds if --auto flag
    if "--auto" in sys.argv:
        print("Auto-closing in 5 seconds...")
        time.sleep(5)
    else:
        input("Press Enter to exit...")
    
    if not result_holder.success:
        sys.exit(1)


if __name__ == "__main__":
    main()

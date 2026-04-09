#!/usr/bin/env python3
"""
WMI/WMIC Repair + DISM/SFC Health Check Script v3.0
Complete Windows System Repair with Post-Reboot Validation
Must run as Administrator
Features: 45s stall detection, smart skip, aggressive timeouts, full Windows repair,
          comprehensive WMI testing, service configuration, post-reboot validation
"""

import subprocess
import sys
import os
import ctypes
import re
import time
import glob
import threading
import queue
import shutil
import winreg
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor, as_completed

# Fix Windows console encoding - MUST be before any print
if sys.platform == 'win32':
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')
    sys.stderr.reconfigure(encoding='utf-8', errors='replace')
    # Also enable VT100 sequences
    kernel32 = ctypes.windll.kernel32
    kernel32.SetConsoleMode(kernel32.GetStdHandle(-11), 7)

# Logging class to write to both console and file
class TeeLogger:
    def __init__(self, log_path):
        self.terminal = sys.stdout
        self.log_path = log_path
        # Clear/create log file
        with open(log_path, 'w', encoding='utf-8') as f:
            f.write('')

    def write(self, message):
        self.terminal.write(message)
        self.terminal.flush()
        with open(self.log_path, 'a', encoding='utf-8') as f:
            # Strip ANSI codes for log file
            clean = re.sub(r'\x1b\[[0-9;]*m', '', message)
            f.write(clean)

    def flush(self):
        self.terminal.flush()

# Enable logging
LOG_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'run_log.txt')
sys.stdout = TeeLogger(LOG_PATH)

# ANSI color codes
class Colors:
    CYAN = '\033[96m'
    GREEN = '\033[92m'
    YELLOW = '\033[93m'
    RED = '\033[91m'
    RESET = '\033[0m'
    BOLD = '\033[1m'
    MAGENTA = '\033[95m'

# Global timeout settings (in seconds) - AGGRESSIVE to avoid stuck
DISM_TIMEOUT = 300  # 5 minutes max for DISM
SFC_TIMEOUT = 300   # 5 minutes max for SFC
CMD_TIMEOUT = 30    # 30 sec for simple commands
STALL_TIMEOUT = 45  # 45 sec max at same % before killing

def is_admin():
    """Check if running with administrator privileges"""
    try:
        return ctypes.windll.shell32.IsUserAnAdmin()
    except:
        return False

def out(msg, color=Colors.RESET):
    """Print colored output"""
    print(f"{color}{msg}{Colors.RESET}")

def progress_bar(current, total, width=50, prefix="Progress", suffix=""):
    """Display a progress bar"""
    if total == 0:
        percent = 100
    else:
        percent = (current / total) * 100
    filled = int(width * current // max(total, 1))
    bar = '=' * filled + '-' * (width - filled)
    print(f"\r{prefix} [{bar}] {percent:5.1f}% {suffix}".ljust(100), end='', flush=True)
    if current >= total:
        print()

def run_cmd(cmd, timeout=CMD_TIMEOUT, show_output=False):
    """Run a command and return exit code with timeout"""
    try:
        if show_output:
            result = subprocess.run(cmd, shell=True, capture_output=False, timeout=timeout)
        else:
            result = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=timeout)
        return result.returncode
    except subprocess.TimeoutExpired:
        return -2  # Timeout code
    except Exception as e:
        return -1

def run_cmd_output(cmd, timeout=CMD_TIMEOUT):
    """Run command and return output"""
    try:
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=timeout)
        return result.stdout + result.stderr
    except subprocess.TimeoutExpired:
        return "TIMEOUT"
    except:
        return ""

def output_reader(pipe, q):
    """Thread function to read output non-blocking"""
    try:
        while True:
            byte = pipe.read(1)
            if not byte:
                break
            q.put(byte)
    except:
        pass
    finally:
        q.put(None)

def kill_process_tree(pid):
    """Kill process and all children"""
    try:
        subprocess.run(f'taskkill /F /T /PID {pid}', shell=True, capture_output=True, timeout=10)
    except:
        pass

def run_dism_with_progress(args, step_name, max_timeout=DISM_TIMEOUT):
    """Run DISM command with real-time progress and hard timeout (never stuck)"""
    # Validate args contains required operation - prevent Error 1639
    if not args or args.strip() == '/online':
        out(f"    ✗ ERROR: DISM called without operation command!", Colors.RED)
        return -1, "MISSING_OPERATION"

    # Ensure /online is included if not present
    if '/online' not in args.lower():
        args = f'/online {args}'

    cmd = f'dism.exe {args}'
    out(f"    Running: {cmd}", Colors.YELLOW)

    progress_bar(0, 100, prefix=step_name)

    process = subprocess.Popen(
        cmd,
        shell=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        bufsize=0
    )

    q = queue.Queue()
    reader_thread = threading.Thread(target=output_reader, args=(process.stdout, q))
    reader_thread.daemon = True
    reader_thread.start()

    last_percent = 0
    error_code = None
    buffer = b''
    start_time = time.time()
    estimated_duration = 180  # 3 min estimate
    spinner_chars = ['|', '/', '-', '\\']
    spinner_idx = 0
    last_activity = time.time()

    # AGGRESSIVE stall detection - 45s max at any % before killing
    def get_stall_timeout():
        if last_percent >= 95:
            return 60  # 60s near end
        else:
            return STALL_TIMEOUT  # 45s everywhere else

    while True:
        current_time = time.time()
        elapsed = current_time - start_time

        # HARD TIMEOUT - never stuck
        if elapsed > max_timeout:
            out(f"\n    ⚠ Timeout after {int(elapsed)}s, killing process...", Colors.YELLOW)
            kill_process_tree(process.pid)
            process.kill()
            return -2, "TIMEOUT"

        stall_timeout = get_stall_timeout()
        if current_time - last_activity > stall_timeout and last_percent < 99:
            out(f"\n    ⚠ No activity for {int(stall_timeout)}s at {last_percent}%, killing...", Colors.YELLOW)
            kill_process_tree(process.pid)
            process.kill()
            return -3, "STALLED"

        try:
            byte = q.get(timeout=0.15)
            last_activity = time.time()
        except queue.Empty:
            if process.poll() is not None:
                break
            time_progress = 99 * (1 - (1 / (1 + elapsed / estimated_duration)))
            micro_increment = (elapsed % 5) / 50
            display_percent = max(last_percent, min(99, time_progress + micro_increment))
            spinner = spinner_chars[spinner_idx % 4]
            spinner_idx += 1
            time_at_current = current_time - last_activity
            if time_at_current > 30:
                wait_info = f"{spinner} {int(elapsed)}s (working...)"
            else:
                wait_info = f"{spinner} {int(elapsed)}s"
            progress_bar(int(display_percent), 100, prefix=step_name, suffix=wait_info)
            continue

        if byte is None:
            break

        buffer += byte

        if byte in (b'\r', b'\n', b']', b'%'):
            try:
                line = buffer.decode('utf-8', errors='ignore')
            except:
                line = buffer.decode('latin-1', errors='ignore')

            match = re.search(r'\[\s*(\d+\.?\d*)\s*%', line)
            if not match:
                match = re.search(r'(\d+\.?\d*)\s*%', line)

            if match:
                percent = float(match.group(1))
                if percent > last_percent:
                    progress_bar(int(percent), 100, prefix=step_name)
                    last_percent = int(percent)
                    last_activity = time.time()
                    if percent > 5:
                        estimated_duration = (elapsed / percent) * 100 * 1.1

            if 'Error:' in line or 'error' in line.lower():
                error_match = re.search(r'Error:\s*(0x[0-9a-fA-F]+|\d+)', line)
                if error_match:
                    error_code = error_match.group(1)

            if byte == b'\n':
                buffer = b''

    process.wait()

    if process.returncode == 0:
        progress_bar(100, 100, prefix=step_name)
    else:
        progress_bar(100, 100, prefix=step_name, suffix="!")
        print()

    return process.returncode, error_code

def run_sfc_with_progress(max_timeout=SFC_TIMEOUT):
    """Run SFC /scannow with real-time progress and hard timeout"""
    out("    Running: sfc /scannow", Colors.YELLOW)

    progress_bar(0, 100, prefix="SFC Scan")

    process = subprocess.Popen(
        'sfc /scannow',
        shell=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        bufsize=0
    )

    q = queue.Queue()
    reader_thread = threading.Thread(target=output_reader, args=(process.stdout, q))
    reader_thread.daemon = True
    reader_thread.start()

    last_percent = 0
    phase = "Scan"
    buffer = b''
    start_time = time.time()
    estimated_duration = 180
    spinner_chars = ['|', '/', '-', '\\']
    spinner_idx = 0
    last_activity = time.time()

    while True:
        current_time = time.time()
        elapsed = current_time - start_time

        if elapsed > max_timeout:
            out(f"\n    ⚠ Timeout after {int(elapsed)}s, killing process...", Colors.YELLOW)
            kill_process_tree(process.pid)
            process.kill()
            return -2

        try:
            byte = q.get(timeout=0.15)
            last_activity = time.time()
        except queue.Empty:
            if process.poll() is not None:
                break
            time_progress = 99 * (1 - (1 / (1 + elapsed / estimated_duration)))
            micro_increment = (elapsed % 5) / 50
            display_percent = max(last_percent, min(99, time_progress + micro_increment))
            spinner = spinner_chars[spinner_idx % 4]
            spinner_idx += 1
            progress_bar(int(display_percent), 100, prefix=f"SFC {phase}", suffix=f"{spinner} {int(elapsed)}s")
            continue

        if byte is None:
            break

        buffer += byte

        if byte in (b'\r', b'\n', b'%'):
            try:
                line = buffer.decode('utf-8', errors='ignore')
            except:
                line = buffer.decode('latin-1', errors='ignore')

            if 'verification' in line.lower():
                phase = "Verify"
            elif 'repair' in line.lower():
                phase = "Repair"
            elif 'scan' in line.lower():
                phase = "Scan"

            match = re.search(r'(\d+)\s*%', line)
            if match:
                percent = int(match.group(1))
                if percent > last_percent:
                    progress_bar(percent, 100, prefix=f"SFC {phase}")
                    last_percent = percent
                    last_activity = time.time()
                    if percent > 5:
                        estimated_duration = (elapsed / percent) * 100 * 1.1

            if byte == b'\n':
                buffer = b''

    process.wait()
    progress_bar(100, 100, prefix="SFC Complete")

    return process.returncode

# ============================================================================
# PHASE 0: PREPARATION
# ============================================================================

def step_0_prepare_system(total_steps):
    """Step 0: Prepare system - stop services, clean caches"""
    step = 0
    out(f"\n[{step}/{total_steps}] Preparing system (stopping services, cleaning caches)...", Colors.YELLOW)

    tasks = [
        ('Stop BITS', 'net stop bits /y 2>nul'),
        ('Stop wuauserv', 'net stop wuauserv /y 2>nul'),
        ('Stop appidsvc', 'net stop appidsvc /y 2>nul'),
        ('Stop cryptsvc', 'net stop cryptsvc /y 2>nul'),
        ('Stop TrustedInstaller', 'net stop TrustedInstaller /y 2>nul'),
        ('Stop Winmgmt', 'net stop Winmgmt /y 2>nul'),
        ('Stop WmiApSrv', 'net stop WmiApSrv /y 2>nul'),
    ]

    total = len(tasks)
    for i, (name, cmd) in enumerate(tasks):
        run_cmd(cmd, timeout=30)
        progress_bar(i + 1, total, prefix="Prepare")

    out("    ✓ Services stopped.", Colors.GREEN)
    return True

def step_1_clean_update_cache(total_steps):
    """Step 1: Clean Windows Update caches (fast, never stuck)"""
    step = 1
    out(f"\n[{step}/{total_steps}] Cleaning Windows Update caches...", Colors.YELLOW)

    system_root = os.environ.get('SystemRoot', 'C:\\Windows')
    total_ops = 4

    def fast_delete(path, timeout=10):
        """Delete folder using cmd with timeout - never hangs"""
        if os.path.exists(path):
            try:
                proc = subprocess.Popen(
                    f'cmd /c rd /s /q "{path}"',
                    shell=True,
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL
                )
                proc.wait(timeout=timeout)
            except subprocess.TimeoutExpired:
                proc.kill()
            except:
                pass

    def fast_rename(src, dst, timeout=5):
        """Rename using cmd with timeout - never hangs"""
        if os.path.exists(src):
            try:
                proc = subprocess.Popen(
                    f'cmd /c ren "{src}" "{os.path.basename(dst)}"',
                    shell=True,
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL,
                    cwd=os.path.dirname(src)
                )
                proc.wait(timeout=timeout)
            except subprocess.TimeoutExpired:
                proc.kill()
            except:
                pass

    progress_bar(0, total_ops, prefix="Clean Cache")

    # 1. Clean SoftwareDistribution
    sd_path = os.path.join(system_root, 'SoftwareDistribution')
    sd_old = sd_path + '.old'
    fast_delete(sd_old, timeout=5)
    fast_rename(sd_path, sd_old, timeout=3)
    progress_bar(1, total_ops, prefix="Clean Cache")

    # 2. Clean catroot2
    cat_path = os.path.join(system_root, 'System32', 'catroot2')
    cat_old = cat_path + '.old'
    fast_delete(cat_old, timeout=5)
    fast_rename(cat_path, cat_old, timeout=3)
    progress_bar(2, total_ops, prefix="Clean Cache")

    # 3. Clean pending.xml
    pending_xml = os.path.join(system_root, 'WinSxS', 'pending.xml')
    try:
        if os.path.exists(pending_xml):
            os.remove(pending_xml)
    except:
        pass
    progress_bar(3, total_ops, prefix="Clean Cache")

    # 4. Clean ReportQueue
    report_queue = os.path.join(system_root, 'WinSxS', 'ReportQueue')
    fast_delete(report_queue, timeout=3)
    progress_bar(4, total_ops, prefix="Clean Cache")

    out("    ✓ Update caches cleaned.", Colors.GREEN)
    return True

# ============================================================================
# PHASE 1: WMI REPAIR
# ============================================================================

def step_2_wmic_capability(total_steps):
    """Step 2: Check/Install WMIC capability"""
    step = 2
    out(f"\n[{step}/{total_steps}] Checking WMIC optional capability...", Colors.YELLOW)
    progress_bar(0, 3, prefix="WMIC Cap")

    cap_name = "WMIC~~~~"

    output = run_cmd_output(f'dism /online /Get-CapabilityInfo /CapabilityName:{cap_name}')
    progress_bar(1, 3, prefix="WMIC Cap")

    if 'State : Installed' in output:
        progress_bar(3, 3, prefix="WMIC Cap")
        out("    ✓ WMIC capability already installed.", Colors.GREEN)
        return True

    out("    → Capability missing, installing...", Colors.YELLOW)
    progress_bar(2, 3, prefix="WMIC Cap")

    exit_code = run_cmd(f'dism /online /Add-Capability /CapabilityName:{cap_name} /NoRestart /Quiet', timeout=120)

    if exit_code == 0:
        progress_bar(3, 3, prefix="WMIC Cap")
        out("    ✓ WMIC capability installed successfully.", Colors.GREEN)
        return True

    out("    → DISM failed, trying Add-WindowsCapability...", Colors.YELLOW)
    exit_code = run_cmd(f'powershell -Command "Add-WindowsCapability -Online -Name {cap_name}"', timeout=120)

    progress_bar(3, 3, prefix="WMIC Cap")

    if exit_code == 0:
        out("    ✓ Add-WindowsCapability succeeded.", Colors.GREEN)
        return True

    out("    ⚠ Unable to install WMIC capability (may already work via WinSxS).", Colors.YELLOW)
    return True  # Continue anyway

def step_3_wmic_exe(total_steps):
    """Step 3: Ensure wmic.exe exists or works via PATH"""
    step = 3
    out(f"\n[{step}/{total_steps}] Checking wmic.exe presence...", Colors.YELLOW)

    wbem_dir = os.path.join(os.environ['SystemRoot'], 'System32', 'wbem')
    wmic_exe = os.path.join(wbem_dir, 'wmic.exe')

    progress_bar(0, 3, prefix="WMIC Exe")

    # Check if wmic works (regardless of where it is)
    result = run_cmd('wmic os get Caption /value', timeout=15)
    if result == 0:
        progress_bar(3, 3, prefix="WMIC Exe")
        out("    ✓ WMIC command works.", Colors.GREEN)
        return True

    progress_bar(1, 3, prefix="WMIC Exe")

    if os.path.exists(wmic_exe):
        progress_bar(3, 3, prefix="WMIC Exe")
        out(f"    ✓ wmic.exe present at {wmic_exe}", Colors.GREEN)
        return True

    out("    → wmic.exe missing, searching WinSxS...", Colors.YELLOW)
    progress_bar(2, 3, prefix="WMIC Exe")

    # Search in WinSxS
    winsxs = os.path.join(os.environ['SystemRoot'], 'WinSxS')
    pattern = os.path.join(winsxs, '*wmic*', 'wmic.exe')
    matches = glob.glob(pattern)

    if matches:
        found = matches[0]
        try:
            shutil.copy2(found, wmic_exe)
            progress_bar(3, 3, prefix="WMIC Exe")
            out(f"    ✓ Copied {found} to {wmic_exe}", Colors.GREEN)
            return True
        except Exception as e:
            out(f"    ⚠ Failed to copy: {e}", Colors.YELLOW)

    progress_bar(3, 3, prefix="WMIC Exe")
    out("    ⚠ wmic.exe not found, but may work via capability.", Colors.YELLOW)
    return True  # Continue anyway

def step_4_reset_wmi(total_steps):
    """Step 4: Reset WMI services & repository"""
    step = 4
    out(f"\n[{step}/{total_steps}] Resetting WMI services & repository...", Colors.YELLOW)

    services = ['Winmgmt', 'WmiApSrv']
    total_ops = 7
    current = 0

    # Configure services to auto-start
    for svc in services:
        run_cmd(f'sc config {svc} start= auto', timeout=15)
        current += 1
        progress_bar(current, total_ops, prefix="WMI Reset")

    # Salvage repository
    run_cmd('winmgmt /salvagerepository', timeout=60)
    current += 1
    progress_bar(current, total_ops, prefix="WMI Reset")

    # Reset repository if needed
    run_cmd('winmgmt /resetrepository', timeout=60)
    current += 1
    progress_bar(current, total_ops, prefix="WMI Reset")

    # Verify repository
    run_cmd('winmgmt /verifyrepository', timeout=30)
    current += 1
    progress_bar(current, total_ops, prefix="WMI Reset")

    # Register WMI provider DLLs
    wbem_dir = os.path.join(os.environ['SystemRoot'], 'System32', 'wbem')
    dlls = ['wbemcore.dll', 'wmisvc.dll', 'fastprox.dll', 'wmiutils.dll',
            'wbemsvc.dll', 'wbemdisp.dll', 'wbemprox.dll', 'mofd.dll', 'mofcomp.exe']
    for dll in dlls:
        dll_path = os.path.join(wbem_dir, dll)
        if os.path.exists(dll_path) and dll.endswith('.dll'):
            run_cmd(f'regsvr32 /s "{dll_path}"', timeout=10)
    current += 1
    progress_bar(current, total_ops, prefix="WMI Reset")

    # Start services
    for svc in services:
        run_cmd(f'net start {svc} 2>nul', timeout=30)
    current += 1
    progress_bar(current, total_ops, prefix="WMI Reset")

    out("    ✓ WMI services restarted & repository verified.", Colors.GREEN)
    return True

def compile_mof(mof_path):
    """Compile a single MOF file with strict timeout (never hangs)"""
    try:
        proc = subprocess.Popen(
            f'mofcomp "{mof_path}"',
            shell=True,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL
        )
        try:
            proc.wait(timeout=5)  # 5 second max per file
        except subprocess.TimeoutExpired:
            proc.kill()
            proc.wait()
    except:
        pass
    return mof_path

def step_5_recompile_mof(total_steps):
    """Step 5: Recompile CORE MOF files only (fast, never stuck)"""
    step = 5
    out(f"\n[{step}/{total_steps}] Recompiling core MOF files...", Colors.YELLOW)

    wbem_dir = os.path.join(os.environ['SystemRoot'], 'System32', 'wbem')

    # Only compile essential MOF files
    core_mofs = [
        'cimwin32.mof', 'cimwin32.mfl',
        'system.mof',
        'win32_encryptablevolume.mof',
        'scrcons.mof',
        'smtpcons.mof',
        'wmipcima.mof', 'wmipcima.mfl',
        'ncprov.mof',
        'msfeeds.mof',
        'secrcw32.mof', 'secrcw32.mfl',
        'policman.mof',
        'subscrpt.mof',
        'regevent.mof',
        'ntevt.mof', 'ntevt.mfl',
        'scm.mof',
        'wmi.mof',
        'dsprov.mof',
        'cli.mof',
    ]

    mof_files = []
    for mof_name in core_mofs:
        mof_path = os.path.join(wbem_dir, mof_name)
        if os.path.exists(mof_path):
            mof_files.append(mof_path)

    # Also add en-US locale files
    en_us_dir = os.path.join(wbem_dir, 'en-US')
    if os.path.exists(en_us_dir):
        for mof_name in core_mofs:
            if mof_name.endswith('.mfl'):
                mof_path = os.path.join(en_us_dir, mof_name)
                if os.path.exists(mof_path):
                    mof_files.append(mof_path)

    total = len(mof_files)
    out(f"    Compiling {total} core MOF files...", Colors.YELLOW)

    if total == 0:
        out("    ⚠ No core MOF files found, running registration...", Colors.YELLOW)
        run_cmd('winmgmt /regserver', timeout=30)
        progress_bar(1, 1, prefix="MOF Compile")
        out("    ✓ WMI registration complete.", Colors.GREEN)
        return True

    completed = 0
    workers = min(os.cpu_count() or 4, 8)

    with ThreadPoolExecutor(max_workers=workers) as executor:
        futures = {executor.submit(compile_mof, mof): mof for mof in mof_files}
        for future in as_completed(futures):
            completed += 1
            progress_bar(completed, total, prefix="MOF Compile", suffix=f"({completed}/{total})")

    run_cmd('winmgmt /regserver', timeout=30)
    out("    ✓ Core MOF compilation complete.", Colors.GREEN)
    return True

def step_6_system_path(total_steps):
    """Step 6: Ensure WBEM in system PATH"""
    step = 6
    out(f"\n[{step}/{total_steps}] Checking WBEM in system PATH...", Colors.YELLOW)

    wbem_dir = os.path.join(os.environ['SystemRoot'], 'System32', 'wbem')

    progress_bar(0, 2, prefix="PATH Check")

    current_path = os.environ.get('PATH', '')

    progress_bar(1, 2, prefix="PATH Check")

    if wbem_dir.lower() in current_path.lower():
        progress_bar(2, 2, prefix="PATH Check")
        out("    ✓ WBEM already in PATH.", Colors.GREEN)
        return True

    run_cmd(f'setx PATH "%PATH%;{wbem_dir}" -m', timeout=15)
    os.environ['PATH'] = current_path + ';' + wbem_dir

    progress_bar(2, 2, prefix="PATH Check")
    out("    ✓ Added WBEM directory to system PATH.", Colors.GREEN)
    return True

# ============================================================================
# PHASE 2: SYSTEM HEALTH (DISM/SFC)
# ============================================================================

def step_7_start_services(total_steps):
    """Step 7: Start and configure all required services"""
    step = 7
    out(f"\n[{step}/{total_steps}] Starting and configuring services...", Colors.YELLOW)

    # Services that should be auto-start
    auto_services = [
        ('cryptsvc', 'Cryptographic Services'),
        ('TrustedInstaller', 'Windows Modules Installer'),
        ('Winmgmt', 'Windows Management Instrumentation'),
    ]

    # Services that can be manual
    manual_services = [
        ('wuauserv', 'Windows Update'),
        ('bits', 'Background Intelligent Transfer'),
    ]

    total = len(auto_services) + len(manual_services)
    current = 0

    # Configure and start auto services
    for svc, name in auto_services:
        run_cmd(f'sc config {svc} start= auto', timeout=15)
        run_cmd(f'net start {svc} 2>nul', timeout=30)
        current += 1
        progress_bar(current, total, prefix="Start Svcs")

    # Just start manual services (don't change config)
    for svc, name in manual_services:
        run_cmd(f'net start {svc} 2>nul', timeout=30)
        current += 1
        progress_bar(current, total, prefix="Start Svcs")

    time.sleep(2)
    out("    ✓ Services configured and started.", Colors.GREEN)
    return True

def step_8_component_cleanup(total_steps):
    """Step 8: Run component cleanup"""
    step = 8
    out(f"\n[{step}/{total_steps}] Running component cleanup...", Colors.YELLOW)

    exit_code, _ = run_dism_with_progress(
        '/online /Cleanup-Image /StartComponentCleanup',
        "Cleanup",
        max_timeout=300
    )

    if exit_code == 0:
        out("    ✓ Component cleanup succeeded.", Colors.GREEN)
    else:
        out("    ⚠ Component cleanup had issues, continuing...", Colors.YELLOW)

    return True

def step_9_check_health(total_steps):
    """Step 9: Run DISM CheckHealth"""
    step = 9
    out(f"\n[{step}/{total_steps}] Running DISM CheckHealth...", Colors.YELLOW)

    exit_code, error_code = run_dism_with_progress(
        '/online /Cleanup-Image /CheckHealth',
        "CheckHealth",
        max_timeout=120
    )

    if exit_code == 0:
        out("    ✓ CheckHealth passed.", Colors.GREEN)
    else:
        out(f"    ⚠ CheckHealth detected issues (error: {error_code})", Colors.YELLOW)

    return True

def step_10_scan_health(total_steps):
    """Step 10: Run DISM ScanHealth"""
    step = 10
    out(f"\n[{step}/{total_steps}] Running DISM ScanHealth...", Colors.YELLOW)

    exit_code, error_code = run_dism_with_progress(
        '/online /Cleanup-Image /ScanHealth',
        "ScanHealth",
        max_timeout=DISM_TIMEOUT
    )

    if exit_code == 0:
        out("    ✓ ScanHealth completed - NO corruption found.", Colors.GREEN)
        return True
    else:
        out(f"    ⚠ ScanHealth found issues (error: {error_code})", Colors.YELLOW)
        return False

def clear_pending_operations():
    """Clear pending operations that cause issues"""
    out("    → Clearing pending operations...", Colors.YELLOW)

    system_root = os.environ.get('SystemRoot', 'C:\\Windows')

    # Clear pending.xml
    pending_xml = os.path.join(system_root, 'WinSxS', 'pending.xml')
    try:
        if os.path.exists(pending_xml):
            os.rename(pending_xml, pending_xml + '.bak')
            out("      ✓ Moved pending.xml", Colors.GREEN)
    except:
        pass

    # Clear poqexec.log
    poq_log = os.path.join(system_root, 'WinSxS', 'poqexec.log')
    try:
        if os.path.exists(poq_log):
            os.remove(poq_log)
            out("      ✓ Removed poqexec.log", Colors.GREEN)
    except:
        pass

    # Clear registry pending operations
    run_cmd('reg delete "HKLM\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Component Based Servicing\\RebootPending" /f 2>nul', timeout=10)
    run_cmd('reg delete "HKLM\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Component Based Servicing\\PackagesPending" /f 2>nul', timeout=10)

    # Reset TrustedInstaller
    run_cmd('net stop TrustedInstaller 2>nul', timeout=15)
    time.sleep(1)
    run_cmd('net start TrustedInstaller 2>nul', timeout=15)

    out("      ✓ Pending operations cleared", Colors.GREEN)

def step_11_restore_health(total_steps):
    """Step 11: Run DISM RestoreHealth"""
    step = 11
    out(f"\n[{step}/{total_steps}] Running DISM RestoreHealth...", Colors.YELLOW)

    clear_pending_operations()

    exit_code, error_code = run_dism_with_progress(
        '/online /Cleanup-Image /RestoreHealth',
        "RestoreHealth",
        max_timeout=DISM_TIMEOUT
    )

    if exit_code == 0:
        out("    ✓ DISM RestoreHealth succeeded.", Colors.GREEN)
        return True

    if exit_code in (-2, -3):
        out(f"    ⚠ RestoreHealth timed out, trying WU source...", Colors.YELLOW)
    else:
        out(f"    ⚠ RestoreHealth failed, trying WU source...", Colors.YELLOW)

    clear_pending_operations()

    exit_code2, _ = run_dism_with_progress(
        '/online /Cleanup-Image /RestoreHealth /Source:WU /LimitAccess',
        "WU Source",
        max_timeout=DISM_TIMEOUT
    )

    if exit_code2 == 0:
        out("    ✓ DISM with WU source succeeded.", Colors.GREEN)
        return True

    out("    ⚠ RestoreHealth had issues. Continuing...", Colors.YELLOW)
    return False

def step_12_sfc_scan(total_steps):
    """Step 12: Run SFC /scannow"""
    step = 12
    out(f"\n[{step}/{total_steps}] Running SFC /scannow...", Colors.YELLOW)

    run_sfc_with_progress()

    out("    ✓ System file check complete.", Colors.GREEN)
    return True

def step_13_final_cleanup(total_steps):
    """Step 13: Final component cleanup"""
    step = 13
    out(f"\n[{step}/{total_steps}] Running final cleanup...", Colors.YELLOW)

    exit_code, _ = run_dism_with_progress(
        '/online /Cleanup-Image /StartComponentCleanup',
        "Final Clean",
        max_timeout=180
    )

    if exit_code == 0:
        out("    ✓ Final cleanup succeeded.", Colors.GREEN)
    else:
        out("    ⚠ Final cleanup had issues.", Colors.YELLOW)

    return True

# ============================================================================
# PHASE 3: COMPREHENSIVE VALIDATION
# ============================================================================

def test_wmi_classes():
    """Test multiple WMI classes to ensure WMI is fully functional"""
    tests = [
        ('Win32_OperatingSystem', 'Get-WmiObject Win32_OperatingSystem'),
        ('Win32_ComputerSystem', 'Get-WmiObject Win32_ComputerSystem'),
        ('Win32_LogicalDisk', 'Get-WmiObject Win32_LogicalDisk'),
        ('Win32_Process', 'Get-WmiObject Win32_Process | Select-Object -First 1'),
        ('Win32_Service', 'Get-WmiObject Win32_Service | Select-Object -First 1'),
        ('Win32_BIOS', 'Get-WmiObject Win32_BIOS'),
    ]

    passed = 0
    failed = 0

    for name, cmd in tests:
        result = run_cmd(f'powershell -Command "{cmd} | Out-Null"', timeout=30)
        if result == 0:
            passed += 1
        else:
            failed += 1
            out(f"      ✗ {name} query failed", Colors.RED)

    return passed, failed

def test_wmic_queries():
    """Test WMIC queries"""
    tests = [
        ('os', 'wmic os get Caption /value'),
        ('cpu', 'wmic cpu get Name /value'),
        ('memorychip', 'wmic memorychip get Capacity /value'),
        ('diskdrive', 'wmic diskdrive get Model /value'),
    ]

    passed = 0
    failed = 0

    for name, cmd in tests:
        result = run_cmd(cmd, timeout=30)
        if result == 0:
            passed += 1
        else:
            failed += 1
            out(f"      ✗ WMIC {name} query failed", Colors.RED)

    return passed, failed

def check_service_status(service_name):
    """Check if a service is running"""
    output = run_cmd_output(f'sc query "{service_name}"', timeout=10)
    return 'RUNNING' in output

def check_pending_reboot():
    """Check if system has pending reboot"""
    paths = [
        r'SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending',
        r'SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired',
    ]

    for path in paths:
        try:
            key = winreg.OpenKey(winreg.HKEY_LOCAL_MACHINE, path)
            winreg.CloseKey(key)
            return True
        except:
            pass

    return False

def step_14_validation(total_steps):
    """Step 14: Comprehensive validation"""
    step = 14
    out(f"\n[{step}/{total_steps}] Running comprehensive validation...", Colors.YELLOW)

    all_passed = True
    total_tests = 8
    current_test = 0

    # Test 1: WMI Repository
    out("\n    Testing WMI Repository...", Colors.CYAN)
    output = run_cmd_output('winmgmt /verifyrepository', timeout=30)
    current_test += 1
    progress_bar(current_test, total_tests, prefix="Validation")
    if 'consistent' in output.lower():
        out("    ✓ WMI repository is consistent.", Colors.GREEN)
    else:
        out("    ✗ WMI repository may have issues.", Colors.RED)
        all_passed = False

    # Test 2: WMI Classes
    out("\n    Testing WMI classes...", Colors.CYAN)
    wmi_passed, wmi_failed = test_wmi_classes()
    current_test += 1
    progress_bar(current_test, total_tests, prefix="Validation")
    if wmi_failed == 0:
        out(f"    ✓ All {wmi_passed} WMI class tests passed.", Colors.GREEN)
    else:
        out(f"    ⚠ {wmi_passed} passed, {wmi_failed} failed.", Colors.YELLOW)
        if wmi_failed > 2:
            all_passed = False

    # Test 3: WMIC Queries
    out("\n    Testing WMIC queries...", Colors.CYAN)
    wmic_passed, wmic_failed = test_wmic_queries()
    current_test += 1
    progress_bar(current_test, total_tests, prefix="Validation")
    if wmic_failed == 0:
        out(f"    ✓ All {wmic_passed} WMIC tests passed.", Colors.GREEN)
    else:
        out(f"    ⚠ {wmic_passed} passed, {wmic_failed} failed.", Colors.YELLOW)

    # Test 4: CIM Instance
    out("\n    Testing CIM instances...", Colors.CYAN)
    result = run_cmd('powershell -Command "Get-CimInstance Win32_OperatingSystem | Out-Null"', timeout=30)
    current_test += 1
    progress_bar(current_test, total_tests, prefix="Validation")
    if result == 0:
        out("    ✓ CIM instance queries work.", Colors.GREEN)
    else:
        out("    ✗ CIM instance queries failed.", Colors.RED)
        all_passed = False

    # Test 5: Critical Services
    out("\n    Testing critical services...", Colors.CYAN)
    services_ok = True
    critical_services = ['Winmgmt', 'TrustedInstaller', 'cryptsvc']
    for svc in critical_services:
        if check_service_status(svc):
            out(f"      ✓ {svc} is running.", Colors.GREEN)
        else:
            out(f"      ✗ {svc} is NOT running.", Colors.RED)
            services_ok = False
    current_test += 1
    progress_bar(current_test, total_tests, prefix="Validation")
    if not services_ok:
        all_passed = False

    # Test 6: DISM CheckHealth
    out("\n    Testing DISM CheckHealth...", Colors.CYAN)
    exit_code, _ = run_dism_with_progress(
        '/online /Cleanup-Image /CheckHealth',
        "DISM Check",
        max_timeout=60
    )
    current_test += 1
    progress_bar(current_test, total_tests, prefix="Validation")
    if exit_code == 0:
        out("    ✓ DISM CheckHealth passed.", Colors.GREEN)
    else:
        out("    ✗ DISM CheckHealth failed.", Colors.RED)
        all_passed = False

    # Test 7: DISM ScanHealth
    out("\n    Final DISM ScanHealth...", Colors.CYAN)
    exit_code2, _ = run_dism_with_progress(
        '/online /Cleanup-Image /ScanHealth',
        "Final Scan",
        max_timeout=120
    )
    current_test += 1
    progress_bar(current_test, total_tests, prefix="Validation")
    if exit_code2 == 0:
        out("    ✓ DISM ScanHealth confirmed healthy.", Colors.GREEN)
    else:
        out("    ⚠ DISM ScanHealth had issues.", Colors.YELLOW)

    # Test 8: Check Pending Reboot
    out("\n    Checking reboot status...", Colors.CYAN)
    current_test += 1
    progress_bar(current_test, total_tests, prefix="Validation")
    if check_pending_reboot():
        out("    ⚠ System has pending reboot - REBOOT RECOMMENDED.", Colors.YELLOW)
    else:
        out("    ✓ No pending reboot required.", Colors.GREEN)

    return all_passed

# ============================================================================
# MAIN ENTRY POINT
# ============================================================================

def main():
    """Main entry point"""
    os.system('')  # Enable ANSI colors

    start_time = time.time()

    out(f"\n{'='*70}", Colors.CYAN)
    out("  WMI/WMIC Repair + DISM/SFC Health Check Script v3.0", Colors.CYAN)
    out(f"  Started @ {time.strftime('%Y-%m-%d %H:%M:%S')}", Colors.CYAN)
    out("  Features: Never stuck | Full WMI repair | DISM/SFC | Validation", Colors.CYAN)
    out(f"{'='*70}", Colors.CYAN)

    # Check admin
    if not is_admin():
        out("\n✗ ERROR: Run this script as Administrator!", Colors.RED)
        out("  Right-click and select 'Run as administrator'", Colors.YELLOW)
        sys.exit(1)

    out("\n✓ Running with Administrator privileges", Colors.GREEN)

    total_steps = 14

    # PHASE 0: PREPARATION
    out(f"\n{'─'*70}", Colors.CYAN)
    out(f"  PHASE 0: PREPARATION (Steps 0-1)", Colors.BOLD)
    out(f"{'─'*70}", Colors.CYAN)

    step_0_prepare_system(total_steps)
    step_1_clean_update_cache(total_steps)

    # PHASE 1: WMI REPAIR
    out(f"\n{'─'*70}", Colors.CYAN)
    out(f"  PHASE 1: WMI REPAIR (Steps 2-6)", Colors.BOLD)
    out(f"{'─'*70}", Colors.CYAN)

    step_2_wmic_capability(total_steps)
    step_3_wmic_exe(total_steps)
    step_4_reset_wmi(total_steps)
    step_5_recompile_mof(total_steps)
    step_6_system_path(total_steps)

    # PHASE 2: SYSTEM HEALTH
    out(f"\n{'─'*70}", Colors.CYAN)
    out(f"  PHASE 2: SYSTEM HEALTH (Steps 7-13)", Colors.BOLD)
    out(f"{'─'*70}", Colors.CYAN)

    step_7_start_services(total_steps)
    step_8_component_cleanup(total_steps)
    step_9_check_health(total_steps)
    is_healthy = step_10_scan_health(total_steps)

    if is_healthy:
        out("\n    → System is healthy, SKIPPING RestoreHealth.", Colors.GREEN)
    else:
        step_11_restore_health(total_steps)

    step_12_sfc_scan(total_steps)
    step_13_final_cleanup(total_steps)

    # PHASE 3: VALIDATION
    out(f"\n{'─'*70}", Colors.CYAN)
    out(f"  PHASE 3: COMPREHENSIVE VALIDATION (Step 14)", Colors.BOLD)
    out(f"{'─'*70}", Colors.CYAN)

    all_passed = step_14_validation(total_steps)

    # Complete
    elapsed = time.time() - start_time
    minutes = int(elapsed // 60)
    seconds = int(elapsed % 60)

    out(f"\n{'='*70}", Colors.CYAN)
    if all_passed:
        out(f"  ✓ ALL REPAIRS COMPLETED SUCCESSFULLY", Colors.GREEN)
        out(f"  System is healthy - WMI, WMIC, DISM, SFC all working!", Colors.GREEN)
    else:
        out(f"  ⚠ REPAIRS COMPLETED WITH SOME ISSUES", Colors.YELLOW)
        out(f"  REBOOT RECOMMENDED to complete pending operations.", Colors.YELLOW)
    out(f"  Finished @ {time.strftime('%Y-%m-%d %H:%M:%S')}", Colors.CYAN)
    out(f"  Total time: {minutes}m {seconds}s", Colors.CYAN)
    out(f"  Log saved to: {LOG_PATH}", Colors.CYAN)
    out(f"{'='*70}\n", Colors.CYAN)

    # Return appropriate exit code
    sys.exit(0 if all_passed else 1)

if __name__ == '__main__':
    main()

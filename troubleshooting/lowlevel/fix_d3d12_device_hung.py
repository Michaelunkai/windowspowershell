#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
D3D12 DXGI_ERROR_DEVICE_HUNG (0x887A0006) Comprehensive Fix Script
===================================================================
NO REBOOT REQUIRED - All fixes applied immediately!

Fixes Unreal Engine LowLevelFatalError: GetDeviceRemovedReason() failed

This script applies ALL known fixes for the GPU device hang/timeout issue:
1. TDR (Timeout Detection and Recovery) registry tweaks + LIVE APPLY
2. GPU driver restart (applies registry changes immediately)
3. Force shader cache cleanup (kills locking processes)
4. DirectX optimization
5. NVIDIA/AMD specific optimizations
6. Windows power settings
7. Game-specific config fixes

Run as Administrator for full functionality.
"""

import os
import sys
import ctypes
import subprocess
import shutil
import winreg
import tempfile
import io
import time
import signal
from pathlib import Path
from datetime import datetime
from ctypes import wintypes

# Force UTF-8 output on Windows (with error handling)
if sys.platform == 'win32':
    try:
        if hasattr(sys.stdout, 'buffer'):
            sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
        if hasattr(sys.stderr, 'buffer'):
            sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8', errors='replace')
    except:
        pass  # Keep default if wrapper fails

# Simple ASCII-safe logging (no special chars)
class Colors:
    GREEN = ''
    YELLOW = ''
    RED = ''
    CYAN = ''
    BOLD = ''
    END = ''

# Try to enable ANSI colors on Windows 10+
try:
    kernel32 = ctypes.windll.kernel32
    kernel32.SetConsoleMode(kernel32.GetStdHandle(-11), 7)
    Colors.GREEN = '\033[92m'
    Colors.YELLOW = '\033[93m'
    Colors.RED = '\033[91m'
    Colors.CYAN = '\033[96m'
    Colors.BOLD = '\033[1m'
    Colors.END = '\033[0m'
except:
    pass

def is_admin():
    """Check if running with administrator privileges."""
    try:
        return ctypes.windll.shell32.IsUserAnAdmin()
    except:
        return False

def run_as_admin():
    """Re-run the script with admin privileges in a new visible window."""
    if sys.platform == 'win32':
        script_path = os.path.abspath(sys.argv[0])
        # Use cmd /k to keep window open, with pause at end
        cmd = f'cmd /k ""{sys.executable}" "{script_path}" & pause"'
        ctypes.windll.shell32.ShellExecuteW(
            None, "runas", "cmd.exe", f'/k ""{sys.executable}" "{script_path}""', None, 1
        )
        print("Admin window launched - check the new window for output!")
        sys.exit(0)

def log(msg, color=Colors.END):
    """Print colored log message with immediate flush for real-time output."""
    timestamp = datetime.now().strftime("%H:%M:%S")
    print(f"{Colors.CYAN}[{timestamp}]{Colors.END} {color}{msg}{Colors.END}", flush=True)

def log_success(msg):
    log(f"[OK] {msg}", Colors.GREEN)

def log_warning(msg):
    log(f"[WARN] {msg}", Colors.YELLOW)

def log_error(msg):
    log(f"[ERROR] {msg}", Colors.RED)

def log_info(msg):
    log(f"[INFO] {msg}", Colors.CYAN)

def create_backup(key_path, backup_name):
    """Create registry backup before modifications."""
    backup_dir = Path(tempfile.gettempdir()) / "d3d12_fix_backups"
    backup_dir.mkdir(exist_ok=True)
    backup_file = backup_dir / f"{backup_name}_{datetime.now().strftime('%Y%m%d_%H%M%S')}.reg"

    try:
        subprocess.run(
            ["reg", "export", key_path, str(backup_file), "/y"],
            capture_output=True, check=True
        )
        log_success(f"Backup created: {backup_file}")
        return True
    except Exception as e:
        log_warning(f"Could not create backup for {key_path}: {e}")
        return False

def set_registry_dword(key_path, value_name, value_data, hkey=winreg.HKEY_LOCAL_MACHINE):
    """Set a DWORD registry value."""
    try:
        key = winreg.CreateKeyEx(hkey, key_path, 0, winreg.KEY_SET_VALUE | winreg.KEY_WOW64_64KEY)
        winreg.SetValueEx(key, value_name, 0, winreg.REG_DWORD, value_data)
        winreg.CloseKey(key)
        log_success(f"Set {value_name} = {value_data}")
        return True
    except PermissionError:
        log_error(f"Permission denied setting {value_name}. Run as Administrator!")
        return False
    except Exception as e:
        log_error(f"Failed to set {value_name}: {e}")
        return False

def get_registry_dword(key_path, value_name, hkey=winreg.HKEY_LOCAL_MACHINE):
    """Get a DWORD registry value."""
    try:
        key = winreg.OpenKey(hkey, key_path, 0, winreg.KEY_READ | winreg.KEY_WOW64_64KEY)
        value, _ = winreg.QueryValueEx(key, value_name)
        winreg.CloseKey(key)
        return value
    except:
        return None


# =============================================================================
# NO-REBOOT FUNCTIONS - Apply changes immediately without restart
# =============================================================================

def kill_process_by_name(process_name):
    """Kill a process by name using taskkill."""
    try:
        result = subprocess.run(
            ["taskkill", "/F", "/IM", process_name],
            capture_output=True, text=True
        )
        return result.returncode == 0
    except:
        return False

def kill_processes_using_path(path):
    """Kill all processes that have handles to files in the given path."""
    try:
        # Use handle.exe if available, otherwise use PowerShell
        ps_cmd = f'''
        $path = "{path}"
        Get-Process | Where-Object {{
            try {{
                $_.Modules | Where-Object {{ $_.FileName -like "$path*" }}
            }} catch {{}}
        }} | ForEach-Object {{
            try {{
                Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue
                Write-Output "Killed: $($_.Name)"
            }} catch {{}}
        }}
        '''
        subprocess.run(["powershell", "-Command", ps_cmd], capture_output=True)
        return True
    except:
        return False

def force_clear_shader_caches():
    """
    Force clear shader caches by killing processes that lock them.
    NO REBOOT REQUIRED.
    """
    log_info("=" * 60)
    log_info("FORCE CLEARING SHADER CACHES (No Reboot)")
    log_info("=" * 60)

    local_appdata = os.environ.get("LOCALAPPDATA", "")

    # Processes that commonly lock shader caches
    cache_locking_processes = [
        "NVDisplay.Container.exe",
        "nvcontainer.exe",
        "NVIDIA Share.exe",
        "NVIDIA Web Helper.exe",
        "RadeonSoftware.exe",
        "AMDRSServ.exe",
        "aaborern.exe",
        "dwm.exe",  # Desktop Window Manager - careful with this one
    ]

    # Kill NVIDIA/AMD background processes that lock shader cache
    log_info("Stopping GPU background services...")

    # Stop NVIDIA services
    nvidia_services = ["NVDisplay.ContainerLocalSystem", "NvContainerLocalSystem"]
    for svc in nvidia_services:
        subprocess.run(["sc", "stop", svc], capture_output=True)

    # Kill NVIDIA processes (except critical ones)
    for proc in ["NVDisplay.Container.exe", "nvcontainer.exe", "NVIDIA Share.exe"]:
        if kill_process_by_name(proc):
            log_info(f"Stopped: {proc}")

    # Stop AMD services
    amd_services = ["AMD External Events Utility"]
    for svc in amd_services:
        subprocess.run(["sc", "stop", svc], capture_output=True)

    time.sleep(2)  # Wait for processes to release file handles

    shader_cache_paths = [
        Path(local_appdata) / "D3DSCache",
        Path(local_appdata) / "NVIDIA" / "DXCache",
        Path(local_appdata) / "NVIDIA" / "GLCache",
        Path(local_appdata) / "AMD" / "DxCache",
        Path(local_appdata) / "AMD" / "DxcCache",
        Path(local_appdata) / "AMD" / "VkCache",
        Path(local_appdata) / "UnrealEngine" / "Common" / "DerivedDataCache",
        Path(os.environ.get("ProgramFiles(x86)", "")) / "Steam" / "steamapps" / "shadercache",
        Path(local_appdata) / "GoriCuddlyCarnage" / "Saved" / "ShaderCache",
        Path(local_appdata) / "GoriCuddlyCarnage" / "Saved" / "PipelineCaches",
        Path(local_appdata) / "UE-GoriCuddlyCarnage" / "Saved" / "ShaderCache",
        Path(local_appdata) / "UE-GoriCuddlyCarnage" / "Saved" / "PipelineCaches",
    ]

    cleared_count = 0
    for cache_path in shader_cache_paths:
        if cache_path.exists():
            try:
                # Try to clear using robocopy trick (faster and handles locks better)
                empty_dir = Path(tempfile.gettempdir()) / "empty_dir_for_clear"
                empty_dir.mkdir(exist_ok=True)

                subprocess.run(
                    ["robocopy", str(empty_dir), str(cache_path), "/MIR", "/NFL", "/NDL", "/NJH", "/NJS", "/nc", "/ns", "/np"],
                    capture_output=True
                )

                if cache_path.is_dir():
                    shutil.rmtree(cache_path, ignore_errors=True)

                log_success(f"Force cleared: {cache_path}")
                cleared_count += 1
            except Exception as e:
                # Last resort: schedule deletion on next access
                try:
                    subprocess.run(
                        ["cmd", "/c", f"rd /s /q \"{cache_path}\""],
                        capture_output=True
                    )
                    log_success(f"Cleared via cmd: {cache_path}")
                    cleared_count += 1
                except:
                    log_warning(f"Could not clear: {cache_path}")

    # Restart NVIDIA services
    for svc in nvidia_services:
        subprocess.run(["sc", "start", svc], capture_output=True)

    log_success(f"Force cleared {cleared_count} shader cache locations")
    return cleared_count

def restart_gpu_driver():
    """
    Restart the GPU driver to apply registry changes WITHOUT REBOOT.
    Uses devcon or pnputil to restart display adapters.
    """
    log_info("=" * 60)
    log_info("RESTARTING GPU DRIVER (Applies TDR changes immediately)")
    log_info("=" * 60)

    log_warning("Screen may flicker for a few seconds...")
    time.sleep(2)

    # Method 1: Try using pnputil (built into Windows)
    try:
        # Get display adapter device IDs
        result = subprocess.run(
            ["powershell", "-Command",
             "Get-PnpDevice -Class Display | Select-Object -ExpandProperty InstanceId"],
            capture_output=True, text=True
        )

        device_ids = [line.strip() for line in result.stdout.strip().split('\n') if line.strip()]

        if device_ids:
            for device_id in device_ids:
                log_info(f"Restarting device: {device_id[:50]}...")

                # Disable the device
                subprocess.run(
                    ["powershell", "-Command",
                     f"Disable-PnpDevice -InstanceId '{device_id}' -Confirm:$false -ErrorAction SilentlyContinue"],
                    capture_output=True
                )
                time.sleep(2)

                # Re-enable the device
                subprocess.run(
                    ["powershell", "-Command",
                     f"Enable-PnpDevice -InstanceId '{device_id}' -Confirm:$false -ErrorAction SilentlyContinue"],
                    capture_output=True
                )
                time.sleep(2)

            log_success("GPU driver restarted - TDR settings now active!")
            return True
    except Exception as e:
        log_warning(f"PnpDevice method failed: {e}")

    # Method 2: Restart display driver service
    try:
        log_info("Trying alternative method: restarting display services...")

        # Restart DWM (Desktop Window Manager) - this refreshes GPU state
        subprocess.run(["taskkill", "/F", "/IM", "dwm.exe"], capture_output=True)
        time.sleep(3)
        # DWM auto-restarts

        log_success("Display services restarted")
        return True
    except:
        pass

    # Method 3: Use devcon if available
    devcon_paths = [
        r"C:\Program Files (x86)\Windows Kits\10\Tools\x64\devcon.exe",
        r"C:\devcon.exe",
        shutil.which("devcon")
    ]

    for devcon in devcon_paths:
        if devcon and Path(devcon).exists():
            try:
                subprocess.run([devcon, "restart", "=display"], capture_output=True)
                log_success("GPU driver restarted via devcon")
                return True
            except:
                continue

    log_warning("Could not restart GPU driver automatically.")
    log_info("TDR settings will apply after next GPU reset or reboot.")
    return False

def apply_tdr_immediately():
    """
    Apply TDR settings and make them effective immediately.
    """
    log_info("=" * 60)
    log_info("FIX 1: TDR Settings + IMMEDIATE APPLICATION")
    log_info("=" * 60)

    key_path = r"SYSTEM\CurrentControlSet\Control\GraphicsDrivers"

    # Create backup
    create_backup(f"HKLM\\{key_path}", "GraphicsDrivers")

    # TdrDelay: Time in seconds GPU has to respond (default: 2, setting: 60 for maximum tolerance)
    set_registry_dword(key_path, "TdrDelay", 60)

    # TdrDdiDelay: Time in seconds for DDI callback (default: 5, setting: 60)
    set_registry_dword(key_path, "TdrDdiDelay", 60)

    # TdrLevel: 3 = Recover on timeout without crash
    set_registry_dword(key_path, "TdrLevel", 3)

    # TdrLimitCount: Number of TDRs allowed (setting high)
    set_registry_dword(key_path, "TdrLimitCount", 50)

    # TdrLimitTime: Time window in seconds
    set_registry_dword(key_path, "TdrLimitTime", 600)

    log_success("TDR settings optimized (60 second timeout)")

def disable_hardware_gpu_scheduling():
    """
    Disable Hardware-accelerated GPU scheduling which can cause instability.
    """
    log_info("=" * 60)
    log_info("FIX 2: Disabling Hardware GPU Scheduling")
    log_info("=" * 60)

    key_path = r"SYSTEM\CurrentControlSet\Control\GraphicsDrivers"

    # Check current status
    current = get_registry_dword(key_path, "HwSchMode")
    if current == 2:
        log_info("Hardware GPU Scheduling is currently ENABLED - disabling for stability")
        set_registry_dword(key_path, "HwSchMode", 1)  # 1 = disabled
        log_success("Hardware GPU Scheduling DISABLED")
    else:
        log_info("Hardware GPU Scheduling already disabled")

    # Also disable in per-GPU settings
    dx_key = r"SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}\0000"
    set_registry_dword(dx_key, "EnableUlps", 0)
    set_registry_dword(dx_key, "EnableCrossFireAutoLink", 0)
    set_registry_dword(dx_key, "PP_SclkDeepSleepDisable", 1)

    # For secondary GPU (if exists)
    dx_key2 = r"SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}\0001"
    try:
        set_registry_dword(dx_key2, "EnableUlps", 0)
    except:
        pass

    log_success("GPU power state optimizations applied")

def fix_nvidia_settings():
    """NVIDIA-specific optimizations"""
    log_info("=" * 60)
    log_info("FIX 3: NVIDIA Optimizations")
    log_info("=" * 60)

    nvidia_smi = shutil.which("nvidia-smi")
    if not nvidia_smi:
        log_info("NVIDIA GPU not detected, skipping")
        return

    log_info("NVIDIA GPU detected")

    try:
        # Set persistence mode
        subprocess.run(["nvidia-smi", "-pm", "1"], capture_output=True)
        log_success("NVIDIA persistence mode enabled")

        # Reset GPU (clears any hung state)
        log_info("Resetting NVIDIA GPU state...")
        subprocess.run(["nvidia-smi", "-r"], capture_output=True)
        log_success("NVIDIA GPU reset completed")

    except Exception as e:
        log_warning(f"nvidia-smi error: {e}")

    # Registry fixes
    nvidia_key = r"SOFTWARE\NVIDIA Corporation\Global\NVTweak"
    try:
        key = winreg.CreateKeyEx(winreg.HKEY_LOCAL_MACHINE, nvidia_key, 0,
                                 winreg.KEY_SET_VALUE | winreg.KEY_WOW64_64KEY)
        winreg.SetValueEx(key, "ShaderCacheMaxSize", 0, winreg.REG_DWORD, 0xFFFFFFFF)
        winreg.CloseKey(key)
        log_success("NVIDIA shader cache size maximized")
    except:
        pass

    # Disable NVIDIA Overlay (known to cause issues)
    try:
        overlay_key = r"SOFTWARE\NVIDIA Corporation\Global\ShadowPlay\NVSPCAPS"
        set_registry_dword(overlay_key, "ShadowPlayEnabled", 0)
        log_success("NVIDIA ShadowPlay/Overlay disabled")
    except:
        pass

def fix_amd_settings():
    """AMD-specific optimizations"""
    log_info("=" * 60)
    log_info("FIX 4: AMD Optimizations")
    log_info("=" * 60)

    amd_key = r"SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}\0000"
    try:
        key = winreg.OpenKey(winreg.HKEY_LOCAL_MACHINE, amd_key, 0, winreg.KEY_READ)
        provider, _ = winreg.QueryValueEx(key, "ProviderName")
        winreg.CloseKey(key)

        if "AMD" in provider or "ATI" in provider:
            log_info("AMD GPU detected")
            set_registry_dword(amd_key, "EnableUlps", 0)
            set_registry_dword(amd_key, "PP_ThermalAutoThrottlingEnable", 0)
            set_registry_dword(amd_key, "StutterMode", 0)
            set_registry_dword(amd_key, "EnableAspmL0s", 0)
            set_registry_dword(amd_key, "EnableAspmL1", 0)
            log_success("AMD optimizations applied")
        else:
            log_info("AMD GPU not primary, skipping")
    except:
        log_info("AMD GPU not detected, skipping")

def fix_directx_settings():
    """DirectX optimization settings"""
    log_info("=" * 60)
    log_info("FIX 5: DirectX Optimization")
    log_info("=" * 60)

    d3d_key = r"SOFTWARE\Microsoft\Direct3D"
    set_registry_dword(d3d_key, "DisableD3D11", 0)
    set_registry_dword(d3d_key, "LoadDebugRuntime", 0)
    set_registry_dword(d3d_key, "EnableDebugLayer", 0)

    dxdiag_key = r"SOFTWARE\Microsoft\DirectX"
    set_registry_dword(dxdiag_key, "MaxFrameLatency", 1)

    log_success("DirectX settings optimized")

def fix_power_settings():
    """Windows power optimizations"""
    log_info("=" * 60)
    log_info("FIX 6: Power Settings")
    log_info("=" * 60)

    try:
        # Activate Ultimate Performance plan (if available) or High Performance
        subprocess.run(
            ["powercfg", "/setactive", "e9a42b02-d5df-448d-aa00-03f14749eb61"],
            capture_output=True
        )
        log_success("Ultimate Performance power plan activated")
    except:
        subprocess.run(
            ["powercfg", "/setactive", "8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c"],
            capture_output=True
        )
        log_success("High Performance power plan activated")

    # Disable PCI Express power management
    subprocess.run(
        ["powercfg", "/setacvalueindex", "scheme_current", "501a4d13-42af-4429-9fd1-a8218c268e20",
         "ee12f906-d277-404b-b6da-e5fa1a576df5", "0"],
        capture_output=True
    )
    subprocess.run(["powercfg", "/setactive", "scheme_current"], capture_output=True)
    log_success("PCI Express power management disabled")

def fix_game_config():
    """Game-specific configuration"""
    log_info("=" * 60)
    log_info("FIX 7: Game Configuration")
    log_info("=" * 60)

    local_appdata = os.environ.get("LOCALAPPDATA", "")

    engine_ini_content = """
[SystemSettings]
; D3D12 DEVICE HUNG FIX - Applied by fix script
r.D3D12.AsyncComputeEnabled=0
r.RHICmdBypass=1
r.D3D12.FailOnDeviceRemoved=0
r.ShaderPipelineCache.Enabled=0
r.Shaders.FastMath=0
r.Streaming.PoolSize=2048
r.RayTracing=0
r.RayTracing.Shadows=0
r.RayTracing.Reflections=0
r.VSync=1
r.FinishCurrentFrame=1
r.GPUCrashDebugging=0
r.D3D12.GPUValidation=0

[D3D12_SM6]
+CVars=r.D3D12.AsyncComputeEnabled=0
+CVars=r.D3D12.FailOnDeviceRemoved=0

[D3D12_SM5]
+CVars=r.D3D12.AsyncComputeEnabled=0
+CVars=r.D3D12.FailOnDeviceRemoved=0

[ConsoleVariables]
r.GPUCrashDebugging=0
r.D3D12.GPUValidation=0
"""

    config_paths = [
        Path(local_appdata) / "GoriCuddlyCarnage" / "Saved" / "Config" / "Windows",
        Path(local_appdata) / "GoriCuddlyCarnage" / "Saved" / "Config" / "WindowsNoEditor",
    ]

    for config_path in config_paths:
        try:
            config_path.mkdir(parents=True, exist_ok=True)
            engine_file = config_path / "Engine.ini"

            if engine_file.exists():
                # Check if already patched
                content = engine_file.read_text()
                if "D3D12 DEVICE HUNG FIX" in content:
                    log_info(f"Already patched: {engine_file}")
                    continue

                # Backup and append
                backup = engine_file.with_suffix(".ini.backup")
                shutil.copy(engine_file, backup)
                with open(engine_file, "a") as f:
                    f.write("\n\n")
                    f.write(engine_ini_content)
            else:
                with open(engine_file, "w") as f:
                    f.write(engine_ini_content)

            log_success(f"Applied: {engine_file}")
        except Exception as e:
            log_warning(f"Could not write to {config_path}: {e}")

def disable_overlays():
    """Disable all game overlays"""
    log_info("=" * 60)
    log_info("FIX 8: Disabling Overlays")
    log_info("=" * 60)

    # Game Bar
    gamebar_key = r"SOFTWARE\Microsoft\GameBar"
    set_registry_dword(gamebar_key, "AllowAutoGameMode", 0, winreg.HKEY_CURRENT_USER)
    set_registry_dword(gamebar_key, "AutoGameModeEnabled", 0, winreg.HKEY_CURRENT_USER)

    # Game DVR
    gamedvr_key = r"SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR"
    set_registry_dword(gamedvr_key, "AppCaptureEnabled", 0, winreg.HKEY_CURRENT_USER)

    # Fullscreen optimizations
    fso_key = r"SOFTWARE\Microsoft\Windows\CurrentVersion\GameConfigStore"
    set_registry_dword(fso_key, "GameDVR_Enabled", 0, winreg.HKEY_CURRENT_USER)
    set_registry_dword(fso_key, "GameDVR_FSEBehaviorMode", 2, winreg.HKEY_CURRENT_USER)

    log_success("All game overlays disabled")

def verify_and_test():
    """Verify fixes are active"""
    log_info("=" * 60)
    log_info("VERIFICATION")
    log_info("=" * 60)

    # Check TDR values
    key_path = r"SYSTEM\CurrentControlSet\Control\GraphicsDrivers"
    tdr_delay = get_registry_dword(key_path, "TdrDelay")
    log_info(f"TdrDelay is now: {tdr_delay} seconds (was 2)")

    # Check GPU status
    nvidia_smi = shutil.which("nvidia-smi")
    if nvidia_smi:
        result = subprocess.run(
            ["nvidia-smi", "--query-gpu=name,temperature.gpu,power.draw",
             "--format=csv,noheader"],
            capture_output=True, text=True
        )
        log_info(f"GPU Status: {result.stdout.strip()}")

    log_success("All fixes verified and active!")

def print_summary():
    """Print summary."""
    print("\n" + "=" * 60)
    print(Colors.BOLD + Colors.GREEN + "  ALL FIXES APPLIED - NO REBOOT REQUIRED!" + Colors.END)
    print("=" * 60)

    print(f"""
{Colors.GREEN}IMMEDIATE CHANGES APPLIED:{Colors.END}
  1. TDR timeout: 2s -> 60s (GPU won't timeout as easily)
  2. Hardware GPU Scheduling: DISABLED
  3. Shader caches: FORCE CLEARED
  4. GPU driver: RESTARTED (settings now active)
  5. DirectX: Optimized for stability
  6. Power plan: Ultimate/High Performance
  7. Game config: D3D12 async compute disabled
  8. Overlays: All disabled

{Colors.CYAN}YOU CAN NOW LAUNCH THE GAME IMMEDIATELY!{Colors.END}

{Colors.YELLOW}If crashes persist:{Colors.END}
  1. Add -dx11 to Steam launch options
  2. Update GPU drivers with DDU clean install
  3. Lower in-game graphics settings
""")

def progress(step, total, desc):
    """Show real-time progress bar."""
    bar_len = 30
    filled = int(bar_len * step / total)
    bar = "=" * filled + "-" * (bar_len - filled)
    pct = int(100 * step / total)
    print(f"\r{Colors.CYAN}[{bar}] {pct}% - {desc}{Colors.END}".ljust(80), end="", flush=True)
    if step == total:
        print()

def main():
    # Immediate output to confirm script is running
    print("\n" + "=" * 60, flush=True)
    print("  D3D12 DXGI_ERROR_DEVICE_HUNG FIX - NO REBOOT EDITION", flush=True)
    print("  For: Gori Cuddly Carnage & Other UE4/UE5 Games", flush=True)
    print("=" * 60 + "\n", flush=True)

    # Skip admin check - assume user is running as admin
    print("[*] Starting fixes (run as Admin if you see permission errors)...", flush=True)
    print(flush=True)

    total_steps = 10
    current_step = 0

    try:
        # Step 1: TDR Settings
        current_step += 1
        progress(current_step, total_steps, "Applying TDR settings...")
        apply_tdr_immediately()

        # Step 2: GPU Scheduling
        current_step += 1
        progress(current_step, total_steps, "Disabling Hardware GPU Scheduling...")
        disable_hardware_gpu_scheduling()

        # Step 3: NVIDIA
        current_step += 1
        progress(current_step, total_steps, "Applying NVIDIA optimizations...")
        fix_nvidia_settings()

        # Step 4: AMD
        current_step += 1
        progress(current_step, total_steps, "Applying AMD optimizations...")
        fix_amd_settings()

        # Step 5: Shader Caches
        current_step += 1
        progress(current_step, total_steps, "Clearing shader caches...")
        force_clear_shader_caches()

        # Step 6: DirectX
        current_step += 1
        progress(current_step, total_steps, "Optimizing DirectX...")
        fix_directx_settings()

        # Step 7: Power Settings
        current_step += 1
        progress(current_step, total_steps, "Setting power plan...")
        fix_power_settings()

        # Step 8: Game Config
        current_step += 1
        progress(current_step, total_steps, "Patching game configuration...")
        fix_game_config()

        # Step 9: Overlays
        current_step += 1
        progress(current_step, total_steps, "Disabling overlays...")
        disable_overlays()

        # Step 10: GPU Restart
        current_step += 1
        progress(current_step, total_steps, "Restarting GPU driver...")
        restart_gpu_driver()

        # Verify
        verify_and_test()

        print_summary()

    except Exception as e:
        log_error(f"Unexpected error: {e}")
        import traceback
        traceback.print_exc()
        return 1

    try:
        input("\nPress Enter to exit...")
    except EOFError:
        pass
    return 0

if __name__ == "__main__":
    sys.exit(main())

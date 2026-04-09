import os
import subprocess
import time
import sys
import shutil
import ctypes

def is_admin():
    """Check if running as administrator"""
    try:
        return ctypes.windll.shell32.IsUserAnAdmin()
    except:
        return False

def run_cmd(cmd, timeout=10, silent=True):
    """Run command with timeout"""
    try:
        result = subprocess.run(
            cmd, shell=True, capture_output=True, timeout=timeout, text=True
        )
        if not silent and result.stdout:
            print(result.stdout.strip())
        return result.returncode == 0, result.stdout, result.stderr
    except subprocess.TimeoutExpired:
        return False, "", "Timeout"
    except Exception as e:
        return False, "", str(e)

def run_ps(cmd, timeout=30):
    """Run PowerShell command"""
    full_cmd = f'powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "{cmd}"'
    return run_cmd(full_cmd, timeout=timeout)

def nuclear_shutdown():
    """Kill ALL Docker and Hyper-V processes/services"""
    print("[1/6] NUCLEAR SHUTDOWN - Killing all Docker/Hyper-V processes...")

    # Kill processes
    processes = [
        "Docker Desktop.exe", "com.docker.backend.exe", "com.docker.service.exe",
        "com.docker.proxy.exe", "com.docker.dev.exe", "docker.exe", "dockerd.exe",
        "vpnkit.exe", "com.docker.vpnkit.exe", "vmmem", "vmwp.exe", "vmcompute.exe",
        "wslhost.exe", "wsl.exe"
    ]
    for proc in processes:
        run_cmd(f'taskkill /F /IM "{proc}" 2>nul', timeout=2)

    print("    Stopping services...")
    # Stop services
    services = ['com.docker.service', 'vmcompute', 'vmms', 'HvHost', 'WslService']
    for svc in services:
        run_cmd(f'net stop "{svc}" /y 2>nul', timeout=5)

    time.sleep(2)
    print("    [OK] Shutdown complete")

def cleanup_hyperv_vms():
    """Remove corrupted Hyper-V Docker VMs"""
    print("\n[2/6] CLEANING HYPER-V VMs...")

    # Remove Docker Desktop VM via PowerShell Hyper-V cmdlets
    ps_cleanup = '''
$ErrorActionPreference = 'SilentlyContinue'
# Get and remove any Docker-related VMs
$vms = Get-VM | Where-Object { $_.Name -like '*docker*' -or $_.Name -like '*DockerDesktop*' }
foreach ($vm in $vms) {
    Write-Host "    Removing VM: $($vm.Name)"
    Stop-VM -Name $vm.Name -Force -TurnOff -ErrorAction SilentlyContinue
    Remove-VM -Name $vm.Name -Force -ErrorAction SilentlyContinue
}
# Also clean up any orphaned VM configs
$vmPath = "$env:ProgramData\\Microsoft\\Windows\\Hyper-V\\Virtual Machines"
if (Test-Path $vmPath) {
    Get-ChildItem $vmPath -Filter "*.vmcx" -ErrorAction SilentlyContinue | ForEach-Object {
        try {
            $vmConfig = [xml](Get-Content $_.FullName -ErrorAction SilentlyContinue)
            if ($vmConfig -and $vmConfig.configuration.properties.name -like '*docker*') {
                Remove-Item $_.FullName -Force -ErrorAction SilentlyContinue
                Write-Host "    Removed orphan config: $($_.Name)"
            }
        } catch {}
    }
}
Write-Host "    [OK] Hyper-V cleanup done"
'''
    run_ps(ps_cleanup, timeout=30)
    print("    [OK] Hyper-V VMs cleaned")

def cleanup_wsl():
    """Reset WSL2 for Docker"""
    print("\n[3/6] RESETTING WSL2...")

    # Shutdown WSL completely
    run_cmd('wsl --shutdown', timeout=10)
    time.sleep(2)

    # Unregister docker-desktop distros if they exist
    success, stdout, _ = run_cmd('wsl -l -q', timeout=5)
    if success and stdout:
        distros = stdout.strip().replace('\x00', '').split('\n')
        for distro in distros:
            distro = distro.strip()
            if 'docker' in distro.lower():
                print(f"    Unregistering: {distro}")
                run_cmd(f'wsl --unregister "{distro}"', timeout=15)

    print("    [OK] WSL2 reset complete")

def cleanup_docker_data():
    """Remove Docker data files that cause issues"""
    print("\n[4/6] CLEANING DOCKER DATA...")

    paths_to_clean = [
        os.path.expandvars(r"%ProgramData%\DockerDesktop\vm-data"),
        os.path.expandvars(r"%LOCALAPPDATA%\Docker\wsl"),
        os.path.expandvars(r"%USERPROFILE%\.docker\desktop\vm"),
    ]

    for path in paths_to_clean:
        if os.path.exists(path):
            print(f"    Cleaning: {path}")
            try:
                # Take ownership first
                run_cmd(f'takeown /F "{path}" /R /A /D Y 2>nul', timeout=10)
                run_cmd(f'icacls "{path}" /grant administrators:F /T 2>nul', timeout=10)
                shutil.rmtree(path, ignore_errors=True)
                print(f"    [OK] Removed")
            except Exception as e:
                print(f"    [WARN] Could not fully clean: {e}")

    # Also clean the specific VHDX
    vhdx_files = [
        os.path.expandvars(r"%ProgramData%\DockerDesktop\vm-data\DockerDesktop.vhdx"),
        os.path.expandvars(r"%LOCALAPPDATA%\Docker\wsl\data\ext4.vhdx"),
        os.path.expandvars(r"%LOCALAPPDATA%\Docker\wsl\distro\ext4.vhdx"),
    ]

    for vhdx in vhdx_files:
        if os.path.exists(vhdx):
            size_gb = os.path.getsize(vhdx) / (1024**3)
            print(f"    Deleting VHDX: {vhdx} ({size_gb:.2f} GB)")
            try:
                os.remove(vhdx)
                print(f"    [OK] Deleted - Reclaimed {size_gb:.2f} GB")
            except:
                run_ps(f"Remove-Item '{vhdx}' -Force", timeout=10)

    print("    [OK] Docker data cleaned")

def reset_docker_settings():
    """Reset Docker Desktop settings to fix config issues"""
    print("\n[5/6] RESETTING DOCKER SETTINGS...")

    settings_path = os.path.expandvars(r"%APPDATA%\Docker\settings.json")

    # Create fresh minimal settings
    fresh_settings = '''{
  "acceptCanaryUpdates": false,
  "analyticsEnabled": false,
  "autoStart": true,
  "backendType": "wsl-2",
  "cpus": 4,
  "crashReportingEnabled": false,
  "credentialHelper": "docker-credential-wincred.exe",
  "disableHardwareAcceleration": false,
  "disableTips": true,
  "disableUpdate": false,
  "diskFlush": false,
  "displayRestartDialog": false,
  "displaySwitchVersionPack": false,
  "displaySwitchWinLinContainers": false,
  "displayedWelcomeMessage": true,
  "enableIntegrationWithDefaultWslDistro": true,
  "exposeDockerAPIOnTCP2375": false,
  "kubernetesEnabled": false,
  "licenseTermsVersion": 2,
  "memoryMiB": 4096,
  "networkType": "nat",
  "onlyMarketplaceExtensions": false,
  "openUIOnStartupDisabled": true,
  "runWinServiceInWslMode": false,
  "skipUpdateToWSLPrompt": true,
  "skipWSLMountPerfWarning": true,
  "swapMiB": 1024,
  "tipLastId": 999,
  "useCredentialHelper": true,
  "useNightlyBuildUpdates": false,
  "useResourceSaver": true,
  "useVirtualizationFramework": false,
  "useVirtualizationFrameworkRosetta": false,
  "useVirtualizationFrameworkVirtioFS": false,
  "useWindowsContainers": false,
  "wslEngineEnabled": true
}'''

    # Backup old settings if exists
    if os.path.exists(settings_path):
        backup_path = settings_path + ".backup"
        try:
            shutil.copy2(settings_path, backup_path)
            print(f"    Backed up old settings")
        except:
            pass

    # Write new settings
    os.makedirs(os.path.dirname(settings_path), exist_ok=True)
    with open(settings_path, 'w') as f:
        f.write(fresh_settings)
    print("    [OK] Fresh settings written")

def start_docker():
    """Start Docker Desktop and wait for it to be ready"""
    print("\n[6/6] STARTING DOCKER DESKTOP...")

    # Ensure Hyper-V compute service is running
    print("    Starting Hyper-V services...")
    run_cmd('net start vmcompute', timeout=15)
    time.sleep(2)

    # Start Docker Desktop
    docker_exe = r"C:\Program Files\Docker\Docker\Docker Desktop.exe"
    if not os.path.exists(docker_exe):
        print(f"    [ERROR] Docker Desktop not found at: {docker_exe}")
        return False

    print("    Launching Docker Desktop...")
    subprocess.Popen(
        f'"{docker_exe}"',
        shell=True,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL
    )

    # Wait for Docker to be ready
    print("    Waiting for Docker daemon (this may take 60-90 seconds)...")
    max_wait = 120  # 2 minutes max
    check_interval = 5

    for i in range(max_wait // check_interval):
        time.sleep(check_interval)
        elapsed = (i + 1) * check_interval

        # Check if docker is responding
        success, stdout, _ = run_cmd('docker info', timeout=10, silent=True)
        if success:
            print(f"\n    [SUCCESS] Docker is operational! (took {elapsed}s)")
            return True

        # Show progress
        print(f"    Waiting... {elapsed}s / {max_wait}s", end='\r')

    print(f"\n    [WARN] Docker may still be starting. Try 'docker info' manually.")
    return False

def main():
    print("=" * 60)
    print("  DOCKER DESKTOP NUCLEAR RESET & FIX")
    print("  Fixes: Hyper-V VM creation errors, WSL issues")
    print("=" * 60)

    # Check admin
    if not is_admin():
        print("\n[ERROR] This script requires Administrator privileges!")
        print("Right-click and 'Run as administrator'")
        input("\nPress Enter to exit...")
        sys.exit(1)

    start_time = time.time()

    # Execute all steps
    nuclear_shutdown()
    cleanup_hyperv_vms()
    cleanup_wsl()
    cleanup_docker_data()
    reset_docker_settings()
    success = start_docker()

    elapsed = time.time() - start_time

    print("\n" + "=" * 60)
    if success:
        print(f"  [COMPLETE] Docker Desktop fixed in {elapsed:.0f} seconds!")
        print("  Docker is running and ready to use.")
    else:
        print(f"  [PARTIAL] Reset complete in {elapsed:.0f} seconds")
        print("  Docker may need more time to initialize.")
        print("  Run 'docker info' to check status.")
    print("=" * 60)

    # Quick verification
    if success:
        print("\nQuick test - running 'docker ps':")
        run_cmd('docker ps', timeout=10, silent=False)

if __name__ == "__main__":
    if sys.platform != 'win32':
        print("[ERROR] This script only works on Windows!")
        sys.exit(1)
    main()

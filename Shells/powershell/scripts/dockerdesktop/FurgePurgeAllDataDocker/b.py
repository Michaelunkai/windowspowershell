import os
import subprocess
import time
import sys

def run_cmd(cmd):
    result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    print(result.stdout)
    return result.returncode

def main():
    vhdx_path = r"C:\ProgramData\DockerDesktop\vm-data\DockerDesktop.vhdx"
    
    if not os.path.exists(vhdx_path):
        print("VHDX file not found!")
        return
    
    print(f"Original size: {os.path.getsize(vhdx_path) / (1024**3):.2f} GB")
    
    print("\n[1/5] Killing all Docker processes...")
    run_cmd('taskkill /F /IM "Docker Desktop.exe" 2>nul')
    run_cmd('taskkill /F /IM "com.docker.backend.exe" 2>nul')
    run_cmd('taskkill /F /IM "com.docker.service.exe" 2>nul')
    run_cmd('taskkill /F /IM "docker.exe" 2>nul')
    run_cmd('taskkill /F /IM "dockerd.exe" 2>nul')
    run_cmd('taskkill /F /IM "vpnkit.exe" 2>nul')
    
    print("\n[2/5] Stopping services...")
    run_cmd('net stop com.docker.service')
    run_cmd('net stop vmcompute')
    
    time.sleep(10)
    
    print("\n[3/5] Deleting VHDX file...")
    try:
        os.remove(vhdx_path)
        print(f"DELETED: {vhdx_path}")
    except Exception as e:
        print(f"ERROR: {e}")
        return
    
    print("\n[4/5] Restarting services...")
    run_cmd('net start vmcompute')
    run_cmd('net start com.docker.service')
    
    print("\n[5/5] Starting Docker Desktop...")
    subprocess.Popen([r"C:\Program Files\Docker\Docker\Docker Desktop.exe"])
    
    print("\nDone! Docker Desktop is starting with a fresh VHDX.")

if __name__ == "__main__":
    if not sys.platform.startswith('win'):
        print("This script only works on Windows!")
        sys.exit(1)
    main()

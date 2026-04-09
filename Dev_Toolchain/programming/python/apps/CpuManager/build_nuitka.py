#!/usr/bin/env python3
"""Build CPU Monitor with Nuitka for better compatibility"""

import subprocess
import sys
import os

def build_with_nuitka():
    """Build CPU Monitor using Nuitka"""
    
    print("Building CPU Monitor with Nuitka...")
    
    cmd = [
        "python", "-m", "nuitka",
        "--onefile",
        "--windows-disable-console",
        "--include-data-files=cpu_limits.json=cpu_limits.json",
        "--plugin-enable=tk-inter",
        "--output-filename=CpuMonitorPro.exe",
        "--windows-icon-from-ico=icon.ico" if os.path.exists("icon.ico") else "",
        "cpu_monitor.py"
    ]
    
    # Remove empty icon argument if no icon exists
    cmd = [arg for arg in cmd if arg]
    
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, cwd=os.getcwd())
        
        if result.returncode == 0:
            print("✓ Build successful!")
            print("EXE location: CpuMonitorPro.exe")
        else:
            print(f"✗ Build failed with return code {result.returncode}")
            print("STDOUT:", result.stdout)
            print("STDERR:", result.stderr)
            
    except Exception as e:
        print(f"Failed to run Nuitka: {e}")

def build_console_version():
    """Build console version for debugging"""
    
    print("Building console version for debugging...")
    
    cmd = [
        "python", "-m", "nuitka",
        "--onefile",
        "--include-data-files=cpu_limits.json=cpu_limits.json",
        "--plugin-enable=tk-inter",
        "--output-filename=CpuMonitorPro_Console.exe",
        "cpu_monitor.py"
    ]
    
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, cwd=os.getcwd())
        
        if result.returncode == 0:
            print("✓ Console build successful!")
            print("EXE location: CpuMonitorPro_Console.exe")
        else:
            print(f"✗ Console build failed with return code {result.returncode}")
            print("STDOUT:", result.stdout)
            print("STDERR:", result.stderr)
            
    except Exception as e:
        print(f"Failed to run Nuitka: {e}")

if __name__ == "__main__":
    print("Choose build type:")
    print("1. Console version (for debugging)")
    print("2. Window version (final)")
    print("3. Both")
    
    choice = input("Enter choice (1/2/3): ").strip()
    
    if choice == "1":
        build_console_version()
    elif choice == "2":
        build_with_nuitka()
    elif choice == "3":
        build_console_version()
        print()
        build_with_nuitka()
    else:
        print("Invalid choice, building console version...")
        build_console_version()
#!/usr/bin/env python3
"""Simple PyInstaller build script"""

import subprocess
import sys
import os

def build_with_pyinstaller():
    """Build CPU Monitor using PyInstaller with debugging enabled"""
    
    print("Building CPU Monitor with PyInstaller...")
    
    cmd = [
        "pyinstaller",
        "--onefile",
        "--windowed",
        "--name=CpuMonitorPro",
        "--add-data=cpu_limits.json;.",
        "--hidden-import=tkinter",
        "--hidden-import=psutil",
        "--hidden-import=ctypes",
        "--debug=all",
        "--log-level=DEBUG",
        "cpu_monitor.py"
    ]
    
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, cwd=os.getcwd())
        
        if result.returncode == 0:
            print("✓ Build successful!")
            print("EXE location: dist/CpuMonitorPro.exe")
        else:
            print(f"✗ Build failed with return code {result.returncode}")
            print("STDOUT:", result.stdout)
            print("STDERR:", result.stderr)
            
    except Exception as e:
        print(f"Failed to run PyInstaller: {e}")

if __name__ == "__main__":
    build_with_pyinstaller()
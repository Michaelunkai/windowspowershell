import sys
from cx_Freeze import setup, Executable

build_exe_options = {
    "packages": [
        "tkinter",
        "psutil",
        "ctypes",
        "json",
        "subprocess",
        "threading",
        "datetime",
        "collections",
    ],
    "excludes": ["unittest", "pydoc", "doctest"],
    "include_files": ["cpu_limits.json"],
}

# Use None for console mode to see errors
setup(
    name="CPU Monitor Pro",
    version="2.0",
    description="CPU Monitor Pro",
    options={"build_exe": build_exe_options},
    executables=[
        Executable(
            "cpu_monitor.py",
            base=None,  # Console mode to see errors
            target_name="CpuMonitorPro.exe",
        )
    ],
)

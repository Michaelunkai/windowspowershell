import sys
from cx_Freeze import setup, Executable

# Dependencies
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
    "excludes": ["unittest", "email", "html", "http", "xml", "pydoc", "doctest"],
    "include_files": ["cpu_limits.json"],
    "optimize": 2,
}

base = "Win32GUI" if sys.platform == "win32" else None

setup(
    name="CPU Monitor Pro",
    version="2.0",
    description="CPU Monitor Pro - Real-time Process CPU Manager for AMD Ryzen 9800X3D",
    options={"build_exe": build_exe_options},
    executables=[
        Executable(
            "cpu_monitor.py",
            base=base,
            target_name="CpuMonitorPro.exe",
            icon=None,
        )
    ],
)

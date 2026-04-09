import sys
from cx_Freeze import setup, Executable

build_exe_options = {
    "packages": ["tkinter"],
    "excludes": ["unittest", "pydoc", "doctest"],
}

setup(
    name="GUI Test",
    version="1.0",
    description="GUI Test",
    options={"build_exe": build_exe_options},
    executables=[
        Executable(
            "test_gui.py",
            base=None,  # Console mode to see errors
            target_name="TestGUI.exe",
        )
    ],
)
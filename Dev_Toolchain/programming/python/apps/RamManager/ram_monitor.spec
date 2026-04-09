# -*- mode: python ; coding: utf-8 -*-
import sys
import os
from PyInstaller.utils.hooks import collect_all, collect_submodules, collect_dynamic_libs

block_cipher = None

# Collect all psutil data and binaries
psutil_datas, psutil_binaries, psutil_hiddenimports = collect_all('psutil')

# Collect VC runtime DLLs
binaries = list(psutil_binaries)

a = Analysis(
    ['ram_monitor.py'],
    pathex=[],
    binaries=binaries,
    datas=psutil_datas,
    hiddenimports=[
        'psutil',
        'psutil._pswindows',
        'tkinter',
        'tkinter.ttk',
        'tkinter.messagebox',
        'ctypes',
        'ctypes.wintypes',
        'json',
        'subprocess',
        're',
        'threading',
        'datetime',
        'logging',
    ] + psutil_hiddenimports,
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=[],
    win_no_prefer_redirects=False,
    win_private_assemblies=False,
    cipher=block_cipher,
    noarchive=False,
)

pyz = PYZ(a.pure, a.zipped_data, cipher=block_cipher)

# Use COLLECT for onedir mode - more reliable than onefile
exe = EXE(
    pyz,
    a.scripts,
    [],
    exclude_binaries=True,
    name='RAM Monitor Pro',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=False,
    console=False,
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
    icon='ram_monitor.ico' if os.path.exists('ram_monitor.ico') else None,
    uac_admin=True,
)

coll = COLLECT(
    exe,
    a.binaries,
    a.zipfiles,
    a.datas,
    strip=False,
    upx=False,
    upx_exclude=[],
    name='RAM Monitor Pro',
)

"""
Windows 11 Voice Typing Enabler (Win+H) - FULLY AUTOMATIC
==========================================================
Run on a fresh Windows 11 machine to enable voice typing.
No user interaction required - everything runs automatically.

Usage: python mic.py (as Administrator)
"""

import subprocess
import os
import sys
import time
import urllib.request
import zipfile
import ctypes
from pathlib import Path


def is_admin():
    try:
        return ctypes.windll.shell32.IsUserAnAdmin()
    except:
        return False


def run_as_admin():
    if not is_admin():
        print("[!] Elevating to Administrator...")
        ctypes.windll.shell32.ShellExecuteW(
            None, "runas", sys.executable, f'"{__file__}"', None, 1
        )
        sys.exit(0)


def run_cmd(cmd):
    try:
        result = subprocess.run(cmd, shell=True, capture_output=True, timeout=120, text=True)
        if result.returncode != 0 and result.stderr:
            print(f"      Warning: {result.stderr.strip()}")
        return True
    except Exception as e:
        print(f"      Error: {e}")
        return False


def run_ps(cmd):
    try:
        result = subprocess.run(
            ["powershell", "-ExecutionPolicy", "Bypass", "-Command", cmd],
            capture_output=True,
            timeout=120,
            text=True
        )
        if result.returncode != 0 and result.stderr:
            print(f"      Warning: {result.stderr.strip()}")
    except Exception as e:
        print(f"      Error: {e}")


def main():
    print("=" * 60)
    print(" WINDOWS 11 VOICE TYPING ENABLER - FULLY AUTOMATIC")
    print("=" * 60)

    run_as_admin()

    script_dir = Path(__file__).parent.absolute()
    tools_dir = script_dir / "voice_typing_tools"
    ahk_dir = tools_dir / "ahk"
    nircmd_dir = tools_dir / "nircmd"
    scripts_dir = tools_dir / "scripts"

    tools_dir.mkdir(parents=True, exist_ok=True)
    scripts_dir.mkdir(parents=True, exist_ok=True)

    print("\n[1/9] Enabling Online Speech Recognition...")
    run_cmd(
        r'reg add "HKCU\Software\Microsoft\Speech_OneCore\Settings\OnlineSpeechPrivacy" /v HasAccepted /t REG_DWORD /d 1 /f'
    )
    run_cmd(
        r'reg add "HKCU\Software\Microsoft\Speech_OneCore\Settings\VoiceActivation\UserPreferenceForAllApps" /v AgentActivationEnabled /t REG_DWORD /d 1 /f'
    )
    run_cmd(
        r'reg add "HKCU\Software\Microsoft\Speech_OneCore\Settings\VoiceActivation\UserPreferenceForAllApps" /v AgentActivationOnLockScreenEnabled /t REG_DWORD /d 1 /f'
    )
    print("      Done")

    print("\n[2/9] Removing organization speech policies...")
    policies = [
        r"HKLM\SOFTWARE\Policies\Microsoft\Speech",
        r"HKCU\SOFTWARE\Policies\Microsoft\Speech",
        r"HKLM\SOFTWARE\Policies\Microsoft\InputPersonalization",
        r"HKCU\SOFTWARE\Policies\Microsoft\InputPersonalization",
        r'"HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Search"',
        r'"HKCU\SOFTWARE\Policies\Microsoft\Windows\Windows Search"',
    ]
    for p in policies:
        # Skip double-quoting if already quoted
        if p.startswith('"'):
            run_cmd(f'reg delete {p} /f')
        else:
            run_cmd(f'reg delete "{p}" /f')
    print("      Done")

    print("\n[3/9] Clearing Group Policy cache...")
    for gp in [
        r"C:\Windows\System32\GroupPolicy",
        r"C:\Windows\System32\GroupPolicyUsers",
    ]:
        if os.path.exists(gp):
            for root, _, files in os.walk(gp):
                for f in files:
                    try:
                        os.remove(os.path.join(root, f))
                    except:
                        pass
    print("      Done")

    print("\n[4/9] Refreshing Group Policy...")
    run_cmd("gpupdate /force")
    print("      Done")

    print("\n[5/9] Downloading AutoHotkey v2...")
    if not (ahk_dir / "AutoHotkey64.exe").exists():
        ahk_dir.mkdir(parents=True, exist_ok=True)
        try:
            ahk_zip = tools_dir / "ahk.zip"
            print("      Downloading from autohotkey.com...")
            urllib.request.urlretrieve(
                "https://www.autohotkey.com/download/ahk-v2.zip", ahk_zip
            )
            print("      Extracting...")
            with zipfile.ZipFile(ahk_zip, "r") as z:
                z.extractall(ahk_dir)
            ahk_zip.unlink()
            print("      Downloaded and extracted successfully")
        except Exception as e:
            print(f"      Failed: {e}")
            print(f"      Trying fallback download...")
            try:
                urllib.request.urlretrieve(
                    "https://github.com/AutoHotkey/AutoHotkey/releases/download/v2.0.11/AutoHotkey_2.0.11.zip", ahk_zip
                )
                with zipfile.ZipFile(ahk_zip, "r") as z:
                    z.extractall(ahk_dir)
                ahk_zip.unlink()
                print("      Downloaded from GitHub successfully")
            except Exception as e2:
                print(f"      Fallback also failed: {e2}")
    else:
        print("      Already installed")

    print("\n[6/9] Downloading NirCmd...")
    if not (nircmd_dir / "nircmd.exe").exists():
        nircmd_dir.mkdir(parents=True, exist_ok=True)
        try:
            nircmd_zip = tools_dir / "nircmd.zip"
            print("      Downloading from nirsoft.net...")
            urllib.request.urlretrieve(
                "https://www.nirsoft.net/utils/nircmd-x64.zip", nircmd_zip
            )
            print("      Extracting...")
            with zipfile.ZipFile(nircmd_zip, "r") as z:
                z.extractall(nircmd_dir)
            nircmd_zip.unlink()
            print("      Downloaded and extracted successfully")
        except Exception as e:
            print(f"      Failed: {e}")
    else:
        print("      Already installed")

    print("\n[7/9] Creating AutoHotkey scripts...")
    (scripts_dir / "activate_voice_typing.ahk").write_text(
        """SetTitleMatchMode 2
if !WinExist("Notepad") {
    Run "notepad.exe"
    WinWait "Notepad",, 10
}
WinActivate "Notepad"
WinWaitActive "Notepad",, 5
Sleep 1000
WinGetPos &X, &Y, &W, &H, "Notepad"
Click X + (W // 2), Y + (H // 2)
Sleep 500
Send "#h"
Sleep 3000
"""
    )
    (scripts_dir / "quick_winh.ahk").write_text('Send "#h"\nSleep 2000\n')
    (scripts_dir / "voice_access.ahk").write_text('Send "#^s"\nSleep 2000\n')
    print("      Done")

    print("\n[8/9] Creating launcher batch files...")
    ahk_exe = ahk_dir / "AutoHotkey64.exe"
    (script_dir / "START_VOICE_TYPING.bat").write_text(
        f'@echo off\nstart "" "{ahk_exe}" "{scripts_dir / "activate_voice_typing.ahk"}"\n'
    )
    (script_dir / "QUICK_WINH.bat").write_text(
        f'@echo off\nstart "" "{ahk_exe}" "{scripts_dir / "quick_winh.ahk"}"\n'
    )
    (script_dir / "VOICE_ACCESS.bat").write_text(
        f'@echo off\nstart "" "{ahk_exe}" "{scripts_dir / "voice_access.ahk"}"\n'
    )
    print("      Done")

    print("\n[9/9] Triggering voice typing...")
    run_ps(
        "Get-Process TextInputHost -ErrorAction SilentlyContinue | Stop-Process -Force"
    )
    time.sleep(2)

    if ahk_exe.exists():
        try:
            subprocess.Popen(
                [str(ahk_exe), str(scripts_dir / "activate_voice_typing.ahk")],
                creationflags=subprocess.CREATE_NO_WINDOW,
            )
            print("      Voice typing triggered!")
        except Exception as e:
            print(f"      Failed to trigger: {e}")
            print(f"      You can manually run: {script_dir / 'START_VOICE_TYPING.bat'}")
    else:
        print(f"      AutoHotkey not found at: {ahk_exe}")
        print(f"      Voice typing can still be activated with Win+H")

    print("\n" + "=" * 60)
    print(" SETUP COMPLETE!")
    print("=" * 60)
    print(f"""
CREATED FILES:
  {script_dir / 'START_VOICE_TYPING.bat'}  - Opens Notepad + Win+H
  {script_dir / 'QUICK_WINH.bat'}          - Sends Win+H instantly
  {script_dir / 'VOICE_ACCESS.bat'}        - Win+Ctrl+S for Voice Access
  {tools_dir}/                             - AutoHotkey & NirCmd

SHORTCUTS:
  Win + H         = Voice Typing
  Win + Ctrl + S  = Voice Access

NOTE: Restart PC if voice typing doesn't appear.
      All batch files are in: {script_dir}
""")
    print("=" * 60)
    input("\nPress Enter to exit...")


if __name__ == "__main__":
    main()

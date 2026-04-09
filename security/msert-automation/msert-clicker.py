#!/usr/bin/env python3
"""
MSERT Auto-Clicker - Clicks through wizard, waits for scan, clicks Remove/Clean, then Finish.
Quick scan (default). Checks every 5 min to click Remove then Finish.
"""

import pyautogui
import time
import win32gui
import win32con
import win32com.client
import ctypes
import ctypes.wintypes

# Windows UI Automation for finding buttons by text
FindWindowEx = ctypes.windll.user32.FindWindowExW
SendMessage = ctypes.windll.user32.SendMessageW
GetWindowText = ctypes.windll.user32.GetWindowTextW
GetClassName = ctypes.windll.user32.GetClassNameW
BM_CLICK = 0x00F5
WM_GETTEXT = 0x000D
WM_GETTEXTLENGTH = 0x000E


def find_msert_window():
    def callback(hwnd, windows):
        if win32gui.IsWindowVisible(hwnd):
            title = win32gui.GetWindowText(hwnd)
            if "Microsoft" in title and "Safety" in title:
                windows.append(hwnd)
    windows = []
    win32gui.EnumWindows(callback, windows)
    return windows[0] if windows else None


def focus_window(hwnd):
    win32gui.ShowWindow(hwnd, win32con.SW_RESTORE)
    win32gui.SetWindowPos(hwnd, win32con.HWND_TOPMOST, 0, 0, 0, 0,
                          win32con.SWP_NOMOVE | win32con.SWP_NOSIZE)
    try:
        win32gui.SetForegroundWindow(hwnd)
    except:
        shell = win32com.client.Dispatch("WScript.Shell")
        shell.SendKeys('%')
        win32gui.SetForegroundWindow(hwnd)
    time.sleep(0.5)


def click_at(x, y, label=""):
    pyautogui.click(x, y)
    print(f"[+] Clicked {label} at ({x}, {y})")


def find_buttons(parent_hwnd):
    """Find all Button controls in the MSERT window and return their texts + hwnds."""
    buttons = []
    child = 0
    while True:
        child = FindWindowEx(parent_hwnd, child, None, None)
        if not child:
            break
        # Get class name
        class_buf = ctypes.create_unicode_buffer(256)
        GetClassName(child, class_buf, 256)
        # Get text
        text_buf = ctypes.create_unicode_buffer(256)
        GetWindowText(child, text_buf, 256)
        text = text_buf.value.strip()
        if text:
            buttons.append((text, child, class_buf.value))
        # Also check children of children (for grouped controls)
        sub = 0
        while True:
            sub = FindWindowEx(child, sub, None, None)
            if not sub:
                break
            sub_text_buf = ctypes.create_unicode_buffer(256)
            GetWindowText(sub, sub_text_buf, 256)
            sub_class_buf = ctypes.create_unicode_buffer(256)
            GetClassName(sub, sub_class_buf, 256)
            sub_text = sub_text_buf.value.strip()
            if sub_text:
                buttons.append((sub_text, sub, sub_class_buf.value))
    return buttons


def click_button_by_text(parent_hwnd, target_texts):
    """Try to find and click a button matching any of the target texts. Returns True if clicked."""
    buttons = find_buttons(parent_hwnd)
    for text, btn_hwnd, classname in buttons:
        for target in target_texts:
            if target.lower() in text.lower():
                # Send BM_CLICK message to the button
                SendMessage(btn_hwnd, BM_CLICK, 0, 0)
                print(f"[+] Clicked button '{text}' (hwnd={btn_hwnd}, class={classname})")
                return True
    return False


def main():
    print("[*] MSERT Auto-Clicker Started (quick scan + auto-remove)")

    time.sleep(5)

    # Find and focus MSERT window
    hwnd = None
    for attempt in range(10):
        hwnd = find_msert_window()
        if hwnd:
            print(f"[+] Found MSERT window on attempt {attempt+1}")
            break
        print(f"[*] Attempt {attempt+1}/10: Waiting for window...")
        time.sleep(2)

    if not hwnd:
        print("[!] Could not find MSERT window after 10 attempts")
        return

    focus_window(hwnd)

    rect = win32gui.GetWindowRect(hwnd)
    win_x, win_y, win_right, win_bottom = rect
    win_width = win_right - win_x
    win_height = win_bottom - win_y
    print(f"[*] Window: {win_width}x{win_height} at ({win_x}, {win_y})")

    # Step 1: Accept EULA - click checkbox then Next
    # Try Win32 button click first, fall back to coordinates
    print("[1/2] Accepting EULA...")
    if not click_button_by_text(hwnd, ["accept", "agree"]):
        click_at(110, 563, "Checkbox")
    time.sleep(0.5)

    # Step 2: Click Next through wizard pages (4 times for EULA -> scan type -> scan start)
    print("[2/2] Clicking Next/Next/Next/Next...")
    for i in range(1, 5):
        print(f"  Next click {i}/4...")
        if not click_button_by_text(hwnd, ["next", ">"]):
            # Fallback to coordinate click
            click_at(601, 690, "Next")
        time.sleep(1.5)

    print("[OK] Scan should be starting (quick scan)...")

    # Step 3: Wait for scan to complete, then click Remove/Clean, then Finish
    print("[*] Waiting for scan to complete (checking every 5min)...")
    max_wait = 3600
    elapsed = 0

    while elapsed < max_wait:
        time.sleep(300)  # Check every 5 minutes
        elapsed += 300

        hwnd = find_msert_window()
        if not hwnd:
            print("[+] MSERT window closed -- scan complete!")
            break

        focus_window(hwnd)

        # List all buttons for debugging
        buttons = find_buttons(hwnd)
        btn_texts = [t for t, h, c in buttons]
        print(f"[*] Buttons found: {btn_texts}")

        # Try clicking Remove/Clean first (threat removal)
        if click_button_by_text(hwnd, ["remove", "clean"]):
            print("[+] Clicked Remove/Clean - waiting for removal...")
            time.sleep(30)  # Give MSERT time to remove threats

        # Now try Finish/Close
        hwnd = find_msert_window()
        if hwnd:
            if click_button_by_text(hwnd, ["finish", "close", "done"]):
                time.sleep(2)
                if not find_msert_window():
                    print("[+] Window closed after Finish -- done!")
                    break

        # Check if window is gone
        if not find_msert_window():
            print("[+] MSERT window closed -- done!")
            break

        print(f"[*] Still scanning... ({elapsed // 60}m elapsed)")

    print("[OK] MSERT clicker done")


if __name__ == "__main__":
    main()

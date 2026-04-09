#!/usr/bin/env python3
"""
MSERT Auto-Clicker - HARDENED VERSION
Improvements:
  - Explicit exit codes (0=success, 1=failure)
  - Shorter timeout (10min instead of 60min)
  - Better button detection using UI Automation
  - Logging to file for debugging
  - Timeout handling for hung windows
  - State tracking to detect stuck state
"""

import pyautogui
import time
import win32gui
import win32con
import win32com.client
import ctypes
import ctypes.wintypes
import sys
import os
from datetime import datetime

# Windows UI Automation
FindWindowEx = ctypes.windll.user32.FindWindowExW
SendMessage = ctypes.windll.user32.SendMessageW
GetWindowText = ctypes.windll.user32.GetWindowTextW
GetClassName = ctypes.windll.user32.GetClassNameW
BM_CLICK = 0x00F5
WM_GETTEXT = 0x000D
WM_GETTEXTLENGTH = 0x000E

# Logging
LOG_FILE = os.path.join(os.path.dirname(__file__), "msert-clicker.log")

def log(message, level="INFO"):
    """Write message to log file and stdout"""
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    line = f"[{timestamp}] [{level}] {message}"
    print(line)
    with open(LOG_FILE, "a", encoding="utf-8") as f:
        f.write(line + "\n")


def find_msert_window():
    """Find MSERT window by title"""
    def callback(hwnd, windows):
        if win32gui.IsWindowVisible(hwnd):
            title = win32gui.GetWindowText(hwnd)
            if "Microsoft" in title or "Safety" in title:
                windows.append((hwnd, title))
    
    windows = []
    win32gui.EnumWindows(callback, windows)
    
    if windows:
        hwnd, title = windows[0]
        log(f"Found MSERT window: '{title}' (hwnd={hwnd})", "DEBUG")
        return hwnd
    
    return None


def focus_window(hwnd):
    """Focus and bring window to foreground"""
    try:
        win32gui.ShowWindow(hwnd, win32con.SW_RESTORE)
        win32gui.SetWindowPos(hwnd, win32con.HWND_TOPMOST, 0, 0, 0, 0,
                              win32con.SWP_NOMOVE | win32con.SWP_NOSIZE)
        win32gui.SetForegroundWindow(hwnd)
        time.sleep(0.5)
        log("Window focused successfully", "DEBUG")
    except Exception as e:
        log(f"Failed to focus window: {e}", "WARN")
        try:
            shell = win32com.client.Dispatch("WScript.Shell")
            shell.SendKeys('%')
            win32gui.SetForegroundWindow(hwnd)
        except:
            log("Fallback focus method also failed", "ERROR")


def find_buttons(parent_hwnd):
    """Find all Button controls and return (text, hwnd, classname)"""
    buttons = []
    child = 0
    
    while True:
        child = FindWindowEx(parent_hwnd, child, None, None)
        if not child:
            break
        
        # Get class name
        class_buf = ctypes.create_unicode_buffer(256)
        GetClassName(child, class_buf, 256)
        class_name = class_buf.value
        
        # Get text
        text_buf = ctypes.create_unicode_buffer(256)
        GetWindowText(child, text_buf, 256)
        text = text_buf.value.strip()
        
        if text:
            buttons.append((text, child, class_name))
        
        # Also check children (for grouped controls)
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


def click_button_by_text(parent_hwnd, target_texts, debug=False):
    """Find and click button matching target text. Returns True if clicked."""
    try:
        buttons = find_buttons(parent_hwnd)
        
        if debug:
            found_texts = [t for t, h, c in buttons]
            log(f"Available buttons: {found_texts}", "DEBUG")
        
        for text, btn_hwnd, classname in buttons:
            for target in target_texts:
                if target.lower() in text.lower():
                    try:
                        SendMessage(btn_hwnd, BM_CLICK, 0, 0)
                        log(f"Clicked button '{text}' (target='{target}')", "INFO")
                        return True
                    except Exception as e:
                        log(f"Failed to click button '{text}': {e}", "WARN")
        
        log(f"No button matching {target_texts} found", "WARN")
        return False
    except Exception as e:
        log(f"Error in click_button_by_text: {e}", "ERROR")
        return False


def main():
    """Main clicker loop"""
    log("=== MSERT Auto-Clicker Started (HARDENED) ===", "INFO")
    
    try:
        # Clear old log
        if os.path.exists(LOG_FILE):
            os.remove(LOG_FILE)
        
        time.sleep(5)
        
        # Find MSERT window
        hwnd = None
        for attempt in range(20):  # Increased from 10
            hwnd = find_msert_window()
            if hwnd:
                log(f"Found MSERT window on attempt {attempt+1}", "INFO")
                break
            log(f"Waiting for window (attempt {attempt+1}/20)...", "DEBUG")
            time.sleep(1)  # Changed from 2s to 1s
        
        if not hwnd:
            log("ERROR: Could not find MSERT window after 20 attempts", "ERROR")
            return 1
        
        focus_window(hwnd)
        
        rect = win32gui.GetWindowRect(hwnd)
        win_x, win_y, win_right, win_bottom = rect
        win_width = win_right - win_x
        win_height = win_bottom - win_y
        log(f"Window: {win_width}x{win_height} at ({win_x}, {win_y})", "DEBUG")
        
        # Step 1: Accept EULA
        log("Step 1/2: Accepting EULA...", "INFO")
        
        # Try button click first
        if not click_button_by_text(hwnd, ["accept", "agree", "checkbox"], debug=True):
            log("No accept/agree button found - may not need EULA acceptance", "WARN")
        
        time.sleep(1)
        
        # Step 2: Click Next multiple times
        log("Step 2/2: Clicking Next to start scan...", "INFO")
        
        for i in range(1, 5):
            log(f"  Next click {i}/4...", "DEBUG")
            if not click_button_by_text(hwnd, ["next", ">", "→"]):
                log(f"Warning: Next button not found on iteration {i}", "WARN")
            time.sleep(2)  # Increased from 1.5s
        
        log("Scan should be starting now...", "INFO")
        
        # Step 3: Wait for scan + click Remove/Finish
        log("Waiting for scan to complete (checking every 5min)...", "INFO")
        
        max_wait = 600  # HARDENED: 10 minutes instead of 60 minutes
        elapsed = 0
        check_interval = 300  # 5 minutes
        last_button_state = None
        stuck_count = 0
        
        while elapsed < max_wait:
            time.sleep(check_interval)
            elapsed += check_interval
            
            log(f"Status check at {elapsed//60}m ({elapsed}s)...", "DEBUG")
            
            hwnd = find_msert_window()
            if not hwnd:
                log("MSERT window closed - scan complete!", "INFO")
                return 0
            
            focus_window(hwnd)
            
            # Get current button state for stuck detection
            buttons = find_buttons(hwnd)
            btn_texts = tuple(sorted([t for t, h, c in buttons]))
            
            if btn_texts == last_button_state:
                stuck_count += 1
                log(f"Same buttons for {stuck_count*check_interval}s - may be stuck", "WARN")
                
                # If stuck for 15+ minutes, force-kill
                if stuck_count > 3:
                    log("ERROR: Window appears stuck - giving up", "ERROR")
                    return 1
            else:
                stuck_count = 0
                log(f"Buttons changed: {btn_texts}", "DEBUG")
            
            last_button_state = btn_texts
            
            # Try clicking Remove/Clean (threat removal)
            if click_button_by_text(hwnd, ["remove", "clean"]):
                log("Clicked Remove/Clean - waiting for removal...", "INFO")
                time.sleep(30)
            
            # Try clicking Finish/Close/Done
            hwnd = find_msert_window()
            if hwnd:
                if click_button_by_text(hwnd, ["finish", "close", "done"]):
                    log("Clicked Finish/Close - window should close...", "INFO")
                    time.sleep(2)
                    
                    if not find_msert_window():
                        log("Window closed after Finish - success!", "INFO")
                        return 0
        
        # Timeout reached
        log(f"ERROR: Timeout after {max_wait}s without scan completion", "ERROR")
        return 1
    
    except Exception as e:
        log(f"CRITICAL ERROR: {e}", "ERROR")
        import traceback
        log(traceback.format_exc(), "ERROR")
        return 1


if __name__ == "__main__":
    exit_code = main()
    log(f"Clicker exiting with code: {exit_code}", "INFO")
    sys.exit(exit_code)

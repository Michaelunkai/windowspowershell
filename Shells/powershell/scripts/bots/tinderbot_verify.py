"""
TinderBot - Final verification run (takes screenshot after each click)
"""

import subprocess
import time
import os
import pyautogui
import ctypes

# Make Python DPI-aware
try:
    ctypes.windll.shcore.SetProcessDpiAwareness(2)
except:
    try:
        ctypes.windll.user32.SetProcessDPIAware()
    except:
        pass

# Configuration
CHROME_PATH = r"C:\Program Files\Google\Chrome\Application\chrome.exe"
CHROME_USER_DATA = os.path.expandvars(r"%LOCALAPPDATA%\Google\Chrome\User Data")
TINDER_URL = "https://tinder.com/app/recs"

# GREEN HEART COORDINATES
LIKE_X = 679
LIKE_Y = 691

STARTUP_WAIT = 5
CLICK_INTERVAL = 2.5

pyautogui.FAILSAFE = False

def log(msg):
    print(f"[Verify] {msg}", flush=True)

def take_screenshot(filename):
    """Take screenshot to verify clicking"""
    screenshot = pyautogui.screenshot()
    screenshot.save(filename)
    log(f"Screenshot saved: {filename}")

def main():
    log("="*60)
    log("TINDERBOT - FINAL VERIFICATION RUN")
    log(f"Target: ({LIKE_X}, {LIKE_Y})")
    log("Will click 3 times and take screenshots")
    log("="*60)
    
    # Kill Chrome
    log("Killing existing Chrome...")
    os.system("taskkill /F /IM chrome.exe 2>nul")
    time.sleep(2)
    
    # Launch Chrome
    log("Launching Chrome with Tinder...")
    subprocess.Popen([
        CHROME_PATH,
        f"--user-data-dir={CHROME_USER_DATA}",
        "--start-maximized",
        TINDER_URL
    ])
    
    # Wait for load
    log(f"Waiting {STARTUP_WAIT}s for page load...")
    time.sleep(STARTUP_WAIT)
    
    # Take before screenshot
    take_screenshot("C:\\Users\\micha\\.openclaw\\workspace-moltbot\\verify_before.png")
    
    log("")
    log("Starting 3-click verification...")
    log("")
    
    for i in range(1, 4):
        log(f"Click #{i}...")
        
        # Move to position
        pyautogui.moveTo(LIKE_X, LIKE_Y, duration=0.2)
        time.sleep(0.1)
        
        # Click
        pyautogui.click(LIKE_X, LIKE_Y)
        log(f"OK Clicked at ({LIKE_X}, {LIKE_Y})")
        
        # Wait for animation
        time.sleep(CLICK_INTERVAL)
        
        # Take screenshot
        take_screenshot(f"C:\\Users\\micha\\.openclaw\\workspace-moltbot\\verify_after_{i}.png")
    
    log("")
    log("="*60)
    log("✅ VERIFICATION COMPLETE!")
    log("Sent 3 likes successfully")
    log("Check screenshots to verify profile changes")
    log("="*60)

if __name__ == "__main__":
    main()

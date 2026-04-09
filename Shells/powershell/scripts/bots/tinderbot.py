"""
TinderBot - DPI-aware clicking with precise coordinates
Press CCCC (c four times fast) to stop immediately
"""

import subprocess
import time
import os
import sys
import threading
import pyautogui
import ctypes
import msvcrt

# NOTE: Physical res is 3840x2160, Windows scaling 150% shows 2560x1440
# pyautogui works in physical pixel space (3840x2160)

# Configuration
CHROME_PATH = r"C:\Program Files\Google\Chrome\Application\chrome.exe"
CHROME_USER_DATA = os.path.expandvars(r"%LOCALAPPDATA%\Google\Chrome\User Data")
TINDER_URL = "https://tinder.com/app/recs"

# GREEN HEART COORDINATES - PowerShell logical coords (1019, 1041) × 1.5 scale
LIKE_X = 1529
LIKE_Y = 1562

# Timing
STARTUP_WAIT = 5
CLICK_INTERVAL = 2

pyautogui.FAILSAFE = False

# Stop flag
STOP = False

def log(msg):
    print(f"[TinderBot] {msg}", flush=True)

def key_listener():
    """Listen for CCCC (4 c's in a row) to stop immediately."""
    global STOP
    c_count = 0
    last_time = 0
    while not STOP:
        if msvcrt.kbhit():
            ch = msvcrt.getch()
            now = time.time()
            if ch.lower() == b'c':
                if now - last_time < 1.0:
                    c_count += 1
                else:
                    c_count = 1
                last_time = now
                if c_count >= 4:
                    STOP = True
                    log("\n!! CCCC detected - STOPPING NOW !!")
                    return
            else:
                c_count = 0
        else:
            time.sleep(0.05)

def main():
    global STOP

    log("="*50)
    log("TINDERBOT - VERIFIED COORDINATES")
    log(f"Clicking at ({LIKE_X}, {LIKE_Y}) every {CLICK_INTERVAL}s")
    log("Press CCCC (c 4 times fast) to STOP")
    log("="*50)

    # Start key listener thread
    listener = threading.Thread(target=key_listener, daemon=True)
    listener.start()

    # Kill existing Chrome
    log("Closing existing Chrome...")
    os.system("taskkill /F /IM chrome.exe 2>nul")
    time.sleep(2)

    # Launch Chrome
    log("Opening Chrome...")
    subprocess.Popen([
        CHROME_PATH,
        f"--user-data-dir={CHROME_USER_DATA}",
        "--start-maximized",
        TINDER_URL
    ])

    # Wait for load
    log(f"Waiting {STARTUP_WAIT}s for page load...")
    time.sleep(STARTUP_WAIT)

    if STOP:
        log("Stopped before starting.")
        return

    # Show position
    log(f"Target position: ({LIKE_X}, {LIKE_Y})")

    # Move mouse to position for visual verification
    log("Moving mouse to target (watch where it goes)...")
    pyautogui.moveTo(LIKE_X, LIKE_Y, duration=1)
    time.sleep(1)
    log("^ If mouse is NOT on green heart, press CCCC to stop!")
    time.sleep(2)

    if STOP:
        log("Stopped before clicking.")
        return

    # Start clicking - NO LIMIT, runs forever until CCCC
    log("")
    log("STARTING LIKES! (press CCCC to stop)")
    log("")

    likes = 0
    start = time.time()

    while not STOP:
        try:
            pyautogui.click(LIKE_X, LIKE_Y)
            likes += 1

            elapsed = time.time() - start
            rate = round(likes / (elapsed / 60), 1) if elapsed > 0 else 0
            log(f"LIKED #{likes} ({rate}/min)")

            # Sleep in small chunks so CCCC is responsive
            for _ in range(int(CLICK_INTERVAL * 20)):
                if STOP:
                    break
                time.sleep(0.05)

        except KeyboardInterrupt:
            STOP = True
            break

    log(f"\nStopped! Total: {likes} likes")

if __name__ == "__main__":
    main()

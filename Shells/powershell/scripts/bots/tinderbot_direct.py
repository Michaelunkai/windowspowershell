import subprocess
import time
import pyautogui
import sys

print("\n" + "="*50)
print(" TinderBot - Direct Chrome Automation")
print("="*50 + "\n")

# Kill existing Chrome
subprocess.run(["taskkill", "/F", "/IM", "chrome.exe"], capture_output=True)
time.sleep(2)

print("[1/6] Opening Chrome with Tinder...")
subprocess.Popen([r"C:\Program Files\Google\Chrome\Application\chrome.exe", "--start-maximized", "https://tinder.com"])
time.sleep(8)

# Get screen size
screen_width, screen_height = pyautogui.size()
print(f"Screen: {screen_width}x{screen_height}")

print("\n[2/6] Waiting for page load...")
time.sleep(5)

print("[3/6] Clicking login button...")
# Click in the general area where login button usually is (top right)
pyautogui.moveTo(screen_width - 150, 100)
time.sleep(0.5)
pyautogui.click()

# Also try center of screen
time.sleep(1)
pyautogui.moveTo(screen_width // 2, screen_height // 2)
pyautogui.click()

# Try tabbing to login
time.sleep(1)
for i in range(8):
    pyautogui.press('tab')
    time.sleep(0.2)
pyautogui.press('enter')

print("[OK] Login clicked (attempted)")
time.sleep(4)

print("\n[4/6] Looking for phone login...")
# "Trouble Logging In" is usually at bottom
pyautogui.moveTo(screen_width // 2, screen_height - 200)
pyautogui.click()

# Also try tabbing
time.sleep(1)
for i in range(10):
    pyautogui.press('tab')
    time.sleep(0.2)
pyautogui.press('enter')

print("[OK] Phone login selected (attempted)")
time.sleep(3)

print("\n[5/6] Entering phone number...")
# Click center (where input usually is)
pyautogui.moveTo(screen_width // 2, screen_height // 2)
pyautogui.click()
time.sleep(0.5)

# Clear and type
pyautogui.hotkey('ctrl', 'a')
pyautogui.typewrite('547632418')
print("[OK] Phone entered: 547632418")

# Submit
pyautogui.press('enter')
print("[OK] Submitted!")

print("\n[6/6] WAITING FOR SMS CODE...")
print("Enter the code manually")
print("Waiting 60 seconds...")

time.sleep(60)

# Go to swipes
print("\nNavigating to swipes...")
pyautogui.hotkey('ctrl', 'l')
time.sleep(0.5)
pyautogui.typewrite('https://tinder.com/app/recs')
pyautogui.press('enter')
time.sleep(5)

print("\n" + "="*50)
print(" AUTO-SWIPING STARTED!")
print("="*50 + "\n")

likes = 0
while True:
    try:
        # Press right arrow
        pyautogui.press('right')
        likes += 1
        
        if likes % 10 == 0:
            print(f"[OK] {likes} likes sent")
        
        # Close popups
        if likes % 25 == 0:
            pyautogui.press('escape')
        
        time.sleep(1.2)
        
    except KeyboardInterrupt:
        break

print(f"\nTotal: {likes} likes")
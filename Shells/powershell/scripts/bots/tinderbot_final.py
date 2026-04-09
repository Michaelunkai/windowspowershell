import time
from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.common.keys import Keys
from selenium.webdriver.chrome.service import Service
import os
import random

print("\n" + "="*50)
print(" TinderBot - WORKING Version")
print("="*50 + "\n")

# Setup Chrome with local driver
driver_path = r"F:\study\shells\powershell\scripts\bots\driver\chromedriver.exe"
if not os.path.exists(driver_path):
    driver_path = "chromedriver.exe"  # Try system PATH

service = Service(driver_path)
options = webdriver.ChromeOptions()
options.add_argument("--start-maximized")
options.add_argument("--disable-blink-features=AutomationControlled")
options.add_experimental_option("excludeSwitches", ["enable-automation"])
options.add_experimental_option("useAutomationExtension", False)

print("[1/6] Starting Chrome...")
driver = webdriver.Chrome(service=service, options=options)
wait = WebDriverWait(driver, 20)

print("[2/6] Opening Tinder...")
driver.get("https://tinder.com")
time.sleep(5)

# Dismiss cookies
try:
    cookie = wait.until(EC.element_to_be_clickable((By.XPATH, "//button[contains(text(), 'I accept')]")))
    cookie.click()
    print("[OK] Cookies accepted")
except:
    pass

print("\n[3/6] Finding and clicking login button...")

# Try multiple methods to find login
login_clicked = False
for attempt in range(10):
    try:
        # Method 1: Direct text search
        login = driver.find_element(By.XPATH, "//a[contains(translate(text(), 'LOGIN', 'login'), 'log in')]")
        driver.execute_script("arguments[0].scrollIntoView(true);", login)
        driver.execute_script("arguments[0].click();", login)
        login_clicked = True
        break
    except:
        pass
    
    try:
        # Method 2: Button search
        buttons = driver.find_elements(By.TAG_NAME, "button")
        for btn in buttons:
            if "log" in btn.text.lower() and "in" in btn.text.lower():
                driver.execute_script("arguments[0].click();", btn)
                login_clicked = True
                break
    except:
        pass
    
    if login_clicked:
        break
    
    try:
        # Method 3: Link search
        links = driver.find_elements(By.TAG_NAME, "a")
        for link in links:
            if "log" in link.text.lower():
                driver.execute_script("arguments[0].click();", link)
                login_clicked = True
                break
    except:
        pass
    
    if login_clicked:
        break
        
    time.sleep(1)

if login_clicked:
    print("[OK] Login button clicked!")
else:
    print("[!] Could not find login button automatically")
    print("Please click login manually...")
    time.sleep(10)

time.sleep(3)

print("\n[4/6] Looking for phone login option...")

# Find "Trouble Logging In?" button
phone_clicked = False
for attempt in range(10):
    try:
        # Look for trouble button
        trouble = wait.until(EC.element_to_be_clickable((By.XPATH, "//button[contains(text(), 'Trouble')]")))
        driver.execute_script("arguments[0].click();", trouble)
        phone_clicked = True
        print("[OK] Phone login selected!")
        break
    except:
        # Try all buttons
        try:
            buttons = driver.find_elements(By.TAG_NAME, "button")
            for btn in buttons:
                if "trouble" in btn.text.lower() or "phone" in btn.text.lower():
                    driver.execute_script("arguments[0].click();", btn)
                    phone_clicked = True
                    break
        except:
            pass
    
    time.sleep(1)

if not phone_clicked:
    print("[!] Please click 'Trouble Logging In?' manually")
    time.sleep(10)

time.sleep(2)

print("\n[5/6] Entering phone number...")

# Find phone input
phone_entered = False
try:
    phone_input = wait.until(EC.presence_of_element_located((By.CSS_SELECTOR, "input[type='tel']")))
    phone_input.clear()
    phone_input.send_keys("547632418")
    print("[OK] Phone number entered: 547632418")
    phone_entered = True
    
    # Submit
    try:
        submit = driver.find_element(By.CSS_SELECTOR, "button[type='submit']")
        driver.execute_script("arguments[0].click();", submit)
        print("[OK] Submitted!")
    except:
        phone_input.send_keys(Keys.RETURN)
        print("[OK] Pressed Enter!")
except:
    print("[!] Could not find phone input")

print("\n[6/6] WAITING FOR SMS CODE...")
print("You have 60 seconds to enter the code")
print("Waiting...")

# Wait for code
time.sleep(60)

# Go to swipe page
print("\nNavigating to swipe page...")
driver.get("https://tinder.com/app/recs")
time.sleep(5)

print("\n" + "="*50)
print(" AUTO-SWIPING STARTED!")
print("="*50 + "\n")

likes = 0
errors = 0

while True:
    try:
        swiped = False
        
        # Method 1: Find and click Like button
        try:
            like_button = driver.find_element(By.XPATH, "//button[@aria-label='Like']")
            driver.execute_script("arguments[0].click();", like_button)
            swiped = True
        except:
            pass
        
        # Method 2: Find heart button
        if not swiped:
            try:
                heart = driver.find_element(By.CSS_SELECTOR, "button[type='button'] path[d*='M35.']")
                parent_button = heart.find_element(By.XPATH, "./../..")
                driver.execute_script("arguments[0].click();", parent_button)
                swiped = True
            except:
                pass
        
        # Method 3: Keyboard shortcut
        if not swiped:
            try:
                body = driver.find_element(By.TAG_NAME, "body")
                body.send_keys(Keys.ARROW_RIGHT)
                swiped = True
            except:
                pass
        
        # Method 4: JavaScript simulation
        if not swiped:
            driver.execute_script("""
                // Find like button
                const likeBtn = document.querySelector('[aria-label="Like"]');
                if (likeBtn) {
                    likeBtn.click();
                    return true;
                }
                
                // Simulate right arrow
                const event = new KeyboardEvent('keydown', {
                    key: 'ArrowRight',
                    keyCode: 39,
                    bubbles: true
                });
                document.dispatchEvent(event);
                return true;
            """)
        
        likes += 1
        errors = 0  # Reset error counter on success
        
        # Show progress
        if likes % 10 == 0:
            print(f"[OK] {likes} profiles liked")
        
        # Handle popups
        if likes % 20 == 0:
            try:
                # Close any popup
                close_btns = driver.find_elements(By.XPATH, "//button[@aria-label='Close']")
                for btn in close_btns:
                    try:
                        driver.execute_script("arguments[0].click();", btn)
                    except:
                        pass
            except:
                pass
        
        # Random delay
        time.sleep(random.uniform(1.0, 2.0))
        
    except Exception as e:
        errors += 1
        if errors > 5:
            print(f"[!] Too many errors. Last error: {e}")
            print("Trying to recover...")
            # Try to go back to swipe page
            driver.get("https://tinder.com/app/recs")
            time.sleep(5)
            errors = 0
        time.sleep(1)

print(f"\nTotal likes: {likes}")
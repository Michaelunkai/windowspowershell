# -*- coding: utf-8 -*-
import time
from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.common.keys import Keys
from selenium.webdriver.chrome.service import Service
from webdriver_manager.chrome import ChromeDriverManager
import random

print("\n" + "="*50)
print(" TinderBot - Full Automation")
print("="*50 + "\n")

# Setup Chrome with proper options
options = webdriver.ChromeOptions()
options.add_argument("--start-maximized")
options.add_argument("--disable-blink-features=AutomationControlled")
options.add_experimental_option("excludeSwitches", ["enable-automation"])
options.add_experimental_option("useAutomationExtension", False)

print("[1/6] Setting up Chrome driver...")
driver = webdriver.Chrome(service=Service(ChromeDriverManager().install()), options=options)
driver.execute_script("Object.defineProperty(navigator, 'webdriver', {get: () => undefined})")

print("[2/6] Opening Tinder...")
driver.get("https://tinder.com")
time.sleep(5)

print("[3/6] Looking for login button...")

# Wait and click login - try multiple methods
login_clicked = False
wait = WebDriverWait(driver, 20)

# Method 1: Wait for cookie banner and dismiss it first
try:
    cookie_btn = driver.find_element(By.XPATH, "//button[contains(text(), 'I accept')]")
    cookie_btn.click()
    time.sleep(1)
except:
    pass

# Method 2: Find login button
for i in range(5):
    try:
        # Try different selectors
        login_selectors = [
            "//a[contains(text(), 'Log in')]",
            "//button[contains(text(), 'Log in')]",
            "//button[contains(@aria-label, 'Log in')]",
            "//span[contains(text(), 'Log in')]/..",
            "//div[@role='button'][contains(., 'Log in')]"
        ]
        
        for selector in login_selectors:
            try:
                login_btn = wait.until(EC.element_to_be_clickable((By.XPATH, selector)))
                driver.execute_script("arguments[0].click();", login_btn)
                login_clicked = True
                print("[OK] Login button clicked!")
                break
            except:
                continue
        
        if login_clicked:
            break
            
    except:
        time.sleep(1)

if not login_clicked:
    print("[!] Could not find login button, trying JavaScript...")
    driver.execute_script("""
        var buttons = document.querySelectorAll('button, a, div[role="button"]');
        for (var btn of buttons) {
            if (btn.textContent.includes('Log in') || btn.textContent.includes('LOGIN')) {
                btn.click();
                break;
            }
        }
    """)

time.sleep(3)

print("[4/6] Looking for phone login option...")

# Click "Trouble Logging In?" or "Log in with phone number"
phone_clicked = False
for i in range(5):
    try:
        phone_selectors = [
            "//button[contains(text(), 'Trouble Logging In')]",
            "//button[contains(text(), 'trouble logging in')]",
            "//button[contains(text(), 'phone')]",
            "//span[contains(text(), 'phone number')]/..",
            "//div[contains(text(), 'SMS')]/.."
        ]
        
        for selector in phone_selectors:
            try:
                phone_btn = driver.find_element(By.XPATH, selector)
                driver.execute_script("arguments[0].click();", phone_btn)
                phone_clicked = True
                print("[OK] Phone login selected!")
                break
            except:
                continue
                
        if phone_clicked:
            break
            
    except:
        time.sleep(1)

if not phone_clicked:
    driver.execute_script("""
        var elements = document.querySelectorAll('button, span, div');
        for (var el of elements) {
            if (el.textContent.includes('Trouble') || el.textContent.includes('phone') || el.textContent.includes('SMS')) {
                el.click();
                break;
            }
        }
    """)

time.sleep(2)

print("[5/6] Entering phone number...")

# Find phone input and enter number
phone_entered = False
try:
    phone_input = wait.until(EC.presence_of_element_located((By.CSS_SELECTOR, "input[type='tel']")))
    phone_input.clear()
    driver.execute_script("arguments[0].value = '';", phone_input)
    phone_input.send_keys("547632418")
    print("[OK] Phone number entered: 547632418")
    phone_entered = True
except:
    print("[!] Could not find phone input")

if phone_entered:
    # Find and click submit
    try:
        submit_btn = driver.find_element(By.CSS_SELECTOR, "button[type='submit']")
        driver.execute_script("arguments[0].click();", submit_btn)
        print("[OK] Submitted!")
    except:
        # Press Enter
        phone_input.send_keys(Keys.RETURN)
        print("[OK] Pressed Enter!")

print("\n[6/6] WAITING FOR SMS CODE...")
print("Enter the SMS code in the browser window")
print("Waiting 60 seconds...\n")

# Wait for SMS code to be entered
time.sleep(60)

# Navigate to swipe page
print("Navigating to swipe page...")
try:
    driver.get("https://tinder.com/app/recs")
except:
    pass

time.sleep(5)

# Start swiping
print("\n" + "="*50)
print(" AUTO-SWIPING STARTED!")
print("="*50 + "\n")

like_count = 0
start_time = time.time()

while True:
    try:
        # Multiple swipe methods
        swiped = False
        
        # Method 1: Click like button directly
        try:
            like_btn = driver.find_element(By.XPATH, "//button[@aria-label='Like']")
            driver.execute_script("arguments[0].click();", like_btn)
            swiped = True
        except:
            pass
        
        # Method 2: Find button by class
        if not swiped:
            try:
                like_btn = driver.find_element(By.CSS_SELECTOR, ".recsGamepad__button--like button")
                driver.execute_script("arguments[0].click();", like_btn)
                swiped = True
            except:
                pass
        
        # Method 3: Use keyboard
        if not swiped:
            try:
                body = driver.find_element(By.TAG_NAME, "body")
                body.send_keys(Keys.ARROW_RIGHT)
                swiped = True
            except:
                pass
        
        # Method 4: JavaScript swipe
        if not swiped:
            driver.execute_script("""
                // Simulate right arrow key
                var event = new KeyboardEvent('keydown', {
                    key: 'ArrowRight',
                    code: 'ArrowRight',
                    keyCode: 39,
                    which: 39,
                    bubbles: true
                });
                document.dispatchEvent(event);
                
                // Or click like button
                var likeBtn = document.querySelector('[aria-label="Like"]');
                if (likeBtn) likeBtn.click();
            """)
        
        like_count += 1
        
        # Progress update
        if like_count % 10 == 0:
            elapsed = time.time() - start_time
            rate = round(like_count / (elapsed / 60), 1)
            print(f"[OK] {like_count} likes sent ({rate} per minute)")
        
        # Handle popups
        if like_count % 20 == 0:
            driver.execute_script("""
                var popups = document.querySelectorAll('[aria-label="Close"], button[title="Close"]');
                popups.forEach(function(popup) { popup.click(); });
            """)
        
        # Random human-like delay
        time.sleep(random.uniform(0.8, 1.5))
        
    except KeyboardInterrupt:
        print("\n[!] Stopped by user")
        break
    except Exception as e:
        print(f"[!] Error: {e}")
        time.sleep(1)

print(f"\n[OK] Total likes: {like_count}")
driver.quit()
import undetected_chromedriver as uc
import time
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.common.keys import Keys
import random

print("\n[1/6] Starting Chrome...")
driver = uc.Chrome()
driver.maximize_window()

print("[2/6] Opening Tinder...")
driver.get("https://tinder.com")
time.sleep(5)

print("[3/6] Looking for login button...")

# Dismiss cookies if present
try:
    cookie = driver.find_element(By.XPATH, "//button[contains(text(), 'I accept')]")
    cookie.click()
except:
    pass

# Click login
login_found = False
for _ in range(10):
    try:
        # Try multiple methods
        try:
            login = driver.find_element(By.XPATH, "//a[contains(text(), 'Log in')]")
            login.click()
            login_found = True
            break
        except:
            try:
                login = driver.find_element(By.XPATH, "//button[contains(text(), 'Log in')]")
                login.click()  
                login_found = True
                break
            except:
                # Try JavaScript
                driver.execute_script("""
                    var btns = document.querySelectorAll('a, button, div[role="button"]');
                    for (var btn of btns) {
                        if (btn.textContent.includes('Log in')) {
                            btn.click();
                            return true;
                        }
                    }
                """)
                time.sleep(1)
    except:
        time.sleep(0.5)

if login_found:
    print("[OK] Login clicked!")
else:
    print("[!] Could not find login button")

time.sleep(3)

# Select phone login
print("[4/6] Selecting phone login...")
phone_found = False
for _ in range(10):
    try:
        trouble = driver.find_element(By.XPATH, "//button[contains(text(), 'Trouble')]")
        trouble.click()
        phone_found = True
        print("[OK] Phone login selected!")
        break
    except:
        try:
            driver.execute_script("""
                var els = document.querySelectorAll('button, span');
                for (var el of els) {
                    if (el.textContent.includes('Trouble') || el.textContent.includes('phone')) {
                        el.click();
                        return true;
                    }
                }
            """)
            time.sleep(1)
        except:
            pass

time.sleep(2)

# Enter phone number
print("[5/6] Entering phone number...")
try:
    phone = driver.find_element(By.CSS_SELECTOR, "input[type='tel']")
    phone.clear()
    phone.send_keys("547632418")
    print("[OK] Phone entered: 547632418")
    
    # Submit
    try:
        submit = driver.find_element(By.CSS_SELECTOR, "button[type='submit']")
        submit.click()
    except:
        phone.send_keys(Keys.RETURN)
    print("[OK] Submitted!")
except:
    print("[!] Could not find phone input")

print("\n[6/6] WAIT FOR SMS CODE!")
print("Enter the code in the browser")
print("Waiting 60 seconds...\n")

time.sleep(60)

# Go to swipes
driver.get("https://tinder.com/app/recs")
time.sleep(5)

# Start swiping
print("\nAUTO-SWIPING STARTED!\n")
likes = 0

while True:
    try:
        # Try to swipe
        try:
            # Method 1: Click like
            like = driver.find_element(By.XPATH, "//button[@aria-label='Like']")
            like.click()
        except:
            # Method 2: Arrow key
            body = driver.find_element(By.TAG_NAME, "body")
            body.send_keys(Keys.ARROW_RIGHT)
        
        likes += 1
        if likes % 10 == 0:
            print(f"[OK] {likes} likes sent")
        
        # Random delay
        time.sleep(random.uniform(0.8, 1.5))
        
        # Close popups
        if likes % 20 == 0:
            try:
                close = driver.find_element(By.XPATH, "//button[@aria-label='Close']")
                close.click()
            except:
                pass
                
    except KeyboardInterrupt:
        break
    except:
        time.sleep(1)

print(f"\nTotal: {likes} likes")

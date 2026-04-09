from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.common.keys import Keys
from webdriver_manager.chrome import ChromeDriverManager
from selenium.webdriver.chrome.service import Service
import time
import random

print("\n[1/5] Setting up Chrome driver...")
service = Service(ChromeDriverManager().install())

options = webdriver.ChromeOptions()
options.add_argument("--start-maximized")
options.add_experimental_option("excludeSwitches", ["enable-logging"])

print("[2/5] Opening Chrome with Tinder...")
driver = webdriver.Chrome(service=service, options=options)
driver.get("https://tinder.com")

print("[OK] Chrome is open! You should see Tinder loading...")
time.sleep(5)

try:
    # Click login
    print("\n[3/5] Clicking login button...")
    wait = WebDriverWait(driver, 10)
    
    # Try multiple ways to find login
    login_found = False
    for attempt in range(3):
        try:
            # Method 1: By text
            login = driver.find_element(By.XPATH, "//a[contains(text(), 'Log in')] | //button[contains(text(), 'Log in')]")
            login.click()
            login_found = True
            break
        except:
            try:
                # Method 2: By aria-label or data attribute
                login = driver.find_element(By.CSS_SELECTOR, "[data-testid='appLoginBtn'], [aria-label*='Log in']")
                login.click()
                login_found = True
                break
            except:
                time.sleep(1)
    
    if login_found:
        print("[OK] Login button clicked!")
        time.sleep(3)
        
        # Click phone login
        print("[4/5] Looking for phone login...")
        trouble = wait.until(EC.element_to_be_clickable((By.XPATH, "//button[contains(text(), 'Trouble')]")))
        trouble.click()
        print("[OK] Phone login selected!")
        time.sleep(2)
        
        # Enter phone
        print("[5/5] Entering phone number...")
        phone = wait.until(EC.presence_of_element_located((By.CSS_SELECTOR, "input[type='tel']")))
        phone.clear()
        phone.send_keys("547632418")
        print("[OK] Phone entered: 547632418")
        
        # Submit
        submit = driver.find_element(By.CSS_SELECTOR, "button[type='submit']")
        submit.click()
        print("[OK] Submitted!")
    
except Exception as e:
    print(f"\n[!]  Auto-login issue: {e}")
    print("Please login manually...")

print("\n[WAIT] WAITING 60 SECONDS for SMS code...")
print("   Enter the code when you receive it!")
time.sleep(60)

# Start swiping
print("\n" + "="*50)
print(" AUTO-SWIPING STARTED!")
print("="*50)
print("\nSwiping right every 1-2 seconds...")
print("Press CTRL+C to stop\n")

likes = 0
start = time.time()

while True:
    try:
        # Try to find and click like button
        like_clicked = False
        
        # Method 1: Like button
        try:
            like = driver.find_element(By.CSS_SELECTOR, "[aria-label='Like']")
            like.click()
            like_clicked = True
        except:
            pass
        
        # Method 2: Right arrow key
        if not like_clicked:
            body = driver.find_element(By.TAG_NAME, "body")
            body.send_keys(Keys.ARROW_RIGHT)
        
        likes += 1
        
        # Show progress
        if likes % 10 == 0:
            elapsed = time.time() - start
            rate = round(likes / (elapsed / 60), 1)
            print(f"[OK] {likes} likes ({rate}/min)")
        
        # Random delay
        time.sleep(random.uniform(1.0, 2.0))
        
    except KeyboardInterrupt:
        break
    except:
        time.sleep(1)

print(f"\n[OK] Total likes: {likes}")
driver.quit()

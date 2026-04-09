"""
TEST EMAIL SENDER
Sends a test email to YOUR OWN address to verify everything works
Run this FIRST before sending to companies
"""

import time
from pathlib import Path
from datetime import datetime
from selenium import webdriver
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC

# Configuration
YOUR_NAME = "Michael Fedorovsky"
YOUR_EMAIL = "michaelovsky5@gmail.com"
RESUME_PATH = Path(r"F:\study\resume\Michael_Fedorovsky_Resume_devops.pdf")
CHROME_USER_DATA = r"C:\Users\micha\AppData\Local\Google\Chrome\User Data"
CHROME_PROFILE = "Default"


def test_send():
    """Send test email to yourself"""
    print("\n" + "="*70)
    print("TEST EMAIL SENDER")
    print("="*70)
    print(f"\nThis will send a test email TO YOURSELF ({YOUR_EMAIL})")
    print("to verify the automation works before sending to companies.")
    print("\n" + "="*70)
    
    # Verify resume
    if not RESUME_PATH.exists():
        print(f"\n[ERROR] Resume not found: {RESUME_PATH}")
        return False
    print(f"\n[OK] Resume found: {RESUME_PATH.name}")
    
    # Start Chrome
    print("\n[1/4] Starting Chrome with your profile...")
    options = Options()
    options.add_argument(f"--user-data-dir={CHROME_USER_DATA}")
    options.add_argument(f"--profile-directory={CHROME_PROFILE}")
    options.add_argument("--no-first-run")
    options.add_argument("--no-default-browser-check")
    options.add_experimental_option('excludeSwitches', ['enable-logging'])
    
    try:
        driver = webdriver.Chrome(options=options)
        print("      [OK] Chrome started!")
    except Exception as e:
        print(f"      [ERROR] {e}")
        print("\n      Make sure Chrome is CLOSED before running!")
        return False
    
    try:
        # Go to Gmail
        print("\n[2/4] Opening Gmail...")
        driver.get("https://mail.google.com")
        time.sleep(5)
        print("      [OK] Gmail opened!")
        
        # Open compose
        print("\n[3/4] Composing test email...")
        driver.get("https://mail.google.com/mail/?view=cm")
        time.sleep(3)
        
        # Wait for compose
        WebDriverWait(driver, 20).until(
            EC.presence_of_element_located((By.CSS_SELECTOR, "input[aria-label*='To']"))
        )
        
        # Fill fields
        print("      Filling TO field...")
        to_field = driver.find_element(By.CSS_SELECTOR, "input[aria-label*='To']")
        to_field.send_keys(YOUR_EMAIL)
        time.sleep(1)
        
        print("      Filling SUBJECT...")
        subject_field = driver.find_element(By.CSS_SELECTOR, "input[name='subjectbox']")
        subject_field.send_keys(f"TEST - Job Application Automation - {datetime.now().strftime('%H:%M:%S')}")
        time.sleep(1)
        
        print("      Filling BODY...")
        body_field = driver.find_element(By.CSS_SELECTOR, "div[aria-label='Message Body']")
        body_field.click()
        body_field.send_keys("This is a test email to verify the job application automation works.\n\nIf you receive this with the resume attached, the automation is working correctly!")
        time.sleep(1)
        
        # Attach resume
        print(f"      Attaching resume: {RESUME_PATH.name}")
        file_inputs = driver.find_elements(By.CSS_SELECTOR, "input[type='file']")
        if file_inputs:
            file_inputs[0].send_keys(str(RESUME_PATH.absolute()))
        time.sleep(5)
        
        # Send
        print("\n[4/4] Sending test email...")
        send_btn = driver.find_element(By.CSS_SELECTOR, "div[aria-label*='Send']")
        send_btn.click()
        time.sleep(3)
        
        print("\n" + "="*70)
        print("[SUCCESS] TEST EMAIL SENT!")
        print("="*70)
        print(f"\nCheck your inbox at {YOUR_EMAIL}")
        print("If you see the test email with resume attached, the automation works!")
        print("\nThen run the full job application sender:")
        print('powershell -ExecutionPolicy Bypass -File "F:\\study\\Dev_Toolchain\\programming\\python\\apps\\automation\\job-auto-applicator\\run_job_applications.ps1"')
        print("\n" + "="*70)
        
        time.sleep(10)
        driver.quit()
        return True
        
    except Exception as e:
        print(f"\n[ERROR] {e}")
        driver.quit()
        return False


if __name__ == "__main__":
    test_send()

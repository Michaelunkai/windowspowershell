# Test LinkedIn login selectors
from playwright.sync_api import sync_playwright
import time

CDP_PORT = 9222

with sync_playwright() as p:
    browser = p.chromium.connect_over_cdp(f"http://127.0.0.1:{CDP_PORT}")
    context = browser.contexts[0]
    page = context.pages[0]
    
    print("Going to LinkedIn login...")
    page.goto("https://www.linkedin.com/login", timeout=20000, wait_until="domcontentloaded")
    time.sleep(3)
    
    print("\n=== PAGE CONTENT ===")
    print(f"URL: {page.url}")
    print(f"Title: {page.title()}")
    
    # Check for username field
    username_selectors = [
        '#username',
        'input[name="session_key"]',
        'input[type="text"]',
        'input[autocomplete="username"]'
    ]
    
    print("\n=== USERNAME FIELD ===")
    for sel in username_selectors:
        elem = page.query_selector(sel)
        if elem:
            print(f"✓ Found: {sel}")
            print(f"  Visible: {elem.is_visible()}")
            print(f"  Enabled: {elem.is_enabled()}")
        else:
            print(f"✗ Not found: {sel}")
    
    # Check for password field
    password_selectors = [
        '#password',
        'input[name="session_password"]',
        'input[type="password"]'
    ]
    
    print("\n=== PASSWORD FIELD ===")
    for sel in password_selectors:
        elem = page.query_selector(sel)
        if elem:
            print(f"✓ Found: {sel}")
            print(f"  Visible: {elem.is_visible()}")
            print(f"  Enabled: {elem.is_enabled()}")
        else:
            print(f"✗ Not found: {sel}")
    
    # Check for submit button
    button_selectors = [
        'button[type="submit"]',
        'button.btn__primary--large',
        '.sign-in-form__submit-btn'
    ]
    
    print("\n=== SUBMIT BUTTON ===")
    for sel in button_selectors:
        elem = page.query_selector(sel)
        if elem:
            print(f"✓ Found: {sel}")
            print(f"  Visible: {elem.is_visible()}")
            print(f"  Enabled: {elem.is_enabled()}")
            print(f"  Text: {elem.inner_text()}")
        else:
            print(f"✗ Not found: {sel}")
    
    print("\n=== SCREENSHOT ===")
    screenshot_path = "F:/study/Dev_Toolchain/programming/python/apps/automation/job-auto-applicator/login_page.png"
    page.screenshot(path=screenshot_path)
    print(f"Saved to: {screenshot_path}")
    
    input("\nPress ENTER to close...")
    page.close()

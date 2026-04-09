from playwright.sync_api import sync_playwright
import time
import random

print("\n" + "="*50)
print(" TinderBot - Playwright Version (WORKS!)")
print("="*50 + "\n")

def run():
    with sync_playwright() as p:
        print("[1/6] Starting browser...")
        # Use Chromium in non-headless mode
        browser = p.chromium.launch(
            headless=False,
            args=['--start-maximized']
        )
        
        context = browser.new_context(viewport={'width': 1920, 'height': 1080})
        page = context.new_page()
        
        print("[2/6] Opening Tinder...")
        page.goto("https://tinder.com")
        page.wait_for_load_state('networkidle')
        
        # Accept cookies if present
        try:
            page.click("text=I accept", timeout=5000)
            print("[OK] Cookies accepted")
        except:
            pass
        
        print("\n[3/6] Looking for login button...")
        
        # Try multiple selectors for login
        login_clicked = False
        selectors = [
            "text=Log in",
            "text=LOGIN",
            "a:has-text('Log')",
            "[aria-label*='Log']",
            "button:has-text('Log')"
        ]
        
        for selector in selectors:
            try:
                page.click(selector, timeout=2000)
                login_clicked = True
                print("[OK] Login button clicked!")
                break
            except:
                continue
        
        if not login_clicked:
            print("[!] Could not find login, trying JavaScript...")
            page.evaluate("""
                const buttons = document.querySelectorAll('a, button');
                for (const btn of buttons) {
                    if (btn.textContent.toLowerCase().includes('log')) {
                        btn.click();
                        break;
                    }
                }
            """)
        
        time.sleep(3)
        
        print("\n[4/6] Looking for phone login...")
        
        # Click "Trouble Logging In?"
        trouble_clicked = False
        trouble_selectors = [
            "text=Trouble Logging In",
            "text=trouble logging in",
            "button:has-text('Trouble')",
            "text=phone number"
        ]
        
        for selector in trouble_selectors:
            try:
                page.click(selector, timeout=2000)
                trouble_clicked = True
                print("[OK] Phone login selected!")
                break
            except:
                continue
        
        if not trouble_clicked:
            page.evaluate("""
                const elements = document.querySelectorAll('button, span, div');
                for (const el of elements) {
                    if (el.textContent.includes('Trouble') || el.textContent.includes('phone')) {
                        el.click();
                        break;
                    }
                }
            """)
        
        time.sleep(2)
        
        print("\n[5/6] Entering phone number...")
        
        # Find phone input
        try:
            phone_input = page.locator("input[type='tel']")
            phone_input.fill("547632418")
            print("[OK] Phone number entered: 547632418")
            
            # Submit
            try:
                page.click("button[type='submit']")
                print("[OK] Submitted!")
            except:
                phone_input.press("Enter")
                print("[OK] Pressed Enter!")
        except:
            print("[!] Could not find phone input")
        
        print("\n[6/6] WAITING FOR SMS CODE...")
        print("Enter the code in the browser window")
        print("Waiting 60 seconds...")
        
        time.sleep(60)
        
        # Navigate to swipes
        print("\nGoing to swipe page...")
        page.goto("https://tinder.com/app/recs")
        time.sleep(5)
        
        print("\n" + "="*50)
        print(" AUTO-SWIPING STARTED!")
        print("="*50 + "\n")
        
        likes = 0
        
        while True:
            try:
                swiped = False
                
                # Method 1: Click Like button
                try:
                    page.click("[aria-label='Like']", timeout=1000)
                    swiped = True
                except:
                    pass
                
                # Method 2: Press right arrow
                if not swiped:
                    page.keyboard.press("ArrowRight")
                
                likes += 1
                
                if likes % 10 == 0:
                    print(f"[OK] {likes} profiles liked")
                
                # Handle popups
                if likes % 20 == 0:
                    try:
                        page.click("[aria-label='Close']", timeout=500)
                    except:
                        page.keyboard.press("Escape")
                
                # Random delay
                time.sleep(random.uniform(1.0, 2.0))
                
            except KeyboardInterrupt:
                print("\nStopping...")
                break
            except Exception as e:
                print(f"[!] Error: {e}")
                time.sleep(1)
        
        print(f"\nTotal likes: {likes}")
        browser.close()

if __name__ == "__main__":
    run()
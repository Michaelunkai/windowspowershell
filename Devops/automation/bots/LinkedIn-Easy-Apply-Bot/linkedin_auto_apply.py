"""
LinkedIn Easy Apply Bot
Automatically applies to LinkedIn jobs using Easy Apply
Uses your existing Chrome profile (already logged into LinkedIn)
"""

import time
import json
from pathlib import Path
from datetime import datetime
from selenium import webdriver
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.common.keys import Keys
from selenium.common.exceptions import TimeoutException, NoSuchElementException

# =============================================================================
# CONFIGURATION
# =============================================================================
YOUR_NAME = "Michael Fedorovsky"
YOUR_EMAIL = "michaelovsky5@gmail.com"
YOUR_PHONE = "0547632418"
RESUME_PATH = Path(r"F:\study\resume\Michael_Fedorovsky_Resume_devops.pdf")

# Chrome profile
CHROME_USER_DATA = r"C:\Users\micha\AppData\Local\Google\Chrome\User Data"
CHROME_PROFILE = "Default"

# Job search criteria
KEYWORDS = "DevOps OR Cloud OR SysAdmin OR System Administrator"
LOCATION = "Israel"
EXPERIENCE_LEVEL = ["Entry level", "Associate"]  # Junior positions
JOB_TYPES = ["Full-time", "Contract"]

# LinkedIn search URL
LINKEDIN_JOBS_URL = f"https://www.linkedin.com/jobs/search/?keywords={KEYWORDS.replace(' ', '%20')}&location={LOCATION}&f_E=2,3&f_AL=true"  # f_E=2,3 is Entry+Associate, f_AL=true is Easy Apply only

# Tracking
TRACKING_FILE = Path(__file__).parent / "linkedin_applied.json"
MAX_APPLICATIONS = 10  # Maximum applications per run

# =============================================================================
# BOT CLASS
# =============================================================================
class LinkedInEasyApplyBot:
    def __init__(self):
        self.driver = None
        self.applied = []
        self.failed = []
        self.skipped = []
        self.history = self._load_history()
    
    def _load_history(self):
        if TRACKING_FILE.exists():
            try:
                return json.loads(TRACKING_FILE.read_text())
            except:
                return {}
        return {}
    
    def _save_history(self):
        TRACKING_FILE.write_text(json.dumps(self.history, indent=2))
    
    def _was_applied(self, job_id):
        return job_id in self.history
    
    def start_chrome(self):
        """Start Chrome with existing profile"""
        print("\n[1/5] Starting Chrome with your LinkedIn profile...")
        
        options = Options()
        options.add_argument(f"--user-data-dir={CHROME_USER_DATA}")
        options.add_argument(f"--profile-directory={CHROME_PROFILE}")
        options.add_argument("--no-first-run")
        options.add_argument("--no-default-browser-check")
        options.add_experimental_option('excludeSwitches', ['enable-logging'])
        
        try:
            self.driver = webdriver.Chrome(options=options)
            print("      [OK] Chrome started!")
            return True
        except Exception as e:
            print(f"      [ERROR] {e}")
            return False
    
    def navigate_to_jobs(self):
        """Navigate to LinkedIn jobs search"""
        print("\n[2/5] Navigating to LinkedIn jobs...")
        print(f"      Search: {KEYWORDS}")
        print(f"      Location: {LOCATION}")
        print(f"      Easy Apply only: Yes")
        
        self.driver.get(LINKEDIN_JOBS_URL)
        time.sleep(5)
        
        # Check if logged in
        if "authwall" in self.driver.current_url or "login" in self.driver.current_url:
            print("\n      [ERROR] Not logged into LinkedIn!")
            print("      Please log into LinkedIn in this Chrome profile first.")
            return False
        
        print("      [OK] LinkedIn jobs loaded!")
        return True
    
    def get_job_listings(self):
        """Get job listings from current page"""
        print("\n[3/5] Loading job listings...")
        
        try:
            # Wait for job cards to load
            WebDriverWait(self.driver, 10).until(
                EC.presence_of_element_located((By.CSS_SELECTOR, "li.jobs-search-results__list-item"))
            )
            
            job_cards = self.driver.find_elements(By.CSS_SELECTOR, "li.jobs-search-results__list-item")
            print(f"      [OK] Found {len(job_cards)} job listings")
            return job_cards
        except TimeoutException:
            print("      [ERROR] No job listings found")
            return []
    
    def apply_to_job(self, job_card):
        """Apply to a single job"""
        try:
            # Click the job card to view details
            job_card.click()
            time.sleep(2)
            
            # Get job title and company
            try:
                job_title = self.driver.find_element(By.CSS_SELECTOR, "h2.jobs-unified-top-card__job-title").text
                company = self.driver.find_element(By.CSS_SELECTOR, "a.jobs-unified-top-card__company-name").text
            except:
                job_title = "Unknown"
                company = "Unknown"
            
            print(f"\n      Job: {job_title}")
            print(f"      Company: {company}")
            
            # Get job ID
            job_url = self.driver.current_url
            job_id = job_url.split("/")[-1].split("?")[0] if "/jobs/view/" in job_url else None
            
            if not job_id:
                print("      [SKIP] Could not get job ID")
                return False
            
            # Check if already applied
            if self._was_applied(job_id):
                print("      [SKIP] Already applied")
                self.skipped.append({"title": job_title, "company": company})
                return False
            
            # Find Easy Apply button
            try:
                easy_apply_btn = WebDriverWait(self.driver, 5).until(
                    EC.presence_of_element_located((By.CSS_SELECTOR, "button.jobs-apply-button"))
                )
            except:
                print("      [SKIP] No Easy Apply button (external application)")
                return False
            
            # Click Easy Apply
            easy_apply_btn.click()
            time.sleep(2)
            
            # Fill application form
            print("      Filling application form...")
            filled = self._fill_application_form()
            
            if filled:
                # Submit
                print("      Submitting application...")
                try:
                    submit_btn = self.driver.find_element(By.CSS_SELECTOR, "button[aria-label*='Submit application'], button[aria-label*='Review'], button[aria-label*='Next']")
                    
                    # If it's a multi-step form, keep clicking Next until Submit
                    max_steps = 5
                    for step in range(max_steps):
                        btn_text = submit_btn.text.lower()
                        submit_btn.click()
                        time.sleep(2)
                        
                        if "submit" in btn_text or "review" in btn_text:
                            break
                        
                        # Find next button
                        try:
                            submit_btn = self.driver.find_element(By.CSS_SELECTOR, "button[aria-label*='Submit application'], button[aria-label*='Review'], button[aria-label*='Next']")
                        except:
                            break
                    
                    # Record success
                    self.history[job_id] = {
                        "title": job_title,
                        "company": company,
                        "date": datetime.now().isoformat(),
                        "url": job_url
                    }
                    self._save_history()
                    
                    self.applied.append({"title": job_title, "company": company})
                    print("      [APPLIED] Successfully applied!")
                    
                    # Close modal
                    try:
                        close_btn = self.driver.find_element(By.CSS_SELECTOR, "button[aria-label*='Dismiss']")
                        close_btn.click()
                    except:
                        pass
                    
                    return True
                    
                except Exception as e:
                    print(f"      [FAIL] Could not submit: {e}")
                    return False
            else:
                print("      [FAIL] Could not fill form")
                return False
                
        except Exception as e:
            print(f"      [ERROR] {e}")
            return False
    
    def _fill_application_form(self):
        """Fill Easy Apply form fields"""
        try:
            # Wait for form to load
            time.sleep(2)
            
            # Phone number
            try:
                phone_inputs = self.driver.find_elements(By.CSS_SELECTOR, "input[type='tel'], input[id*='phoneNumber']")
                for phone_input in phone_inputs:
                    if not phone_input.get_attribute("value"):
                        phone_input.clear()
                        phone_input.send_keys(YOUR_PHONE)
            except:
                pass
            
            # Resume upload
            try:
                resume_inputs = self.driver.find_elements(By.CSS_SELECTOR, "input[type='file']")
                if resume_inputs and RESUME_PATH.exists():
                    resume_inputs[0].send_keys(str(RESUME_PATH.absolute()))
                    time.sleep(2)
            except:
                pass
            
            # Additional questions (try to answer common ones)
            try:
                # Yes/No questions - default to Yes for experience/willingness
                radio_buttons = self.driver.find_elements(By.CSS_SELECTOR, "input[type='radio']")
                for radio in radio_buttons:
                    label = radio.get_attribute("value") or radio.get_attribute("aria-label") or ""
                    if "yes" in label.lower() or "1" in label:
                        radio.click()
            except:
                pass
            
            return True
            
        except Exception as e:
            print(f"      Form fill error: {e}")
            return False
    
    def run(self):
        """Main execution"""
        print("\n" + "="*70)
        print("LINKEDIN EASY APPLY BOT")
        print("="*70)
        print(f"\nApplicant: {YOUR_NAME}")
        print(f"Email: {YOUR_EMAIL}")
        print(f"Phone: {YOUR_PHONE}")
        print(f"Resume: {RESUME_PATH.name}")
        print(f"Max applications: {MAX_APPLICATIONS}")
        print("="*70)
        
        if not RESUME_PATH.exists():
            print(f"\n[ERROR] Resume not found: {RESUME_PATH}")
            return
        
        if not self.start_chrome():
            return
        
        if not self.navigate_to_jobs():
            if self.driver:
                self.driver.quit()
            return
        
        job_cards = self.get_job_listings()
        
        if not job_cards:
            print("\n[ERROR] No jobs found!")
            if self.driver:
                self.driver.quit()
            return
        
        print(f"\n[4/5] Applying to jobs...")
        print(f"      Target: {MAX_APPLICATIONS} applications")
        
        for i, job_card in enumerate(job_cards):
            if len(self.applied) >= MAX_APPLICATIONS:
                print(f"\n      [LIMIT] Reached {MAX_APPLICATIONS} applications")
                break
            
            print(f"\n{'='*70}")
            print(f"[{len(self.applied)+1}/{MAX_APPLICATIONS}] Processing job...")
            
            success = self.apply_to_job(job_card)
            
            if success:
                time.sleep(5)  # Delay between applications
        
        print(f"\n[5/5] Summary")
        print("="*70)
        print(f"APPLIED:  {len(self.applied)}")
        print(f"SKIPPED:  {len(self.skipped)}")
        print(f"FAILED:   {len(self.failed)}")
        print("="*70)
        
        if self.applied:
            print("\nApplied to:")
            for job in self.applied:
                print(f"  - {job['title']} at {job['company']}")
        
        print("\n" + "="*70)
        print("DONE! Browser will close in 30 seconds...")
        print("="*70)
        time.sleep(30)
        
        if self.driver:
            self.driver.quit()


def main():
    bot = LinkedInEasyApplyBot()
    bot.run()


if __name__ == "__main__":
    main()

"""
FULLY AUTOMATED Job Application Sender
Uses YOUR Chrome profile (already logged into Gmail)
NO MANUAL STEPS - sends emails with attachments automatically
"""

import time
import json
import os
from pathlib import Path
from datetime import datetime
from selenium import webdriver
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.chrome.service import Service
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.common.keys import Keys

# =============================================================================
# CONFIGURATION - YOUR DATA
# =============================================================================
YOUR_NAME = "Michael Fedorovsky"
YOUR_EMAIL = "michaelovsky5@gmail.com"
YOUR_PHONE = "054-763-2418"
PORTFOLIO_URL = "https://portfolio-website-psi-jade-83.vercel.app/"
GITHUB_URL = "https://github.com/Michaelunkai"
RESUME_PATH = Path(r"F:\study\resume\Michael_Fedorovsky_Resume_devops.pdf")

# Chrome profile path - ALREADY LOGGED INTO GMAIL
CHROME_USER_DATA = r"C:\Users\micha\AppData\Local\Google\Chrome\User Data"
CHROME_PROFILE = "Default"  # Profile with michaelovsky5@gmail.com

# =============================================================================
# TARGET COMPANIES - Junior DevOps/Cloud/SysAdmin in Israel
# =============================================================================
COMPANIES = [
    {"name": "Imubit", "email": "careers@imubit.com", "position": "Junior DevOps Engineer", "location": "Central Israel"},
    {"name": "Oligo Security", "email": "jobs@oligosecurity.com", "position": "DevOps Engineer", "location": "Tel Aviv"},
    {"name": "FireArc", "email": "careers@firearc.com", "position": "DevOps Engineer", "location": "Herzliya"},
    {"name": "Prologic", "email": "hr@prologic.co.il", "position": "DevOps Engineer", "location": "Ra'anana"},
    {"name": "Taldor", "email": "hr@taldor.co.il", "position": "Junior DevOps Engineer", "location": "Tel Aviv"},
    {"name": "Matrix IT", "email": "jobs@matrix.co.il", "position": "Junior DevOps Engineer", "location": "Herzliya"},
    {"name": "Ness Technologies", "email": "recruit@ness.com", "position": "DevOps Engineer", "location": "Israel"},
]

# Tracking file
TRACKING_FILE = Path(__file__).parent / "sent_applications.json"
COOLDOWN_DAYS = 7

# =============================================================================
# EMAIL TEMPLATE
# =============================================================================
EMAIL_BODY = """Dear {company} Hiring Team,

I am writing to express my interest in the {position} position.

EXPERIENCE:
- 1 year as DevOps Engineer at TovTech
- Built and maintained cloud infrastructure (AWS)
- Developed CI/CD pipelines with GitHub Actions
- Container orchestration with Docker and Kubernetes

SKILLS:
- Cloud: AWS (EC2, S3, Lambda), Azure
- Containers: Docker, Kubernetes, Docker Compose
- CI/CD: GitHub Actions, Jenkins, GitLab CI
- Monitoring: Prometheus, Grafana, ELK Stack
- Infrastructure: Nginx, Traefik, Linux Administration
- Scripting: Python, Bash, PowerShell
- IaC: Terraform, Ansible

I have 50+ projects on my GitHub demonstrating practical DevOps experience.

Contact:
- Phone: {phone}
- Email: {email}
- Portfolio: {portfolio}
- GitHub: {github}

I would welcome the opportunity to discuss how I can contribute to your team.

Best regards,
{name}"""


class ChromeGmailSender:
    """Sends emails via Gmail using existing Chrome profile"""
    
    def __init__(self):
        self.driver = None
        self.sent = []
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
    
    def _was_recently_sent(self, email):
        if email.lower() in self.history:
            last = datetime.fromisoformat(self.history[email.lower()]['date'])
            days = (datetime.now() - last).days
            if days < COOLDOWN_DAYS:
                return True, f"Sent {days} days ago"
        return False, ""
    
    def start_chrome(self):
        """Start Chrome with existing profile (already logged in)"""
        print("\n[1/4] Starting Chrome with your profile...")
        print(f"      Profile: {CHROME_PROFILE}")
        print(f"      Email: {YOUR_EMAIL}")
        
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
            print("\n      Make sure Chrome is CLOSED before running this script!")
            return False
    
    def send_email(self, company):
        """Send email via Gmail web interface"""
        try:
            # Navigate to Gmail compose
            print(f"\n      Opening Gmail compose...")
            self.driver.get("https://mail.google.com/mail/?view=cm")
            time.sleep(3)
            
            # Wait for compose window
            WebDriverWait(self.driver, 20).until(
                EC.presence_of_element_located((By.CSS_SELECTOR, "input[aria-label*='To']"))
            )
            
            # Fill TO field
            print(f"      Filling recipient: {company['email']}")
            to_field = self.driver.find_element(By.CSS_SELECTOR, "input[aria-label*='To']")
            to_field.clear()
            to_field.send_keys(company['email'])
            time.sleep(1)
            
            # Fill SUBJECT
            subject = f"Application for {company['position']} - {YOUR_NAME}"
            print(f"      Setting subject...")
            subject_field = self.driver.find_element(By.CSS_SELECTOR, "input[name='subjectbox']")
            subject_field.clear()
            subject_field.send_keys(subject)
            time.sleep(1)
            
            # Fill BODY
            print(f"      Writing email body...")
            body = EMAIL_BODY.format(
                company=company['name'],
                position=company['position'],
                name=YOUR_NAME,
                email=YOUR_EMAIL,
                phone=YOUR_PHONE,
                portfolio=PORTFOLIO_URL,
                github=GITHUB_URL
            )
            body_field = self.driver.find_element(By.CSS_SELECTOR, "div[aria-label='Message Body']")
            body_field.click()
            body_field.send_keys(body)
            time.sleep(1)
            
            # ATTACH RESUME
            print(f"      Attaching resume: {RESUME_PATH.name}")
            # Find the file input
            file_inputs = self.driver.find_elements(By.CSS_SELECTOR, "input[type='file']")
            if file_inputs:
                file_inputs[0].send_keys(str(RESUME_PATH.absolute()))
            else:
                # Click attach button and use file dialog
                attach_btn = self.driver.find_element(By.CSS_SELECTOR, "div[data-tooltip*='Attach']")
                attach_btn.click()
                time.sleep(1)
                file_input = self.driver.find_element(By.CSS_SELECTOR, "input[type='file'][name='Filedata']")
                file_input.send_keys(str(RESUME_PATH.absolute()))
            
            # Wait for upload
            print(f"      Uploading attachment...")
            time.sleep(5)
            
            # SEND
            print(f"      Sending...")
            send_btn = self.driver.find_element(By.CSS_SELECTOR, "div[aria-label*='Send']")
            send_btn.click()
            time.sleep(3)
            
            # Record success
            self.history[company['email'].lower()] = {
                'name': company['name'],
                'position': company['position'],
                'date': datetime.now().isoformat()
            }
            self._save_history()
            
            print(f"      [SENT] Email sent to {company['name']}!")
            return True
            
        except Exception as e:
            print(f"      [FAILED] {e}")
            return False
    
    def run(self):
        """Main execution"""
        print("\n" + "="*70)
        print("FULLY AUTOMATED JOB APPLICATION SENDER")
        print("="*70)
        print(f"\nApplicant: {YOUR_NAME}")
        print(f"Email: {YOUR_EMAIL}")
        print(f"Phone: {YOUR_PHONE}")
        print(f"Portfolio: {PORTFOLIO_URL}")
        print(f"Resume: {RESUME_PATH.name}")
        print(f"Companies: {len(COMPANIES)}")
        print("="*70)
        
        # Verify resume exists
        if not RESUME_PATH.exists():
            print(f"\n[ERROR] Resume not found: {RESUME_PATH}")
            return
        
        # Start Chrome
        if not self.start_chrome():
            return
        
        print("\n[2/4] Verifying Gmail login...")
        self.driver.get("https://mail.google.com")
        time.sleep(5)
        
        # Check if logged in
        if "inbox" not in self.driver.current_url.lower() and "mail.google.com" in self.driver.current_url:
            print("      [OK] Gmail is accessible!")
        
        print("\n[3/4] Sending applications...")
        
        for i, company in enumerate(COMPANIES, 1):
            print(f"\n{'='*70}")
            print(f"[{i}/{len(COMPANIES)}] {company['name']}")
            print(f"      Position: {company['position']}")
            print(f"      Location: {company['location']}")
            print(f"      Email: {company['email']}")
            
            # Check cooldown
            was_sent, reason = self._was_recently_sent(company['email'])
            if was_sent:
                print(f"      [SKIPPED] {reason}")
                self.skipped.append(company)
                continue
            
            # Send email
            if self.send_email(company):
                self.sent.append(company)
            else:
                self.failed.append(company)
            
            # Delay between emails
            if i < len(COMPANIES):
                print(f"\n      Waiting 10 seconds before next email...")
                time.sleep(10)
        
        print("\n[4/4] Summary")
        print("="*70)
        print(f"SENT:    {len(self.sent)}")
        print(f"SKIPPED: {len(self.skipped)}")
        print(f"FAILED:  {len(self.failed)}")
        print("="*70)
        
        if self.sent:
            print("\nSent to:")
            for c in self.sent:
                print(f"  - {c['name']} ({c['position']})")
        
        if self.skipped:
            print("\nSkipped (already sent recently):")
            for c in self.skipped:
                print(f"  - {c['name']}")
        
        if self.failed:
            print("\nFailed:")
            for c in self.failed:
                print(f"  - {c['name']}")
        
        print("\n" + "="*70)
        print("DONE! Browser will close in 30 seconds...")
        print("="*70)
        time.sleep(30)
        
        if self.driver:
            self.driver.quit()


def main():
    sender = ChromeGmailSender()
    sender.run()


if __name__ == "__main__":
    main()

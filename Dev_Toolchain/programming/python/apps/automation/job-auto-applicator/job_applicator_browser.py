"""
Automated Job Application System - BROWSER VERSION
Uses your existing logged-in Gmail session - NO PASSWORD NEEDED!
"""

import os
import time
import logging
from datetime import datetime
from pathlib import Path
from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.common.keys import Keys
from selenium.webdriver.chrome.service import Service
from selenium.webdriver.chrome.options import Options

# Import configuration
try:
    from config import (
        GMAIL_EMAIL, YOUR_NAME, PHONE, LOCATION, PORTFOLIO_URL, 
        RESUME_PATH, COMPANIES, MESSAGE_TEMPLATE, DELAY_BETWEEN_EMAILS
    )
except ImportError:
    print("❌ Error: config.py not found.")
    exit(1)

# Setup logging
LOG_DIR = Path(__file__).parent / "logs"
LOG_DIR.mkdir(exist_ok=True)
LOG_FILE = LOG_DIR / f"browser_applications_{datetime.now().strftime('%Y%m%d_%H%M%S')}.log"

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(LOG_FILE, encoding='utf-8'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)


class BrowserJobApplicator:
    """Sends job applications via browser automation (uses your logged-in Gmail)"""
    
    def __init__(self):
        self.email = GMAIL_EMAIL
        self.resume_path = Path(RESUME_PATH)
        self.sent_applications = []
        self.failed_applications = []
        self.driver = None
        
        self._validate_setup()
    
    def _validate_setup(self):
        """Validate configuration"""
        logger.info("🔍 Validating configuration...")
        
        if not self.resume_path.exists():
            logger.error(f"❌ Resume file not found: {self.resume_path}")
            exit(1)
        
        if not COMPANIES:
            logger.error("❌ No companies configured")
            exit(1)
        
        logger.info(f"✅ Resume: {self.resume_path.name}")
        logger.info(f"✅ Ready to apply to {len(COMPANIES)} companies")
    
    def _init_browser(self):
        """Initialize Chrome browser with your user profile"""
        logger.info("🌐 Starting Chrome browser...")
        
        chrome_options = Options()
        
        # Use your existing Chrome profile (already logged into Gmail)
        user_data_dir = os.path.expanduser(r"~\AppData\Local\Google\Chrome\User Data")
        chrome_options.add_argument(f"user-data-dir={user_data_dir}")
        chrome_options.add_argument("profile-directory=Default")
        
        # Keep browser visible
        chrome_options.add_experimental_option('excludeSwitches', ['enable-logging'])
        chrome_options.add_experimental_option('detach', True)
        
        try:
            self.driver = webdriver.Chrome(options=chrome_options)
            self.driver.maximize_window()
            logger.info("✅ Browser started successfully")
        except Exception as e:
            logger.error(f"❌ Failed to start browser: {e}")
            logger.info("💡 Make sure Chrome is installed and close all Chrome windows before running")
            exit(1)
    
    def _send_email_via_browser(self, company: dict) -> bool:
        """Send email using Gmail web interface"""
        try:
            # Open Gmail compose
            logger.info("📧 Opening Gmail compose...")
            self.driver.get("https://mail.google.com/mail/?view=cm&fs=1&tf=1")
            time.sleep(3)
            
            # Wait for compose window
            try:
                to_field = WebDriverWait(self.driver, 10).until(
                    EC.presence_of_element_located((By.CSS_SELECTOR, "textarea[name='to']"))
                )
            except:
                logger.warning("Trying alternative selector for recipient field...")
                to_field = self.driver.find_element(By.CSS_SELECTOR, "input[aria-label*='To']")
            
            # Fill recipient
            to_field.send_keys(company['email'])
            time.sleep(1)
            to_field.send_keys(Keys.ENTER)
            time.sleep(1)
            
            # Subject
            subject = f"Application for {company['position']} - {YOUR_NAME}"
            subject_field = self.driver.find_element(By.CSS_SELECTOR, "input[name='subjectbox']")
            subject_field.send_keys(subject)
            time.sleep(1)
            
            # Body
            message = MESSAGE_TEMPLATE.format(
                company_name=company['name'],
                position=company['position'],
                location=company.get('location', 'Israel')
            )
            
            body_field = self.driver.find_element(By.CSS_SELECTOR, "div[aria-label='Message Body']")
            body_field.send_keys(message)
            time.sleep(2)
            
            # Attach resume
            logger.info(f"📎 Attaching resume: {self.resume_path.name}")
            attach_button = self.driver.find_element(By.CSS_SELECTOR, "div[command='Files']")
            attach_button.click()
            time.sleep(1)
            
            # Upload file
            file_input = self.driver.find_element(By.CSS_SELECTOR, "input[type='file']")
            file_input.send_keys(str(self.resume_path.absolute()))
            
            # Wait for upload to complete
            logger.info("⏳ Waiting for file upload...")
            time.sleep(5)
            
            # Send email
            logger.info("🚀 Sending email...")
            send_button = self.driver.find_element(By.CSS_SELECTOR, "div[aria-label*='Send']")
            send_button.click()
            
            # Wait for confirmation
            time.sleep(3)
            
            logger.info(f"✅ Application sent to {company['name']} successfully!")
            return True
            
        except Exception as e:
            logger.error(f"❌ Failed to send email: {e}")
            import traceback
            logger.error(traceback.format_exc())
            return False
    
    def apply_to_company(self, company: dict) -> bool:
        """Send application to a single company"""
        logger.info(f"\n📧 Preparing application for {company['name']}...")
        logger.info(f"   Position: {company['position']}")
        logger.info(f"   Email: {company['email']}")
        
        try:
            if self._send_email_via_browser(company):
                self.sent_applications.append(company)
                return True
            else:
                self.failed_applications.append(company)
                return False
        except Exception as e:
            logger.error(f"❌ Failed to send to {company['name']}: {e}")
            self.failed_applications.append(company)
            return False
    
    def run(self):
        """Main application loop"""
        logger.info("\n" + "="*70)
        logger.info("🚀 AUTOMATED JOB APPLICATION SYSTEM (BROWSER MODE)")
        logger.info("="*70)
        logger.info(f"Applicant: {YOUR_NAME}")
        logger.info(f"Email: {self.email}")
        logger.info(f"Resume: {self.resume_path.name}")
        logger.info(f"Target Companies: {len(COMPANIES)}")
        logger.info(f"Log File: {LOG_FILE}")
        logger.info("="*70 + "\n")
        
        # Initialize browser
        self._init_browser()
        
        start_time = datetime.now()
        
        try:
            for i, company in enumerate(COMPANIES, 1):
                logger.info(f"\n📊 Progress: {i}/{len(COMPANIES)}")
                self.apply_to_company(company)
                
                # Delay between emails
                if i < len(COMPANIES):
                    logger.info(f"⏳ Waiting {DELAY_BETWEEN_EMAILS} seconds...")
                    time.sleep(DELAY_BETWEEN_EMAILS)
        
        finally:
            # Keep browser open for review
            logger.info("\n✅ All applications processed!")
            logger.info("🌐 Browser will stay open for 30 seconds for you to review...")
            time.sleep(30)
            
            if self.driver:
                self.driver.quit()
        
        # Summary
        end_time = datetime.now()
        duration = (end_time - start_time).total_seconds()
        
        logger.info("\n" + "="*70)
        logger.info("📊 FINAL SUMMARY")
        logger.info("="*70)
        logger.info(f"✅ Successful: {len(self.sent_applications)}/{len(COMPANIES)}")
        logger.info(f"❌ Failed: {len(self.failed_applications)}/{len(COMPANIES)}")
        logger.info(f"⏱️ Total Time: {int(duration)} seconds")
        
        if self.sent_applications:
            logger.info("\n✅ Successfully sent to:")
            for company in self.sent_applications:
                logger.info(f"   • {company['name']} ({company['position']})")
        
        if self.failed_applications:
            logger.info("\n❌ Failed to send to:")
            for company in self.failed_applications:
                logger.info(f"   • {company['name']} ({company['position']})")
        
        logger.info("\n" + "="*70)
        logger.info(f"📄 Full log: {LOG_FILE}")
        logger.info("="*70)


def main():
    """Entry point"""
    try:
        applicator = BrowserJobApplicator()
        applicator.run()
    except KeyboardInterrupt:
        logger.warning("\n⚠️ Interrupted by user")
        exit(0)
    except Exception as e:
        logger.error(f"\n❌ Fatal error: {e}")
        import traceback
        logger.error(traceback.format_exc())
        exit(1)


if __name__ == "__main__":
    main()

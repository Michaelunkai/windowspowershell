"""
Automated Job Application System - SIMPLE BROWSER VERSION
Opens Gmail, you login ONCE, then it sends all emails automatically
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
LOG_FILE = LOG_DIR / f"simple_applications_{datetime.now().strftime('%Y%m%d_%H%M%S')}.log"

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(LOG_FILE, encoding='utf-8'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)


class SimpleJobApplicator:
    """Sends job applications via Gmail web interface"""
    
    def __init__(self):
        self.email = GMAIL_EMAIL
        self.resume_path = Path(RESUME_PATH)
        self.sent_applications = []
        self.failed_applications = []
        self.driver = None
        self.logged_in = False
        
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
        """Initialize Chrome browser (fresh instance)"""
        logger.info("🌐 Starting Chrome browser...")
        
        chrome_options = Options()
        chrome_options.add_argument("--start-maximized")
        chrome_options.add_experimental_option('excludeSwitches', ['enable-logging'])
        
        try:
            self.driver = webdriver.Chrome(options=chrome_options)
            logger.info("✅ Browser started successfully")
        except Exception as e:
            logger.error(f"❌ Failed to start browser: {e}")
            logger.info("💡 Installing ChromeDriver...")
            from selenium.webdriver.chrome.service import Service
            from webdriver_manager.chrome import ChromeDriverManager
            
            service = Service(ChromeDriverManager().install())
            self.driver = webdriver.Chrome(service=service, options=chrome_options)
            logger.info("✅ Browser started successfully")
    
    def _login_to_gmail(self):
        """Open Gmail and wait for user to log in"""
        logger.info("📧 Opening Gmail...")
        self.driver.get("https://mail.google.com")
        
        # Wait for login
        logger.info("⏳ Please log in to Gmail in the browser window...")
        logger.info("   (Waiting up to 60 seconds)")
        
        try:
            # Wait for Gmail inbox to load (means user is logged in)
            WebDriverWait(self.driver, 60).until(
                EC.presence_of_element_located((By.CSS_SELECTOR, "div[role='button'][gh='cm']"))
            )
            self.logged_in = True
            logger.info("✅ Successfully logged in to Gmail!")
            time.sleep(2)
        except:
            logger.error("❌ Login timeout. Please try again.")
            return False
        
        return True
    
    def _send_email(self, company: dict) -> bool:
        """Send email using Gmail web interface"""
        try:
            # Click Compose button
            logger.info("📝 Clicking Compose...")
            compose_button = self.driver.find_element(By.CSS_SELECTOR, "div[role='button'][gh='cm']")
            compose_button.click()
            time.sleep(3)
            
            # Fill recipient
            logger.info(f"📧 To: {company['email']}")
            to_field = WebDriverWait(self.driver, 10).until(
                EC.presence_of_element_located((By.CSS_SELECTOR, "input[aria-label*='To']"))
            )
            to_field.send_keys(company['email'])
            time.sleep(1)
            
            # Subject
            subject = f"Application for {company['position']} - {YOUR_NAME}"
            logger.info(f"📑 Subject: {subject}")
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
            body_field.click()
            body_field.send_keys(message)
            time.sleep(2)
            
            # Attach resume
            logger.info(f"📎 Attaching: {self.resume_path.name}")
            attach_button = self.driver.find_element(By.CSS_SELECTOR, "div[data-tooltip*='Attach']")
            attach_button.click()
            time.sleep(1)
            
            file_input = self.driver.find_element(By.CSS_SELECTOR, "input[type='file'][name='Filedata']")
            file_input.send_keys(str(self.resume_path.absolute()))
            
            # Wait for upload
            logger.info("⏳ Uploading file...")
            time.sleep(6)
            
            # Send
            logger.info("🚀 Sending email...")
            send_button = self.driver.find_element(By.CSS_SELECTOR, "div[aria-label*='Send']")
            send_button.click()
            
            # Wait for confirmation
            time.sleep(4)
            
            logger.info(f"✅ Email sent to {company['name']}!")
            return True
            
        except Exception as e:
            logger.error(f"❌ Failed: {e}")
            # Take screenshot for debugging
            try:
                screenshot_path = LOG_DIR / f"error_{company['name']}_{datetime.now().strftime('%H%M%S')}.png"
                self.driver.save_screenshot(str(screenshot_path))
                logger.info(f"📸 Screenshot saved: {screenshot_path}")
            except:
                pass
            return False
    
    def apply_to_company(self, company: dict) -> bool:
        """Send application to a company"""
        logger.info(f"\n{'='*70}")
        logger.info(f"📧 Company: {company['name']}")
        logger.info(f"   Position: {company['position']}")
        logger.info(f"   Email: {company['email']}")
        logger.info(f"{'='*70}")
        
        try:
            if self._send_email(company):
                self.sent_applications.append(company)
                return True
            else:
                self.failed_applications.append(company)
                return False
        except Exception as e:
            logger.error(f"❌ Error: {e}")
            self.failed_applications.append(company)
            return False
    
    def run(self):
        """Main execution"""
        logger.info("\n" + "="*70)
        logger.info("🚀 AUTOMATED JOB APPLICATION SYSTEM")
        logger.info("="*70)
        logger.info(f"Applicant: {YOUR_NAME}")
        logger.info(f"Resume: {self.resume_path.name}")
        logger.info(f"Companies: {len(COMPANIES)}")
        logger.info("="*70 + "\n")
        
        # Start browser
        self._init_browser()
        
        # Login
        if not self._login_to_gmail():
            logger.error("❌ Failed to log in. Exiting.")
            if self.driver:
                self.driver.quit()
            return
        
        start_time = datetime.now()
        
        try:
            # Send applications
            for i, company in enumerate(COMPANIES, 1):
                logger.info(f"\n\n📊 Progress: {i}/{len(COMPANIES)}\n")
                self.apply_to_company(company)
                
                if i < len(COMPANIES):
                    logger.info(f"\n⏳ Waiting {DELAY_BETWEEN_EMAILS} seconds...\n")
                    time.sleep(DELAY_BETWEEN_EMAILS)
        
        finally:
            # Summary
            end_time = datetime.now()
            duration = (end_time - start_time).total_seconds()
            
            logger.info("\n\n" + "="*70)
            logger.info("📊 FINAL SUMMARY")
            logger.info("="*70)
            logger.info(f"✅ Successful: {len(self.sent_applications)}/{len(COMPANIES)}")
            logger.info(f"❌ Failed: {len(self.failed_applications)}/{len(COMPANIES)}")
            logger.info(f"⏱️ Time: {int(duration)} seconds")
            
            if self.sent_applications:
                logger.info("\n✅ Sent to:")
                for company in self.sent_applications:
                    logger.info(f"   • {company['name']}")
            
            if self.failed_applications:
                logger.info("\n❌ Failed:")
                for company in self.failed_applications:
                    logger.info(f"   • {company['name']}")
            
            logger.info("\n" + "="*70)
            logger.info(f"📄 Log: {LOG_FILE}")
            logger.info("="*70 + "\n")
            
            # Keep browser open
            logger.info("🌐 Keeping browser open for 30 seconds for review...")
            time.sleep(30)
            
            if self.driver:
                self.driver.quit()


def main():
    try:
        applicator = SimpleJobApplicator()
        applicator.run()
    except KeyboardInterrupt:
        logger.warning("\n⚠️ Interrupted")
        exit(0)
    except Exception as e:
        logger.error(f"\n❌ Error: {e}")
        import traceback
        logger.error(traceback.format_exc())
        exit(1)


if __name__ == "__main__":
    main()

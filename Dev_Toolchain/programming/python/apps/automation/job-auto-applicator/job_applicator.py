"""
Automated Job Application System
Sends personalized emails with resume attachments to target companies
"""

import os
import time
import logging
from datetime import datetime
from pathlib import Path
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from email.mime.application import MIMEApplication
from typing import List, Dict

# Import configuration
try:
    from config import (
        GMAIL_EMAIL, GMAIL_APP_PASSWORD, YOUR_NAME, PHONE, LOCATION,
        PORTFOLIO_URL, RESUME_PATH, COMPANIES, MESSAGE_TEMPLATE,
        DELAY_BETWEEN_EMAILS, MAX_RETRIES
    )
except ImportError:
    print("❌ Error: config.py not found. Make sure it's in the same directory.")
    exit(1)

# Setup logging
LOG_DIR = Path(__file__).parent / "logs"
LOG_DIR.mkdir(exist_ok=True)
LOG_FILE = LOG_DIR / f"applications_{datetime.now().strftime('%Y%m%d_%H%M%S')}.log"

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(LOG_FILE, encoding='utf-8'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)


class JobApplicator:
    """Handles automated job applications via email"""
    
    def __init__(self):
        self.email = GMAIL_EMAIL
        self.password = GMAIL_APP_PASSWORD.replace(" ", "")  # Remove all spaces from app password
        self.resume_path = Path(RESUME_PATH)
        self.sent_applications = []
        self.failed_applications = []
        
        # Validate setup
        self._validate_setup()
    
    def _validate_setup(self):
        """Validate configuration before starting"""
        logger.info("🔍 Validating configuration...")
        
        if self.password == "YOUR_APP_PASSWORD_HERE":
            logger.error("❌ Gmail App Password not set! Get it from: https://myaccount.google.com/apppasswords")
            exit(1)
        
        if not self.resume_path.exists():
            logger.error(f"❌ Resume file not found: {self.resume_path}")
            exit(1)
        
        if not COMPANIES:
            logger.error("❌ No companies configured in config.py")
            exit(1)
        
        logger.info(f"✅ Configuration valid. Resume: {self.resume_path.name}")
        logger.info(f"✅ Ready to apply to {len(COMPANIES)} companies")
    
    def _create_email(self, company: Dict) -> MIMEMultipart:
        """Create email with personalized message and resume attachment"""
        msg = MIMEMultipart()
        msg['From'] = self.email
        msg['To'] = company['email']
        msg['Subject'] = f"Application for {company['position']} - {YOUR_NAME}"
        
        # Personalized message body
        body = MESSAGE_TEMPLATE.format(
            company_name=company['name'],
            position=company['position'],
            location=company.get('location', 'Israel')
        )
        msg.attach(MIMEText(body, 'plain', 'utf-8'))
        
        # Attach resume
        try:
            with open(self.resume_path, 'rb') as f:
                resume = MIMEApplication(f.read(), _subtype='pdf')
                resume.add_header('Content-Disposition', 'attachment', 
                                filename=self.resume_path.name)
                msg.attach(resume)
        except Exception as e:
            logger.error(f"Failed to attach resume: {e}")
            raise
        
        return msg
    
    def _send_email(self, msg: MIMEMultipart, company: Dict, retry: int = 0) -> bool:
        """Send email via Gmail SMTP"""
        try:
            with smtplib.SMTP_SSL('smtp.gmail.com', 465) as server:
                server.set_debuglevel(0)  # Set to 1 for detailed SMTP debugging
                server.login(self.email, self.password)
                server.send_message(msg)
            return True
        except smtplib.SMTPAuthenticationError as e:
            logger.error(f"❌ Gmail authentication failed: {str(e)}")
            logger.error(f"   Email: {self.email}")
            logger.error(f"   Password length: {len(self.password)} chars")
            logger.error("   Make sure you generated an App Password at: https://myaccount.google.com/apppasswords")
            logger.error("   NOT your regular Gmail password!")
            return False
        except Exception as e:
            if retry < MAX_RETRIES:
                logger.warning(f"⚠️ Send failed (retry {retry+1}/{MAX_RETRIES}): {e}")
                time.sleep(5)
                return self._send_email(msg, company, retry + 1)
            else:
                logger.error(f"❌ Failed after {MAX_RETRIES} retries: {e}")
                return False
    
    def apply_to_company(self, company: Dict) -> bool:
        """Send application to a single company"""
        logger.info(f"\n📧 Preparing application for {company['name']}...")
        logger.info(f"   Position: {company['position']}")
        logger.info(f"   Email: {company['email']}")
        
        try:
            # Create email
            msg = self._create_email(company)
            
            # Send email
            if self._send_email(msg, company):
                logger.info(f"✅ Application sent to {company['name']} successfully!")
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
        logger.info("🚀 AUTOMATED JOB APPLICATION SYSTEM STARTED")
        logger.info("="*70)
        logger.info(f"Applicant: {YOUR_NAME}")
        logger.info(f"Email: {self.email}")
        logger.info(f"Resume: {self.resume_path.name}")
        logger.info(f"Target Companies: {len(COMPANIES)}")
        logger.info(f"Log File: {LOG_FILE}")
        logger.info("="*70 + "\n")
        
        start_time = datetime.now()
        
        for i, company in enumerate(COMPANIES, 1):
            logger.info(f"\n📊 Progress: {i}/{len(COMPANIES)}")
            self.apply_to_company(company)
            
            # Delay between emails (except last one)
            if i < len(COMPANIES):
                logger.info(f"⏳ Waiting {DELAY_BETWEEN_EMAILS} seconds before next application...")
                time.sleep(DELAY_BETWEEN_EMAILS)
        
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
        logger.info(f"📄 Full log saved to: {LOG_FILE}")
        logger.info("="*70 + "\n")
        
        if len(self.sent_applications) == len(COMPANIES):
            logger.info("🎉 ALL APPLICATIONS SENT SUCCESSFULLY! 🎉")
        elif len(self.sent_applications) > 0:
            logger.info("✅ Job application campaign completed with partial success.")
        else:
            logger.error("❌ No applications were sent. Please check the errors above.")


def main():
    """Entry point"""
    try:
        applicator = JobApplicator()
        applicator.run()
    except KeyboardInterrupt:
        logger.warning("\n\n⚠️ Application interrupted by user. Exiting...")
        exit(0)
    except Exception as e:
        logger.error(f"\n❌ Fatal error: {e}")
        import traceback
        logger.error(traceback.format_exc())
        exit(1)


if __name__ == "__main__":
    main()

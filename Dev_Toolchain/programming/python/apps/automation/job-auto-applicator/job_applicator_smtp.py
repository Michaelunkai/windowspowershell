"""
SMTP Job Application System - NO BROWSER NEEDED
Uses Gmail SMTP directly with app password
- No Selenium, no browser, no login issues
- Direct SMTP email sending
- PDF attachment support
- Duplicate tracking with 7-day cooldown
"""

import os
import json
import time
import smtplib
import logging
from datetime import datetime, timedelta
from pathlib import Path
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from email.mime.base import MIMEBase
from email import encoders

# Import configuration
try:
    from config import (
        GMAIL_EMAIL, GMAIL_APP_PASSWORD, YOUR_NAME, PHONE, LOCATION, 
        PORTFOLIO_URL, RESUME_PATH, COMPANIES, MESSAGE_TEMPLATE, 
        DELAY_BETWEEN_EMAILS
    )
except ImportError:
    print("❌ Error: config.py not found.")
    exit(1)

# Setup logging
LOG_DIR = Path(__file__).parent / "logs"
LOG_DIR.mkdir(exist_ok=True)
LOG_FILE = LOG_DIR / f"smtp_applications_{datetime.now().strftime('%Y%m%d_%H%M%S')}.log"

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(LOG_FILE, encoding='utf-8'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

# Tracking file
TRACKING_FILE = Path(__file__).parent / "sent_applications.json"
COOLDOWN_DAYS = 7

# Relevant job keywords
RELEVANT_KEYWORDS = [
    "devops", "cloud", "sysadmin", "system administrator", "infrastructure",
    "aws", "azure", "docker", "kubernetes", "k8s", "ci/cd", "jenkins",
    "junior", "entry level", "intern", "graduate"
]

# Location keywords
LOCATION_KEYWORDS = [
    "israel", "tel aviv", "jerusalem", "haifa", "remote", "hybrid",
    "bat yam", "ramat gan", "herzliya", "petah tikva", "ra'anana",
    "raanana", "rishon", "holon", "netanya", "central israel",
    "center", "north", "south"
]


class SMTPJobApplicator:
    """SMTP-based job applicator - no browser needed"""
    
    def __init__(self):
        self.email = GMAIL_EMAIL
        self.password = GMAIL_APP_PASSWORD.replace(" ", "")  # Remove spaces
        self.resume_path = Path(RESUME_PATH)
        self.sent_applications = []
        self.failed_applications = []
        self.skipped_applications = []
        self.sent_history = self._load_sent_history()
        
        self._validate_setup()
    
    def _load_sent_history(self) -> dict:
        """Load history of sent applications"""
        if TRACKING_FILE.exists():
            try:
                with open(TRACKING_FILE, 'r', encoding='utf-8') as f:
                    return json.load(f)
            except:
                return {}
        return {}
    
    def _save_sent_history(self):
        """Save sent applications history"""
        with open(TRACKING_FILE, 'w', encoding='utf-8') as f:
            json.dump(self.sent_history, f, indent=2, ensure_ascii=False)
    
    def _is_job_relevant(self, company: dict) -> tuple[bool, str]:
        """Check if job is relevant"""
        position = company.get('position', '').lower()
        location = company.get('location', '').lower()
        
        has_relevant_keywords = any(keyword in position for keyword in RELEVANT_KEYWORDS)
        if not has_relevant_keywords:
            return False, f"Position '{company['position']}' not relevant"
        
        has_relevant_location = any(loc in location for loc in LOCATION_KEYWORDS)
        if not has_relevant_location and location and location != "israel":
            return False, f"Location '{company['location']}' not relevant"
        
        return True, "Relevant job"
    
    def _was_recently_sent(self, company: dict) -> tuple[bool, str]:
        """Check if we sent to this company recently (< 7 days ago)"""
        company_key = company['email'].lower()
        
        if company_key in self.sent_history:
            last_sent = datetime.fromisoformat(self.sent_history[company_key]['date'])
            days_ago = (datetime.now() - last_sent).days
            
            if days_ago < COOLDOWN_DAYS:
                return True, f"Already sent {days_ago} days ago (cooldown: {COOLDOWN_DAYS} days)"
        
        return False, "Not sent recently"
    
    def _validate_data(self) -> tuple[bool, list]:
        """Validate all required data"""
        errors = []
        
        if not self.resume_path.exists():
            errors.append(f"Resume not found: {self.resume_path}")
        
        if not GMAIL_EMAIL or "@" not in GMAIL_EMAIL:
            errors.append("Invalid email address")
        
        if not self.password:
            errors.append("Gmail app password not configured")
        
        if not YOUR_NAME:
            errors.append("Name not configured")
        
        if not PHONE:
            errors.append("Phone not configured")
        
        if not PORTFOLIO_URL:
            errors.append("Portfolio URL not configured")
        
        if not MESSAGE_TEMPLATE or "{company_name}" not in MESSAGE_TEMPLATE:
            errors.append("Message template invalid")
        
        return len(errors) == 0, errors
    
    def _validate_setup(self):
        """Validate configuration"""
        logger.info("🔍 Validating configuration...")
        
        valid, errors = self._validate_data()
        if not valid:
            logger.error("❌ Configuration errors:")
            for error in errors:
                logger.error(f"   • {error}")
            exit(1)
        
        if not COMPANIES:
            logger.error("❌ No companies configured")
            exit(1)
        
        logger.info(f"✅ Resume: {self.resume_path.name}")
        logger.info(f"✅ Email: {self.email}")
        logger.info(f"✅ Portfolio: {PORTFOLIO_URL}")
        logger.info(f"✅ Companies: {len(COMPANIES)}")
        logger.info(f"✅ Sent history: {len(self.sent_history)} companies")
    
    def _send_email_smtp(self, company: dict) -> bool:
        """Send email via Gmail SMTP - NO BROWSER NEEDED"""
        try:
            logger.info("📧 Connecting to Gmail SMTP...")
            
            # Create message
            msg = MIMEMultipart()
            msg['From'] = f"{YOUR_NAME} <{self.email}>"
            msg['To'] = company['email']
            msg['Subject'] = f"Application for {company['position']} - {YOUR_NAME}"
            
            # Email body
            message = MESSAGE_TEMPLATE.format(
                company_name=company['name'],
                position=company['position'],
                location=company.get('location', 'Israel')
            )
            
            msg.attach(MIMEText(message, 'plain', 'utf-8'))
            
            # Attach resume PDF
            logger.info(f"📎 Attaching: {self.resume_path.name}")
            with open(self.resume_path, 'rb') as attachment:
                part = MIMEBase('application', 'octet-stream')
                part.set_payload(attachment.read())
                encoders.encode_base64(part)
                part.add_header(
                    'Content-Disposition',
                    f'attachment; filename= {self.resume_path.name}'
                )
                msg.attach(part)
            
            # Connect to Gmail SMTP
            logger.info("🔐 Authenticating...")
            server = smtplib.SMTP('smtp.gmail.com', 587)
            server.starttls()
            server.login(self.email, self.password)
            
            # Send email
            logger.info(f"🚀 Sending to {company['email']}...")
            text = msg.as_string()
            server.sendmail(self.email, company['email'], text)
            server.quit()
            
            # Record in history
            self.sent_history[company['email'].lower()] = {
                'name': company['name'],
                'position': company['position'],
                'date': datetime.now().isoformat(),
                'email': company['email']
            }
            self._save_sent_history()
            
            logger.info(f"✅ Sent successfully to {company['name']}!")
            return True
            
        except smtplib.SMTPAuthenticationError as e:
            logger.error(f"❌ Authentication failed: {e}")
            logger.error("💡 Check Gmail app password in config.py")
            return False
        except Exception as e:
            logger.error(f"❌ Failed: {e}")
            return False
    
    def apply_to_company(self, company: dict) -> str:
        """Apply to company with validation"""
        logger.info(f"\n{'='*70}")
        logger.info(f"📧 {company['name']}")
        logger.info(f"   Position: {company['position']}")
        logger.info(f"   Location: {company.get('location', 'N/A')}")
        logger.info(f"   Email: {company['email']}")
        
        # Check if job is relevant
        is_relevant, reason = self._is_job_relevant(company)
        if not is_relevant:
            logger.warning(f"⏭️ SKIPPED: {reason}")
            self.skipped_applications.append({'company': company, 'reason': reason})
            return "skipped"
        
        # Check if already sent recently
        was_sent, reason = self._was_recently_sent(company)
        if was_sent:
            logger.warning(f"⏭️ SKIPPED: {reason}")
            self.skipped_applications.append({'company': company, 'reason': reason})
            return "skipped"
        
        logger.info("✅ Validation passed")
        logger.info(f"{'='*70}")
        
        try:
            if self._send_email_smtp(company):
                self.sent_applications.append(company)
                return "sent"
            else:
                self.failed_applications.append(company)
                return "failed"
        except Exception as e:
            logger.error(f"❌ Error: {e}")
            self.failed_applications.append(company)
            return "failed"
    
    def run(self):
        """Main execution"""
        logger.info("\n" + "="*70)
        logger.info("🚀 SMTP JOB APPLICATION SYSTEM (NO BROWSER)")
        logger.info("="*70)
        logger.info(f"Applicant: {YOUR_NAME}")
        logger.info(f"Email: {self.email}")
        logger.info(f"Phone: {PHONE}")
        logger.info(f"Portfolio: {PORTFOLIO_URL}")
        logger.info(f"Resume: {self.resume_path.name}")
        logger.info(f"Companies: {len(COMPANIES)}")
        logger.info("="*70 + "\n")
        
        start_time = datetime.now()
        
        try:
            for i, company in enumerate(COMPANIES, 1):
                logger.info(f"\n📊 Progress: {i}/{len(COMPANIES)}\n")
                result = self.apply_to_company(company)
                
                if result == "sent" and i < len(COMPANIES):
                    logger.info(f"\n⏳ Waiting {DELAY_BETWEEN_EMAILS}s...\n")
                    time.sleep(DELAY_BETWEEN_EMAILS)
        
        finally:
            end_time = datetime.now()
            duration = (end_time - start_time).total_seconds()
            
            logger.info("\n\n" + "="*70)
            logger.info("📊 FINAL SUMMARY")
            logger.info("="*70)
            logger.info(f"✅ Sent: {len(self.sent_applications)}")
            logger.info(f"⏭️ Skipped: {len(self.skipped_applications)}")
            logger.info(f"❌ Failed: {len(self.failed_applications)}")
            logger.info(f"📦 Total: {len(COMPANIES)}")
            logger.info(f"⏱️ Time: {int(duration)}s")
            
            if self.sent_applications:
                logger.info("\n✅ SENT TO:")
                for company in self.sent_applications:
                    logger.info(f"   • {company['name']} ({company['position']})")
            
            if self.skipped_applications:
                logger.info("\n⏭️ SKIPPED:")
                for item in self.skipped_applications:
                    logger.info(f"   • {item['company']['name']}: {item['reason']}")
            
            if self.failed_applications:
                logger.info("\n❌ FAILED:")
                for company in self.failed_applications:
                    logger.info(f"   • {company['name']}")
            
            logger.info("\n" + "="*70)
            logger.info(f"📄 Log: {LOG_FILE}")
            logger.info(f"📊 History: {TRACKING_FILE}")
            logger.info("="*70 + "\n")


def main():
    try:
        applicator = SMTPJobApplicator()
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

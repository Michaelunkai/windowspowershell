"""
Outlook SMTP Sender - Uses Microsoft Outlook/Hotmail
Alternative to Gmail - may have easier authentication
"""

import smtplib
import json
import time
import logging
from datetime import datetime
from pathlib import Path
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from email.mime.base import MIMEBase
from email import encoders

# Setup logging
LOG_DIR = Path(__file__).parent / "logs"
LOG_DIR.mkdir(exist_ok=True)
LOG_FILE = LOG_DIR / f"outlook_applications_{datetime.now().strftime('%Y%m%d_%H%M%S')}.log"

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(LOG_FILE, encoding='utf-8'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

# Configuration
OUTLOOK_EMAIL = ""  # User fills this
OUTLOOK_PASSWORD = ""  # User fills this (regular password or app password)
YOUR_NAME = "Michael Fedorovsky"
PHONE = "054-763-2418"
PORTFOLIO_URL = "https://portfolio-website-psi-jade-83.vercel.app/"
GITHUB_URL = "https://github.com/Michaelunkai"
RESUME_PATH = Path(r"F:\study\resume\Michael_Fedorovsky_Resume_devops.pdf")

# Target companies
COMPANIES = [
    {"name": "Imubit", "email": "careers@imubit.com", "position": "Junior DevOps Engineer", "location": "Central Israel"},
    {"name": "Oligo Security", "email": "jobs@oligosecurity.com", "position": "DevOps Engineer", "location": "Tel Aviv"},
    {"name": "FireArc", "email": "careers@firearc.com", "position": "DevOps Engineer", "location": "Herzliya"},
    {"name": "Prologic", "email": "hr@prologic.co.il", "position": "DevOps Engineer", "location": "Ra'anana"},
    {"name": "Taldor", "email": "hr@taldor.co.il", "position": "Junior DevOps Engineer", "location": "Tel Aviv"},
]

MESSAGE_TEMPLATE = """Dear {company_name} Hiring Team,

I am writing to express my interest in the {position} position at {company_name}.

I am a DevOps Engineer with 1 year of experience at TovTech, where I developed and maintained cloud infrastructure and CI/CD pipelines. My technical skills include:

- Cloud: AWS (EC2, S3, Lambda), Azure
- Containers: Docker, Kubernetes
- CI/CD: GitHub Actions, Jenkins
- Monitoring: Prometheus, Grafana
- Infrastructure: Nginx, Traefik, Linux
- Scripting: Python, Bash

I have built over 50 projects on GitHub and would welcome the opportunity to contribute to {company_name}.

Best regards,
{name}
Phone: {phone}
Portfolio: {portfolio}
GitHub: {github}"""


def test_outlook_connection():
    """Test Outlook SMTP connection"""
    logger.info("Testing Outlook SMTP connection...")
    
    if not OUTLOOK_EMAIL or not OUTLOOK_PASSWORD:
        logger.error("Outlook credentials not configured")
        logger.info("\nTo use Outlook SMTP:")
        logger.info("1. Edit this file")
        logger.info("2. Fill in OUTLOOK_EMAIL (your Outlook/Hotmail address)")
        logger.info("3. Fill in OUTLOOK_PASSWORD (your password)")
        logger.info("\nNote: If you have 2FA enabled, you may need an app password")
        logger.info("Get app password: https://account.live.com/proofs/AppPassword")
        return False
    
    try:
        server = smtplib.SMTP('smtp-mail.outlook.com', 587, timeout=10)
        server.starttls()
        server.login(OUTLOOK_EMAIL, OUTLOOK_PASSWORD)
        server.quit()
        logger.info("[OK] Outlook SMTP connection successful!")
        return True
    except smtplib.SMTPAuthenticationError as e:
        logger.error(f"[FAIL] Authentication failed: {e}")
        return False
    except Exception as e:
        logger.error(f"[FAIL] Connection error: {e}")
        return False


def send_application(company):
    """Send job application via Outlook SMTP"""
    try:
        msg = MIMEMultipart()
        msg['From'] = f"{YOUR_NAME} <{OUTLOOK_EMAIL}>"
        msg['To'] = company['email']
        msg['Subject'] = f"Application for {company['position']} - {YOUR_NAME}"
        
        body = MESSAGE_TEMPLATE.format(
            company_name=company['name'],
            position=company['position'],
            name=YOUR_NAME,
            phone=PHONE,
            portfolio=PORTFOLIO_URL,
            github=GITHUB_URL
        )
        msg.attach(MIMEText(body, 'plain', 'utf-8'))
        
        # Attach resume
        with open(RESUME_PATH, 'rb') as f:
            part = MIMEBase('application', 'octet-stream')
            part.set_payload(f.read())
            encoders.encode_base64(part)
            part.add_header('Content-Disposition', f'attachment; filename={RESUME_PATH.name}')
            msg.attach(part)
        
        # Send
        server = smtplib.SMTP('smtp-mail.outlook.com', 587)
        server.starttls()
        server.login(OUTLOOK_EMAIL, OUTLOOK_PASSWORD)
        server.sendmail(OUTLOOK_EMAIL, company['email'], msg.as_string())
        server.quit()
        
        logger.info(f"[OK] Sent to {company['name']}")
        return True
    except Exception as e:
        logger.error(f"[FAIL] {company['name']}: {e}")
        return False


def main():
    logger.info("\n" + "="*70)
    logger.info("OUTLOOK SMTP JOB APPLICATOR")
    logger.info("="*70)
    
    if not test_outlook_connection():
        return
    
    sent = 0
    failed = 0
    
    for company in COMPANIES:
        logger.info(f"\nSending to {company['name']}...")
        if send_application(company):
            sent += 1
        else:
            failed += 1
        time.sleep(10)  # Delay between emails
    
    logger.info("\n" + "="*70)
    logger.info(f"DONE: Sent={sent}, Failed={failed}")
    logger.info("="*70)


if __name__ == "__main__":
    main()

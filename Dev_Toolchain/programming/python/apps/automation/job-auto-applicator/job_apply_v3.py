# -*- coding: utf-8 -*-
"""
Job Application Automation v3 - WITH AUTO-LOGIN
Searches LinkedIn, filters jobs, collects qualified opportunities.
Auto-logs in to LinkedIn and Gmail if needed.
Waits for phone verification when required.

Usage: python job_apply_v3.py 5
"""

import sys
import os
import json
import time
import re
import logging
import socket
import subprocess
import random
from datetime import datetime, timedelta
from pathlib import Path
from urllib.parse import quote

if sys.platform == 'win32':
    sys.stdout.reconfigure(encoding='utf-8')
    sys.stderr.reconfigure(encoding='utf-8')

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# CONFIG
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

PROFILE = {
    "name": "Michael Fedorovsky",
    "email": "michaelovsky5@gmail.com",
    "password": "Aa1111111!",
    "phone": "054-763-2418",
    "location": "Bat Yam, Israel",
    "portfolio": "https://portfolio-website-psi-jade-83.vercel.app/",
    "github": "https://github.com/Michaelunkai",
    "resume_path": r"F:\study\resume\Michael_Fedorovsky_Resume_devops.pdf",
}

CDP_PORT = 9222
CHROME_EXE = r"C:\Program Files\Google\Chrome\Application\chrome.exe"
CHROME_USER_DATA = os.path.expanduser("~") + r"\AppData\Local\Google\Chrome\User Data"

TITLE_DISQUALIFIERS = ["senior", "lead", "staff", "principal", "architect", "manager", "head of", "director"]
EXPERIENCE_MAX = 3
MIN_TECH_MATCH = 3

LOG_DIR = Path(__file__).parent / "logs"
LOG_DIR.mkdir(exist_ok=True)
LOG_FILE = LOG_DIR / f"jobs_{datetime.now().strftime('%Y%m%d_%H%M%S')}.log"

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[
        logging.FileHandler(LOG_FILE, encoding="utf-8"),
        logging.StreamHandler()
    ]
)
log = logging.getLogger(__name__)

STATE_FILE = Path(__file__).parent / "applied_companies.json"


def load_applied():
    if STATE_FILE.exists():
        with open(STATE_FILE, "r", encoding="utf-8") as f:
            return json.load(f)
    return {}


def save_applied(applied):
    with open(STATE_FILE, "w", encoding="utf-8") as f:
        json.dump(applied, f, indent=2, ensure_ascii=False)


def is_recently_applied(company_name, applied):
    return company_name.lower().strip() in applied


def is_title_valid(title):
    title_lower = title.lower()
    for disq in TITLE_DISQUALIFIERS:
        if disq in title_lower:
            return False
    relevant = ["devops", "cloud", "infrastructure", "platform", "sre", "site reliability", "automation"]
    return any(kw in title_lower for kw in relevant)


def check_experience(description):
    desc_lower = description.lower()
    patterns = [
        r'(\d+)\+?\s*(?:years?|yrs?)\s*(?:of)?\s*(?:experience|exp)',
        r'(?:minimum|at least|min)\s*(\d+)\s*(?:years?|yrs?)',
    ]
    for pattern in patterns:
        match = re.search(pattern, desc_lower)
        if match:
            years = int(match.group(1))
            if years > EXPERIENCE_MAX:
                return False, years
    return True, 0


def extract_tech_keywords(description):
    tech = ["docker", "kubernetes", "aws", "azure", "terraform", "ansible",
            "jenkins", "github actions", "ci/cd", "prometheus", "grafana",
            "python", "bash", "linux", "k8s", "gcp", "helm", "argocd"]
    found = [t.title() for t in tech if t in description.lower()]
    return found


def extract_email(text):
    emails = re.findall(r'[\w.+-]+@[\w-]+\.[\w.-]+', text)
    return emails[0] if emails else None


def generate_email_body(company, title, tech):
    tech_line = f"I'm particularly excited about {', '.join(tech[:3])}. " if tech else ""
    return f"""Hi {company} team,

I'm applying for the {title} position. I'm a DevOps Engineer with 1 year of production experience at TovTech, where I:
- Built CI/CD pipelines (GitHub Actions, Jenkins)
- Managed AWS and Azure infrastructure  
- Deployed Kubernetes clusters in production
- Implemented IaC with Terraform and Ansible
- Set up monitoring (Prometheus, Grafana)

{tech_line}I'm eager to contribute and grow.

Portfolio: {PROFILE['portfolio']}
GitHub: {PROFILE['github']}

Based in {PROFILE['location']}, available for remote/hybrid/on-site.

Best regards,
{PROFILE['name']}
{PROFILE['phone']}
{PROFILE['email']}"""


def is_port_open(port):
    try:
        with socket.create_connection(("127.0.0.1", port), timeout=2):
            return True
    except:
        return False


def ensure_chrome():
    """Connect to existing Chrome instance - DON'T launch new one"""
    if is_port_open(CDP_PORT):
        log.info(f"✓ Connected to existing Chrome on port {CDP_PORT}")
        return True
    
    log.error(f"❌ Chrome not running on port {CDP_PORT}")
    log.error("Launch Chrome manually with: chrome.exe --remote-debugging-port=9222")
    return False


def check_linkedin_login(page):
    """Check if logged into LinkedIn"""
    try:
        page.goto("https://www.linkedin.com/feed/", timeout=15000, wait_until="domcontentloaded")
        time.sleep(3)
        
        # If we see feed or nav, we're logged in
        if page.query_selector('nav.global-nav') or page.query_selector('[data-test-id="feed-container"]'):
            log.info("✓ Already logged into LinkedIn")
            return True
        
        return False
    except:
        return False


def login_linkedin(page):
    """Auto-login to LinkedIn"""
    log.info("🔐 Logging into LinkedIn...")
    
    try:
        page.goto("https://www.linkedin.com/login", timeout=20000, wait_until="domcontentloaded")
        time.sleep(3)
        
        # Fill email
        email_field = page.query_selector('#username')
        if email_field:
            email_field.fill(PROFILE['email'])
            time.sleep(1)
        
        # Fill password
        password_field = page.query_selector('#password')
        if password_field:
            password_field.fill(PROFILE['password'])
            time.sleep(1)
        
        # Click sign in
        sign_in_btn = page.query_selector('button[type="submit"]')
        if sign_in_btn:
            sign_in_btn.click()
            time.sleep(5)
        
        # Check for verification challenge
        if page.query_selector('[data-test-id="challenge-code-input"]') or 'checkpoint/challenge' in page.url:
            log.warning("⚠️ Phone verification required! Waiting for user to verify...")
            log.warning("⏳ Please complete verification on your phone, then press ENTER in terminal...")
            
            # Wait up to 5 minutes for verification
            for i in range(60):  # 60 x 5s = 5 minutes
                time.sleep(5)
                if 'feed' in page.url or page.query_selector('nav.global-nav'):
                    log.info("✓ Verification complete!")
                    return True
            
            log.error("❌ Verification timeout")
            return False
        
        # Check success
        time.sleep(5)
        if page.query_selector('nav.global-nav') or 'feed' in page.url:
            log.info("✓ LinkedIn login successful!")
            return True
        
        log.error("❌ LinkedIn login failed")
        return False
        
    except Exception as e:
        log.error(f"❌ LinkedIn login error: {e}")
        return False


def check_gmail_login(page):
    """Check if logged into Gmail"""
    try:
        page.goto("https://mail.google.com/mail/", timeout=15000, wait_until="domcontentloaded")
        time.sleep(3)
        
        # If we see compose or inbox, we're logged in
        if page.query_selector('[aria-label="Compose"]') or page.query_selector('[role="navigation"]'):
            log.info("✓ Already logged into Gmail")
            return True
        
        return False
    except:
        return False


def login_gmail(page):
    """Auto-login to Gmail"""
    log.info("🔐 Logging into Gmail...")
    
    try:
        page.goto("https://accounts.google.com/signin/v2/identifier?service=mail", timeout=20000, wait_until="domcontentloaded")
        time.sleep(3)
        
        # Fill email
        email_field = page.query_selector('input[type="email"]')
        if email_field:
            email_field.fill(PROFILE['email'])
            time.sleep(1)
            
            # Click next
            next_btn = page.query_selector('#identifierNext button')
            if next_btn:
                next_btn.click()
                time.sleep(4)
        
        # Fill password
        password_field = page.query_selector('input[type="password"]')
        if password_field:
            password_field.fill(PROFILE['password'])
            time.sleep(1)
            
            # Click next
            next_btn = page.query_selector('#passwordNext button')
            if next_btn:
                next_btn.click()
                time.sleep(5)
        
        # Check for 2FA
        if page.query_selector('[data-challengetype]') or 'challenge' in page.url:
            log.warning("⚠️ 2FA verification required! Waiting for user...")
            log.warning("⏳ Please complete verification on your phone, then press ENTER...")
            
            # Wait up to 5 minutes
            for i in range(60):
                time.sleep(5)
                if 'mail.google.com' in page.url:
                    log.info("✓ Verification complete!")
                    return True
            
            log.error("❌ Verification timeout")
            return False
        
        # Check success
        time.sleep(5)
        if 'mail.google.com' in page.url or page.query_selector('[aria-label="Compose"]'):
            log.info("✓ Gmail login successful!")
            return True
        
        log.error("❌ Gmail login failed")
        return False
        
    except Exception as e:
        log.error(f"❌ Gmail login error: {e}")
        return False


def collect_job_urls(page):
    """Collect job URLs from search results without navigating"""
    jobs = []
    cards = page.query_selector_all('.base-search-card')
    
    for card in cards:
        try:
            title_el = card.query_selector('.base-search-card__title')
            company_el = card.query_selector('.base-search-card__subtitle')
            link_el = card.query_selector('a.base-card__full-link')
            
            if not (title_el and company_el and link_el):
                continue
            
            title = title_el.inner_text().strip()
            company = company_el.inner_text().strip()
            url = link_el.get_attribute('href')
            
            if title and company and url:
                jobs.append({"title": title, "company": company, "url": url})
        except:
            continue
    
    return jobs


def send_gmail_batch(page, applications):
    """Send all applications via Gmail compose"""
    log.info(f"\nSending {len(applications)} applications via Gmail...")
    sent = 0
    
    for app in applications:
        try:
            subject = f"Application: {app['title']} - {PROFILE['name']}"
            body = generate_email_body(app['company'], app['title'], app['tech'])
            
            # Open Gmail compose in NEW TAB (avoid navigation conflicts)
            page.goto("https://mail.google.com/mail/u/0/#inbox", timeout=15000)
            time.sleep(2)
            
            # Click compose
            compose_btn = page.query_selector('[aria-label="Compose"], .T-I.T-I-KE')
            if compose_btn:
                compose_btn.click()
                time.sleep(2)
                
                # Fill recipient
                to_field = page.query_selector('[aria-label="To"], input[aria-autocomplete="list"]')
                if to_field:
                    to_field.fill(app['email'])
                    time.sleep(1)
                
                # Fill subject
                subject_field = page.query_selector('[aria-label="Subject"], input[name="subjectbox"]')
                if subject_field:
                    subject_field.fill(subject)
                    time.sleep(1)
                
                # Fill body
                body_field = page.query_selector('[aria-label="Message Body"], div[aria-label="Message Body"]')
                if body_field:
                    body_field.fill(body)
                    time.sleep(2)
                
                # Click send
                send_btn = page.query_selector('[aria-label="Send"], .T-I.J-J5-Ji')
                if send_btn:
                    send_btn.click()
                    time.sleep(3)
                    
                    log.info(f"  ✓ Sent to {app['company']}")
                    sent += 1
                else:
                    log.error(f"  ✗ Send button not found for {app['company']}")
            else:
                log.error(f"  ✗ Compose button not found")
            
            time.sleep(random.uniform(3, 5))
            
        except Exception as e:
            log.error(f"  Failed {app['company']}: {e}")
            continue
    
    return sent


def run(target_count):
    from playwright.sync_api import sync_playwright
    
    applied = load_applied()
    qualified_jobs = []
    evaluated = 0
    start_time = time.time()
    
    log.info("=" * 60)
    log.info("JOB APPLICATION AUTOMATION v3")
    log.info("=" * 60)
    log.info(f"  Target: {target_count}")
    log.info(f"  Profile: {PROFILE['name']}")
    log.info(f"  Already applied: {len(applied)} companies")
    
    if not ensure_chrome():
        return 0
    
    with sync_playwright() as p:
        browser = p.chromium.connect_over_cdp(f"http://127.0.0.1:{CDP_PORT}")
        context = browser.contexts[0]
        page = context.pages[0]
        
        # STEP 1: Ensure LinkedIn login
        if not check_linkedin_login(page):
            if not login_linkedin(page):
                log.error("❌ LinkedIn login required - cannot proceed")
                page.close()
                return 0
        
        # STEP 2: Ensure Gmail login
        if not check_gmail_login(page):
            if not login_gmail(page):
                log.error("❌ Gmail login required - cannot proceed")
                page.close()
                return 0
        
        # Phase 1: COLLECT job URLs
        log.info("\n=== PHASE 1: COLLECTING JOBS ===")
        
        all_jobs = []
        queries = [
            "DevOps+Engineer&location=Israel",
            "Junior+DevOps+Engineer&location=Israel",
            "Cloud+Engineer&location=Israel",
        ]
        
        for query in queries:
            try:
                url = f"https://www.linkedin.com/jobs/search?keywords={query}"
                page.goto(url, timeout=25000, wait_until="domcontentloaded")
                time.sleep(random.uniform(4, 6))
                
                jobs = collect_job_urls(page)
                all_jobs.extend(jobs)
                log.info(f"  {query}: found {len(jobs)} jobs")
                
                time.sleep(random.uniform(2, 4))
            except Exception as e:
                log.error(f"  Search failed for {query}: {e}")
                continue
        
        # Deduplicate
        seen = set()
        unique_jobs = []
        for job in all_jobs:
            key = job['company'].lower().strip()
            if key not in seen:
                seen.add(key)
                unique_jobs.append(job)
        
        log.info(f"\nTotal unique jobs: {len(unique_jobs)}")
        
        # Phase 2: EVALUATE each job
        log.info("\n=== PHASE 2: EVALUATING JOBS ===")
        
        for job in unique_jobs[:50]:  # Cap at 50
            if len(qualified_jobs) >= target_count:
                break
            
            evaluated += 1
            company = job['company']
            title = job['title']
            
            log.info(f"\n[{evaluated}] {title} @ {company}")
            
            # Filter 1: Title
            if not is_title_valid(title):
                log.info("  SKIP: title")
                continue
            
            # Filter 2: Already applied
            if is_recently_applied(company, applied):
                log.info("  SKIP: already applied")
                continue
            
            # Navigate to job page
            try:
                page.goto(job['url'], timeout=20000, wait_until="domcontentloaded")
                time.sleep(random.uniform(3, 5))
            except Exception as e:
                log.error(f"  SKIP: navigation failed - {e}")
                continue
            
            # Get description
            desc_el = page.query_selector('.show-more-less-html__markup, .description__text')
            description = desc_el.inner_text() if desc_el else ""
            
            # Filter 3: Experience
            exp_ok, exp_years = check_experience(description)
            if not exp_ok:
                log.info(f"  SKIP: {exp_years}+ years required")
                continue
            
            # Filter 4: Tech match
            tech = extract_tech_keywords(description)
            if len(tech) < MIN_TECH_MATCH:
                log.info(f"  SKIP: only {len(tech)} tech matches")
                continue
            
            # Find email
            email = extract_email(description)
            if not email:
                company_clean = re.sub(r'[^a-z]', '', company.lower())
                email = f"jobs@{company_clean}.com"
            
            log.info(f"  QUALIFIED! Skills: {', '.join(tech[:5])}")
            log.info(f"  Email: {email}")
            
            qualified_jobs.append({
                "company": company,
                "title": title,
                "url": job['url'],
                "email": email,
                "tech": tech,
                "description": description[:500],
            })
            
            time.sleep(random.uniform(2, 4))
        
        # Phase 3: APPLY via Gmail
        log.info(f"\n=== PHASE 3: APPLYING ({len(qualified_jobs)} jobs) ===")
        
        if qualified_jobs:
            sent = send_gmail_batch(page, qualified_jobs)
            
            # Update applied state
            for app in qualified_jobs[:sent]:
                applied[app['company'].lower().strip()] = {
                    "date": datetime.now().isoformat(),
                    "title": app['title'],
                    "email": app['email'],
                }
            save_applied(applied)
        else:
            sent = 0
            log.warning("No qualified jobs found!")
        
        page.close()
    
    # Summary
    elapsed = (time.time() - start_time) / 60
    log.info("")
    log.info("=" * 60)
    log.info("SESSION COMPLETE")
    log.info("=" * 60)
    log.info(f"  Duration: {elapsed:.1f} min")
    log.info(f"  Evaluated: {evaluated}")
    log.info(f"  Qualified: {len(qualified_jobs)}")
    log.info(f"  Sent: {sent}/{target_count}")
    log.info(f"  Log: {LOG_FILE}")
    log.info("=" * 60)
    
    return sent


def main():
    if len(sys.argv) < 2:
        print("Usage: python job_apply_v3.py [NUMBER]")
        sys.exit(1)
    
    target = int(sys.argv[1])
    if not (1 <= target <= 50):
        print("Target must be 1-50")
        sys.exit(1)
    
    result = run(target)
    
    print(f"\n{'SUCCESS' if result >= target else 'PARTIAL'}: {result}/{target} applications")
    sys.exit(0 if result >= target else 1)


if __name__ == "__main__":
    main()

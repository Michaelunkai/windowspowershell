# -*- coding: utf-8 -*-
"""
Auto Job Applicator v3.0 - Public LinkedIn + Gmail Browser
No LinkedIn login needed! Searches public job listings, then applies via:
1. Company career page forms
2. Gmail browser compose (using your logged-in Gmail session)

Setup:
  1. Close Chrome
  2. Run: start_chrome.bat  (or the script auto-launches Chrome with CDP)
  3. Run: python job_apply.py 5

Usage: python job_apply.py [NUMBER]
"""

import sys
import os
import json
import time
import re
import logging
import socket
import subprocess
from datetime import datetime, timedelta
from pathlib import Path
from urllib.parse import quote_plus, quote

# Fix Windows encoding
if sys.platform == 'win32':
    sys.stdout.reconfigure(encoding='utf-8')
    sys.stderr.reconfigure(encoding='utf-8')

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# CONFIGURATION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

PROFILE = {
    "name": "Michael Fedorovsky",
    "email": "michaelovsky5@gmail.com",
    "phone": "0547632418",
    "phone_formatted": "054-763-2418",
    "location": "Bat Yam, Israel",
    "portfolio": "https://portfolio-website-psi-jade-83.vercel.app/",
    "github": "https://github.com/Michaelunkai",
    "resume_path": r"F:\study\resume\Michael_Fedorovsky_Resume_devops.pdf",
    "experience_years": 1,
}

CDP_PORT = 9222
CHROME_EXE = r"C:\Program Files\Google\Chrome\Application\chrome.exe"
CHROME_USER_DATA = os.path.expanduser("~") + r"\AppData\Local\Google\Chrome\User Data"
CHROME_PROFILE = "Default"

TITLE_DISQUALIFIERS = ["senior", "lead", "staff", "principal", "architect", "manager", "head of", "director"]
EXPERIENCE_MAX = 3

LOG_DIR = Path(__file__).parent / "logs"
LOG_DIR.mkdir(exist_ok=True)
LOG_FILE = LOG_DIR / f"apply_{datetime.now().strftime('%Y%m%d_%H%M%S')}.log"

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


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# HELPERS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

def load_applied():
    if STATE_FILE.exists():
        with open(STATE_FILE, "r", encoding="utf-8") as f:
            return json.load(f)
    return {}


def save_applied(applied):
    with open(STATE_FILE, "w", encoding="utf-8") as f:
        json.dump(applied, f, indent=2, ensure_ascii=False)


def is_recently_applied(company_name, applied, days=7):
    company_key = company_name.lower().strip()
    if company_key in applied:
        applied_date = datetime.fromisoformat(applied[company_key]["date"])
        if datetime.now() - applied_date < timedelta(days=days):
            return True
    return False


def is_title_valid(title):
    title_lower = title.lower()
    for disq in TITLE_DISQUALIFIERS:
        if disq in title_lower:
            return False
    relevant = ["devops", "cloud", "infrastructure", "platform", "sre", "site reliability", "automation"]
    return any(kw in title_lower for kw in relevant)


def check_experience_requirement(description):
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
            return True, years
    return True, 0


def extract_tech_keywords(description):
    tech_checks = ["docker", "kubernetes", "aws", "azure", "terraform", "ansible",
                   "jenkins", "github actions", "ci/cd", "prometheus", "grafana",
                   "python", "bash", "linux", "k8s", "gcp", "helm", "argocd",
                   "gitlab", "circleci", "datadog", "elk", "nginx"]
    found = []
    desc_lower = description.lower()
    for tech in tech_checks:
        if tech in desc_lower:
            found.append(tech.title())
    return found


def generate_email_body(company_name, job_title, tech_keywords=None):
    tech_mention = ""
    if tech_keywords:
        tech_mention = f"I'm particularly excited about working with {', '.join(tech_keywords[:3])}. "
    
    return f"""Hi {company_name} team,

I'm writing to apply for the {job_title} position. I'm a DevOps Engineer with 1 year of production experience at TovTech, where I built CI/CD pipelines with GitHub Actions, managed AWS and Azure cloud infrastructure, and deployed production Kubernetes clusters.

{tech_mention}I'm eager to contribute my expertise in Docker, Terraform, and cloud automation.

Key highlights:
- Production CI/CD (GitHub Actions, Jenkins)
- AWS and Azure infrastructure management
- Kubernetes cluster deployment
- Infrastructure as Code (Terraform, Ansible)
- Monitoring (Prometheus, Grafana)

Portfolio: {PROFILE['portfolio']}
GitHub: {PROFILE['github']}

Based in Bat Yam, Israel. Available for remote, hybrid, or on-site.

Best regards,
Michael Fedorovsky
Phone: {PROFILE['phone_formatted']}
Email: {PROFILE['email']}"""


def is_port_open(port):
    try:
        with socket.create_connection(("127.0.0.1", port), timeout=2):
            return True
    except:
        return False


def ensure_chrome_running():
    if is_port_open(CDP_PORT):
        log.info(f"Chrome CDP already running on port {CDP_PORT}")
        return True
    
    log.info("Launching Chrome with CDP...")
    subprocess.run(["taskkill", "/F", "/IM", "chrome.exe"], capture_output=True, timeout=10)
    time.sleep(2)
    
    subprocess.Popen([
        CHROME_EXE,
        f"--remote-debugging-port={CDP_PORT}",
        f"--user-data-dir={CHROME_USER_DATA}",
        f"--profile-directory={CHROME_PROFILE}",
        "--no-first-run",
        "--no-default-browser-check",
        "--start-maximized",
    ], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    
    for i in range(15):
        time.sleep(1)
        if is_port_open(CDP_PORT):
            log.info(f"Chrome ready (took {i+1}s)")
            return True
    
    log.error("Chrome failed to start")
    return False


def send_gmail_browser(page, to_email, company_name, job_title, tech_keywords):
    """Send email via Gmail compose in the browser (uses logged-in session)"""
    subject = f"Application: {job_title} - {PROFILE['name']}"
    body = generate_email_body(company_name, job_title, tech_keywords)
    
    # Build Gmail compose URL
    params = f"view=cm&to={quote(to_email)}&su={quote(subject)}&body={quote(body)}"
    gmail_url = f"https://mail.google.com/mail/?{params}"
    
    try:
        page.goto(gmail_url, timeout=20000, wait_until="domcontentloaded")
        time.sleep(4)
        
        # Check if Gmail loaded (may need login)
        if "accounts.google.com" in page.url:
            log.warning("  Gmail requires login - skipping email method")
            return False
        
        # Wait for compose window
        time.sleep(2)
        
        # Try to attach resume
        file_input = page.query_selector('input[type="file"][name="Filedata"]')
        if file_input:
            resume = Path(PROFILE['resume_path'])
            if resume.exists():
                file_input.set_input_files(str(resume))
                log.info("  Resume attached")
                time.sleep(2)
        
        # Click Send button
        send_btn = None
        for sel in [
            'div[aria-label*="Send"][role="button"]',
            'div[data-tooltip*="Send"]',
            'div.T-I.J-J5-Ji.aoO.v7.T-I-atl.L3',
        ]:
            btn = page.query_selector(sel)
            if btn:
                send_btn = btn
                break
        
        if send_btn:
            send_btn.click()
            time.sleep(3)
            log.info(f"  Email sent to {to_email}!")
            return True
        else:
            # Try keyboard shortcut: Ctrl+Enter
            page.keyboard.press("Control+Enter")
            time.sleep(3)
            log.info(f"  Email sent (via Ctrl+Enter) to {to_email}")
            return True
    
    except Exception as e:
        log.error(f"  Gmail compose failed: {e}")
        return False


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# MAIN APPLICATION LOGIC
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

def run_applications(target_count):
    from playwright.sync_api import sync_playwright
    
    applied = load_applied()
    successful = 0
    evaluated = 0
    skipped_senior = 0
    skipped_duplicate = 0
    skipped_skills = 0
    start_time = time.time()
    max_time = target_count * 5 * 60
    
    log.info("=" * 55)
    log.info("JOB APPLICATION AUTOMATION STARTED")
    log.info("=" * 55)
    log.info(f"  Target: {target_count} applications")
    log.info(f"  Time limit: {max_time // 60} minutes")
    log.info(f"  Profile: {PROFILE['name']}")
    log.info(f"  Resume: {PROFILE['resume_path']}")
    log.info(f"  Previously applied: {len(applied)} companies")
    
    if not ensure_chrome_running():
        return 0
    
    time.sleep(2)
    
    with sync_playwright() as p:
        log.info(f"Connecting to Chrome CDP port {CDP_PORT}...")
        
        try:
            browser = p.chromium.connect_over_cdp(f"http://127.0.0.1:{CDP_PORT}")
            log.info("Connected to Chrome!")
        except Exception as e:
            log.error(f"Cannot connect: {e}")
            return 0
        
        ctx = browser.contexts[0]
        page = ctx.new_page()
        
        # Search queries for public LinkedIn
        search_queries = [
            "DevOps+Engineer&location=Israel",
            "Junior+DevOps+Engineer&location=Israel",
            "Cloud+Engineer&location=Israel",
            "DevOps+Engineer&location=Tel+Aviv",
            "Infrastructure+Engineer&location=Israel",
        ]
        
        seen_companies = set()
        
        for q_idx, query in enumerate(search_queries):
            if successful >= target_count:
                break
            if time.time() - start_time > max_time:
                log.warning("Time limit reached!")
                break
            
            log.info(f"\nSearch {q_idx + 1}/{len(search_queries)}: {query}")
            
            search_url = f"https://www.linkedin.com/jobs/search?keywords={query}"
            
            try:
                page.goto(search_url, timeout=30000, wait_until="domcontentloaded")
                time.sleep(5)
            except Exception as e:
                log.error(f"  Search failed: {e}")
                continue
            
            # Get job cards (public LinkedIn selectors)
            cards = page.query_selector_all('.base-search-card')
            log.info(f"  Found {len(cards)} job listings")
            
            if not cards:
                continue
            
            for card_idx, card in enumerate(cards[:25]):
                if successful >= target_count:
                    break
                if time.time() - start_time > max_time:
                    break
                
                try:
                    # Extract info from card
                    title_el = card.query_selector('.base-search-card__title')
                    company_el = card.query_selector('.base-search-card__subtitle a, .base-search-card__subtitle')
                    location_el = card.query_selector('.job-search-card__location')
                    link_el = card.query_selector('a.base-card__full-link')
                    
                    job_title = title_el.inner_text().strip() if title_el else ""
                    company_name = company_el.inner_text().strip() if company_el else ""
                    job_location = location_el.inner_text().strip() if location_el else ""
                    job_url = link_el.get_attribute('href') if link_el else ""
                    
                    if not job_title or not company_name:
                        continue
                    
                    # Deduplicate
                    company_key = company_name.lower().strip()
                    if company_key in seen_companies:
                        continue
                    seen_companies.add(company_key)
                    
                    evaluated += 1
                    log.info(f"\n[{evaluated}] {job_title} @ {company_name} ({job_location})")
                    
                    # CHECK 1: Title
                    if not is_title_valid(job_title):
                        log.info("  SKIP: title disqualified (senior/lead/non-DevOps)")
                        skipped_senior += 1
                        continue
                    
                    # CHECK 2: Already applied
                    if is_recently_applied(company_name, applied):
                        log.info("  SKIP: already applied recently")
                        skipped_duplicate += 1
                        continue
                    
                    # Navigate to job detail page
                    if not job_url:
                        continue
                    
                    page.goto(job_url, timeout=20000, wait_until="domcontentloaded")
                    time.sleep(3)
                    
                    # Get description
                    desc_el = page.query_selector('.show-more-less-html__markup, .description__text, .decorated-job-posting__details')
                    description = desc_el.inner_text() if desc_el else ""
                    
                    # CHECK 3: Experience
                    exp_ok, exp_years = check_experience_requirement(description)
                    if not exp_ok:
                        log.info(f"  SKIP: requires {exp_years}+ years")
                        skipped_senior += 1
                        continue
                    
                    # CHECK 4: Skill match
                    tech_keywords = extract_tech_keywords(description)
                    if len(tech_keywords) < 2:
                        log.info(f"  SKIP: only {len(tech_keywords)} skill matches")
                        skipped_skills += 1
                        continue
                    
                    log.info(f"  PASSED! Skills: {', '.join(tech_keywords[:5])}")
                    
                    # Find apply button/link
                    apply_el = page.query_selector('a.apply-button, a[data-tracking-control-name*="apply"], a.topcard__org-name-link')
                    apply_url = apply_el.get_attribute('href') if apply_el else None
                    
                    # Extract company email from description
                    email_pattern = r'[\w.+-]+@[\w-]+\.[\w.-]+'
                    emails_found = re.findall(email_pattern, description)
                    
                    # Strategy: Send application email via Gmail browser
                    # Build a suitable recipient email
                    target_email = None
                    
                    if emails_found:
                        target_email = emails_found[0]
                        log.info(f"  Found email in description: {target_email}")
                    else:
                        # Try common patterns
                        company_domain = None
                        # Look for company website link
                        website_link = page.query_selector('a[data-tracking-control-name="public_jobs_topcard-org-name"]')
                        if website_link:
                            href = website_link.get_attribute('href') or ""
                            # Extract domain from LinkedIn company URL
                            log.info(f"  Company link: {href[:60]}")
                        
                        # Use common email patterns
                        company_clean = re.sub(r'[^a-zA-Z]', '', company_name.lower())
                        common_emails = [
                            f"jobs@{company_clean}.com",
                            f"careers@{company_clean}.com",
                            f"hr@{company_clean}.com",
                        ]
                        target_email = common_emails[0]
                        log.info(f"  Using guessed email: {target_email}")
                    
                    # Send via Gmail browser compose
                    log.info(f"  Sending application email via Gmail...")
                    if send_gmail_browser(page, target_email, company_name, job_title, tech_keywords):
                        successful += 1
                        applied[company_key] = {
                            "date": datetime.now().isoformat(),
                            "title": job_title,
                            "method": "Gmail Browser",
                            "company": company_name,
                            "email": target_email,
                            "location": job_location,
                            "url": job_url,
                        }
                        save_applied(applied)
                        log.info(f"  >>> APPLICATION {successful}/{target_count}: {company_name} - {job_title}")
                        
                        # Navigate back to search results
                        page.goto(search_url, timeout=20000, wait_until="domcontentloaded")
                        time.sleep(3)
                    else:
                        log.warning(f"  Gmail send failed for {company_name}")
                
                except Exception as e:
                    log.error(f"  Error on card {card_idx}: {e}")
                    # Try to go back to search
                    try:
                        page.goto(search_url, timeout=20000, wait_until="domcontentloaded")
                        time.sleep(3)
                    except:
                        pass
                    continue
                
                # Progress
                if successful > 0 and successful % 2 == 0:
                    elapsed_min = (time.time() - start_time) / 60
                    log.info(f"\n>>> PROGRESS: {successful}/{target_count} | {elapsed_min:.1f}m elapsed")
        
        page.close()
    
    total_time = time.time() - start_time
    
    log.info("")
    log.info("=" * 55)
    log.info("JOB APPLICATION SESSION COMPLETE")
    log.info("=" * 55)
    log.info(f"  Date: {datetime.now().strftime('%Y-%m-%d %H:%M')}")
    log.info(f"  Duration: {total_time / 60:.1f} minutes")
    log.info(f"  Target: {target_count}")
    log.info(f"  Submitted: {successful}/{target_count}")
    log.info(f"  Jobs evaluated: {evaluated}")
    log.info(f"  Skipped (senior/exp): {skipped_senior}")
    log.info(f"  Skipped (duplicate): {skipped_duplicate}")
    log.info(f"  Skipped (low skill): {skipped_skills}")
    log.info(f"  Log: {LOG_FILE}")
    log.info("=" * 55)
    
    save_applied(applied)
    return successful


def main():
    if len(sys.argv) < 2:
        print("Usage: python job_apply.py [NUMBER]")
        print("Example: python job_apply.py 5")
        sys.exit(1)
    
    try:
        target = int(sys.argv[1])
    except ValueError:
        print(f"Error: '{sys.argv[1]}' is not a number")
        sys.exit(1)
    
    if target < 1 or target > 50:
        print("Error: target must be 1-50")
        sys.exit(1)
    
    result = run_applications(target)
    
    if result >= target:
        print(f"\nSUCCESS: {result}/{target} applications submitted!")
    else:
        print(f"\nPARTIAL: {result}/{target} applications submitted")
    
    sys.exit(0 if result >= target else 1)


if __name__ == "__main__":
    main()

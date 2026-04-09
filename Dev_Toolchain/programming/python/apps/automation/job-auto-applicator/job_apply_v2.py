# -*- coding: utf-8 -*-
"""
Job Application Automation v2 - Collect First, Apply Later
Searches LinkedIn, filters jobs, collects qualified opportunities.
Then applies via Gmail browser compose (batch mode).

Usage: python job_apply_v2.py 5
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
            
            params = f"view=cm&to={quote(app['email'])}&su={quote(subject)}&body={quote(body)}"
            gmail_url = f"https://mail.google.com/mail/?{params}"
            
            page.goto(gmail_url, timeout=15000, wait_until="domcontentloaded")
            time.sleep(3)
            
            if "accounts.google.com" in page.url:
                log.warning("  Gmail login required - stopping batch send")
                break
            
            # Attach resume
            file_input = page.query_selector('input[type="file"]')
            if file_input:
                resume = Path(PROFILE['resume_path'])
                if resume.exists():
                    file_input.set_input_files(str(resume))
                    time.sleep(2)
            
            # Send
            page.keyboard.press("Control+Enter")
            time.sleep(2)
            
            sent += 1
            log.info(f"  [{sent}/{len(applications)}] Sent to {app['company']}")
            
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
    log.info("JOB APPLICATION AUTOMATION v2")
    log.info("=" * 60)
    log.info(f"  Target: {target_count}")
    log.info(f"  Profile: {PROFILE['name']}")
    log.info(f"  Already applied: {len(applied)} companies")
    
    if not ensure_chrome():
        log.error("Chrome failed to start")
        return 0
    
    time.sleep(2)
    
    with sync_playwright() as p:
        try:
            browser = p.chromium.connect_over_cdp(f"http://127.0.0.1:{CDP_PORT}")
            ctx = browser.contexts[0]
            page = ctx.new_page()
        except Exception as e:
            log.error(f"CDP connect failed: {e}")
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
        print("Usage: python job_apply_v2.py [NUMBER]")
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

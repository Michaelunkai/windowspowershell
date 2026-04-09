"""
Gmail Browser Sender - Uses existing browser session
Sends emails via Gmail web interface - NO APP PASSWORD NEEDED
Works because you're already logged into Gmail in your browser
"""

import webbrowser
import time
import urllib.parse
from pathlib import Path

# Configuration - YOUR DATA
YOUR_NAME = "Michael Fedorovsky"
YOUR_EMAIL = "michaelovsky5@gmail.com"
YOUR_PHONE = "054-763-2418"
PORTFOLIO_URL = "https://portfolio-website-psi-jade-83.vercel.app/"
GITHUB_URL = "https://github.com/Michaelunkai"
RESUME_PATH = Path(r"F:\study\resume\Michael_Fedorovsky_Resume_devops.pdf")

# Target companies - relevant junior DevOps/Cloud/SysAdmin positions
COMPANIES = [
    {
        "name": "Imubit",
        "email": "careers@imubit.com",
        "position": "Junior DevOps Engineer",
        "location": "Central Israel"
    },
    {
        "name": "Oligo Security",
        "email": "jobs@oligosecurity.com", 
        "position": "DevOps Engineer",
        "location": "Tel Aviv"
    },
    {
        "name": "FireArc",
        "email": "careers@firearc.com",
        "position": "DevOps Engineer",
        "location": "Herzliya"
    },
    {
        "name": "Prologic",
        "email": "hr@prologic.co.il",
        "position": "DevOps Engineer", 
        "location": "Ra'anana"
    },
    {
        "name": "Taldor",
        "email": "hr@taldor.co.il",
        "position": "Junior DevOps Engineer",
        "location": "Tel Aviv"
    },
    {
        "name": "Matrix",
        "email": "jobs@matrix.co.il",
        "position": "Junior DevOps Engineer",
        "location": "Herzliya"
    },
    {
        "name": "Ness Technologies",
        "email": "recruit@ness.com",
        "position": "DevOps Engineer",
        "location": "Israel"
    }
]


def create_email_body(company):
    """Create personalized email body"""
    return f"""Dear {company['name']} Hiring Team,

I am writing to express my interest in the {company['position']} position at {company['name']}.

I am a DevOps Engineer with 1 year of experience at TovTech, where I developed and maintained cloud infrastructure and CI/CD pipelines. My technical skills include:

- Cloud: AWS (EC2, S3, Lambda, CloudFormation), Azure
- Containers: Docker, Kubernetes, Docker Compose
- CI/CD: GitHub Actions, Jenkins, GitLab CI
- Monitoring: Prometheus, Grafana, ELK Stack
- Infrastructure: Nginx, Traefik, Linux Administration
- Scripting: Python, Bash, PowerShell
- IaC: Terraform, Ansible

I have built over 50 projects showcased on my GitHub ({GITHUB_URL}) and portfolio ({PORTFOLIO_URL}).

I am excited about the opportunity to contribute to {company['name']} and would welcome the chance to discuss how my skills align with your needs.

Best regards,
{YOUR_NAME}
Email: {YOUR_EMAIL}
Phone: {YOUR_PHONE}
Portfolio: {PORTFOLIO_URL}
GitHub: {GITHUB_URL}

P.S. My resume is attached. I would be happy to provide any additional information."""


def create_gmail_compose_url(company):
    """Create Gmail compose URL with pre-filled fields"""
    subject = f"Application for {company['position']} - {YOUR_NAME}"
    body = create_email_body(company)
    
    # URL encode
    params = {
        'to': company['email'],
        'su': subject,
        'body': body
    }
    
    query = urllib.parse.urlencode(params)
    return f"https://mail.google.com/mail/?view=cm&{query}"


def open_all_compose_windows():
    """Open Gmail compose windows for all companies"""
    print("\n" + "="*70)
    print("GMAIL BROWSER SENDER - NO APP PASSWORD NEEDED")
    print("="*70)
    print(f"\nApplicant: {YOUR_NAME}")
    print(f"Email: {YOUR_EMAIL}")
    print(f"Phone: {YOUR_PHONE}")
    print(f"Portfolio: {PORTFOLIO_URL}")
    print(f"Resume: {RESUME_PATH.name}")
    print(f"\nTarget: {len(COMPANIES)} companies")
    print("="*70)
    
    print("\n[INFO] This will open Gmail compose windows for each company.")
    print("[INFO] Your browser will open with pre-filled emails.")
    print("[INFO] YOU MUST:")
    print("       1. Attach your resume manually (click the paperclip icon)")
    print("       2. Review the email")
    print("       3. Click SEND")
    print("\n[INFO] The compose windows will open one by one.")
    print("[INFO] Make sure you're logged into Gmail in your browser!")
    print("="*70)
    
    input("\nPress ENTER to start opening compose windows...")
    
    for i, company in enumerate(COMPANIES, 1):
        print(f"\n[{i}/{len(COMPANIES)}] Opening compose for {company['name']}...")
        print(f"    Position: {company['position']}")
        print(f"    Email: {company['email']}")
        
        url = create_gmail_compose_url(company)
        webbrowser.open(url)
        
        print(f"    [OK] Compose window opened!")
        print(f"\n    ATTACH: {RESUME_PATH}")
        print("    Then click SEND")
        
        if i < len(COMPANIES):
            input(f"\n    Press ENTER when you've sent this email to open the next...")
    
    print("\n" + "="*70)
    print("[DONE] All compose windows opened!")
    print("="*70)
    print(f"\nTotal emails to send: {len(COMPANIES)}")
    print("\nREMINDER:")
    print("  1. Make sure each email has your resume attached")
    print("  2. Review the content before sending")
    print("  3. Click SEND on each one")
    print("\n" + "="*70)


if __name__ == "__main__":
    import sys
    if sys.platform == "win32":
        try:
            sys.stdout.reconfigure(encoding='utf-8')
        except:
            pass
    
    open_all_compose_windows()

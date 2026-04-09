"""
Browser Job Application System - WORKS WITHOUT ANY SETUP
Opens pre-filled Gmail compose windows in your browser
Uses your existing Gmail login - NO APP PASSWORD NEEDED
"""

import webbrowser
import urllib.parse
import time
from pathlib import Path

# Configuration
YOUR_NAME = "Michael Fedorovsky"
YOUR_EMAIL = "michaelovsky5@gmail.com"
YOUR_PHONE = "054-763-2418"
PORTFOLIO_URL = "https://portfolio-website-psi-jade-83.vercel.app/"
GITHUB_URL = "https://github.com/Michaelunkai"
RESUME_PATH = r"F:\study\resume\Michael_Fedorovsky_Resume_devops.pdf"

# Companies - relevant junior DevOps positions in Israel
COMPANIES = [
    {"name": "Imubit", "email": "careers@imubit.com", "position": "Junior DevOps Engineer", "location": "Central Israel"},
    {"name": "Oligo Security", "email": "jobs@oligosecurity.com", "position": "DevOps Engineer", "location": "Tel Aviv"},
    {"name": "FireArc", "email": "careers@firearc.com", "position": "DevOps Engineer", "location": "Herzliya"},
    {"name": "Prologic", "email": "hr@prologic.co.il", "position": "DevOps Engineer", "location": "Ra'anana"},
    {"name": "Taldor", "email": "hr@taldor.co.il", "position": "Junior DevOps Engineer", "location": "Tel Aviv"},
    {"name": "Matrix IT", "email": "jobs@matrix.co.il", "position": "Junior DevOps Engineer", "location": "Herzliya"},
    {"name": "Ness Technologies", "email": "recruit@ness.com", "position": "DevOps Engineer", "location": "Israel"}
]

MESSAGE = """Dear {company} Hiring Team,

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
- Infrastructure: Nginx, Traefik, Linux
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
{name}

Note: Resume attached."""


def open_compose(company):
    """Open Gmail compose with pre-filled content"""
    subject = f"Application for {company['position']} - {YOUR_NAME}"
    body = MESSAGE.format(
        company=company['name'],
        position=company['position'],
        name=YOUR_NAME,
        email=YOUR_EMAIL,
        phone=YOUR_PHONE,
        portfolio=PORTFOLIO_URL,
        github=GITHUB_URL
    )
    
    params = urllib.parse.urlencode({
        'view': 'cm',
        'to': company['email'],
        'su': subject,
        'body': body
    })
    
    url = f"https://mail.google.com/mail/?{params}"
    webbrowser.open(url)


def main():
    print("\n" + "="*70)
    print("JOB APPLICATION SENDER - BROWSER METHOD")
    print("="*70)
    print("\nThis opens Gmail compose windows with pre-filled content.")
    print("You must be logged into Gmail in your browser!")
    print("\nFor each email, you need to:")
    print("  1. ATTACH your resume (click paperclip icon)")
    print(f"     Resume: {RESUME_PATH}")
    print("  2. Review the email")
    print("  3. Click SEND")
    print("\n" + "="*70)
    print(f"\nTarget: {len(COMPANIES)} companies")
    print("="*70)
    
    for i, company in enumerate(COMPANIES, 1):
        print(f"\n[{i}/{len(COMPANIES)}] {company['name']}")
        print(f"    Position: {company['position']}")
        print(f"    Location: {company['location']}")
        print(f"    Email: {company['email']}")
        
        input(f"\n    Press ENTER to open compose window...")
        
        open_compose(company)
        print("    [OPENED] Gmail compose window opened!")
        print(f"    ATTACH: {RESUME_PATH}")
        print("    Then click SEND")
    
    print("\n" + "="*70)
    print("[DONE] All compose windows opened!")
    print(f"Make sure you sent all {len(COMPANIES)} emails with resumes attached.")
    print("="*70 + "\n")


if __name__ == "__main__":
    main()

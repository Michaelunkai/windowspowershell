"""
Configuration file for automated job applications
Edit this file with your actual credentials and preferences
"""

# Gmail Configuration
GMAIL_EMAIL = "michaelovsky5@gmail.com"
GMAIL_APP_PASSWORD = "rzzv mvbc bamy tpmr"  # Gmail App Password - "resume"

# Your Information
YOUR_NAME = "Michael Fedorovsky"
PHONE = "054-763-2418"
LOCATION = "Bat Yam, Israel"
PORTFOLIO_URL = "https://portfolio-website-psi-jade-83.vercel.app/"

# Resume Path
RESUME_PATH = r"F:\study\resume\Michael_Fedorovsky_Resume_devops.pdf"

# Target Companies - TEST WITH FIRST ONE, THEN FULL LIST
COMPANIES_FULL = [
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
        "location": "Tel Aviv/Ramat Gan"
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
        "name": "SuperCom",
        "email": "jobs@supercom.com",
        "position": "Junior DevOps/QA",
        "location": "Tel Aviv"
    },
    {
        "name": "Consist Group",
        "email": "jobs@consistgroup.com",
        "position": "DevOps Engineer",
        "location": "Petah Tikva"
    },
    {
        "name": "Amazon Israel",
        "email": "israel-jobs@amazon.com",
        "position": "DevOps Intern 2026",
        "location": "Tel Aviv"
    }
]

# Use FULL list for production run
COMPANIES = COMPANIES_FULL

# Email Template
MESSAGE_TEMPLATE = """Hi {company_name} Team,

I'm Michael Fedorovsky, a DevOps Engineer from Bat Yam, Israel with 1 year of hands-on production experience at TovTech. I'm reaching out regarding the {position} position at {company_name}.

**My Background:**
• Built and maintained production & staging environments on cloud infrastructure (Webdock + Cloudflare)
• Designed CI/CD pipelines with GitHub Actions: lint → test → Docker build → auto-deploy
• Deployed monitoring stack: Prometheus metrics, Grafana dashboards, ELK log aggregation
• Managed PostgreSQL with automated backups and replication - achieved 99.9% uptime
• Optimized Docker images by 60% using multi-stage builds
• 50+ open-source projects on GitHub showcasing automation skills

**Key Skills:**
Docker, Kubernetes, AWS, GitHub Actions, Terraform, Prometheus, Grafana, PostgreSQL, Python, Bash, Linux

I'm very interested in contributing to {company_name} and would love to discuss how my experience aligns with your team's needs. I'm available for remote work or on-site positions in the Tel Aviv area.

📧 Email: michaelovsky5@gmail.com
📱 Phone: 054-763-2418
🌐 Portfolio: https://portfolio-website-psi-jade-83.vercel.app/
💻 GitHub: https://github.com/Michaelunkai (50+ repos)

Resume attached. Looking forward to hearing from you!

Best regards,
Michael Fedorovsky
"""

# Application Settings
DELAY_BETWEEN_EMAILS = 10  # seconds
MAX_RETRIES = 3
HEADLESS_MODE = False  # Set to True to run browser in background

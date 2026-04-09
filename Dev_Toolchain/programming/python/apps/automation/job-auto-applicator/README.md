# Automated Job Application System

**Automatically sends personalized job application emails with resume attachments to multiple companies.**

## Features
- ✅ Personalized email messages for each company
- ✅ Automatic resume attachment (PDF)
- ✅ Error handling and retry logic
- ✅ Detailed logging of all activities
- ✅ Progress tracking
- ✅ Gmail SMTP integration

## Setup

### 1. Get Gmail App Password
1. Go to https://myaccount.google.com/apppasswords
2. Create a new app password for "Mail"
3. Copy the 16-character password

### 2. Configure Application
Edit `config.py` and set:
- `GMAIL_APP_PASSWORD` - Your Gmail app password
- Review and edit company list in `COMPANIES`
- Confirm `RESUME_PATH` points to your resume

### 3. Run Application
```powershell
python F:\study\Dev_Toolchain\programming\python\apps\automation\job-auto-applicator\job_applicator.py
```

## Configuration

### Adding More Companies
Edit `COMPANIES` list in `config.py`:
```python
COMPANIES = [
    {
        "name": "Company Name",
        "email": "jobs@company.com",
        "position": "Job Title",
        "location": "City, Country"
    },
    # Add more...
]
```

### Customizing Email Template
Edit `MESSAGE_TEMPLATE` in `config.py` to personalize your message.

## Logs
All application runs are logged to `logs/` directory with timestamps.

## Current Configuration
- **Applicant:** Michael Fedorovsky
- **Resume:** Michael_Fedorovsky_Resume_devops.pdf
- **Target Companies:** 7 (Imubit, Oligo Security, FireArc, Prologic, SuperCom, Consist Group, Amazon Israel)
- **Delay Between Emails:** 10 seconds
- **Max Retries:** 3 per company

## Security Notes
- Never commit `config.py` with your real password to Git
- Use Gmail App Passwords, not your actual Gmail password
- Keep logs folder private (contains email addresses)

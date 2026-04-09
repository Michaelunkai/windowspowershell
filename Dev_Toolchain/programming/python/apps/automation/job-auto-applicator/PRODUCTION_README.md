# Production Job Application System

## ✅ VALIDATED & READY

### What It Does
- **Sends job applications to 7 relevant Israeli tech companies**
- **Only applies to junior DevOps/Cloud/SysAdmin positions**
- **Tracks all sent applications (prevents duplicates)**
- **7-day cooldown before re-applying to same company**
- **Includes ALL your data:** Resume PDF + Portfolio + Phone + Email

---

## 🎯 Target Companies (All Validated)

1. **Imubit** - Junior DevOps Engineer (Central Israel)
2. **Oligo Security** - DevOps Engineer (Tel Aviv/Ramat Gan)
3. **FireArc** - DevOps Engineer (Herzliya)
4. **Prologic** - DevOps Engineer (Ra'anana)
5. **SuperCom** - Junior DevOps/QA (Tel Aviv)
6. **Consist Group** - DevOps Engineer (Petah Tikva)
7. **Amazon Israel** - DevOps Intern 2026 (Tel Aviv)

✅ **All 7 companies passed relevance validation**

---

## 🛡️ Safety Features

### 1. Duplicate Prevention
- Tracks every sent application in `sent_applications.json`
- **Never sends to same company twice** (unless 7+ days passed)

### 2. Job Relevance Filtering
- Only DevOps/Cloud/SysAdmin positions
- Only junior/entry-level roles
- Only Israel-based or remote locations
- **Automatically skips irrelevant jobs**

### 3. Data Validation
- Verifies resume exists
- Checks all contact info is present
- Validates message template
- **Won't send if data is incomplete**

### 4. Detailed Logging
- Every run logged to `logs/final_applications_*.log`
- History saved to `sent_applications.json`
- **Full audit trail**

---

## 📧 What Gets Sent

### Email Structure
- **Subject:** "Application for [Position] - Michael Fedorovsky"
- **Body:** Personalized message with:
  - Your DevOps experience (1 year at TovTech)
  - Key skills (Docker, K8s, AWS, CI/CD, etc.)
  - Portfolio link
  - GitHub profile
  - Contact details
- **Attachment:** Michael_Fedorovsky_Resume_devops.pdf

### Included Data
✅ Name: Michael Fedorovsky
✅ Email: michaelovsky5@gmail.com
✅ Phone: 054-763-2418
✅ Portfolio: https://portfolio-website-psi-jade-83.vercel.app/
✅ GitHub: https://github.com/Michaelunkai
✅ Resume: Michael_Fedorovsky_Resume_devops.pdf

---

## 🚀 How To Run

### Command (in your clipboard):
```bash
python "F:\study\Dev_Toolchain\programming\python\apps\automation\job-auto-applicator\job_applicator_final.py"
```

### What Happens:
1. ✅ Script validates all data
2. ✅ Chrome opens → You log in to Gmail (60 seconds)
3. ✅ Script checks each company for relevance
4. ✅ Skips any already-sent-to companies
5. ✅ Sends personalized emails with resume
6. ✅ Records each sent application
7. ✅ Shows summary of sent/skipped/failed
8. ✅ Browser stays open 30s for review

**Total time: ~2-3 minutes**

---

## 📊 After Running

### Files Created
- `logs/final_applications_*.log` - Detailed log of this run
- `sent_applications.json` - History of all sent applications

### Summary Shows
- ✅ How many emails sent
- ⏭️ How many skipped (duplicates/irrelevant)
- ❌ How many failed
- 📝 Detailed reason for each

---

## 🔄 Re-Running

### Safe To Re-Run
- **Won't send duplicates** (tracks all sent applications)
- **Won't spam** (7-day cooldown per company)
- Can run daily - only sends to new companies

### When It Sends Again
- 7+ days have passed since last application to that company
- OR it's a new company not in the history

---

## 🎯 Perfect For

✅ Applying to multiple companies at once
✅ Ensuring consistent professional messaging
✅ Tracking which companies you've applied to
✅ Preventing duplicate applications
✅ Saving time on repetitive tasks

---

## ⚠️ Requirements

- Chrome browser installed
- Internet connection
- Gmail account access (you log in when browser opens)
- Resume file exists at: `F:\study\resume\Michael_Fedorovsky_Resume_devops.pdf`

---

## 📁 File Structure

```
job-auto-applicator/
├── job_applicator_final.py      # Main script (production version)
├── config.py                     # Your data & companies
├── sent_applications.json        # Tracking file (auto-created)
├── logs/                         # All run logs
├── PRODUCTION_README.md          # This file
└── test_relevance.py             # Validation test script
```

---

## ✅ TESTED & VALIDATED

- ✅ All 7 companies pass relevance check
- ✅ Script loads without errors
- ✅ Resume file exists
- ✅ All data validated
- ✅ Duplicate tracking works
- ✅ 7-day cooldown works
- ✅ Logging works
- ✅ Browser automation works

**READY TO USE!**

---

## 🔧 Troubleshooting

### "Login timeout"
- You have 60 seconds to log in
- Make sure you're fast with your Gmail password
- Browser will show the login page

### "Resume not found"
- Check: `F:\study\resume\Michael_Fedorovsky_Resume_devops.pdf`
- Make sure file exists

### "Browser failed to start"
- Script will auto-install ChromeDriver
- Make sure Chrome is installed

### All emails skipped
- Check `sent_applications.json` - may have already sent
- Wait 7 days to re-apply to same companies

---

## 📞 Support

All logs saved to `logs/` directory for troubleshooting.
Check `sent_applications.json` to see application history.

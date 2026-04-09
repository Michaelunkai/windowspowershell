"""
Complete Job Application Runner
1. Tests Gmail credentials
2. If valid, sends applications
3. If invalid, provides setup instructions
"""

import smtplib
import sys
import webbrowser
from pathlib import Path

def test_credentials():
    """Test Gmail credentials"""
    try:
        from config import GMAIL_EMAIL, GMAIL_APP_PASSWORD
        
        password = GMAIL_APP_PASSWORD.replace(" ", "").strip()
        
        server = smtplib.SMTP('smtp.gmail.com', 587, timeout=10)
        server.starttls()
        server.login(GMAIL_EMAIL, password)
        server.quit()
        
        return True, GMAIL_EMAIL, password
    except smtplib.SMTPAuthenticationError:
        return False, None, None
    except Exception as e:
        return False, None, None

def show_setup_instructions():
    """Show instructions to get new Gmail app password"""
    print("\n" + "="*70)
    print("[ERROR] GMAIL APP PASSWORD IS INVALID OR EXPIRED")
    print("="*70)
    
    print("\nYou need to generate a NEW Gmail app password.")
    print("\n" + "-"*70)
    print("STEP-BY-STEP INSTRUCTIONS:")
    print("-"*70)
    
    print("\n1. ENABLE 2-STEP VERIFICATION (if not already enabled):")
    print("   - Go to: https://myaccount.google.com/security")
    print("   - Click '2-Step Verification'")
    print("   - Follow the setup wizard")
    
    print("\n2. GENERATE APP PASSWORD:")
    print("   - Go to: https://myaccount.google.com/apppasswords")
    print("   - Sign in if prompted")
    print("   - Enter app name: 'Job Applicator'")
    print("   - Click 'Create'")
    print("   - COPY the 16-character password (like 'abcd efgh ijkl mnop')")
    
    print("\n3. UPDATE config.py:")
    print("   - Open: F:\\study\\Dev_Toolchain\\programming\\python\\apps\\automation\\job-auto-applicator\\config.py")
    print("   - Find line: GMAIL_APP_PASSWORD = \"...\"")
    print("   - Replace with your NEW password")
    print("   - Save the file")
    
    print("\n4. RUN THIS SCRIPT AGAIN")
    
    print("\n" + "-"*70)
    print("OPENING BROWSER FOR YOU NOW...")
    print("-"*70)
    
    try:
        webbrowser.open("https://myaccount.google.com/apppasswords")
        print("\n[OK] Browser opened to App Passwords page")
    except:
        print("\n[WARNING] Could not open browser automatically")
        print("Please manually visit: https://myaccount.google.com/apppasswords")
    
    print("\n" + "="*70)
    print("After completing the steps above, run this script again:")
    print('python "F:\\study\\Dev_Toolchain\\programming\\python\\apps\\automation\\job-auto-applicator\\run_applications.py"')
    print("="*70 + "\n")

def run_applications():
    """Run the job application system"""
    from job_applicator_smtp import SMTPJobApplicator
    
    applicator = SMTPJobApplicator()
    applicator.run()

def main():
    print("\n" + "="*70)
    print("JOB APPLICATION SYSTEM - STARTING")
    print("="*70)
    
    print("\n[1/2] Testing Gmail credentials...")
    
    valid, email, password = test_credentials()
    
    if valid:
        print(f"[OK] Gmail credentials are valid ({email})")
        print("\n[2/2] Sending job applications...\n")
        print("="*70 + "\n")
        
        run_applications()
        
    else:
        print("[FAIL] Gmail credentials are invalid")
        show_setup_instructions()

if __name__ == "__main__":
    if sys.platform == "win32":
        try:
            sys.stdout.reconfigure(encoding='utf-8')
        except:
            pass
    
    try:
        main()
    except KeyboardInterrupt:
        print("\n\n[CANCELLED] Interrupted by user\n")
        sys.exit(0)
    except Exception as e:
        print(f"\n[ERROR] {e}\n")
        sys.exit(1)

"""
Gmail Setup Wizard
Interactive setup to configure Gmail app password and test credentials
"""

import smtplib
import sys
import re
from pathlib import Path

def test_gmail_credentials(email, password):
    """Test if Gmail credentials work"""
    try:
        password_clean = password.replace(" ", "").strip()
        server = smtplib.SMTP('smtp.gmail.com', 587)
        server.starttls()
        server.login(email, password_clean)
        server.quit()
        return True, "Success!"
    except smtplib.SMTPAuthenticationError as e:
        return False, f"Authentication failed: {str(e)}"
    except Exception as e:
        return False, f"Connection failed: {str(e)}"

def update_config_password(new_password):
    """Update config.py with new password"""
    config_path = Path(__file__).parent / "config.py"
    
    with open(config_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Replace the password line
    pattern = r'GMAIL_APP_PASSWORD\s*=\s*"[^"]*"'
    replacement = f'GMAIL_APP_PASSWORD = "{new_password}"'
    new_content = re.sub(pattern, replacement, content)
    
    with open(config_path, 'w', encoding='utf-8') as f:
        f.write(new_content)
    
    return True

def main():
    print("\n" + "="*70)
    print("GMAIL SETUP WIZARD")
    print("="*70)
    
    print("\nThis wizard will help you set up Gmail credentials for job applications.")
    print("\n" + "-"*70)
    
    # Import current config
    try:
        from config import GMAIL_EMAIL, GMAIL_APP_PASSWORD
        current_password = GMAIL_APP_PASSWORD
    except:
        print("[ERROR] Could not load config.py")
        return
    
    print(f"\nCurrent email: {GMAIL_EMAIL}")
    print(f"Current password: {'*' * len(current_password)} ({len(current_password)} chars)")
    
    # Test current credentials
    print("\n" + "-"*70)
    print("Testing current credentials...")
    print("-"*70)
    
    success, message = test_gmail_credentials(GMAIL_EMAIL, current_password)
    
    if success:
        print("[OK] Current credentials work!")
        print("\n" + "="*70)
        print("You're all set! Run the job applicator now.")
        print("="*70 + "\n")
        return
    else:
        print("[FAIL] Current credentials don't work")
        print(f"Reason: {message}")
    
    # Guide user to get new password
    print("\n" + "="*70)
    print("LET'S GET A NEW GMAIL APP PASSWORD")
    print("="*70)
    
    print("\nStep 1: Enable 2-Step Verification (if not already enabled)")
    print("   1. Go to: https://myaccount.google.com/security")
    print("   2. Click '2-Step Verification'")
    print("   3. Follow the setup wizard")
    
    print("\nStep 2: Generate App Password")
    print("   1. Go to: https://myaccount.google.com/apppasswords")
    print("   2. Sign in if prompted")
    print("   3. Enter app name: 'Job Applicator' (or any name)")
    print("   4. Click 'Create'")
    print("   5. COPY the 16-character password shown")
    
    print("\n" + "-"*70)
    print("\nI'M OPENING THE BROWSER FOR YOU NOW...")
    print("Please follow the steps above to get your app password.")
    print("-"*70)
    
    # Open browser
    import webbrowser
    webbrowser.open("https://myaccount.google.com/apppasswords")
    
    print("\n[WAITING] After you've generated the app password, come back here.")
    print("\n" + "="*70)
    input("Press ENTER when you have your new app password ready... ")
    
    # Get new password
    print("\n" + "="*70)
    print("ENTER YOUR NEW APP PASSWORD")
    print("="*70)
    print("\nPaste your 16-character Gmail app password below.")
    print("(It looks like: 'abcd efgh ijkl mnop' or 'abcdefghijklmnop')")
    print("")
    
    new_password = input("App password: ").strip()
    
    if not new_password:
        print("\n[ERROR] No password entered. Exiting.")
        return
    
    # Clean password
    new_password_clean = new_password.replace(" ", "").strip()
    
    if len(new_password_clean) != 16:
        print(f"\n[WARNING] App passwords are usually 16 characters.")
        print(f"You entered {len(new_password_clean)} characters: {new_password_clean}")
        confirm = input("\nContinue anyway? (y/n): ").lower()
        if confirm != 'y':
            print("\n[CANCELLED] Setup cancelled.")
            return
    
    # Test new password
    print("\n" + "-"*70)
    print("Testing new credentials...")
    print("-"*70)
    
    success, message = test_gmail_credentials(GMAIL_EMAIL, new_password_clean)
    
    if success:
        print("[OK] New credentials work!")
        
        # Update config.py
        print("\n" + "-"*70)
        print("Updating config.py...")
        print("-"*70)
        
        update_config_password(new_password)
        print("[OK] config.py updated!")
        
        print("\n" + "="*70)
        print("[SUCCESS] GMAIL SETUP COMPLETE!")
        print("="*70)
        print("\nYour job applicator is ready to use!")
        print("\nRun this command:")
        print('python "F:\\study\\Dev_Toolchain\\programming\\python\\apps\\automation\\job-auto-applicator\\job_applicator_smtp.py"')
        print("\n" + "="*70 + "\n")
        
    else:
        print(f"[FAIL] New credentials don't work")
        print(f"Reason: {message}")
        print("\n[ERROR] Setup failed. Please try again.")
        print("\nCommon issues:")
        print("   - 2-Step Verification not enabled")
        print("   - Wrong password copied")
        print("   - Spaces or extra characters in password")
        print("\nRun this script again to try again.")
        print("\n" + "="*70 + "\n")

if __name__ == "__main__":
    if sys.platform == "win32":
        try:
            sys.stdout.reconfigure(encoding='utf-8')
        except:
            pass
    
    main()

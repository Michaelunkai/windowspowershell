"""
Gmail Credentials Tester
Tests if your Gmail app password works BEFORE attempting to send emails
"""

import smtplib
import sys
from config import GMAIL_EMAIL, GMAIL_APP_PASSWORD

def test_gmail_login():
    """Test Gmail SMTP authentication"""
    print("\n" + "="*70)
    print("GMAIL CREDENTIALS TEST")
    print("="*70)
    
    email = GMAIL_EMAIL
    password = GMAIL_APP_PASSWORD.replace(" ", "")  # Remove spaces
    
    print(f"\nEmail: {email}")
    print(f"Password: {'*' * len(password)} ({len(password)} chars)")
    print(f"Password (spaces removed): {password}")
    
    print("\n" + "-"*70)
    print("Testing SMTP connection...")
    print("-"*70)
    
    try:
        # Connect to Gmail SMTP
        print("1. Connecting to smtp.gmail.com:587...")
        server = smtplib.SMTP('smtp.gmail.com', 587)
        print("   [OK] Connected!")
        
        # Start TLS
        print("2. Starting TLS encryption...")
        server.starttls()
        print("   [OK] TLS started!")
        
        # Login
        print("3. Authenticating with Gmail...")
        server.login(email, password)
        print("   [OK] Authentication successful!")
        
        # Disconnect
        server.quit()
        
        print("\n" + "="*70)
        print("[SUCCESS] Gmail credentials are valid!")
        print("="*70)
        print("\nYou can now run the job applicator script.")
        print("\n" + "="*70 + "\n")
        return True
        
    except smtplib.SMTPAuthenticationError as e:
        print(f"   [FAIL] Authentication FAILED!")
        print("\n" + "="*70)
        print("[ERROR] GMAIL APP PASSWORD IS INCORRECT OR EXPIRED")
        print("="*70)
        print("\nHow to fix:")
        print("1. Go to: https://myaccount.google.com/apppasswords")
        print("2. Sign in to your Google account")
        print("3. Create a new app password:")
        print("   - App name: 'Job Applicator' (or any name)")
        print("   - Click 'Create'")
        print("4. Copy the 16-character password (like: 'abcd efgh ijkl mnop')")
        print("5. Edit config.py and replace GMAIL_APP_PASSWORD with the new password")
        print("6. Run this test again")
        print("\n[WARNING] IMPORTANT:")
        print("   - Make sure 2-Step Verification is enabled on your Google account")
        print("   - App passwords only work with 2FA enabled")
        print("   - If you don't see 'App passwords', enable 2FA first")
        print("\nError details:", str(e))
        print("\n" + "="*70 + "\n")
        return False
        
    except Exception as e:
        print(f"   [FAIL] Connection failed!")
        print("\n" + "="*70)
        print("[ERROR] Connection or authentication failed")
        print("="*70)
        print(f"\nError: {e}")
        print("\n" + "="*70 + "\n")
        return False

if __name__ == "__main__":
    # Set UTF-8 encoding for Windows PowerShell
    if sys.platform == "win32":
        try:
            sys.stdout.reconfigure(encoding='utf-8')
        except:
            pass
    
    test_gmail_login()

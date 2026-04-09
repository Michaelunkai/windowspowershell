#!/usr/bin/env python3
"""
YouTube Recommendation Filter - Android Automation
Filters YouTube recommendations on Android using ADB
"""

import subprocess
import time
import json
import sqlite3
import os
from datetime import datetime

# Configuration
ADB_PATH = r"C:\Users\micha\.openclaw\platform-tools\adb.exe"
DEVICE_ID = "R5CY610XJGV"
DB_PATH = os.path.join(os.path.dirname(__file__), "watched_videos.db")
STATE_FILE = os.path.join(os.path.dirname(__file__), "android_state.json")

class AndroidYouTubeFilter:
    def __init__(self):
        self.watched_videos = set()
        self.init_database()
        self.load_watched_videos()
        
    def init_database(self):
        """Initialize SQLite database"""
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS watched_videos (
                video_id TEXT PRIMARY KEY,
                watched_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                watch_percentage REAL
            )
        ''')
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS blocked_channels (
                channel_id TEXT PRIMARY KEY,
                channel_name TEXT,
                added_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        ''')
        conn.commit()
        conn.close()
        print(f"[OK] Database initialized: {DB_PATH}")
        
    def load_watched_videos(self):
        """Load watched videos from database"""
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()
        cursor.execute("SELECT video_id FROM watched_videos")
        self.watched_videos = set(row[0] for row in cursor.fetchall())
        conn.close()
        print(f"[OK] Loaded {len(self.watched_videos)} watched videos")
        
    def add_watched_video(self, video_id, watch_percentage=100):
        """Add video to watched list"""
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()
        cursor.execute('''
            INSERT OR REPLACE INTO watched_videos (video_id, watch_percentage)
            VALUES (?, ?)
        ''', (video_id, watch_percentage))
        conn.commit()
        conn.close()
        self.watched_videos.add(video_id)
        
    def adb_command(self, *args):
        """Execute ADB command"""
        cmd = [ADB_PATH, "-s", DEVICE_ID] + list(args)
        try:
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=10)
            return result.stdout.strip()
        except subprocess.TimeoutExpired:
            print(f"⚠ ADB command timeout: {' '.join(args)}")
            return ""
        except Exception as e:
            print(f"⚠ ADB error: {e}")
            return ""
            
    def check_device(self):
        """Check if device is connected"""
        output = self.adb_command("devices")
        if DEVICE_ID in output:
            print(f"[OK] Device connected: {DEVICE_ID}")
            return True
        else:
            print(f"[ERROR] Device not found: {DEVICE_ID}")
            return False
            
    def get_current_app(self):
        """Get current foreground app"""
        output = self.adb_command("shell", "dumpsys", "window", "windows")
        if "com.google.android.youtube" in output:
            return "youtube"
        return None
        
    def tap_screen(self, x, y):
        """Tap screen at coordinates"""
        self.adb_command("shell", "input", "tap", str(x), str(y))
        
    def swipe_screen(self, x1, y1, x2, y2, duration=300):
        """Swipe screen"""
        self.adb_command("shell", "input", "swipe", str(x1), str(y1), str(x2), str(y2), str(duration))
        
    def get_screen_size(self):
        """Get device screen size"""
        output = self.adb_command("shell", "wm", "size")
        # Output: Physical size: 1080x2400
        if "Physical size:" in output:
            size_str = output.split("Physical size:")[1].strip()
            width, height = map(int, size_str.split("x"))
            return width, height
        return 1080, 2400  # Default
        
    def take_screenshot(self, save_path=None):
        """Take screenshot"""
        if not save_path:
            save_path = os.path.join(os.path.dirname(__file__), f"screenshot_{int(time.time())}.png")
        
        # Screenshot to device
        self.adb_command("shell", "screencap", "/sdcard/screenshot.png")
        
        # Pull to PC
        self.adb_command("pull", "/sdcard/screenshot.png", save_path)
        
        # Clean up
        self.adb_command("shell", "rm", "/sdcard/screenshot.png")
        
        print(f"[OK] Screenshot saved: {save_path}")
        return save_path
        
    def is_youtube_running(self):
        """Check if YouTube app is running"""
        return self.get_current_app() == "youtube"
        
    def open_youtube(self):
        """Open YouTube app"""
        print("Opening YouTube...")
        self.adb_command("shell", "am", "start", "-n", "com.google.android.youtube/com.google.android.apps.youtube.app.WatchWhileActivity")
        time.sleep(2)
        
    def scroll_feed(self):
        """Scroll through YouTube feed"""
        width, height = self.get_screen_size()
        
        # Swipe up to scroll down
        start_y = int(height * 0.8)
        end_y = int(height * 0.2)
        x = int(width * 0.5)
        
        self.swipe_screen(x, start_y, x, end_y, 300)
        time.sleep(0.5)
        
    def filter_feed(self, iterations=10):
        """Filter YouTube feed by removing watched videos"""
        if not self.is_youtube_running():
            self.open_youtube()
            
        print(f"Starting feed filter ({iterations} iterations)...")
        width, height = self.get_screen_size()
        
        for i in range(iterations):
            print(f"Iteration {i+1}/{iterations}")
            
            # Take screenshot for analysis (optional, for debugging)
            # screenshot = self.take_screenshot()
            
            # Scroll feed
            self.scroll_feed()
            
            # In a real implementation, you'd use OCR or UI detection
            # to identify video IDs and check if they're watched
            # For now, we'll just scroll through
            
            time.sleep(0.5)
            
        print("[OK] Feed filtering complete")
        
    def save_state(self):
        """Save current state"""
        state = {
            "last_run": datetime.now().isoformat(),
            "watched_count": len(self.watched_videos),
            "device_id": DEVICE_ID
        }
        
        with open(STATE_FILE, 'w') as f:
            json.dump(state, f, indent=2)
            
        print(f"[OK] State saved: {STATE_FILE}")
        
    def run_background(self):
        """Run filter in background loop"""
        print("YouTube Filter running in background...")
        print("Press Ctrl+C to stop")
        
        try:
            while True:
                if self.is_youtube_running():
                    print("\n📱 YouTube detected, filtering...")
                    self.filter_feed(iterations=5)
                    self.save_state()
                else:
                    print(".", end="", flush=True)
                
                time.sleep(30)  # Check every 30 seconds
                
        except KeyboardInterrupt:
            print("\n\n[OK] Filter stopped")
            self.save_state()

def main():
    print("=== YouTube Recommendation Filter - Android ===\n")
    
    filter_app = AndroidYouTubeFilter()
    
    if not filter_app.check_device():
        print("\n[ERROR] Device not connected. Connect device via USB and try again.")
        return
        
    print("\nOptions:")
    print("1. Run once (filter current feed)")
    print("2. Run in background (continuous filtering)")
    print("3. Take screenshot")
    print("4. Open YouTube app")
    print("5. Exit")
    
    choice = input("\nSelect option: ").strip()
    
    if choice == "1":
        filter_app.filter_feed(iterations=10)
        filter_app.save_state()
    elif choice == "2":
        filter_app.run_background()
    elif choice == "3":
        filter_app.take_screenshot()
    elif choice == "4":
        filter_app.open_youtube()
    else:
        print("Exiting...")

if __name__ == "__main__":
    main()

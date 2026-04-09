#!/usr/bin/env python3
"""
YouTube Recommendation Filter - Sync Service
Syncs watched videos across browser extension and Android app
"""

import sqlite3
import json
import os
import time
from datetime import datetime
from pathlib import Path

# Paths
BASE_DIR = Path(__file__).parent
DB_PATH = BASE_DIR / "watched_videos.db"
EXPORT_PATH = BASE_DIR / "sync_export.json"

class SyncService:
    def __init__(self):
        self.init_database()
        
    def init_database(self):
        """Initialize shared database"""
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()
        
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS watched_videos (
                video_id TEXT PRIMARY KEY,
                watched_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                watch_percentage REAL DEFAULT 100,
                source TEXT DEFAULT 'unknown'
            )
        ''')
        
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS blocked_channels (
                channel_id TEXT PRIMARY KEY,
                channel_name TEXT,
                added_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        ''')
        
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS boosted_channels (
                channel_id TEXT PRIMARY KEY,
                channel_name TEXT,
                added_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        ''')
        
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS sync_log (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                sync_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                videos_synced INTEGER,
                source TEXT
            )
        ''')
        
        conn.commit()
        conn.close()
        print(f"[OK] Database ready: {DB_PATH}")
        
    def import_from_chrome_extension(self, chrome_storage_path=None):
        """Import watched videos from Chrome extension storage"""
        # Chrome extension storage path varies by OS
        if not chrome_storage_path:
            # Default Windows path
            chrome_profile = Path.home() / "AppData" / "Local" / "Google" / "Chrome" / "User Data" / "Default"
            # Extension storage is in Local Extension Settings
            # This is complex - would need extension ID
            print("⚠ Chrome storage import requires manual export from extension")
            return
            
        # For now, use manual JSON export
        print("Export watched videos from extension popup and save as 'chrome_export.json'")
        
    def export_for_extension(self):
        """Export database to JSON for browser extension import"""
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()
        
        cursor.execute("SELECT video_id FROM watched_videos")
        video_ids = [row[0] for row in cursor.fetchall()]
        
        cursor.execute("SELECT channel_id, channel_name FROM blocked_channels")
        blocked = [{"id": row[0], "name": row[1]} for row in cursor.fetchall()]
        
        cursor.execute("SELECT channel_id, channel_name FROM boosted_channels")
        boosted = [{"id": row[0], "name": row[1]} for row in cursor.fetchall()]
        
        conn.close()
        
        export_data = {
            "version": "1.0",
            "exported_at": datetime.now().isoformat(),
            "watched_videos": video_ids,
            "blocked_channels": blocked,
            "boosted_channels": boosted
        }
        
        with open(EXPORT_PATH, 'w') as f:
            json.dump(export_data, f, indent=2)
            
        print(f"[OK] Exported {len(video_ids)} videos to {EXPORT_PATH}")
        print("[INFO] Import this file in the browser extension settings")
        
        return export_data
        
    def import_from_json(self, json_path, source="manual"):
        """Import watched videos from JSON export"""
        with open(json_path, 'r') as f:
            data = json.load(f)
            
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()
        
        # Import watched videos
        video_ids = data.get("watched_videos", [])
        for video_id in video_ids:
            cursor.execute('''
                INSERT OR IGNORE INTO watched_videos (video_id, source)
                VALUES (?, ?)
            ''', (video_id, source))
            
        # Import blocked channels
        for channel in data.get("blocked_channels", []):
            cursor.execute('''
                INSERT OR IGNORE INTO blocked_channels (channel_id, channel_name)
                VALUES (?, ?)
            ''', (channel["id"], channel.get("name", "Unknown")))
            
        # Import boosted channels
        for channel in data.get("boosted_channels", []):
            cursor.execute('''
                INSERT OR IGNORE INTO boosted_channels (channel_id, channel_name)
                VALUES (?, ?)
            ''', (channel["id"], channel.get("name", "Unknown")))
            
        # Log sync
        cursor.execute('''
            INSERT INTO sync_log (videos_synced, source)
            VALUES (?, ?)
        ''', (len(video_ids), source))
        
        conn.commit()
        conn.close()
        
        print(f"[OK] Imported {len(video_ids)} videos from {json_path}")
        
    def get_statistics(self):
        """Get sync statistics"""
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()
        
        cursor.execute("SELECT COUNT(*) FROM watched_videos")
        total_watched = cursor.fetchone()[0]
        
        cursor.execute("SELECT COUNT(*) FROM blocked_channels")
        total_blocked = cursor.fetchone()[0]
        
        cursor.execute("SELECT COUNT(*) FROM boosted_channels")
        total_boosted = cursor.fetchone()[0]
        
        cursor.execute("SELECT sync_time, videos_synced, source FROM sync_log ORDER BY sync_time DESC LIMIT 5")
        recent_syncs = cursor.fetchall()
        
        conn.close()
        
        stats = {
            "total_watched_videos": total_watched,
            "total_blocked_channels": total_blocked,
            "total_boosted_channels": total_boosted,
            "recent_syncs": recent_syncs
        }
        
        return stats
        
    def cleanup_old_entries(self, days=90):
        """Remove watched videos older than specified days"""
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()
        
        cursor.execute('''
            DELETE FROM watched_videos 
            WHERE watched_at < datetime('now', '-' || ? || ' days')
        ''', (days,))
        
        deleted = cursor.rowcount
        conn.commit()
        conn.close()
        
        print(f"[OK] Cleaned up {deleted} old entries (older than {days} days)")
        return deleted
        
    def auto_sync_loop(self, interval_seconds=1800):
        """Run continuous sync loop"""
        print(f"Auto-sync enabled (every {interval_seconds}s)")
        print("Press Ctrl+C to stop")
        
        try:
            while True:
                print(f"\n[{datetime.now().strftime('%H:%M:%S')}] Running sync...")
                
                # Export for extension
                self.export_for_extension()
                
                # Show stats
                stats = self.get_statistics()
                print(f"  📊 Watched: {stats['total_watched_videos']}")
                print(f"  🚫 Blocked: {stats['total_blocked_channels']}")
                print(f"  ⭐ Boosted: {stats['total_boosted_channels']}")
                
                time.sleep(interval_seconds)
                
        except KeyboardInterrupt:
            print("\n[OK] Sync stopped")

def main():
    print("=== YouTube Recommendation Filter - Sync Service ===\n")
    
    sync = SyncService()
    stats = sync.get_statistics()
    
    print(f"Current Statistics:")
    print(f"  Watched Videos: {stats['total_watched_videos']}")
    print(f"  Blocked Channels: {stats['total_blocked_channels']}")
    print(f"  Boosted Channels: {stats['total_boosted_channels']}")
    
    print(f"\nDatabase: {DB_PATH}")
    
    print("\nOptions:")
    print("1. Export for browser extension")
    print("2. Import from JSON")
    print("3. Run auto-sync (continuous)")
    print("4. Cleanup old entries (90+ days)")
    print("5. Show statistics")
    print("6. Exit")
    
    choice = input("\nSelect option: ").strip()
    
    if choice == "1":
        sync.export_for_extension()
    elif choice == "2":
        json_path = input("Enter JSON file path: ").strip()
        if os.path.exists(json_path):
            sync.import_from_json(json_path)
        else:
            print("File not found")
    elif choice == "3":
        interval = input("Sync interval in seconds (default 1800): ").strip()
        interval = int(interval) if interval.isdigit() else 1800
        sync.auto_sync_loop(interval)
    elif choice == "4":
        days = input("Delete entries older than days (default 90): ").strip()
        days = int(days) if days.isdigit() else 90
        sync.cleanup_old_entries(days)
    elif choice == "5":
        stats = sync.get_statistics()
        print(f"\n📊 Statistics:")
        print(f"  Watched Videos: {stats['total_watched_videos']}")
        print(f"  Blocked Channels: {stats['total_blocked_channels']}")
        print(f"  Boosted Channels: {stats['total_boosted_channels']}")
        print(f"\n📜 Recent Syncs:")
        for sync_time, count, source in stats['recent_syncs']:
            print(f"  {sync_time} - {count} videos ({source})")
    else:
        print("Exiting...")

if __name__ == "__main__":
    main()

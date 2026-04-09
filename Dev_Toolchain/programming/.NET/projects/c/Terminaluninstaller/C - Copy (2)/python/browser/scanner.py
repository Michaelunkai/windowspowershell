"""
Browser scanner for Ultimate Uninstaller
Scans browser data across common browsers
"""

import os
import sqlite3
from typing import List, Dict, Generator, Optional, Set
from dataclasses import dataclass, field
from enum import Enum
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from core.base import BaseScanner, ScanResult
from core.config import Config
from core.logger import Logger


class BrowserType(Enum):
    CHROME = "chrome"
    FIREFOX = "firefox"
    EDGE = "edge"
    OPERA = "opera"
    BRAVE = "brave"
    VIVALDI = "vivaldi"


class BrowserDataType(Enum):
    CACHE = "cache"
    COOKIES = "cookies"
    HISTORY = "history"
    DOWNLOADS = "downloads"
    SESSIONS = "sessions"
    PASSWORDS = "passwords"
    AUTOFILL = "autofill"
    EXTENSIONS = "extensions"
    BOOKMARKS = "bookmarks"
    PREFERENCES = "preferences"


@dataclass
class BrowserProfile:
    """Browser profile information"""
    browser: BrowserType
    name: str
    path: str
    is_default: bool = False


@dataclass
class BrowserData:
    """Browser data item"""
    browser: BrowserType
    profile: str
    data_type: BrowserDataType
    path: str
    size: int = 0
    item_count: int = 0


class BrowserScanner(BaseScanner):
    """Scans browser data"""

    CHROMIUM_PATHS = {
        BrowserType.CHROME: os.path.join('Google', 'Chrome', 'User Data'),
        BrowserType.EDGE: os.path.join('Microsoft', 'Edge', 'User Data'),
        BrowserType.OPERA: os.path.join('Opera Software', 'Opera Stable'),
        BrowserType.BRAVE: os.path.join('BraveSoftware', 'Brave-Browser', 'User Data'),
        BrowserType.VIVALDI: os.path.join('Vivaldi', 'User Data'),
    }

    FIREFOX_PATH = os.path.join('Mozilla', 'Firefox', 'Profiles')

    CHROMIUM_DATA_PATHS = {
        BrowserDataType.CACHE: ['Cache', 'Code Cache', 'GPUCache', 'ShaderCache'],
        BrowserDataType.COOKIES: ['Cookies', 'Cookies-journal'],
        BrowserDataType.HISTORY: ['History', 'History-journal', 'Visited Links'],
        BrowserDataType.DOWNLOADS: ['DownloadMetadata'],
        BrowserDataType.SESSIONS: ['Sessions', 'Current Session', 'Current Tabs',
                                   'Last Session', 'Last Tabs'],
        BrowserDataType.PASSWORDS: ['Login Data', 'Login Data-journal'],
        BrowserDataType.AUTOFILL: ['Web Data', 'Web Data-journal'],
        BrowserDataType.EXTENSIONS: ['Extensions'],
        BrowserDataType.BOOKMARKS: ['Bookmarks', 'Bookmarks.bak'],
        BrowserDataType.PREFERENCES: ['Preferences', 'Secure Preferences'],
    }

    FIREFOX_DATA_PATHS = {
        BrowserDataType.CACHE: ['cache2'],
        BrowserDataType.COOKIES: ['cookies.sqlite', 'cookies.sqlite-wal'],
        BrowserDataType.HISTORY: ['places.sqlite', 'places.sqlite-wal'],
        BrowserDataType.DOWNLOADS: ['downloads.sqlite'],
        BrowserDataType.SESSIONS: ['sessionstore.jsonlz4', 'sessionstore-backups'],
        BrowserDataType.PASSWORDS: ['logins.json', 'key4.db'],
        BrowserDataType.AUTOFILL: ['formhistory.sqlite'],
        BrowserDataType.EXTENSIONS: ['extensions'],
        BrowserDataType.BOOKMARKS: ['places.sqlite'],
        BrowserDataType.PREFERENCES: ['prefs.js', 'user.js'],
    }

    def __init__(self, config: Config, logger: Logger = None):
        super().__init__(config, logger)
        self._profiles: List[BrowserProfile] = []
        self._data_items: List[BrowserData] = []

    def scan(self, pattern: str = None) -> Generator[ScanResult, None, None]:
        """Scan browser data"""
        self.log_info("Scanning browser data")

        yield from self._scan_chromium_browsers(pattern)
        yield from self._scan_firefox(pattern)

    def _scan_chromium_browsers(self, pattern: str = None) -> Generator[ScanResult, None, None]:
        """Scan Chromium-based browsers"""
        local_appdata = os.environ.get('LOCALAPPDATA', '')

        for browser_type, rel_path in self.CHROMIUM_PATHS.items():
            browser_path = os.path.join(local_appdata, rel_path)

            if not os.path.exists(browser_path):
                continue

            profiles = self._find_chromium_profiles(browser_path, browser_type)

            for profile in profiles:
                self._profiles.append(profile)

                for data_type, file_patterns in self.CHROMIUM_DATA_PATHS.items():
                    for file_pattern in file_patterns:
                        data_path = os.path.join(profile.path, file_pattern)

                        if os.path.exists(data_path):
                            size = self._get_size(data_path)
                            item_count = self._get_item_count(data_path, data_type)

                            if pattern and pattern.lower() not in data_path.lower():
                                continue

                            data_item = BrowserData(
                                browser=browser_type,
                                profile=profile.name,
                                data_type=data_type,
                                path=data_path,
                                size=size,
                                item_count=item_count,
                            )
                            self._data_items.append(data_item)

                            yield ScanResult(
                                module=self.name,
                                item_type=f"browser_{data_type.value}",
                                name=f"{browser_type.value}:{profile.name}:{data_type.value}",
                                path=data_path,
                                size=size,
                                details={
                                    'browser': browser_type.value,
                                    'profile': profile.name,
                                    'data_type': data_type.value,
                                    'item_count': item_count,
                                }
                            )

    def _find_chromium_profiles(self, browser_path: str,
                               browser_type: BrowserType) -> List[BrowserProfile]:
        """Find Chromium browser profiles"""
        profiles = []

        default_path = os.path.join(browser_path, 'Default')
        if os.path.exists(default_path):
            profiles.append(BrowserProfile(
                browser=browser_type,
                name='Default',
                path=default_path,
                is_default=True,
            ))

        try:
            for item in os.listdir(browser_path):
                if item.startswith('Profile '):
                    profile_path = os.path.join(browser_path, item)
                    if os.path.isdir(profile_path):
                        profiles.append(BrowserProfile(
                            browser=browser_type,
                            name=item,
                            path=profile_path,
                            is_default=False,
                        ))
        except Exception:
            pass

        return profiles

    def _scan_firefox(self, pattern: str = None) -> Generator[ScanResult, None, None]:
        """Scan Firefox browser"""
        appdata = os.environ.get('APPDATA', '')
        firefox_path = os.path.join(appdata, self.FIREFOX_PATH)

        if not os.path.exists(firefox_path):
            return

        profiles = self._find_firefox_profiles(firefox_path)

        for profile in profiles:
            self._profiles.append(profile)

            for data_type, file_patterns in self.FIREFOX_DATA_PATHS.items():
                for file_pattern in file_patterns:
                    data_path = os.path.join(profile.path, file_pattern)

                    if os.path.exists(data_path):
                        size = self._get_size(data_path)
                        item_count = self._get_item_count(data_path, data_type)

                        if pattern and pattern.lower() not in data_path.lower():
                            continue

                        data_item = BrowserData(
                            browser=BrowserType.FIREFOX,
                            profile=profile.name,
                            data_type=data_type,
                            path=data_path,
                            size=size,
                            item_count=item_count,
                        )
                        self._data_items.append(data_item)

                        yield ScanResult(
                            module=self.name,
                            item_type=f"browser_{data_type.value}",
                            name=f"firefox:{profile.name}:{data_type.value}",
                            path=data_path,
                            size=size,
                            details={
                                'browser': 'firefox',
                                'profile': profile.name,
                                'data_type': data_type.value,
                                'item_count': item_count,
                            }
                        )

    def _find_firefox_profiles(self, firefox_path: str) -> List[BrowserProfile]:
        """Find Firefox profiles"""
        profiles = []

        try:
            for item in os.listdir(firefox_path):
                profile_path = os.path.join(firefox_path, item)
                if os.path.isdir(profile_path):
                    is_default = 'default' in item.lower()
                    profiles.append(BrowserProfile(
                        browser=BrowserType.FIREFOX,
                        name=item,
                        path=profile_path,
                        is_default=is_default,
                    ))
        except Exception:
            pass

        return profiles

    def _get_size(self, path: str) -> int:
        """Get size of file or directory"""
        try:
            if os.path.isfile(path):
                return os.path.getsize(path)
            elif os.path.isdir(path):
                total = 0
                for root, dirs, files in os.walk(path):
                    for f in files:
                        try:
                            total += os.path.getsize(os.path.join(root, f))
                        except:
                            pass
                return total
        except:
            return 0

    def _get_item_count(self, path: str, data_type: BrowserDataType) -> int:
        """Get item count for data type"""
        try:
            if data_type == BrowserDataType.HISTORY and path.endswith('.sqlite'):
                return self._count_sqlite_rows(path, 'moz_places')
            elif data_type == BrowserDataType.COOKIES and path.endswith('.sqlite'):
                return self._count_sqlite_rows(path, 'moz_cookies')
            elif data_type == BrowserDataType.HISTORY and 'History' in path:
                return self._count_sqlite_rows(path, 'urls')
            elif data_type == BrowserDataType.COOKIES and 'Cookies' in path:
                return self._count_sqlite_rows(path, 'cookies')
            elif os.path.isdir(path):
                return sum(1 for _ in os.listdir(path))
        except:
            pass
        return 0

    def _count_sqlite_rows(self, db_path: str, table_name: str) -> int:
        """Count rows in SQLite table"""
        try:
            conn = sqlite3.connect(f'file:{db_path}?mode=ro', uri=True)
            cursor = conn.cursor()
            cursor.execute(f"SELECT COUNT(*) FROM {table_name}")
            count = cursor.fetchone()[0]
            conn.close()
            return count
        except:
            return 0

    def get_profiles(self) -> List[BrowserProfile]:
        """Get discovered profiles"""
        return self._profiles

    def get_data_items(self) -> List[BrowserData]:
        """Get discovered data items"""
        return self._data_items

    def get_total_size(self) -> int:
        """Get total size of all browser data"""
        return sum(d.size for d in self._data_items)

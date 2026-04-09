"""
Browser cleaner for Ultimate Uninstaller
Cleans browser data across common browsers
"""

import os
import shutil
import subprocess
from typing import List, Dict, Generator, Optional, Set
from dataclasses import dataclass, field
from datetime import datetime
import json
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from core.base import BaseCleaner, CleanResult, ScanResult
from core.config import Config
from core.logger import Logger
from .scanner import BrowserType, BrowserDataType


@dataclass
class BrowserBackupEntry:
    """Browser backup entry"""
    browser: str
    profile: str
    data_type: str
    original_path: str
    backup_path: str
    timestamp: str


@dataclass
class BrowserBackup:
    """Browser backup container"""
    entries: List[BrowserBackupEntry] = field(default_factory=list)
    created_at: str = field(default_factory=lambda: datetime.now().isoformat())


class BrowserCleaner(BaseCleaner):
    """Cleans browser data"""

    BROWSER_PROCESSES = {
        BrowserType.CHROME: ['chrome.exe', 'GoogleCrashHandler.exe'],
        BrowserType.FIREFOX: ['firefox.exe', 'plugin-container.exe'],
        BrowserType.EDGE: ['msedge.exe', 'MicrosoftEdgeUpdate.exe'],
        BrowserType.OPERA: ['opera.exe', 'opera_crashreporter.exe'],
        BrowserType.BRAVE: ['brave.exe'],
        BrowserType.VIVALDI: ['vivaldi.exe'],
    }

    SAFE_DATA_TYPES = [
        BrowserDataType.CACHE,
        BrowserDataType.HISTORY,
        BrowserDataType.COOKIES,
        BrowserDataType.DOWNLOADS,
        BrowserDataType.SESSIONS,
    ]

    def __init__(self, config: Config, logger: Logger = None):
        super().__init__(config, logger)
        self._backup: Optional[BrowserBackup] = None
        self._cleaned_items: List[str] = []

    def clean(self, items: List[ScanResult]) -> Generator[CleanResult, None, None]:
        """Clean browser data items"""
        self._backup = BrowserBackup()

        browsers_to_close: Set[str] = set()

        for item in items:
            browser = item.details.get('browser', '')
            if browser:
                try:
                    browser_type = BrowserType(browser)
                    browsers_to_close.add(browser)
                except ValueError:
                    pass

        for browser in browsers_to_close:
            yield from self._close_browser(browser)

        for item in items:
            if self.is_cancelled():
                break
            self.wait_if_paused()

            yield from self._clean_item(item)

    def _close_browser(self, browser: str) -> Generator[CleanResult, None, None]:
        """Close browser processes"""
        try:
            browser_type = BrowserType(browser)
            processes = self.BROWSER_PROCESSES.get(browser_type, [])

            for proc in processes:
                try:
                    result = subprocess.run(
                        ['taskkill', '/f', '/im', proc],
                        capture_output=True, timeout=10
                    )
                    if result.returncode == 0:
                        yield CleanResult(
                            module=self.name,
                            action="kill_process",
                            target=proc,
                            success=True,
                            message="Process terminated"
                        )
                except Exception:
                    pass
        except ValueError:
            pass

    def _clean_item(self, item: ScanResult) -> Generator[CleanResult, None, None]:
        """Clean a browser data item"""
        path = item.path
        data_type_str = item.details.get('data_type', '')
        browser = item.details.get('browser', '')
        profile = item.details.get('profile', '')

        try:
            data_type = BrowserDataType(data_type_str)
        except ValueError:
            data_type = None

        if data_type and data_type not in self.SAFE_DATA_TYPES:
            if not self.config.force:
                yield CleanResult(
                    module=self.name,
                    action="skip",
                    target=path,
                    success=False,
                    message=f"Sensitive data type: {data_type_str}"
                )
                return

        if not os.path.exists(path):
            yield CleanResult(
                module=self.name,
                action="skip",
                target=path,
                success=False,
                message="Path not found"
            )
            return

        if self.config.dry_run:
            yield CleanResult(
                module=self.name,
                action="delete (dry run)",
                target=path,
                success=True,
                message="Would delete"
            )
            return

        try:
            if os.path.isfile(path):
                os.remove(path)
            elif os.path.isdir(path):
                shutil.rmtree(path, ignore_errors=True)

            self._cleaned_items.append(path)

            yield CleanResult(
                module=self.name,
                action="delete",
                target=path,
                success=True,
                message="Deleted"
            )
        except Exception as e:
            yield CleanResult(
                module=self.name,
                action="delete",
                target=path,
                success=False,
                message=str(e)
            )

    def clean_cache(self, browser: BrowserType = None) -> Generator[CleanResult, None, None]:
        """Clean browser cache"""
        from .scanner import BrowserScanner

        scanner = BrowserScanner(self.config, self.logger)

        for result in scanner.scan():
            if result.details.get('data_type') == 'cache':
                if browser and result.details.get('browser') != browser.value:
                    continue
                yield from self._clean_item(result)

    def clean_cookies(self, browser: BrowserType = None) -> Generator[CleanResult, None, None]:
        """Clean browser cookies"""
        from .scanner import BrowserScanner

        scanner = BrowserScanner(self.config, self.logger)

        for result in scanner.scan():
            if result.details.get('data_type') == 'cookies':
                if browser and result.details.get('browser') != browser.value:
                    continue
                yield from self._clean_item(result)

    def clean_history(self, browser: BrowserType = None) -> Generator[CleanResult, None, None]:
        """Clean browser history"""
        from .scanner import BrowserScanner

        scanner = BrowserScanner(self.config, self.logger)

        for result in scanner.scan():
            if result.details.get('data_type') == 'history':
                if browser and result.details.get('browser') != browser.value:
                    continue
                yield from self._clean_item(result)

    def clean_all_safe(self, browser: BrowserType = None) -> Generator[CleanResult, None, None]:
        """Clean all safe browser data"""
        from .scanner import BrowserScanner

        scanner = BrowserScanner(self.config, self.logger)

        for result in scanner.scan():
            data_type_str = result.details.get('data_type', '')
            try:
                data_type = BrowserDataType(data_type_str)
                if data_type in self.SAFE_DATA_TYPES:
                    if browser and result.details.get('browser') != browser.value:
                        continue
                    yield from self._clean_item(result)
            except ValueError:
                pass

    def clean_profile(self, browser: BrowserType,
                     profile_name: str) -> Generator[CleanResult, None, None]:
        """Clean entire browser profile"""
        from .scanner import BrowserScanner

        scanner = BrowserScanner(self.config, self.logger)

        for result in scanner.scan():
            if (result.details.get('browser') == browser.value and
                result.details.get('profile') == profile_name):
                yield from self._clean_item(result)

    def save_backup(self, path: str):
        """Save backup to file"""
        if self._backup:
            backup_data = {
                'entries': [
                    {
                        'browser': e.browser,
                        'profile': e.profile,
                        'data_type': e.data_type,
                        'original_path': e.original_path,
                        'backup_path': e.backup_path,
                        'timestamp': e.timestamp,
                    }
                    for e in self._backup.entries
                ],
                'created_at': self._backup.created_at,
            }
            with open(path, 'w', encoding='utf-8') as f:
                json.dump(backup_data, f, indent=2)

    def get_cleaned_items(self) -> List[str]:
        """Get list of cleaned items"""
        return self._cleaned_items


class BrowserCleanerFactory:
    """Factory for browser-specific cleaners"""

    @staticmethod
    def get_cleaner(browser: BrowserType, config: Config,
                   logger: Logger = None) -> 'BrowserCleaner':
        """Get browser-specific cleaner"""
        from .chrome import ChromeCleaner
        from .firefox import FirefoxCleaner
        from .edge import EdgeCleaner

        cleaners = {
            BrowserType.CHROME: ChromeCleaner,
            BrowserType.FIREFOX: FirefoxCleaner,
            BrowserType.EDGE: EdgeCleaner,
        }

        cleaner_class = cleaners.get(browser, BrowserCleaner)
        return cleaner_class(config, logger)

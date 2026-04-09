"""
Firefox cleaner for Ultimate Uninstaller
Firefox-specific cleaning functionality
"""

import os
import shutil
import sqlite3
from typing import List, Dict, Generator, Optional
from datetime import datetime
import json
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from core.base import CleanResult, ScanResult
from core.config import Config
from core.logger import Logger
from .cleaner import BrowserCleaner
from .scanner import BrowserType, BrowserDataType


class FirefoxCleaner(BrowserCleaner):
    """Firefox-specific cleaner"""

    FIREFOX_PATH = os.path.join(
        os.environ.get('APPDATA', ''),
        'Mozilla', 'Firefox', 'Profiles'
    )

    CACHE_PATH = os.path.join(
        os.environ.get('LOCALAPPDATA', ''),
        'Mozilla', 'Firefox', 'Profiles'
    )

    CACHE_DIRS = ['cache2', 'startupCache', 'thumbnails']

    TEMP_EXTENSIONS = ['.tmp', '.log', '.old', '.bak', '.mfasl']

    def __init__(self, config: Config, logger: Logger = None):
        super().__init__(config, logger)
        self.name = "FirefoxCleaner"

    def clean_cache(self) -> Generator[CleanResult, None, None]:
        """Clean Firefox cache"""
        yield from self._close_browser('firefox')

        for base_path in [self.FIREFOX_PATH, self.CACHE_PATH]:
            if not os.path.exists(base_path):
                continue

            profiles = self._get_profiles(base_path)

            for profile in profiles:
                for cache_dir in self.CACHE_DIRS:
                    cache_path = os.path.join(profile, cache_dir)

                    if os.path.exists(cache_path):
                        if self.config.dry_run:
                            yield CleanResult(
                                module=self.name,
                                action="delete (dry run)",
                                target=cache_path,
                                success=True,
                                message="Would delete"
                            )
                        else:
                            try:
                                shutil.rmtree(cache_path, ignore_errors=True)
                                self._cleaned_items.append(cache_path)
                                yield CleanResult(
                                    module=self.name,
                                    action="delete",
                                    target=cache_path,
                                    success=True,
                                    message="Deleted"
                                )
                            except Exception as e:
                                yield CleanResult(
                                    module=self.name,
                                    action="delete",
                                    target=cache_path,
                                    success=False,
                                    message=str(e)
                                )

    def clean_cookies(self) -> Generator[CleanResult, None, None]:
        """Clean Firefox cookies"""
        yield from self._close_browser('firefox')

        if not os.path.exists(self.FIREFOX_PATH):
            return

        profiles = self._get_profiles(self.FIREFOX_PATH)

        for profile in profiles:
            cookies_path = os.path.join(profile, 'cookies.sqlite')
            cookies_wal = os.path.join(profile, 'cookies.sqlite-wal')
            cookies_shm = os.path.join(profile, 'cookies.sqlite-shm')

            for path in [cookies_path, cookies_wal, cookies_shm]:
                if os.path.exists(path):
                    if self.config.dry_run:
                        yield CleanResult(
                            module=self.name,
                            action="delete (dry run)",
                            target=path,
                            success=True,
                            message="Would delete"
                        )
                    else:
                        try:
                            os.remove(path)
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

    def clean_history(self) -> Generator[CleanResult, None, None]:
        """Clean Firefox browsing history"""
        yield from self._close_browser('firefox')

        if not os.path.exists(self.FIREFOX_PATH):
            return

        profiles = self._get_profiles(self.FIREFOX_PATH)

        for profile in profiles:
            places_path = os.path.join(profile, 'places.sqlite')

            if os.path.exists(places_path):
                if self.config.dry_run:
                    yield CleanResult(
                        module=self.name,
                        action="clear (dry run)",
                        target=f"{places_path}:history",
                        success=True,
                        message="Would clear history"
                    )
                else:
                    try:
                        conn = sqlite3.connect(places_path)
                        cursor = conn.cursor()
                        cursor.execute("DELETE FROM moz_historyvisits")
                        cursor.execute("DELETE FROM moz_inputhistory")
                        cursor.execute("VACUUM")
                        conn.commit()
                        conn.close()

                        yield CleanResult(
                            module=self.name,
                            action="clear",
                            target=f"{places_path}:history",
                            success=True,
                            message="Cleared"
                        )
                    except Exception as e:
                        yield CleanResult(
                            module=self.name,
                            action="clear",
                            target=f"{places_path}:history",
                            success=False,
                            message=str(e)
                        )

    def clean_downloads_history(self) -> Generator[CleanResult, None, None]:
        """Clean Firefox download history"""
        yield from self._close_browser('firefox')

        if not os.path.exists(self.FIREFOX_PATH):
            return

        profiles = self._get_profiles(self.FIREFOX_PATH)

        for profile in profiles:
            downloads_path = os.path.join(profile, 'downloads.sqlite')

            if os.path.exists(downloads_path):
                if self.config.dry_run:
                    yield CleanResult(
                        module=self.name,
                        action="delete (dry run)",
                        target=downloads_path,
                        success=True,
                        message="Would delete"
                    )
                else:
                    try:
                        os.remove(downloads_path)
                        self._cleaned_items.append(downloads_path)
                        yield CleanResult(
                            module=self.name,
                            action="delete",
                            target=downloads_path,
                            success=True,
                            message="Deleted"
                        )
                    except Exception as e:
                        yield CleanResult(
                            module=self.name,
                            action="delete",
                            target=downloads_path,
                            success=False,
                            message=str(e)
                        )

    def clean_form_history(self) -> Generator[CleanResult, None, None]:
        """Clean Firefox form history"""
        yield from self._close_browser('firefox')

        if not os.path.exists(self.FIREFOX_PATH):
            return

        profiles = self._get_profiles(self.FIREFOX_PATH)

        for profile in profiles:
            formhistory_path = os.path.join(profile, 'formhistory.sqlite')

            if os.path.exists(formhistory_path):
                if self.config.dry_run:
                    yield CleanResult(
                        module=self.name,
                        action="clear (dry run)",
                        target=formhistory_path,
                        success=True,
                        message="Would clear"
                    )
                else:
                    try:
                        conn = sqlite3.connect(formhistory_path)
                        cursor = conn.cursor()
                        cursor.execute("DELETE FROM moz_formhistory")
                        cursor.execute("VACUUM")
                        conn.commit()
                        conn.close()

                        yield CleanResult(
                            module=self.name,
                            action="clear",
                            target=formhistory_path,
                            success=True,
                            message="Cleared"
                        )
                    except Exception as e:
                        yield CleanResult(
                            module=self.name,
                            action="clear",
                            target=formhistory_path,
                            success=False,
                            message=str(e)
                        )

    def clean_session_data(self) -> Generator[CleanResult, None, None]:
        """Clean Firefox session data"""
        yield from self._close_browser('firefox')

        if not os.path.exists(self.FIREFOX_PATH):
            return

        profiles = self._get_profiles(self.FIREFOX_PATH)

        session_files = [
            'sessionstore.jsonlz4', 'sessionstore.js',
            'sessionstore-backups', 'sessionCheckpoints.json',
        ]

        for profile in profiles:
            for sess_file in session_files:
                sess_path = os.path.join(profile, sess_file)

                if os.path.exists(sess_path):
                    if self.config.dry_run:
                        yield CleanResult(
                            module=self.name,
                            action="delete (dry run)",
                            target=sess_path,
                            success=True,
                            message="Would delete"
                        )
                    else:
                        try:
                            if os.path.isfile(sess_path):
                                os.remove(sess_path)
                            else:
                                shutil.rmtree(sess_path, ignore_errors=True)
                            self._cleaned_items.append(sess_path)
                            yield CleanResult(
                                module=self.name,
                                action="delete",
                                target=sess_path,
                                success=True,
                                message="Deleted"
                            )
                        except Exception as e:
                            yield CleanResult(
                                module=self.name,
                                action="delete",
                                target=sess_path,
                                success=False,
                                message=str(e)
                            )

    def clean_crash_reports(self) -> Generator[CleanResult, None, None]:
        """Clean Firefox crash reports"""
        crash_paths = [
            os.path.join(os.environ.get('APPDATA', ''),
                        'Mozilla', 'Firefox', 'Crash Reports'),
            os.path.join(os.environ.get('LOCALAPPDATA', ''),
                        'Mozilla', 'Firefox', 'Crash Reports'),
        ]

        for crash_path in crash_paths:
            if os.path.exists(crash_path):
                if self.config.dry_run:
                    yield CleanResult(
                        module=self.name,
                        action="delete (dry run)",
                        target=crash_path,
                        success=True,
                        message="Would delete"
                    )
                else:
                    try:
                        shutil.rmtree(crash_path, ignore_errors=True)
                        self._cleaned_items.append(crash_path)
                        yield CleanResult(
                            module=self.name,
                            action="delete",
                            target=crash_path,
                            success=True,
                            message="Deleted"
                        )
                    except Exception as e:
                        yield CleanResult(
                            module=self.name,
                            action="delete",
                            target=crash_path,
                            success=False,
                            message=str(e)
                        )

    def clean_temp_files(self) -> Generator[CleanResult, None, None]:
        """Clean Firefox temporary files"""
        if not os.path.exists(self.FIREFOX_PATH):
            return

        profiles = self._get_profiles(self.FIREFOX_PATH)

        for profile in profiles:
            for root, dirs, files in os.walk(profile):
                for f in files:
                    if any(f.endswith(ext) for ext in self.TEMP_EXTENSIONS):
                        file_path = os.path.join(root, f)

                        if self.config.dry_run:
                            yield CleanResult(
                                module=self.name,
                                action="delete (dry run)",
                                target=file_path,
                                success=True,
                                message="Would delete"
                            )
                        else:
                            try:
                                os.remove(file_path)
                                self._cleaned_items.append(file_path)
                                yield CleanResult(
                                    module=self.name,
                                    action="delete",
                                    target=file_path,
                                    success=True,
                                    message="Deleted"
                                )
                            except Exception as e:
                                pass

    def clean_all(self) -> Generator[CleanResult, None, None]:
        """Clean all Firefox data"""
        yield from self.clean_cache()
        yield from self.clean_cookies()
        yield from self.clean_history()
        yield from self.clean_downloads_history()
        yield from self.clean_form_history()
        yield from self.clean_session_data()
        yield from self.clean_crash_reports()
        yield from self.clean_temp_files()

    def _get_profiles(self, base_path: str) -> List[str]:
        """Get Firefox profile directories"""
        profiles = []

        try:
            for item in os.listdir(base_path):
                profile_path = os.path.join(base_path, item)
                if os.path.isdir(profile_path):
                    profiles.append(profile_path)
        except Exception:
            pass

        return profiles

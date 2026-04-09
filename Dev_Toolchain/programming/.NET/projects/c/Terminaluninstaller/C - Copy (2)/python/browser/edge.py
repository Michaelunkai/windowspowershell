"""
Edge cleaner for Ultimate Uninstaller
Microsoft Edge-specific cleaning functionality
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


class EdgeCleaner(BrowserCleaner):
    """Microsoft Edge-specific cleaner"""

    EDGE_PATH = os.path.join(
        os.environ.get('LOCALAPPDATA', ''),
        'Microsoft', 'Edge', 'User Data'
    )

    CACHE_DIRS = [
        'Cache', 'Code Cache', 'GPUCache', 'ShaderCache',
        'GrShaderCache', 'Service Worker', 'Storage',
    ]

    TEMP_EXTENSIONS = ['.tmp', '.log', '.old', '.bak']

    def __init__(self, config: Config, logger: Logger = None):
        super().__init__(config, logger)
        self.name = "EdgeCleaner"

    def clean_cache(self) -> Generator[CleanResult, None, None]:
        """Clean Edge cache directories"""
        yield from self._close_browser('edge')

        if not os.path.exists(self.EDGE_PATH):
            return

        profiles = self._get_profiles()

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
        """Clean Edge cookies"""
        yield from self._close_browser('edge')

        if not os.path.exists(self.EDGE_PATH):
            return

        profiles = self._get_profiles()

        for profile in profiles:
            cookies_path = os.path.join(profile, 'Cookies')
            cookies_journal = os.path.join(profile, 'Cookies-journal')

            for path in [cookies_path, cookies_journal]:
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
        """Clean Edge browsing history"""
        yield from self._close_browser('edge')

        if not os.path.exists(self.EDGE_PATH):
            return

        profiles = self._get_profiles()

        history_files = ['History', 'History-journal', 'Visited Links',
                        'Top Sites', 'Top Sites-journal']

        for profile in profiles:
            for hist_file in history_files:
                hist_path = os.path.join(profile, hist_file)

                if os.path.exists(hist_path):
                    if self.config.dry_run:
                        yield CleanResult(
                            module=self.name,
                            action="delete (dry run)",
                            target=hist_path,
                            success=True,
                            message="Would delete"
                        )
                    else:
                        try:
                            os.remove(hist_path)
                            self._cleaned_items.append(hist_path)
                            yield CleanResult(
                                module=self.name,
                                action="delete",
                                target=hist_path,
                                success=True,
                                message="Deleted"
                            )
                        except Exception as e:
                            yield CleanResult(
                                module=self.name,
                                action="delete",
                                target=hist_path,
                                success=False,
                                message=str(e)
                            )

    def clean_downloads_history(self) -> Generator[CleanResult, None, None]:
        """Clean Edge download history"""
        yield from self._close_browser('edge')

        if not os.path.exists(self.EDGE_PATH):
            return

        profiles = self._get_profiles()

        for profile in profiles:
            history_path = os.path.join(profile, 'History')

            if os.path.exists(history_path):
                if self.config.dry_run:
                    yield CleanResult(
                        module=self.name,
                        action="clear (dry run)",
                        target=f"{history_path}:downloads",
                        success=True,
                        message="Would clear downloads"
                    )
                else:
                    try:
                        conn = sqlite3.connect(history_path)
                        cursor = conn.cursor()
                        cursor.execute("DELETE FROM downloads")
                        cursor.execute("DELETE FROM downloads_url_chains")
                        conn.commit()
                        conn.close()

                        yield CleanResult(
                            module=self.name,
                            action="clear",
                            target=f"{history_path}:downloads",
                            success=True,
                            message="Cleared"
                        )
                    except Exception as e:
                        yield CleanResult(
                            module=self.name,
                            action="clear",
                            target=f"{history_path}:downloads",
                            success=False,
                            message=str(e)
                        )

    def clean_autofill(self) -> Generator[CleanResult, None, None]:
        """Clean Edge autofill data"""
        yield from self._close_browser('edge')

        if not os.path.exists(self.EDGE_PATH):
            return

        profiles = self._get_profiles()

        for profile in profiles:
            webdata_path = os.path.join(profile, 'Web Data')

            if os.path.exists(webdata_path):
                if self.config.dry_run:
                    yield CleanResult(
                        module=self.name,
                        action="clear (dry run)",
                        target=f"{webdata_path}:autofill",
                        success=True,
                        message="Would clear autofill"
                    )
                else:
                    try:
                        conn = sqlite3.connect(webdata_path)
                        cursor = conn.cursor()
                        cursor.execute("DELETE FROM autofill")
                        cursor.execute("DELETE FROM autofill_profiles")
                        conn.commit()
                        conn.close()

                        yield CleanResult(
                            module=self.name,
                            action="clear",
                            target=f"{webdata_path}:autofill",
                            success=True,
                            message="Cleared"
                        )
                    except Exception as e:
                        yield CleanResult(
                            module=self.name,
                            action="clear",
                            target=f"{webdata_path}:autofill",
                            success=False,
                            message=str(e)
                        )

    def clean_session_data(self) -> Generator[CleanResult, None, None]:
        """Clean Edge session data"""
        yield from self._close_browser('edge')

        if not os.path.exists(self.EDGE_PATH):
            return

        profiles = self._get_profiles()

        session_files = ['Current Session', 'Current Tabs',
                        'Last Session', 'Last Tabs']

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
                            os.remove(sess_path)
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

    def clean_collections(self) -> Generator[CleanResult, None, None]:
        """Clean Edge collections data"""
        yield from self._close_browser('edge')

        if not os.path.exists(self.EDGE_PATH):
            return

        profiles = self._get_profiles()

        for profile in profiles:
            collections_path = os.path.join(profile, 'Collections')

            if os.path.exists(collections_path):
                if self.config.dry_run:
                    yield CleanResult(
                        module=self.name,
                        action="delete (dry run)",
                        target=collections_path,
                        success=True,
                        message="Would delete"
                    )
                else:
                    try:
                        shutil.rmtree(collections_path, ignore_errors=True)
                        self._cleaned_items.append(collections_path)
                        yield CleanResult(
                            module=self.name,
                            action="delete",
                            target=collections_path,
                            success=True,
                            message="Deleted"
                        )
                    except Exception as e:
                        yield CleanResult(
                            module=self.name,
                            action="delete",
                            target=collections_path,
                            success=False,
                            message=str(e)
                        )

    def clean_temp_files(self) -> Generator[CleanResult, None, None]:
        """Clean Edge temporary files"""
        if not os.path.exists(self.EDGE_PATH):
            return

        profiles = self._get_profiles()

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
        """Clean all Edge data"""
        yield from self.clean_cache()
        yield from self.clean_cookies()
        yield from self.clean_history()
        yield from self.clean_downloads_history()
        yield from self.clean_session_data()
        yield from self.clean_temp_files()

    def _get_profiles(self) -> List[str]:
        """Get Edge profile directories"""
        profiles = []

        default_path = os.path.join(self.EDGE_PATH, 'Default')
        if os.path.exists(default_path):
            profiles.append(default_path)

        try:
            for item in os.listdir(self.EDGE_PATH):
                if item.startswith('Profile '):
                    profile_path = os.path.join(self.EDGE_PATH, item)
                    if os.path.isdir(profile_path):
                        profiles.append(profile_path)
        except Exception:
            pass

        return profiles

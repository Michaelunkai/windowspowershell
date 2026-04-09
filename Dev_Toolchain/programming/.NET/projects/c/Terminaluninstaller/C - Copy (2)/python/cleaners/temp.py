"""
Temp file cleaner for Ultimate Uninstaller
Cleans temporary files across the system
"""

import os
import shutil
from typing import List, Dict, Generator, Optional, Set
from dataclasses import dataclass, field
from datetime import datetime, timedelta
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from core.base import BaseCleaner, CleanResult, ScanResult
from core.config import Config
from core.logger import Logger


@dataclass
class TempLocation:
    """Temporary file location"""
    name: str
    path: str
    extensions: List[str] = field(default_factory=list)
    max_age_days: int = 0


class TempCleaner(BaseCleaner):
    """Cleans temporary files"""

    TEMP_EXTENSIONS = [
        '.tmp', '.temp', '.~tmp', '.~temp',
        '.bak', '.backup', '.old', '.orig',
        '.log', '.log1', '.log2',
        '.dmp', '.dump', '.mdmp',
        '.chk', '.gid', '.fts', '.ftg',
        '._mp', '.prv', '.pf',
        '.err', '.crash',
    ]

    TEMP_PREFIXES = [
        '~$', '~WRL', '~WRS', 'ppt', 'CVR',
        'FXS', 'hsperfdata_',
    ]

    TEMP_PATTERNS = [
        'Thumbs.db', 'desktop.ini', '.DS_Store',
        '*.stackdump', 'core.*',
    ]

    def __init__(self, config: Config, logger: Logger = None):
        super().__init__(config, logger)
        self._locations = self._get_temp_locations()
        self._cleaned_items: List[str] = []
        self._total_size_cleaned = 0
        self._files_deleted = 0

    def _get_temp_locations(self) -> List[TempLocation]:
        """Get temp file locations"""
        temp = os.environ.get('TEMP', '')
        tmp = os.environ.get('TMP', '')
        localappdata = os.environ.get('LOCALAPPDATA', '')
        userprofile = os.environ.get('USERPROFILE', '')
        windir = os.environ.get('WINDIR', 'C:\\Windows')

        return [
            TempLocation(
                name="User Temp",
                path=temp,
                max_age_days=0,
            ),
            TempLocation(
                name="User TMP",
                path=tmp,
                max_age_days=0,
            ),
            TempLocation(
                name="Windows Temp",
                path=os.path.join(windir, 'Temp'),
                max_age_days=0,
            ),
            TempLocation(
                name="Low Temp",
                path=os.path.join(localappdata, 'Temp'),
                max_age_days=0,
            ),
            TempLocation(
                name="Recent Documents",
                path=os.path.join(userprofile, 'Recent'),
                extensions=['.lnk'],
                max_age_days=30,
            ),
            TempLocation(
                name="Downloads Temp",
                path=os.path.join(userprofile, 'Downloads'),
                extensions=['.tmp', '.crdownload', '.partial'],
                max_age_days=7,
            ),
            TempLocation(
                name="Crash Dumps",
                path=os.path.join(localappdata, 'CrashDumps'),
                max_age_days=0,
            ),
            TempLocation(
                name="Microsoft Temp",
                path=os.path.join(localappdata, 'Microsoft', 'Windows', 'WER'),
                max_age_days=0,
            ),
        ]

    def scan(self) -> Generator[ScanResult, None, None]:
        """Scan for temporary files"""
        self.log_info("Scanning temporary files")

        for location in self._locations:
            if not os.path.exists(location.path):
                continue

            try:
                file_count, total_size = self._scan_location(location)

                if file_count > 0:
                    yield ScanResult(
                        module=self.name,
                        item_type="temp",
                        name=location.name,
                        path=location.path,
                        size=total_size,
                        details={
                            'file_count': file_count,
                            'extensions': location.extensions,
                            'max_age_days': location.max_age_days,
                        }
                    )
            except Exception as e:
                self.log_error(f"Failed to scan {location.path}: {e}")

        yield from self._scan_system_temp_files()

    def _scan_location(self, location: TempLocation) -> tuple:
        """Scan a temp location"""
        file_count = 0
        total_size = 0
        cutoff_date = None

        if location.max_age_days > 0:
            cutoff_date = datetime.now() - timedelta(days=location.max_age_days)

        try:
            for root, dirs, files in os.walk(location.path):
                for f in files:
                    file_path = os.path.join(root, f)

                    if self._is_temp_file(f, location.extensions):
                        if cutoff_date:
                            try:
                                mtime = datetime.fromtimestamp(os.path.getmtime(file_path))
                                if mtime > cutoff_date:
                                    continue
                            except:
                                pass

                        try:
                            total_size += os.path.getsize(file_path)
                            file_count += 1
                        except:
                            pass
        except:
            pass

        return file_count, total_size

    def _is_temp_file(self, filename: str, extensions: List[str] = None) -> bool:
        """Check if file is temporary"""
        filename_lower = filename.lower()

        if extensions:
            return any(filename_lower.endswith(ext) for ext in extensions)

        if any(filename_lower.endswith(ext) for ext in self.TEMP_EXTENSIONS):
            return True

        if any(filename_lower.startswith(prefix.lower()) for prefix in self.TEMP_PREFIXES):
            return True

        import fnmatch
        if any(fnmatch.fnmatch(filename_lower, pattern.lower())
               for pattern in self.TEMP_PATTERNS):
            return True

        return False

    def _scan_system_temp_files(self) -> Generator[ScanResult, None, None]:
        """Scan for system-wide temp files"""
        drives = self._get_drives()

        for drive in drives:
            recycler_path = os.path.join(drive, '$Recycle.Bin')
            if os.path.exists(recycler_path):
                try:
                    size = self._get_directory_size(recycler_path)
                    if size > 0:
                        yield ScanResult(
                            module=self.name,
                            item_type="recycle_bin",
                            name=f"Recycle Bin ({drive})",
                            path=recycler_path,
                            size=size,
                            details={'drive': drive}
                        )
                except:
                    pass

    def clean(self, items: List[ScanResult] = None) -> Generator[CleanResult, None, None]:
        """Clean temporary files"""
        self.log_info("Cleaning temporary files")

        if items:
            for item in items:
                if self.is_cancelled():
                    break
                self.wait_if_paused()

                if item.item_type == "recycle_bin":
                    yield from self._empty_recycle_bin()
                else:
                    yield from self._clean_path(item.path, item.name)
        else:
            for location in self._locations:
                if self.is_cancelled():
                    break
                self.wait_if_paused()
                yield from self._clean_location(location)

            yield from self._empty_recycle_bin()

    def _clean_location(self, location: TempLocation) -> Generator[CleanResult, None, None]:
        """Clean a temp location"""
        if not os.path.exists(location.path):
            return

        if self.config.dry_run:
            file_count, total_size = self._scan_location(location)
            yield CleanResult(
                module=self.name,
                action="clean (dry run)",
                target=f"{location.name}: {location.path}",
                success=True,
                message=f"Would delete {file_count} files ({self._format_size(total_size)})"
            )
            return

        cutoff_date = None
        if location.max_age_days > 0:
            cutoff_date = datetime.now() - timedelta(days=location.max_age_days)

        cleaned_count = 0
        cleaned_size = 0

        try:
            for root, dirs, files in os.walk(location.path, topdown=False):
                for f in files:
                    file_path = os.path.join(root, f)

                    if self._is_temp_file(f, location.extensions):
                        if cutoff_date:
                            try:
                                mtime = datetime.fromtimestamp(os.path.getmtime(file_path))
                                if mtime > cutoff_date:
                                    continue
                            except:
                                pass

                        try:
                            size = os.path.getsize(file_path)
                            os.remove(file_path)
                            cleaned_count += 1
                            cleaned_size += size
                        except:
                            pass

                for d in dirs:
                    dir_path = os.path.join(root, d)
                    try:
                        if not os.listdir(dir_path):
                            os.rmdir(dir_path)
                    except:
                        pass

            self._total_size_cleaned += cleaned_size
            self._files_deleted += cleaned_count

            yield CleanResult(
                module=self.name,
                action="clean",
                target=f"{location.name}: {location.path}",
                success=True,
                message=f"Deleted {cleaned_count} files ({self._format_size(cleaned_size)})"
            )
        except Exception as e:
            yield CleanResult(
                module=self.name,
                action="clean",
                target=f"{location.name}: {location.path}",
                success=False,
                message=str(e)
            )

    def _clean_path(self, path: str, name: str) -> Generator[CleanResult, None, None]:
        """Clean a specific path"""
        if not os.path.exists(path):
            return

        if self.config.dry_run:
            size = self._get_directory_size(path)
            yield CleanResult(
                module=self.name,
                action="clean (dry run)",
                target=f"{name}: {path}",
                success=True,
                message=f"Would clean {self._format_size(size)}"
            )
            return

        try:
            size_before = self._get_directory_size(path)

            for item in os.listdir(path):
                item_path = os.path.join(path, item)
                try:
                    if os.path.isfile(item_path):
                        os.remove(item_path)
                    elif os.path.isdir(item_path):
                        shutil.rmtree(item_path, ignore_errors=True)
                except:
                    pass

            size_after = self._get_directory_size(path)
            cleaned_size = size_before - size_after
            self._total_size_cleaned += cleaned_size

            yield CleanResult(
                module=self.name,
                action="clean",
                target=f"{name}: {path}",
                success=True,
                message=f"Cleaned {self._format_size(cleaned_size)}"
            )
        except Exception as e:
            yield CleanResult(
                module=self.name,
                action="clean",
                target=f"{name}: {path}",
                success=False,
                message=str(e)
            )

    def _empty_recycle_bin(self) -> Generator[CleanResult, None, None]:
        """Empty the recycle bin"""
        if self.config.dry_run:
            yield CleanResult(
                module=self.name,
                action="empty (dry run)",
                target="Recycle Bin",
                success=True,
                message="Would empty recycle bin"
            )
            return

        try:
            import ctypes
            from ctypes import wintypes

            shell32 = ctypes.windll.shell32
            SHEmptyRecycleBin = shell32.SHEmptyRecycleBinW
            SHEmptyRecycleBin.argtypes = [wintypes.HWND, wintypes.LPCWSTR, wintypes.DWORD]
            SHEmptyRecycleBin.restype = ctypes.c_int

            SHERB_NOCONFIRMATION = 0x00000001
            SHERB_NOPROGRESSUI = 0x00000002
            SHERB_NOSOUND = 0x00000004

            flags = SHERB_NOCONFIRMATION | SHERB_NOPROGRESSUI | SHERB_NOSOUND
            result = SHEmptyRecycleBin(None, None, flags)

            if result == 0:
                yield CleanResult(
                    module=self.name,
                    action="empty",
                    target="Recycle Bin",
                    success=True,
                    message="Recycle bin emptied"
                )
            else:
                yield CleanResult(
                    module=self.name,
                    action="empty",
                    target="Recycle Bin",
                    success=True,
                    message="Recycle bin empty or already cleared"
                )
        except Exception as e:
            yield CleanResult(
                module=self.name,
                action="empty",
                target="Recycle Bin",
                success=False,
                message=str(e)
            )

    def _get_drives(self) -> List[str]:
        """Get available drives"""
        drives = []
        for letter in 'ABCDEFGHIJKLMNOPQRSTUVWXYZ':
            drive = f"{letter}:\\"
            if os.path.exists(drive):
                drives.append(drive)
        return drives

    def _get_directory_size(self, path: str) -> int:
        """Get total size of directory"""
        total = 0
        try:
            for root, dirs, files in os.walk(path):
                for f in files:
                    try:
                        total += os.path.getsize(os.path.join(root, f))
                    except:
                        pass
        except:
            pass
        return total

    def _format_size(self, size: int) -> str:
        """Format size for display"""
        for unit in ['B', 'KB', 'MB', 'GB']:
            if size < 1024:
                return f"{size:.1f} {unit}"
            size /= 1024
        return f"{size:.1f} TB"

    def get_cleaned_items(self) -> List[str]:
        return self._cleaned_items

    def get_total_size_cleaned(self) -> int:
        return self._total_size_cleaned

    def get_files_deleted(self) -> int:
        return self._files_deleted

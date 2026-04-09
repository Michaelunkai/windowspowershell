"""
Thumbnail cleaner for Ultimate Uninstaller
Cleans Windows thumbnail cache and icon cache
"""

import os
import shutil
import subprocess
from typing import List, Dict, Generator, Optional
from dataclasses import dataclass
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from core.base import BaseCleaner, CleanResult, ScanResult
from core.config import Config
from core.logger import Logger


@dataclass
class ThumbnailCache:
    """Thumbnail cache information"""
    name: str
    path: str
    size: int
    file_count: int


class ThumbnailCleaner(BaseCleaner):
    """Cleans Windows thumbnail and icon caches"""

    THUMBNAIL_PATTERNS = ['thumbcache_*.db', 'iconcache_*.db']

    CACHE_LOCATIONS = [
        os.path.join(os.environ.get('LOCALAPPDATA', ''),
                    'Microsoft', 'Windows', 'Explorer'),
    ]

    def __init__(self, config: Config, logger: Logger = None):
        super().__init__(config, logger)
        self._caches: List[ThumbnailCache] = []
        self._cleaned_items: List[str] = []
        self._total_size_cleaned = 0

    def scan(self) -> Generator[ScanResult, None, None]:
        """Scan thumbnail caches"""
        self.log_info("Scanning thumbnail caches")

        for location in self.CACHE_LOCATIONS:
            if not os.path.exists(location):
                continue

            try:
                thumb_count, thumb_size = self._scan_thumbnails(location)
                icon_count, icon_size = self._scan_icons(location)

                total_count = thumb_count + icon_count
                total_size = thumb_size + icon_size

                if total_count > 0:
                    cache = ThumbnailCache(
                        name="Windows Explorer Cache",
                        path=location,
                        size=total_size,
                        file_count=total_count,
                    )
                    self._caches.append(cache)

                    yield ScanResult(
                        module=self.name,
                        item_type="thumbnail_cache",
                        name="Windows Explorer Cache",
                        path=location,
                        size=total_size,
                        details={
                            'thumbnail_count': thumb_count,
                            'thumbnail_size': thumb_size,
                            'icon_count': icon_count,
                            'icon_size': icon_size,
                        }
                    )
            except Exception as e:
                self.log_error(f"Failed to scan {location}: {e}")

    def _scan_thumbnails(self, path: str) -> tuple:
        """Scan thumbnail cache files"""
        import fnmatch

        count = 0
        size = 0

        try:
            for f in os.listdir(path):
                if fnmatch.fnmatch(f.lower(), 'thumbcache_*.db'):
                    file_path = os.path.join(path, f)
                    try:
                        size += os.path.getsize(file_path)
                        count += 1
                    except:
                        pass
        except:
            pass

        return count, size

    def _scan_icons(self, path: str) -> tuple:
        """Scan icon cache files"""
        import fnmatch

        count = 0
        size = 0

        try:
            for f in os.listdir(path):
                if fnmatch.fnmatch(f.lower(), 'iconcache_*.db'):
                    file_path = os.path.join(path, f)
                    try:
                        size += os.path.getsize(file_path)
                        count += 1
                    except:
                        pass
        except:
            pass

        return count, size

    def clean(self, items: List[ScanResult] = None) -> Generator[CleanResult, None, None]:
        """Clean thumbnail caches"""
        self.log_info("Cleaning thumbnail caches")

        yield from self._stop_explorer()

        for location in self.CACHE_LOCATIONS:
            if not os.path.exists(location):
                continue

            yield from self._clean_thumbnails(location)
            yield from self._clean_icons(location)

        yield from self._start_explorer()

    def _stop_explorer(self) -> Generator[CleanResult, None, None]:
        """Stop Windows Explorer"""
        if self.config.dry_run:
            yield CleanResult(
                module=self.name,
                action="stop (dry run)",
                target="Windows Explorer",
                success=True,
                message="Would stop Explorer"
            )
            return

        try:
            result = subprocess.run(
                ['taskkill', '/f', '/im', 'explorer.exe'],
                capture_output=True, timeout=30
            )

            if result.returncode == 0:
                yield CleanResult(
                    module=self.name,
                    action="stop",
                    target="Windows Explorer",
                    success=True,
                    message="Explorer stopped"
                )
            else:
                yield CleanResult(
                    module=self.name,
                    action="stop",
                    target="Windows Explorer",
                    success=False,
                    message="Failed to stop Explorer"
                )
        except Exception as e:
            yield CleanResult(
                module=self.name,
                action="stop",
                target="Windows Explorer",
                success=False,
                message=str(e)
            )

    def _start_explorer(self) -> Generator[CleanResult, None, None]:
        """Start Windows Explorer"""
        if self.config.dry_run:
            yield CleanResult(
                module=self.name,
                action="start (dry run)",
                target="Windows Explorer",
                success=True,
                message="Would start Explorer"
            )
            return

        try:
            subprocess.Popen(['explorer.exe'])

            yield CleanResult(
                module=self.name,
                action="start",
                target="Windows Explorer",
                success=True,
                message="Explorer started"
            )
        except Exception as e:
            yield CleanResult(
                module=self.name,
                action="start",
                target="Windows Explorer",
                success=False,
                message=str(e)
            )

    def _clean_thumbnails(self, path: str) -> Generator[CleanResult, None, None]:
        """Clean thumbnail cache files"""
        import fnmatch

        if self.config.dry_run:
            count, size = self._scan_thumbnails(path)
            yield CleanResult(
                module=self.name,
                action="delete (dry run)",
                target=f"Thumbnail cache: {path}",
                success=True,
                message=f"Would delete {count} files ({self._format_size(size)})"
            )
            return

        cleaned_count = 0
        cleaned_size = 0

        try:
            for f in os.listdir(path):
                if fnmatch.fnmatch(f.lower(), 'thumbcache_*.db'):
                    file_path = os.path.join(path, f)
                    try:
                        size = os.path.getsize(file_path)
                        os.remove(file_path)
                        cleaned_count += 1
                        cleaned_size += size
                        self._cleaned_items.append(file_path)
                    except:
                        pass

            self._total_size_cleaned += cleaned_size

            yield CleanResult(
                module=self.name,
                action="delete",
                target=f"Thumbnail cache: {path}",
                success=True,
                message=f"Deleted {cleaned_count} files ({self._format_size(cleaned_size)})"
            )
        except Exception as e:
            yield CleanResult(
                module=self.name,
                action="delete",
                target=f"Thumbnail cache: {path}",
                success=False,
                message=str(e)
            )

    def _clean_icons(self, path: str) -> Generator[CleanResult, None, None]:
        """Clean icon cache files"""
        import fnmatch

        if self.config.dry_run:
            count, size = self._scan_icons(path)
            yield CleanResult(
                module=self.name,
                action="delete (dry run)",
                target=f"Icon cache: {path}",
                success=True,
                message=f"Would delete {count} files ({self._format_size(size)})"
            )
            return

        cleaned_count = 0
        cleaned_size = 0

        try:
            for f in os.listdir(path):
                if fnmatch.fnmatch(f.lower(), 'iconcache_*.db'):
                    file_path = os.path.join(path, f)
                    try:
                        size = os.path.getsize(file_path)
                        os.remove(file_path)
                        cleaned_count += 1
                        cleaned_size += size
                        self._cleaned_items.append(file_path)
                    except:
                        pass

            self._total_size_cleaned += cleaned_size

            yield CleanResult(
                module=self.name,
                action="delete",
                target=f"Icon cache: {path}",
                success=True,
                message=f"Deleted {cleaned_count} files ({self._format_size(cleaned_size)})"
            )
        except Exception as e:
            yield CleanResult(
                module=self.name,
                action="delete",
                target=f"Icon cache: {path}",
                success=False,
                message=str(e)
            )

    def rebuild_icon_cache(self) -> Generator[CleanResult, None, None]:
        """Rebuild icon cache using system command"""
        if self.config.dry_run:
            yield CleanResult(
                module=self.name,
                action="rebuild (dry run)",
                target="Icon Cache",
                success=True,
                message="Would rebuild icon cache"
            )
            return

        try:
            localappdata = os.environ.get('LOCALAPPDATA', '')
            cache_path = os.path.join(localappdata, 'Microsoft', 'Windows', 'Explorer')

            result = subprocess.run(
                ['ie4uinit.exe', '-ClearIconCache'],
                capture_output=True, timeout=30
            )

            yield CleanResult(
                module=self.name,
                action="rebuild",
                target="Icon Cache",
                success=True,
                message="Icon cache rebuild initiated"
            )
        except Exception as e:
            yield CleanResult(
                module=self.name,
                action="rebuild",
                target="Icon Cache",
                success=False,
                message=str(e)
            )

    def clear_font_cache(self) -> Generator[CleanResult, None, None]:
        """Clear Windows font cache"""
        font_cache_path = os.path.join(
            os.environ.get('WINDIR', 'C:\\Windows'),
            'ServiceProfiles', 'LocalService', 'AppData', 'Local'
        )

        if self.config.dry_run:
            yield CleanResult(
                module=self.name,
                action="clear (dry run)",
                target="Font Cache",
                success=True,
                message="Would clear font cache"
            )
            return

        try:
            if os.path.exists(font_cache_path):
                import fnmatch
                cleaned_count = 0

                for f in os.listdir(font_cache_path):
                    if fnmatch.fnmatch(f.lower(), 'fontcache*.dat'):
                        file_path = os.path.join(font_cache_path, f)
                        try:
                            os.remove(file_path)
                            cleaned_count += 1
                        except:
                            pass

                yield CleanResult(
                    module=self.name,
                    action="clear",
                    target="Font Cache",
                    success=True,
                    message=f"Cleared {cleaned_count} font cache files"
                )
            else:
                yield CleanResult(
                    module=self.name,
                    action="clear",
                    target="Font Cache",
                    success=True,
                    message="Font cache path not found"
                )
        except Exception as e:
            yield CleanResult(
                module=self.name,
                action="clear",
                target="Font Cache",
                success=False,
                message=str(e)
            )

    def _format_size(self, size: int) -> str:
        """Format size for display"""
        for unit in ['B', 'KB', 'MB', 'GB']:
            if size < 1024:
                return f"{size:.1f} {unit}"
            size /= 1024
        return f"{size:.1f} TB"

    def get_caches(self) -> List[ThumbnailCache]:
        return self._caches

    def get_cleaned_items(self) -> List[str]:
        return self._cleaned_items

    def get_total_size_cleaned(self) -> int:
        return self._total_size_cleaned

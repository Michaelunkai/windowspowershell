"""
Cache cleaner for Ultimate Uninstaller
Cleans various system and application caches
"""

import os
import shutil
from typing import List, Dict, Generator, Optional, Set
from dataclasses import dataclass, field
from datetime import datetime
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from core.base import BaseCleaner, CleanResult, ScanResult
from core.config import Config
from core.logger import Logger


@dataclass
class CacheLocation:
    """Cache location definition"""
    name: str
    path: str
    patterns: List[str] = field(default_factory=list)
    recursive: bool = True
    safe: bool = True


class CacheCleaner(BaseCleaner):
    """Cleans system and application caches"""

    def __init__(self, config: Config, logger: Logger = None):
        super().__init__(config, logger)
        self._locations = self._get_cache_locations()
        self._cleaned_items: List[str] = []
        self._total_size_cleaned = 0

    def _get_cache_locations(self) -> List[CacheLocation]:
        """Get cache locations to clean"""
        localappdata = os.environ.get('LOCALAPPDATA', '')
        appdata = os.environ.get('APPDATA', '')
        temp = os.environ.get('TEMP', '')
        userprofile = os.environ.get('USERPROFILE', '')
        windir = os.environ.get('WINDIR', 'C:\\Windows')

        return [
            CacheLocation(
                name="Windows Temp",
                path=temp,
                patterns=['*'],
                recursive=True,
                safe=True,
            ),
            CacheLocation(
                name="Windows Temp Alt",
                path=os.path.join(windir, 'Temp'),
                patterns=['*'],
                recursive=True,
                safe=True,
            ),
            CacheLocation(
                name="Icon Cache",
                path=os.path.join(localappdata, 'Microsoft', 'Windows', 'Explorer'),
                patterns=['iconcache*.db', 'thumbcache*.db'],
                recursive=False,
                safe=True,
            ),
            CacheLocation(
                name="Font Cache",
                path=os.path.join(windir, 'ServiceProfiles', 'LocalService', 'AppData', 'Local'),
                patterns=['FontCache*.dat'],
                recursive=False,
                safe=True,
            ),
            CacheLocation(
                name="Windows Installer Cache",
                path=os.path.join(windir, 'Installer', '$PatchCache$'),
                patterns=['*'],
                recursive=True,
                safe=False,
            ),
            CacheLocation(
                name="WDI Cache",
                path=os.path.join(windir, 'System32', 'wdi'),
                patterns=['*.etl'],
                recursive=True,
                safe=True,
            ),
            CacheLocation(
                name="Package Cache",
                path=os.path.join(os.environ.get('PROGRAMDATA', ''), 'Package Cache'),
                patterns=['*'],
                recursive=True,
                safe=False,
            ),
            CacheLocation(
                name=".NET Cache",
                path=os.path.join(windir, 'Microsoft.NET', 'Framework', 'v4.0.30319',
                                 'Temporary ASP.NET Files'),
                patterns=['*'],
                recursive=True,
                safe=True,
            ),
            CacheLocation(
                name=".NET 64 Cache",
                path=os.path.join(windir, 'Microsoft.NET', 'Framework64', 'v4.0.30319',
                                 'Temporary ASP.NET Files'),
                patterns=['*'],
                recursive=True,
                safe=True,
            ),
            CacheLocation(
                name="INetCache",
                path=os.path.join(localappdata, 'Microsoft', 'Windows', 'INetCache'),
                patterns=['*'],
                recursive=True,
                safe=True,
            ),
            CacheLocation(
                name="WebCache",
                path=os.path.join(localappdata, 'Microsoft', 'Windows', 'WebCache'),
                patterns=['*'],
                recursive=True,
                safe=True,
            ),
            CacheLocation(
                name="CryptnetUrlCache",
                path=os.path.join(localappdata, 'Microsoft', 'Windows', 'INetCache',
                                 'IE', 'CryptnetUrlCache'),
                patterns=['*'],
                recursive=True,
                safe=True,
            ),
            CacheLocation(
                name="Windows Store Cache",
                path=os.path.join(localappdata, 'Packages'),
                patterns=['AC', 'TempState', 'Cache'],
                recursive=True,
                safe=True,
            ),
            CacheLocation(
                name="Delivery Optimization Cache",
                path=os.path.join(windir, 'SoftwareDistribution', 'DeliveryOptimization'),
                patterns=['*'],
                recursive=True,
                safe=True,
            ),
        ]

    def scan(self) -> Generator[ScanResult, None, None]:
        """Scan cache locations"""
        self.log_info("Scanning cache locations")

        for location in self._locations:
            if not location.safe and not self.config.force:
                continue

            if not os.path.exists(location.path):
                continue

            try:
                size = self._get_directory_size(location.path)

                yield ScanResult(
                    module=self.name,
                    item_type="cache",
                    name=location.name,
                    path=location.path,
                    size=size,
                    details={
                        'patterns': location.patterns,
                        'recursive': location.recursive,
                        'safe': location.safe,
                    }
                )
            except Exception as e:
                self.log_error(f"Failed to scan {location.path}: {e}")

    def clean(self, items: List[ScanResult] = None) -> Generator[CleanResult, None, None]:
        """Clean cache locations"""
        self.log_info("Cleaning cache locations")

        if items:
            for item in items:
                if self.is_cancelled():
                    break
                self.wait_if_paused()
                yield from self._clean_path(item.path, item.name)
        else:
            for location in self._locations:
                if self.is_cancelled():
                    break
                self.wait_if_paused()

                if not location.safe and not self.config.force:
                    continue

                yield from self._clean_location(location)

    def _clean_location(self, location: CacheLocation) -> Generator[CleanResult, None, None]:
        """Clean a cache location"""
        if not os.path.exists(location.path):
            return

        if self.config.dry_run:
            size = self._get_directory_size(location.path)
            yield CleanResult(
                module=self.name,
                action="clean (dry run)",
                target=f"{location.name}: {location.path}",
                success=True,
                message=f"Would clean {self._format_size(size)}",
                details={'size': size}
            )
            return

        try:
            if location.patterns == ['*']:
                size_before = self._get_directory_size(location.path)
                self._clean_directory(location.path, location.recursive)
                size_after = self._get_directory_size(location.path)
                cleaned_size = size_before - size_after
                self._total_size_cleaned += cleaned_size

                yield CleanResult(
                    module=self.name,
                    action="clean",
                    target=f"{location.name}: {location.path}",
                    success=True,
                    message=f"Cleaned {self._format_size(cleaned_size)}",
                    details={'size_cleaned': cleaned_size}
                )
            else:
                for pattern in location.patterns:
                    yield from self._clean_pattern(location.path, pattern,
                                                   location.recursive, location.name)
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
            self._clean_directory(path, recursive=True)
            size_after = self._get_directory_size(path)
            cleaned_size = size_before - size_after
            self._total_size_cleaned += cleaned_size
            self._cleaned_items.append(path)

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

    def _clean_pattern(self, path: str, pattern: str, recursive: bool,
                      name: str) -> Generator[CleanResult, None, None]:
        """Clean files matching pattern"""
        import fnmatch

        try:
            cleaned_count = 0
            cleaned_size = 0

            if recursive:
                for root, dirs, files in os.walk(path):
                    for f in files:
                        if fnmatch.fnmatch(f.lower(), pattern.lower()):
                            file_path = os.path.join(root, f)
                            try:
                                size = os.path.getsize(file_path)
                                os.remove(file_path)
                                cleaned_count += 1
                                cleaned_size += size
                            except:
                                pass

                    for d in list(dirs):
                        if fnmatch.fnmatch(d.lower(), pattern.lower()):
                            dir_path = os.path.join(root, d)
                            try:
                                size = self._get_directory_size(dir_path)
                                shutil.rmtree(dir_path, ignore_errors=True)
                                cleaned_count += 1
                                cleaned_size += size
                                dirs.remove(d)
                            except:
                                pass
            else:
                for item in os.listdir(path):
                    if fnmatch.fnmatch(item.lower(), pattern.lower()):
                        item_path = os.path.join(path, item)
                        try:
                            if os.path.isfile(item_path):
                                size = os.path.getsize(item_path)
                                os.remove(item_path)
                            else:
                                size = self._get_directory_size(item_path)
                                shutil.rmtree(item_path, ignore_errors=True)
                            cleaned_count += 1
                            cleaned_size += size
                        except:
                            pass

            self._total_size_cleaned += cleaned_size

            if cleaned_count > 0:
                yield CleanResult(
                    module=self.name,
                    action="clean",
                    target=f"{name}: {pattern}",
                    success=True,
                    message=f"Cleaned {cleaned_count} items ({self._format_size(cleaned_size)})"
                )
        except Exception as e:
            yield CleanResult(
                module=self.name,
                action="clean",
                target=f"{name}: {pattern}",
                success=False,
                message=str(e)
            )

    def _clean_directory(self, path: str, recursive: bool = True):
        """Clean directory contents"""
        try:
            for item in os.listdir(path):
                item_path = os.path.join(path, item)
                try:
                    if os.path.isfile(item_path):
                        os.remove(item_path)
                    elif os.path.isdir(item_path) and recursive:
                        shutil.rmtree(item_path, ignore_errors=True)
                except:
                    pass
        except:
            pass

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

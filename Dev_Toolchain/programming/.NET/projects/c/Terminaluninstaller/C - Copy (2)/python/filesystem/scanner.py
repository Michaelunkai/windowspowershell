"""
Filesystem scanner for Ultimate Uninstaller
Deep scanning of file system for software traces
"""

import os
import stat
import fnmatch
from pathlib import Path
from typing import List, Dict, Generator, Optional, Set, Tuple, Any
from dataclasses import dataclass, field
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from core.base import BaseScanner, ScanResult
from core.config import Config, ScanDepth
from core.logger import Logger


@dataclass
class FileInfo:
    """File information"""
    path: str
    name: str
    size: int = 0
    created: float = 0.0
    modified: float = 0.0
    accessed: float = 0.0
    is_hidden: bool = False
    is_readonly: bool = False
    extension: str = ""

    def __post_init__(self):
        self.extension = Path(self.path).suffix.lower()


@dataclass
class DirectoryInfo:
    """Directory information"""
    path: str
    name: str
    file_count: int = 0
    dir_count: int = 0
    total_size: int = 0
    created: float = 0.0
    modified: float = 0.0


class FileSystemScanner(BaseScanner):
    """Deep filesystem scanner for finding software traces"""

    SKIP_DIRS = {
        '$recycle.bin', 'system volume information', 'windows',
        'program files', 'program files (x86)', 'programdata',
        'recovery', 'config.msi', 'msocache', 'perflogs',
    }

    EXECUTABLE_EXTENSIONS = {'.exe', '.dll', '.sys', '.msi', '.bat', '.cmd', '.ps1'}
    CONFIG_EXTENSIONS = {'.ini', '.cfg', '.conf', '.json', '.xml', '.yaml', '.yml'}
    DATA_EXTENSIONS = {'.dat', '.db', '.sqlite', '.log', '.cache'}

    def __init__(self, config: Config, logger: Logger = None):
        super().__init__(config, logger)
        self.fs_config = config.filesystem
        self._found_files: Dict[str, FileInfo] = {}
        self._found_dirs: Dict[str, DirectoryInfo] = {}

    def scan(self, target: str = None, patterns: List[str] = None,
             depth: ScanDepth = None) -> Generator[ScanResult, None, None]:
        """Scan filesystem for matching files and directories"""
        depth = depth or self.config.depth
        patterns = patterns or []

        if target:
            patterns.append(target.lower())

        self.log_info(f"Starting filesystem scan for: {patterns}")
        self._stats.items_scanned = 0

        scan_paths = self._get_scan_paths()

        with ThreadPoolExecutor(max_workers=8) as executor:
            futures = {}

            for scan_path in scan_paths:
                if os.path.exists(scan_path):
                    future = executor.submit(
                        self._scan_directory, scan_path, patterns, depth
                    )
                    futures[future] = scan_path

            for future in as_completed(futures):
                if self.is_cancelled():
                    break

                scan_path = futures[future]
                try:
                    for result in future.result():
                        yield result
                except Exception as e:
                    self.log_error(f"Error scanning {scan_path}: {e}")

        self.log_info(f"Filesystem scan complete. Found {self._stats.items_found} items")

    def _get_scan_paths(self) -> List[str]:
        """Get paths to scan"""
        paths = []

        if self.fs_config.scan_program_files:
            paths.extend([
                os.environ.get('PROGRAMFILES', r'C:\Program Files'),
                os.environ.get('PROGRAMFILES(X86)', r'C:\Program Files (x86)'),
            ])

        if self.fs_config.scan_appdata:
            appdata = os.environ.get('APPDATA', '')
            localappdata = os.environ.get('LOCALAPPDATA', '')
            if appdata:
                paths.append(appdata)
            if localappdata:
                paths.append(localappdata)

        if self.fs_config.scan_programdata:
            programdata = os.environ.get('PROGRAMDATA', r'C:\ProgramData')
            paths.append(programdata)

        if self.fs_config.scan_temp:
            paths.extend([
                os.environ.get('TEMP', ''),
                os.environ.get('TMP', ''),
            ])

        if self.fs_config.scan_user_profile:
            paths.append(os.path.expanduser('~'))

        return [p for p in paths if p and os.path.exists(p)]

    def _scan_directory(self, base_path: str, patterns: List[str],
                       depth: ScanDepth) -> Generator[ScanResult, None, None]:
        """Scan a directory recursively"""
        max_depth = {
            ScanDepth.QUICK: 2,
            ScanDepth.STANDARD: 5,
            ScanDepth.DEEP: 15,
            ScanDepth.FORENSIC: 50,
        }.get(depth, 5)

        yield from self._scan_recursive(base_path, patterns, 0, max_depth)

    def _scan_recursive(self, path: str, patterns: List[str],
                       current_depth: int, max_depth: int) -> Generator[ScanResult, None, None]:
        """Recursively scan directory"""
        if current_depth > max_depth or self.is_cancelled():
            return

        try:
            entries = list(os.scandir(path))
        except (PermissionError, OSError):
            return

        for entry in entries:
            if self.is_cancelled():
                break

            self._stats.items_scanned += 1

            try:
                name_lower = entry.name.lower()

                if entry.is_dir(follow_symlinks=False):
                    if name_lower in self.SKIP_DIRS:
                        continue

                    if self._matches_patterns(entry.name, patterns):
                        dir_info = self._get_dir_info(entry)
                        self._found_dirs[entry.path] = dir_info
                        self._stats.items_found += 1

                        yield ScanResult(
                            module=self.name,
                            item_type="directory",
                            path=entry.path,
                            name=entry.name,
                            details={
                                'size': dir_info.total_size,
                                'files': dir_info.file_count,
                                'dirs': dir_info.dir_count,
                            }
                        )

                    yield from self._scan_recursive(
                        entry.path, patterns,
                        current_depth + 1, max_depth
                    )

                elif entry.is_file(follow_symlinks=False):
                    if self._matches_patterns(entry.name, patterns):
                        file_info = self._get_file_info(entry)
                        self._found_files[entry.path] = file_info
                        self._stats.items_found += 1

                        yield ScanResult(
                            module=self.name,
                            item_type="file",
                            path=entry.path,
                            name=entry.name,
                            size=file_info.size,
                            details={
                                'extension': file_info.extension,
                                'modified': file_info.modified,
                                'hidden': file_info.is_hidden,
                            }
                        )

            except (PermissionError, OSError):
                continue

    def _matches_patterns(self, name: str, patterns: List[str]) -> bool:
        """Check if name matches any pattern"""
        if not patterns:
            return False

        name_lower = name.lower()
        return any(p.lower() in name_lower or fnmatch.fnmatch(name_lower, f"*{p.lower()}*")
                   for p in patterns)

    def _get_file_info(self, entry) -> FileInfo:
        """Get file information"""
        try:
            stat_info = entry.stat()
            return FileInfo(
                path=entry.path,
                name=entry.name,
                size=stat_info.st_size,
                created=stat_info.st_ctime,
                modified=stat_info.st_mtime,
                accessed=stat_info.st_atime,
                is_hidden=bool(stat_info.st_file_attributes & stat.FILE_ATTRIBUTE_HIDDEN)
                          if hasattr(stat_info, 'st_file_attributes') else False,
                is_readonly=bool(stat_info.st_file_attributes & stat.FILE_ATTRIBUTE_READONLY)
                            if hasattr(stat_info, 'st_file_attributes') else False,
            )
        except:
            return FileInfo(path=entry.path, name=entry.name)

    def _get_dir_info(self, entry) -> DirectoryInfo:
        """Get directory information"""
        try:
            stat_info = entry.stat()
            return DirectoryInfo(
                path=entry.path,
                name=entry.name,
                created=stat_info.st_ctime,
                modified=stat_info.st_mtime,
            )
        except:
            return DirectoryInfo(path=entry.path, name=entry.name)

    def find_empty_directories(self, base_path: str) -> List[str]:
        """Find empty directories"""
        empty_dirs = []

        for root, dirs, files in os.walk(base_path, topdown=False):
            if not files and not dirs:
                empty_dirs.append(root)
            elif not files:
                all_empty = all(os.path.join(root, d) in empty_dirs for d in dirs)
                if all_empty:
                    empty_dirs.append(root)

        return empty_dirs

    def find_large_files(self, base_path: str, min_size: int = 100*1024*1024) -> List[FileInfo]:
        """Find files larger than min_size"""
        large_files = []

        for root, _, files in os.walk(base_path):
            for file in files:
                try:
                    path = os.path.join(root, file)
                    size = os.path.getsize(path)
                    if size >= min_size:
                        large_files.append(FileInfo(path=path, name=file, size=size))
                except:
                    continue

        return sorted(large_files, key=lambda x: x.size, reverse=True)

    def get_found_files(self) -> Dict[str, FileInfo]:
        """Get all found files"""
        return self._found_files

    def get_found_dirs(self) -> Dict[str, DirectoryInfo]:
        """Get all found directories"""
        return self._found_dirs

    def clear_cache(self):
        """Clear scan cache"""
        self._found_files.clear()
        self._found_dirs.clear()

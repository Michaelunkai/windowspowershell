"""
Filesystem analyzer for Ultimate Uninstaller
Analyzes files and directories using patterns and heuristics
"""

import os
import re
import hashlib
from pathlib import Path
from typing import List, Dict, Set, Tuple, Optional, Any
from dataclasses import dataclass, field
from datetime import datetime, timedelta
import sys
import fnmatch

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from core.config import Config, KNOWN_APPS_SIGNATURES
from core.logger import Logger


@dataclass
class FilePattern:
    """Pattern for matching files"""
    name: str
    extensions: List[str] = field(default_factory=list)
    name_patterns: List[str] = field(default_factory=list)
    path_patterns: List[str] = field(default_factory=list)
    exclude_patterns: List[str] = field(default_factory=list)
    min_size: int = 0
    max_size: int = 0
    weight: float = 1.0


@dataclass
class AnalysisResult:
    """Result of filesystem analysis"""
    app_name: str
    confidence: float
    files_found: List[str]
    directories_found: List[str]
    total_size: int
    install_location: str = ""
    related_patterns: List[str] = field(default_factory=list)


class FileAnalyzer:
    """Analyzes filesystem for software traces"""

    COMMON_PATTERNS = [
        FilePattern(
            name="executable",
            extensions=['.exe', '.dll', '.sys'],
            weight=2.0
        ),
        FilePattern(
            name="config",
            extensions=['.ini', '.cfg', '.conf', '.json', '.xml'],
            weight=1.0
        ),
        FilePattern(
            name="data",
            extensions=['.dat', '.db', '.sqlite', '.cache'],
            weight=0.8
        ),
        FilePattern(
            name="log",
            extensions=['.log', '.txt'],
            name_patterns=['*log*', '*debug*', '*error*'],
            weight=0.5
        ),
        FilePattern(
            name="temp",
            extensions=['.tmp', '.temp', '.bak'],
            weight=0.3
        ),
    ]

    def __init__(self, config: Config, logger: Logger = None):
        self.config = config
        self.logger = logger or Logger.get_instance()
        self._patterns: Dict[str, FilePattern] = {}
        self._app_signatures: Dict[str, List[str]] = KNOWN_APPS_SIGNATURES
        self._analysis_cache: Dict[str, AnalysisResult] = {}

        self._load_default_patterns()

    def _load_default_patterns(self):
        """Load default analysis patterns"""
        for pattern in self.COMMON_PATTERNS:
            self._patterns[pattern.name] = pattern

    def add_pattern(self, pattern: FilePattern):
        """Add custom pattern"""
        self._patterns[pattern.name] = pattern

    def analyze_for_app(self, app_name: str, search_paths: List[str] = None) -> AnalysisResult:
        """Analyze filesystem for specific application"""
        if app_name in self._analysis_cache:
            return self._analysis_cache[app_name]

        result = AnalysisResult(
            app_name=app_name,
            confidence=0.0,
            files_found=[],
            directories_found=[],
            total_size=0
        )

        search_patterns = self._get_app_patterns(app_name)
        search_paths = search_paths or self._get_default_search_paths()

        for base_path in search_paths:
            if not os.path.exists(base_path):
                continue

            self._search_directory(base_path, search_patterns, result, 0, 10)

        result.confidence = self._calculate_confidence(result)
        self._analysis_cache[app_name] = result

        return result

    def _get_app_patterns(self, app_name: str) -> List[str]:
        """Get search patterns for application"""
        patterns = [app_name.lower()]

        for key, signatures in self._app_signatures.items():
            if app_name.lower() in [s.lower() for s in signatures]:
                patterns.extend(signatures)
                break
            elif any(s.lower() in app_name.lower() for s in signatures):
                patterns.extend(signatures)

        return list(set(patterns))

    def _get_default_search_paths(self) -> List[str]:
        """Get default search paths"""
        return [
            os.environ.get('PROGRAMFILES', ''),
            os.environ.get('PROGRAMFILES(X86)', ''),
            os.environ.get('PROGRAMDATA', ''),
            os.environ.get('APPDATA', ''),
            os.environ.get('LOCALAPPDATA', ''),
        ]

    def _search_directory(self, base_path: str, patterns: List[str],
                         result: AnalysisResult, depth: int, max_depth: int):
        """Search directory for patterns"""
        if depth > max_depth:
            return

        try:
            entries = list(os.scandir(base_path))
        except (PermissionError, OSError):
            return

        for entry in entries:
            try:
                name_lower = entry.name.lower()

                if entry.is_dir(follow_symlinks=False):
                    if self._matches_patterns(name_lower, patterns):
                        result.directories_found.append(entry.path)

                        if not result.install_location:
                            result.install_location = entry.path

                        try:
                            size = self._get_directory_size(entry.path)
                            result.total_size += size
                        except:
                            pass

                    self._search_directory(entry.path, patterns, result,
                                          depth + 1, max_depth)

                elif entry.is_file(follow_symlinks=False):
                    if self._matches_patterns(name_lower, patterns):
                        result.files_found.append(entry.path)

                        try:
                            result.total_size += entry.stat().st_size
                        except:
                            pass

            except (PermissionError, OSError):
                continue

    def _matches_patterns(self, text: str, patterns: List[str]) -> bool:
        """Check if text matches any pattern"""
        if not text:
            return False

        return any(p.lower() in text for p in patterns)

    def _get_directory_size(self, path: str) -> int:
        """Calculate directory size"""
        total = 0
        try:
            for entry in os.scandir(path):
                if entry.is_file(follow_symlinks=False):
                    total += entry.stat().st_size
                elif entry.is_dir(follow_symlinks=False):
                    total += self._get_directory_size(entry.path)
        except:
            pass
        return total

    def _calculate_confidence(self, result: AnalysisResult) -> float:
        """Calculate confidence score"""
        score = 0.0

        score += len(result.files_found) * 0.05
        score += len(result.directories_found) * 0.1

        if result.install_location:
            score += 0.3

        for file_path in result.files_found:
            ext = Path(file_path).suffix.lower()
            if ext in ['.exe', '.dll']:
                score += 0.2
            elif ext in ['.ini', '.cfg', '.json']:
                score += 0.1

        return min(1.0, score)

    def find_orphaned_files(self, paths: List[str]) -> List[str]:
        """Find orphaned files (no associated program)"""
        orphaned = []

        for path in paths:
            if not os.path.exists(path):
                continue

            try:
                for entry in os.scandir(path):
                    if entry.is_dir():
                        if not self._has_executable(entry.path):
                            orphaned.append(entry.path)
            except:
                continue

        return orphaned

    def _has_executable(self, path: str) -> bool:
        """Check if directory contains executable"""
        try:
            for root, _, files in os.walk(path):
                for f in files:
                    if f.lower().endswith(('.exe', '.msi')):
                        return True
        except:
            pass
        return False

    def find_duplicate_files(self, path: str, min_size: int = 1024) -> Dict[str, List[str]]:
        """Find duplicate files by hash"""
        hashes: Dict[str, List[str]] = {}

        try:
            for root, _, files in os.walk(path):
                for f in files:
                    file_path = os.path.join(root, f)
                    try:
                        size = os.path.getsize(file_path)
                        if size < min_size:
                            continue

                        file_hash = self._hash_file(file_path)
                        if file_hash:
                            if file_hash not in hashes:
                                hashes[file_hash] = []
                            hashes[file_hash].append(file_path)
                    except:
                        continue
        except:
            pass

        return {h: paths for h, paths in hashes.items() if len(paths) > 1}

    def _hash_file(self, path: str, chunk_size: int = 8192) -> Optional[str]:
        """Calculate file hash"""
        try:
            hasher = hashlib.md5()
            with open(path, 'rb') as f:
                chunk = f.read(chunk_size)
                while chunk:
                    hasher.update(chunk)
                    chunk = f.read(chunk_size)
            return hasher.hexdigest()
        except:
            return None

    def find_old_files(self, path: str, days: int = 90) -> List[str]:
        """Find files older than specified days"""
        old_files = []
        cutoff = datetime.now() - timedelta(days=days)
        cutoff_timestamp = cutoff.timestamp()

        try:
            for root, _, files in os.walk(path):
                for f in files:
                    file_path = os.path.join(root, f)
                    try:
                        mtime = os.path.getmtime(file_path)
                        if mtime < cutoff_timestamp:
                            old_files.append(file_path)
                    except:
                        continue
        except:
            pass

        return old_files

    def clear_cache(self):
        """Clear analysis cache"""
        self._analysis_cache.clear()

    def get_app_signatures(self) -> Dict[str, List[str]]:
        """Get known app signatures"""
        return self._app_signatures.copy()

    def add_app_signature(self, app_name: str, signatures: List[str]):
        """Add custom app signature"""
        if app_name in self._app_signatures:
            self._app_signatures[app_name].extend(signatures)
        else:
            self._app_signatures[app_name] = signatures

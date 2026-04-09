"""
Registry analyzer for Ultimate Uninstaller
Analyzes registry for software traces using patterns and heuristics
"""

import re
import winreg
from typing import List, Dict, Set, Tuple, Optional, Any
from dataclasses import dataclass, field
from pathlib import Path
import sys
import os

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from core.config import Config, KNOWN_APPS_SIGNATURES
from core.logger import Logger
from core.cache import cached


@dataclass
class RegistryPattern:
    """Pattern for matching registry entries"""
    name: str
    key_patterns: List[str] = field(default_factory=list)
    value_patterns: List[str] = field(default_factory=list)
    data_patterns: List[str] = field(default_factory=list)
    exclude_patterns: List[str] = field(default_factory=list)
    weight: float = 1.0
    case_sensitive: bool = False


@dataclass
class AnalysisResult:
    """Result of registry analysis"""
    app_name: str
    confidence: float
    keys_found: List[str]
    values_found: List[Tuple[str, str]]
    install_paths: Set[str]
    uninstall_strings: List[str]
    related_files: Set[str]


class RegistryAnalyzer:
    """Analyzes registry for software traces"""

    COMMON_SOFTWARE_PATTERNS = [
        RegistryPattern(
            name="uninstall_entry",
            key_patterns=[
                r".*\\Uninstall\\.*",
                r".*\\WOW6432Node\\.*\\Uninstall\\.*",
            ],
            weight=2.0
        ),
        RegistryPattern(
            name="clsid_entry",
            key_patterns=[r".*\\CLSID\\{[0-9A-Fa-f-]+}"],
            weight=0.5
        ),
        RegistryPattern(
            name="shell_extension",
            key_patterns=[
                r".*\\shellex\\.*",
                r".*\\ContextMenuHandlers\\.*",
            ],
            weight=1.5
        ),
        RegistryPattern(
            name="app_path",
            key_patterns=[r".*\\App Paths\\.*\.exe"],
            weight=1.0
        ),
        RegistryPattern(
            name="service",
            key_patterns=[r"SYSTEM\\.*\\Services\\.*"],
            weight=1.5
        ),
        RegistryPattern(
            name="run_entry",
            key_patterns=[
                r".*\\Run$",
                r".*\\RunOnce$",
            ],
            weight=1.5
        ),
    ]

    def __init__(self, config: Config, logger: Logger = None):
        self.config = config
        self.logger = logger or Logger.get_instance()
        self._patterns: Dict[str, RegistryPattern] = {}
        self._app_signatures: Dict[str, List[str]] = KNOWN_APPS_SIGNATURES
        self._analysis_cache: Dict[str, AnalysisResult] = {}

        self._load_default_patterns()

    def _load_default_patterns(self):
        """Load default analysis patterns"""
        for pattern in self.COMMON_SOFTWARE_PATTERNS:
            self._patterns[pattern.name] = pattern

    def add_pattern(self, pattern: RegistryPattern):
        """Add custom pattern"""
        self._patterns[pattern.name] = pattern

    def analyze_for_app(self, app_name: str) -> AnalysisResult:
        """Analyze registry for specific application"""
        if app_name in self._analysis_cache:
            return self._analysis_cache[app_name]

        result = AnalysisResult(
            app_name=app_name,
            confidence=0.0,
            keys_found=[],
            values_found=[],
            install_paths=set(),
            uninstall_strings=[],
            related_files=set()
        )

        app_patterns = self._get_app_patterns(app_name)

        for hive, hive_name in [
            (winreg.HKEY_LOCAL_MACHINE, "HKLM"),
            (winreg.HKEY_CURRENT_USER, "HKCU"),
        ]:
            self._search_hive(hive, hive_name, app_patterns, result)

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

        patterns = list(set(patterns))
        return patterns

    def _search_hive(self, hive: int, hive_name: str,
                    patterns: List[str], result: AnalysisResult):
        """Search a registry hive for patterns"""
        search_paths = [
            r"SOFTWARE",
            r"SOFTWARE\WOW6432Node",
            r"SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
            r"SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall",
            r"Software",
        ]

        for path in search_paths:
            try:
                self._search_key_recursive(
                    hive, hive_name, path, patterns, result, 0, 10
                )
            except:
                continue

    def _search_key_recursive(self, hive: int, hive_name: str, path: str,
                             patterns: List[str], result: AnalysisResult,
                             depth: int, max_depth: int):
        """Recursively search registry key"""
        if depth > max_depth:
            return

        try:
            key = winreg.OpenKey(hive, path, 0, winreg.KEY_READ)
        except:
            return

        try:
            key_name = path.split('\\')[-1] if path else ""
            full_path = f"{hive_name}\\{path}"

            if self._matches_patterns(key_name, patterns):
                result.keys_found.append(full_path)
                self._extract_key_info(key, full_path, result)

            _, value_count, _ = winreg.QueryInfoKey(key)

            for i in range(value_count):
                try:
                    name, data, _ = winreg.EnumValue(key, i)

                    if self._matches_patterns(name, patterns):
                        result.values_found.append((full_path, name))

                    if isinstance(data, str):
                        if self._matches_patterns(data, patterns):
                            result.values_found.append((full_path, name))
                            self._extract_path_info(data, result)
                except:
                    continue

            subkey_count, _, _ = winreg.QueryInfoKey(key)

            for i in range(subkey_count):
                try:
                    subkey_name = winreg.EnumKey(key, i)

                    if self._matches_patterns(subkey_name, patterns):
                        subkey_path = f"{path}\\{subkey_name}"
                        result.keys_found.append(f"{hive_name}\\{subkey_path}")
                        self._search_key_recursive(
                            hive, hive_name, subkey_path, patterns,
                            result, depth + 1, max_depth
                        )
                    elif depth < max_depth // 2:
                        subkey_path = f"{path}\\{subkey_name}"
                        self._search_key_recursive(
                            hive, hive_name, subkey_path, patterns,
                            result, depth + 1, max_depth
                        )
                except:
                    continue

        finally:
            winreg.CloseKey(key)

    def _matches_patterns(self, text: str, patterns: List[str]) -> bool:
        """Check if text matches any pattern"""
        if not text:
            return False

        text_lower = text.lower()
        return any(p.lower() in text_lower for p in patterns)

    def _extract_key_info(self, key, full_path: str, result: AnalysisResult):
        """Extract relevant info from registry key"""
        info_values = [
            ('InstallLocation', 'install_paths'),
            ('InstallDir', 'install_paths'),
            ('Path', 'install_paths'),
            ('UninstallString', 'uninstall_strings'),
            ('QuietUninstallString', 'uninstall_strings'),
        ]

        for value_name, target in info_values:
            try:
                data, _ = winreg.QueryValueEx(key, value_name)
                if isinstance(data, str) and data:
                    if target == 'install_paths':
                        result.install_paths.add(data)
                    elif target == 'uninstall_strings':
                        result.uninstall_strings.append(data)
            except:
                continue

    def _extract_path_info(self, data: str, result: AnalysisResult):
        """Extract file paths from registry data"""
        path_pattern = r'[A-Za-z]:\\[^"<>|*?\n\r]+'

        matches = re.findall(path_pattern, data)

        for match in matches:
            clean_path = match.strip().rstrip('\\')
            if len(clean_path) > 3:
                result.related_files.add(clean_path)

                if '\\' in clean_path:
                    dir_path = '\\'.join(clean_path.split('\\')[:-1])
                    if len(dir_path) > 3:
                        result.install_paths.add(dir_path)

    def _calculate_confidence(self, result: AnalysisResult) -> float:
        """Calculate confidence score for analysis result"""
        score = 0.0

        score += len(result.keys_found) * 0.1
        score += len(result.values_found) * 0.05
        score += len(result.install_paths) * 0.2
        score += len(result.uninstall_strings) * 0.3
        score += len(result.related_files) * 0.02

        for key in result.keys_found:
            if 'Uninstall' in key:
                score += 0.5
            if 'Services' in key:
                score += 0.3

        return min(1.0, score)

    def find_related_entries(self, paths: Set[str]) -> Dict[str, List[str]]:
        """Find registry entries related to file paths"""
        related = {}

        for path in paths:
            related[path] = []

            search_term = Path(path).name.lower()

            for hive, hive_name in [
                (winreg.HKEY_LOCAL_MACHINE, "HKLM"),
                (winreg.HKEY_CURRENT_USER, "HKCU"),
                (winreg.HKEY_CLASSES_ROOT, "HKCR"),
            ]:
                found = self._find_path_references(hive, hive_name, path, search_term)
                related[path].extend(found)

        return related

    def _find_path_references(self, hive: int, hive_name: str,
                             path: str, search_term: str) -> List[str]:
        """Find registry references to a path"""
        found = []

        search_locations = [
            r"SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths",
            r"SOFTWARE\Classes\Applications",
        ]

        for location in search_locations:
            try:
                key = winreg.OpenKey(hive, location, 0, winreg.KEY_READ)
                subkey_count, _, _ = winreg.QueryInfoKey(key)

                for i in range(subkey_count):
                    try:
                        subkey_name = winreg.EnumKey(key, i)
                        if search_term in subkey_name.lower():
                            found.append(f"{hive_name}\\{location}\\{subkey_name}")
                    except:
                        continue

                winreg.CloseKey(key)
            except:
                continue

        return found

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

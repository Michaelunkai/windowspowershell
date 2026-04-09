"""
Registry scanner for Ultimate Uninstaller
Deep scanning of Windows registry for software traces
"""

import winreg
import time
import threading
from typing import List, Dict, Generator, Optional, Tuple, Any
from dataclasses import dataclass, field
from enum import Enum, auto
from concurrent.futures import ThreadPoolExecutor, as_completed
import sys
import os

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from core.base import BaseScanner, ScanResult
from core.config import Config, ScanDepth, RegistryConfig
from core.logger import Logger
from core.cache import cached


class RegistryHive(Enum):
    """Windows registry hives"""
    HKLM = winreg.HKEY_LOCAL_MACHINE
    HKCU = winreg.HKEY_CURRENT_USER
    HKCR = winreg.HKEY_CLASSES_ROOT
    HKU = winreg.HKEY_USERS
    HKCC = winreg.HKEY_CURRENT_CONFIG


@dataclass
class RegistryValue:
    """Represents a registry value"""
    name: str
    data: Any
    value_type: int
    type_name: str = ""

    def __post_init__(self):
        type_names = {
            winreg.REG_SZ: "REG_SZ",
            winreg.REG_EXPAND_SZ: "REG_EXPAND_SZ",
            winreg.REG_BINARY: "REG_BINARY",
            winreg.REG_DWORD: "REG_DWORD",
            winreg.REG_DWORD_BIG_ENDIAN: "REG_DWORD_BE",
            winreg.REG_LINK: "REG_LINK",
            winreg.REG_MULTI_SZ: "REG_MULTI_SZ",
            winreg.REG_QWORD: "REG_QWORD",
            winreg.REG_NONE: "REG_NONE",
        }
        self.type_name = type_names.get(self.value_type, "UNKNOWN")


@dataclass
class RegistryKey:
    """Represents a registry key"""
    hive: RegistryHive
    path: str
    name: str
    full_path: str = ""
    subkeys: List[str] = field(default_factory=list)
    values: List[RegistryValue] = field(default_factory=list)
    last_modified: float = 0.0

    def __post_init__(self):
        self.full_path = f"{self.hive.name}\\{self.path}"


class RegistryScanner(BaseScanner):
    """Deep registry scanner for finding software traces"""

    def __init__(self, config: Config, logger: Logger = None):
        super().__init__(config, logger)
        self.reg_config = config.registry
        self._found_keys: Dict[str, RegistryKey] = {}
        self._scan_cache: Dict[str, List[RegistryKey]] = {}

    def scan(self, target: str = None, patterns: List[str] = None,
             depth: ScanDepth = None) -> Generator[ScanResult, None, None]:
        """Scan registry for matching entries"""
        depth = depth or self.config.depth
        patterns = patterns or []

        if target:
            patterns.append(target.lower())

        self.log_info(f"Starting registry scan for: {patterns}")
        self._stats.items_scanned = 0

        hives_to_scan = self._get_hives_to_scan()

        with ThreadPoolExecutor(max_workers=4) as executor:
            futures = {}

            for hive in hives_to_scan:
                for base_path in self._get_scan_paths(hive):
                    future = executor.submit(
                        self._scan_path, hive, base_path, patterns, depth
                    )
                    futures[future] = (hive, base_path)

            for future in as_completed(futures):
                if self.is_cancelled():
                    break

                hive, path = futures[future]
                try:
                    for result in future.result():
                        yield result
                except Exception as e:
                    self.log_error(f"Error scanning {hive.name}\\{path}: {e}")

        self.log_info(f"Registry scan complete. Found {self._stats.items_found} items")

    def _get_hives_to_scan(self) -> List[RegistryHive]:
        """Get list of registry hives to scan"""
        hives = []

        if self.reg_config.scan_hklm:
            hives.append(RegistryHive.HKLM)
        if self.reg_config.scan_hkcu:
            hives.append(RegistryHive.HKCU)
        if self.reg_config.scan_hkcr:
            hives.append(RegistryHive.HKCR)
        if self.reg_config.scan_users:
            hives.append(RegistryHive.HKU)

        return hives

    def _get_scan_paths(self, hive: RegistryHive) -> List[str]:
        """Get registry paths to scan for a hive"""
        paths = []

        if hive == RegistryHive.HKLM:
            paths.extend(self.reg_config.uninstall_paths)
            paths.extend(self.reg_config.software_paths)
            paths.extend(self.reg_config.run_paths)
            paths.append(r"SYSTEM\CurrentControlSet\Services")

        elif hive == RegistryHive.HKCU:
            paths.extend([
                p.replace(r"SOFTWARE\Microsoft", r"Software\Microsoft")
                for p in self.reg_config.run_paths
            ])
            paths.append(r"Software")
            paths.append(r"Software\Microsoft\Windows\CurrentVersion\Uninstall")

        elif hive == RegistryHive.HKCR:
            paths.append(r"CLSID")
            paths.append(r"TypeLib")
            paths.append(r"Interface")

        elif hive == RegistryHive.HKU:
            paths.append(r".DEFAULT\Software")

        return paths

    def _scan_path(self, hive: RegistryHive, path: str, patterns: List[str],
                   depth: ScanDepth) -> Generator[ScanResult, None, None]:
        """Scan a specific registry path"""
        max_depth = {
            ScanDepth.QUICK: 2,
            ScanDepth.STANDARD: 5,
            ScanDepth.DEEP: 15,
            ScanDepth.FORENSIC: 50,
        }.get(depth, 5)

        try:
            yield from self._scan_key_recursive(
                hive, path, patterns, 0, max_depth
            )
        except Exception as e:
            self.log_trace(f"Cannot access {hive.name}\\{path}: {e}")

    def _scan_key_recursive(self, hive: RegistryHive, path: str,
                            patterns: List[str], current_depth: int,
                            max_depth: int) -> Generator[ScanResult, None, None]:
        """Recursively scan registry keys"""
        if current_depth > max_depth or self.is_cancelled():
            return

        self._stats.items_scanned += 1

        try:
            key = winreg.OpenKey(hive.value, path, 0, winreg.KEY_READ)
        except (PermissionError, FileNotFoundError, OSError):
            return

        try:
            key_name = path.split('\\')[-1] if path else ""

            values = self._get_key_values(key)

            if self._matches_patterns(key_name, path, values, patterns):
                reg_key = RegistryKey(
                    hive=hive,
                    path=path,
                    name=key_name,
                    values=values,
                )

                self._found_keys[reg_key.full_path] = reg_key
                self._stats.items_found += 1

                yield ScanResult(
                    module=self.name,
                    item_type="registry_key",
                    path=reg_key.full_path,
                    name=key_name,
                    details={
                        'hive': hive.name,
                        'path': path,
                        'values': len(values),
                        'value_names': [v.name for v in values[:10]],
                    }
                )

            subkey_count, _, _ = winreg.QueryInfoKey(key)

            for i in range(subkey_count):
                if self.is_cancelled():
                    break
                try:
                    subkey_name = winreg.EnumKey(key, i)
                    subkey_path = f"{path}\\{subkey_name}" if path else subkey_name

                    yield from self._scan_key_recursive(
                        hive, subkey_path, patterns,
                        current_depth + 1, max_depth
                    )
                except OSError:
                    continue

        finally:
            winreg.CloseKey(key)

    def _get_key_values(self, key) -> List[RegistryValue]:
        """Get all values from a registry key"""
        values = []

        try:
            _, value_count, _ = winreg.QueryInfoKey(key)

            for i in range(value_count):
                try:
                    name, data, value_type = winreg.EnumValue(key, i)
                    values.append(RegistryValue(
                        name=name or "(Default)",
                        data=data,
                        value_type=value_type
                    ))
                except OSError:
                    continue
        except OSError:
            pass

        return values

    def _matches_patterns(self, key_name: str, path: str,
                         values: List[RegistryValue], patterns: List[str]) -> bool:
        """Check if key matches any search pattern"""
        if not patterns:
            return False

        search_text = f"{key_name} {path}".lower()

        for value in values:
            if isinstance(value.data, str):
                search_text += f" {value.data.lower()}"
            if value.name:
                search_text += f" {value.name.lower()}"

        for pattern in patterns:
            if pattern.lower() in search_text:
                return True

        return False

    def scan_uninstall_keys(self) -> List[Dict[str, Any]]:
        """Scan uninstall registry keys for installed programs"""
        programs = []

        uninstall_paths = [
            (RegistryHive.HKLM, r"SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"),
            (RegistryHive.HKLM, r"SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"),
            (RegistryHive.HKCU, r"Software\Microsoft\Windows\CurrentVersion\Uninstall"),
        ]

        for hive, path in uninstall_paths:
            try:
                key = winreg.OpenKey(hive.value, path, 0, winreg.KEY_READ)
                subkey_count, _, _ = winreg.QueryInfoKey(key)

                for i in range(subkey_count):
                    try:
                        subkey_name = winreg.EnumKey(key, i)
                        subkey_path = f"{path}\\{subkey_name}"
                        subkey = winreg.OpenKey(hive.value, subkey_path, 0, winreg.KEY_READ)

                        program = self._read_uninstall_info(subkey, subkey_name)
                        if program.get('DisplayName'):
                            program['registry_key'] = f"{hive.name}\\{subkey_path}"
                            programs.append(program)

                        winreg.CloseKey(subkey)
                    except OSError:
                        continue

                winreg.CloseKey(key)
            except OSError:
                continue

        return programs

    def _read_uninstall_info(self, key, key_name: str) -> Dict[str, Any]:
        """Read uninstall information from registry key"""
        info = {'KeyName': key_name}

        fields = [
            'DisplayName', 'DisplayVersion', 'Publisher', 'InstallDate',
            'InstallLocation', 'UninstallString', 'QuietUninstallString',
            'DisplayIcon', 'EstimatedSize', 'Comments', 'URLInfoAbout',
            'SystemComponent', 'NoRemove', 'NoModify',
        ]

        for field_name in fields:
            try:
                value, _ = winreg.QueryValueEx(key, field_name)
                info[field_name] = value
            except OSError:
                pass

        return info

    def get_found_keys(self) -> Dict[str, RegistryKey]:
        """Get all found registry keys"""
        return self._found_keys

    def clear_cache(self):
        """Clear scan cache"""
        self._scan_cache.clear()
        self._found_keys.clear()

"""
Driver scanner for Ultimate Uninstaller
Scans Windows drivers for software traces
"""

import winreg
import subprocess
import os
from typing import List, Dict, Generator, Optional, Any
from dataclasses import dataclass, field
from enum import Enum
from pathlib import Path
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from core.base import BaseScanner, ScanResult
from core.config import Config, ScanDepth
from core.logger import Logger


class DriverType(Enum):
    """Driver type"""
    KERNEL = 1
    FILE_SYSTEM = 2
    ADAPTER = 3
    RECOGNIZER = 8
    UNKNOWN = 0


class DriverState(Enum):
    """Driver state"""
    RUNNING = 4
    STOPPED = 1
    START_PENDING = 2
    STOP_PENDING = 3
    UNKNOWN = 0


@dataclass
class DriverInfo:
    """Windows driver information"""
    name: str
    display_name: str
    description: str = ""
    driver_type: DriverType = DriverType.UNKNOWN
    state: DriverState = DriverState.UNKNOWN
    image_path: str = ""
    start_type: int = 0
    provider: str = ""
    version: str = ""
    inf_file: str = ""
    signed: bool = False
    registry_path: str = ""


class DriverScanner(BaseScanner):
    """Scans Windows drivers for software traces"""

    DRIVERS_KEY = r"SYSTEM\CurrentControlSet\Services"
    DRIVER_STORE = os.path.join(os.environ.get('SYSTEMROOT', r'C:\Windows'),
                                 'System32', 'DriverStore', 'FileRepository')

    PROTECTED_DRIVERS = {
        'disk', 'ntfs', 'volmgr', 'partmgr', 'volume', 'mountmgr',
        'fltmgr', 'ksecdd', 'tcpip', 'afd', 'netbt', 'mrxsmb', 'rdbss',
        'ndis', 'http', 'dfsc', 'classpnp', 'storport', 'acpi', 'pci',
        'wdf01000', 'wudfpf', 'wudfrd', 'usbhub', 'usbehci', 'usbxhci',
    }

    def __init__(self, config: Config, logger: Logger = None):
        super().__init__(config, logger)
        self._found_drivers: Dict[str, DriverInfo] = {}
        self._all_drivers: Dict[str, DriverInfo] = {}

    def scan(self, target: str = None, patterns: List[str] = None,
             depth: ScanDepth = None) -> Generator[ScanResult, None, None]:
        """Scan drivers for matching entries"""
        patterns = patterns or []

        if target:
            patterns.append(target.lower())

        self.log_info(f"Starting driver scan for: {patterns}")
        self._stats.items_scanned = 0

        drivers = self._enumerate_drivers()

        for driver in drivers:
            if self.is_cancelled():
                break

            self._stats.items_scanned += 1

            if self._matches_patterns(driver, patterns):
                self._found_drivers[driver.name] = driver
                self._stats.items_found += 1

                yield ScanResult(
                    module=self.name,
                    item_type="driver",
                    path=driver.registry_path,
                    name=driver.name,
                    details={
                        'display_name': driver.display_name,
                        'description': driver.description,
                        'state': driver.state.name,
                        'type': driver.driver_type.name,
                        'image_path': driver.image_path,
                        'provider': driver.provider,
                        'signed': driver.signed,
                        'is_protected': driver.name.lower() in self.PROTECTED_DRIVERS,
                    }
                )

        self.log_info(f"Driver scan complete. Found {self._stats.items_found} drivers")

    def _enumerate_drivers(self) -> List[DriverInfo]:
        """Enumerate all Windows drivers"""
        drivers = []

        try:
            key = winreg.OpenKey(
                winreg.HKEY_LOCAL_MACHINE,
                self.DRIVERS_KEY,
                0, winreg.KEY_READ
            )

            subkey_count, _, _ = winreg.QueryInfoKey(key)

            for i in range(subkey_count):
                try:
                    service_name = winreg.EnumKey(key, i)
                    driver_info = self._get_driver_info(service_name)
                    if driver_info and driver_info.driver_type != DriverType.UNKNOWN:
                        drivers.append(driver_info)
                        self._all_drivers[service_name] = driver_info
                except:
                    continue

            winreg.CloseKey(key)

        except Exception as e:
            self.log_error(f"Failed to enumerate drivers: {e}")

        return drivers

    def _get_driver_info(self, name: str) -> Optional[DriverInfo]:
        """Get detailed driver information"""
        try:
            key_path = f"{self.DRIVERS_KEY}\\{name}"
            key = winreg.OpenKey(
                winreg.HKEY_LOCAL_MACHINE,
                key_path, 0, winreg.KEY_READ
            )

            service_type = self._get_reg_value(key, "Type", 0)

            if service_type not in [1, 2, 8]:
                winreg.CloseKey(key)
                return None

            info = DriverInfo(
                name=name,
                display_name=self._get_reg_value(key, "DisplayName", name),
                description=self._get_reg_value(key, "Description", ""),
                image_path=self._get_reg_value(key, "ImagePath", ""),
                start_type=self._get_reg_value(key, "Start", 3),
                registry_path=f"HKLM\\{key_path}"
            )

            try:
                info.driver_type = DriverType(service_type)
            except:
                info.driver_type = DriverType.UNKNOWN

            winreg.CloseKey(key)

            self._get_driver_state(info)
            self._get_driver_signature(info)

            return info

        except Exception:
            return None

    def _get_reg_value(self, key, name: str, default: Any = None) -> Any:
        """Get registry value safely"""
        try:
            value, _ = winreg.QueryValueEx(key, name)
            return value
        except:
            return default

    def _get_driver_state(self, driver: DriverInfo):
        """Get current driver state"""
        try:
            result = subprocess.run(
                ['sc', 'query', driver.name],
                capture_output=True, text=True, timeout=5
            )

            if result.returncode == 0:
                output = result.stdout.lower()
                if 'running' in output:
                    driver.state = DriverState.RUNNING
                elif 'stopped' in output:
                    driver.state = DriverState.STOPPED
                else:
                    driver.state = DriverState.UNKNOWN
            else:
                driver.state = DriverState.UNKNOWN

        except:
            driver.state = DriverState.UNKNOWN

    def _get_driver_signature(self, driver: DriverInfo):
        """Check if driver is signed"""
        try:
            image_path = driver.image_path
            if image_path.startswith('\\SystemRoot'):
                system_root = os.environ.get('SYSTEMROOT', r'C:\Windows')
                image_path = image_path.replace('\\SystemRoot', system_root)
            elif image_path.startswith('System32'):
                system_root = os.environ.get('SYSTEMROOT', r'C:\Windows')
                image_path = os.path.join(system_root, image_path)

            if os.path.exists(image_path):
                result = subprocess.run(
                    ['signtool', 'verify', '/v', image_path],
                    capture_output=True, timeout=10
                )
                driver.signed = result.returncode == 0
            else:
                driver.signed = False

        except:
            driver.signed = False

    def _matches_patterns(self, driver: DriverInfo, patterns: List[str]) -> bool:
        """Check if driver matches patterns"""
        if not patterns:
            return False

        search_text = f"{driver.name} {driver.display_name} {driver.description} {driver.image_path} {driver.provider}".lower()
        return any(p.lower() in search_text for p in patterns)

    def get_third_party_drivers(self) -> List[DriverInfo]:
        """Get non-Microsoft drivers"""
        result = []

        for driver in self._all_drivers.values():
            path = driver.image_path.lower()
            if not any(x in path for x in ['windows', 'system32', 'microsoft']):
                result.append(driver)

        return result

    def scan_driver_store(self, patterns: List[str]) -> List[str]:
        """Scan driver store for matching packages"""
        matches = []

        if not os.path.exists(self.DRIVER_STORE):
            return matches

        try:
            for entry in os.scandir(self.DRIVER_STORE):
                if entry.is_dir():
                    name_lower = entry.name.lower()
                    if any(p.lower() in name_lower for p in patterns):
                        matches.append(entry.path)
        except:
            pass

        return matches

    def get_found_drivers(self) -> Dict[str, DriverInfo]:
        """Get found drivers"""
        return self._found_drivers

    def get_all_drivers(self) -> Dict[str, DriverInfo]:
        """Get all drivers"""
        if not self._all_drivers:
            self._enumerate_drivers()
        return self._all_drivers

    def is_protected(self, name: str) -> bool:
        """Check if driver is protected"""
        return name.lower() in self.PROTECTED_DRIVERS

    def clear_cache(self):
        """Clear scan cache"""
        self._found_drivers.clear()
        self._all_drivers.clear()

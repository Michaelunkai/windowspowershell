"""
Service scanner for Ultimate Uninstaller
Scans Windows services for software traces
"""

import winreg
import subprocess
from typing import List, Dict, Generator, Optional, Any
from dataclasses import dataclass, field
from enum import Enum
from concurrent.futures import ThreadPoolExecutor
import sys
import os

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from core.base import BaseScanner, ScanResult
from core.config import Config, ScanDepth
from core.logger import Logger


class ServiceState(Enum):
    """Service state"""
    STOPPED = 1
    START_PENDING = 2
    STOP_PENDING = 3
    RUNNING = 4
    CONTINUE_PENDING = 5
    PAUSE_PENDING = 6
    PAUSED = 7
    UNKNOWN = 0


class ServiceStartType(Enum):
    """Service start type"""
    BOOT = 0
    SYSTEM = 1
    AUTO = 2
    MANUAL = 3
    DISABLED = 4
    UNKNOWN = 255


@dataclass
class ServiceInfo:
    """Windows service information"""
    name: str
    display_name: str
    description: str = ""
    state: ServiceState = ServiceState.UNKNOWN
    start_type: ServiceStartType = ServiceStartType.UNKNOWN
    binary_path: str = ""
    dependencies: List[str] = field(default_factory=list)
    dependent_services: List[str] = field(default_factory=list)
    account: str = ""
    registry_path: str = ""

    @property
    def is_running(self) -> bool:
        return self.state == ServiceState.RUNNING

    @property
    def is_disabled(self) -> bool:
        return self.start_type == ServiceStartType.DISABLED


class ServiceScanner(BaseScanner):
    """Scans Windows services for software traces"""

    SERVICES_KEY = r"SYSTEM\CurrentControlSet\Services"

    PROTECTED_SERVICES = {
        'wuauserv', 'bits', 'cryptsvc', 'msiserver', 'trustedinstaller',
        'windefend', 'mpssvc', 'eventlog', 'lanmanserver', 'lanmanworkstation',
        'rpcss', 'plugplay', 'dhcp', 'dnscache', 'netlogon', 'w32time',
        'schedule', 'spooler', 'themes', 'audiosrv', 'wmi', 'winmgmt',
    }

    def __init__(self, config: Config, logger: Logger = None):
        super().__init__(config, logger)
        self._found_services: Dict[str, ServiceInfo] = {}
        self._all_services: Dict[str, ServiceInfo] = {}

    def scan(self, target: str = None, patterns: List[str] = None,
             depth: ScanDepth = None) -> Generator[ScanResult, None, None]:
        """Scan services for matching entries"""
        patterns = patterns or []

        if target:
            patterns.append(target.lower())

        self.log_info(f"Starting service scan for: {patterns}")
        self._stats.items_scanned = 0

        services = self._enumerate_services()

        for service in services:
            if self.is_cancelled():
                break

            self._stats.items_scanned += 1

            if self._matches_patterns(service, patterns):
                self._found_services[service.name] = service
                self._stats.items_found += 1

                yield ScanResult(
                    module=self.name,
                    item_type="service",
                    path=service.registry_path,
                    name=service.name,
                    details={
                        'display_name': service.display_name,
                        'description': service.description,
                        'state': service.state.name,
                        'start_type': service.start_type.name,
                        'binary_path': service.binary_path,
                        'account': service.account,
                        'is_protected': service.name.lower() in self.PROTECTED_SERVICES,
                    }
                )

        self.log_info(f"Service scan complete. Found {self._stats.items_found} services")

    def _enumerate_services(self) -> List[ServiceInfo]:
        """Enumerate all Windows services"""
        services = []

        try:
            key = winreg.OpenKey(
                winreg.HKEY_LOCAL_MACHINE,
                self.SERVICES_KEY,
                0, winreg.KEY_READ
            )

            subkey_count, _, _ = winreg.QueryInfoKey(key)

            for i in range(subkey_count):
                try:
                    service_name = winreg.EnumKey(key, i)
                    service_info = self._get_service_info(service_name)
                    if service_info:
                        services.append(service_info)
                        self._all_services[service_name] = service_info
                except:
                    continue

            winreg.CloseKey(key)

        except Exception as e:
            self.log_error(f"Failed to enumerate services: {e}")

        return services

    def _get_service_info(self, name: str) -> Optional[ServiceInfo]:
        """Get detailed service information"""
        try:
            key_path = f"{self.SERVICES_KEY}\\{name}"
            key = winreg.OpenKey(
                winreg.HKEY_LOCAL_MACHINE,
                key_path, 0, winreg.KEY_READ
            )

            info = ServiceInfo(
                name=name,
                display_name=self._get_reg_value(key, "DisplayName", name),
                description=self._get_reg_value(key, "Description", ""),
                binary_path=self._get_reg_value(key, "ImagePath", ""),
                account=self._get_reg_value(key, "ObjectName", ""),
                registry_path=f"HKLM\\{key_path}"
            )

            start_type = self._get_reg_value(key, "Start", 255)
            try:
                info.start_type = ServiceStartType(start_type)
            except:
                info.start_type = ServiceStartType.UNKNOWN

            deps = self._get_reg_value(key, "DependOnService", [])
            if isinstance(deps, list):
                info.dependencies = deps
            elif isinstance(deps, str):
                info.dependencies = [deps]

            winreg.CloseKey(key)

            self._get_service_state(info)

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

    def _get_service_state(self, service: ServiceInfo):
        """Get current service state using sc command"""
        try:
            result = subprocess.run(
                ['sc', 'query', service.name],
                capture_output=True, text=True, timeout=5
            )

            if result.returncode == 0:
                output = result.stdout.lower()
                if 'running' in output:
                    service.state = ServiceState.RUNNING
                elif 'stopped' in output:
                    service.state = ServiceState.STOPPED
                elif 'paused' in output:
                    service.state = ServiceState.PAUSED
                else:
                    service.state = ServiceState.UNKNOWN
            else:
                service.state = ServiceState.UNKNOWN

        except:
            service.state = ServiceState.UNKNOWN

    def _matches_patterns(self, service: ServiceInfo, patterns: List[str]) -> bool:
        """Check if service matches patterns"""
        if not patterns:
            return False

        search_text = f"{service.name} {service.display_name} {service.description} {service.binary_path}".lower()
        return any(p.lower() in search_text for p in patterns)

    def get_service_by_name(self, name: str) -> Optional[ServiceInfo]:
        """Get service by name"""
        if name in self._all_services:
            return self._all_services[name]

        return self._get_service_info(name)

    def get_services_by_binary(self, binary_path: str) -> List[ServiceInfo]:
        """Get services by binary path"""
        result = []
        binary_lower = binary_path.lower()

        for service in self._all_services.values():
            if binary_lower in service.binary_path.lower():
                result.append(service)

        return result

    def get_third_party_services(self) -> List[ServiceInfo]:
        """Get non-Microsoft services"""
        result = []

        for service in self._all_services.values():
            binary = service.binary_path.lower()
            if not any(x in binary for x in ['windows', 'system32', 'microsoft']):
                result.append(service)

        return result

    def get_found_services(self) -> Dict[str, ServiceInfo]:
        """Get found services"""
        return self._found_services

    def get_all_services(self) -> Dict[str, ServiceInfo]:
        """Get all services"""
        if not self._all_services:
            self._enumerate_services()
        return self._all_services

    def is_protected(self, name: str) -> bool:
        """Check if service is protected"""
        return name.lower() in self.PROTECTED_SERVICES

    def clear_cache(self):
        """Clear scan cache"""
        self._found_services.clear()
        self._all_services.clear()

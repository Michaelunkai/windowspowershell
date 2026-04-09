"""
Service cleaner for Ultimate Uninstaller
Safe service removal and cleanup
"""

import winreg
import subprocess
import json
import time
from typing import List, Dict, Generator, Tuple, Optional
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
import sys
import os

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from core.base import BaseCleaner, CleanResult, ScanResult
from core.config import Config
from core.logger import Logger
from core.exceptions import ServiceError
from .scanner import ServiceInfo, ServiceState, ServiceStartType


@dataclass
class ServiceBackupEntry:
    """Service backup entry"""
    name: str
    display_name: str
    description: str
    binary_path: str
    start_type: int
    account: str
    dependencies: List[str]
    timestamp: float


class ServiceBackup:
    """Service backup manager"""

    def __init__(self, backup_dir: str):
        self.backup_dir = Path(backup_dir)
        self.backup_dir.mkdir(parents=True, exist_ok=True)
        self._entries: List[ServiceBackupEntry] = []
        self._backup_file: Optional[Path] = None

    def start_backup(self, name: str = None) -> str:
        """Start new backup session"""
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        name = name or f"service_backup_{timestamp}"
        self._backup_file = self.backup_dir / f"{name}.json"
        self._entries = []
        return str(self._backup_file)

    def backup_service(self, service: ServiceInfo) -> bool:
        """Backup service configuration"""
        try:
            entry = ServiceBackupEntry(
                name=service.name,
                display_name=service.display_name,
                description=service.description,
                binary_path=service.binary_path,
                start_type=service.start_type.value,
                account=service.account,
                dependencies=service.dependencies,
                timestamp=time.time()
            )
            self._entries.append(entry)
            return True
        except:
            return False

    def save_backup(self) -> bool:
        """Save backup to file"""
        if not self._backup_file:
            return False

        try:
            data = {
                'version': '1.0',
                'created': datetime.now().isoformat(),
                'entries': [
                    {
                        'name': e.name,
                        'display_name': e.display_name,
                        'description': e.description,
                        'binary_path': e.binary_path,
                        'start_type': e.start_type,
                        'account': e.account,
                        'dependencies': e.dependencies,
                        'timestamp': e.timestamp,
                    }
                    for e in self._entries
                ]
            }

            with open(self._backup_file, 'w') as f:
                json.dump(data, f, indent=2)

            return True
        except:
            return False

    def load_backup(self, path: str) -> bool:
        """Load backup from file"""
        try:
            with open(path, 'r') as f:
                data = json.load(f)

            self._entries = [
                ServiceBackupEntry(
                    name=e['name'],
                    display_name=e['display_name'],
                    description=e['description'],
                    binary_path=e['binary_path'],
                    start_type=e['start_type'],
                    account=e['account'],
                    dependencies=e['dependencies'],
                    timestamp=e['timestamp']
                )
                for e in data.get('entries', [])
            ]
            return True
        except:
            return False

    def restore_services(self) -> Tuple[int, int]:
        """Restore backed up services"""
        restored = 0
        failed = 0

        for entry in self._entries:
            try:
                deps = ' '.join(entry.dependencies) if entry.dependencies else ''

                cmd = [
                    'sc', 'create', entry.name,
                    'binPath=', entry.binary_path,
                    'DisplayName=', entry.display_name,
                    'start=', self._start_type_name(entry.start_type),
                ]

                if deps:
                    cmd.extend(['depend=', deps])

                result = subprocess.run(cmd, capture_output=True, timeout=30)

                if result.returncode == 0:
                    restored += 1

                    if entry.description:
                        subprocess.run([
                            'sc', 'description', entry.name, entry.description
                        ], capture_output=True, timeout=10)
                else:
                    failed += 1

            except:
                failed += 1

        return restored, failed

    def _start_type_name(self, value: int) -> str:
        """Convert start type value to name"""
        return {
            0: 'boot',
            1: 'system',
            2: 'auto',
            3: 'demand',
            4: 'disabled',
        }.get(value, 'demand')

    def get_entries(self) -> List[ServiceBackupEntry]:
        """Get backup entries"""
        return self._entries


class ServiceCleaner(BaseCleaner):
    """Service cleaner for removing software services"""

    PROTECTED_SERVICES = {
        'wuauserv', 'bits', 'cryptsvc', 'msiserver', 'trustedinstaller',
        'windefend', 'mpssvc', 'eventlog', 'lanmanserver', 'lanmanworkstation',
        'rpcss', 'plugplay', 'dhcp', 'dnscache', 'netlogon', 'w32time',
        'schedule', 'spooler', 'themes', 'audiosrv', 'winmgmt',
    }

    def __init__(self, config: Config, logger: Logger = None):
        super().__init__(config, logger)
        self.backup = ServiceBackup(config.backup_dir)
        self._deleted_services: List[str] = []

    def clean(self, items: List[ScanResult]) -> Generator[CleanResult, None, None]:
        """Remove services from scan results"""
        if self.config.create_backup:
            self.backup.start_backup()

        for item in items:
            if self.is_cancelled():
                break
            self.wait_if_paused()

            if item.item_type != "service":
                continue

            yield self._clean_service(item)

        if self.config.create_backup:
            self.backup.save_backup()

    def _clean_service(self, item: ScanResult) -> CleanResult:
        """Remove a single service"""
        service_name = item.name

        if self._is_protected(service_name):
            return CleanResult(
                module=self.name,
                action="skip",
                target=service_name,
                success=False,
                message="Protected system service"
            )

        service_info = self._get_service_info(item)

        if service_info and self.config.create_backup:
            self.backup.backup_service(service_info)

        if self.config.dry_run:
            return CleanResult(
                module=self.name,
                action="delete (dry run)",
                target=service_name,
                success=True,
                message="Would remove service"
            )

        success, message = self._remove_service(service_name)

        if success:
            self._deleted_services.append(service_name)

        return CleanResult(
            module=self.name,
            action="delete",
            target=service_name,
            success=success,
            message=message
        )

    def _is_protected(self, name: str) -> bool:
        """Check if service is protected"""
        return name.lower() in self.PROTECTED_SERVICES

    def _get_service_info(self, item: ScanResult) -> Optional[ServiceInfo]:
        """Get service info from scan result"""
        details = item.details or {}

        return ServiceInfo(
            name=item.name,
            display_name=details.get('display_name', item.name),
            description=details.get('description', ''),
            binary_path=details.get('binary_path', ''),
            account=details.get('account', ''),
            dependencies=details.get('dependencies', [])
        )

    def _remove_service(self, name: str) -> Tuple[bool, str]:
        """Remove a Windows service"""
        try:
            stop_result = subprocess.run(
                ['sc', 'stop', name],
                capture_output=True, timeout=30
            )

            time.sleep(1)

            delete_result = subprocess.run(
                ['sc', 'delete', name],
                capture_output=True, text=True, timeout=30
            )

            if delete_result.returncode == 0:
                return True, "Service removed"
            elif 'does not exist' in delete_result.stderr.lower():
                return True, "Already removed"
            else:
                return False, delete_result.stderr.strip()

        except subprocess.TimeoutExpired:
            return False, "Operation timed out"
        except Exception as e:
            return False, str(e)

    def disable_service(self, name: str) -> Tuple[bool, str]:
        """Disable a service instead of removing"""
        try:
            subprocess.run(
                ['sc', 'stop', name],
                capture_output=True, timeout=30
            )

            result = subprocess.run(
                ['sc', 'config', name, 'start=', 'disabled'],
                capture_output=True, text=True, timeout=30
            )

            if result.returncode == 0:
                return True, "Service disabled"
            else:
                return False, result.stderr.strip()

        except Exception as e:
            return False, str(e)

    def get_deleted_services(self) -> List[str]:
        """Get list of deleted services"""
        return self._deleted_services

    def restore_backup(self, backup_file: str = None) -> Tuple[int, int]:
        """Restore from backup"""
        if backup_file:
            self.backup.load_backup(backup_file)
        return self.backup.restore_services()

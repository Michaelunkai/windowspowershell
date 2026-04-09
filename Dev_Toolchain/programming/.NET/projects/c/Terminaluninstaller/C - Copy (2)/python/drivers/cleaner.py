"""
Driver cleaner for Ultimate Uninstaller
Safe driver removal and cleanup
"""

import subprocess
import shutil
import json
import time
import os
from typing import List, Dict, Generator, Tuple, Optional
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from core.base import BaseCleaner, CleanResult, ScanResult
from core.config import Config
from core.logger import Logger
from core.exceptions import DriverError
from .scanner import DriverInfo, DriverState


@dataclass
class DriverBackupEntry:
    """Driver backup entry"""
    name: str
    display_name: str
    image_path: str
    start_type: int
    inf_file: str
    driver_store_path: str
    timestamp: float


class DriverBackup:
    """Driver backup manager"""

    def __init__(self, backup_dir: str):
        self.backup_dir = Path(backup_dir)
        self.backup_dir.mkdir(parents=True, exist_ok=True)
        self._entries: List[DriverBackupEntry] = []
        self._backup_file: Optional[Path] = None
        self._files_dir: Optional[Path] = None

    def start_backup(self, name: str = None) -> str:
        """Start new backup session"""
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        name = name or f"driver_backup_{timestamp}"
        self._session_dir = self.backup_dir / name
        self._session_dir.mkdir(parents=True, exist_ok=True)
        self._backup_file = self._session_dir / "manifest.json"
        self._files_dir = self._session_dir / "files"
        self._files_dir.mkdir(exist_ok=True)
        self._entries = []
        return str(self._session_dir)

    def backup_driver(self, driver: DriverInfo) -> bool:
        """Backup driver configuration and files"""
        try:
            driver_files_dir = self._files_dir / driver.name
            driver_files_dir.mkdir(exist_ok=True)

            image_path = self._resolve_path(driver.image_path)
            if image_path and os.path.exists(image_path):
                shutil.copy2(image_path, driver_files_dir)

            entry = DriverBackupEntry(
                name=driver.name,
                display_name=driver.display_name,
                image_path=driver.image_path,
                start_type=driver.start_type,
                inf_file=driver.inf_file,
                driver_store_path="",
                timestamp=time.time()
            )
            self._entries.append(entry)
            return True
        except:
            return False

    def _resolve_path(self, path: str) -> Optional[str]:
        """Resolve driver image path"""
        if not path:
            return None

        if path.startswith('\\SystemRoot'):
            system_root = os.environ.get('SYSTEMROOT', r'C:\Windows')
            return path.replace('\\SystemRoot', system_root)
        elif path.startswith('System32'):
            system_root = os.environ.get('SYSTEMROOT', r'C:\Windows')
            return os.path.join(system_root, path)
        elif path.startswith('\\??\\'):
            return path[4:]

        return path

    def save_backup(self) -> bool:
        """Save backup manifest"""
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
                        'image_path': e.image_path,
                        'start_type': e.start_type,
                        'inf_file': e.inf_file,
                        'driver_store_path': e.driver_store_path,
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
        """Load backup manifest"""
        try:
            with open(path, 'r') as f:
                data = json.load(f)

            self._session_dir = Path(path).parent
            self._files_dir = self._session_dir / "files"

            self._entries = [
                DriverBackupEntry(
                    name=e['name'],
                    display_name=e['display_name'],
                    image_path=e['image_path'],
                    start_type=e['start_type'],
                    inf_file=e.get('inf_file', ''),
                    driver_store_path=e.get('driver_store_path', ''),
                    timestamp=e['timestamp']
                )
                for e in data.get('entries', [])
            ]
            return True
        except:
            return False

    def restore_drivers(self) -> Tuple[int, int]:
        """Restore backed up drivers"""
        restored = 0
        failed = 0

        for entry in self._entries:
            try:
                backup_file = self._files_dir / entry.name
                if backup_file.exists():
                    for f in backup_file.iterdir():
                        if f.suffix.lower() == '.sys':
                            target = self._resolve_path(entry.image_path)
                            if target:
                                os.makedirs(os.path.dirname(target), exist_ok=True)
                                shutil.copy2(f, target)

                result = subprocess.run(
                    ['sc', 'create', entry.name,
                     'binPath=', entry.image_path,
                     'DisplayName=', entry.display_name,
                     'type=', 'kernel',
                     'start=', str(entry.start_type)],
                    capture_output=True, timeout=30
                )

                if result.returncode == 0:
                    restored += 1
                else:
                    failed += 1

            except:
                failed += 1

        return restored, failed


class DriverCleaner(BaseCleaner):
    """Driver cleaner for removing software drivers"""

    PROTECTED_DRIVERS = {
        'disk', 'ntfs', 'volmgr', 'partmgr', 'volume', 'mountmgr',
        'fltmgr', 'ksecdd', 'tcpip', 'afd', 'netbt', 'mrxsmb', 'rdbss',
        'ndis', 'http', 'dfsc', 'classpnp', 'storport', 'acpi', 'pci',
    }

    def __init__(self, config: Config, logger: Logger = None):
        super().__init__(config, logger)
        self.backup = DriverBackup(config.backup_dir)
        self._deleted_drivers: List[str] = []

    def clean(self, items: List[ScanResult]) -> Generator[CleanResult, None, None]:
        """Remove drivers from scan results"""
        if self.config.create_backup:
            self.backup.start_backup()

        for item in items:
            if self.is_cancelled():
                break
            self.wait_if_paused()

            if item.item_type != "driver":
                continue

            yield self._clean_driver(item)

        if self.config.create_backup:
            self.backup.save_backup()

    def _clean_driver(self, item: ScanResult) -> CleanResult:
        """Remove a single driver"""
        driver_name = item.name

        if self._is_protected(driver_name):
            return CleanResult(
                module=self.name,
                action="skip",
                target=driver_name,
                success=False,
                message="Protected system driver"
            )

        driver_info = self._get_driver_info(item)

        if driver_info and self.config.create_backup:
            self.backup.backup_driver(driver_info)

        if self.config.dry_run:
            return CleanResult(
                module=self.name,
                action="delete (dry run)",
                target=driver_name,
                success=True,
                message="Would remove driver"
            )

        success, message = self._remove_driver(driver_name)

        if success:
            self._deleted_drivers.append(driver_name)

        return CleanResult(
            module=self.name,
            action="delete",
            target=driver_name,
            success=success,
            message=message
        )

    def _is_protected(self, name: str) -> bool:
        """Check if driver is protected"""
        return name.lower() in self.PROTECTED_DRIVERS

    def _get_driver_info(self, item: ScanResult) -> Optional[DriverInfo]:
        """Get driver info from scan result"""
        details = item.details or {}

        return DriverInfo(
            name=item.name,
            display_name=details.get('display_name', item.name),
            description=details.get('description', ''),
            image_path=details.get('image_path', ''),
            start_type=details.get('start_type', 3)
        )

    def _remove_driver(self, name: str) -> Tuple[bool, str]:
        """Remove a Windows driver"""
        try:
            subprocess.run(
                ['sc', 'stop', name],
                capture_output=True, timeout=30
            )

            time.sleep(1)

            delete_result = subprocess.run(
                ['sc', 'delete', name],
                capture_output=True, text=True, timeout=30
            )

            if delete_result.returncode == 0:
                return True, "Driver removed"
            elif 'does not exist' in delete_result.stderr.lower():
                return True, "Already removed"
            else:
                return False, delete_result.stderr.strip()

        except subprocess.TimeoutExpired:
            return False, "Operation timed out"
        except Exception as e:
            return False, str(e)

    def clean_driver_store(self, patterns: List[str]) -> int:
        """Clean driver store packages matching patterns"""
        cleaned = 0
        driver_store = os.path.join(
            os.environ.get('SYSTEMROOT', r'C:\Windows'),
            'System32', 'DriverStore', 'FileRepository'
        )

        if not os.path.exists(driver_store):
            return 0

        try:
            for entry in os.scandir(driver_store):
                if entry.is_dir():
                    name_lower = entry.name.lower()
                    if any(p.lower() in name_lower for p in patterns):
                        if self.config.dry_run:
                            cleaned += 1
                        else:
                            try:
                                shutil.rmtree(entry.path)
                                cleaned += 1
                            except:
                                pass
        except:
            pass

        return cleaned

    def get_deleted_drivers(self) -> List[str]:
        """Get list of deleted drivers"""
        return self._deleted_drivers

    def restore_backup(self, backup_file: str = None) -> Tuple[int, int]:
        """Restore from backup"""
        if backup_file:
            self.backup.load_backup(backup_file)
        return self.backup.restore_drivers()

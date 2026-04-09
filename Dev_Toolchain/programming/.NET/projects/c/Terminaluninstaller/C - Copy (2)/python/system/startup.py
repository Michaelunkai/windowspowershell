"""
Startup scanner and cleaner for Ultimate Uninstaller
Manages Windows startup items
"""

import winreg
import os
import json
import time
from typing import List, Dict, Generator, Optional, Tuple
from dataclasses import dataclass, field
from datetime import datetime
from pathlib import Path
from enum import Enum
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from core.base import BaseScanner, BaseCleaner, ScanResult, CleanResult
from core.config import Config, ScanDepth
from core.logger import Logger


class StartupLocation(Enum):
    """Startup location type"""
    REGISTRY_RUN = "registry_run"
    REGISTRY_RUNONCE = "registry_runonce"
    STARTUP_FOLDER = "startup_folder"
    TASK_SCHEDULER = "task_scheduler"
    SERVICE = "service"


@dataclass
class StartupItem:
    """Startup item information"""
    name: str
    command: str
    location: StartupLocation
    path: str
    enabled: bool = True
    user_specific: bool = False
    description: str = ""


class StartupScanner(BaseScanner):
    """Scans Windows startup items"""

    RUN_KEYS = [
        (winreg.HKEY_LOCAL_MACHINE,
         r"SOFTWARE\Microsoft\Windows\CurrentVersion\Run", False),
        (winreg.HKEY_LOCAL_MACHINE,
         r"SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce", False),
        (winreg.HKEY_LOCAL_MACHINE,
         r"SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run", False),
        (winreg.HKEY_CURRENT_USER,
         r"Software\Microsoft\Windows\CurrentVersion\Run", True),
        (winreg.HKEY_CURRENT_USER,
         r"Software\Microsoft\Windows\CurrentVersion\RunOnce", True),
    ]

    def __init__(self, config: Config, logger: Logger = None):
        super().__init__(config, logger)
        self._found_items: Dict[str, StartupItem] = {}
        self._all_items: List[StartupItem] = []

    def scan(self, target: str = None, patterns: List[str] = None,
             depth: ScanDepth = None) -> Generator[ScanResult, None, None]:
        """Scan startup items for matching entries"""
        patterns = patterns or []

        if target:
            patterns.append(target.lower())

        self.log_info(f"Starting startup scan for: {patterns}")
        self._stats.items_scanned = 0

        items = self._enumerate_startup_items()

        for item in items:
            if self.is_cancelled():
                break

            self._stats.items_scanned += 1

            if self._matches_patterns(item, patterns):
                self._found_items[item.name] = item
                self._stats.items_found += 1

                yield ScanResult(
                    module=self.name,
                    item_type="startup",
                    path=item.path,
                    name=item.name,
                    details={
                        'command': item.command,
                        'location': item.location.value,
                        'enabled': item.enabled,
                        'user_specific': item.user_specific,
                    }
                )

        self.log_info(f"Startup scan complete. Found {self._stats.items_found} items")

    def _enumerate_startup_items(self) -> List[StartupItem]:
        """Enumerate all startup items"""
        items = []

        for hive, path, user_specific in self.RUN_KEYS:
            items.extend(self._scan_registry_run(hive, path, user_specific))

        items.extend(self._scan_startup_folders())

        self._all_items = items
        return items

    def _scan_registry_run(self, hive: int, path: str,
                          user_specific: bool) -> List[StartupItem]:
        """Scan registry run keys"""
        items = []
        hive_name = "HKCU" if user_specific else "HKLM"

        try:
            key = winreg.OpenKey(hive, path, 0, winreg.KEY_READ)
            _, value_count, _ = winreg.QueryInfoKey(key)

            location = StartupLocation.REGISTRY_RUNONCE if 'RunOnce' in path else StartupLocation.REGISTRY_RUN

            for i in range(value_count):
                try:
                    name, data, _ = winreg.EnumValue(key, i)
                    items.append(StartupItem(
                        name=name or "(Default)",
                        command=str(data),
                        location=location,
                        path=f"{hive_name}\\{path}",
                        user_specific=user_specific
                    ))
                except:
                    continue

            winreg.CloseKey(key)

        except:
            pass

        return items

    def _scan_startup_folders(self) -> List[StartupItem]:
        """Scan startup folders"""
        items = []

        startup_paths = [
            (os.path.join(os.environ.get('APPDATA', ''),
                         'Microsoft', 'Windows', 'Start Menu', 'Programs', 'Startup'), True),
            (os.path.join(os.environ.get('PROGRAMDATA', ''),
                         'Microsoft', 'Windows', 'Start Menu', 'Programs', 'Startup'), False),
        ]

        for folder, user_specific in startup_paths:
            if os.path.exists(folder):
                try:
                    for entry in os.scandir(folder):
                        if entry.is_file():
                            items.append(StartupItem(
                                name=entry.name,
                                command=entry.path,
                                location=StartupLocation.STARTUP_FOLDER,
                                path=folder,
                                user_specific=user_specific
                            ))
                except:
                    pass

        return items

    def _matches_patterns(self, item: StartupItem, patterns: List[str]) -> bool:
        """Check if item matches patterns"""
        if not patterns:
            return False

        search_text = f"{item.name} {item.command}".lower()
        return any(p.lower() in search_text for p in patterns)

    def get_found_items(self) -> Dict[str, StartupItem]:
        """Get found startup items"""
        return self._found_items

    def get_all_items(self) -> List[StartupItem]:
        """Get all startup items"""
        if not self._all_items:
            self._enumerate_startup_items()
        return self._all_items


class StartupCleaner(BaseCleaner):
    """Cleaner for startup items"""

    def __init__(self, config: Config, logger: Logger = None):
        super().__init__(config, logger)
        self._backup_file: Optional[Path] = None
        self._backup_entries: List[Dict] = []
        self._deleted_items: List[str] = []

    def clean(self, items: List[ScanResult]) -> Generator[CleanResult, None, None]:
        """Remove startup items from scan results"""
        if self.config.create_backup:
            self._start_backup()

        for item in items:
            if self.is_cancelled():
                break
            self.wait_if_paused()

            if item.item_type != "startup":
                continue

            yield self._clean_item(item)

        if self.config.create_backup:
            self._save_backup()

    def _start_backup(self):
        """Start backup session"""
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        backup_dir = Path(self.config.backup_dir)
        backup_dir.mkdir(parents=True, exist_ok=True)
        self._backup_file = backup_dir / f"startup_backup_{timestamp}.json"
        self._backup_entries = []

    def _save_backup(self):
        """Save backup to file"""
        if self._backup_file and self._backup_entries:
            try:
                data = {
                    'version': '1.0',
                    'created': datetime.now().isoformat(),
                    'entries': self._backup_entries
                }
                with open(self._backup_file, 'w') as f:
                    json.dump(data, f, indent=2)
            except:
                pass

    def _clean_item(self, item: ScanResult) -> CleanResult:
        """Remove a startup item"""
        details = item.details or {}
        location = details.get('location', '')

        if self.config.create_backup:
            self._backup_entries.append({
                'name': item.name,
                'path': item.path,
                'command': details.get('command', ''),
                'location': location,
            })

        if self.config.dry_run:
            return CleanResult(
                module=self.name,
                action="delete (dry run)",
                target=item.name,
                success=True,
                message="Would remove startup item"
            )

        if location == StartupLocation.STARTUP_FOLDER.value:
            success, message = self._remove_startup_file(item)
        else:
            success, message = self._remove_registry_entry(item)

        if success:
            self._deleted_items.append(item.name)

        return CleanResult(
            module=self.name,
            action="delete",
            target=item.name,
            success=success,
            message=message
        )

    def _remove_registry_entry(self, item: ScanResult) -> Tuple[bool, str]:
        """Remove registry startup entry"""
        path = item.path
        name = item.name

        try:
            if path.startswith("HKLM"):
                hive = winreg.HKEY_LOCAL_MACHINE
                subkey = path.replace("HKLM\\", "")
            else:
                hive = winreg.HKEY_CURRENT_USER
                subkey = path.replace("HKCU\\", "")

            key = winreg.OpenKey(hive, subkey, 0, winreg.KEY_SET_VALUE)
            winreg.DeleteValue(key, name)
            winreg.CloseKey(key)

            return True, "Removed"

        except FileNotFoundError:
            return True, "Already removed"
        except Exception as e:
            return False, str(e)

    def _remove_startup_file(self, item: ScanResult) -> Tuple[bool, str]:
        """Remove startup folder file"""
        details = item.details or {}
        command = details.get('command', '')

        if os.path.exists(command):
            try:
                os.remove(command)
                return True, "Removed"
            except Exception as e:
                return False, str(e)

        return True, "Already removed"

    def get_deleted_items(self) -> List[str]:
        """Get list of deleted items"""
        return self._deleted_items

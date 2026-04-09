"""
Registry cleaner for Ultimate Uninstaller
Safe deletion and backup of registry entries
"""

import winreg
import os
import json
import time
from typing import List, Dict, Generator, Optional, Tuple, Any
from dataclasses import dataclass, field
from pathlib import Path
from datetime import datetime
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from core.base import BaseCleaner, CleanResult, ScanResult
from core.config import Config
from core.logger import Logger
from core.exceptions import RegistryError
from .scanner import RegistryHive, RegistryKey, RegistryValue


@dataclass
class RegistryBackupEntry:
    """Single registry backup entry"""
    key_path: str
    hive: str
    values: List[Dict[str, Any]]
    subkeys: List[str]
    timestamp: float


class RegistryBackup:
    """Registry backup manager"""

    def __init__(self, backup_dir: str):
        self.backup_dir = Path(backup_dir)
        self.backup_dir.mkdir(parents=True, exist_ok=True)
        self._entries: List[RegistryBackupEntry] = []
        self._backup_file: Optional[Path] = None

    def start_backup(self, name: str = None) -> str:
        """Start a new backup session"""
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        name = name or f"registry_backup_{timestamp}"
        self._backup_file = self.backup_dir / f"{name}.json"
        self._entries = []
        return str(self._backup_file)

    def backup_key(self, hive: RegistryHive, path: str) -> bool:
        """Backup a registry key with all values and subkeys"""
        try:
            key = winreg.OpenKey(hive.value, path, 0, winreg.KEY_READ)
        except (PermissionError, FileNotFoundError, OSError):
            return False

        try:
            values = []
            _, value_count, _ = winreg.QueryInfoKey(key)

            for i in range(value_count):
                try:
                    name, data, value_type = winreg.EnumValue(key, i)

                    if isinstance(data, bytes):
                        data = data.hex()

                    values.append({
                        'name': name,
                        'data': data,
                        'type': value_type,
                    })
                except OSError:
                    continue

            subkeys = []
            subkey_count, _, _ = winreg.QueryInfoKey(key)

            for i in range(subkey_count):
                try:
                    subkey_name = winreg.EnumKey(key, i)
                    subkeys.append(subkey_name)
                except OSError:
                    continue

            entry = RegistryBackupEntry(
                key_path=path,
                hive=hive.name,
                values=values,
                subkeys=subkeys,
                timestamp=time.time()
            )

            self._entries.append(entry)
            return True

        finally:
            winreg.CloseKey(key)

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
                        'key_path': e.key_path,
                        'hive': e.hive,
                        'values': e.values,
                        'subkeys': e.subkeys,
                        'timestamp': e.timestamp,
                    }
                    for e in self._entries
                ]
            }

            with open(self._backup_file, 'w') as f:
                json.dump(data, f, indent=2)

            return True
        except Exception:
            return False

    def load_backup(self, path: str) -> bool:
        """Load backup from file"""
        try:
            with open(path, 'r') as f:
                data = json.load(f)

            self._entries = []
            for entry_data in data.get('entries', []):
                entry = RegistryBackupEntry(
                    key_path=entry_data['key_path'],
                    hive=entry_data['hive'],
                    values=entry_data['values'],
                    subkeys=entry_data['subkeys'],
                    timestamp=entry_data['timestamp']
                )
                self._entries.append(entry)

            return True
        except Exception:
            return False

    def restore_backup(self) -> Tuple[int, int]:
        """Restore all backed up entries"""
        restored = 0
        failed = 0

        for entry in reversed(self._entries):
            try:
                hive = RegistryHive[entry.hive]

                try:
                    key = winreg.CreateKey(hive.value, entry.key_path)
                except:
                    key = winreg.OpenKey(
                        hive.value, entry.key_path, 0,
                        winreg.KEY_WRITE | winreg.KEY_SET_VALUE
                    )

                for value in entry.values:
                    try:
                        data = value['data']
                        if value['type'] == winreg.REG_BINARY:
                            data = bytes.fromhex(data)

                        winreg.SetValueEx(
                            key, value['name'], 0,
                            value['type'], data
                        )
                    except:
                        pass

                winreg.CloseKey(key)
                restored += 1

            except Exception:
                failed += 1

        return restored, failed

    def get_entries(self) -> List[RegistryBackupEntry]:
        """Get all backup entries"""
        return self._entries


class RegistryCleaner(BaseCleaner):
    """Registry cleaner for removing software traces"""

    PROTECTED_KEYS = [
        r"SOFTWARE\Microsoft\Windows NT",
        r"SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing",
        r"SYSTEM\CurrentControlSet\Control",
        r"SYSTEM\CurrentControlSet\Enum",
        r"SYSTEM\Setup",
        r"SECURITY",
        r"SAM",
    ]

    def __init__(self, config: Config, logger: Logger = None):
        super().__init__(config, logger)
        self.backup = RegistryBackup(config.backup_dir)
        self._deleted_keys: List[str] = []
        self._deleted_values: List[Tuple[str, str]] = []

    def clean(self, items: List[ScanResult]) -> Generator[CleanResult, None, None]:
        """Clean registry entries from scan results"""
        if self.config.create_backup:
            self.backup.start_backup()

        for item in items:
            if self.is_cancelled():
                break
            self.wait_if_paused()

            if item.item_type != "registry_key":
                continue

            yield self._clean_key(item)

        if self.config.create_backup:
            self.backup.save_backup()

    def _clean_key(self, item: ScanResult) -> CleanResult:
        """Clean a single registry key"""
        key_path = item.path
        hive_name = item.details.get('hive', 'HKLM')
        path = item.details.get('path', '')

        if self._is_protected(path):
            return CleanResult(
                module=self.name,
                action="skip",
                target=key_path,
                success=False,
                message="Protected system key"
            )

        try:
            hive = RegistryHive[hive_name]
        except KeyError:
            return CleanResult(
                module=self.name,
                action="delete",
                target=key_path,
                success=False,
                message=f"Unknown hive: {hive_name}"
            )

        if self.config.create_backup:
            self.backup.backup_key(hive, path)

        if self.config.dry_run:
            return CleanResult(
                module=self.name,
                action="delete (dry run)",
                target=key_path,
                success=True,
                message="Would delete"
            )

        success, message = self._delete_key(hive, path)

        if success:
            self._deleted_keys.append(key_path)

        return CleanResult(
            module=self.name,
            action="delete",
            target=key_path,
            success=success,
            message=message
        )

    def _is_protected(self, path: str) -> bool:
        """Check if path is protected"""
        path_lower = path.lower()
        for protected in self.PROTECTED_KEYS:
            if path_lower.startswith(protected.lower()):
                return True
        return False

    def _delete_key(self, hive: RegistryHive, path: str) -> Tuple[bool, str]:
        """Delete a registry key and all subkeys"""
        try:
            self._delete_key_recursive(hive.value, path)
            return True, "Deleted"
        except PermissionError:
            return False, "Access denied"
        except FileNotFoundError:
            return True, "Already deleted"
        except OSError as e:
            return False, str(e)

    def _delete_key_recursive(self, hive, path: str):
        """Recursively delete registry key and subkeys"""
        try:
            key = winreg.OpenKey(hive, path, 0,
                                winreg.KEY_ALL_ACCESS | winreg.KEY_WOW64_64KEY)
        except FileNotFoundError:
            return
        except PermissionError:
            try:
                key = winreg.OpenKey(hive, path, 0,
                                    winreg.KEY_ALL_ACCESS | winreg.KEY_WOW64_32KEY)
            except:
                raise

        try:
            while True:
                try:
                    subkey_name = winreg.EnumKey(key, 0)
                    subkey_path = f"{path}\\{subkey_name}"
                    self._delete_key_recursive(hive, subkey_path)
                except OSError:
                    break
        finally:
            winreg.CloseKey(key)

        parent_path = '\\'.join(path.split('\\')[:-1])
        key_name = path.split('\\')[-1]

        if parent_path:
            try:
                parent_key = winreg.OpenKey(hive, parent_path, 0,
                                           winreg.KEY_ALL_ACCESS)
                winreg.DeleteKey(parent_key, key_name)
                winreg.CloseKey(parent_key)
            except:
                winreg.DeleteKey(hive, path)
        else:
            winreg.DeleteKey(hive, path)

    def delete_value(self, hive: RegistryHive, path: str,
                    value_name: str) -> Tuple[bool, str]:
        """Delete a specific registry value"""
        try:
            key = winreg.OpenKey(hive.value, path, 0,
                                winreg.KEY_SET_VALUE)
            winreg.DeleteValue(key, value_name)
            winreg.CloseKey(key)

            self._deleted_values.append((f"{hive.name}\\{path}", value_name))
            return True, "Deleted"

        except FileNotFoundError:
            return True, "Not found"
        except PermissionError:
            return False, "Access denied"
        except OSError as e:
            return False, str(e)

    def clean_empty_keys(self, hive: RegistryHive, path: str) -> int:
        """Remove empty registry keys"""
        removed = 0

        try:
            key = winreg.OpenKey(hive.value, path, 0, winreg.KEY_READ)
            subkey_count, value_count, _ = winreg.QueryInfoKey(key)

            subkeys_to_check = []
            for i in range(subkey_count):
                try:
                    subkey_name = winreg.EnumKey(key, i)
                    subkeys_to_check.append(subkey_name)
                except:
                    continue

            winreg.CloseKey(key)

            for subkey_name in subkeys_to_check:
                subkey_path = f"{path}\\{subkey_name}"
                removed += self.clean_empty_keys(hive, subkey_path)

            key = winreg.OpenKey(hive.value, path, 0, winreg.KEY_READ)
            subkey_count, value_count, _ = winreg.QueryInfoKey(key)
            winreg.CloseKey(key)

            if subkey_count == 0 and value_count == 0:
                success, _ = self._delete_key(hive, path)
                if success:
                    removed += 1

        except:
            pass

        return removed

    def get_deleted_keys(self) -> List[str]:
        """Get list of deleted keys"""
        return self._deleted_keys

    def restore_backup(self, backup_file: str = None) -> Tuple[int, int]:
        """Restore from backup"""
        if backup_file:
            self.backup.load_backup(backup_file)
        return self.backup.restore_backup()

"""
Filesystem cleaner for Ultimate Uninstaller
Safe deletion and backup of files and directories
"""

import os
import shutil
import json
import time
from pathlib import Path
from typing import List, Dict, Generator, Optional, Tuple, Set
from dataclasses import dataclass, field
from datetime import datetime
from concurrent.futures import ThreadPoolExecutor
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from core.base import BaseCleaner, CleanResult, ScanResult
from core.config import Config
from core.logger import Logger
from core.exceptions import FileSystemError


@dataclass
class FileBackupEntry:
    """Single file backup entry"""
    original_path: str
    backup_path: str
    size: int
    timestamp: float
    is_directory: bool = False


class FileBackup:
    """File backup manager"""

    def __init__(self, backup_dir: str):
        self.backup_dir = Path(backup_dir)
        self.backup_dir.mkdir(parents=True, exist_ok=True)
        self._entries: List[FileBackupEntry] = []
        self._manifest_file: Optional[Path] = None

    def start_backup(self, name: str = None) -> str:
        """Start new backup session"""
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        name = name or f"file_backup_{timestamp}"
        self._session_dir = self.backup_dir / name
        self._session_dir.mkdir(parents=True, exist_ok=True)
        self._manifest_file = self._session_dir / "manifest.json"
        self._entries = []
        return str(self._session_dir)

    def backup_file(self, path: str) -> bool:
        """Backup a single file"""
        try:
            if not os.path.exists(path):
                return False

            rel_path = self._safe_relative_path(path)
            backup_path = self._session_dir / rel_path

            backup_path.parent.mkdir(parents=True, exist_ok=True)

            if os.path.isfile(path):
                shutil.copy2(path, backup_path)
                size = os.path.getsize(path)
            else:
                return False

            entry = FileBackupEntry(
                original_path=path,
                backup_path=str(backup_path),
                size=size,
                timestamp=time.time(),
                is_directory=False
            )
            self._entries.append(entry)
            return True

        except Exception:
            return False

    def backup_directory(self, path: str) -> bool:
        """Backup entire directory"""
        try:
            if not os.path.isdir(path):
                return False

            rel_path = self._safe_relative_path(path)
            backup_path = self._session_dir / rel_path

            shutil.copytree(path, backup_path, dirs_exist_ok=True)

            total_size = sum(
                os.path.getsize(os.path.join(r, f))
                for r, _, files in os.walk(backup_path)
                for f in files
            )

            entry = FileBackupEntry(
                original_path=path,
                backup_path=str(backup_path),
                size=total_size,
                timestamp=time.time(),
                is_directory=True
            )
            self._entries.append(entry)
            return True

        except Exception:
            return False

    def _safe_relative_path(self, path: str) -> str:
        """Create safe relative path for backup"""
        path = path.replace(':', '_drive')
        if path.startswith(('\\', '/')):
            path = path[1:]
        return path

    def save_manifest(self) -> bool:
        """Save backup manifest"""
        if not self._manifest_file:
            return False

        try:
            data = {
                'version': '1.0',
                'created': datetime.now().isoformat(),
                'entries': [
                    {
                        'original_path': e.original_path,
                        'backup_path': e.backup_path,
                        'size': e.size,
                        'timestamp': e.timestamp,
                        'is_directory': e.is_directory,
                    }
                    for e in self._entries
                ]
            }

            with open(self._manifest_file, 'w') as f:
                json.dump(data, f, indent=2)
            return True
        except:
            return False

    def load_manifest(self, manifest_path: str) -> bool:
        """Load backup manifest"""
        try:
            with open(manifest_path, 'r') as f:
                data = json.load(f)

            self._entries = [
                FileBackupEntry(
                    original_path=e['original_path'],
                    backup_path=e['backup_path'],
                    size=e['size'],
                    timestamp=e['timestamp'],
                    is_directory=e.get('is_directory', False)
                )
                for e in data.get('entries', [])
            ]
            return True
        except:
            return False

    def restore_all(self) -> Tuple[int, int]:
        """Restore all backed up items"""
        restored = 0
        failed = 0

        for entry in reversed(self._entries):
            try:
                if entry.is_directory:
                    if os.path.exists(entry.backup_path):
                        shutil.copytree(entry.backup_path, entry.original_path,
                                       dirs_exist_ok=True)
                        restored += 1
                else:
                    if os.path.exists(entry.backup_path):
                        os.makedirs(os.path.dirname(entry.original_path), exist_ok=True)
                        shutil.copy2(entry.backup_path, entry.original_path)
                        restored += 1
            except:
                failed += 1

        return restored, failed

    def get_entries(self) -> List[FileBackupEntry]:
        """Get all backup entries"""
        return self._entries


class FileSystemCleaner(BaseCleaner):
    """Filesystem cleaner for removing software traces"""

    PROTECTED_PATHS = [
        os.environ.get('SYSTEMROOT', r'C:\Windows'),
        os.environ.get('SYSTEMDRIVE', 'C:') + '\\',
    ]

    def __init__(self, config: Config, logger: Logger = None):
        super().__init__(config, logger)
        self.backup = FileBackup(config.backup_dir)
        self._deleted_files: List[str] = []
        self._deleted_dirs: List[str] = []

    def clean(self, items: List[ScanResult]) -> Generator[CleanResult, None, None]:
        """Clean files and directories from scan results"""
        if self.config.create_backup:
            self.backup.start_backup()

        dirs_to_delete = []
        files_to_delete = []

        for item in items:
            if item.item_type == "directory":
                dirs_to_delete.append(item)
            elif item.item_type == "file":
                files_to_delete.append(item)

        for item in files_to_delete:
            if self.is_cancelled():
                break
            self.wait_if_paused()
            yield self._clean_file(item)

        for item in dirs_to_delete:
            if self.is_cancelled():
                break
            self.wait_if_paused()
            yield self._clean_directory(item)

        if self.config.create_backup:
            self.backup.save_manifest()

    def _clean_file(self, item: ScanResult) -> CleanResult:
        """Delete a single file"""
        path = item.path

        if self._is_protected(path):
            return CleanResult(
                module=self.name,
                action="skip",
                target=path,
                success=False,
                message="Protected system path"
            )

        if self.config.create_backup:
            self.backup.backup_file(path)

        if self.config.dry_run:
            return CleanResult(
                module=self.name,
                action="delete (dry run)",
                target=path,
                success=True,
                message="Would delete"
            )

        success, message = self._delete_file(path)

        if success:
            self._deleted_files.append(path)

        return CleanResult(
            module=self.name,
            action="delete",
            target=path,
            success=success,
            message=message
        )

    def _clean_directory(self, item: ScanResult) -> CleanResult:
        """Delete a directory"""
        path = item.path

        if self._is_protected(path):
            return CleanResult(
                module=self.name,
                action="skip",
                target=path,
                success=False,
                message="Protected system path"
            )

        if self.config.create_backup:
            self.backup.backup_directory(path)

        if self.config.dry_run:
            return CleanResult(
                module=self.name,
                action="delete (dry run)",
                target=path,
                success=True,
                message="Would delete"
            )

        success, message = self._delete_directory(path)

        if success:
            self._deleted_dirs.append(path)

        return CleanResult(
            module=self.name,
            action="delete",
            target=path,
            success=success,
            message=message
        )

    def _is_protected(self, path: str) -> bool:
        """Check if path is protected"""
        path_lower = path.lower()
        for protected in self.PROTECTED_PATHS:
            if path_lower.startswith(protected.lower()):
                if protected.lower() == path_lower or protected.lower() + '\\' == path_lower:
                    return True
        return False

    def _delete_file(self, path: str) -> Tuple[bool, str]:
        """Delete a file"""
        try:
            if not os.path.exists(path):
                return True, "Already deleted"

            os.chmod(path, 0o777)
            os.remove(path)
            return True, "Deleted"

        except PermissionError:
            return False, "Access denied"
        except OSError as e:
            return False, str(e)

    def _delete_directory(self, path: str) -> Tuple[bool, str]:
        """Delete a directory and all contents"""
        try:
            if not os.path.exists(path):
                return True, "Already deleted"

            def remove_readonly(func, path, excinfo):
                os.chmod(path, 0o777)
                func(path)

            shutil.rmtree(path, onerror=remove_readonly)
            return True, "Deleted"

        except PermissionError:
            return False, "Access denied"
        except OSError as e:
            return False, str(e)

    def delete_empty_directories(self, base_path: str) -> int:
        """Remove empty directories"""
        removed = 0

        for root, dirs, files in os.walk(base_path, topdown=False):
            for d in dirs:
                dir_path = os.path.join(root, d)
                try:
                    if not os.listdir(dir_path):
                        os.rmdir(dir_path)
                        removed += 1
                except:
                    continue

        return removed

    def get_deleted_files(self) -> List[str]:
        """Get list of deleted files"""
        return self._deleted_files

    def get_deleted_dirs(self) -> List[str]:
        """Get list of deleted directories"""
        return self._deleted_dirs

    def restore_backup(self, manifest_path: str = None) -> Tuple[int, int]:
        """Restore from backup"""
        if manifest_path:
            self.backup.load_manifest(manifest_path)
        return self.backup.restore_all()

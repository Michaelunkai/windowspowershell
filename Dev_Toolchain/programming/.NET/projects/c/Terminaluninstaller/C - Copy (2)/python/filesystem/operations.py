"""
Filesystem operations for Ultimate Uninstaller
Low-level file operations with safety checks
"""

import os
import stat
import shutil
import ctypes
import subprocess
from pathlib import Path
from typing import List, Dict, Optional, Tuple, Any
from dataclasses import dataclass
import sys
import time
import random

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from core.logger import Logger
from core.exceptions import FileSystemError
from core.admin import AdminHelper


@dataclass
class FileAttributes:
    """File attributes information"""
    path: str
    size: int
    is_hidden: bool
    is_system: bool
    is_readonly: bool
    is_archive: bool
    is_directory: bool
    created: float
    modified: float
    accessed: float


class SecureDelete:
    """Secure file deletion with overwrite"""

    OVERWRITE_PASSES = 3
    PATTERNS = [b'\x00', b'\xff', b'\xaa', b'\x55']

    @classmethod
    def secure_delete_file(cls, path: str, passes: int = None) -> bool:
        """Securely delete file by overwriting"""
        passes = passes or cls.OVERWRITE_PASSES

        if not os.path.isfile(path):
            return False

        try:
            size = os.path.getsize(path)

            os.chmod(path, stat.S_IWRITE | stat.S_IREAD)

            with open(path, 'r+b') as f:
                for i in range(passes):
                    pattern = cls.PATTERNS[i % len(cls.PATTERNS)]
                    f.seek(0)
                    for _ in range(size):
                        f.write(pattern)
                    f.flush()
                    os.fsync(f.fileno())

                f.seek(0)
                f.write(os.urandom(size))
                f.flush()
                os.fsync(f.fileno())

            os.remove(path)
            return True

        except Exception:
            try:
                os.remove(path)
                return True
            except:
                return False

    @classmethod
    def secure_delete_directory(cls, path: str, passes: int = None) -> bool:
        """Securely delete directory and contents"""
        if not os.path.isdir(path):
            return False

        try:
            for root, dirs, files in os.walk(path, topdown=False):
                for f in files:
                    file_path = os.path.join(root, f)
                    cls.secure_delete_file(file_path, passes)

                for d in dirs:
                    dir_path = os.path.join(root, d)
                    try:
                        os.rmdir(dir_path)
                    except:
                        pass

            os.rmdir(path)
            return True

        except Exception:
            return False


class FileOperations:
    """Low-level file operations"""

    FILE_ATTRIBUTE_HIDDEN = 0x02
    FILE_ATTRIBUTE_SYSTEM = 0x04
    FILE_ATTRIBUTE_READONLY = 0x01
    FILE_ATTRIBUTE_ARCHIVE = 0x20

    def __init__(self, logger: Logger = None):
        self.logger = logger or Logger.get_instance()
        self._is_admin = AdminHelper.is_admin()

    def get_attributes(self, path: str) -> Optional[FileAttributes]:
        """Get file attributes"""
        try:
            stat_info = os.stat(path)

            attrs = 0
            if hasattr(stat_info, 'st_file_attributes'):
                attrs = stat_info.st_file_attributes

            return FileAttributes(
                path=path,
                size=stat_info.st_size,
                is_hidden=bool(attrs & self.FILE_ATTRIBUTE_HIDDEN),
                is_system=bool(attrs & self.FILE_ATTRIBUTE_SYSTEM),
                is_readonly=bool(attrs & self.FILE_ATTRIBUTE_READONLY),
                is_archive=bool(attrs & self.FILE_ATTRIBUTE_ARCHIVE),
                is_directory=os.path.isdir(path),
                created=stat_info.st_ctime,
                modified=stat_info.st_mtime,
                accessed=stat_info.st_atime,
            )
        except:
            return None

    def set_hidden(self, path: str, hidden: bool = True) -> bool:
        """Set hidden attribute"""
        try:
            attrs = ctypes.windll.kernel32.GetFileAttributesW(path)
            if hidden:
                attrs |= self.FILE_ATTRIBUTE_HIDDEN
            else:
                attrs &= ~self.FILE_ATTRIBUTE_HIDDEN
            return ctypes.windll.kernel32.SetFileAttributesW(path, attrs) != 0
        except:
            return False

    def set_readonly(self, path: str, readonly: bool = True) -> bool:
        """Set readonly attribute"""
        try:
            if readonly:
                os.chmod(path, stat.S_IREAD)
            else:
                os.chmod(path, stat.S_IWRITE | stat.S_IREAD)
            return True
        except:
            return False

    def remove_all_attributes(self, path: str) -> bool:
        """Remove all file attributes"""
        try:
            ctypes.windll.kernel32.SetFileAttributesW(path, 0x80)
            os.chmod(path, stat.S_IWRITE | stat.S_IREAD)
            return True
        except:
            return False

    def force_delete(self, path: str) -> Tuple[bool, str]:
        """Force delete file or directory"""
        try:
            if not os.path.exists(path):
                return True, "Already deleted"

            self.remove_all_attributes(path)

            if os.path.isfile(path):
                os.remove(path)
            else:
                def onerror(func, path, exc_info):
                    self.remove_all_attributes(path)
                    func(path)

                shutil.rmtree(path, onerror=onerror)

            return True, "Deleted"

        except PermissionError:
            return self._try_scheduled_delete(path)
        except Exception as e:
            return False, str(e)

    def _try_scheduled_delete(self, path: str) -> Tuple[bool, str]:
        """Schedule file for deletion on reboot"""
        try:
            if os.path.isfile(path):
                ctypes.windll.kernel32.MoveFileExW(
                    path, None, 4
                )
                return True, "Scheduled for deletion on reboot"
        except:
            pass

        return False, "Access denied"

    def copy_with_retry(self, src: str, dst: str, retries: int = 3) -> bool:
        """Copy file with retry on failure"""
        for attempt in range(retries):
            try:
                os.makedirs(os.path.dirname(dst), exist_ok=True)

                if os.path.isfile(src):
                    shutil.copy2(src, dst)
                else:
                    shutil.copytree(src, dst, dirs_exist_ok=True)

                return True
            except Exception:
                if attempt < retries - 1:
                    time.sleep(0.5 * (attempt + 1))
                continue

        return False

    def move_with_retry(self, src: str, dst: str, retries: int = 3) -> bool:
        """Move file with retry on failure"""
        for attempt in range(retries):
            try:
                os.makedirs(os.path.dirname(dst), exist_ok=True)
                shutil.move(src, dst)
                return True
            except Exception:
                if attempt < retries - 1:
                    time.sleep(0.5 * (attempt + 1))
                continue

        return False

    def get_owner(self, path: str) -> Optional[str]:
        """Get file owner"""
        try:
            import win32security
            sd = win32security.GetFileSecurity(
                path, win32security.OWNER_SECURITY_INFORMATION
            )
            owner_sid = sd.GetSecurityDescriptorOwner()
            name, domain, _ = win32security.LookupAccountSid(None, owner_sid)
            return f"{domain}\\{name}"
        except:
            return None

    def take_ownership(self, path: str) -> bool:
        """Take ownership of file"""
        try:
            result = subprocess.run(
                ['takeown', '/f', path, '/r', '/d', 'y'],
                capture_output=True, timeout=30
            )
            return result.returncode == 0
        except:
            return False

    def grant_full_access(self, path: str) -> bool:
        """Grant full access to current user"""
        try:
            username = os.environ.get('USERNAME', '')
            result = subprocess.run(
                ['icacls', path, '/grant', f'{username}:F', '/t', '/c'],
                capture_output=True, timeout=30
            )
            return result.returncode == 0
        except:
            return False

    def is_in_use(self, path: str) -> bool:
        """Check if file is in use"""
        if not os.path.isfile(path):
            return False

        try:
            with open(path, 'r+b'):
                return False
        except IOError:
            return True
        except:
            return False

    def wait_for_file_release(self, path: str, timeout: int = 10) -> bool:
        """Wait for file to be released"""
        start = time.time()

        while time.time() - start < timeout:
            if not self.is_in_use(path):
                return True
            time.sleep(0.5)

        return False

    def rename_random(self, path: str) -> Optional[str]:
        """Rename file to random name"""
        try:
            directory = os.path.dirname(path)
            ext = os.path.splitext(path)[1]
            new_name = ''.join(random.choices('abcdefghijklmnopqrstuvwxyz', k=8)) + ext
            new_path = os.path.join(directory, new_name)

            os.rename(path, new_path)
            return new_path
        except:
            return None

    def get_directory_size(self, path: str) -> int:
        """Get directory total size"""
        total = 0

        try:
            for entry in os.scandir(path):
                if entry.is_file(follow_symlinks=False):
                    total += entry.stat().st_size
                elif entry.is_dir(follow_symlinks=False):
                    total += self.get_directory_size(entry.path)
        except:
            pass

        return total

    def list_open_handles(self, path: str) -> List[Dict[str, Any]]:
        """List processes with open handles to path"""
        handles = []

        try:
            result = subprocess.run(
                ['handle.exe', '-accepteula', path],
                capture_output=True, text=True, timeout=30
            )

            for line in result.stdout.split('\n'):
                if path.lower() in line.lower():
                    parts = line.split()
                    if len(parts) >= 3:
                        handles.append({
                            'process': parts[0],
                            'pid': parts[1] if len(parts) > 1 else '',
                            'handle': parts[2] if len(parts) > 2 else '',
                        })
        except:
            pass

        return handles

    def close_handles(self, path: str) -> int:
        """Attempt to close handles to path"""
        closed = 0

        try:
            result = subprocess.run(
                ['handle.exe', '-accepteula', '-c', path, '-y'],
                capture_output=True, timeout=30
            )
            if result.returncode == 0:
                closed = 1
        except:
            pass

        return closed

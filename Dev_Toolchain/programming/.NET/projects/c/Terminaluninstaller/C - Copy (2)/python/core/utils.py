"""
Utility functions for Ultimate Uninstaller
Common helpers used across all modules
"""

import os
import re
import sys
import time
import hashlib
import platform
import subprocess
import ctypes
from pathlib import Path
from typing import Optional, List, Dict, Tuple, Generator, Any, Union
from datetime import datetime, timedelta
from functools import wraps, lru_cache
from contextlib import contextmanager
import threading
import struct


class Utils:
    """General utility functions"""

    @staticmethod
    def is_admin() -> bool:
        """Check if running with administrator privileges"""
        try:
            if os.name == 'nt':
                return ctypes.windll.shell32.IsUserAnAdmin() != 0
            return os.getuid() == 0
        except:
            return False

    @staticmethod
    def run_as_admin(script_path: str = None) -> bool:
        """Restart script with admin privileges"""
        if Utils.is_admin():
            return True

        if os.name == 'nt':
            script = script_path or sys.argv[0]
            params = ' '.join(sys.argv[1:])

            ctypes.windll.shell32.ShellExecuteW(
                None, "runas", sys.executable, f'"{script}" {params}', None, 1
            )
            return False
        return False

    @staticmethod
    def get_system_info() -> Dict[str, Any]:
        """Get comprehensive system information"""
        info = {
            'platform': platform.system(),
            'platform_release': platform.release(),
            'platform_version': platform.version(),
            'architecture': platform.machine(),
            'processor': platform.processor(),
            'hostname': platform.node(),
            'python_version': platform.python_version(),
            'is_64bit': sys.maxsize > 2**32,
            'is_admin': Utils.is_admin(),
        }

        if os.name == 'nt':
            info['windows_edition'] = Utils._get_windows_edition()
            info['windows_build'] = Utils._get_windows_build()

        return info

    @staticmethod
    def _get_windows_edition() -> str:
        """Get Windows edition"""
        try:
            import winreg
            key = winreg.OpenKey(
                winreg.HKEY_LOCAL_MACHINE,
                r"SOFTWARE\Microsoft\Windows NT\CurrentVersion"
            )
            edition, _ = winreg.QueryValueEx(key, "EditionID")
            return edition
        except:
            return "Unknown"

    @staticmethod
    def _get_windows_build() -> str:
        """Get Windows build number"""
        try:
            import winreg
            key = winreg.OpenKey(
                winreg.HKEY_LOCAL_MACHINE,
                r"SOFTWARE\Microsoft\Windows NT\CurrentVersion"
            )
            build, _ = winreg.QueryValueEx(key, "CurrentBuild")
            return build
        except:
            return "Unknown"

    @staticmethod
    def normalize_path(path: str) -> str:
        """Normalize file path for consistent comparison"""
        if not path:
            return ""
        path = os.path.normpath(path)
        path = os.path.normcase(path)
        return path

    @staticmethod
    def expand_env_vars(path: str) -> str:
        """Expand environment variables in path"""
        return os.path.expandvars(os.path.expanduser(path))

    @staticmethod
    def safe_string(value: Any, default: str = "") -> str:
        """Safely convert value to string"""
        if value is None:
            return default
        try:
            if isinstance(value, bytes):
                return value.decode('utf-8', errors='ignore')
            return str(value)
        except:
            return default

    @staticmethod
    def match_pattern(text: str, patterns: List[str],
                      case_sensitive: bool = False) -> bool:
        """Check if text matches any pattern"""
        if not case_sensitive:
            text = text.lower()
            patterns = [p.lower() for p in patterns]

        for pattern in patterns:
            if '*' in pattern or '?' in pattern:
                regex = pattern.replace('.', r'\.').replace('*', '.*').replace('?', '.')
                if re.match(regex, text):
                    return True
            elif pattern in text:
                return True
        return False

    @staticmethod
    def format_size(size_bytes: int) -> str:
        """Format byte size to human readable string"""
        if size_bytes < 0:
            return "0 B"

        units = ['B', 'KB', 'MB', 'GB', 'TB', 'PB']
        unit_index = 0
        size = float(size_bytes)

        while size >= 1024 and unit_index < len(units) - 1:
            size /= 1024
            unit_index += 1

        if unit_index == 0:
            return f"{int(size)} {units[unit_index]}"
        return f"{size:.2f} {units[unit_index]}"

    @staticmethod
    def format_duration(seconds: float) -> str:
        """Format duration to human readable string"""
        if seconds < 0:
            return "0s"

        if seconds < 1:
            return f"{seconds*1000:.0f}ms"
        elif seconds < 60:
            return f"{seconds:.1f}s"
        elif seconds < 3600:
            minutes = int(seconds // 60)
            secs = int(seconds % 60)
            return f"{minutes}m {secs}s"
        else:
            hours = int(seconds // 3600)
            minutes = int((seconds % 3600) // 60)
            return f"{hours}h {minutes}m"

    @staticmethod
    def generate_hash(data: Union[str, bytes], algorithm: str = 'sha256') -> str:
        """Generate hash of data"""
        if isinstance(data, str):
            data = data.encode('utf-8')

        hasher = hashlib.new(algorithm)
        hasher.update(data)
        return hasher.hexdigest()

    @staticmethod
    def file_hash(path: str, algorithm: str = 'sha256',
                  chunk_size: int = 8192) -> Optional[str]:
        """Calculate file hash"""
        try:
            hasher = hashlib.new(algorithm)
            with open(path, 'rb') as f:
                while chunk := f.read(chunk_size):
                    hasher.update(chunk)
            return hasher.hexdigest()
        except:
            return None


class PathHelper:
    """Path manipulation helpers"""

    SYSTEM_DRIVE = os.environ.get('SystemDrive', 'C:')
    WINDOWS_DIR = os.environ.get('SystemRoot', r'C:\Windows')
    PROGRAM_FILES = os.environ.get('ProgramFiles', r'C:\Program Files')
    PROGRAM_FILES_X86 = os.environ.get('ProgramFiles(x86)', r'C:\Program Files (x86)')
    APPDATA = os.environ.get('APPDATA', '')
    LOCAL_APPDATA = os.environ.get('LOCALAPPDATA', '')
    PROGRAM_DATA = os.environ.get('ProgramData', r'C:\ProgramData')
    USER_PROFILE = os.environ.get('USERPROFILE', '')
    TEMP = os.environ.get('TEMP', '')

    @classmethod
    def get_all_user_profiles(cls) -> List[str]:
        """Get paths to all user profiles"""
        users_dir = Path(cls.SYSTEM_DRIVE) / "Users"
        profiles = []

        if users_dir.exists():
            for item in users_dir.iterdir():
                if item.is_dir() and item.name not in ['Public', 'Default', 'Default User', 'All Users']:
                    profiles.append(str(item))

        return profiles

    @classmethod
    def get_user_appdata_paths(cls, username: str = None) -> Dict[str, str]:
        """Get AppData paths for user"""
        if username:
            base = Path(cls.SYSTEM_DRIVE) / "Users" / username
        else:
            base = Path(cls.USER_PROFILE)

        return {
            'roaming': str(base / "AppData" / "Roaming"),
            'local': str(base / "AppData" / "Local"),
            'locallow': str(base / "AppData" / "LocalLow"),
        }

    @classmethod
    def is_system_path(cls, path: str) -> bool:
        """Check if path is a protected system path"""
        path = Utils.normalize_path(path)

        protected = [
            Utils.normalize_path(cls.WINDOWS_DIR),
            Utils.normalize_path(os.path.join(cls.WINDOWS_DIR, 'System32')),
            Utils.normalize_path(os.path.join(cls.WINDOWS_DIR, 'SysWOW64')),
            Utils.normalize_path(os.path.join(cls.WINDOWS_DIR, 'WinSxS')),
        ]

        for p in protected:
            if path.startswith(p):
                return True
        return False

    @classmethod
    def is_program_path(cls, path: str) -> bool:
        """Check if path is in Program Files"""
        path = Utils.normalize_path(path)

        program_dirs = [
            Utils.normalize_path(cls.PROGRAM_FILES),
            Utils.normalize_path(cls.PROGRAM_FILES_X86),
        ]

        for p in program_dirs:
            if path.startswith(p):
                return True
        return False

    @staticmethod
    def safe_delete(path: str, force: bool = False) -> Tuple[bool, str]:
        """Safely delete file or directory"""
        try:
            path_obj = Path(path)

            if not path_obj.exists():
                return True, "Already deleted"

            if PathHelper.is_system_path(path) and not force:
                return False, "Protected system path"

            if path_obj.is_file():
                path_obj.unlink()
            else:
                import shutil
                shutil.rmtree(path, ignore_errors=True)

            return True, "Deleted"
        except PermissionError:
            return False, "Permission denied"
        except Exception as e:
            return False, str(e)

    @staticmethod
    def get_folder_size(path: str) -> int:
        """Get total size of folder"""
        total = 0
        try:
            for entry in os.scandir(path):
                if entry.is_file(follow_symlinks=False):
                    total += entry.stat().st_size
                elif entry.is_dir(follow_symlinks=False):
                    total += PathHelper.get_folder_size(entry.path)
        except:
            pass
        return total

    @staticmethod
    def iter_files(path: str, pattern: str = "*",
                   recursive: bool = True) -> Generator[Path, None, None]:
        """Iterate over files matching pattern"""
        try:
            root = Path(path)
            if recursive:
                yield from root.rglob(pattern)
            else:
                yield from root.glob(pattern)
        except:
            pass


class TimeHelper:
    """Time-related utilities"""

    @staticmethod
    def timestamp() -> float:
        """Get current timestamp"""
        return time.time()

    @staticmethod
    def now() -> datetime:
        """Get current datetime"""
        return datetime.now()

    @staticmethod
    def format_timestamp(ts: float, fmt: str = "%Y-%m-%d %H:%M:%S") -> str:
        """Format timestamp to string"""
        return datetime.fromtimestamp(ts).strftime(fmt)

    @staticmethod
    def parse_timestamp(s: str, fmt: str = "%Y-%m-%d %H:%M:%S") -> datetime:
        """Parse timestamp string"""
        return datetime.strptime(s, fmt)

    @staticmethod
    def elapsed_since(start: float) -> float:
        """Get seconds elapsed since start time"""
        return time.time() - start

    @staticmethod
    @contextmanager
    def timer(name: str = "Operation"):
        """Context manager for timing operations"""
        start = time.time()
        yield
        elapsed = time.time() - start
        print(f"{name} took {Utils.format_duration(elapsed)}")


def retry(max_attempts: int = 3, delay: float = 1.0,
          exceptions: Tuple = (Exception,)):
    """Decorator for retrying failed operations"""
    def decorator(func):
        @wraps(func)
        def wrapper(*args, **kwargs):
            last_exception = None
            for attempt in range(max_attempts):
                try:
                    return func(*args, **kwargs)
                except exceptions as e:
                    last_exception = e
                    if attempt < max_attempts - 1:
                        time.sleep(delay * (attempt + 1))
            raise last_exception
        return wrapper
    return decorator


def memoize(ttl_seconds: int = 300):
    """Decorator for caching function results with TTL"""
    cache = {}
    lock = threading.Lock()

    def decorator(func):
        @wraps(func)
        def wrapper(*args, **kwargs):
            key = (args, tuple(sorted(kwargs.items())))

            with lock:
                if key in cache:
                    result, timestamp = cache[key]
                    if time.time() - timestamp < ttl_seconds:
                        return result

                result = func(*args, **kwargs)
                cache[key] = (result, time.time())
                return result

        wrapper.cache_clear = lambda: cache.clear()
        return wrapper
    return decorator


def run_elevated(command: List[str], wait: bool = True) -> Tuple[int, str, str]:
    """Run command with elevated privileges"""
    if os.name == 'nt':
        import ctypes

        if not Utils.is_admin():
            ctypes.windll.shell32.ShellExecuteW(
                None, "runas", command[0], ' '.join(command[1:]), None, 1
            )
            return 0, "", ""

    result = subprocess.run(command, capture_output=True, text=True)
    return result.returncode, result.stdout, result.stderr


def kill_process(pid: int = None, name: str = None, force: bool = True) -> bool:
    """Kill process by PID or name"""
    try:
        if os.name == 'nt':
            if pid:
                cmd = f'taskkill {"/" if force else ""} /PID {pid}'
            elif name:
                cmd = f'taskkill {"/F" if force else ""} /IM {name}'
            else:
                return False

            result = subprocess.run(cmd, shell=True, capture_output=True)
            return result.returncode == 0
        else:
            import signal
            if pid:
                os.kill(pid, signal.SIGKILL if force else signal.SIGTERM)
                return True
    except:
        pass
    return False

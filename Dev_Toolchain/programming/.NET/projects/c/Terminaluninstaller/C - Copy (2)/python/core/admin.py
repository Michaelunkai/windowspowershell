"""
Administrator privilege management for Ultimate Uninstaller
Handles elevation, privilege tokens, and secure operations
"""

import os
import sys
import ctypes
import subprocess
from typing import Optional, Tuple, List, Callable
from enum import Enum, auto
from dataclasses import dataclass
from functools import wraps
import platform


class PrivilegeLevel(Enum):
    """Privilege levels"""
    USER = auto()
    ELEVATED = auto()
    SYSTEM = auto()
    TRUSTEDINSTALLER = auto()


@dataclass
class ProcessToken:
    """Process security token info"""
    pid: int
    elevated: bool
    integrity_level: str
    privileges: List[str]
    sid: str


class AdminHelper:
    """Helper class for administrator operations"""

    SE_PRIVILEGE_ENABLED = 0x00000002
    TOKEN_ADJUST_PRIVILEGES = 0x0020
    TOKEN_QUERY = 0x0008

    KNOWN_PRIVILEGES = [
        "SeDebugPrivilege",
        "SeBackupPrivilege",
        "SeRestorePrivilege",
        "SeTakeOwnershipPrivilege",
        "SeSecurityPrivilege",
        "SeLoadDriverPrivilege",
        "SeSystemtimePrivilege",
        "SeShutdownPrivilege",
        "SeRemoteShutdownPrivilege",
        "SeUndockPrivilege",
        "SeManageVolumePrivilege",
        "SeImpersonatePrivilege",
        "SeCreateGlobalPrivilege",
        "SeTcbPrivilege",
        "SeAssignPrimaryTokenPrivilege",
        "SeIncreaseQuotaPrivilege",
        "SeChangeNotifyPrivilege",
    ]

    @staticmethod
    def is_admin() -> bool:
        """Check if current process has admin privileges"""
        try:
            if os.name == 'nt':
                return bool(ctypes.windll.shell32.IsUserAnAdmin())
            else:
                return os.getuid() == 0
        except:
            return False

    @staticmethod
    def get_elevation_status() -> Tuple[bool, str]:
        """Get detailed elevation status"""
        if os.name != 'nt':
            is_root = os.getuid() == 0
            return is_root, "root" if is_root else "user"

        try:
            is_admin = bool(ctypes.windll.shell32.IsUserAnAdmin())

            if is_admin:
                token = AdminHelper._get_process_token()
                if token:
                    elevation_type = AdminHelper._get_elevation_type(token)
                    ctypes.windll.kernel32.CloseHandle(token)
                    return True, elevation_type
                return True, "elevated"
            return False, "standard"
        except:
            return False, "unknown"

    @staticmethod
    def _get_process_token() -> Optional[int]:
        """Get current process token"""
        if os.name != 'nt':
            return None

        TOKEN_QUERY = 0x0008
        handle = ctypes.c_void_p()

        result = ctypes.windll.advapi32.OpenProcessToken(
            ctypes.windll.kernel32.GetCurrentProcess(),
            TOKEN_QUERY,
            ctypes.byref(handle)
        )

        return handle.value if result else None

    @staticmethod
    def _get_elevation_type(token: int) -> str:
        """Get token elevation type"""
        if os.name != 'nt':
            return "unknown"

        TOKEN_ELEVATION_TYPE = 18

        class TOKEN_ELEVATION_TYPE_ENUM(ctypes.c_int):
            TokenElevationTypeDefault = 1
            TokenElevationTypeFull = 2
            TokenElevationTypeLimited = 3

        elevation_type = TOKEN_ELEVATION_TYPE_ENUM()
        returned_length = ctypes.c_ulong()

        ctypes.windll.advapi32.GetTokenInformation(
            token,
            TOKEN_ELEVATION_TYPE,
            ctypes.byref(elevation_type),
            ctypes.sizeof(elevation_type),
            ctypes.byref(returned_length)
        )

        types = {
            1: "default",
            2: "full",
            3: "limited"
        }

        return types.get(elevation_type.value, "unknown")

    @staticmethod
    def run_as_admin(command: List[str] = None,
                     script: str = None,
                     wait: bool = True) -> Tuple[bool, int]:
        """Run command or script with admin privileges"""
        if os.name != 'nt':
            if AdminHelper.is_admin():
                if command:
                    result = subprocess.run(command, capture_output=True)
                    return True, result.returncode
                return True, 0

            if command:
                sudo_cmd = ['sudo'] + command
                result = subprocess.run(sudo_cmd, capture_output=True)
                return result.returncode == 0, result.returncode
            return False, 1

        try:
            if command:
                cmd_str = ' '.join(f'"{c}"' if ' ' in c else c for c in command)
            elif script:
                cmd_str = f'"{script}"'
            else:
                cmd_str = f'"{sys.executable}" "{sys.argv[0]}"'

            shell_params = ctypes.c_int(1 if wait else 0)

            result = ctypes.windll.shell32.ShellExecuteW(
                None,
                "runas",
                sys.executable if not command else command[0],
                cmd_str if command else f'"{script or sys.argv[0]}"',
                None,
                shell_params
            )

            return result > 32, result
        except Exception as e:
            return False, -1

    @staticmethod
    def enable_privilege(privilege_name: str) -> bool:
        """Enable a specific privilege for current process"""
        if os.name != 'nt':
            return True

        try:
            class LUID(ctypes.Structure):
                _fields_ = [
                    ("LowPart", ctypes.c_ulong),
                    ("HighPart", ctypes.c_long),
                ]

            class LUID_AND_ATTRIBUTES(ctypes.Structure):
                _fields_ = [
                    ("Luid", LUID),
                    ("Attributes", ctypes.c_ulong),
                ]

            class TOKEN_PRIVILEGES(ctypes.Structure):
                _fields_ = [
                    ("PrivilegeCount", ctypes.c_ulong),
                    ("Privileges", LUID_AND_ATTRIBUTES * 1),
                ]

            handle = ctypes.c_void_p()
            TOKEN_ADJUST_PRIVILEGES = 0x0020
            TOKEN_QUERY = 0x0008

            if not ctypes.windll.advapi32.OpenProcessToken(
                ctypes.windll.kernel32.GetCurrentProcess(),
                TOKEN_ADJUST_PRIVILEGES | TOKEN_QUERY,
                ctypes.byref(handle)
            ):
                return False

            luid = LUID()
            if not ctypes.windll.advapi32.LookupPrivilegeValueW(
                None,
                privilege_name,
                ctypes.byref(luid)
            ):
                ctypes.windll.kernel32.CloseHandle(handle)
                return False

            tp = TOKEN_PRIVILEGES()
            tp.PrivilegeCount = 1
            tp.Privileges[0].Luid = luid
            tp.Privileges[0].Attributes = AdminHelper.SE_PRIVILEGE_ENABLED

            result = ctypes.windll.advapi32.AdjustTokenPrivileges(
                handle,
                False,
                ctypes.byref(tp),
                ctypes.sizeof(tp),
                None,
                None
            )

            ctypes.windll.kernel32.CloseHandle(handle)
            return bool(result)

        except Exception:
            return False

    @staticmethod
    def enable_all_privileges() -> List[str]:
        """Enable all available privileges"""
        enabled = []

        for priv in AdminHelper.KNOWN_PRIVILEGES:
            if AdminHelper.enable_privilege(priv):
                enabled.append(priv)

        return enabled

    @staticmethod
    def get_integrity_level() -> str:
        """Get current process integrity level"""
        if os.name != 'nt':
            return "root" if os.getuid() == 0 else "user"

        try:
            TOKEN_INTEGRITY_LEVEL = 25

            handle = AdminHelper._get_process_token()
            if not handle:
                return "unknown"

            info_size = ctypes.c_ulong()
            ctypes.windll.advapi32.GetTokenInformation(
                handle,
                TOKEN_INTEGRITY_LEVEL,
                None,
                0,
                ctypes.byref(info_size)
            )

            buffer = ctypes.create_string_buffer(info_size.value)
            ctypes.windll.advapi32.GetTokenInformation(
                handle,
                TOKEN_INTEGRITY_LEVEL,
                buffer,
                info_size,
                ctypes.byref(info_size)
            )

            ctypes.windll.kernel32.CloseHandle(handle)

            integrity_levels = {
                0x0000: "Untrusted",
                0x1000: "Low",
                0x2000: "Medium",
                0x2100: "Medium Plus",
                0x3000: "High",
                0x4000: "System",
                0x5000: "Protected",
            }

            sid_ptr = ctypes.cast(buffer, ctypes.POINTER(ctypes.c_void_p))
            sub_auth_count = ctypes.windll.advapi32.GetSidSubAuthorityCount(sid_ptr[0])

            if sub_auth_count:
                rid = ctypes.windll.advapi32.GetSidSubAuthority(
                    sid_ptr[0],
                    sub_auth_count.contents.value - 1
                )
                rid_value = rid.contents.value

                for level, name in sorted(integrity_levels.items()):
                    if rid_value >= level:
                        result = name
                return result

            return "unknown"
        except:
            return "unknown"


class PrivilegeManager:
    """Manages process privileges and security tokens"""

    def __init__(self):
        self.is_admin = AdminHelper.is_admin()
        self.elevation_status = AdminHelper.get_elevation_status()
        self.integrity_level = AdminHelper.get_integrity_level()
        self._enabled_privileges: List[str] = []

    def ensure_admin(self, required: bool = True) -> bool:
        """Ensure admin privileges, elevating if needed"""
        if self.is_admin:
            return True

        if required:
            success, _ = AdminHelper.run_as_admin()
            if success:
                sys.exit(0)
            return False

        return False

    def enable_privileges(self, privileges: List[str] = None) -> List[str]:
        """Enable specified or all privileges"""
        if not self.is_admin:
            return []

        if privileges:
            for priv in privileges:
                if AdminHelper.enable_privilege(priv):
                    self._enabled_privileges.append(priv)
        else:
            self._enabled_privileges = AdminHelper.enable_all_privileges()

        return self._enabled_privileges

    def has_privilege(self, privilege: str) -> bool:
        """Check if privilege is enabled"""
        return privilege in self._enabled_privileges

    def get_status(self) -> dict:
        """Get current privilege status"""
        return {
            'is_admin': self.is_admin,
            'elevation_status': self.elevation_status,
            'integrity_level': self.integrity_level,
            'enabled_privileges': self._enabled_privileges,
            'platform': platform.system(),
        }


def require_admin(func: Callable) -> Callable:
    """Decorator requiring admin privileges"""
    @wraps(func)
    def wrapper(*args, **kwargs):
        if not AdminHelper.is_admin():
            raise PermissionError("Administrator privileges required")
        return func(*args, **kwargs)
    return wrapper


def try_elevate(func: Callable) -> Callable:
    """Decorator that tries to elevate if not admin"""
    @wraps(func)
    def wrapper(*args, **kwargs):
        if not AdminHelper.is_admin():
            AdminHelper.run_as_admin()
            sys.exit(0)
        return func(*args, **kwargs)
    return wrapper


def with_privilege(privilege: str) -> Callable:
    """Decorator that enables specific privilege"""
    def decorator(func: Callable) -> Callable:
        @wraps(func)
        def wrapper(*args, **kwargs):
            AdminHelper.enable_privilege(privilege)
            return func(*args, **kwargs)
        return wrapper
    return decorator

"""
Filesystem path definitions for Ultimate Uninstaller
Comprehensive collection of file paths for scanning
"""

import os
from pathlib import Path
from typing import List, Dict, Set
from dataclasses import dataclass


@dataclass
class ScanPath:
    """Filesystem scan path definition"""
    path: str
    description: str = ""
    recursive: bool = True
    max_depth: int = 10
    include_patterns: List[str] = None
    exclude_patterns: List[str] = None

    def __post_init__(self):
        self.include_patterns = self.include_patterns or []
        self.exclude_patterns = self.exclude_patterns or []


class CommonPaths:
    """Common filesystem paths"""

    PROGRAM_FILES = os.environ.get('PROGRAMFILES', r'C:\Program Files')
    PROGRAM_FILES_X86 = os.environ.get('PROGRAMFILES(X86)', r'C:\Program Files (x86)')
    PROGRAMDATA = os.environ.get('PROGRAMDATA', r'C:\ProgramData')
    SYSTEMROOT = os.environ.get('SYSTEMROOT', r'C:\Windows')
    SYSTEMDRIVE = os.environ.get('SYSTEMDRIVE', 'C:')
    USERPROFILE = os.environ.get('USERPROFILE', os.path.expanduser('~'))

    @classmethod
    def get_all_program_paths(cls) -> List[str]:
        """Get all program installation paths"""
        return [
            cls.PROGRAM_FILES,
            cls.PROGRAM_FILES_X86,
            cls.PROGRAMDATA,
        ]

    @classmethod
    def get_user_paths(cls) -> List[str]:
        """Get all user profile paths"""
        return [
            cls.USERPROFILE,
            os.path.join(cls.USERPROFILE, 'Desktop'),
            os.path.join(cls.USERPROFILE, 'Documents'),
            os.path.join(cls.USERPROFILE, 'Downloads'),
        ]


class AppDataPaths:
    """Application data paths"""

    APPDATA = os.environ.get('APPDATA', '')
    LOCALAPPDATA = os.environ.get('LOCALAPPDATA', '')

    @classmethod
    def get_roaming_path(cls, app_name: str = None) -> str:
        """Get roaming appdata path"""
        base = cls.APPDATA
        return os.path.join(base, app_name) if app_name else base

    @classmethod
    def get_local_path(cls, app_name: str = None) -> str:
        """Get local appdata path"""
        base = cls.LOCALAPPDATA
        return os.path.join(base, app_name) if app_name else base

    @classmethod
    def get_local_low_path(cls, app_name: str = None) -> str:
        """Get LocalLow appdata path"""
        base = os.path.join(os.path.dirname(cls.LOCALAPPDATA), 'LocalLow')
        return os.path.join(base, app_name) if app_name else base

    @classmethod
    def get_all_appdata_paths(cls) -> List[str]:
        """Get all appdata paths"""
        return [
            cls.APPDATA,
            cls.LOCALAPPDATA,
            cls.get_local_low_path(),
        ]

    COMMON_APP_FOLDERS = [
        'Logs', 'Cache', 'Temp', 'Data', 'Config',
        'Settings', 'Preferences', 'User Data',
    ]

    @classmethod
    def get_app_scan_paths(cls, app_name: str) -> List[ScanPath]:
        """Get scan paths for specific app"""
        paths = []

        for base in cls.get_all_appdata_paths():
            app_path = os.path.join(base, app_name)
            if os.path.exists(app_path):
                paths.append(ScanPath(
                    path=app_path,
                    description=f"AppData path for {app_name}"
                ))

        return paths


class TempPaths:
    """Temporary file paths"""

    TEMP = os.environ.get('TEMP', '')
    TMP = os.environ.get('TMP', '')
    WINDOWS_TEMP = os.path.join(CommonPaths.SYSTEMROOT, 'Temp')

    TEMP_PATTERNS = ['*.tmp', '*.temp', '~*', '*.bak', '*.old']

    @classmethod
    def get_all_temp_paths(cls) -> List[str]:
        """Get all temp paths"""
        paths = [cls.TEMP, cls.TMP, cls.WINDOWS_TEMP]
        return [p for p in paths if p and os.path.exists(p)]

    @classmethod
    def get_temp_scan_paths(cls) -> List[ScanPath]:
        """Get scan paths for temp files"""
        paths = []

        for temp_path in cls.get_all_temp_paths():
            paths.append(ScanPath(
                path=temp_path,
                description="Temporary files",
                include_patterns=cls.TEMP_PATTERNS
            ))

        return paths


class CachePaths:
    """Cache file paths"""

    @classmethod
    def get_windows_cache_paths(cls) -> List[str]:
        """Get Windows cache paths"""
        return [
            os.path.join(CommonPaths.SYSTEMROOT, 'Prefetch'),
            os.path.join(CommonPaths.SYSTEMROOT, 'SoftwareDistribution', 'Download'),
            os.path.join(CommonPaths.LOCALAPPDATA, 'Microsoft', 'Windows', 'INetCache'),
            os.path.join(CommonPaths.LOCALAPPDATA, 'Microsoft', 'Windows', 'Explorer'),
        ]

    @classmethod
    def get_browser_cache_paths(cls) -> List[str]:
        """Get browser cache paths"""
        local = AppDataPaths.LOCALAPPDATA
        roaming = AppDataPaths.APPDATA

        return [
            os.path.join(local, 'Google', 'Chrome', 'User Data', 'Default', 'Cache'),
            os.path.join(local, 'Microsoft', 'Edge', 'User Data', 'Default', 'Cache'),
            os.path.join(local, 'Mozilla', 'Firefox', 'Profiles'),
            os.path.join(roaming, 'Opera Software', 'Opera Stable', 'Cache'),
            os.path.join(local, 'BraveSoftware', 'Brave-Browser', 'User Data', 'Default', 'Cache'),
        ]


class LogPaths:
    """Log file paths"""

    WINDOWS_LOGS = [
        os.path.join(CommonPaths.SYSTEMROOT, 'Logs'),
        os.path.join(CommonPaths.SYSTEMROOT, 'Debug'),
        os.path.join(CommonPaths.SYSTEMROOT, 'System32', 'LogFiles'),
    ]

    LOG_PATTERNS = ['*.log', '*.etl', '*.evtx']

    @classmethod
    def get_all_log_paths(cls) -> List[str]:
        """Get all log paths"""
        paths = list(cls.WINDOWS_LOGS)
        paths.append(os.path.join(CommonPaths.PROGRAMDATA, 'Microsoft', 'Windows', 'WER'))
        return [p for p in paths if os.path.exists(p)]


class StartupPaths:
    """Startup folder paths"""

    @classmethod
    def get_user_startup(cls) -> str:
        """Get user startup folder"""
        return os.path.join(
            AppDataPaths.APPDATA,
            'Microsoft', 'Windows', 'Start Menu', 'Programs', 'Startup'
        )

    @classmethod
    def get_common_startup(cls) -> str:
        """Get common startup folder"""
        return os.path.join(
            CommonPaths.PROGRAMDATA,
            'Microsoft', 'Windows', 'Start Menu', 'Programs', 'Startup'
        )

    @classmethod
    def get_all_startup_paths(cls) -> List[str]:
        """Get all startup paths"""
        return [cls.get_user_startup(), cls.get_common_startup()]


class DriverPaths:
    """Driver file paths"""

    DRIVERS = os.path.join(CommonPaths.SYSTEMROOT, 'System32', 'drivers')
    DRIVER_STORE = os.path.join(CommonPaths.SYSTEMROOT, 'System32', 'DriverStore')
    INF = os.path.join(CommonPaths.SYSTEMROOT, 'INF')

    @classmethod
    def get_all_driver_paths(cls) -> List[str]:
        """Get all driver paths"""
        return [cls.DRIVERS, cls.DRIVER_STORE, cls.INF]


class FontPaths:
    """Font file paths"""

    SYSTEM_FONTS = os.path.join(CommonPaths.SYSTEMROOT, 'Fonts')
    USER_FONTS = os.path.join(AppDataPaths.LOCALAPPDATA, 'Microsoft', 'Windows', 'Fonts')

    @classmethod
    def get_all_font_paths(cls) -> List[str]:
        """Get all font paths"""
        return [cls.SYSTEM_FONTS, cls.USER_FONTS]


class ShortcutPaths:
    """Shortcut/link file paths"""

    @classmethod
    def get_desktop_paths(cls) -> List[str]:
        """Get desktop paths"""
        return [
            os.path.join(CommonPaths.USERPROFILE, 'Desktop'),
            os.path.join(CommonPaths.PROGRAMDATA, 'Desktop'),
        ]

    @classmethod
    def get_start_menu_paths(cls) -> List[str]:
        """Get start menu paths"""
        return [
            os.path.join(AppDataPaths.APPDATA, 'Microsoft', 'Windows', 'Start Menu'),
            os.path.join(CommonPaths.PROGRAMDATA, 'Microsoft', 'Windows', 'Start Menu'),
        ]

    @classmethod
    def get_recent_paths(cls) -> List[str]:
        """Get recent files paths"""
        return [
            os.path.join(AppDataPaths.APPDATA, 'Microsoft', 'Windows', 'Recent'),
        ]


class AllPaths:
    """Aggregator for all path collections"""

    @classmethod
    def get_all_scan_locations(cls) -> Dict[str, List[str]]:
        """Get all scan locations organized by category"""
        return {
            'programs': CommonPaths.get_all_program_paths(),
            'appdata': AppDataPaths.get_all_appdata_paths(),
            'temp': TempPaths.get_all_temp_paths(),
            'cache': CachePaths.get_windows_cache_paths(),
            'browser_cache': CachePaths.get_browser_cache_paths(),
            'logs': LogPaths.get_all_log_paths(),
            'startup': StartupPaths.get_all_startup_paths(),
            'drivers': DriverPaths.get_all_driver_paths(),
            'shortcuts': ShortcutPaths.get_start_menu_paths(),
        }

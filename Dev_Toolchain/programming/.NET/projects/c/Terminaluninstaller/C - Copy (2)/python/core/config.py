"""
Configuration module for Ultimate Uninstaller
Defines all configuration constants and settings
"""

import os
import json
from enum import Enum, auto
from dataclasses import dataclass, field
from typing import Dict, List, Set, Optional
from pathlib import Path


class UninstallMode(Enum):
    """Uninstall operation modes"""
    SAFE = auto()
    NORMAL = auto()
    AGGRESSIVE = auto()
    NUCLEAR = auto()


class ScanDepth(Enum):
    """Scanning depth levels"""
    QUICK = 1
    STANDARD = 2
    DEEP = 3
    FORENSIC = 4


class CleanupType(Enum):
    """Types of cleanup operations"""
    REGISTRY = auto()
    FILES = auto()
    SERVICES = auto()
    DRIVERS = auto()
    STARTUP = auto()
    SCHEDULED_TASKS = auto()
    FIREWALL = auto()
    CERTIFICATES = auto()
    ENVIRONMENT = auto()
    BROWSER = auto()
    CACHE = auto()
    TEMP = auto()
    PREFETCH = auto()
    EVENTLOG = auto()
    NETWORK = auto()


@dataclass
class RegistryConfig:
    """Registry scanning configuration"""
    scan_hklm: bool = True
    scan_hkcu: bool = True
    scan_hkcr: bool = True
    scan_users: bool = True
    deep_scan: bool = True
    scan_values: bool = True
    scan_subkeys: bool = True
    max_depth: int = 50
    timeout_per_key: float = 0.5
    batch_size: int = 1000

    uninstall_paths: List[str] = field(default_factory=lambda: [
        r"SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
        r"SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall",
    ])

    software_paths: List[str] = field(default_factory=lambda: [
        r"SOFTWARE",
        r"SOFTWARE\WOW6432Node",
        r"SOFTWARE\Classes",
        r"SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths",
        r"SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FileExts",
        r"SOFTWARE\Microsoft\Windows\CurrentVersion\Shell Extensions",
    ])

    run_paths: List[str] = field(default_factory=lambda: [
        r"SOFTWARE\Microsoft\Windows\CurrentVersion\Run",
        r"SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce",
        r"SOFTWARE\Microsoft\Windows\CurrentVersion\RunServices",
        r"SOFTWARE\Microsoft\Windows\CurrentVersion\RunServicesOnce",
        r"SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer\Run",
        r"SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon",
    ])


@dataclass
class FileSystemConfig:
    """File system scanning configuration"""
    scan_program_files: bool = True
    scan_appdata: bool = True
    scan_programdata: bool = True
    scan_temp: bool = True
    scan_user_profile: bool = True
    scan_windows: bool = False
    scan_system32: bool = False
    follow_symlinks: bool = False
    max_file_size: int = 100 * 1024 * 1024
    max_depth: int = 30
    thread_count: int = 8
    batch_size: int = 500

    program_paths: List[str] = field(default_factory=lambda: [
        os.environ.get('ProgramFiles', r'C:\Program Files'),
        os.environ.get('ProgramFiles(x86)', r'C:\Program Files (x86)'),
        os.environ.get('ProgramW6432', r'C:\Program Files'),
    ])

    user_paths: List[str] = field(default_factory=lambda: [
        os.environ.get('APPDATA', ''),
        os.environ.get('LOCALAPPDATA', ''),
        os.environ.get('USERPROFILE', ''),
    ])

    system_paths: List[str] = field(default_factory=lambda: [
        os.environ.get('ProgramData', r'C:\ProgramData'),
        os.environ.get('TEMP', ''),
        os.environ.get('TMP', ''),
        r'C:\Windows\Temp',
        r'C:\Windows\Prefetch',
    ])

    exclude_patterns: List[str] = field(default_factory=lambda: [
        '*.sys', '*.dll', '*.exe',
        'Windows', 'System32', 'SysWOW64',
        '$Recycle.Bin', 'System Volume Information',
    ])


@dataclass
class ServiceConfig:
    """Service management configuration"""
    stop_timeout: int = 30
    kill_timeout: int = 10
    retry_count: int = 3
    parallel_stops: int = 4
    scan_drivers: bool = True
    scan_kernel: bool = False
    force_stop: bool = True


@dataclass
class NetworkConfig:
    """Network cleanup configuration"""
    clean_dns_cache: bool = True
    clean_arp_cache: bool = True
    clean_netbios: bool = True
    clean_winsock: bool = False
    clean_firewall: bool = True
    clean_hosts: bool = False
    timeout: int = 30


@dataclass
class BrowserConfig:
    """Browser cleanup configuration"""
    clean_chrome: bool = True
    clean_firefox: bool = True
    clean_edge: bool = True
    clean_opera: bool = True
    clean_brave: bool = True
    clean_extensions: bool = True
    clean_cache: bool = True
    clean_cookies: bool = False
    clean_history: bool = False
    clean_passwords: bool = False


@dataclass
class CacheConfig:
    """Cache configuration"""
    enabled: bool = True
    max_size_mb: int = 500
    ttl_seconds: int = 3600
    persist_to_disk: bool = True
    cache_dir: str = ""
    compression: bool = True


@dataclass
class Config:
    """Main configuration class"""
    mode: UninstallMode = UninstallMode.AGGRESSIVE
    depth: ScanDepth = ScanDepth.DEEP
    parallel: bool = True
    max_workers: int = 8
    timeout: int = 300
    dry_run: bool = False
    create_backup: bool = True
    backup_dir: str = ""
    log_dir: str = ""
    verbose: bool = True

    registry: RegistryConfig = field(default_factory=RegistryConfig)
    filesystem: FileSystemConfig = field(default_factory=FileSystemConfig)
    services: ServiceConfig = field(default_factory=ServiceConfig)
    network: NetworkConfig = field(default_factory=NetworkConfig)
    browser: BrowserConfig = field(default_factory=BrowserConfig)
    cache: CacheConfig = field(default_factory=CacheConfig)

    cleanup_types: Set[CleanupType] = field(default_factory=lambda: {
        CleanupType.REGISTRY,
        CleanupType.FILES,
        CleanupType.SERVICES,
        CleanupType.STARTUP,
        CleanupType.SCHEDULED_TASKS,
        CleanupType.CACHE,
        CleanupType.TEMP,
        CleanupType.BROWSER,
    })

    def __post_init__(self):
        if not self.backup_dir:
            self.backup_dir = str(Path.home() / ".uninstaller_backup")
        if not self.log_dir:
            self.log_dir = str(Path.home() / ".uninstaller_logs")
        if not self.cache.cache_dir:
            self.cache.cache_dir = str(Path.home() / ".uninstaller_cache")

    @classmethod
    def from_file(cls, path: str) -> 'Config':
        """Load configuration from JSON file"""
        with open(path, 'r') as f:
            data = json.load(f)
        return cls._from_dict(data)

    @classmethod
    def _from_dict(cls, data: Dict) -> 'Config':
        """Create config from dictionary"""
        config = cls()
        for key, value in data.items():
            if hasattr(config, key):
                setattr(config, key, value)
        return config

    def to_file(self, path: str):
        """Save configuration to JSON file"""
        with open(path, 'w') as f:
            json.dump(self._to_dict(), f, indent=2, default=str)

    def _to_dict(self) -> Dict:
        """Convert config to dictionary"""
        result = {}
        for key in dir(self):
            if not key.startswith('_') and not callable(getattr(self, key)):
                value = getattr(self, key)
                if isinstance(value, Enum):
                    result[key] = value.name
                elif hasattr(value, '__dataclass_fields__'):
                    result[key] = {k: getattr(value, k) for k in value.__dataclass_fields__}
                else:
                    result[key] = value
        return result


KNOWN_APPS_SIGNATURES = {
    'adobe': ['adobe', 'acrobat', 'photoshop', 'illustrator', 'premiere'],
    'microsoft': ['microsoft', 'office', 'visual studio', 'vscode', 'teams'],
    'google': ['google', 'chrome', 'drive', 'earth'],
    'mozilla': ['mozilla', 'firefox', 'thunderbird'],
    'nvidia': ['nvidia', 'geforce', 'physx', 'cuda'],
    'amd': ['amd', 'radeon', 'catalyst', 'ryzen'],
    'intel': ['intel', 'graphics', 'driver'],
    'java': ['java', 'jdk', 'jre', 'oracle'],
    'python': ['python', 'anaconda', 'miniconda'],
    'node': ['node', 'nodejs', 'npm'],
    'steam': ['steam', 'valve'],
    'epic': ['epic', 'unreal', 'fortnite'],
    'discord': ['discord'],
    'slack': ['slack'],
    'zoom': ['zoom'],
    'spotify': ['spotify'],
    'vlc': ['vlc', 'videolan'],
    '7zip': ['7-zip', '7zip'],
    'winrar': ['winrar', 'rarlab'],
}

SYSTEM_PROTECTED_PATHS = [
    r'C:\Windows',
    r'C:\Windows\System32',
    r'C:\Windows\SysWOW64',
    r'C:\Windows\WinSxS',
    r'C:\Program Files\Windows',
    r'C:\Program Files (x86)\Windows',
]

REGISTRY_PROTECTED_KEYS = [
    r'HKLM\SYSTEM',
    r'HKLM\SECURITY',
    r'HKLM\SAM',
    r'HKLM\SOFTWARE\Microsoft\Windows NT',
    r'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing',
]

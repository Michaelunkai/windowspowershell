"""
Registry module for Ultimate Uninstaller
Provides deep Windows registry scanning and cleaning
"""

from .scanner import RegistryScanner, RegistryKey, RegistryValue
from .cleaner import RegistryCleaner, RegistryBackup
from .paths import RegistryPaths, UninstallPaths, RunPaths
from .analyzer import RegistryAnalyzer, RegistryPattern
from .operations import RegistryOperations

__all__ = [
    'RegistryScanner', 'RegistryKey', 'RegistryValue',
    'RegistryCleaner', 'RegistryBackup',
    'RegistryPaths', 'UninstallPaths', 'RunPaths',
    'RegistryAnalyzer', 'RegistryPattern',
    'RegistryOperations',
]

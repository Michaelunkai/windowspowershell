"""
Filesystem module for Ultimate Uninstaller
Deep scanning and cleaning of file system traces
"""

from .scanner import FileSystemScanner, FileInfo, DirectoryInfo
from .cleaner import FileSystemCleaner, FileBackup
from .paths import CommonPaths, AppDataPaths, TempPaths
from .analyzer import FileAnalyzer, FilePattern
from .operations import FileOperations, SecureDelete

__all__ = [
    'FileSystemScanner',
    'FileInfo',
    'DirectoryInfo',
    'FileSystemCleaner',
    'FileBackup',
    'CommonPaths',
    'AppDataPaths',
    'TempPaths',
    'FileAnalyzer',
    'FilePattern',
    'FileOperations',
    'SecureDelete',
]

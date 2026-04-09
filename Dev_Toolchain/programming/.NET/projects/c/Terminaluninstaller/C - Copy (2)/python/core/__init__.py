"""
Core module for Ultimate Uninstaller
Contains configuration, logging, utilities, and base classes
"""

from .config import Config, UninstallMode, ScanDepth
from .logger import Logger, LogLevel
from .utils import Utils, PathHelper, TimeHelper
from .parallel import ParallelExecutor, TaskQueue, WorkerPool
from .admin import AdminHelper, PrivilegeManager
from .cache import Cache, CacheManager, CachePolicy
from .base import BaseScanner, BaseCleaner, BaseModule
from .exceptions import (
    UninstallerError, RegistryError, FileSystemError,
    ServiceError, PermissionError, NetworkError
)

__all__ = [
    'Config', 'UninstallMode', 'ScanDepth',
    'Logger', 'LogLevel',
    'Utils', 'PathHelper', 'TimeHelper',
    'ParallelExecutor', 'TaskQueue', 'WorkerPool',
    'AdminHelper', 'PrivilegeManager',
    'Cache', 'CacheManager', 'CachePolicy',
    'BaseScanner', 'BaseCleaner', 'BaseModule',
    'UninstallerError', 'RegistryError', 'FileSystemError',
    'ServiceError', 'PermissionError', 'NetworkError'
]

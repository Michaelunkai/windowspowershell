"""
Cleaners module for Ultimate Uninstaller
System cache and temp file cleanup utilities
"""

from .cache import CacheCleaner
from .temp import TempCleaner
from .prefetch import PrefetchCleaner
from .logs import LogCleaner
from .thumbnails import ThumbnailCleaner

__all__ = [
    'CacheCleaner',
    'TempCleaner',
    'PrefetchCleaner',
    'LogCleaner',
    'ThumbnailCleaner',
]

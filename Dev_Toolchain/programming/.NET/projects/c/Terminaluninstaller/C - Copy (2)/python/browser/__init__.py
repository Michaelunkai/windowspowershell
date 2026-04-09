"""
Browser module for Ultimate Uninstaller
Browser data cleanup for common browsers
"""

from .scanner import BrowserScanner
from .cleaner import BrowserCleaner
from .chrome import ChromeCleaner
from .firefox import FirefoxCleaner
from .edge import EdgeCleaner

__all__ = [
    'BrowserScanner',
    'BrowserCleaner',
    'ChromeCleaner',
    'FirefoxCleaner',
    'EdgeCleaner',
]

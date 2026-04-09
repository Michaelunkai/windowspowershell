"""
Apps module for Ultimate Uninstaller
Application-specific cleaners for common software
"""

from .base import AppCleaner, AppCleanerBase
from .adobe import AdobeCleaner
from .microsoft import MicrosoftCleaner
from .development import DevelopmentToolsCleaner

__all__ = [
    'AppCleaner',
    'AppCleanerBase',
    'AdobeCleaner',
    'MicrosoftCleaner',
    'DevelopmentToolsCleaner',
]

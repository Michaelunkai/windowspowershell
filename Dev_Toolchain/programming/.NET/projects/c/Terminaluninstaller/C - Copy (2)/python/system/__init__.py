"""
System module for Ultimate Uninstaller
Startup items and scheduled tasks management
"""

from .startup import StartupScanner, StartupItem, StartupCleaner
from .tasks import TaskScanner, ScheduledTask, TaskCleaner
from .processes import ProcessScanner, ProcessInfo, ProcessManager

__all__ = [
    'StartupScanner',
    'StartupItem',
    'StartupCleaner',
    'TaskScanner',
    'ScheduledTask',
    'TaskCleaner',
    'ProcessScanner',
    'ProcessInfo',
    'ProcessManager',
]

"""
Log cleaner for Ultimate Uninstaller
Cleans log files across the system
"""

import os
import shutil
from typing import List, Dict, Generator, Optional, Set
from dataclasses import dataclass, field
from datetime import datetime, timedelta
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from core.base import BaseCleaner, CleanResult, ScanResult
from core.config import Config
from core.logger import Logger


@dataclass
class LogLocation:
    """Log file location"""
    name: str
    path: str
    patterns: List[str] = field(default_factory=list)
    max_age_days: int = 30
    safe: bool = True


class LogCleaner(BaseCleaner):
    """Cleans log files"""

    LOG_EXTENSIONS = [
        '.log', '.log1', '.log2', '.log.1', '.log.2',
        '.etl', '.evtx', '.evt',
        '.dmp', '.mdmp', '.hdmp',
        '.trace', '.trc',
    ]

    def __init__(self, config: Config, logger: Logger = None):
        super().__init__(config, logger)
        self._locations = self._get_log_locations()
        self._cleaned_items: List[str] = []
        self._total_size_cleaned = 0
        self._files_deleted = 0

    def _get_log_locations(self) -> List[LogLocation]:
        """Get log file locations"""
        windir = os.environ.get('WINDIR', 'C:\\Windows')
        localappdata = os.environ.get('LOCALAPPDATA', '')
        programdata = os.environ.get('PROGRAMDATA', '')
        temp = os.environ.get('TEMP', '')

        return [
            LogLocation(
                name="Windows Logs",
                path=os.path.join(windir, 'Logs'),
                patterns=['*.log', '*.etl'],
                max_age_days=30,
                safe=True,
            ),
            LogLocation(
                name="CBS Logs",
                path=os.path.join(windir, 'Logs', 'CBS'),
                patterns=['*.log', '*.cab'],
                max_age_days=14,
                safe=True,
            ),
            LogLocation(
                name="DISM Logs",
                path=os.path.join(windir, 'Logs', 'DISM'),
                patterns=['*.log'],
                max_age_days=14,
                safe=True,
            ),
            LogLocation(
                name="Windows Update Logs",
                path=os.path.join(windir, 'SoftwareDistribution'),
                patterns=['*.log', '*.etl'],
                max_age_days=7,
                safe=True,
            ),
            LogLocation(
                name="Panther Logs",
                path=os.path.join(windir, 'Panther'),
                patterns=['*.log', '*.xml'],
                max_age_days=30,
                safe=True,
            ),
            LogLocation(
                name="INF Logs",
                path=os.path.join(windir, 'INF'),
                patterns=['*.log', 'setupapi*.log'],
                max_age_days=30,
                safe=True,
            ),
            LogLocation(
                name="WER Reports",
                path=os.path.join(localappdata, 'Microsoft', 'Windows', 'WER'),
                patterns=['*'],
                max_age_days=7,
                safe=True,
            ),
            LogLocation(
                name="System WER",
                path=os.path.join(programdata, 'Microsoft', 'Windows', 'WER'),
                patterns=['*'],
                max_age_days=7,
                safe=True,
            ),
            LogLocation(
                name="Memory Dumps",
                path=os.path.join(windir, 'Minidump'),
                patterns=['*.dmp'],
                max_age_days=14,
                safe=True,
            ),
            LogLocation(
                name="MEMORY.DMP",
                path=windir,
                patterns=['MEMORY.DMP'],
                max_age_days=0,
                safe=True,
            ),
            LogLocation(
                name="Debug Logs",
                path=os.path.join(windir, 'Debug'),
                patterns=['*.log'],
                max_age_days=14,
                safe=True,
            ),
            LogLocation(
                name="Performance Logs",
                path=os.path.join(windir, 'System32', 'LogFiles'),
                patterns=['*.etl', '*.log'],
                max_age_days=30,
                safe=False,
            ),
            LogLocation(
                name="Temp Logs",
                path=temp,
                patterns=['*.log', '*.etl'],
                max_age_days=7,
                safe=True,
            ),
            LogLocation(
                name="IIS Logs",
                path=os.path.join(windir, 'System32', 'LogFiles', 'W3SVC1'),
                patterns=['*.log'],
                max_age_days=30,
                safe=True,
            ),
        ]

    def scan(self) -> Generator[ScanResult, None, None]:
        """Scan for log files"""
        self.log_info("Scanning log files")

        for location in self._locations:
            if not location.safe and not self.config.force:
                continue

            if not os.path.exists(location.path):
                continue

            try:
                file_count, total_size = self._scan_location(location)

                if file_count > 0:
                    yield ScanResult(
                        module=self.name,
                        item_type="logs",
                        name=location.name,
                        path=location.path,
                        size=total_size,
                        details={
                            'file_count': file_count,
                            'patterns': location.patterns,
                            'max_age_days': location.max_age_days,
                            'safe': location.safe,
                        }
                    )
            except Exception as e:
                self.log_error(f"Failed to scan {location.path}: {e}")

    def _scan_location(self, location: LogLocation) -> tuple:
        """Scan a log location"""
        import fnmatch

        file_count = 0
        total_size = 0
        cutoff_date = datetime.now() - timedelta(days=location.max_age_days)

        try:
            if location.patterns == ['*']:
                for root, dirs, files in os.walk(location.path):
                    for f in files:
                        file_path = os.path.join(root, f)
                        try:
                            if location.max_age_days > 0:
                                mtime = datetime.fromtimestamp(os.path.getmtime(file_path))
                                if mtime > cutoff_date:
                                    continue

                            total_size += os.path.getsize(file_path)
                            file_count += 1
                        except:
                            pass
            else:
                for root, dirs, files in os.walk(location.path):
                    for f in files:
                        if any(fnmatch.fnmatch(f.lower(), p.lower())
                               for p in location.patterns):
                            file_path = os.path.join(root, f)
                            try:
                                if location.max_age_days > 0:
                                    mtime = datetime.fromtimestamp(os.path.getmtime(file_path))
                                    if mtime > cutoff_date:
                                        continue

                                total_size += os.path.getsize(file_path)
                                file_count += 1
                            except:
                                pass
        except:
            pass

        return file_count, total_size

    def clean(self, items: List[ScanResult] = None) -> Generator[CleanResult, None, None]:
        """Clean log files"""
        self.log_info("Cleaning log files")

        if items:
            for item in items:
                if self.is_cancelled():
                    break
                self.wait_if_paused()
                yield from self._clean_path(item.path, item.name,
                                           item.details.get('patterns', ['*']),
                                           item.details.get('max_age_days', 30))
        else:
            for location in self._locations:
                if self.is_cancelled():
                    break
                self.wait_if_paused()

                if not location.safe and not self.config.force:
                    continue

                yield from self._clean_location(location)

    def _clean_location(self, location: LogLocation) -> Generator[CleanResult, None, None]:
        """Clean a log location"""
        if not os.path.exists(location.path):
            return

        yield from self._clean_path(location.path, location.name,
                                    location.patterns, location.max_age_days)

    def _clean_path(self, path: str, name: str, patterns: List[str],
                   max_age_days: int) -> Generator[CleanResult, None, None]:
        """Clean log files in a path"""
        import fnmatch

        if not os.path.exists(path):
            return

        if self.config.dry_run:
            file_count, total_size = self._scan_location(LogLocation(
                name=name, path=path, patterns=patterns, max_age_days=max_age_days
            ))
            yield CleanResult(
                module=self.name,
                action="clean (dry run)",
                target=f"{name}: {path}",
                success=True,
                message=f"Would delete {file_count} files ({self._format_size(total_size)})"
            )
            return

        cutoff_date = datetime.now() - timedelta(days=max_age_days) if max_age_days > 0 else None
        cleaned_count = 0
        cleaned_size = 0

        try:
            if patterns == ['*']:
                for root, dirs, files in os.walk(path, topdown=False):
                    for f in files:
                        file_path = os.path.join(root, f)
                        try:
                            if cutoff_date:
                                mtime = datetime.fromtimestamp(os.path.getmtime(file_path))
                                if mtime > cutoff_date:
                                    continue

                            size = os.path.getsize(file_path)
                            os.remove(file_path)
                            cleaned_count += 1
                            cleaned_size += size
                        except:
                            pass

                    for d in dirs:
                        dir_path = os.path.join(root, d)
                        try:
                            if not os.listdir(dir_path):
                                os.rmdir(dir_path)
                        except:
                            pass
            else:
                for root, dirs, files in os.walk(path):
                    for f in files:
                        if any(fnmatch.fnmatch(f.lower(), p.lower()) for p in patterns):
                            file_path = os.path.join(root, f)
                            try:
                                if cutoff_date:
                                    mtime = datetime.fromtimestamp(os.path.getmtime(file_path))
                                    if mtime > cutoff_date:
                                        continue

                                size = os.path.getsize(file_path)
                                os.remove(file_path)
                                cleaned_count += 1
                                cleaned_size += size
                            except:
                                pass

            self._total_size_cleaned += cleaned_size
            self._files_deleted += cleaned_count

            yield CleanResult(
                module=self.name,
                action="clean",
                target=f"{name}: {path}",
                success=True,
                message=f"Deleted {cleaned_count} files ({self._format_size(cleaned_size)})"
            )
        except Exception as e:
            yield CleanResult(
                module=self.name,
                action="clean",
                target=f"{name}: {path}",
                success=False,
                message=str(e)
            )

    def clear_event_logs(self) -> Generator[CleanResult, None, None]:
        """Clear Windows Event Logs"""
        import subprocess

        if self.config.dry_run:
            yield CleanResult(
                module=self.name,
                action="clear (dry run)",
                target="Windows Event Logs",
                success=True,
                message="Would clear event logs"
            )
            return

        logs_to_clear = ['Application', 'System', 'Security', 'Setup']

        for log_name in logs_to_clear:
            try:
                result = subprocess.run(
                    ['wevtutil', 'cl', log_name],
                    capture_output=True, timeout=30
                )

                if result.returncode == 0:
                    yield CleanResult(
                        module=self.name,
                        action="clear",
                        target=f"Event Log: {log_name}",
                        success=True,
                        message="Cleared"
                    )
                else:
                    yield CleanResult(
                        module=self.name,
                        action="clear",
                        target=f"Event Log: {log_name}",
                        success=False,
                        message="Failed to clear"
                    )
            except Exception as e:
                yield CleanResult(
                    module=self.name,
                    action="clear",
                    target=f"Event Log: {log_name}",
                    success=False,
                    message=str(e)
                )

    def _format_size(self, size: int) -> str:
        """Format size for display"""
        for unit in ['B', 'KB', 'MB', 'GB']:
            if size < 1024:
                return f"{size:.1f} {unit}"
            size /= 1024
        return f"{size:.1f} TB"

    def get_cleaned_items(self) -> List[str]:
        return self._cleaned_items

    def get_total_size_cleaned(self) -> int:
        return self._total_size_cleaned

    def get_files_deleted(self) -> int:
        return self._files_deleted

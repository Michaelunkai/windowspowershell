"""
Scheduled task scanner and cleaner for Ultimate Uninstaller
Manages Windows Task Scheduler items
"""

import subprocess
import xml.etree.ElementTree as ET
import json
import os
from typing import List, Dict, Generator, Optional, Tuple, Any
from dataclasses import dataclass, field
from datetime import datetime
from pathlib import Path
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from core.base import BaseScanner, BaseCleaner, ScanResult, CleanResult
from core.config import Config, ScanDepth
from core.logger import Logger


@dataclass
class ScheduledTask:
    """Scheduled task information"""
    name: str
    path: str
    state: str
    next_run: str = ""
    last_run: str = ""
    last_result: int = 0
    author: str = ""
    description: str = ""
    command: str = ""
    arguments: str = ""
    triggers: List[str] = field(default_factory=list)


class TaskScanner(BaseScanner):
    """Scans Windows scheduled tasks"""

    PROTECTED_TASKS = {
        'microsoft', 'windows', 'defender', 'update', 'system',
    }

    def __init__(self, config: Config, logger: Logger = None):
        super().__init__(config, logger)
        self._found_tasks: Dict[str, ScheduledTask] = {}
        self._all_tasks: List[ScheduledTask] = []

    def scan(self, target: str = None, patterns: List[str] = None,
             depth: ScanDepth = None) -> Generator[ScanResult, None, None]:
        """Scan scheduled tasks for matching entries"""
        patterns = patterns or []

        if target:
            patterns.append(target.lower())

        self.log_info(f"Starting task scan for: {patterns}")
        self._stats.items_scanned = 0

        tasks = self._enumerate_tasks()

        for task in tasks:
            if self.is_cancelled():
                break

            self._stats.items_scanned += 1

            if self._matches_patterns(task, patterns):
                self._found_tasks[task.name] = task
                self._stats.items_found += 1

                yield ScanResult(
                    module=self.name,
                    item_type="scheduled_task",
                    path=task.path,
                    name=task.name,
                    details={
                        'state': task.state,
                        'command': task.command,
                        'arguments': task.arguments,
                        'author': task.author,
                        'next_run': task.next_run,
                        'is_protected': self._is_protected(task),
                    }
                )

        self.log_info(f"Task scan complete. Found {self._stats.items_found} tasks")

    def _enumerate_tasks(self) -> List[ScheduledTask]:
        """Enumerate all scheduled tasks"""
        tasks = []

        try:
            result = subprocess.run(
                ['schtasks', '/query', '/fo', 'csv', '/v'],
                capture_output=True, text=True, timeout=60,
                encoding='cp437', errors='replace'
            )

            if result.returncode == 0:
                import csv
                from io import StringIO

                lines = result.stdout.strip().split('\n')
                if len(lines) > 1:
                    reader = csv.DictReader(StringIO(result.stdout))
                    for row in reader:
                        task = self._parse_task_row(row)
                        if task:
                            tasks.append(task)

        except Exception as e:
            self.log_error(f"Failed to enumerate tasks: {e}")

        self._all_tasks = tasks
        return tasks

    def _parse_task_row(self, row: Dict[str, str]) -> Optional[ScheduledTask]:
        """Parse task from CSV row"""
        try:
            host_name_key = next((k for k in row.keys() if 'HostName' in k), None)
            task_name_key = next((k for k in row.keys() if 'TaskName' in k), None)
            status_key = next((k for k in row.keys() if 'Status' in k), None)

            name = row.get(task_name_key, row.get('TaskName', ''))
            if not name or name == 'TaskName':
                return None

            return ScheduledTask(
                name=name.split('\\')[-1] if '\\' in name else name,
                path=name,
                state=row.get(status_key, row.get('Status', 'Unknown')),
                next_run=row.get('Next Run Time', ''),
                last_run=row.get('Last Run Time', ''),
                author=row.get('Author', ''),
                command=row.get('Task To Run', ''),
            )
        except:
            return None

    def _matches_patterns(self, task: ScheduledTask, patterns: List[str]) -> bool:
        """Check if task matches patterns"""
        if not patterns:
            return False

        search_text = f"{task.name} {task.path} {task.command} {task.author}".lower()
        return any(p.lower() in search_text for p in patterns)

    def _is_protected(self, task: ScheduledTask) -> bool:
        """Check if task is protected"""
        path_lower = task.path.lower()
        return any(p in path_lower for p in self.PROTECTED_TASKS)

    def get_third_party_tasks(self) -> List[ScheduledTask]:
        """Get non-Microsoft tasks"""
        result = []

        for task in self._all_tasks:
            path_lower = task.path.lower()
            if not any(p in path_lower for p in ['microsoft', 'windows']):
                result.append(task)

        return result

    def get_task_xml(self, task_path: str) -> Optional[str]:
        """Get task XML definition"""
        try:
            result = subprocess.run(
                ['schtasks', '/query', '/xml', '/tn', task_path],
                capture_output=True, text=True, timeout=30
            )

            if result.returncode == 0:
                return result.stdout
        except:
            pass

        return None

    def get_found_tasks(self) -> Dict[str, ScheduledTask]:
        """Get found tasks"""
        return self._found_tasks

    def get_all_tasks(self) -> List[ScheduledTask]:
        """Get all tasks"""
        if not self._all_tasks:
            self._enumerate_tasks()
        return self._all_tasks


class TaskCleaner(BaseCleaner):
    """Cleaner for scheduled tasks"""

    PROTECTED_PATHS = ['\\Microsoft\\', '\\Windows\\']

    def __init__(self, config: Config, logger: Logger = None):
        super().__init__(config, logger)
        self._backup_file: Optional[Path] = None
        self._backup_entries: List[Dict] = []
        self._deleted_tasks: List[str] = []

    def clean(self, items: List[ScanResult]) -> Generator[CleanResult, None, None]:
        """Remove scheduled tasks from scan results"""
        if self.config.create_backup:
            self._start_backup()

        for item in items:
            if self.is_cancelled():
                break
            self.wait_if_paused()

            if item.item_type != "scheduled_task":
                continue

            yield self._clean_task(item)

        if self.config.create_backup:
            self._save_backup()

    def _start_backup(self):
        """Start backup session"""
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        backup_dir = Path(self.config.backup_dir)
        backup_dir.mkdir(parents=True, exist_ok=True)
        self._backup_file = backup_dir / f"tasks_backup_{timestamp}.json"
        self._backup_entries = []

    def _save_backup(self):
        """Save backup to file"""
        if self._backup_file and self._backup_entries:
            try:
                data = {
                    'version': '1.0',
                    'created': datetime.now().isoformat(),
                    'entries': self._backup_entries
                }
                with open(self._backup_file, 'w') as f:
                    json.dump(data, f, indent=2)
            except:
                pass

    def _clean_task(self, item: ScanResult) -> CleanResult:
        """Remove a scheduled task"""
        task_path = item.path
        details = item.details or {}

        if self._is_protected(task_path):
            return CleanResult(
                module=self.name,
                action="skip",
                target=item.name,
                success=False,
                message="Protected system task"
            )

        if self.config.create_backup:
            xml = self._get_task_xml(task_path)
            self._backup_entries.append({
                'name': item.name,
                'path': task_path,
                'xml': xml,
                'details': details,
            })

        if self.config.dry_run:
            return CleanResult(
                module=self.name,
                action="delete (dry run)",
                target=item.name,
                success=True,
                message="Would remove task"
            )

        success, message = self._remove_task(task_path)

        if success:
            self._deleted_tasks.append(item.name)

        return CleanResult(
            module=self.name,
            action="delete",
            target=item.name,
            success=success,
            message=message
        )

    def _is_protected(self, path: str) -> bool:
        """Check if task path is protected"""
        return any(p in path for p in self.PROTECTED_PATHS)

    def _get_task_xml(self, task_path: str) -> Optional[str]:
        """Get task XML for backup"""
        try:
            result = subprocess.run(
                ['schtasks', '/query', '/xml', '/tn', task_path],
                capture_output=True, text=True, timeout=30
            )
            if result.returncode == 0:
                return result.stdout
        except:
            pass
        return None

    def _remove_task(self, task_path: str) -> Tuple[bool, str]:
        """Remove a scheduled task"""
        try:
            result = subprocess.run(
                ['schtasks', '/delete', '/tn', task_path, '/f'],
                capture_output=True, text=True, timeout=30
            )

            if result.returncode == 0:
                return True, "Task removed"
            elif 'does not exist' in result.stderr.lower():
                return True, "Already removed"
            else:
                return False, result.stderr.strip()

        except subprocess.TimeoutExpired:
            return False, "Operation timed out"
        except Exception as e:
            return False, str(e)

    def disable_task(self, task_path: str) -> Tuple[bool, str]:
        """Disable a task instead of removing"""
        try:
            result = subprocess.run(
                ['schtasks', '/change', '/tn', task_path, '/disable'],
                capture_output=True, text=True, timeout=30
            )

            if result.returncode == 0:
                return True, "Task disabled"
            else:
                return False, result.stderr.strip()

        except Exception as e:
            return False, str(e)

    def restore_task(self, xml_content: str, task_path: str) -> Tuple[bool, str]:
        """Restore task from XML"""
        try:
            import tempfile
            with tempfile.NamedTemporaryFile(mode='w', suffix='.xml', delete=False) as f:
                f.write(xml_content)
                temp_file = f.name

            result = subprocess.run(
                ['schtasks', '/create', '/tn', task_path, '/xml', temp_file, '/f'],
                capture_output=True, text=True, timeout=30
            )

            os.unlink(temp_file)

            if result.returncode == 0:
                return True, "Task restored"
            else:
                return False, result.stderr.strip()

        except Exception as e:
            return False, str(e)

    def get_deleted_tasks(self) -> List[str]:
        """Get list of deleted tasks"""
        return self._deleted_tasks

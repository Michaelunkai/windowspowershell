"""
Process scanner and manager for Ultimate Uninstaller
Manages running processes
"""

import subprocess
import ctypes
import os
from typing import List, Dict, Generator, Optional, Tuple, Any
from dataclasses import dataclass
from concurrent.futures import ThreadPoolExecutor
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from core.base import BaseScanner, ScanResult
from core.config import Config, ScanDepth
from core.logger import Logger
from core.admin import AdminHelper


@dataclass
class ProcessInfo:
    """Process information"""
    pid: int
    name: str
    path: str = ""
    command_line: str = ""
    memory_usage: int = 0
    cpu_usage: float = 0.0
    user: str = ""
    parent_pid: int = 0


class ProcessScanner(BaseScanner):
    """Scans running processes"""

    PROTECTED_PROCESSES = {
        'system', 'smss.exe', 'csrss.exe', 'wininit.exe', 'services.exe',
        'lsass.exe', 'svchost.exe', 'winlogon.exe', 'dwm.exe', 'explorer.exe',
        'taskmgr.exe', 'conhost.exe', 'cmd.exe', 'powershell.exe', 'python.exe',
    }

    def __init__(self, config: Config, logger: Logger = None):
        super().__init__(config, logger)
        self._found_processes: Dict[int, ProcessInfo] = {}
        self._all_processes: List[ProcessInfo] = []

    def scan(self, target: str = None, patterns: List[str] = None,
             depth: ScanDepth = None) -> Generator[ScanResult, None, None]:
        """Scan processes for matching entries"""
        patterns = patterns or []

        if target:
            patterns.append(target.lower())

        self.log_info(f"Starting process scan for: {patterns}")
        self._stats.items_scanned = 0

        processes = self._enumerate_processes()

        for proc in processes:
            if self.is_cancelled():
                break

            self._stats.items_scanned += 1

            if self._matches_patterns(proc, patterns):
                self._found_processes[proc.pid] = proc
                self._stats.items_found += 1

                yield ScanResult(
                    module=self.name,
                    item_type="process",
                    path=proc.path,
                    name=proc.name,
                    details={
                        'pid': proc.pid,
                        'command_line': proc.command_line,
                        'memory_usage': proc.memory_usage,
                        'user': proc.user,
                        'is_protected': proc.name.lower() in self.PROTECTED_PROCESSES,
                    }
                )

        self.log_info(f"Process scan complete. Found {self._stats.items_found} processes")

    def _enumerate_processes(self) -> List[ProcessInfo]:
        """Enumerate all running processes"""
        processes = []

        try:
            result = subprocess.run(
                ['wmic', 'process', 'get',
                 'ProcessId,Name,ExecutablePath,CommandLine,WorkingSetSize',
                 '/format:csv'],
                capture_output=True, text=True, timeout=30
            )

            if result.returncode == 0:
                import csv
                from io import StringIO

                lines = [l for l in result.stdout.strip().split('\n') if l.strip()]
                if len(lines) > 1:
                    reader = csv.DictReader(StringIO('\n'.join(lines)))
                    for row in reader:
                        proc = self._parse_process_row(row)
                        if proc:
                            processes.append(proc)

        except Exception as e:
            self.log_error(f"Failed to enumerate processes: {e}")
            processes = self._enumerate_processes_fallback()

        self._all_processes = processes
        return processes

    def _enumerate_processes_fallback(self) -> List[ProcessInfo]:
        """Fallback process enumeration using tasklist"""
        processes = []

        try:
            result = subprocess.run(
                ['tasklist', '/fo', 'csv', '/v'],
                capture_output=True, text=True, timeout=30
            )

            if result.returncode == 0:
                import csv
                from io import StringIO

                reader = csv.DictReader(StringIO(result.stdout))
                for row in reader:
                    try:
                        name = row.get('Image Name', '')
                        pid_str = row.get('PID', '0')
                        mem_str = row.get('Mem Usage', '0 K')

                        mem_usage = int(mem_str.replace(' K', '').replace(',', '')) * 1024

                        processes.append(ProcessInfo(
                            pid=int(pid_str),
                            name=name,
                            memory_usage=mem_usage,
                            user=row.get('User Name', ''),
                        ))
                    except:
                        continue

        except:
            pass

        return processes

    def _parse_process_row(self, row: Dict[str, str]) -> Optional[ProcessInfo]:
        """Parse process from WMIC row"""
        try:
            pid_str = row.get('ProcessId', '0')
            name = row.get('Name', '')

            if not name or pid_str == 'ProcessId':
                return None

            mem_str = row.get('WorkingSetSize', '0')

            return ProcessInfo(
                pid=int(pid_str),
                name=name,
                path=row.get('ExecutablePath', ''),
                command_line=row.get('CommandLine', ''),
                memory_usage=int(mem_str) if mem_str else 0,
            )
        except:
            return None

    def _matches_patterns(self, proc: ProcessInfo, patterns: List[str]) -> bool:
        """Check if process matches patterns"""
        if not patterns:
            return False

        search_text = f"{proc.name} {proc.path} {proc.command_line}".lower()
        return any(p.lower() in search_text for p in patterns)

    def get_found_processes(self) -> Dict[int, ProcessInfo]:
        """Get found processes"""
        return self._found_processes

    def get_all_processes(self) -> List[ProcessInfo]:
        """Get all processes"""
        if not self._all_processes:
            self._enumerate_processes()
        return self._all_processes

    def is_protected(self, name: str) -> bool:
        """Check if process is protected"""
        return name.lower() in self.PROTECTED_PROCESSES


class ProcessManager:
    """Process management operations"""

    PROCESS_TERMINATE = 0x0001
    PROCESS_QUERY_INFORMATION = 0x0400

    def __init__(self, logger: Logger = None):
        self.logger = logger or Logger.get_instance()
        self._is_admin = AdminHelper.is_admin()

    def kill_process(self, pid: int, force: bool = False) -> Tuple[bool, str]:
        """Kill a process by PID"""
        try:
            cmd = ['taskkill', '/pid', str(pid)]
            if force:
                cmd.append('/f')

            result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)

            if result.returncode == 0:
                return True, "Process terminated"
            else:
                return False, result.stderr.strip()

        except subprocess.TimeoutExpired:
            return False, "Operation timed out"
        except Exception as e:
            return False, str(e)

    def kill_process_by_name(self, name: str, force: bool = False) -> Tuple[int, str]:
        """Kill all processes by name"""
        try:
            cmd = ['taskkill', '/im', name]
            if force:
                cmd.append('/f')

            result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)

            if result.returncode == 0:
                return 1, "Processes terminated"
            else:
                return 0, result.stderr.strip()

        except Exception as e:
            return 0, str(e)

    def kill_process_tree(self, pid: int) -> Tuple[bool, str]:
        """Kill process and all children"""
        try:
            result = subprocess.run(
                ['taskkill', '/pid', str(pid), '/t', '/f'],
                capture_output=True, text=True, timeout=30
            )

            if result.returncode == 0:
                return True, "Process tree terminated"
            else:
                return False, result.stderr.strip()

        except Exception as e:
            return False, str(e)

    def suspend_process(self, pid: int) -> Tuple[bool, str]:
        """Suspend a process"""
        try:
            kernel32 = ctypes.windll.kernel32
            ntdll = ctypes.windll.ntdll

            handle = kernel32.OpenProcess(0x1F0FFF, False, pid)
            if not handle:
                return False, "Cannot open process"

            result = ntdll.NtSuspendProcess(handle)
            kernel32.CloseHandle(handle)

            if result == 0:
                return True, "Process suspended"
            else:
                return False, f"Suspend failed: {result}"

        except Exception as e:
            return False, str(e)

    def resume_process(self, pid: int) -> Tuple[bool, str]:
        """Resume a suspended process"""
        try:
            kernel32 = ctypes.windll.kernel32
            ntdll = ctypes.windll.ntdll

            handle = kernel32.OpenProcess(0x1F0FFF, False, pid)
            if not handle:
                return False, "Cannot open process"

            result = ntdll.NtResumeProcess(handle)
            kernel32.CloseHandle(handle)

            if result == 0:
                return True, "Process resumed"
            else:
                return False, f"Resume failed: {result}"

        except Exception as e:
            return False, str(e)

    def is_process_running(self, name: str) -> bool:
        """Check if process is running"""
        try:
            result = subprocess.run(
                ['tasklist', '/fi', f'imagename eq {name}'],
                capture_output=True, text=True, timeout=10
            )
            return name.lower() in result.stdout.lower()
        except:
            return False

    def get_process_path(self, pid: int) -> Optional[str]:
        """Get process executable path"""
        try:
            result = subprocess.run(
                ['wmic', 'process', 'where', f'ProcessId={pid}',
                 'get', 'ExecutablePath', '/value'],
                capture_output=True, text=True, timeout=10
            )

            if result.returncode == 0:
                for line in result.stdout.split('\n'):
                    if line.startswith('ExecutablePath='):
                        return line.split('=', 1)[1].strip()
        except:
            pass

        return None

    def wait_for_process_exit(self, pid: int, timeout: int = 30) -> bool:
        """Wait for process to exit"""
        import time
        start = time.time()

        while time.time() - start < timeout:
            try:
                result = subprocess.run(
                    ['tasklist', '/fi', f'pid eq {pid}'],
                    capture_output=True, text=True, timeout=5
                )
                if str(pid) not in result.stdout:
                    return True
            except:
                pass
            time.sleep(0.5)

        return False

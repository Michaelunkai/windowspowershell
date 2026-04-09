"""
Advanced logging module for Ultimate Uninstaller
Provides multi-level, multi-target logging with colors and formatting
"""

import os
import sys
import time
import threading
import traceback
from enum import IntEnum
from datetime import datetime
from pathlib import Path
from typing import Optional, TextIO, Dict, List, Callable
from dataclasses import dataclass, field
from queue import Queue
from collections import deque


class LogLevel(IntEnum):
    """Log severity levels"""
    TRACE = 0
    DEBUG = 10
    INFO = 20
    SUCCESS = 25
    WARNING = 30
    ERROR = 40
    CRITICAL = 50
    FATAL = 60


class Colors:
    """ANSI color codes for terminal output"""
    RESET = '\033[0m'
    BOLD = '\033[1m'
    DIM = '\033[2m'
    UNDERLINE = '\033[4m'

    BLACK = '\033[30m'
    RED = '\033[31m'
    GREEN = '\033[32m'
    YELLOW = '\033[33m'
    BLUE = '\033[34m'
    MAGENTA = '\033[35m'
    CYAN = '\033[36m'
    WHITE = '\033[37m'

    BG_RED = '\033[41m'
    BG_GREEN = '\033[42m'
    BG_YELLOW = '\033[43m'
    BG_BLUE = '\033[44m'

    BRIGHT_RED = '\033[91m'
    BRIGHT_GREEN = '\033[92m'
    BRIGHT_YELLOW = '\033[93m'
    BRIGHT_BLUE = '\033[94m'
    BRIGHT_MAGENTA = '\033[95m'
    BRIGHT_CYAN = '\033[96m'


LEVEL_COLORS = {
    LogLevel.TRACE: Colors.DIM + Colors.WHITE,
    LogLevel.DEBUG: Colors.CYAN,
    LogLevel.INFO: Colors.WHITE,
    LogLevel.SUCCESS: Colors.BRIGHT_GREEN,
    LogLevel.WARNING: Colors.BRIGHT_YELLOW,
    LogLevel.ERROR: Colors.BRIGHT_RED,
    LogLevel.CRITICAL: Colors.BG_RED + Colors.WHITE,
    LogLevel.FATAL: Colors.BG_RED + Colors.BOLD + Colors.WHITE,
}

LEVEL_ICONS = {
    LogLevel.TRACE: '...',
    LogLevel.DEBUG: '[D]',
    LogLevel.INFO: '[i]',
    LogLevel.SUCCESS: '[+]',
    LogLevel.WARNING: '[!]',
    LogLevel.ERROR: '[X]',
    LogLevel.CRITICAL: '[!!]',
    LogLevel.FATAL: '[XXX]',
}


@dataclass
class LogEntry:
    """Single log entry"""
    timestamp: datetime
    level: LogLevel
    message: str
    module: str = ""
    thread_name: str = ""
    exception: Optional[str] = None
    extra: Dict = field(default_factory=dict)


class LogHandler:
    """Base log handler class"""

    def __init__(self, level: LogLevel = LogLevel.INFO):
        self.level = level
        self._lock = threading.Lock()

    def handle(self, entry: LogEntry):
        """Handle a log entry"""
        if entry.level >= self.level:
            with self._lock:
                self._write(entry)

    def _write(self, entry: LogEntry):
        """Write the entry - override in subclasses"""
        raise NotImplementedError

    def close(self):
        """Close the handler"""
        pass


class ConsoleHandler(LogHandler):
    """Handler that writes to console with colors"""

    def __init__(self, level: LogLevel = LogLevel.INFO,
                 stream: TextIO = None, use_colors: bool = True):
        super().__init__(level)
        self.stream = stream or sys.stdout
        self.use_colors = use_colors and self._supports_color()

    def _supports_color(self) -> bool:
        """Check if terminal supports colors"""
        if os.name == 'nt':
            os.system('')
            return True
        return hasattr(self.stream, 'isatty') and self.stream.isatty()

    def _write(self, entry: LogEntry):
        timestamp = entry.timestamp.strftime('%H:%M:%S.%f')[:-3]
        icon = LEVEL_ICONS.get(entry.level, '[?]')

        if self.use_colors:
            color = LEVEL_COLORS.get(entry.level, '')
            reset = Colors.RESET
            dim = Colors.DIM

            line = f"{dim}{timestamp}{reset} {color}{icon}{reset} "
            if entry.module:
                line += f"{Colors.BLUE}[{entry.module}]{reset} "
            line += f"{color}{entry.message}{reset}"
        else:
            line = f"{timestamp} {icon} "
            if entry.module:
                line += f"[{entry.module}] "
            line += entry.message

        print(line, file=self.stream, flush=True)

        if entry.exception:
            exc_lines = entry.exception.split('\n')
            for exc_line in exc_lines:
                if self.use_colors:
                    print(f"  {Colors.RED}{exc_line}{Colors.RESET}",
                          file=self.stream, flush=True)
                else:
                    print(f"  {exc_line}", file=self.stream, flush=True)


class FileHandler(LogHandler):
    """Handler that writes to file"""

    def __init__(self, path: str, level: LogLevel = LogLevel.DEBUG,
                 max_size_mb: int = 10, backup_count: int = 5):
        super().__init__(level)
        self.path = Path(path)
        self.max_size = max_size_mb * 1024 * 1024
        self.backup_count = backup_count
        self._file: Optional[TextIO] = None
        self._open_file()

    def _open_file(self):
        """Open or create log file"""
        self.path.parent.mkdir(parents=True, exist_ok=True)
        self._file = open(self.path, 'a', encoding='utf-8')

    def _rotate_if_needed(self):
        """Rotate log file if size exceeded"""
        if self._file and self.path.exists():
            if self.path.stat().st_size > self.max_size:
                self._rotate()

    def _rotate(self):
        """Perform log rotation"""
        self._file.close()

        for i in range(self.backup_count - 1, 0, -1):
            src = self.path.with_suffix(f'.{i}.log')
            dst = self.path.with_suffix(f'.{i+1}.log')
            if src.exists():
                src.rename(dst)

        if self.path.exists():
            self.path.rename(self.path.with_suffix('.1.log'))

        self._open_file()

    def _write(self, entry: LogEntry):
        self._rotate_if_needed()

        timestamp = entry.timestamp.isoformat()
        level_name = entry.level.name

        line = f"{timestamp} [{level_name:8}] "
        if entry.module:
            line += f"[{entry.module}] "
        if entry.thread_name:
            line += f"({entry.thread_name}) "
        line += entry.message

        self._file.write(line + '\n')

        if entry.exception:
            for exc_line in entry.exception.split('\n'):
                self._file.write(f"  {exc_line}\n")

        self._file.flush()

    def close(self):
        if self._file:
            self._file.close()
            self._file = None


class MemoryHandler(LogHandler):
    """Handler that keeps logs in memory"""

    def __init__(self, level: LogLevel = LogLevel.DEBUG, max_entries: int = 10000):
        super().__init__(level)
        self.max_entries = max_entries
        self.entries: deque = deque(maxlen=max_entries)

    def _write(self, entry: LogEntry):
        self.entries.append(entry)

    def get_entries(self, level: LogLevel = None,
                    module: str = None, limit: int = None) -> List[LogEntry]:
        """Get filtered log entries"""
        result = list(self.entries)

        if level:
            result = [e for e in result if e.level >= level]
        if module:
            result = [e for e in result if module in e.module]
        if limit:
            result = result[-limit:]

        return result

    def clear(self):
        """Clear all entries"""
        self.entries.clear()


class AsyncHandler(LogHandler):
    """Async handler that processes logs in background thread"""

    def __init__(self, handler: LogHandler):
        super().__init__(handler.level)
        self.handler = handler
        self._queue: Queue = Queue()
        self._running = True
        self._thread = threading.Thread(target=self._process_loop, daemon=True)
        self._thread.start()

    def _process_loop(self):
        """Background processing loop"""
        while self._running or not self._queue.empty():
            try:
                entry = self._queue.get(timeout=0.1)
                self.handler.handle(entry)
                self._queue.task_done()
            except:
                pass

    def handle(self, entry: LogEntry):
        if entry.level >= self.level:
            self._queue.put(entry)

    def close(self):
        self._running = False
        self._thread.join(timeout=5)
        self.handler.close()


class Logger:
    """Main logger class"""

    _instance: Optional['Logger'] = None
    _lock = threading.Lock()

    def __init__(self, name: str = "Uninstaller"):
        self.name = name
        self.handlers: List[LogHandler] = []
        self.level = LogLevel.DEBUG
        self._callbacks: List[Callable[[LogEntry], None]] = []
        self._stats = {level: 0 for level in LogLevel}
        self._start_time = time.time()

    @classmethod
    def get_instance(cls) -> 'Logger':
        """Get singleton instance"""
        if cls._instance is None:
            with cls._lock:
                if cls._instance is None:
                    cls._instance = cls()
        return cls._instance

    def add_handler(self, handler: LogHandler):
        """Add a log handler"""
        self.handlers.append(handler)

    def remove_handler(self, handler: LogHandler):
        """Remove a log handler"""
        if handler in self.handlers:
            self.handlers.remove(handler)
            handler.close()

    def add_callback(self, callback: Callable[[LogEntry], None]):
        """Add callback for log entries"""
        self._callbacks.append(callback)

    def _log(self, level: LogLevel, message: str, module: str = "",
             exception: Exception = None, **extra):
        """Internal log method"""
        if level < self.level:
            return

        entry = LogEntry(
            timestamp=datetime.now(),
            level=level,
            message=message,
            module=module or self.name,
            thread_name=threading.current_thread().name,
            exception=traceback.format_exc() if exception else None,
            extra=extra
        )

        self._stats[level] += 1

        for handler in self.handlers:
            try:
                handler.handle(entry)
            except:
                pass

        for callback in self._callbacks:
            try:
                callback(entry)
            except:
                pass

    def trace(self, message: str, module: str = "", **extra):
        self._log(LogLevel.TRACE, message, module, **extra)

    def debug(self, message: str, module: str = "", **extra):
        self._log(LogLevel.DEBUG, message, module, **extra)

    def info(self, message: str, module: str = "", **extra):
        self._log(LogLevel.INFO, message, module, **extra)

    def success(self, message: str, module: str = "", **extra):
        self._log(LogLevel.SUCCESS, message, module, **extra)

    def warning(self, message: str, module: str = "", **extra):
        self._log(LogLevel.WARNING, message, module, **extra)

    def error(self, message: str, module: str = "",
              exception: Exception = None, **extra):
        self._log(LogLevel.ERROR, message, module, exception, **extra)

    def critical(self, message: str, module: str = "",
                 exception: Exception = None, **extra):
        self._log(LogLevel.CRITICAL, message, module, exception, **extra)

    def fatal(self, message: str, module: str = "",
              exception: Exception = None, **extra):
        self._log(LogLevel.FATAL, message, module, exception, **extra)

    def get_stats(self) -> Dict:
        """Get logging statistics"""
        return {
            'counts': dict(self._stats),
            'total': sum(self._stats.values()),
            'runtime': time.time() - self._start_time,
            'handlers': len(self.handlers),
        }

    def close(self):
        """Close all handlers"""
        for handler in self.handlers:
            handler.close()
        self.handlers.clear()


def setup_logger(log_dir: str = None, console_level: LogLevel = LogLevel.INFO,
                 file_level: LogLevel = LogLevel.DEBUG) -> Logger:
    """Setup and configure logger"""
    logger = Logger.get_instance()

    logger.add_handler(ConsoleHandler(level=console_level))

    if log_dir:
        log_path = Path(log_dir) / f"uninstaller_{datetime.now():%Y%m%d_%H%M%S}.log"
        logger.add_handler(FileHandler(str(log_path), level=file_level))

    logger.add_handler(MemoryHandler(level=LogLevel.DEBUG))

    return logger

"""
Base classes for Ultimate Uninstaller modules
Provides abstract interfaces for scanners, cleaners, and modules
"""

import time
import threading
from abc import ABC, abstractmethod
from typing import List, Dict, Any, Optional, Generator, Callable, Tuple
from dataclasses import dataclass, field
from enum import Enum, auto
from .logger import Logger, LogLevel
from .config import Config, ScanDepth


class ModuleState(Enum):
    """Module lifecycle states"""
    UNINITIALIZED = auto()
    INITIALIZED = auto()
    RUNNING = auto()
    PAUSED = auto()
    COMPLETED = auto()
    FAILED = auto()
    CANCELLED = auto()


@dataclass
class ScanResult:
    """Result from a scan operation"""
    module: str
    item_type: str
    path: str
    name: str = ""
    size: int = 0
    details: Dict[str, Any] = field(default_factory=dict)
    confidence: float = 1.0
    can_delete: bool = True
    risk_level: int = 0


@dataclass
class CleanResult:
    """Result from a clean operation"""
    module: str
    action: str
    target: str
    success: bool
    message: str = ""
    size_freed: int = 0
    details: Dict[str, Any] = field(default_factory=dict)


@dataclass
class ModuleStats:
    """Statistics for module execution"""
    module_name: str
    start_time: float = 0.0
    end_time: float = 0.0
    items_scanned: int = 0
    items_found: int = 0
    items_cleaned: int = 0
    items_failed: int = 0
    bytes_freed: int = 0
    errors: List[str] = field(default_factory=list)

    @property
    def duration(self) -> float:
        if self.end_time and self.start_time:
            return self.end_time - self.start_time
        return 0.0

    @property
    def success_rate(self) -> float:
        total = self.items_cleaned + self.items_failed
        if total == 0:
            return 1.0
        return self.items_cleaned / total


class BaseModule(ABC):
    """Base class for all uninstaller modules"""

    def __init__(self, config: Config, logger: Logger = None):
        self.config = config
        self.logger = logger or Logger.get_instance()
        self.name = self.__class__.__name__
        self.state = ModuleState.UNINITIALIZED
        self._stats = ModuleStats(module_name=self.name)
        self._lock = threading.Lock()
        self._cancel_event = threading.Event()
        self._pause_event = threading.Event()
        self._pause_event.set()
        self._progress_callback: Optional[Callable[[float, str], None]] = None

    def initialize(self) -> bool:
        """Initialize the module"""
        try:
            self.state = ModuleState.INITIALIZED
            self.log_debug(f"Initialized {self.name}")
            return True
        except Exception as e:
            self.log_error(f"Failed to initialize: {e}")
            self.state = ModuleState.FAILED
            return False

    def cleanup(self):
        """Cleanup module resources"""
        self.state = ModuleState.UNINITIALIZED

    def cancel(self):
        """Cancel current operation"""
        self._cancel_event.set()
        self.state = ModuleState.CANCELLED

    def pause(self):
        """Pause current operation"""
        self._pause_event.clear()
        self.state = ModuleState.PAUSED

    def resume(self):
        """Resume paused operation"""
        self._pause_event.set()
        self.state = ModuleState.RUNNING

    def is_cancelled(self) -> bool:
        """Check if operation was cancelled"""
        return self._cancel_event.is_set()

    def wait_if_paused(self):
        """Block if operation is paused"""
        self._pause_event.wait()

    def set_progress_callback(self, callback: Callable[[float, str], None]):
        """Set callback for progress updates"""
        self._progress_callback = callback

    def report_progress(self, progress: float, message: str = ""):
        """Report progress to callback"""
        if self._progress_callback:
            self._progress_callback(progress, message)

    def get_stats(self) -> ModuleStats:
        """Get module statistics"""
        return self._stats

    def reset_stats(self):
        """Reset statistics"""
        self._stats = ModuleStats(module_name=self.name)

    def log_trace(self, message: str):
        self.logger.trace(message, module=self.name)

    def log_debug(self, message: str):
        self.logger.debug(message, module=self.name)

    def log_info(self, message: str):
        self.logger.info(message, module=self.name)

    def log_success(self, message: str):
        self.logger.success(message, module=self.name)

    def log_warning(self, message: str):
        self.logger.warning(message, module=self.name)

    def log_error(self, message: str, exception: Exception = None):
        self.logger.error(message, module=self.name, exception=exception)
        self._stats.errors.append(message)


class BaseScanner(BaseModule):
    """Base class for scanner modules"""

    def __init__(self, config: Config, logger: Logger = None):
        super().__init__(config, logger)
        self._results: List[ScanResult] = []

    @abstractmethod
    def scan(self, target: str = None, patterns: List[str] = None,
             depth: ScanDepth = None) -> Generator[ScanResult, None, None]:
        """Perform scan operation - must be implemented by subclasses"""
        pass

    def scan_all(self, target: str = None, patterns: List[str] = None,
                 depth: ScanDepth = None) -> List[ScanResult]:
        """Perform scan and return all results as list"""
        self._results = []
        self.state = ModuleState.RUNNING
        self._stats.start_time = time.time()

        try:
            for result in self.scan(target, patterns, depth):
                if self.is_cancelled():
                    break
                self.wait_if_paused()
                self._results.append(result)
                self._stats.items_found += 1

            self.state = ModuleState.COMPLETED
        except Exception as e:
            self.log_error(f"Scan failed: {e}", exception=e)
            self.state = ModuleState.FAILED
        finally:
            self._stats.end_time = time.time()

        return self._results

    def get_results(self) -> List[ScanResult]:
        """Get scan results"""
        return self._results

    def clear_results(self):
        """Clear stored results"""
        self._results = []


class BaseCleaner(BaseModule):
    """Base class for cleaner modules"""

    def __init__(self, config: Config, logger: Logger = None):
        super().__init__(config, logger)
        self._results: List[CleanResult] = []

    @abstractmethod
    def clean(self, items: List[ScanResult]) -> Generator[CleanResult, None, None]:
        """Perform clean operation - must be implemented by subclasses"""
        pass

    def clean_all(self, items: List[ScanResult]) -> List[CleanResult]:
        """Clean all items and return results"""
        self._results = []
        self.state = ModuleState.RUNNING
        self._stats.start_time = time.time()

        try:
            total = len(items)
            for i, result in enumerate(self.clean(items)):
                if self.is_cancelled():
                    break
                self.wait_if_paused()
                self._results.append(result)

                if result.success:
                    self._stats.items_cleaned += 1
                    self._stats.bytes_freed += result.size_freed
                else:
                    self._stats.items_failed += 1

                self.report_progress((i + 1) / total, result.target)

            self.state = ModuleState.COMPLETED
        except Exception as e:
            self.log_error(f"Clean failed: {e}", exception=e)
            self.state = ModuleState.FAILED
        finally:
            self._stats.end_time = time.time()

        return self._results

    def get_results(self) -> List[CleanResult]:
        """Get clean results"""
        return self._results


class ScannerCleanerModule(BaseModule):
    """Combined scanner and cleaner module"""

    def __init__(self, config: Config, logger: Logger = None):
        super().__init__(config, logger)
        self._scan_results: List[ScanResult] = []
        self._clean_results: List[CleanResult] = []

    @abstractmethod
    def scan(self, target: str = None, patterns: List[str] = None,
             depth: ScanDepth = None) -> Generator[ScanResult, None, None]:
        """Scan for items"""
        pass

    @abstractmethod
    def clean(self, items: List[ScanResult]) -> Generator[CleanResult, None, None]:
        """Clean found items"""
        pass

    def run(self, target: str = None, patterns: List[str] = None,
            depth: ScanDepth = None, auto_clean: bool = True) -> Tuple:
        """Run full scan and clean cycle"""
        from typing import Tuple

        self.state = ModuleState.RUNNING
        self._stats.start_time = time.time()
        self._scan_results = []
        self._clean_results = []

        try:
            self.log_info("Starting scan...")

            for result in self.scan(target, patterns, depth):
                if self.is_cancelled():
                    break
                self.wait_if_paused()
                self._scan_results.append(result)
                self._stats.items_found += 1

            self.log_info(f"Found {len(self._scan_results)} items")

            if auto_clean and self._scan_results and not self.is_cancelled():
                self.log_info("Starting cleanup...")

                for result in self.clean(self._scan_results):
                    if self.is_cancelled():
                        break
                    self.wait_if_paused()
                    self._clean_results.append(result)

                    if result.success:
                        self._stats.items_cleaned += 1
                        self._stats.bytes_freed += result.size_freed
                    else:
                        self._stats.items_failed += 1

            self.state = ModuleState.COMPLETED
        except Exception as e:
            self.log_error(f"Operation failed: {e}", exception=e)
            self.state = ModuleState.FAILED
        finally:
            self._stats.end_time = time.time()

        return self._scan_results, self._clean_results


class ModuleRegistry:
    """Registry for managing modules"""

    _instance: Optional['ModuleRegistry'] = None
    _lock = threading.Lock()

    def __init__(self):
        self._modules: Dict[str, type] = {}
        self._instances: Dict[str, BaseModule] = {}

    @classmethod
    def get_instance(cls) -> 'ModuleRegistry':
        if cls._instance is None:
            with cls._lock:
                if cls._instance is None:
                    cls._instance = cls()
        return cls._instance

    def register(self, name: str, module_class: type):
        """Register a module class"""
        self._modules[name] = module_class

    def get_module(self, name: str, config: Config = None,
                   logger: Logger = None) -> Optional[BaseModule]:
        """Get or create module instance"""
        if name in self._instances:
            return self._instances[name]

        if name in self._modules:
            instance = self._modules[name](config or Config(), logger)
            self._instances[name] = instance
            return instance

        return None

    def get_all_modules(self) -> List[str]:
        """Get list of registered module names"""
        return list(self._modules.keys())

    def clear(self):
        """Clear all instances"""
        for instance in self._instances.values():
            instance.cleanup()
        self._instances.clear()

"""
Base application cleaner for Ultimate Uninstaller
Common functionality for application-specific cleaners
"""

import os
import shutil
from typing import List, Dict, Generator, Optional, Set, Tuple
from dataclasses import dataclass, field
from abc import ABC, abstractmethod
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from core.base import BaseCleaner, CleanResult, ScanResult
from core.config import Config
from core.logger import Logger
from registry.cleaner import RegistryCleaner
from filesystem.cleaner import FileSystemCleaner


@dataclass
class AppCleanSpec:
    """Application clean specification"""
    name: str
    display_name: str
    registry_patterns: List[str] = field(default_factory=list)
    file_patterns: List[str] = field(default_factory=list)
    service_patterns: List[str] = field(default_factory=list)
    process_names: List[str] = field(default_factory=list)
    appdata_folders: List[str] = field(default_factory=list)
    programdata_folders: List[str] = field(default_factory=list)
    program_folders: List[str] = field(default_factory=list)


class AppCleanerBase(BaseCleaner, ABC):
    """Base class for application-specific cleaners"""

    def __init__(self, config: Config, logger: Logger = None):
        super().__init__(config, logger)
        self.registry_cleaner = RegistryCleaner(config, logger)
        self.filesystem_cleaner = FileSystemCleaner(config, logger)
        self._specs: Dict[str, AppCleanSpec] = {}
        self._cleaned_items: List[str] = []

        self._load_specs()

    @abstractmethod
    def _load_specs(self):
        """Load application specifications - override in subclass"""
        pass

    def get_supported_apps(self) -> List[str]:
        """Get list of supported applications"""
        return list(self._specs.keys())

    def clean(self, items: List[ScanResult]) -> Generator[CleanResult, None, None]:
        """Clean application traces"""
        for item in items:
            if self.is_cancelled():
                break
            self.wait_if_paused()

            app_name = item.details.get('app_name', item.name) if item.details else item.name

            if app_name in self._specs:
                yield from self._clean_app(app_name)
            else:
                yield from self._clean_generic(item)

    def _clean_app(self, app_name: str) -> Generator[CleanResult, None, None]:
        """Clean specific application"""
        spec = self._specs.get(app_name)
        if not spec:
            return

        self.log_info(f"Cleaning {spec.display_name}")

        yield from self._clean_processes(spec)
        yield from self._clean_registry(spec)
        yield from self._clean_files(spec)
        yield from self._clean_appdata(spec)

    def _clean_processes(self, spec: AppCleanSpec) -> Generator[CleanResult, None, None]:
        """Kill related processes"""
        import subprocess

        for proc_name in spec.process_names:
            try:
                result = subprocess.run(
                    ['taskkill', '/f', '/im', proc_name],
                    capture_output=True, timeout=10
                )

                if result.returncode == 0:
                    yield CleanResult(
                        module=self.name,
                        action="kill_process",
                        target=proc_name,
                        success=True,
                        message="Process terminated"
                    )
            except:
                pass

    def _clean_registry(self, spec: AppCleanSpec) -> Generator[CleanResult, None, None]:
        """Clean registry entries"""
        from registry.scanner import RegistryScanner

        scanner = RegistryScanner(self.config, self.logger)

        for pattern in spec.registry_patterns:
            for result in scanner.scan(pattern):
                for clean_result in self.registry_cleaner.clean([result]):
                    yield clean_result

    def _clean_files(self, spec: AppCleanSpec) -> Generator[CleanResult, None, None]:
        """Clean program files"""
        program_files = os.environ.get('PROGRAMFILES', '')
        program_files_x86 = os.environ.get('PROGRAMFILES(X86)', '')

        for folder in spec.program_folders:
            for base in [program_files, program_files_x86]:
                if not base:
                    continue

                path = os.path.join(base, folder)
                if os.path.exists(path):
                    yield from self._remove_directory(path)

    def _clean_appdata(self, spec: AppCleanSpec) -> Generator[CleanResult, None, None]:
        """Clean appdata folders"""
        appdata = os.environ.get('APPDATA', '')
        localappdata = os.environ.get('LOCALAPPDATA', '')
        programdata = os.environ.get('PROGRAMDATA', '')

        for folder in spec.appdata_folders:
            for base in [appdata, localappdata]:
                if not base:
                    continue

                path = os.path.join(base, folder)
                if os.path.exists(path):
                    yield from self._remove_directory(path)

        for folder in spec.programdata_folders:
            if programdata:
                path = os.path.join(programdata, folder)
                if os.path.exists(path):
                    yield from self._remove_directory(path)

    def _remove_directory(self, path: str) -> Generator[CleanResult, None, None]:
        """Remove a directory"""
        if self.config.dry_run:
            yield CleanResult(
                module=self.name,
                action="delete (dry run)",
                target=path,
                success=True,
                message="Would delete"
            )
            return

        try:
            shutil.rmtree(path, ignore_errors=True)
            self._cleaned_items.append(path)

            yield CleanResult(
                module=self.name,
                action="delete",
                target=path,
                success=True,
                message="Deleted"
            )
        except Exception as e:
            yield CleanResult(
                module=self.name,
                action="delete",
                target=path,
                success=False,
                message=str(e)
            )

    def _clean_generic(self, item: ScanResult) -> Generator[CleanResult, None, None]:
        """Generic clean for unknown apps"""
        if item.item_type == "directory":
            yield from self._remove_directory(item.path)
        elif item.item_type == "file":
            if self.config.dry_run:
                yield CleanResult(
                    module=self.name,
                    action="delete (dry run)",
                    target=item.path,
                    success=True,
                    message="Would delete"
                )
            else:
                try:
                    os.remove(item.path)
                    yield CleanResult(
                        module=self.name,
                        action="delete",
                        target=item.path,
                        success=True,
                        message="Deleted"
                    )
                except Exception as e:
                    yield CleanResult(
                        module=self.name,
                        action="delete",
                        target=item.path,
                        success=False,
                        message=str(e)
                    )

    def get_cleaned_items(self) -> List[str]:
        """Get list of cleaned items"""
        return self._cleaned_items


class AppCleaner(AppCleanerBase):
    """Generic application cleaner"""

    def _load_specs(self):
        """Load common application specs"""
        self._specs = {
            'generic': AppCleanSpec(
                name='generic',
                display_name='Generic Application',
                registry_patterns=[],
                file_patterns=[],
            )
        }

    def add_spec(self, spec: AppCleanSpec):
        """Add application specification"""
        self._specs[spec.name] = spec

    def clean_by_name(self, app_name: str) -> Generator[CleanResult, None, None]:
        """Clean application by name"""
        if app_name in self._specs:
            yield from self._clean_app(app_name)
        else:
            temp_spec = AppCleanSpec(
                name=app_name,
                display_name=app_name,
                registry_patterns=[app_name],
                appdata_folders=[app_name],
                program_folders=[app_name],
            )
            self._specs[app_name] = temp_spec
            yield from self._clean_app(app_name)

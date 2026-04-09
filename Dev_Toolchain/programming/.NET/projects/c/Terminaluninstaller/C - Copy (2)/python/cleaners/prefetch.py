"""
Prefetch cleaner for Ultimate Uninstaller
Cleans Windows prefetch files
"""

import os
import shutil
from typing import List, Dict, Generator, Optional
from dataclasses import dataclass
from datetime import datetime, timedelta
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from core.base import BaseCleaner, CleanResult, ScanResult
from core.config import Config
from core.logger import Logger


@dataclass
class PrefetchFile:
    """Prefetch file information"""
    name: str
    path: str
    size: int
    executable: str
    last_run: Optional[datetime]
    run_count: int


class PrefetchCleaner(BaseCleaner):
    """Cleans Windows prefetch files"""

    PREFETCH_PATH = os.path.join(os.environ.get('WINDIR', 'C:\\Windows'), 'Prefetch')

    PROTECTED_PREFETCH = [
        'NTOSBOOT', 'LAYOUT.INI', 'POWERSHELL',
        'SVCHOST', 'EXPLORER', 'CSRSS', 'SMSS',
        'WINLOGON', 'SERVICES', 'LSASS',
    ]

    def __init__(self, config: Config, logger: Logger = None):
        super().__init__(config, logger)
        self._prefetch_files: List[PrefetchFile] = []
        self._cleaned_items: List[str] = []
        self._total_size_cleaned = 0

    def scan(self) -> Generator[ScanResult, None, None]:
        """Scan prefetch files"""
        self.log_info("Scanning prefetch files")

        if not os.path.exists(self.PREFETCH_PATH):
            return

        try:
            total_size = 0
            total_count = 0
            safe_count = 0
            safe_size = 0

            for filename in os.listdir(self.PREFETCH_PATH):
                if not filename.endswith('.pf'):
                    continue

                file_path = os.path.join(self.PREFETCH_PATH, filename)

                try:
                    size = os.path.getsize(file_path)
                    total_size += size
                    total_count += 1

                    executable = self._extract_executable_name(filename)
                    is_protected = self._is_protected(executable)

                    if not is_protected:
                        safe_count += 1
                        safe_size += size

                    mtime = datetime.fromtimestamp(os.path.getmtime(file_path))

                    pf = PrefetchFile(
                        name=filename,
                        path=file_path,
                        size=size,
                        executable=executable,
                        last_run=mtime,
                        run_count=0,
                    )
                    self._prefetch_files.append(pf)
                except:
                    pass

            yield ScanResult(
                module=self.name,
                item_type="prefetch",
                name="Windows Prefetch",
                path=self.PREFETCH_PATH,
                size=total_size,
                details={
                    'total_files': total_count,
                    'safe_files': safe_count,
                    'safe_size': safe_size,
                }
            )

        except Exception as e:
            self.log_error(f"Failed to scan prefetch: {e}")

    def _extract_executable_name(self, filename: str) -> str:
        """Extract executable name from prefetch filename"""
        name = filename.rsplit('-', 1)[0] if '-' in filename else filename
        return name.replace('.pf', '').upper()

    def _is_protected(self, executable: str) -> bool:
        """Check if executable is protected"""
        exe_upper = executable.upper()
        return any(p.upper() in exe_upper for p in self.PROTECTED_PREFETCH)

    def clean(self, items: List[ScanResult] = None) -> Generator[CleanResult, None, None]:
        """Clean prefetch files"""
        self.log_info("Cleaning prefetch files")

        if not os.path.exists(self.PREFETCH_PATH):
            return

        if self.config.dry_run:
            safe_count = sum(1 for pf in self._prefetch_files
                            if not self._is_protected(pf.executable))
            safe_size = sum(pf.size for pf in self._prefetch_files
                           if not self._is_protected(pf.executable))

            yield CleanResult(
                module=self.name,
                action="clean (dry run)",
                target="Windows Prefetch",
                success=True,
                message=f"Would delete {safe_count} files ({self._format_size(safe_size)})"
            )
            return

        cleaned_count = 0
        cleaned_size = 0

        for pf in self._prefetch_files:
            if self.is_cancelled():
                break

            if self._is_protected(pf.executable) and not self.config.force:
                continue

            try:
                os.remove(pf.path)
                cleaned_count += 1
                cleaned_size += pf.size
                self._cleaned_items.append(pf.path)
            except:
                pass

        self._total_size_cleaned = cleaned_size

        yield CleanResult(
            module=self.name,
            action="clean",
            target="Windows Prefetch",
            success=True,
            message=f"Deleted {cleaned_count} files ({self._format_size(cleaned_size)})"
        )

    def clean_old_prefetch(self, days: int = 30) -> Generator[CleanResult, None, None]:
        """Clean prefetch files older than specified days"""
        cutoff_date = datetime.now() - timedelta(days=days)

        if self.config.dry_run:
            old_count = sum(1 for pf in self._prefetch_files
                          if pf.last_run and pf.last_run < cutoff_date
                          and not self._is_protected(pf.executable))
            old_size = sum(pf.size for pf in self._prefetch_files
                         if pf.last_run and pf.last_run < cutoff_date
                         and not self._is_protected(pf.executable))

            yield CleanResult(
                module=self.name,
                action="clean (dry run)",
                target=f"Prefetch older than {days} days",
                success=True,
                message=f"Would delete {old_count} files ({self._format_size(old_size)})"
            )
            return

        cleaned_count = 0
        cleaned_size = 0

        for pf in self._prefetch_files:
            if self.is_cancelled():
                break

            if self._is_protected(pf.executable) and not self.config.force:
                continue

            if pf.last_run and pf.last_run < cutoff_date:
                try:
                    os.remove(pf.path)
                    cleaned_count += 1
                    cleaned_size += pf.size
                    self._cleaned_items.append(pf.path)
                except:
                    pass

        self._total_size_cleaned += cleaned_size

        yield CleanResult(
            module=self.name,
            action="clean",
            target=f"Prefetch older than {days} days",
            success=True,
            message=f"Deleted {cleaned_count} files ({self._format_size(cleaned_size)})"
        )

    def clean_for_executable(self, executable: str) -> Generator[CleanResult, None, None]:
        """Clean prefetch files for specific executable"""
        exe_upper = executable.upper()

        if self.config.dry_run:
            matching = [pf for pf in self._prefetch_files
                       if exe_upper in pf.executable.upper()]
            size = sum(pf.size for pf in matching)

            yield CleanResult(
                module=self.name,
                action="clean (dry run)",
                target=f"Prefetch for {executable}",
                success=True,
                message=f"Would delete {len(matching)} files ({self._format_size(size)})"
            )
            return

        cleaned_count = 0
        cleaned_size = 0

        for pf in self._prefetch_files:
            if exe_upper in pf.executable.upper():
                try:
                    os.remove(pf.path)
                    cleaned_count += 1
                    cleaned_size += pf.size
                    self._cleaned_items.append(pf.path)
                except:
                    pass

        self._total_size_cleaned += cleaned_size

        yield CleanResult(
            module=self.name,
            action="clean",
            target=f"Prefetch for {executable}",
            success=True,
            message=f"Deleted {cleaned_count} files ({self._format_size(cleaned_size)})"
        )

    def optimize_prefetch(self) -> Generator[CleanResult, None, None]:
        """Optimize prefetch by keeping only recent/frequent items"""
        recent_cutoff = datetime.now() - timedelta(days=7)
        frequently_used = set()

        for pf in self._prefetch_files:
            if pf.last_run and pf.last_run > recent_cutoff:
                frequently_used.add(pf.executable)

        if self.config.dry_run:
            old_count = sum(1 for pf in self._prefetch_files
                          if pf.executable not in frequently_used
                          and not self._is_protected(pf.executable))

            yield CleanResult(
                module=self.name,
                action="optimize (dry run)",
                target="Prefetch optimization",
                success=True,
                message=f"Would remove {old_count} unused prefetch entries"
            )
            return

        cleaned_count = 0
        cleaned_size = 0

        for pf in self._prefetch_files:
            if self.is_cancelled():
                break

            if self._is_protected(pf.executable):
                continue

            if pf.executable not in frequently_used:
                try:
                    os.remove(pf.path)
                    cleaned_count += 1
                    cleaned_size += pf.size
                except:
                    pass

        self._total_size_cleaned += cleaned_size

        yield CleanResult(
            module=self.name,
            action="optimize",
            target="Prefetch optimization",
            success=True,
            message=f"Removed {cleaned_count} unused entries ({self._format_size(cleaned_size)})"
        )

    def _format_size(self, size: int) -> str:
        """Format size for display"""
        for unit in ['B', 'KB', 'MB', 'GB']:
            if size < 1024:
                return f"{size:.1f} {unit}"
            size /= 1024
        return f"{size:.1f} TB"

    def get_prefetch_files(self) -> List[PrefetchFile]:
        return self._prefetch_files

    def get_cleaned_items(self) -> List[str]:
        return self._cleaned_items

    def get_total_size_cleaned(self) -> int:
        return self._total_size_cleaned

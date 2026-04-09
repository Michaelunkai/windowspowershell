#!/usr/bin/env python3
"""
Ultimate Uninstaller - Main Orchestrator
Deep and fast Windows software uninstaller

This is the main entry point that coordinates all cleaning modules.
Run with administrator privileges for full functionality.
"""

import os
import sys
import time
import argparse
from datetime import datetime
from typing import List, Dict, Generator, Optional
from concurrent.futures import ThreadPoolExecutor, as_completed
from dataclasses import dataclass, field

# Add project root to path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from core.config import Config, UninstallMode, ScanDepth
from core.logger import Logger
from core.base import CleanResult, ScanResult
from core.admin import AdminHelper
from core.parallel import ParallelExecutor


@dataclass
class CleanStats:
    """Cleaning statistics"""
    total_items_scanned: int = 0
    total_items_cleaned: int = 0
    total_size_cleaned: int = 0
    total_errors: int = 0
    start_time: float = 0
    end_time: float = 0
    module_stats: Dict[str, Dict] = field(default_factory=dict)


class UltimateUninstaller:
    """Main orchestrator for the Ultimate Uninstaller"""

    VERSION = "2.0.0"
    BANNER = """
    ================================================================
    |           ULTIMATE UNINSTALLER v2.0.0                        |
    |           Deep & Fast Windows Cleanup Tool                   |
    ================================================================
    """

    def __init__(self, config: Config = None):
        self.config = config or Config()
        self.logger = Logger(self.config)
        self.stats = CleanStats()
        self._results: List[CleanResult] = []

    def run(self, mode: str = "full", target: str = None,
            parallel: bool = True) -> CleanStats:
        """Run the uninstaller"""
        print(self.BANNER)
        self.stats.start_time = time.time()

        if not AdminHelper.is_admin():
            self.logger.warning("Not running as administrator. Some operations may fail.")
            print("\n[!] Warning: Run as Administrator for full functionality\n")

        if mode == "full":
            self._run_full_clean(parallel)
        elif mode == "registry":
            self._run_registry_clean(target)
        elif mode == "filesystem":
            self._run_filesystem_clean(target)
        elif mode == "services":
            self._run_services_clean(target)
        elif mode == "drivers":
            self._run_drivers_clean(target)
        elif mode == "startup":
            self._run_startup_clean(target)
        elif mode == "network":
            self._run_network_clean()
        elif mode == "browser":
            self._run_browser_clean(target)
        elif mode == "cache":
            self._run_cache_clean()
        elif mode == "temp":
            self._run_temp_clean()
        elif mode == "app":
            self._run_app_clean(target)
        elif mode == "scan":
            self._run_scan_only(target)
        else:
            self.logger.error(f"Unknown mode: {mode}")

        self.stats.end_time = time.time()
        self._print_summary()

        return self.stats

    def _run_full_clean(self, parallel: bool = True):
        """Run full system cleanup"""
        self.logger.info("Starting full system cleanup")
        print("\n[*] Starting full system cleanup...\n")

        modules = [
            ("Registry Cleanup", self._run_registry_clean),
            ("Filesystem Cleanup", self._run_filesystem_clean),
            ("Services Cleanup", self._run_services_clean),
            ("Drivers Cleanup", self._run_drivers_clean),
            ("Startup Cleanup", self._run_startup_clean),
            ("Network Cleanup", self._run_network_clean),
            ("Browser Cleanup", self._run_browser_clean),
            ("Cache Cleanup", self._run_cache_clean),
            ("Temp Files Cleanup", self._run_temp_clean),
            ("Prefetch Cleanup", self._run_prefetch_clean),
            ("Log Cleanup", self._run_log_clean),
            ("Thumbnail Cleanup", self._run_thumbnail_clean),
        ]

        if parallel:
            self._run_parallel(modules)
        else:
            self._run_sequential(modules)

    def _run_parallel(self, modules: List[tuple]):
        """Run modules in parallel"""
        with ThreadPoolExecutor(max_workers=4) as executor:
            futures = {}
            for name, func in modules:
                future = executor.submit(self._safe_run, name, func)
                futures[future] = name

            for future in as_completed(futures):
                name = futures[future]
                try:
                    future.result()
                except Exception as e:
                    self.logger.error(f"{name} failed: {e}")
                    self.stats.total_errors += 1

    def _run_sequential(self, modules: List[tuple]):
        """Run modules sequentially"""
        for name, func in modules:
            self._safe_run(name, func)

    def _safe_run(self, name: str, func, *args):
        """Safely run a module function"""
        try:
            print(f"\n[>] {name}...")
            func(*args)
            print(f"[+] {name} complete")
        except Exception as e:
            self.logger.error(f"{name} error: {e}")
            print(f"[!] {name} failed: {e}")
            self.stats.total_errors += 1

    def _run_registry_clean(self, pattern: str = None):
        """Run registry cleanup"""
        from registry.scanner import RegistryScanner
        from registry.cleaner import RegistryCleaner

        scanner = RegistryScanner(self.config, self.logger)
        cleaner = RegistryCleaner(self.config, self.logger)

        items = list(scanner.scan(pattern))
        self.stats.total_items_scanned += len(items)

        for result in cleaner.clean(items):
            self._process_result("Registry", result)

    def _run_filesystem_clean(self, pattern: str = None):
        """Run filesystem cleanup"""
        from filesystem.scanner import FileSystemScanner
        from filesystem.cleaner import FileSystemCleaner

        scanner = FileSystemScanner(self.config, self.logger)
        cleaner = FileSystemCleaner(self.config, self.logger)

        items = list(scanner.scan(pattern))
        self.stats.total_items_scanned += len(items)

        for result in cleaner.clean(items):
            self._process_result("Filesystem", result)

    def _run_services_clean(self, pattern: str = None):
        """Run services cleanup"""
        from services.scanner import ServiceScanner
        from services.cleaner import ServiceCleaner

        scanner = ServiceScanner(self.config, self.logger)
        cleaner = ServiceCleaner(self.config, self.logger)

        items = list(scanner.scan(pattern))
        self.stats.total_items_scanned += len(items)

        for result in cleaner.clean(items):
            self._process_result("Services", result)

    def _run_drivers_clean(self, pattern: str = None):
        """Run drivers cleanup"""
        from drivers.scanner import DriverScanner
        from drivers.cleaner import DriverCleaner

        scanner = DriverScanner(self.config, self.logger)
        cleaner = DriverCleaner(self.config, self.logger)

        items = list(scanner.scan(pattern))
        self.stats.total_items_scanned += len(items)

        for result in cleaner.clean(items):
            self._process_result("Drivers", result)

    def _run_startup_clean(self, pattern: str = None):
        """Run startup cleanup"""
        from system.startup import StartupScanner, StartupCleaner

        scanner = StartupScanner(self.config, self.logger)
        cleaner = StartupCleaner(self.config, self.logger)

        items = list(scanner.scan(pattern))
        self.stats.total_items_scanned += len(items)

        for result in cleaner.clean(items):
            self._process_result("Startup", result)

    def _run_network_clean(self, pattern: str = None):
        """Run network cleanup"""
        from network.scanner import NetworkScanner
        from network.cleaner import NetworkCleaner

        scanner = NetworkScanner(self.config, self.logger)
        cleaner = NetworkCleaner(self.config, self.logger)

        items = list(scanner.scan(pattern))
        self.stats.total_items_scanned += len(items)

        for result in cleaner.clean(items):
            self._process_result("Network", result)

    def _run_browser_clean(self, browser: str = None):
        """Run browser cleanup"""
        from browser.scanner import BrowserScanner, BrowserType
        from browser.cleaner import BrowserCleaner

        scanner = BrowserScanner(self.config, self.logger)
        cleaner = BrowserCleaner(self.config, self.logger)

        items = list(scanner.scan())
        self.stats.total_items_scanned += len(items)

        if browser:
            items = [i for i in items if browser.lower() in i.details.get('browser', '').lower()]

        for result in cleaner.clean(items):
            self._process_result("Browser", result)

    def _run_cache_clean(self):
        """Run cache cleanup"""
        from cleaners.cache import CacheCleaner

        cleaner = CacheCleaner(self.config, self.logger)

        items = list(cleaner.scan())
        self.stats.total_items_scanned += len(items)

        for result in cleaner.clean(items):
            self._process_result("Cache", result)

        self.stats.total_size_cleaned += cleaner.get_total_size_cleaned()

    def _run_temp_clean(self):
        """Run temp files cleanup"""
        from cleaners.temp import TempCleaner

        cleaner = TempCleaner(self.config, self.logger)

        items = list(cleaner.scan())
        self.stats.total_items_scanned += len(items)

        for result in cleaner.clean(items):
            self._process_result("Temp", result)

        self.stats.total_size_cleaned += cleaner.get_total_size_cleaned()

    def _run_prefetch_clean(self):
        """Run prefetch cleanup"""
        from cleaners.prefetch import PrefetchCleaner

        cleaner = PrefetchCleaner(self.config, self.logger)

        items = list(cleaner.scan())
        self.stats.total_items_scanned += len(items)

        for result in cleaner.clean(items):
            self._process_result("Prefetch", result)

        self.stats.total_size_cleaned += cleaner.get_total_size_cleaned()

    def _run_log_clean(self):
        """Run log files cleanup"""
        from cleaners.logs import LogCleaner

        cleaner = LogCleaner(self.config, self.logger)

        items = list(cleaner.scan())
        self.stats.total_items_scanned += len(items)

        for result in cleaner.clean(items):
            self._process_result("Logs", result)

        self.stats.total_size_cleaned += cleaner.get_total_size_cleaned()

    def _run_thumbnail_clean(self):
        """Run thumbnail cache cleanup"""
        from cleaners.thumbnails import ThumbnailCleaner

        cleaner = ThumbnailCleaner(self.config, self.logger)

        items = list(cleaner.scan())
        self.stats.total_items_scanned += len(items)

        for result in cleaner.clean(items):
            self._process_result("Thumbnails", result)

        self.stats.total_size_cleaned += cleaner.get_total_size_cleaned()

    def _run_app_clean(self, app_name: str):
        """Run application-specific cleanup"""
        if not app_name:
            self.logger.error("Application name required")
            return

        from apps.base import AppCleaner

        cleaner = AppCleaner(self.config, self.logger)

        for result in cleaner.clean_by_name(app_name):
            self._process_result("App", result)

    def _run_scan_only(self, pattern: str = None):
        """Run scan without cleaning"""
        print("\n[*] Scanning system (no changes will be made)...\n")

        scanners = [
            ("Registry", self._scan_registry),
            ("Filesystem", self._scan_filesystem),
            ("Services", self._scan_services),
            ("Drivers", self._scan_drivers),
            ("Startup", self._scan_startup),
            ("Network", self._scan_network),
            ("Browser", self._scan_browser),
            ("Cache", self._scan_cache),
            ("Temp", self._scan_temp),
        ]

        for name, func in scanners:
            print(f"\n[>] Scanning {name}...")
            try:
                count = func(pattern)
                print(f"[+] Found {count} items in {name}")
            except Exception as e:
                print(f"[!] {name} scan failed: {e}")

    def _scan_registry(self, pattern: str = None) -> int:
        from registry.scanner import RegistryScanner
        scanner = RegistryScanner(self.config, self.logger)
        items = list(scanner.scan(pattern))
        self.stats.total_items_scanned += len(items)
        return len(items)

    def _scan_filesystem(self, pattern: str = None) -> int:
        from filesystem.scanner import FileSystemScanner
        scanner = FileSystemScanner(self.config, self.logger)
        items = list(scanner.scan(pattern))
        self.stats.total_items_scanned += len(items)
        return len(items)

    def _scan_services(self, pattern: str = None) -> int:
        from services.scanner import ServiceScanner
        scanner = ServiceScanner(self.config, self.logger)
        items = list(scanner.scan(pattern))
        self.stats.total_items_scanned += len(items)
        return len(items)

    def _scan_drivers(self, pattern: str = None) -> int:
        from drivers.scanner import DriverScanner
        scanner = DriverScanner(self.config, self.logger)
        items = list(scanner.scan(pattern))
        self.stats.total_items_scanned += len(items)
        return len(items)

    def _scan_startup(self, pattern: str = None) -> int:
        from system.startup import StartupScanner
        scanner = StartupScanner(self.config, self.logger)
        items = list(scanner.scan(pattern))
        self.stats.total_items_scanned += len(items)
        return len(items)

    def _scan_network(self, pattern: str = None) -> int:
        from network.scanner import NetworkScanner
        scanner = NetworkScanner(self.config, self.logger)
        items = list(scanner.scan(pattern))
        self.stats.total_items_scanned += len(items)
        return len(items)

    def _scan_browser(self, pattern: str = None) -> int:
        from browser.scanner import BrowserScanner
        scanner = BrowserScanner(self.config, self.logger)
        items = list(scanner.scan(pattern))
        self.stats.total_items_scanned += len(items)
        return len(items)

    def _scan_cache(self, pattern: str = None) -> int:
        from cleaners.cache import CacheCleaner
        cleaner = CacheCleaner(self.config, self.logger)
        items = list(cleaner.scan())
        self.stats.total_items_scanned += len(items)
        return len(items)

    def _scan_temp(self, pattern: str = None) -> int:
        from cleaners.temp import TempCleaner
        cleaner = TempCleaner(self.config, self.logger)
        items = list(cleaner.scan())
        self.stats.total_items_scanned += len(items)
        return len(items)

    def _process_result(self, module: str, result: CleanResult):
        """Process a clean result"""
        self._results.append(result)

        if result.success:
            self.stats.total_items_cleaned += 1
            if module not in self.stats.module_stats:
                self.stats.module_stats[module] = {'cleaned': 0, 'errors': 0}
            self.stats.module_stats[module]['cleaned'] += 1

            if self.config.verbose:
                print(f"  [{module}] {result.action}: {result.target}")
        else:
            self.stats.total_errors += 1
            if module not in self.stats.module_stats:
                self.stats.module_stats[module] = {'cleaned': 0, 'errors': 0}
            self.stats.module_stats[module]['errors'] += 1

            if self.config.verbose:
                print(f"  [{module}] FAILED: {result.target} - {result.message}")

    def _print_summary(self):
        """Print cleanup summary"""
        duration = self.stats.end_time - self.stats.start_time

        print("\n" + "=" * 60)
        print("                    CLEANUP SUMMARY")
        print("=" * 60)
        print(f"  Duration:         {duration:.2f} seconds")
        print(f"  Items Scanned:    {self.stats.total_items_scanned}")
        print(f"  Items Cleaned:    {self.stats.total_items_cleaned}")
        print(f"  Space Recovered:  {self._format_size(self.stats.total_size_cleaned)}")
        print(f"  Errors:           {self.stats.total_errors}")

        if self.stats.module_stats:
            print("\n  Module Statistics:")
            print("  " + "-" * 40)
            for module, stats in self.stats.module_stats.items():
                print(f"    {module:15} Cleaned: {stats['cleaned']:5}  Errors: {stats['errors']:3}")

        print("=" * 60)

        if self.config.dry_run:
            print("\n[!] DRY RUN - No actual changes were made")

    def _format_size(self, size: int) -> str:
        """Format size for display"""
        for unit in ['B', 'KB', 'MB', 'GB']:
            if size < 1024:
                return f"{size:.1f} {unit}"
            size /= 1024
        return f"{size:.1f} TB"


def parse_args():
    """Parse command line arguments"""
    parser = argparse.ArgumentParser(
        description="Ultimate Uninstaller - Deep & Fast Windows Cleanup Tool",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python a.py                    # Full cleanup
  python a.py --mode scan        # Scan only (no changes)
  python a.py --mode registry    # Registry cleanup only
  python a.py --mode browser     # Browser cleanup only
  python a.py --mode app --target "Adobe"  # Clean Adobe apps
  python a.py --dry-run          # Show what would be done
  python a.py --force            # Force clean protected items
        """
    )

    parser.add_argument(
        '--mode', '-m',
        choices=['full', 'scan', 'registry', 'filesystem', 'services',
                'drivers', 'startup', 'network', 'browser', 'cache',
                'temp', 'app'],
        default='full',
        help='Cleanup mode (default: full)'
    )

    parser.add_argument(
        '--target', '-t',
        help='Target pattern or application name'
    )

    parser.add_argument(
        '--dry-run', '-n',
        action='store_true',
        help='Show what would be done without making changes'
    )

    parser.add_argument(
        '--force', '-f',
        action='store_true',
        help='Force clean protected items'
    )

    parser.add_argument(
        '--verbose', '-v',
        action='store_true',
        help='Verbose output'
    )

    parser.add_argument(
        '--sequential', '-s',
        action='store_true',
        help='Run modules sequentially instead of parallel'
    )

    parser.add_argument(
        '--depth',
        choices=['quick', 'normal', 'deep'],
        default='normal',
        help='Scan depth (default: normal)'
    )

    parser.add_argument(
        '--backup-dir',
        help='Directory for backups'
    )

    parser.add_argument(
        '--log-file',
        help='Log file path'
    )

    return parser.parse_args()


def main():
    """Main entry point"""
    args = parse_args()

    # Configure
    config = Config()
    config.dry_run = args.dry_run
    config.force = args.force
    config.verbose = args.verbose

    if args.depth == 'quick':
        config.scan_depth = ScanDepth.QUICK
    elif args.depth == 'deep':
        config.scan_depth = ScanDepth.DEEP
    else:
        config.scan_depth = ScanDepth.NORMAL

    if args.backup_dir:
        config.backup_path = args.backup_dir

    if args.log_file:
        config.log_file = args.log_file

    # Run
    uninstaller = UltimateUninstaller(config)
    stats = uninstaller.run(
        mode=args.mode,
        target=args.target,
        parallel=not args.sequential
    )

    # Exit code
    sys.exit(0 if stats.total_errors == 0 else 1)


if __name__ == "__main__":
    main()

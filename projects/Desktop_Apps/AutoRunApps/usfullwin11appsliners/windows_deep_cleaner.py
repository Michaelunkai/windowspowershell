#!/usr/bin/env python3
"""
Windows Deep Cleaner - Comprehensive C Drive Cleanup Tool
Author: System Administrator
Version: 3.0.0
Description: Safely cleans Windows C drive to maximize free space without removing essential files
"""

import os
import sys
import shutil
import subprocess
import ctypes
import winreg
import json
import time
import logging
import hashlib
import sqlite3
import tempfile
import threading
import queue
import argparse
import configparser
import datetime
import glob
import re
import stat
import uuid
import socket
import struct
import traceback
import psutil
import win32api
import win32con
import win32file
import win32security
import win32process
import win32service
import win32serviceutil
import wmi
from pathlib import Path
from typing import List, Dict, Tuple, Optional, Set, Any, Union
from dataclasses import dataclass, field
from enum import Enum, auto
from collections import defaultdict, namedtuple
from concurrent.futures import ThreadPoolExecutor, ProcessPoolExecutor
from contextlib import contextmanager

# Constants and Configuration
WINDOWS_DIR = os.environ.get('WINDIR', 'C:\\Windows')
PROGRAM_FILES = os.environ.get('ProgramFiles', 'C:\\Program Files')
PROGRAM_FILES_X86 = os.environ.get('ProgramFiles(x86)', 'C:\\Program Files (x86)')
APPDATA = os.environ.get('APPDATA', '')
LOCALAPPDATA = os.environ.get('LOCALAPPDATA', '')
TEMP = os.environ.get('TEMP', 'C:\\Windows\\Temp')
USER_PROFILE = os.environ.get('USERPROFILE', '')
PROGRAM_DATA = os.environ.get('ProgramData', 'C:\\ProgramData')

# File size thresholds
MIN_FILE_AGE_DAYS = 7
LARGE_FILE_THRESHOLD = 100 * 1024 * 1024  # 100 MB
VERY_LARGE_FILE_THRESHOLD = 500 * 1024 * 1024  # 500 MB
GIGANTIC_FILE_THRESHOLD = 1024 * 1024 * 1024  # 1 GB

# Safety patterns - files/folders that should never be deleted
CRITICAL_SYSTEM_PATTERNS = [
    r'.*\\System32\\.*',
    r'.*\\SysWOW64\\.*',
    r'.*\\Windows\\System\\.*',
    r'.*\\Windows\\Boot\\.*',
    r'.*\\Windows\\WinSxS\\.*',
    r'.*\\Windows\\Registration\\.*',
    r'.*\\Windows\\ServiceProfiles\\.*',
    r'.*\\Windows\\CSC\\.*',
    r'.*\\Windows\\Installer\\.*',
    r'.*\\Program Files\\Windows.*',
    r'.*\\Users\\.*\\NTUSER\.DAT.*',
    r'.*\\Users\\.*\\UsrClass\.dat.*',
    r'.*\\bootmgr.*',
    r'.*\\pagefile\.sys',
    r'.*\\hiberfil\.sys',
    r'.*\\swapfile\.sys',
    r'.*\\System Volume Information\\.*',
    r'.*\\\$Recycle\.Bin\\.*',
    r'.*\\Recovery\\.*',
    r'.*\\EFI\\.*',
]

# Safe to clean patterns
SAFE_CLEAN_PATTERNS = [
    r'.*\.tmp$',
    r'.*\.temp$',
    r'.*\.cache$',
    r'.*\~\$.*',
    r'.*\.log$',
    r'.*\.old$',
    r'.*\.bak$',
    r'.*\.backup$',
    r'.*\_old$',
    r'.*\.dmp$',
    r'.*\.hdmp$',
    r'.*\.mdmp$',
    r'.*thumbs\.db$',
    r'.*desktop\.ini$',
    r'.*\.etl$',
    r'.*\.evtx$',
]

# Cleaner categories
class CleanerCategory(Enum):
    TEMP_FILES = auto()
    BROWSER_CACHE = auto()
    SYSTEM_LOGS = auto()
    WINDOWS_UPDATE = auto()
    THUMBNAILS = auto()
    PREFETCH = auto()
    MEMORY_DUMPS = auto()
    RECYCLE_BIN = auto()
    OLD_WINDOWS = auto()
    INSTALLER_CACHE = auto()
    DRIVER_PACKAGES = auto()
    FONT_CACHE = auto()
    ICON_CACHE = auto()
    SEARCH_INDEX = auto()
    ERROR_REPORTS = auto()
    DELIVERY_OPTIMIZATION = auto()
    WINDOWS_DEFENDER = auto()
    SYSTEM_RESTORE = auto()
    HIBERNATION = auto()
    VIRTUAL_MEMORY = auto()
    DUPLICATE_FILES = auto()
    EMPTY_FOLDERS = auto()
    BROKEN_SHORTCUTS = auto()
    INVALID_REGISTRY = auto()
    OLD_DRIVERS = auto()
    ORPHANED_INSTALLERS = auto()
    APPLICATION_CACHE = auto()
    GAME_CACHE = auto()
    CLOUD_CACHE = auto()
    UPDATE_CACHE = auto()

@dataclass
class CleanupItem:
    """Represents an item to be cleaned"""
    path: str
    size: int
    category: CleanerCategory
    description: str
    safe_to_delete: bool = True
    requires_admin: bool = False
    last_modified: Optional[datetime.datetime] = None
    hash: Optional[str] = None
    
class CleanupResult:
    """Stores cleanup operation results"""
    def __init__(self):
        self.total_space_freed = 0
        self.items_deleted = 0
        self.items_failed = 0
        self.errors = []
        self.warnings = []
        self.start_time = time.time()
        self.end_time = None
        self.details = defaultdict(list)
        
    def add_success(self, item: CleanupItem):
        self.items_deleted += 1
        self.total_space_freed += item.size
        self.details[item.category].append({
            'path': item.path,
            'size': item.size,
            'status': 'deleted'
        })
        
    def add_failure(self, item: CleanupItem, error: str):
        self.items_failed += 1
        self.errors.append(f"Failed to delete {item.path}: {error}")
        self.details[item.category].append({
            'path': item.path,
            'size': item.size,
            'status': 'failed',
            'error': error
        })
        
    def finalize(self):
        self.end_time = time.time()
        
    @property
    def duration(self):
        if self.end_time:
            return self.end_time - self.start_time
        return time.time() - self.start_time
        
    def get_summary(self) -> str:
        """Get formatted summary of cleanup results"""
        summary = []
        summary.append("=" * 80)
        summary.append("CLEANUP SUMMARY")
        summary.append("=" * 80)
        summary.append(f"Total space freed: {self.format_size(self.total_space_freed)}")
        summary.append(f"Items deleted: {self.items_deleted:,}")
        summary.append(f"Items failed: {self.items_failed:,}")
        summary.append(f"Duration: {self.duration:.2f} seconds")
        summary.append("")
        
        if self.details:
            summary.append("Details by category:")
            for category, items in self.details.items():
                total_size = sum(item['size'] for item in items if item['status'] == 'deleted')
                summary.append(f"  {category.name}: {self.format_size(total_size)} freed")
                
        if self.errors:
            summary.append("\nErrors encountered:")
            for error in self.errors[:10]:  # Show first 10 errors
                summary.append(f"  - {error}")
            if len(self.errors) > 10:
                summary.append(f"  ... and {len(self.errors) - 10} more errors")
                
        return "\n".join(summary)
        
    @staticmethod
    def format_size(size_bytes: int) -> str:
        """Format bytes to human readable size"""
        for unit in ['B', 'KB', 'MB', 'GB', 'TB']:
            if size_bytes < 1024.0:
                return f"{size_bytes:.2f} {unit}"
            size_bytes /= 1024.0
        return f"{size_bytes:.2f} PB"

class WindowsDeepCleaner:
    """Main Windows Deep Cleaner class - Continued from Part 1"""
    
    # ... [Previous class methods from Part 1 continue here] ...
    
    def find_cloud_storage_cache(self) -> List[CleanupItem]:
        """Find cloud storage sync cache files"""
        items = []
        
        cloud_cache_locations = {
            'OneDrive': [
                (LOCALAPPDATA, 'Microsoft', 'OneDrive', 'logs'),
                (LOCALAPPDATA, 'Microsoft', 'OneDrive', 'setup', 'logs'),
            ],
            'Dropbox': [
                (APPDATA, 'Dropbox', 'cache'),
                (LOCALAPPDATA, 'Dropbox', 'instance1', 'cache'),
            ],
            'Google Drive': [
                (LOCALAPPDATA, 'Google', 'DriveFS', 'cef_cache'),
            ],
            'iCloud': [
                (LOCALAPPDATA, 'Apple Inc', 'CloudKit', 'Cache'),
            ],
        }
        
        for service, cache_paths in cloud_cache_locations.items():
            for path_parts in cache_paths:
                path_parts = [p for p in path_parts if p]
                if not path_parts:
                    continue
                    
                cache_dir = os.path.join(*path_parts)
                
                if os.path.exists(cache_dir):
                    items.extend(self._scan_directory_for_cleanup(
                        cache_dir,
                        CleanerCategory.CLOUD_CACHE,
                        f"{service} cache files"
                    ))
                    
        return items
        
    def find_update_downloads(self) -> List[CleanupItem]:
        """Find downloaded update files from various applications"""
        items = []
        
        update_locations = [
            (LOCALAPPDATA, 'Microsoft', 'OneDrive', 'Update', 'Download'),
            (LOCALAPPDATA, 'Google', 'Update', 'Download'),
            (APPDATA, 'Mozilla', 'updates'),
            (LOCALAPPDATA, 'Microsoft', 'Teams', 'current', 'downloads'),
        ]
        
        for path_parts in update_locations:
            path_parts = [p for p in path_parts if p]
            if not path_parts:
                continue
                
            update_dir = os.path.join(*path_parts)
            
            if os.path.exists(update_dir):
                items.extend(self._scan_directory_for_cleanup(
                    update_dir,
                    CleanerCategory.UPDATE_CACHE,
                    "Application update downloads"
                ))
                
        return items
        
    def optimize_services(self) -> None:
        """Optimize Windows services for better performance"""
        if not self.is_admin or not self.aggressive:
            return
            
        self.logger.info("Optimizing Windows services...")
        
        # Services that can be safely disabled for most users
        optional_services = [
            'WSearch',  # Windows Search (if not using search)
            'SysMain',  # Superfetch
            'DiagTrack',  # Diagnostics Tracking
            'dmwappushservice',  # WAP Push Message Service
            'MapsBroker',  # Downloaded Maps Manager
            'lfsvc',  # Geolocation Service
            'WbioSrvc',  # Windows Biometric Service (if not using fingerprint)
        ]
        
        for service_name in optional_services:
            try:
                service_status = win32serviceutil.QueryServiceStatus(service_name)[1]
                
                if service_status != win32service.SERVICE_STOPPED:
                    if self.interactive:
                        response = input(f"Stop and disable {service_name} service? (y/n): ").lower()
                        if response == 'y':
                            win32serviceutil.StopService(service_name)
                            self.logger.info(f"Stopped service: {service_name}")
                            
            except Exception as e:
                self.logger.debug(f"Could not optimize service {service_name}: {e}")
                
    def clean_winsxs(self) -> List[CleanupItem]:
        """Clean WinSxS folder using DISM (safe method)"""
        items = []
        
        if self.is_admin and self.aggressive:
            try:
                # Run DISM to analyze component store
                result = subprocess.run(
                    ['dism', '/Online', '/Cleanup-Image', '/AnalyzeComponentStore'],
                    capture_output=True,
                    text=True
                )
                
                # Parse output to get reclaimable space
                for line in result.stdout.split('\n'):
                    if 'Component Store Cleanup Recommended' in line and 'Yes' in line:
                        # Estimate reclaimable space
                        estimated_size = 2 * 1024 * 1024 * 1024  # 2 GB estimate
                        
                        items.append(CleanupItem(
                            path='WinSxS_Cleanup',
                            size=estimated_size,
                            category=CleanerCategory.WINDOWS_UPDATE,
                            description="WinSxS component store cleanup",
                            requires_admin=True
                        ))
                        break
                        
            except Exception as e:
                self.logger.warning(f"Error analyzing WinSxS: {e}")
                
        return items
        
    def find_crash_dumps(self) -> List[CleanupItem]:
        """Find application crash dump files"""
        items = []
        
        crash_locations = [
            (USER_PROFILE, 'AppData', 'Local', 'CrashDumps'),
            (WINDOWS_DIR, 'LiveKernelReports'),
            (WINDOWS_DIR, 'Minidump'),
        ]
        
        for path_parts in crash_locations:
            path_parts = [p for p in path_parts if p]
            if not path_parts:
                continue
                
            crash_dir = os.path.join(*path_parts)
            
            if os.path.exists(crash_dir):
                for dump_file in Path(crash_dir).glob('*.dmp'):
                    try:
                        size = dump_file.stat().st_size
                        items.append(CleanupItem(
                            path=str(dump_file),
                            size=size,
                            category=CleanerCategory.MEMORY_DUMPS,
                            description="Crash dump file"
                        ))
                    except:
                        pass
                        
        return items
        
    def clean_npm_cache(self) -> List[CleanupItem]:
        """Clean NPM cache for Node.js developers"""
        items = []
        
        npm_cache_dir = os.path.join(APPDATA, 'npm-cache') if APPDATA else None
        
        if npm_cache_dir and os.path.exists(npm_cache_dir):
            items.extend(self._scan_directory_for_cleanup(
                npm_cache_dir,
                CleanerCategory.APPLICATION_CACHE,
                "NPM package cache"
            ))
            
        return items
        
    def clean_pip_cache(self) -> List[CleanupItem]:
        """Clean Python pip cache"""
        items = []
        
        pip_cache_locations = [
            os.path.join(LOCALAPPDATA, 'pip', 'Cache') if LOCALAPPDATA else None,
            os.path.join(APPDATA, 'pip', 'Cache') if APPDATA else None,
        ]
        
        for cache_dir in pip_cache_locations:
            if cache_dir and os.path.exists(cache_dir):
                items.extend(self._scan_directory_for_cleanup(
                    cache_dir,
                    CleanerCategory.APPLICATION_CACHE,
                    "Python pip cache"
                ))
                
        return items
        
    def clean_nuget_cache(self) -> List[CleanupItem]:
        """Clean NuGet package cache for .NET developers"""
        items = []
        
        nuget_cache_dir = os.path.join(USER_PROFILE, '.nuget', 'packages') if USER_PROFILE else None
        
        if nuget_cache_dir and os.path.exists(nuget_cache_dir):
            # Only clean old versions
            package_dirs = {}
            
            for package_dir in Path(nuget_cache_dir).iterdir():
                if package_dir.is_dir():
                    versions = list(package_dir.iterdir())
                    if len(versions) > 1:
                        # Sort versions and keep only the latest
                        versions.sort(key=lambda x: x.stat().st_mtime, reverse=True)
                        
                        for old_version in versions[1:]:
                            size = self._get_directory_size(str(old_version))
                            items.append(CleanupItem(
                                path=str(old_version),
                                size=size,
                                category=CleanerCategory.APPLICATION_CACHE,
                                description=f"Old NuGet package: {package_dir.name}"
                            ))
                            
        return items
        
    def clean_maven_cache(self) -> List[CleanupItem]:
        """Clean Maven repository cache for Java developers"""
        items = []
        
        maven_cache_dir = os.path.join(USER_PROFILE, '.m2', 'repository') if USER_PROFILE else None
        
        if maven_cache_dir and os.path.exists(maven_cache_dir):
            # Clean old snapshot versions
            for snapshot_dir in Path(maven_cache_dir).rglob('*-SNAPSHOT'):
                if snapshot_dir.is_dir():
                    size = self._get_directory_size(str(snapshot_dir))
                    items.append(CleanupItem(
                        path=str(snapshot_dir),
                        size=size,
                        category=CleanerCategory.APPLICATION_CACHE,
                        description="Maven snapshot dependency"
                    ))
                    
        return items
        
    def clean_gradle_cache(self) -> List[CleanupItem]:
        """Clean Gradle build cache"""
        items = []
        
        gradle_cache_dir = os.path.join(USER_PROFILE, '.gradle', 'caches') if USER_PROFILE else None
        
        if gradle_cache_dir and os.path.exists(gradle_cache_dir):
            items.extend(self._scan_directory_for_cleanup(
                gradle_cache_dir,
                CleanerCategory.APPLICATION_CACHE,
                "Gradle build cache"
            ))
            
        return items
        
    def clean_docker_cache(self) -> List[CleanupItem]:
        """Clean Docker cache and unused images"""
        items = []
        
        if self.aggressive:
            try:
                # Check if Docker is installed
                result = subprocess.run(['docker', 'info'], capture_output=True)
                
                if result.returncode == 0:
                    # Get unused images
                    result = subprocess.run(
                        ['docker', 'images', '-f', 'dangling=true', '-q'],
                        capture_output=True,
                        text=True
                    )
                    
                    if result.stdout.strip():
                        # Estimate size of dangling images
                        estimated_size = 1024 * 1024 * 1024  # 1 GB estimate
                        
                        items.append(CleanupItem(
                            path='Docker_Dangling_Images',
                            size=estimated_size,
                            category=CleanerCategory.APPLICATION_CACHE,
                            description="Docker dangling images"
                        ))
                        
            except Exception as e:
                self.logger.debug(f"Docker not available: {e}")
                
        return items
        
    def clean_rust_cache(self) -> List[CleanupItem]:
        """Clean Rust cargo cache"""
        items = []
        
        cargo_cache_dir = os.path.join(USER_PROFILE, '.cargo', 'registry', 'cache') if USER_PROFILE else None
        
        if cargo_cache_dir and os.path.exists(cargo_cache_dir):
            items.extend(self._scan_directory_for_cleanup(
                cargo_cache_dir,
                CleanerCategory.APPLICATION_CACHE,
                "Rust cargo cache"
            ))
            
        return items
        
    def clean_go_cache(self) -> List[CleanupItem]:
        """Clean Go module cache"""
        items = []
        
        go_cache_dir = os.path.join(USER_PROFILE, 'go', 'pkg', 'mod', 'cache') if USER_PROFILE else None
        
        if go_cache_dir and os.path.exists(go_cache_dir):
            items.extend(self._scan_directory_for_cleanup(
                go_cache_dir,
                CleanerCategory.APPLICATION_CACHE,
                "Go module cache"
            ))
            
        return items
        
    def clean_android_cache(self) -> List[CleanupItem]:
        """Clean Android Studio and SDK cache"""
        items = []
        
        android_locations = [
            (USER_PROFILE, '.android', 'cache'),
            (USER_PROFILE, '.gradle', 'caches'),
            (LOCALAPPDATA, 'Android', 'Sdk', 'build-cache'),
        ]
        
        for path_parts in android_locations:
            path_parts = [p for p in path_parts if p]
            if not path_parts:
                continue
                
            cache_dir = os.path.join(*path_parts)
            
            if os.path.exists(cache_dir):
                items.extend(self._scan_directory_for_cleanup(
                    cache_dir,
                    CleanerCategory.APPLICATION_CACHE,
                    "Android development cache"
                ))
                
        return items
        
    def clean_composer_cache(self) -> List[CleanupItem]:
        """Clean PHP Composer cache"""
        items = []
        
        composer_cache_dir = os.path.join(LOCALAPPDATA, 'Composer', 'cache') if LOCALAPPDATA else None
        
        if composer_cache_dir and os.path.exists(composer_cache_dir):
            items.extend(self._scan_directory_for_cleanup(
                composer_cache_dir,
                CleanerCategory.APPLICATION_CACHE,
                "PHP Composer cache"
            ))
            
        return items
        
    def clean_yarn_cache(self) -> List[CleanupItem]:
        """Clean Yarn package manager cache"""
        items = []
        
        yarn_cache_dir = os.path.join(LOCALAPPDATA, 'Yarn', 'Cache') if LOCALAPPDATA else None
        
        if yarn_cache_dir and os.path.exists(yarn_cache_dir):
            items.extend(self._scan_directory_for_cleanup(
                yarn_cache_dir,
                CleanerCategory.APPLICATION_CACHE,
                "Yarn package cache"
            ))
            
        return items
        
    def clean_chocolatey_cache(self) -> List[CleanupItem]:
        """Clean Chocolatey package manager cache"""
        items = []
        
        choco_cache_dirs = [
            'C:\\ProgramData\\chocolatey\\cache',
            'C:\\ProgramData\\chocolatey\\lib-bad',
            'C:\\ProgramData\\chocolatey\\lib-bkp',
        ]
        
        for cache_dir in choco_cache_dirs:
            if os.path.exists(cache_dir):
                items.extend(self._scan_directory_for_cleanup(
                    cache_dir,
                    CleanerCategory.APPLICATION_CACHE,
                    "Chocolatey package cache"
                ))
                
        return items
        
    def clean_office_cache(self) -> List[CleanupItem]:
        """Clean Microsoft Office cache and temporary files"""
        items = []
        
        office_locations = [
            (LOCALAPPDATA, 'Microsoft', 'Office', 'OTele'),
            (LOCALAPPDATA, 'Microsoft', 'Office', 'Spw'),
            (APPDATA, 'Microsoft', 'Office', 'Recent'),
            (LOCALAPPDATA, 'Microsoft', 'Outlook', 'RoamCache'),
        ]
        
        for path_parts in office_locations:
            path_parts = [p for p in path_parts if p]
            if not path_parts:
                continue
                
            cache_dir = os.path.join(*path_parts)
            
            if os.path.exists(cache_dir):
                items.extend(self._scan_directory_for_cleanup(
                    cache_dir,
                    CleanerCategory.APPLICATION_CACHE,
                    "Microsoft Office cache"
                ))
                
        return items
        
    def clean_creative_cloud_cache(self) -> List[CleanupItem]:
        """Clean Adobe Creative Cloud cache"""
        items = []
        
        adobe_locations = [
            (APPDATA, 'Adobe', 'Common', 'Media Cache'),
            (APPDATA, 'Adobe', 'Common', 'Media Cache Files'),
            (LOCALAPPDATA, 'Adobe', 'CRLogs'),
            (TEMP, 'Adobe'),
        ]
        
        for path_parts in adobe_locations:
            path_parts = [p for p in path_parts if p]
            if not path_parts:
                continue
                
            cache_dir = os.path.join(*path_parts)
            
            if os.path.exists(cache_dir):
                items.extend(self._scan_directory_for_cleanup(
                    cache_dir,
                    CleanerCategory.APPLICATION_CACHE,
                    "Adobe Creative Cloud cache"
                ))
                
        return items
        
    def clean_autodesk_cache(self) -> List[CleanupItem]:
        """Clean Autodesk application cache"""
        items = []
        
        autodesk_locations = [
            (LOCALAPPDATA, 'Autodesk', 'webdeploy'),
            (APPDATA, 'Autodesk', 'WebCache'),
            (PROGRAM_DATA, 'Autodesk', 'Temp'),
        ]
        
        for path_parts in autodesk_locations:
            path_parts = [p for p in path_parts if p]
            if not path_parts:
                continue
                
            cache_dir = os.path.join(*path_parts)
            
            if os.path.exists(cache_dir):
                items.extend(self._scan_directory_for_cleanup(
                    cache_dir,
                    CleanerCategory.APPLICATION_CACHE,
                    "Autodesk application cache"
                ))
                
        return items
        
    def defragment_suggestion(self) -> None:
        """Suggest defragmentation for HDDs"""
        if not self.is_admin:
            return
            
        try:
            # Check if C: drive is SSD or HDD
            c = wmi.WMI()
            for physical_disk in c.Win32_DiskDrive():
                for partition in physical_disk.associators("Win32_DiskDriveToDiskPartition"):
                    for logical_disk in partition.associators("Win32_LogicalDiskToPartition"):
                        if logical_disk.DeviceID == "C:":
                            # Check if it's an SSD
                            if physical_disk.MediaType and 'SSD' not in physical_disk.MediaType:
                                print("\nSuggestion: Your C: drive appears to be an HDD.")
                                print("Consider running defragmentation for better performance:")
                                print("  defrag C: /O")
                                
        except Exception as e:
            self.logger.debug(f"Could not determine disk type: {e}")
            
    def compress_old_files(self) -> List[CleanupItem]:
        """Suggest compressing old files to save space"""
        items = []
        
        if self.aggressive:
            # Look for old, large files that could be compressed
            scan_dirs = [
                os.path.join(USER_PROFILE, 'Documents') if USER_PROFILE else None,
                os.path.join(USER_PROFILE, 'Downloads') if USER_PROFILE else None,
            ]
            
            for scan_dir in scan_dirs:
                if not scan_dir or not os.path.exists(scan_dir):
                    continue
                    
                try:
                    for root, dirs, files in os.walk(scan_dir):
                        for file in files:
                            file_path = os.path.join(root, file)
                            
                            try:
                                stat_info = os.stat(file_path)
                                size = stat_info.st_size
                                age_days = (time.time() - stat_info.st_mtime) / (24 * 3600)
                                
                                # Large, old files that aren't already compressed
                                if (size > LARGE_FILE_THRESHOLD and 
                                    age_days > 90 and
                                    not file_path.endswith(('.zip', '.rar', '.7z', '.gz'))):
                                    
                                    # Estimate compression savings (30%)
                                    estimated_savings = int(size * 0.3)
                                    
                                    items.append(CleanupItem(
                                        path=file_path,
                                        size=estimated_savings,
                                        category=CleanerCategory.OLD_FILES,
                                        description="Old file (can be compressed)",
                                        safe_to_delete=False  # Don't delete, just suggest compression
                                    ))
                                    
                            except Exception as e:
                                self.logger.debug(f"Error checking file {file_path}: {e}")
                                
                except Exception as e:
                    self.logger.warning(f"Error scanning directory {scan_dir}: {e}")
                    
        return items

    def execute_special_cleanups(self, item: CleanupItem) -> bool:
        """Execute special cleanup operations that aren't simple file deletions"""
        if item.category == CleanerCategory.RECYCLE_BIN:
            # Empty recycle bin
            if not self.dry_run:
                try:
                    ctypes.windll.shell32.SHEmptyRecycleBinW(None, None, 0)
                    return True
                except:
                    return False
                    
        elif item.path == 'WinSxS_Cleanup':
            # Run DISM cleanup
            if not self.dry_run and self.is_admin:
                try:
                    subprocess.run(
                        ['dism', '/Online', '/Cleanup-Image', '/StartComponentCleanup'],
                        capture_output=True
                    )
                    return True
                except:
                    return False
                    
        elif item.path == 'Docker_Dangling_Images':
            # Clean Docker images
            if not self.dry_run:
                try:
                    subprocess.run(['docker', 'image', 'prune', '-f'], capture_output=True)
                    return True
                except:
                    return False
                    
        return False

    def generate_cleanup_script(self) -> None:
        """Generate a PowerShell script for automated cleanup"""
        if not self.cleanup_items:
            return
            
        script_path = Path.home() / 'windows_cleanup_script.ps1'
        
        script_content = [
            '# Windows Deep Cleanup Script',
            f'# Generated on {datetime.datetime.now()}',
            '# Run as Administrator for best results',
            '',
            '$ErrorActionPreference = "SilentlyContinue"',
            '',
            '# Function to delete files/folders',
            'function Remove-ItemSafely {',
            '    param([string]$Path)',
            '    if (Test-Path $Path) {',
            '        Remove-Item -Path $Path -Recurse -Force -ErrorAction SilentlyContinue',
            '        Write-Host "Deleted: $Path"',
            '    }',
            '}',
            '',
            '# Cleanup operations',
        ]
        
        for item in self.cleanup_items[:100]:  # Limit to first 100 items
            if item.safe_to_delete and not item.requires_admin:
                script_content.append(f'Remove-ItemSafely "{item.path}"')
                
        script_content.extend([
            '',
            '# Empty Recycle Bin',
            'Clear-RecycleBin -Force -ErrorAction SilentlyContinue',
            '',
            '# Run Disk Cleanup',
            'cleanmgr /sagerun:1',
            '',
            'Write-Host "Cleanup complete!"',
        ])
        
        try:
            with open(script_path, 'w', encoding='utf-8') as f:
                f.write('\n'.join(script_content))
                
            print(f"\nPowerShell cleanup script saved to: {script_path}")
            print("Run it with: powershell -ExecutionPolicy Bypass -File", script_path)
            
        except Exception as e:
            self.logger.error(f"Failed to save cleanup script: {e}")

    def run_comprehensive_analysis(self) -> None:
        """Run comprehensive system analysis with all available scanners"""
        print("\n" + "=" * 80)
        print("RUNNING COMPREHENSIVE SYSTEM ANALYSIS")
        print("=" * 80)
        
        all_scanners = [
            ("Temporary Files", self.find_temp_files),
            ("Browser Cache", self.find_browser_cache),
            ("System Logs", self.find_log_files),
            ("Windows Update", self.find_windows_update_files),
            ("Thumbnail Cache", self.find_thumbnail_cache),
            ("Prefetch Files", self.find_prefetch_files),
            ("Memory Dumps", self.find_memory_dumps),
            ("Crash Dumps", self.find_crash_dumps),
            ("Recycle Bin", self.find_recycle_bin_items),
            ("Old Windows", self.find_old_windows_installations),
            ("Installer Cache", self.find_installer_cache),
            ("Driver Packages", self.find_driver_packages),
            ("Font Cache", self.find_font_cache),
            ("Icon Cache", self.find_icon_cache),
            ("Search Index", self.find_search_index),
            ("Error Reports", self.find_error_reports),
            ("Delivery Optimization", self.find_delivery_optimization),
            ("Windows Defender", self.find_windows_defender_files),
            ("Application Cache", self.find_application_cache),
            ("Game Cache", self.find_game_cache),
            ("Cloud Storage Cache", self.find_cloud_storage_cache),
            ("Update Downloads", self.find_update_downloads),
            ("NPM Cache", self.clean_npm_cache),
            ("Pip Cache", self.clean_pip_cache),
            ("NuGet Cache", self.clean_nuget_cache),
            ("Maven Cache", self.clean_maven_cache),
            ("Gradle Cache", self.clean_gradle_cache),
            ("Docker Cache", self.clean_docker_cache),
            ("Rust Cache", self.clean_rust_cache),
            ("Go Cache", self.clean_go_cache),
            ("Android Cache", self.clean_android_cache),
            ("Composer Cache", self.clean_composer_cache),
            ("Yarn Cache", self.clean_yarn_cache),
            ("Chocolatey Cache", self.clean_chocolatey_cache),
            ("Office Cache", self.clean_office_cache),
            ("Creative Cloud Cache", self.clean_creative_cloud_cache),
            ("Autodesk Cache", self.clean_autodesk_cache),
        ]
        
        if self.aggressive:
            all_scanners.extend([
                ("Duplicate Files", self.find_duplicate_files),
                ("Empty Folders", self.find_empty_folders),
                ("Broken Shortcuts", self.find_broken_shortcuts),
                ("System Restore Points", self.find_system_restore_points),
                ("Hibernation File", self.find_hibernation_file),
                ("Virtual Memory", self.find_virtual_memory_settings),
                ("WinSxS Cleanup", self.clean_winsxs),
                ("Registry Cleanup", self.clean_registry),
                ("Old Files Compression", self.compress_old_files),
            ])
        
        total_scanners = len(all_scanners)
        
        for i, (name, scanner) in enumerate(all_scanners, 1):
            print(f"[{i}/{total_scanners}] {name}...", end='')
            
            try:
                items = scanner()
                if items:
                    self.cleanup_items.extend(items)
                    total_size = sum(item.size for item in items)
                    print(f" Found {len(items)} items ({self.result.format_size(total_size)})")
                else:
                    print(" Nothing found")
                    
            except Exception as e:
                print(f" Error: {e}")
                self.logger.error(f"Scanner {name} failed: {e}")
        
        # Sort by size
        self.cleanup_items.sort(key=lambda x: x.size, reverse=True)
        
        # Calculate totals
        total_items = len(self.cleanup_items)
        total_size = sum(item.size for item in self.cleanup_items)
        
        print("\n" + "=" * 80)
        print("ANALYSIS COMPLETE")
        print("=" * 80)
        print(f"Total items found: {total_items:,}")
        print(f"Total space that can be freed: {self.result.format_size(total_size)}")
        print("=" * 80)

def main():
    """Enhanced main entry point with additional features"""
    parser = argparse.ArgumentParser(
        description='Windows Deep Cleaner v3.0 - Maximum C Drive Space Recovery',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
This tool performs comprehensive Windows cleanup including:
  - Temporary files and caches
  - Browser data
  - Windows update files
  - Application caches
  - Developer tool caches
  - System logs and dumps
  - Duplicate files (aggressive mode)
  - And much more...

Examples:
  %(prog)s                      # Interactive mode
  %(prog)s --aggressive         # Maximum cleanup
  %(prog)s --dry-run           # Preview only
  %(prog)s --auto --admin      # Automatic admin cleanup
        """
    )
    
    parser.add_argument('--dry-run', action='store_true',
                       help='Preview what would be deleted')
    parser.add_argument('--aggressive', action='store_true',
                       help='Enable aggressive cleaning')
    parser.add_argument('--auto', '--no-interactive', dest='auto', 
                       action='store_true',
                       help='Run automatically without prompts')
    parser.add_argument('--admin', action='store_true',
                       help='Request administrator privileges')
    parser.add_argument('--generate-script', action='store_true',
                       help='Generate PowerShell cleanup script')
    parser.add_argument('--quiet', action='store_true',
                       help='Minimal output')
    
    args = parser.parse_args()
    
    # Request admin if needed
    if args.admin and not ctypes.windll.shell32.IsUserAnAdmin():
        print("Requesting administrator privileges...")
        ctypes.windll.shell32.ShellExecuteW(
            None, "runas", sys.executable, " ".join(sys.argv), None, 1
        )
        sys.exit(0)
    
    # Create cleaner instance
    cleaner = WindowsDeepCleaner(
        dry_run=args.dry_run,
        verbose=not args.quiet,
        aggressive=args.aggressive,
        interactive=not args.auto
    )
    
    print("=" * 80)
    print("WINDOWS DEEP CLEANER v3.0")
    print("Maximum C Drive Space Recovery Tool")
    print("=" * 80)
    
    if not cleaner.is_admin:
        print("\n⚠  Not running as Administrator")
        print("   Some cleanup operations will be skipped")
        print("   For maximum cleanup, run as Administrator\n")
    
    if args.dry_run:
        print("\n📋 DRY RUN MODE - No files will be deleted\n")
    
    if args.aggressive:
        print("\n⚡ AGGRESSIVE MODE - Maximum cleanup enabled\n")
    
    try:
        # Run comprehensive analysis
        cleaner.run_comprehensive_analysis()
        
        # Show summary
        cleaner.show_cleanup_summary()
        
        # Generate script if requested
        if args.generate_script:
            cleaner.generate_cleanup_script()
        
        # Perform cleanup
        if not args.generate_script or not cleaner.interactive:
            cleaner.perform_cleanup()
        
        # Additional suggestions
        if cleaner.aggressive:
            cleaner.defragment_suggestion()
            cleaner.optimize_services()
        
    except KeyboardInterrupt:
        print("\n\nOperation cancelled by user.")
    except Exception as e:
        print(f"\n\nError: {e}")
        if cleaner.verbose:
            traceback.print_exc()
    
    print("\n" + "=" * 80)
    print("Cleanup process completed!")
    print("=" * 80)

if __name__ == "__main__":
    main()

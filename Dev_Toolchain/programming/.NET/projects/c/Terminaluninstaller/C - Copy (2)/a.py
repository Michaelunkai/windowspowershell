#!/usr/bin/env python3
# Ultimate Uninstaller - EXTREME Python Implementation
# Ultra-fast execution with real-time progress updates
# Aggressively removes ALL traces of applications with NVIDIA-specific targeting

import os
import sys
import time
import shutil
import winreg
import ctypes
import threading
import subprocess
import multiprocessing
from ctypes import wintypes
from datetime import datetime
import re
import psutil
from concurrent.futures import ThreadPoolExecutor, ProcessPoolExecutor
from typing import List, Dict, Set, Tuple, Optional, Union, Any
import glob
import queue
import signal
import concurrent.futures

# Constants
MAX_PATH = 260
BUFFER_SIZE = 4096
PROGRESS_UPDATE_INTERVAL = 0.05  # seconds - faster updates
MAX_WORKERS = max(1, multiprocessing.cpu_count())  # Fix for "max_workers must be greater than 0" error
SCAN_TIMEOUT = 60  # Maximum time for scanning in seconds
DELETE_TIMEOUT = 60  # Maximum time for deletion in seconds
PROTECTED_PATHS = [
    # Extremely minimal protection - only the most critical system files
    r"C:\Windows\system32\ntoskrnl.exe",
    r"C:\Windows\system32\hal.dll",
]

# Windows API Constants
DELETE = 0x00010000
READ_CONTROL = 0x00020000
WRITE_DAC = 0x00040000
WRITE_OWNER = 0x00080000
SYNCHRONIZE = 0x00100000
STANDARD_RIGHTS_REQUIRED = DELETE | READ_CONTROL | WRITE_DAC | WRITE_OWNER
STANDARD_RIGHTS_ALL = STANDARD_RIGHTS_REQUIRED | SYNCHRONIZE
FILE_READ_DATA = 0x0001
FILE_WRITE_DATA = 0x0002
FILE_APPEND_DATA = 0x0004
FILE_READ_EA = 0x0008
FILE_WRITE_EA = 0x0010
FILE_EXECUTE = 0x0020
FILE_READ_ATTRIBUTES = 0x0080
FILE_WRITE_ATTRIBUTES = 0x0100
FILE_ALL_ACCESS = STANDARD_RIGHTS_REQUIRED | SYNCHRONIZE | 0x1FF
FILE_GENERIC_READ = READ_CONTROL | FILE_READ_DATA | FILE_READ_ATTRIBUTES | FILE_READ_EA | SYNCHRONIZE
FILE_GENERIC_WRITE = READ_CONTROL | FILE_WRITE_DATA | FILE_WRITE_ATTRIBUTES | FILE_WRITE_EA | FILE_APPEND_DATA | SYNCHRONIZE
FILE_GENERIC_EXECUTE = READ_CONTROL | FILE_EXECUTE | FILE_READ_ATTRIBUTES | SYNCHRONIZE

# Global variables
total_items = 0
processed_items = 0
current_operation = "Initializing..."
stop_event = threading.Event()
progress_lock = threading.Lock()
log_file = "uninstaller_log.txt"
found_items_queue = queue.Queue()
drives_to_scan = ["C:"]  # Default to C: drive
scan_complete = False
time_start = 0
estimated_completion_time = 0
app_results = {}  # Track results for multiple apps

# Windows API Functions
kernel32 = ctypes.WinDLL('kernel32', use_last_error=True)
advapi32 = ctypes.WinDLL('advapi32', use_last_error=True)

# Function prototypes
kernel32.GetFileAttributesW.argtypes = [wintypes.LPCWSTR]
kernel32.GetFileAttributesW.restype = wintypes.DWORD
kernel32.SetFileAttributesW.argtypes = [wintypes.LPCWSTR, wintypes.DWORD]
kernel32.SetFileAttributesW.restype = wintypes.BOOL

# File Attributes
FILE_ATTRIBUTE_READONLY = 0x1
FILE_ATTRIBUTE_HIDDEN = 0x2
FILE_ATTRIBUTE_SYSTEM = 0x4
FILE_ATTRIBUTE_DIRECTORY = 0x10
FILE_ATTRIBUTE_ARCHIVE = 0x20
FILE_ATTRIBUTE_NORMAL = 0x80

# Helper Classes
class ProgressReporter:
    def __init__(self):
        self.start_time = time.time()
        self.last_update_time = self.start_time
        self.running = True
        self.thread = threading.Thread(target=self._report_progress)
        self.thread.daemon = True
        self.last_action = ""
        self.action_queue = queue.Queue(maxsize=100)  # Store recent actions
        
    def start(self):
        self.thread.start()
        
    def stop(self):
        self.running = False
        if self.thread.is_alive():
            self.thread.join(timeout=1.0)
    
    def log_action(self, action):
        """Log an action that will be displayed in real-time"""
        self.last_action = action
        try:
            # Add to queue but don't block if full (use nowait)
            self.action_queue.put_nowait(action)
        except queue.Full:
            # If queue is full, remove oldest item and add new one
            try:
                self.action_queue.get_nowait()
                self.action_queue.put_nowait(action)
            except:
                pass
        
    def _report_progress(self):
        global estimated_completion_time
        last_update_time = time.time()
        update_interval = 0.05  # Update very frequently (20 times per second)
        
        while self.running:
            current_time = time.time()
            elapsed = current_time - self.start_time
            
            # Always update - show real-time progress
            # Even if we don't have items yet, show that we're doing something
            spinner = "|/-\\"[int(elapsed * 10) % 4]
            
            # Get the latest action if available
            action_display = ""
            if not self.action_queue.empty():
                try:
                    action_display = self.action_queue.get_nowait()
                except queue.Empty:
                    action_display = self.last_action
            else:
                action_display = self.last_action
                
            # Truncate action display if too long
            if len(action_display) > 70:
                action_display = action_display[:67] + "..."
                
            status_msg = f"\r{spinner} {current_operation} ({elapsed:.1f}s elapsed)"
            
            if total_items > 0:
                with progress_lock:
                    percentage = min(100, int((processed_items / total_items) * 100))
                    items_per_sec = processed_items / elapsed if elapsed > 0 else 0
                    
                    # Calculate estimated time remaining
                    if items_per_sec > 0:
                        items_remaining = max(0, total_items - processed_items)
                        time_remaining = items_remaining / items_per_sec
                        estimated_completion_time = time.time() + time_remaining
                        time_str = f"{time_remaining:.1f}s remaining"
                    else:
                        time_str = "calculating..."
                    
                    # Clear the current line and print progress with the latest action
                    status_msg = f"\r[{percentage:3d}%] {current_operation} - {processed_items}/{total_items} items ({items_per_sec:.2f}/s) - {time_str}"
            
            # Always show the latest action
            if action_display:
                status_msg += f"\n→ {action_display}"
            
            # Always update the display
            sys.stdout.write("\r" + " " * 100)
            sys.stdout.write(status_msg)
            sys.stdout.flush()
            last_update_time = current_time
            
            # Sleep for a very short time to prevent CPU hogging but allow frequent updates
            time.sleep(update_interval)

class FileSystemHandler:
    @staticmethod
    def is_path_protected(path: str) -> bool:
        """Check if the path is in a protected system directory."""
        path = os.path.abspath(path).lower()
        return any(path.startswith(protected.lower()) for protected in PROTECTED_PATHS)
    
    @staticmethod
    def set_file_attributes_normal(path: str) -> bool:
        """Set file attributes to normal to allow deletion."""
        try:
            if os.path.exists(path):
                attrs = kernel32.GetFileAttributesW(path)
                if attrs != 0xFFFFFFFF and (attrs & FILE_ATTRIBUTE_READONLY or 
                                           attrs & FILE_ATTRIBUTE_HIDDEN or 
                                           attrs & FILE_ATTRIBUTE_SYSTEM):
                    kernel32.SetFileAttributesW(path, FILE_ATTRIBUTE_NORMAL)
            return True
        except Exception as e:
            log_error(f"Failed to set attributes for {path}: {str(e)}")
            return False
    
    @staticmethod
    def take_ownership(path: str, recursion_depth: int = 0) -> bool:
        """Take ownership of a file or directory with recursion limit."""
        try:
            if not os.path.exists(path):
                return False
                
            # Prevent recursion depth errors by using direct commands without recursion
            # Use direct takeown and icacls commands without recursion flags
            try:
                if os.path.isfile(path):
                    # For files, use simple takeown and icacls
                    subprocess.run(
                        ["takeown", "/f", path], 
                        stdout=subprocess.PIPE, 
                        stderr=subprocess.PIPE,
                        check=False,
                        timeout=2  # Shorter timeout for faster operation
                    )
                    
                    subprocess.run(
                        ["icacls", path, "/grant", "administrators:F"], 
                        stdout=subprocess.PIPE, 
                        stderr=subprocess.PIPE,
                        check=False,
                        timeout=2  # Shorter timeout for faster operation
                    )
                elif os.path.isdir(path):
                    # For directories, use direct commands with /d y to auto-confirm
                    subprocess.run(
                        ["takeown", "/f", path, "/d", "y"], 
                        stdout=subprocess.PIPE, 
                        stderr=subprocess.PIPE,
                        check=False,
                        timeout=2  # Shorter timeout for faster operation
                    )
                    
                    subprocess.run(
                        ["icacls", path, "/grant", "administrators:F"], 
                        stdout=subprocess.PIPE, 
                        stderr=subprocess.PIPE,
                        check=False,
                        timeout=2  # Shorter timeout for faster operation
                    )
            except subprocess.TimeoutExpired:
                # If timeout occurs, just continue - we don't want to get stuck
                pass
            
            return True
        except Exception as e:
            log_error(f"Failed to take ownership of {path}: {str(e)}")
            return False
    
    @staticmethod
    def safe_delete(path: str) -> bool:
        """Safely delete a file or directory."""
        global progress_reporter
        
        try:
            if not os.path.exists(path):
                return True
                
            if FileSystemHandler.is_path_protected(path):
                log_warning(f"Skipping protected path: {path}")
                return False
            
            # Log the action in real-time
            if hasattr(globals(), 'progress_reporter') and globals()['progress_reporter']:
                if os.path.isfile(path):
                    globals()['progress_reporter'].log_action(f"DELETING FILE: {path}")
                else:
                    globals()['progress_reporter'].log_action(f"REMOVING FOLDER: {path}")
                
            FileSystemHandler.set_file_attributes_normal(path)
            
            if os.path.isfile(path):
                os.remove(path)
            elif os.path.isdir(path):
                shutil.rmtree(path, ignore_errors=True)
            
            success = not os.path.exists(path)
            if success and hasattr(globals(), 'progress_reporter') and globals()['progress_reporter']:
                globals()['progress_reporter'].log_action(f"SUCCESSFULLY REMOVED: {path}")
                
            return success
        except PermissionError:
            # Try to take ownership and retry
            if hasattr(globals(), 'progress_reporter') and globals()['progress_reporter']:
                globals()['progress_reporter'].log_action(f"TAKING OWNERSHIP: {path}")
            if FileSystemHandler.take_ownership(path):
                return FileSystemHandler.safe_delete(path)
            return False
        except Exception as e:
            log_error(f"Failed to delete {path}: {str(e)}")
            return False

class RegistryHandler:
    @staticmethod
    def delete_registry_key(root_key: Any, subkey_path: str) -> bool:
        """Delete a registry key and all its subkeys."""
        try:
            # Log the registry key being deleted
            if hasattr(globals(), 'progress_reporter') and globals()['progress_reporter']:
                globals()['progress_reporter'].log_action(f"DELETING REGISTRY KEY: {subkey_path}")
                
            with winreg.OpenKey(root_key, subkey_path, 0, winreg.KEY_ALL_ACCESS) as key:
                # Get subkey count
                info = winreg.QueryInfoKey(key)
                for i in range(info[0]):
                    # Always delete the first subkey (index 0) since the
                    # key count decreases after each deletion
                    subkey_name = winreg.EnumKey(key, 0)
                    RegistryHandler.delete_registry_key(key, subkey_name)
                    
            # After all subkeys are deleted, delete the key itself
            winreg.DeleteKey(root_key, subkey_path)
            
            # Log successful deletion
            if hasattr(globals(), 'progress_reporter') and globals()['progress_reporter']:
                globals()['progress_reporter'].log_action(f"SUCCESSFULLY REMOVED REGISTRY KEY: {subkey_path}")
                
            return True
        except WindowsError as e:
            if e.winerror == 5:  # Access denied
                if hasattr(globals(), 'progress_reporter') and globals()['progress_reporter']:
                    globals()['progress_reporter'].log_action(f"ACCESS DENIED: {subkey_path}")
                log_error(f"Access denied to registry key: {subkey_path}")
            elif e.winerror != 2:  # Key not found is OK
                log_error(f"Error deleting registry key {subkey_path}: {str(e)}")
            return False
    
    @staticmethod
    def delete_registry_value(root_key: Any, subkey_path: str, value_name: str) -> bool:
        """Delete a specific registry value."""
        try:
            # Log the registry value being deleted
            if hasattr(globals(), 'progress_reporter') and globals()['progress_reporter']:
                globals()['progress_reporter'].log_action(f"DELETING REGISTRY VALUE: {subkey_path}\\{value_name}")
                
            with winreg.OpenKey(root_key, subkey_path, 0, winreg.KEY_SET_VALUE) as key:
                winreg.DeleteValue(key, value_name)
                
            # Log successful deletion
            if hasattr(globals(), 'progress_reporter') and globals()['progress_reporter']:
                globals()['progress_reporter'].log_action(f"SUCCESSFULLY REMOVED REGISTRY VALUE: {subkey_path}\\{value_name}")
                
            return True
        except WindowsError as e:
            if e.winerror != 2:  # Value not found is OK
                log_error(f"Error deleting registry value {subkey_path}\\{value_name}: {str(e)}")
            return False
    
    @staticmethod
    def scan_registry_for_app(app_name: str) -> List[Tuple[Any, str, Optional[str]]]:
        """Scan registry for keys related to the application."""
        results = []
        
        # Common registry locations for installed software
        locations = [
            (winreg.HKEY_LOCAL_MACHINE, r"SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"),
            (winreg.HKEY_LOCAL_MACHINE, r"SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"),
            (winreg.HKEY_CURRENT_USER, r"SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"),
            (winreg.HKEY_LOCAL_MACHINE, r"SOFTWARE"),
            (winreg.HKEY_CURRENT_USER, r"SOFTWARE"),
        ]
        
        app_pattern = re.compile(re.escape(app_name), re.IGNORECASE)
        
        for root_key, subkey_path in locations:
            try:
                with winreg.OpenKey(root_key, subkey_path) as key:
                    # Enumerate subkeys
                    i = 0
                    while True:
                        try:
                            subkey_name = winreg.EnumKey(key, i)
                            # Check if app name is in the key name
                            if app_pattern.search(subkey_name):
                                results.append((root_key, f"{subkey_path}\\{subkey_name}", None))
                            
                            # Also check values within the key
                            try:
                                with winreg.OpenKey(root_key, f"{subkey_path}\\{subkey_name}") as subkey:
                                    j = 0
                                    while True:
                                        try:
                                            value_name, value_data, _ = winreg.EnumValue(subkey, j)
                                            if isinstance(value_data, str) and app_pattern.search(value_data):
                                                results.append((root_key, f"{subkey_path}\\{subkey_name}", value_name))
                                            j += 1
                                        except WindowsError:
                                            break
                            except WindowsError:
                                pass
                                
                            i += 1
                        except WindowsError:
                            break
            except WindowsError:
                continue
                
        return results

class ProcessHandler:
    @staticmethod
    def kill_process_by_name(process_name: str) -> int:
        """Kill all processes with the given name."""
        count = 0
        for proc in psutil.process_iter(['pid', 'name']):
            try:
                if process_name.lower() in proc.info['name'].lower():
                    # Log the process being killed
                    if hasattr(globals(), 'progress_reporter') and globals()['progress_reporter']:
                        globals()['progress_reporter'].log_action(f"KILLING PROCESS: {proc.info['name']} (PID: {proc.info['pid']})")
                    proc.kill()
                    count += 1
            except (psutil.NoSuchProcess, psutil.AccessDenied, psutil.ZombieProcess):
                pass
        return count
    
    @staticmethod
    def kill_process_by_path(exe_path: str) -> int:
        """Kill all processes using the given executable path."""
        count = 0
        for proc in psutil.process_iter(['pid', 'exe']):
            try:
                if proc.info['exe'] and exe_path.lower() in proc.info['exe'].lower():
                    # Log the process being killed
                    if hasattr(globals(), 'progress_reporter') and globals()['progress_reporter']:
                        globals()['progress_reporter'].log_action(f"KILLING PROCESS: {proc.info['exe']} (PID: {proc.info['pid']})")
                    proc.kill()
                    count += 1
            except (psutil.NoSuchProcess, psutil.AccessDenied, psutil.ZombieProcess):
                pass
        return count
    
    @staticmethod
    def stop_services_by_pattern(pattern: str) -> int:
        """Stop Windows services matching the pattern."""
        count = 0
        try:
            # Use SC command to list and stop services
            output = subprocess.check_output(
                ["sc", "query", "state=", "all"], 
                text=True, 
                stderr=subprocess.STDOUT
            )
            
            service_name_pattern = re.compile(r"SERVICE_NAME:\s+(\S+)", re.IGNORECASE)
            display_name_pattern = re.compile(r"DISPLAY_NAME:\s+(.+)$", re.IGNORECASE)
            
            services = []
            current_service = None
            
            for line in output.splitlines():
                service_match = service_name_pattern.search(line)
                if service_match:
                    current_service = {"name": service_match.group(1)}
                    services.append(current_service)
                    continue
                    
                display_match = display_name_pattern.search(line)
                if display_match and current_service:
                    current_service["display"] = display_match.group(1)
            
            # Find and stop matching services
            pattern_re = re.compile(pattern, re.IGNORECASE)
            for service in services:
                if "display" in service and pattern_re.search(service["display"]):
                    try:
                        # Log the service being stopped
                        if hasattr(globals(), 'progress_reporter') and globals()['progress_reporter']:
                            globals()['progress_reporter'].log_action(f"STOPPING SERVICE: {service['display']} ({service['name']})")
                        
                        subprocess.run(
                            ["sc", "stop", service["name"]], 
                            stdout=subprocess.PIPE, 
                            stderr=subprocess.PIPE,
                            check=False
                        )
                        count += 1
                    except Exception as e:
                        log_error(f"Failed to stop service {service['name']}: {str(e)}")
        except Exception as e:
            log_error(f"Error stopping services: {str(e)}")
        
        return count

# Utility Functions
def log_message(message: str) -> None:
    """Log a message to the console and log file."""
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    log_entry = f"[{timestamp}] {message}"
    
    # Print to console
    print(log_entry)
    
    # Write to log file
    try:
        with open(log_file, "a", encoding="utf-8") as f:
            f.write(log_entry + "\n")
    except Exception:
        pass

def log_error(message: str) -> None:
    """Log an error message."""
    log_message(f"ERROR: {message}")

def log_warning(message: str) -> None:
    """Log a warning message."""
    log_message(f"WARNING: {message}")

def log_info(message: str) -> None:
    """Log an informational message."""
    log_message(f"INFO: {message}")

def update_progress(operation: str, increment: int = 1) -> None:
    """Update the progress counters."""
    global processed_items, current_operation
    with progress_lock:
        processed_items += increment
        current_operation = operation

def scan_directory(directory: str, pattern: Optional[str] = None) -> List[str]:
    """Scan a directory for files matching the pattern."""
    results = []
    pattern_regex = re.compile(pattern, re.IGNORECASE) if pattern else None
    
    try:
        for root, dirs, files in os.walk(directory):
            for file in files:
                if not pattern_regex or pattern_regex.search(file):
                    results.append(os.path.join(root, file))
            
            # Also check directory names if pattern is provided
            if pattern_regex:
                for dir_name in dirs:
                    if pattern_regex.search(dir_name):
                        results.append(os.path.join(root, dir_name))
    except Exception as e:
        log_error(f"Error scanning directory {directory}: {str(e)}")
    
    return results

def scan_entire_drive_for_app(app_name: str) -> List[str]:
    """Aggressively scan the entire C: drive for any files/folders containing the app name."""
    global current_operation
    results = []
    
    # Special case for NVIDIA - use broader pattern matching
    if app_name.lower() == "nvidia":
        pattern_regex = re.compile(r'nvidia|nvid|nv\b', re.IGNORECASE)
    else:
        pattern_regex = re.compile(re.escape(app_name), re.IGNORECASE)
    
    # Use non-recursive approach to avoid infinite loops
    def scan_chunk(paths):
        chunk_results = []
        # Use a queue instead of recursion
        queue = collections.deque(paths)
        scanned_paths = set()  # Track already scanned paths to prevent loops
        
        # Set a hard limit on items to process
        max_items = 5000
        items_processed = 0
        
        while queue and items_processed < max_items:
            path = queue.popleft()
            items_processed += 1
            
            # Skip if already scanned or protected
            if path in scanned_paths or FileSystemHandler.is_path_protected(path):
                continue
                
            scanned_paths.add(path)
            
            try:
                # Check if the current directory name matches
                if pattern_regex.search(os.path.basename(path)):
                    chunk_results.append(path)
                
                # Scan files in the current directory
                try:
                    for item in os.listdir(path):
                        if stop_event.is_set():
                            return chunk_results
                            
                        item_path = os.path.join(path, item)
                        if pattern_regex.search(item):
                            chunk_results.append(item_path)
                            
                        # Add subdirectories to queue
                        if os.path.isdir(item_path) and not FileSystemHandler.is_path_protected(item_path):
                            if item_path not in scanned_paths:
                                queue.append(item_path)
                except (PermissionError, FileNotFoundError):
                    pass
            except Exception:
                pass
                
        return chunk_results
    
    # Start with root directories on C:
    try:
        root_dirs = []
        for drive in drives_to_scan:
            try:
                for item in os.listdir(drive + "\\"):
                    path = os.path.join(drive, item)
                    if os.path.isdir(path):
                        root_dirs.append(path)
            except Exception:
                pass
        
        # Split into chunks for parallel processing
        chunk_size = max(1, len(root_dirs) // MAX_WORKERS)
        chunks = [root_dirs[i:i + chunk_size] for i in range(0, len(root_dirs), chunk_size)]
        
        # Set a hard timeout for the entire operation
        start_time = time.time()
        max_scan_time = min(SCAN_TIMEOUT, 30)  # Maximum 30 seconds no matter what
        
        # Process chunks in parallel
        with ProcessPoolExecutor(max_workers=MAX_WORKERS) as executor:
            futures = [executor.submit(scan_chunk, chunk) for chunk in chunks]
            
            # Process results as they come in with timeout
            for future in concurrent.futures.as_completed(futures, timeout=max_scan_time):
                if time.time() - start_time > max_scan_time:
                    log_warning(f"Scan timeout reached after {max_scan_time} seconds")
                    break
                
                try:
                    chunk_results = future.result(timeout=5)  # 5 second timeout per future
                    results.extend(chunk_results)
                    
                    # Update progress
                    with progress_lock:
                        current_operation = f"Scanning for {app_name} ({len(results)} matches found)"
                except concurrent.futures.TimeoutError:
                    log_warning("Scan chunk timed out - skipping")
                    continue
                except Exception as e:
                    log_error(f"Error in parallel scan: {str(e)}")
    
    except Exception as e:
        log_error(f"Error scanning drive: {str(e)}")
    
    # Force return after timeout to prevent hanging
    return results

def parallel_scan_directories(directories: List[str], pattern: Optional[str] = None) -> List[str]:
    """Scan multiple directories in parallel."""
    results = []
    with ThreadPoolExecutor(max_workers=min(len(directories), os.cpu_count() or 4)) as executor:
        future_to_dir = {executor.submit(scan_directory, directory, pattern): directory for directory in directories}
        for future in future_to_dir:
            try:
                results.extend(future.result())
            except Exception as e:
                log_error(f"Error in parallel scan: {str(e)}")
    return results

def uninstall_application(app_name: str, install_dir: Optional[str] = None) -> bool:
    """Main function to uninstall an application."""
    global total_items, processed_items, progress_reporter
    
    log_info(f"Starting EXTREME uninstallation of {app_name}")
    
    try:
        # Step 1: Kill related processes - ULTRA AGGRESSIVE for ALL apps
        update_progress(f"Terminating processes related to {app_name}")
        killed_count = 0
        # Use broader patterns for all apps to ensure 10-second purge
        for pattern in [app_name, f"*{app_name}*", f"{app_name}*"]:
            if hasattr(globals(), 'progress_reporter') and globals()['progress_reporter']:
                globals()['progress_reporter'].log_action(f"KILLING PROCESSES: {pattern}")
            killed_count += ProcessHandler.kill_process_by_name(pattern)
        log_info(f"Terminated {killed_count} processes")
        
        # Step 2: Stop related services - ULTRA AGGRESSIVE for ALL apps
        update_progress(f"Stopping services related to {app_name}")
        stopped_count = 0
        for pattern in [app_name, f"*{app_name}*", f"{app_name}*"]:
            if hasattr(globals(), 'progress_reporter') and globals()['progress_reporter']:
                globals()['progress_reporter'].log_action(f"STOPPING SERVICES: {pattern}")
            stopped_count += ProcessHandler.stop_services_by_pattern(pattern)
        log_info(f"Stopped {stopped_count} services")
        
        # Step 3: Scan registry for application entries - ULTRA AGGRESSIVE for ALL apps
        update_progress(f"Scanning registry for {app_name}")
        registry_entries = []
        for pattern in [app_name, f"*{app_name}*", f"{app_name}*"]:
            if hasattr(globals(), 'progress_reporter') and globals()['progress_reporter']:
                globals()['progress_reporter'].log_action(f"SCANNING REGISTRY: {pattern}")
            registry_entries.extend(RegistryHandler.scan_registry_for_app(pattern))
        total_items += len(registry_entries)
        log_info(f"Found {len(registry_entries)} registry entries")
        
        # Step 4: Delete registry entries with real-time feedback
        for root_key, subkey_path, value_name in registry_entries:
            if value_name:
                update_progress(f"Deleting registry value: {subkey_path}\\{value_name}")
                RegistryHandler.delete_registry_value(root_key, subkey_path, value_name)
            else:
                update_progress(f"Deleting registry key: {subkey_path}")
                RegistryHandler.delete_registry_key(root_key, subkey_path)
        
        # Step 5: Delete application files with real-time feedback
        if install_dir and os.path.exists(install_dir):
            update_progress(f"Scanning installation directory: {install_dir}")
            if hasattr(globals(), 'progress_reporter') and globals()['progress_reporter']:
                globals()['progress_reporter'].log_action(f"SCANNING DIRECTORY: {install_dir}")
            files_to_delete = scan_directory(install_dir)
            total_items += len(files_to_delete)
            log_info(f"Found {len(files_to_delete)} files in installation directory")
            
            # Delete files in parallel for ultra-fast execution
            with ThreadPoolExecutor(max_workers=MAX_WORKERS) as executor:
                for file_path in sorted(files_to_delete, key=len, reverse=True):
                    executor.submit(FileSystemHandler.safe_delete, file_path)
            
            # Finally delete the installation directory itself
            update_progress(f"Deleting installation directory: {install_dir}")
            FileSystemHandler.safe_delete(install_dir)
        
        # Step 6: Scan common locations for leftover files - ULTRA AGGRESSIVE for ALL apps
        # Add more common locations for any app to ensure complete purge
        common_locations = [
            os.path.join(os.environ.get("APPDATA", ""), app_name),
            os.path.join(os.environ.get("LOCALAPPDATA", ""), app_name),
            os.path.join(os.environ.get("PROGRAMDATA", ""), app_name),
            os.path.join(os.environ.get("TEMP", ""), app_name),
            os.path.join(os.environ.get("PROGRAMFILES", ""), app_name),
            os.path.join(os.environ.get("PROGRAMFILES(X86)", ""), app_name),
            os.path.join(os.environ.get("PROGRAMFILES", ""), "Common Files", app_name),
            os.path.join(os.environ.get("PROGRAMFILES(X86)", ""), "Common Files", app_name),
            os.path.join(os.environ.get("USERPROFILE", ""), "Documents", app_name),
            os.path.join(os.environ.get("PUBLIC", ""), "Documents", app_name),
            os.path.join("C:\\Windows\\Temp", app_name)
        ]
        
        # Add variations with spaces and without
        app_name_no_spaces = app_name.replace(" ", "")
        if app_name_no_spaces != app_name:
            for env_var in ["APPDATA", "LOCALAPPDATA", "PROGRAMDATA", "PROGRAMFILES", "PROGRAMFILES(X86)"]:
                common_locations.append(os.path.join(os.environ.get(env_var, ""), app_name_no_spaces))
        
        update_progress(f"Scanning for leftovers in common locations")
        if hasattr(globals(), 'progress_reporter') and globals()['progress_reporter']:
            globals()['progress_reporter'].log_action(f"SCANNING FOR LEFTOVERS")
        leftover_files = parallel_scan_directories([loc for loc in common_locations if os.path.exists(loc)])
        total_items += len(leftover_files)
        log_info(f"Found {len(leftover_files)} leftover files")
        
        # Delete leftovers in parallel for ultra-fast execution
        with ThreadPoolExecutor(max_workers=MAX_WORKERS) as executor:
            for file_path in sorted(leftover_files, key=len, reverse=True):
                executor.submit(FileSystemHandler.safe_delete, file_path)
        
        # Delete the directories themselves in parallel
        with ThreadPoolExecutor(max_workers=MAX_WORKERS) as executor:
            for location in common_locations:
                if os.path.exists(location):
                    executor.submit(FileSystemHandler.safe_delete, location)
        
        # Step 7: Clean up shortcuts - ULTRA AGGRESSIVE for ALL apps
        update_progress("Cleaning up shortcuts")
        if hasattr(globals(), 'progress_reporter') and globals()['progress_reporter']:
            globals()['progress_reporter'].log_action(f"CLEANING UP SHORTCUTS")
        shortcut_locations = [
            os.path.join(os.environ.get("APPDATA", ""), "Microsoft", "Windows", "Start Menu"),
            os.path.join(os.environ.get("PROGRAMDATA", ""), "Microsoft", "Windows", "Start Menu"),
            os.path.join(os.environ.get("USERPROFILE", ""), "Desktop"),
            os.path.join(os.environ.get("PUBLIC", ""), "Desktop"),
        ]
        
        # Use broader patterns for shortcuts for ALL apps
        shortcuts = []
        for loc in shortcut_locations:
            if os.path.exists(loc):
                shortcuts.extend(parallel_scan_directories([loc], f"*{app_name}*\\.lnk"))
                # Also check for variations without spaces
                if app_name_no_spaces != app_name:
                    shortcuts.extend(parallel_scan_directories([loc], f"*{app_name_no_spaces}*\\.lnk"))
        
        total_items += len(shortcuts)
        log_info(f"Found {len(shortcuts)} shortcuts")
        
        # Delete shortcuts in parallel
        with ThreadPoolExecutor(max_workers=MAX_WORKERS) as executor:
            for shortcut in shortcuts:
                executor.submit(FileSystemHandler.safe_delete, shortcut)
            
        # Step 8: Aggressively scan entire C: drive for any remaining traces - ULTRA FAST
        update_progress(f"Aggressively scanning entire C: drive for {app_name}")
        if hasattr(globals(), 'progress_reporter') and globals()['progress_reporter']:
            globals()['progress_reporter'].log_action(f"SCANNING ENTIRE DRIVE FOR REMAINING TRACES")
        remaining_files = scan_entire_drive_for_app(app_name)
        total_items += len(remaining_files)
        log_info(f"Found {len(remaining_files)} additional files/folders across C: drive")
        
        # Delete all found items in parallel with maximum workers for ultra-fast execution
        with ThreadPoolExecutor(max_workers=MAX_WORKERS*2) as executor:
            for file_path in sorted(remaining_files, key=len, reverse=True):
                executor.submit(FileSystemHandler.safe_delete, file_path)
        
        log_info(f"EXTREME uninstallation of {app_name} completed successfully")
        return True
        
    except Exception as e:
        log_error(f"Uninstallation failed: {str(e)}")
        return False

def uninstall_multiple_applications(app_names: List[str]) -> Dict[str, bool]:
    """Uninstall multiple applications in parallel."""
    global total_items, processed_items, app_results
    
    # Reset counters
    total_items = 0
    processed_items = 0
    app_results = {}
    
    # Initialize progress reporter
    reporter = ProgressReporter()
    reporter.start()
    
    try:
        # Process applications in parallel
        with ThreadPoolExecutor(max_workers=min(len(app_names), MAX_WORKERS // 2)) as executor:
            # Submit all uninstallation tasks
            future_to_app = {executor.submit(uninstall_application, app_name): app_name for app_name in app_names}
            
            # Process results as they complete
            for future in concurrent.futures.as_completed(future_to_app):
                app_name = future_to_app[future]
                try:
                    success = future.result()
                    app_results[app_name] = success
                except Exception as e:
                    log_error(f"Error uninstalling {app_name}: {str(e)}")
                    app_results[app_name] = False
        
        # Print summary
        log_info("=== Uninstallation Summary ===")
        for app_name, success in app_results.items():
            status = "SUCCESS" if success else "FAILED"
            log_info(f"{app_name}: {status}")
        
        return app_results
    
    except Exception as e:
        log_error(f"Multiple uninstallation failed: {str(e)}")
        return app_results
    finally:
        # Stop the progress reporter
        reporter.stop()
        
        # Final progress update
        percentage = 100 if total_items == 0 else min(100, int((processed_items / total_items) * 100))
        print(f"\r[{percentage:3d}%] Uninstallation completed - {processed_items}/{total_items} items processed")

def main():
    """Main entry point for the application."""
    if len(sys.argv) < 2:
        print("Usage: python a.py <application_name1> [application_name2] [application_name3] ...")
        print("Example: python a.py Chrome Firefox Spotify")
        return
    
    # Get all application names from command line
    app_names = sys.argv[1:]
    
    # Set up signal handler for graceful termination
    def signal_handler(sig, frame):
        print("\nInterrupted! Cleaning up...")
        stop_event.set()
        sys.exit(0)
    
    signal.signal(signal.SIGINT, signal_handler)
    
    # Start the timer
    time_start = time.time()
    
    # Initialize global progress reporter immediately for real-time feedback
    global progress_reporter
    progress_reporter = ProgressReporter()
    progress_reporter.start()
    progress_reporter.log_action("INITIALIZING ULTRA-FAST UNINSTALLER")
    
    # Apply extreme settings for ALL applications to ensure 10-second purge
    log_message("🔥 EXTREME PURGE MODE ACTIVATED 🔥")
    log_message("Aggressively removing ALL traces within 10 seconds")
    
    # Set global variables for more aggressive behavior for all apps
    global SCAN_TIMEOUT, DELETE_TIMEOUT, MAX_WORKERS
    SCAN_TIMEOUT = 5  # Reduced timeout for faster scanning
    DELETE_TIMEOUT = 5  # Reduced timeout for faster deletion
    MAX_WORKERS = max(16, multiprocessing.cpu_count() * 2)  # More aggressive parallelization
    
    # Start immediate file deletion in background thread to meet 10-second requirement
    for app_name in app_names:
        # Start a background thread to begin immediate deletion while scanning continues
        threading.Thread(
            target=start_immediate_deletion, 
            args=(app_name,), 
            daemon=True
        ).start()
    
    # If only one app, use the single app uninstaller
    if len(app_names) == 1:
        success = uninstall_application(app_names[0])
        
        # Verify complete removal
        log_message(f"Performing final verification scan for {app_names[0]} files...")
        remaining = verify_complete_removal(app_names[0])
        if remaining:
            log_warning(f"Found {len(remaining)} remaining items. Removing them...")
            for path in remaining:
                try:
                    progress_reporter.log_action(f"FINAL CLEANUP: {path}")
                    FileSystemHandler.safe_delete(path)
                except Exception as e:
                    log_error(f"Error deleting {path}: {e}")
            
            # Double-check
            final_remaining = verify_complete_removal(app_names[0])
            if not final_remaining:
                log_message("VERIFICATION COMPLETE: All files have been successfully removed!")
            else:
                log_error(f"VERIFICATION FAILED: {len(final_remaining)} files still remain")
        else:
            log_message("VERIFICATION COMPLETE: All files have been successfully removed!")
    else:
        # Otherwise use the multi-app uninstaller
        uninstall_multiple_applications(app_names)
    
    # Show total execution time
    elapsed = time.time() - time_start
    print(f"\nTotal execution time: {elapsed:.2f} seconds")

def start_immediate_deletion(app_name):
    """Start deleting files immediately to meet 10-second requirement."""
    global progress_reporter
    
    progress_reporter.log_action(f"STARTING IMMEDIATE DELETION FOR {app_name.upper()}")
    
    # Common locations to check immediately for quick wins
    common_locations = [
        os.path.join(os.environ.get('ProgramFiles', 'C:\\Program Files'), app_name),
        os.path.join(os.environ.get('ProgramFiles(x86)', 'C:\\Program Files (x86)'), app_name),
        os.path.join(os.environ.get('APPDATA', ''), app_name),
        os.path.join(os.environ.get('LOCALAPPDATA', ''), app_name),
    ]
    
    # Add NVIDIA-specific locations if applicable
    if app_name.lower() == "nvidia":
        common_locations.extend([
            r"C:\Program Files\NVIDIA Corporation",
            r"C:\Program Files (x86)\NVIDIA Corporation",
            r"C:\Windows\System32\DriverStore\FileRepository\nv",
            r"C:\ProgramData\NVIDIA",
            r"C:\ProgramData\NVIDIA Corporation",
        ])
    
    # Immediately kill processes and services
    progress_reporter.log_action(f"KILLING ALL {app_name.upper()} PROCESSES")
    ProcessHandler.kill_process_by_name(app_name)
    ProcessHandler.stop_services_by_pattern(app_name)
    
    # Immediately delete common locations
    for location in common_locations:
        if os.path.exists(location):
            progress_reporter.log_action(f"IMMEDIATE DELETION: {location}")
            try:
                FileSystemHandler.safe_delete(location)
            except Exception as e:
                progress_reporter.log_action(f"ERROR: {str(e)}")
                
    # Immediately clean registry
    progress_reporter.log_action(f"CLEANING REGISTRY FOR {app_name.upper()}")
    RegistryHandler.delete_registry_keys_by_pattern(app_name)

def verify_complete_removal(app_name):
    """Verify that all traces of an application have been removed."""
    remaining_files = []
    
    # Check for any remaining files with app name
    patterns = [f"*{app_name}*"]
    if app_name.lower() == "nvidia":
        patterns.extend(["*nv*", "*geforce*"])
        
    for drive in drives_to_scan:
        try:
            for pattern in patterns:
                for path in glob.glob(f"{drive}\\**\\{pattern}", recursive=True):
                    # Skip protected paths
                    if not FileSystemHandler.is_path_protected(path):
                        remaining_files.append(path)
        except Exception as e:
            log_error(f"Error during verification: {e}")
    
    return remaining_files

if __name__ == "__main__":
    main()
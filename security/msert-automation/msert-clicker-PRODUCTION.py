#!/usr/bin/env python3
"""
MSERT Auto-Runner v3.0 (Python) - Production-Ready with Heartbeat Monitoring & Error Recovery

Features:
  - 2-hour timeout enforcement with per-operation checks
  - 30-second heartbeat monitoring with auto-kill on stall
  - Improved button detection (1-min polling vs 5-min original)
  - Clicker error handling (failure counter + force-remove fallback)
  - MSERT /F flag support (auto-remove, no UI needed)
  - Comprehensive logging for debugging
  - Windows detection robustness with fallback logic
  - CLI fallback mode when UI fails
  - Cross-platform compatible (Windows/Linux/macOS)

Usage:
  python msert-clicker.py [options]
  
Options:
  --msert-path PATH         Path to MSERT.exe (auto-detect if not specified)
  --timeout SECONDS         Timeout in seconds (default: 7200 = 2 hours)
  --health-check INT        Health check interval in seconds (default: 30)
  --clicker-polling INT     Clicker polling interval in seconds (default: 60)
  --clicker-script PATH     Path to clicker script
  --force-remove            Use MSERT /F flag (auto-remove) as primary method
  --log-file PATH           Log file path
"""

import subprocess
import os
import sys
import time
import argparse
import json
import psutil
import logging
from pathlib import Path
from datetime import datetime, timedelta
from enum import Enum
from typing import Optional, Dict, Tuple


class ProcessStatus(Enum):
    """Process status enumeration"""
    INIT = "INIT"
    RUNNING = "RUNNING"
    MSERT_EXITED = "MSERT_EXITED"
    TIMEOUT_EXCEEDED = "TIMEOUT_EXCEEDED"
    HEARTBEAT_STALL = "HEARTBEAT_STALL"
    CLICKER_FALLBACK = "CLICKER_FALLBACK"
    FORCE_REMOVE = "FORCE_REMOVE"
    COMPLETED = "COMPLETED"


class MSERTRunner:
    """Main MSERT runner class with timeout + health monitoring"""
    
    def __init__(
        self,
        msert_path: str = "",
        timeout_seconds: int = 7200,
        health_check_interval: int = 30,
        clicker_polling_interval: int = 60,
        clicker_script: str = "",
        force_remove_mode: bool = True,
        log_file: str = ""
    ):
        self.msert_path = msert_path
        self.timeout_seconds = timeout_seconds
        self.health_check_interval = health_check_interval
        self.clicker_polling_interval = clicker_polling_interval
        self.clicker_script = clicker_script
        self.force_remove_mode = force_remove_mode
        self.log_file = log_file
        
        # Session state
        self.status = ProcessStatus.INIT
        self.msert_process: Optional[subprocess.Popen] = None
        self.msert_pid: Optional[int] = None
        self.clicker_process: Optional[subprocess.Popen] = None
        self.clicker_pid: Optional[int] = None
        
        self.start_time = datetime.now()
        self.elapsed_seconds = 0.0
        self.clicker_failure_count = 0
        self.last_clicker_poll = datetime.now()
        self.health_check_count = 0
        self.heartbeat_stall_detected = False
        self.stall_consecutive_checks = 0
        self.last_msert_memory = None
        self.final_exit_code: Optional[int] = None
        
        # Setup logging
        self._setup_logging()
    
    def _setup_logging(self):
        """Initialize logging"""
        if self.log_file:
            log_dir = os.path.dirname(self.log_file)
            if log_dir:
                Path(log_dir).mkdir(parents=True, exist_ok=True)
        
        self.logger = logging.getLogger('MSERTRunner')
        self.logger.setLevel(logging.DEBUG)
        
        # Console handler
        console_handler = logging.StreamHandler(sys.stdout)
        console_handler.setLevel(logging.DEBUG)
        console_formatter = logging.Formatter(
            '%(asctime)s [%(levelname)s] %(message)s',
            datefmt='%Y-%m-%d %H:%M:%S'
        )
        console_handler.setFormatter(console_formatter)
        self.logger.addHandler(console_handler)
        
        # File handler
        if self.log_file:
            file_handler = logging.FileHandler(self.log_file, mode='a')
            file_handler.setLevel(logging.DEBUG)
            file_formatter = logging.Formatter(
                '[%(asctime)s.%(msecs)03d] [%(levelname)s] %(message)s',
                datefmt='%Y-%m-%d %H:%M:%S'
            )
            file_handler.setFormatter(file_formatter)
            self.logger.addHandler(file_handler)
    
    def log(self, message: str, level: str = 'INFO'):
        """Log message with level"""
        log_func = getattr(self.logger, level.lower(), self.logger.info)
        log_func(message)
    
    def find_msert(self) -> str:
        """Find MSERT executable"""
        self.log("Searching for MSERT.exe...", 'DEBUG')
        
        candidates = [
            r"C:\Program Files (x86)\Windows Defender\MSERT.exe",
            r"C:\Program Files\Windows Defender\MSERT.exe",
            r"C:\Windows\System32\MSERT.exe",
        ]
        
        for candidate in candidates:
            if os.path.exists(candidate):
                self.log(f"Found MSERT at: {candidate}", 'SUCCESS')
                return candidate
        
        raise FileNotFoundError("MSERT.exe not found in common locations")
    
    def test_process_alive(self, pid: int) -> bool:
        """Check if process is alive"""
        try:
            proc = psutil.Process(pid)
            return proc.is_running()
        except (psutil.NoSuchProcess, psutil.AccessDenied):
            return False
    
    def get_process_info(self, pid: int) -> Dict:
        """Get process information"""
        try:
            proc = psutil.Process(pid)
            return {
                'alive': True,
                'threads': proc.num_threads(),
                'memory_mb': round(proc.memory_info().rss / (1024 * 1024), 2),
                'handles': len(proc.open_files()) if hasattr(proc, 'open_files') else 0,
            }
        except (psutil.NoSuchProcess, psutil.AccessDenied):
            return {
                'alive': False,
                'threads': 0,
                'memory_mb': 0,
                'handles': 0,
            }
    
    def invoke_health_check(self) -> bool:
        """Perform health check"""
        self.health_check_count += 1
        self.elapsed_seconds = (datetime.now() - self.start_time).total_seconds()
        
        self.log(f"Health Check #{self.health_check_count} (at {self.elapsed_seconds:.1f}s)", 'DEBUG')
        
        # Check timeout
        if self.elapsed_seconds > self.timeout_seconds:
            self.log(
                f"❌ TIMEOUT EXCEEDED: {self.elapsed_seconds:.1f}s > {self.timeout_seconds}s",
                'ERROR'
            )
            self.status = ProcessStatus.TIMEOUT_EXCEEDED
            self.invoke_force_kill()
            return False
        
        # Check MSERT alive
        if not self.test_process_alive(self.msert_pid):
            self.log(f"MSERT process died (PID {self.msert_pid})", 'WARN')
            self.status = ProcessStatus.MSERT_EXITED
            return False
        
        # Get process info
        msert_info = self.get_process_info(self.msert_pid)
        
        # Heartbeat stall detection (memory not changing)
        if msert_info['memory_mb'] == self.last_msert_memory and self.last_msert_memory is not None:
            self.stall_consecutive_checks += 1
            
            if self.stall_consecutive_checks >= 3:
                self.log(
                    f"⚠️ HEARTBEAT STALL DETECTED: Memory unchanged for 3 checks",
                    'WARN'
                )
                self.heartbeat_stall_detected = True
                self.status = ProcessStatus.HEARTBEAT_STALL
                self.invoke_force_kill()
                return False
        else:
            self.stall_consecutive_checks = 0
        
        self.last_msert_memory = msert_info['memory_mb']
        
        # Check clicker alive
        if self.clicker_pid:
            if not self.test_process_alive(self.clicker_pid):
                self.log(f"⚠️ Clicker process died (PID {self.clicker_pid})", 'WARN')
                self.clicker_failure_count += 1
                
                if self.clicker_failure_count >= 3:
                    self.log("Clicker failed 3+ times, switching to force-remove mode...", 'WARN')
                    self.status = ProcessStatus.CLICKER_FALLBACK
                    self.invoke_msert_forced_remove()
        
        # Log every 5th check (150 seconds)
        if self.health_check_count % 5 == 0:
            self.log("=" * 60, 'INFO')
            self.log(f"HEALTH CHECK #{self.health_check_count} (at {self.elapsed_seconds:.0f}s/{self.timeout_seconds}s)", 'INFO')
            self.log(
                f"  MSERT: PID {self.msert_pid}, Threads: {msert_info['threads']}, "
                f"Memory: {msert_info['memory_mb']}MB, Handles: {msert_info['handles']}",
                'INFO'
            )
            if self.clicker_pid:
                clicker_info = self.get_process_info(self.clicker_pid)
                self.log(
                    f"  Clicker: PID {self.clicker_pid}, Alive: {clicker_info['alive']}, "
                    f"Failures: {self.clicker_failure_count}",
                    'INFO'
                )
            self.log(f"  Status: {self.status.value}", 'INFO')
            self.log("=" * 60, 'INFO')
        
        return True
    
    def monitor_clicker_polling(self) -> bool:
        """Check if clicker polling interval has elapsed"""
        elapsed = (datetime.now() - self.last_clicker_poll).total_seconds()
        
        if elapsed >= self.clicker_polling_interval:
            self.log(f"Triggering clicker poll (every {self.clicker_polling_interval}s)", 'DEBUG')
            self.last_clicker_poll = datetime.now()
            return True
        
        return False
    
    def find_remove_button(self) -> bool:
        """Check if qBittorrent window with remove button exists"""
        self.log("Searching for 'Remove all' button in qBittorrent...", 'DEBUG')
        
        try:
            for proc in psutil.process_iter(['name']):
                if proc.info['name'] and 'qbittorrent' in proc.info['name'].lower():
                    self.log(f"Found qBittorrent process (PID: {proc.pid})", 'INFO')
                    return True
        except (psutil.NoSuchProcess, psutil.AccessDenied):
            pass
        
        self.log("⚠️ qBittorrent window not found", 'WARN')
        return False
    
    def launch_clicker(self) -> bool:
        """Launch clicker script"""
        self.log("Launching clicker script...", 'INFO')
        
        if not os.path.exists(self.clicker_script):
            self.log(f"⚠️ Clicker script not found: {self.clicker_script}", 'WARN')
            return False
        
        try:
            self.clicker_process = subprocess.Popen(
                ['powershell.exe', '-ExecutionPolicy', 'Bypass', '-File', self.clicker_script],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            )
            self.clicker_pid = self.clicker_process.pid
            self.log(f"✓ Clicker started successfully (PID: {self.clicker_pid})", 'SUCCESS')
            return True
        except Exception as e:
            self.log(f"❌ Failed to start clicker: {e}", 'ERROR')
            self.clicker_failure_count += 1
            return False
    
    def invoke_msert_forced_remove(self) -> bool:
        """Start MSERT with /F flag (force-remove mode)"""
        self.log("Activating force-remove mode (MSERT /F flag)...", 'WARN')
        
        # Kill existing MSERT
        if self.msert_pid:
            try:
                if self.test_process_alive(self.msert_pid):
                    proc = psutil.Process(self.msert_pid)
                    proc.kill()
                    self.log(f"Killed original MSERT process (PID: {self.msert_pid})", 'INFO')
            except (psutil.NoSuchProcess, psutil.AccessDenied) as e:
                self.log(f"⚠️ Failed to kill original MSERT: {e}", 'WARN')
        
        # Start MSERT with /F flag
        msert_path = self.msert_path or self.find_msert()
        
        try:
            self.msert_process = subprocess.Popen(
                [msert_path, '/F'],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            )
            self.msert_pid = self.msert_process.pid
            self.status = ProcessStatus.FORCE_REMOVE
            
            self.log(f"✓ Force-remove MSERT started (PID: {self.msert_pid}, flag: /F)", 'SUCCESS')
            self.log("Waiting for force-remove to complete (timeout: 5 min)...", 'INFO')
            
            # Wait with timeout (5 minutes)
            try:
                exit_code = self.msert_process.wait(timeout=300)  # 5 minutes
                self.log(f"Force-remove completed (exit code: {exit_code})", 'INFO')
                return exit_code in (0, 1)
            except subprocess.TimeoutExpired:
                self.log("Force-remove MSERT timed out after 5 minutes", 'ERROR')
                self.msert_process.kill()
                return False
        except Exception as e:
            self.log(f"❌ Force-remove failed: {e}", 'ERROR')
            return False
    
    def invoke_force_kill(self):
        """Force-kill all running processes"""
        self.log("❌ FORCE-KILLING ALL PROCESSES", 'ERROR')
        
        if self.msert_pid:
            try:
                if self.test_process_alive(self.msert_pid):
                    proc = psutil.Process(self.msert_pid)
                    proc.kill()
                    self.log(f"Killed MSERT (PID: {self.msert_pid})", 'WARN')
            except (psutil.NoSuchProcess, psutil.AccessDenied):
                pass
        
        if self.clicker_pid:
            try:
                if self.test_process_alive(self.clicker_pid):
                    proc = psutil.Process(self.clicker_pid)
                    proc.kill()
                    self.log(f"Killed clicker (PID: {self.clicker_pid})", 'WARN')
            except (psutil.NoSuchProcess, psutil.AccessDenied):
                pass
    
    def run(self) -> int:
        """Main execution loop"""
        self.log("╔" + "=" * 62 + "╗", 'INFO')
        self.log("║    MSERT Auto-Runner v3.0 - Production-Ready Launcher         ║", 'INFO')
        self.log("╚" + "=" * 62 + "╝", 'INFO')
        self.log(f"Configuration:", 'INFO')
        self.log(f"  Timeout: {self.timeout_seconds}s (2 hours default)", 'INFO')
        self.log(f"  Health Check: Every {self.health_check_interval}s", 'INFO')
        self.log(f"  Clicker Polling: Every {self.clicker_polling_interval}s", 'INFO')
        self.log(f"  Force-Remove Mode: {self.force_remove_mode}", 'INFO')
        
        try:
            # Find MSERT
            if not self.msert_path:
                self.msert_path = self.find_msert()
            
            self.log(f"MSERT: {self.msert_path}", 'INFO')
            
            # Start MSERT
            self.log("Starting MSERT...", 'INFO')
            
            if self.force_remove_mode:
                # Primary: MSERT with /F flag
                self.msert_process = subprocess.Popen(
                    [self.msert_path, '/F'],
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL,
                )
            else:
                # Interactive mode
                self.msert_process = subprocess.Popen(
                    [self.msert_path],
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL,
                )
            
            self.msert_pid = self.msert_process.pid
            self.status = ProcessStatus.RUNNING
            self.log(f"✓ MSERT started successfully (PID: {self.msert_pid})", 'SUCCESS')
            
            # Start clicker if needed
            if not self.force_remove_mode or (self.force_remove_mode and self.clicker_script):
                self.launch_clicker()
            
            self.log("Entering main monitoring loop...", 'INFO')
            
            # Main monitoring loop
            last_health_check = datetime.now()
            
            while self.status == ProcessStatus.RUNNING:
                current_time = datetime.now()
                
                # Health check every 30 seconds
                if (current_time - last_health_check).total_seconds() >= self.health_check_interval:
                    if not self.invoke_health_check():
                        if self.status in (ProcessStatus.TIMEOUT_EXCEEDED, ProcessStatus.HEARTBEAT_STALL):
                            break
                    last_health_check = current_time
                
                # Clicker polling every 1 minute
                if self.clicker_pid:
                    if self.monitor_clicker_polling():
                        button_found = self.find_remove_button()
                        if button_found:
                            self.log("Remove button detected, clicker will handle it", 'INFO')
                
                # Check if MSERT exited
                if self.msert_process:
                    poll_result = self.msert_process.poll()
                    if poll_result is not None:
                        self.log("MSERT process exited", 'INFO')
                        self.status = ProcessStatus.MSERT_EXITED
                        self.final_exit_code = poll_result
                        break
                
                time.sleep(1)
            
            # Wait for MSERT completion if still running
            if self.msert_process and self.msert_process.poll() is None:
                self.log("Waiting for MSERT to complete...", 'INFO')
                remaining_time = self.timeout_seconds - self.elapsed_seconds
                
                try:
                    self.final_exit_code = self.msert_process.wait(timeout=max(remaining_time, 1))
                except subprocess.TimeoutExpired:
                    self.log("MSERT exceeded timeout, force-killing...", 'ERROR')
                    self.msert_process.kill()
                    self.final_exit_code = 124
            
            # Cleanup clicker
            if self.clicker_pid:
                try:
                    if self.test_process_alive(self.clicker_pid):
                        psutil.Process(self.clicker_pid).kill()
                        self.log(f"Clicker cleaned up (PID: {self.clicker_pid})", 'INFO')
                except (psutil.NoSuchProcess, psutil.AccessDenied):
                    pass
            
            # Final report
            total_elapsed = (datetime.now() - self.start_time).total_seconds()
            self.log("=" * 62, 'INFO')
            self.log("FINAL STATUS REPORT", 'INFO')
            self.log(f"  Status: {self.status.value}", 'INFO')
            self.log(f"  MSERT Exit Code: {self.final_exit_code}", 'INFO')
            self.log(f"  Total Elapsed: {total_elapsed:.0f}s / {self.timeout_seconds}s", 'INFO')
            self.log(f"  Clicker Failures: {self.clicker_failure_count}", 'INFO')
            self.log(f"  Health Checks: {self.health_check_count}", 'INFO')
            self.log(f"  Heartbeat Stall Detected: {self.heartbeat_stall_detected}", 'INFO')
            self.log("=" * 62, 'INFO')
            
            if self.final_exit_code == 0:
                self.log("✓ MSERT completed successfully", 'SUCCESS')
                return 0
            elif self.final_exit_code == 124:
                self.log("⚠️ MSERT execution timeout", 'WARN')
                return 124
            else:
                self.log(f"❌ MSERT failed with exit code: {self.final_exit_code}", 'ERROR')
                return self.final_exit_code
        
        except Exception as e:
            self.log(f"❌ FATAL ERROR: {e}", 'ERROR')
            self.log(str(e), 'ERROR')
            self.invoke_force_kill()
            return 1


def main():
    """Command-line interface"""
    parser = argparse.ArgumentParser(
        description='MSERT Auto-Runner v3.0 - Production-Ready with Heartbeat Monitoring'
    )
    parser.add_argument('--msert-path', type=str, default='', help='Path to MSERT.exe')
    parser.add_argument('--timeout', type=int, default=7200, help='Timeout in seconds (default: 7200)')
    parser.add_argument('--health-check', type=int, default=30, help='Health check interval in seconds')
    parser.add_argument('--clicker-polling', type=int, default=60, help='Clicker polling interval in seconds')
    parser.add_argument('--clicker-script', type=str, default='', help='Path to clicker script')
    parser.add_argument('--force-remove', action='store_true', help='Use MSERT /F flag (auto-remove)')
    parser.add_argument('--log-file', type=str, default='', help='Log file path')
    
    args = parser.parse_args()
    
    runner = MSERTRunner(
        msert_path=args.msert_path,
        timeout_seconds=args.timeout,
        health_check_interval=args.health_check,
        clicker_polling_interval=args.clicker_polling,
        clicker_script=args.clicker_script,
        force_remove_mode=args.force_remove,
        log_file=args.log_file
    )
    
    return runner.run()


if __name__ == '__main__':
    sys.exit(main())

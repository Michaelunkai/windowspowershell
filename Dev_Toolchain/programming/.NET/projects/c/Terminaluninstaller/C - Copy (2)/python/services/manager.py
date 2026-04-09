"""
Service manager for Ultimate Uninstaller
Windows service control and management
"""

import subprocess
import winreg
import ctypes
import time
from typing import List, Dict, Optional, Tuple, Any
from dataclasses import dataclass
from enum import Enum
import sys
import os

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from core.logger import Logger
from core.exceptions import ServiceError
from core.admin import AdminHelper
from .scanner import ServiceInfo, ServiceState, ServiceStartType


class ServiceControl(Enum):
    """Service control commands"""
    START = 'start'
    STOP = 'stop'
    RESTART = 'restart'
    PAUSE = 'pause'
    CONTINUE = 'continue'


class ServiceManager:
    """Windows service manager"""

    SC_MANAGER_ALL_ACCESS = 0xF003F
    SERVICE_ALL_ACCESS = 0xF01FF
    SERVICE_QUERY_STATUS = 0x0004
    SERVICE_START = 0x0010
    SERVICE_STOP = 0x0020

    SERVICE_CONTROL_STOP = 0x01
    SERVICE_CONTROL_PAUSE = 0x02
    SERVICE_CONTROL_CONTINUE = 0x03

    def __init__(self, logger: Logger = None):
        self.logger = logger or Logger.get_instance()
        self._is_admin = AdminHelper.is_admin()

    def control_service(self, name: str, action: ServiceControl) -> Tuple[bool, str]:
        """Control a service"""
        try:
            if action == ServiceControl.START:
                return self.start_service(name)
            elif action == ServiceControl.STOP:
                return self.stop_service(name)
            elif action == ServiceControl.RESTART:
                return self.restart_service(name)
            elif action == ServiceControl.PAUSE:
                return self.pause_service(name)
            elif action == ServiceControl.CONTINUE:
                return self.continue_service(name)
            else:
                return False, f"Unknown action: {action}"
        except Exception as e:
            return False, str(e)

    def start_service(self, name: str) -> Tuple[bool, str]:
        """Start a service"""
        try:
            result = subprocess.run(
                ['sc', 'start', name],
                capture_output=True, text=True, timeout=60
            )

            if result.returncode == 0:
                return True, "Service started"
            elif 'already' in result.stdout.lower():
                return True, "Service already running"
            else:
                return False, result.stderr.strip() or result.stdout.strip()

        except subprocess.TimeoutExpired:
            return False, "Start operation timed out"
        except Exception as e:
            return False, str(e)

    def stop_service(self, name: str, timeout: int = 30) -> Tuple[bool, str]:
        """Stop a service"""
        try:
            result = subprocess.run(
                ['sc', 'stop', name],
                capture_output=True, text=True, timeout=timeout
            )

            if result.returncode == 0:
                start_time = time.time()
                while time.time() - start_time < timeout:
                    state = self.get_service_state(name)
                    if state == ServiceState.STOPPED:
                        return True, "Service stopped"
                    time.sleep(1)

                return True, "Stop command sent"

            elif 'not started' in result.stdout.lower():
                return True, "Service not running"
            else:
                return False, result.stderr.strip() or result.stdout.strip()

        except subprocess.TimeoutExpired:
            return False, "Stop operation timed out"
        except Exception as e:
            return False, str(e)

    def restart_service(self, name: str) -> Tuple[bool, str]:
        """Restart a service"""
        stop_success, stop_msg = self.stop_service(name)

        if not stop_success and 'not running' not in stop_msg.lower():
            return False, f"Failed to stop: {stop_msg}"

        time.sleep(1)

        return self.start_service(name)

    def pause_service(self, name: str) -> Tuple[bool, str]:
        """Pause a service"""
        try:
            result = subprocess.run(
                ['sc', 'pause', name],
                capture_output=True, text=True, timeout=30
            )

            if result.returncode == 0:
                return True, "Service paused"
            else:
                return False, result.stderr.strip() or result.stdout.strip()

        except Exception as e:
            return False, str(e)

    def continue_service(self, name: str) -> Tuple[bool, str]:
        """Continue a paused service"""
        try:
            result = subprocess.run(
                ['sc', 'continue', name],
                capture_output=True, text=True, timeout=30
            )

            if result.returncode == 0:
                return True, "Service continued"
            else:
                return False, result.stderr.strip() or result.stdout.strip()

        except Exception as e:
            return False, str(e)

    def get_service_state(self, name: str) -> ServiceState:
        """Get current service state"""
        try:
            result = subprocess.run(
                ['sc', 'query', name],
                capture_output=True, text=True, timeout=10
            )

            if result.returncode == 0:
                output = result.stdout.lower()
                if 'running' in output:
                    return ServiceState.RUNNING
                elif 'stopped' in output:
                    return ServiceState.STOPPED
                elif 'paused' in output:
                    return ServiceState.PAUSED
                elif 'start_pending' in output:
                    return ServiceState.START_PENDING
                elif 'stop_pending' in output:
                    return ServiceState.STOP_PENDING

            return ServiceState.UNKNOWN

        except:
            return ServiceState.UNKNOWN

    def set_start_type(self, name: str, start_type: ServiceStartType) -> Tuple[bool, str]:
        """Set service start type"""
        type_map = {
            ServiceStartType.AUTO: 'auto',
            ServiceStartType.MANUAL: 'demand',
            ServiceStartType.DISABLED: 'disabled',
            ServiceStartType.BOOT: 'boot',
            ServiceStartType.SYSTEM: 'system',
        }

        type_name = type_map.get(start_type, 'demand')

        try:
            result = subprocess.run(
                ['sc', 'config', name, 'start=', type_name],
                capture_output=True, text=True, timeout=30
            )

            if result.returncode == 0:
                return True, f"Start type set to {type_name}"
            else:
                return False, result.stderr.strip()

        except Exception as e:
            return False, str(e)

    def delete_service(self, name: str) -> Tuple[bool, str]:
        """Delete a service"""
        self.stop_service(name)

        try:
            result = subprocess.run(
                ['sc', 'delete', name],
                capture_output=True, text=True, timeout=30
            )

            if result.returncode == 0:
                return True, "Service deleted"
            elif 'does not exist' in result.stderr.lower():
                return True, "Service does not exist"
            else:
                return False, result.stderr.strip()

        except Exception as e:
            return False, str(e)

    def create_service(self, name: str, display_name: str, binary_path: str,
                      start_type: ServiceStartType = ServiceStartType.MANUAL,
                      dependencies: List[str] = None) -> Tuple[bool, str]:
        """Create a new service"""
        type_map = {
            ServiceStartType.AUTO: 'auto',
            ServiceStartType.MANUAL: 'demand',
            ServiceStartType.DISABLED: 'disabled',
        }

        type_name = type_map.get(start_type, 'demand')

        cmd = [
            'sc', 'create', name,
            'binPath=', binary_path,
            'DisplayName=', display_name,
            'start=', type_name,
        ]

        if dependencies:
            cmd.extend(['depend=', '/'.join(dependencies)])

        try:
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)

            if result.returncode == 0:
                return True, "Service created"
            else:
                return False, result.stderr.strip()

        except Exception as e:
            return False, str(e)

    def get_dependent_services(self, name: str) -> List[str]:
        """Get services dependent on this service"""
        dependents = []

        try:
            result = subprocess.run(
                ['sc', 'enumdepend', name],
                capture_output=True, text=True, timeout=30
            )

            if result.returncode == 0:
                for line in result.stdout.split('\n'):
                    if 'SERVICE_NAME:' in line:
                        dep_name = line.split(':')[-1].strip()
                        if dep_name:
                            dependents.append(dep_name)

        except:
            pass

        return dependents

    def stop_dependent_services(self, name: str) -> int:
        """Stop all services dependent on this one"""
        stopped = 0
        dependents = self.get_dependent_services(name)

        for dep in dependents:
            success, _ = self.stop_service(dep)
            if success:
                stopped += 1

        return stopped

    def get_service_config(self, name: str) -> Dict[str, Any]:
        """Get detailed service configuration"""
        config = {}

        try:
            result = subprocess.run(
                ['sc', 'qc', name],
                capture_output=True, text=True, timeout=10
            )

            if result.returncode == 0:
                for line in result.stdout.split('\n'):
                    if ':' in line:
                        parts = line.split(':', 1)
                        key = parts[0].strip()
                        value = parts[1].strip() if len(parts) > 1 else ''
                        config[key] = value

        except:
            pass

        return config

    def service_exists(self, name: str) -> bool:
        """Check if service exists"""
        try:
            result = subprocess.run(
                ['sc', 'query', name],
                capture_output=True, timeout=10
            )
            return result.returncode == 0
        except:
            return False

    def wait_for_state(self, name: str, target_state: ServiceState,
                      timeout: int = 30) -> bool:
        """Wait for service to reach target state"""
        start_time = time.time()

        while time.time() - start_time < timeout:
            current = self.get_service_state(name)
            if current == target_state:
                return True
            time.sleep(1)

        return False

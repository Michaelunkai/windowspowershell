"""
Driver manager for Ultimate Uninstaller
Windows driver control and management
"""

import subprocess
import winreg
import os
import shutil
from typing import List, Dict, Optional, Tuple, Any
from enum import Enum
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from core.logger import Logger
from core.admin import AdminHelper
from .scanner import DriverInfo, DriverState, DriverType


class DriverManager:
    """Windows driver manager"""

    DRIVER_STORE = os.path.join(
        os.environ.get('SYSTEMROOT', r'C:\Windows'),
        'System32', 'DriverStore', 'FileRepository'
    )

    def __init__(self, logger: Logger = None):
        self.logger = logger or Logger.get_instance()
        self._is_admin = AdminHelper.is_admin()

    def start_driver(self, name: str) -> Tuple[bool, str]:
        """Start a driver"""
        try:
            result = subprocess.run(
                ['sc', 'start', name],
                capture_output=True, text=True, timeout=60
            )

            if result.returncode == 0:
                return True, "Driver started"
            elif 'already' in result.stdout.lower():
                return True, "Driver already running"
            else:
                return False, result.stderr.strip() or result.stdout.strip()

        except subprocess.TimeoutExpired:
            return False, "Start operation timed out"
        except Exception as e:
            return False, str(e)

    def stop_driver(self, name: str) -> Tuple[bool, str]:
        """Stop a driver"""
        try:
            result = subprocess.run(
                ['sc', 'stop', name],
                capture_output=True, text=True, timeout=30
            )

            if result.returncode == 0:
                return True, "Driver stopped"
            elif 'not started' in result.stdout.lower():
                return True, "Driver not running"
            else:
                return False, result.stderr.strip() or result.stdout.strip()

        except subprocess.TimeoutExpired:
            return False, "Stop operation timed out"
        except Exception as e:
            return False, str(e)

    def delete_driver(self, name: str) -> Tuple[bool, str]:
        """Delete a driver"""
        self.stop_driver(name)

        try:
            result = subprocess.run(
                ['sc', 'delete', name],
                capture_output=True, text=True, timeout=30
            )

            if result.returncode == 0:
                return True, "Driver deleted"
            elif 'does not exist' in result.stderr.lower():
                return True, "Driver does not exist"
            else:
                return False, result.stderr.strip()

        except Exception as e:
            return False, str(e)

    def disable_driver(self, name: str) -> Tuple[bool, str]:
        """Disable a driver"""
        try:
            self.stop_driver(name)

            result = subprocess.run(
                ['sc', 'config', name, 'start=', 'disabled'],
                capture_output=True, text=True, timeout=30
            )

            if result.returncode == 0:
                return True, "Driver disabled"
            else:
                return False, result.stderr.strip()

        except Exception as e:
            return False, str(e)

    def set_start_type(self, name: str, start_type: int) -> Tuple[bool, str]:
        """Set driver start type"""
        type_map = {
            0: 'boot',
            1: 'system',
            2: 'auto',
            3: 'demand',
            4: 'disabled',
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

    def get_driver_state(self, name: str) -> DriverState:
        """Get current driver state"""
        try:
            result = subprocess.run(
                ['sc', 'query', name],
                capture_output=True, text=True, timeout=10
            )

            if result.returncode == 0:
                output = result.stdout.lower()
                if 'running' in output:
                    return DriverState.RUNNING
                elif 'stopped' in output:
                    return DriverState.STOPPED

            return DriverState.UNKNOWN

        except:
            return DriverState.UNKNOWN

    def install_driver(self, inf_path: str) -> Tuple[bool, str]:
        """Install driver from INF file"""
        if not os.path.exists(inf_path):
            return False, "INF file not found"

        try:
            result = subprocess.run(
                ['pnputil', '/add-driver', inf_path, '/install'],
                capture_output=True, text=True, timeout=120
            )

            if result.returncode == 0:
                return True, "Driver installed"
            else:
                return False, result.stderr.strip() or result.stdout.strip()

        except Exception as e:
            return False, str(e)

    def uninstall_driver_package(self, inf_name: str) -> Tuple[bool, str]:
        """Uninstall driver package"""
        try:
            result = subprocess.run(
                ['pnputil', '/delete-driver', inf_name, '/uninstall', '/force'],
                capture_output=True, text=True, timeout=120
            )

            if result.returncode == 0:
                return True, "Driver package removed"
            else:
                return False, result.stderr.strip() or result.stdout.strip()

        except Exception as e:
            return False, str(e)

    def list_driver_packages(self) -> List[Dict[str, str]]:
        """List installed driver packages"""
        packages = []

        try:
            result = subprocess.run(
                ['pnputil', '/enum-drivers'],
                capture_output=True, text=True, timeout=60
            )

            if result.returncode == 0:
                current = {}
                for line in result.stdout.split('\n'):
                    line = line.strip()
                    if ':' in line:
                        key, value = line.split(':', 1)
                        current[key.strip()] = value.strip()
                    elif not line and current:
                        packages.append(current)
                        current = {}

                if current:
                    packages.append(current)

        except:
            pass

        return packages

    def find_driver_package(self, pattern: str) -> List[Dict[str, str]]:
        """Find driver packages matching pattern"""
        packages = self.list_driver_packages()
        pattern_lower = pattern.lower()

        return [
            p for p in packages
            if any(pattern_lower in str(v).lower() for v in p.values())
        ]

    def clean_driver_store(self, pattern: str) -> Tuple[int, List[str]]:
        """Clean driver store packages matching pattern"""
        cleaned = 0
        deleted = []

        if not os.path.exists(self.DRIVER_STORE):
            return 0, []

        try:
            for entry in os.scandir(self.DRIVER_STORE):
                if entry.is_dir() and pattern.lower() in entry.name.lower():
                    try:
                        shutil.rmtree(entry.path)
                        cleaned += 1
                        deleted.append(entry.path)
                    except:
                        pass
        except:
            pass

        return cleaned, deleted

    def get_driver_files(self, name: str) -> List[str]:
        """Get files associated with a driver"""
        files = []

        try:
            key_path = f"SYSTEM\\CurrentControlSet\\Services\\{name}"
            key = winreg.OpenKey(
                winreg.HKEY_LOCAL_MACHINE,
                key_path, 0, winreg.KEY_READ
            )

            try:
                image_path, _ = winreg.QueryValueEx(key, "ImagePath")
                resolved = self._resolve_path(image_path)
                if resolved and os.path.exists(resolved):
                    files.append(resolved)
            except:
                pass

            winreg.CloseKey(key)

        except:
            pass

        return files

    def _resolve_path(self, path: str) -> Optional[str]:
        """Resolve driver image path"""
        if not path:
            return None

        if path.startswith('\\SystemRoot'):
            system_root = os.environ.get('SYSTEMROOT', r'C:\Windows')
            return path.replace('\\SystemRoot', system_root)
        elif path.startswith('System32'):
            system_root = os.environ.get('SYSTEMROOT', r'C:\Windows')
            return os.path.join(system_root, path)
        elif path.startswith('\\??\\'):
            return path[4:]

        return path

    def driver_exists(self, name: str) -> bool:
        """Check if driver exists"""
        try:
            result = subprocess.run(
                ['sc', 'query', name],
                capture_output=True, timeout=10
            )
            return result.returncode == 0
        except:
            return False

    def export_driver_list(self) -> List[Dict[str, Any]]:
        """Export list of all drivers with details"""
        drivers = []

        try:
            result = subprocess.run(
                ['driverquery', '/v', '/fo', 'csv'],
                capture_output=True, text=True, timeout=60
            )

            if result.returncode == 0:
                lines = result.stdout.strip().split('\n')
                if len(lines) > 1:
                    import csv
                    from io import StringIO
                    reader = csv.DictReader(StringIO(result.stdout))
                    drivers = list(reader)

        except:
            pass

        return drivers

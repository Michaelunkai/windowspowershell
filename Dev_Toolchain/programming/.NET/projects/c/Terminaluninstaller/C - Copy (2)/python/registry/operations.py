"""
Registry operations for Ultimate Uninstaller
Low-level registry operations with safety checks
"""

import winreg
import ctypes
from typing import List, Dict, Optional, Tuple, Any, Union
from dataclasses import dataclass
import sys
import os

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from core.logger import Logger
from core.exceptions import RegistryError
from core.admin import AdminHelper


@dataclass
class RegistryValueInfo:
    """Registry value information"""
    name: str
    data: Any
    value_type: int
    type_name: str


class RegistryOperations:
    """Low-level registry operations"""

    HIVE_MAP = {
        'HKLM': winreg.HKEY_LOCAL_MACHINE,
        'HKEY_LOCAL_MACHINE': winreg.HKEY_LOCAL_MACHINE,
        'HKCU': winreg.HKEY_CURRENT_USER,
        'HKEY_CURRENT_USER': winreg.HKEY_CURRENT_USER,
        'HKCR': winreg.HKEY_CLASSES_ROOT,
        'HKEY_CLASSES_ROOT': winreg.HKEY_CLASSES_ROOT,
        'HKU': winreg.HKEY_USERS,
        'HKEY_USERS': winreg.HKEY_USERS,
        'HKCC': winreg.HKEY_CURRENT_CONFIG,
        'HKEY_CURRENT_CONFIG': winreg.HKEY_CURRENT_CONFIG,
    }

    TYPE_NAMES = {
        winreg.REG_SZ: "REG_SZ",
        winreg.REG_EXPAND_SZ: "REG_EXPAND_SZ",
        winreg.REG_BINARY: "REG_BINARY",
        winreg.REG_DWORD: "REG_DWORD",
        winreg.REG_DWORD_BIG_ENDIAN: "REG_DWORD_BIG_ENDIAN",
        winreg.REG_LINK: "REG_LINK",
        winreg.REG_MULTI_SZ: "REG_MULTI_SZ",
        winreg.REG_QWORD: "REG_QWORD",
        winreg.REG_NONE: "REG_NONE",
    }

    def __init__(self, logger: Logger = None):
        self.logger = logger or Logger.get_instance()
        self._is_admin = AdminHelper.is_admin()

    def parse_key_path(self, full_path: str) -> Tuple[int, str]:
        """Parse full key path into hive and subkey"""
        parts = full_path.split('\\', 1)

        if len(parts) < 1:
            raise RegistryError("Invalid key path", key_path=full_path)

        hive_name = parts[0].upper()
        subkey = parts[1] if len(parts) > 1 else ""

        hive = self.HIVE_MAP.get(hive_name)
        if hive is None:
            raise RegistryError(f"Unknown hive: {hive_name}", key_path=full_path)

        return hive, subkey

    def key_exists(self, hive: int, path: str) -> bool:
        """Check if registry key exists"""
        try:
            key = winreg.OpenKey(hive, path, 0, winreg.KEY_READ)
            winreg.CloseKey(key)
            return True
        except FileNotFoundError:
            return False
        except PermissionError:
            return True
        except:
            return False

    def value_exists(self, hive: int, path: str, value_name: str) -> bool:
        """Check if registry value exists"""
        try:
            key = winreg.OpenKey(hive, path, 0, winreg.KEY_READ)
            winreg.QueryValueEx(key, value_name)
            winreg.CloseKey(key)
            return True
        except FileNotFoundError:
            return False
        except:
            return False

    def get_value(self, hive: int, path: str, value_name: str,
                 default: Any = None) -> Any:
        """Get registry value"""
        try:
            key = winreg.OpenKey(hive, path, 0, winreg.KEY_READ)
            data, _ = winreg.QueryValueEx(key, value_name)
            winreg.CloseKey(key)
            return data
        except:
            return default

    def get_value_info(self, hive: int, path: str,
                      value_name: str) -> Optional[RegistryValueInfo]:
        """Get detailed value information"""
        try:
            key = winreg.OpenKey(hive, path, 0, winreg.KEY_READ)
            data, value_type = winreg.QueryValueEx(key, value_name)
            winreg.CloseKey(key)

            return RegistryValueInfo(
                name=value_name,
                data=data,
                value_type=value_type,
                type_name=self.TYPE_NAMES.get(value_type, "UNKNOWN")
            )
        except:
            return None

    def set_value(self, hive: int, path: str, value_name: str,
                 data: Any, value_type: int = None) -> bool:
        """Set registry value"""
        if value_type is None:
            value_type = self._infer_type(data)

        try:
            key = winreg.OpenKey(hive, path, 0, winreg.KEY_SET_VALUE)
        except FileNotFoundError:
            try:
                key = winreg.CreateKey(hive, path)
            except Exception as e:
                raise RegistryError(f"Cannot create key: {e}", key_path=path)

        try:
            winreg.SetValueEx(key, value_name, 0, value_type, data)
            return True
        except Exception as e:
            raise RegistryError(f"Cannot set value: {e}",
                              key_path=path, value_name=value_name)
        finally:
            winreg.CloseKey(key)

    def delete_value(self, hive: int, path: str, value_name: str) -> bool:
        """Delete registry value"""
        try:
            key = winreg.OpenKey(hive, path, 0, winreg.KEY_SET_VALUE)
            winreg.DeleteValue(key, value_name)
            winreg.CloseKey(key)
            return True
        except FileNotFoundError:
            return True
        except Exception as e:
            raise RegistryError(f"Cannot delete value: {e}",
                              key_path=path, value_name=value_name)

    def create_key(self, hive: int, path: str) -> bool:
        """Create registry key"""
        try:
            key = winreg.CreateKey(hive, path)
            winreg.CloseKey(key)
            return True
        except Exception as e:
            raise RegistryError(f"Cannot create key: {e}", key_path=path)

    def delete_key(self, hive: int, path: str, recursive: bool = True) -> bool:
        """Delete registry key"""
        if recursive:
            return self._delete_key_recursive(hive, path)

        try:
            parent_path = '\\'.join(path.split('\\')[:-1])
            key_name = path.split('\\')[-1]

            if parent_path:
                parent_key = winreg.OpenKey(hive, parent_path, 0,
                                           winreg.KEY_ALL_ACCESS)
                winreg.DeleteKey(parent_key, key_name)
                winreg.CloseKey(parent_key)
            else:
                winreg.DeleteKey(hive, key_name)

            return True
        except FileNotFoundError:
            return True
        except Exception as e:
            raise RegistryError(f"Cannot delete key: {e}", key_path=path)

    def _delete_key_recursive(self, hive: int, path: str) -> bool:
        """Recursively delete key and all subkeys"""
        try:
            key = winreg.OpenKey(hive, path, 0, winreg.KEY_ALL_ACCESS)
        except FileNotFoundError:
            return True
        except PermissionError:
            raise RegistryError("Access denied", key_path=path,
                              code=RegistryError.ERROR_ACCESS_DENIED)

        try:
            while True:
                try:
                    subkey_name = winreg.EnumKey(key, 0)
                    subkey_path = f"{path}\\{subkey_name}"
                    self._delete_key_recursive(hive, subkey_path)
                except OSError:
                    break
        finally:
            winreg.CloseKey(key)

        return self.delete_key(hive, path, recursive=False)

    def enumerate_subkeys(self, hive: int, path: str) -> List[str]:
        """Enumerate all subkeys of a key"""
        subkeys = []

        try:
            key = winreg.OpenKey(hive, path, 0, winreg.KEY_READ)
            subkey_count, _, _ = winreg.QueryInfoKey(key)

            for i in range(subkey_count):
                try:
                    subkey_name = winreg.EnumKey(key, i)
                    subkeys.append(subkey_name)
                except:
                    continue

            winreg.CloseKey(key)
        except:
            pass

        return subkeys

    def enumerate_values(self, hive: int, path: str) -> List[RegistryValueInfo]:
        """Enumerate all values of a key"""
        values = []

        try:
            key = winreg.OpenKey(hive, path, 0, winreg.KEY_READ)
            _, value_count, _ = winreg.QueryInfoKey(key)

            for i in range(value_count):
                try:
                    name, data, value_type = winreg.EnumValue(key, i)
                    values.append(RegistryValueInfo(
                        name=name or "(Default)",
                        data=data,
                        value_type=value_type,
                        type_name=self.TYPE_NAMES.get(value_type, "UNKNOWN")
                    ))
                except:
                    continue

            winreg.CloseKey(key)
        except:
            pass

        return values

    def copy_key(self, src_hive: int, src_path: str,
                dst_hive: int, dst_path: str) -> bool:
        """Copy registry key with all values and subkeys"""
        try:
            self.create_key(dst_hive, dst_path)

            for value in self.enumerate_values(src_hive, src_path):
                self.set_value(dst_hive, dst_path, value.name,
                              value.data, value.value_type)

            for subkey_name in self.enumerate_subkeys(src_hive, src_path):
                src_subkey = f"{src_path}\\{subkey_name}"
                dst_subkey = f"{dst_path}\\{subkey_name}"
                self.copy_key(src_hive, src_subkey, dst_hive, dst_subkey)

            return True
        except Exception as e:
            raise RegistryError(f"Cannot copy key: {e}", key_path=src_path)

    def rename_key(self, hive: int, path: str, new_name: str) -> bool:
        """Rename a registry key"""
        parent_path = '\\'.join(path.split('\\')[:-1])
        new_path = f"{parent_path}\\{new_name}" if parent_path else new_name

        try:
            self.copy_key(hive, path, hive, new_path)
            self.delete_key(hive, path)
            return True
        except Exception as e:
            raise RegistryError(f"Cannot rename key: {e}", key_path=path)

    def export_key(self, hive: int, path: str) -> Dict:
        """Export key to dictionary"""
        result = {
            'path': path,
            'values': [],
            'subkeys': {}
        }

        for value in self.enumerate_values(hive, path):
            data = value.data
            if isinstance(data, bytes):
                data = data.hex()

            result['values'].append({
                'name': value.name,
                'data': data,
                'type': value.value_type,
                'type_name': value.type_name,
            })

        for subkey_name in self.enumerate_subkeys(hive, path):
            subkey_path = f"{path}\\{subkey_name}"
            result['subkeys'][subkey_name] = self.export_key(hive, subkey_path)

        return result

    def import_key(self, hive: int, path: str, data: Dict) -> bool:
        """Import key from dictionary"""
        try:
            self.create_key(hive, path)

            for value in data.get('values', []):
                value_data = value['data']
                if value['type'] == winreg.REG_BINARY and isinstance(value_data, str):
                    value_data = bytes.fromhex(value_data)

                self.set_value(hive, path, value['name'],
                              value_data, value['type'])

            for subkey_name, subkey_data in data.get('subkeys', {}).items():
                subkey_path = f"{path}\\{subkey_name}"
                self.import_key(hive, subkey_path, subkey_data)

            return True
        except Exception as e:
            raise RegistryError(f"Cannot import key: {e}", key_path=path)

    def _infer_type(self, data: Any) -> int:
        """Infer registry type from Python type"""
        if isinstance(data, str):
            if '%' in data:
                return winreg.REG_EXPAND_SZ
            return winreg.REG_SZ
        elif isinstance(data, int):
            if data > 0xFFFFFFFF:
                return winreg.REG_QWORD
            return winreg.REG_DWORD
        elif isinstance(data, bytes):
            return winreg.REG_BINARY
        elif isinstance(data, list):
            return winreg.REG_MULTI_SZ
        else:
            return winreg.REG_SZ

    def search_values(self, hive: int, path: str, pattern: str,
                     recursive: bool = True, max_depth: int = 10) -> List[Tuple[str, str]]:
        """Search for values matching pattern"""
        matches = []
        pattern_lower = pattern.lower()

        def search(current_path: str, depth: int):
            if depth > max_depth:
                return

            for value in self.enumerate_values(hive, current_path):
                if pattern_lower in value.name.lower():
                    matches.append((current_path, value.name))
                elif isinstance(value.data, str) and pattern_lower in value.data.lower():
                    matches.append((current_path, value.name))

            if recursive:
                for subkey in self.enumerate_subkeys(hive, current_path):
                    subkey_path = f"{current_path}\\{subkey}"
                    search(subkey_path, depth + 1)

        search(path, 0)
        return matches

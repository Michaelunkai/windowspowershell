"""
Exception classes for Ultimate Uninstaller
Provides specific exception types for different error scenarios
"""

from typing import Optional, Any, Dict


class UninstallerError(Exception):
    """Base exception for all uninstaller errors"""

    def __init__(self, message: str, code: int = None,
                 details: Dict[str, Any] = None, cause: Exception = None):
        super().__init__(message)
        self.message = message
        self.code = code
        self.details = details or {}
        self.cause = cause

    def __str__(self) -> str:
        result = self.message
        if self.code:
            result = f"[{self.code}] {result}"
        if self.cause:
            result = f"{result} (caused by: {self.cause})"
        return result

    def to_dict(self) -> Dict[str, Any]:
        """Convert exception to dictionary"""
        return {
            'type': self.__class__.__name__,
            'message': self.message,
            'code': self.code,
            'details': self.details,
            'cause': str(self.cause) if self.cause else None,
        }


class RegistryError(UninstallerError):
    """Exception for registry-related errors"""

    ERROR_ACCESS_DENIED = 5
    ERROR_KEY_NOT_FOUND = 2
    ERROR_VALUE_NOT_FOUND = 3
    ERROR_INVALID_KEY = 4

    def __init__(self, message: str, key_path: str = None,
                 value_name: str = None, **kwargs):
        super().__init__(message, **kwargs)
        self.key_path = key_path
        self.value_name = value_name
        self.details['key_path'] = key_path
        self.details['value_name'] = value_name


class FileSystemError(UninstallerError):
    """Exception for file system errors"""

    ERROR_FILE_NOT_FOUND = 1
    ERROR_PATH_NOT_FOUND = 2
    ERROR_ACCESS_DENIED = 3
    ERROR_FILE_IN_USE = 4
    ERROR_DISK_FULL = 5

    def __init__(self, message: str, path: str = None,
                 operation: str = None, **kwargs):
        super().__init__(message, **kwargs)
        self.path = path
        self.operation = operation
        self.details['path'] = path
        self.details['operation'] = operation


class ServiceError(UninstallerError):
    """Exception for Windows service errors"""

    ERROR_SERVICE_NOT_FOUND = 1
    ERROR_SERVICE_NOT_ACTIVE = 2
    ERROR_SERVICE_STOP_FAILED = 3
    ERROR_SERVICE_DELETE_FAILED = 4
    ERROR_SERVICE_ACCESS_DENIED = 5

    def __init__(self, message: str, service_name: str = None,
                 state: str = None, **kwargs):
        super().__init__(message, **kwargs)
        self.service_name = service_name
        self.state = state
        self.details['service_name'] = service_name
        self.details['state'] = state


class DriverError(UninstallerError):
    """Exception for driver-related errors"""

    ERROR_DRIVER_NOT_FOUND = 1
    ERROR_DRIVER_IN_USE = 2
    ERROR_DRIVER_STOP_FAILED = 3
    ERROR_DRIVER_DELETE_FAILED = 4

    def __init__(self, message: str, driver_name: str = None, **kwargs):
        super().__init__(message, **kwargs)
        self.driver_name = driver_name
        self.details['driver_name'] = driver_name


class PermissionError(UninstallerError):
    """Exception for permission/access errors"""

    ERROR_NOT_ADMIN = 1
    ERROR_ACCESS_DENIED = 2
    ERROR_PRIVILEGE_NOT_HELD = 3
    ERROR_ELEVATION_REQUIRED = 4

    def __init__(self, message: str, required_privilege: str = None, **kwargs):
        super().__init__(message, **kwargs)
        self.required_privilege = required_privilege
        self.details['required_privilege'] = required_privilege


class NetworkError(UninstallerError):
    """Exception for network-related errors"""

    ERROR_CONNECTION_FAILED = 1
    ERROR_TIMEOUT = 2
    ERROR_HOST_NOT_FOUND = 3
    ERROR_FIREWALL_BLOCKED = 4

    def __init__(self, message: str, host: str = None,
                 port: int = None, **kwargs):
        super().__init__(message, **kwargs)
        self.host = host
        self.port = port
        self.details['host'] = host
        self.details['port'] = port


class ProcessError(UninstallerError):
    """Exception for process-related errors"""

    ERROR_PROCESS_NOT_FOUND = 1
    ERROR_PROCESS_ACCESS_DENIED = 2
    ERROR_PROCESS_TERMINATE_FAILED = 3
    ERROR_PROCESS_TIMEOUT = 4

    def __init__(self, message: str, pid: int = None,
                 process_name: str = None, **kwargs):
        super().__init__(message, **kwargs)
        self.pid = pid
        self.process_name = process_name
        self.details['pid'] = pid
        self.details['process_name'] = process_name


class CacheError(UninstallerError):
    """Exception for cache-related errors"""

    ERROR_CACHE_FULL = 1
    ERROR_CACHE_CORRUPTED = 2
    ERROR_CACHE_MISS = 3
    ERROR_SERIALIZATION_FAILED = 4

    def __init__(self, message: str, key: str = None, **kwargs):
        super().__init__(message, **kwargs)
        self.key = key
        self.details['key'] = key


class ConfigError(UninstallerError):
    """Exception for configuration errors"""

    ERROR_CONFIG_NOT_FOUND = 1
    ERROR_CONFIG_INVALID = 2
    ERROR_CONFIG_PARSE_FAILED = 3

    def __init__(self, message: str, config_path: str = None, **kwargs):
        super().__init__(message, **kwargs)
        self.config_path = config_path
        self.details['config_path'] = config_path


class TaskError(UninstallerError):
    """Exception for task/operation errors"""

    ERROR_TASK_FAILED = 1
    ERROR_TASK_TIMEOUT = 2
    ERROR_TASK_CANCELLED = 3
    ERROR_TASK_DEPENDENCY_FAILED = 4

    def __init__(self, message: str, task_id: str = None,
                 task_name: str = None, **kwargs):
        super().__init__(message, **kwargs)
        self.task_id = task_id
        self.task_name = task_name
        self.details['task_id'] = task_id
        self.details['task_name'] = task_name


class ValidationError(UninstallerError):
    """Exception for validation errors"""

    def __init__(self, message: str, field: str = None,
                 value: Any = None, **kwargs):
        super().__init__(message, **kwargs)
        self.field = field
        self.value = value
        self.details['field'] = field
        self.details['value'] = str(value)


class ModuleError(UninstallerError):
    """Exception for module-related errors"""

    ERROR_MODULE_NOT_FOUND = 1
    ERROR_MODULE_LOAD_FAILED = 2
    ERROR_MODULE_INIT_FAILED = 3
    ERROR_MODULE_DEPENDENCY = 4

    def __init__(self, message: str, module_name: str = None, **kwargs):
        super().__init__(message, **kwargs)
        self.module_name = module_name
        self.details['module_name'] = module_name


class BackupError(UninstallerError):
    """Exception for backup/restore errors"""

    ERROR_BACKUP_FAILED = 1
    ERROR_RESTORE_FAILED = 2
    ERROR_BACKUP_NOT_FOUND = 3
    ERROR_BACKUP_CORRUPTED = 4

    def __init__(self, message: str, backup_path: str = None, **kwargs):
        super().__init__(message, **kwargs)
        self.backup_path = backup_path
        self.details['backup_path'] = backup_path


def handle_exception(func):
    """Decorator to convert exceptions to UninstallerError"""
    from functools import wraps

    @wraps(func)
    def wrapper(*args, **kwargs):
        try:
            return func(*args, **kwargs)
        except UninstallerError:
            raise
        except PermissionError as e:
            raise PermissionError(str(e), cause=e)
        except FileNotFoundError as e:
            raise FileSystemError(str(e), code=FileSystemError.ERROR_FILE_NOT_FOUND, cause=e)
        except OSError as e:
            raise FileSystemError(str(e), cause=e)
        except TimeoutError as e:
            raise TaskError(str(e), code=TaskError.ERROR_TASK_TIMEOUT, cause=e)
        except Exception as e:
            raise UninstallerError(str(e), cause=e)

    return wrapper

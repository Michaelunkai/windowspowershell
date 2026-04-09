"""
Registry path definitions for Ultimate Uninstaller
Comprehensive collection of registry paths for scanning
"""

from typing import List, Dict, Tuple
from dataclasses import dataclass, field
import winreg


@dataclass
class RegistryPath:
    """Registry path definition"""
    hive: int
    path: str
    description: str = ""
    scan_values: bool = True
    scan_subkeys: bool = True
    is_64bit: bool = True


class RegistryPaths:
    """Collection of important registry paths"""

    HKLM = winreg.HKEY_LOCAL_MACHINE
    HKCU = winreg.HKEY_CURRENT_USER
    HKCR = winreg.HKEY_CLASSES_ROOT
    HKU = winreg.HKEY_USERS

    SOFTWARE_PATHS = [
        RegistryPath(HKLM, r"SOFTWARE", "Main software registry"),
        RegistryPath(HKLM, r"SOFTWARE\WOW6432Node", "32-bit software on 64-bit"),
        RegistryPath(HKCU, r"Software", "User software settings"),
        RegistryPath(HKLM, r"SOFTWARE\Classes", "File associations and COM"),
        RegistryPath(HKCU, r"Software\Classes", "User file associations"),
    ]

    SHELL_EXTENSION_PATHS = [
        RegistryPath(HKLM, r"SOFTWARE\Microsoft\Windows\CurrentVersion\Shell Extensions\Approved"),
        RegistryPath(HKLM, r"SOFTWARE\Microsoft\Windows\CurrentVersion\ShellServiceObjectDelayLoad"),
        RegistryPath(HKCU, r"Software\Microsoft\Windows\CurrentVersion\Shell Extensions\Approved"),
        RegistryPath(HKCR, r"*\shellex\ContextMenuHandlers"),
        RegistryPath(HKCR, r"Directory\shellex\ContextMenuHandlers"),
        RegistryPath(HKCR, r"Folder\shellex\ContextMenuHandlers"),
        RegistryPath(HKCR, r"Drive\shellex\ContextMenuHandlers"),
    ]

    COM_PATHS = [
        RegistryPath(HKLM, r"SOFTWARE\Classes\CLSID", "COM classes"),
        RegistryPath(HKLM, r"SOFTWARE\Classes\WOW6432Node\CLSID", "32-bit COM"),
        RegistryPath(HKCU, r"Software\Classes\CLSID", "User COM classes"),
        RegistryPath(HKLM, r"SOFTWARE\Classes\TypeLib", "Type libraries"),
        RegistryPath(HKLM, r"SOFTWARE\Classes\Interface", "COM interfaces"),
        RegistryPath(HKLM, r"SOFTWARE\Classes\AppID", "Application IDs"),
    ]

    BROWSER_PATHS = [
        RegistryPath(HKLM, r"SOFTWARE\Microsoft\Internet Explorer\Extensions"),
        RegistryPath(HKCU, r"Software\Microsoft\Internet Explorer\Extensions"),
        RegistryPath(HKLM, r"SOFTWARE\Microsoft\Internet Explorer\Toolbar"),
        RegistryPath(HKCU, r"Software\Microsoft\Internet Explorer\Toolbar"),
        RegistryPath(HKLM, r"SOFTWARE\Google\Chrome\Extensions"),
        RegistryPath(HKCU, r"Software\Google\Chrome\Extensions"),
        RegistryPath(HKLM, r"SOFTWARE\Mozilla"),
        RegistryPath(HKCU, r"Software\Mozilla"),
    ]

    SYSTEM_PATHS = [
        RegistryPath(HKLM, r"SYSTEM\CurrentControlSet\Services", "Windows services"),
        RegistryPath(HKLM, r"SYSTEM\CurrentControlSet\Control\Class", "Device classes"),
        RegistryPath(HKLM, r"SYSTEM\CurrentControlSet\Enum", "Device enumeration"),
        RegistryPath(HKLM, r"SYSTEM\CurrentControlSet\Control\Print\Environments"),
        RegistryPath(HKLM, r"SYSTEM\CurrentControlSet\Control\SecurityProviders"),
    ]

    APP_PATHS = [
        RegistryPath(HKLM, r"SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths"),
        RegistryPath(HKCU, r"Software\Microsoft\Windows\CurrentVersion\App Paths"),
    ]

    FILE_EXTENSION_PATHS = [
        RegistryPath(HKCR, r""),
        RegistryPath(HKLM, r"SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FileExts"),
        RegistryPath(HKCU, r"Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts"),
    ]

    ENVIRONMENT_PATHS = [
        RegistryPath(HKLM, r"SYSTEM\CurrentControlSet\Control\Session Manager\Environment"),
        RegistryPath(HKCU, r"Environment"),
    ]

    @classmethod
    def get_all_paths(cls) -> List[RegistryPath]:
        """Get all registry paths"""
        all_paths = []
        all_paths.extend(cls.SOFTWARE_PATHS)
        all_paths.extend(cls.SHELL_EXTENSION_PATHS)
        all_paths.extend(cls.COM_PATHS)
        all_paths.extend(cls.BROWSER_PATHS)
        all_paths.extend(cls.SYSTEM_PATHS)
        all_paths.extend(cls.APP_PATHS)
        all_paths.extend(cls.FILE_EXTENSION_PATHS)
        all_paths.extend(cls.ENVIRONMENT_PATHS)
        return all_paths

    @classmethod
    def get_paths_for_scan_type(cls, scan_type: str) -> List[RegistryPath]:
        """Get paths for specific scan type"""
        type_map = {
            'software': cls.SOFTWARE_PATHS,
            'shell': cls.SHELL_EXTENSION_PATHS,
            'com': cls.COM_PATHS,
            'browser': cls.BROWSER_PATHS,
            'system': cls.SYSTEM_PATHS,
            'app': cls.APP_PATHS,
            'file_ext': cls.FILE_EXTENSION_PATHS,
            'environment': cls.ENVIRONMENT_PATHS,
        }
        return type_map.get(scan_type, [])


class UninstallPaths:
    """Uninstall registry paths"""

    PATHS = [
        (winreg.HKEY_LOCAL_MACHINE,
         r"SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"),
        (winreg.HKEY_LOCAL_MACHINE,
         r"SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"),
        (winreg.HKEY_CURRENT_USER,
         r"Software\Microsoft\Windows\CurrentVersion\Uninstall"),
    ]

    REQUIRED_FIELDS = ['DisplayName', 'UninstallString']

    OPTIONAL_FIELDS = [
        'DisplayVersion', 'Publisher', 'InstallDate', 'InstallLocation',
        'QuietUninstallString', 'ModifyPath', 'DisplayIcon', 'EstimatedSize',
        'URLInfoAbout', 'URLUpdateInfo', 'HelpLink', 'Comments',
        'SystemComponent', 'NoRemove', 'NoModify', 'NoRepair',
        'WindowsInstaller', 'ParentKeyName', 'ReleaseType',
    ]

    @classmethod
    def get_all_paths(cls) -> List[Tuple[int, str]]:
        """Get all uninstall paths"""
        return cls.PATHS


class RunPaths:
    """Startup/Run registry paths"""

    HKLM = winreg.HKEY_LOCAL_MACHINE
    HKCU = winreg.HKEY_CURRENT_USER

    RUN_PATHS = [
        (HKLM, r"SOFTWARE\Microsoft\Windows\CurrentVersion\Run"),
        (HKLM, r"SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce"),
        (HKLM, r"SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run"),
        (HKLM, r"SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\RunOnce"),
        (HKCU, r"Software\Microsoft\Windows\CurrentVersion\Run"),
        (HKCU, r"Software\Microsoft\Windows\CurrentVersion\RunOnce"),
    ]

    RUN_SERVICES_PATHS = [
        (HKLM, r"SOFTWARE\Microsoft\Windows\CurrentVersion\RunServices"),
        (HKLM, r"SOFTWARE\Microsoft\Windows\CurrentVersion\RunServicesOnce"),
    ]

    POLICY_RUN_PATHS = [
        (HKLM, r"SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer\Run"),
        (HKCU, r"Software\Microsoft\Windows\CurrentVersion\Policies\Explorer\Run"),
    ]

    WINLOGON_PATHS = [
        (HKLM, r"SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"),
    ]

    WINLOGON_VALUES = [
        'Shell', 'Userinit', 'VmApplet', 'AppSetup',
    ]

    ACTIVE_SETUP_PATHS = [
        (HKLM, r"SOFTWARE\Microsoft\Active Setup\Installed Components"),
        (HKLM, r"SOFTWARE\WOW6432Node\Microsoft\Active Setup\Installed Components"),
    ]

    SHELL_FOLDERS = [
        (HKCU, r"Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders"),
        (HKCU, r"Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders"),
        (HKLM, r"SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders"),
        (HKLM, r"SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders"),
    ]

    STARTUP_FOLDER_VALUES = ['Startup', 'Common Startup']

    @classmethod
    def get_all_run_paths(cls) -> List[Tuple[int, str]]:
        """Get all run/startup paths"""
        paths = []
        paths.extend(cls.RUN_PATHS)
        paths.extend(cls.RUN_SERVICES_PATHS)
        paths.extend(cls.POLICY_RUN_PATHS)
        paths.extend(cls.WINLOGON_PATHS)
        paths.extend(cls.ACTIVE_SETUP_PATHS)
        return paths

    @classmethod
    def get_startup_folders(cls) -> List[Tuple[int, str]]:
        """Get startup folder registry paths"""
        return cls.SHELL_FOLDERS


class AppCompatPaths:
    """Application compatibility registry paths"""

    HKLM = winreg.HKEY_LOCAL_MACHINE
    HKCU = winreg.HKEY_CURRENT_USER

    COMPATIBILITY_PATHS = [
        (HKLM, r"SOFTWARE\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers"),
        (HKCU, r"Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers"),
        (HKLM, r"SOFTWARE\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Custom"),
        (HKCU, r"Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Custom"),
    ]

    SHIM_PATHS = [
        (HKLM, r"SOFTWARE\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\InstalledSDB"),
    ]

    @classmethod
    def get_all_paths(cls) -> List[Tuple[int, str]]:
        """Get all app compatibility paths"""
        paths = []
        paths.extend(cls.COMPATIBILITY_PATHS)
        paths.extend(cls.SHIM_PATHS)
        return paths


class MUICache:
    """MUI Cache registry paths"""

    PATHS = [
        (winreg.HKEY_CURRENT_USER,
         r"Software\Classes\Local Settings\Software\Microsoft\Windows\Shell\MuiCache"),
        (winreg.HKEY_CURRENT_USER,
         r"Software\Microsoft\Windows\ShellNoRoam\MUICache"),
    ]

    @classmethod
    def get_paths(cls) -> List[Tuple[int, str]]:
        return cls.PATHS


class UserAssist:
    """UserAssist registry paths"""

    PATHS = [
        (winreg.HKEY_CURRENT_USER,
         r"Software\Microsoft\Windows\CurrentVersion\Explorer\UserAssist"),
    ]

    @classmethod
    def get_paths(cls) -> List[Tuple[int, str]]:
        return cls.PATHS

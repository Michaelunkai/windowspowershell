"""
ULTIMATE FORCE REBOOT - Maximum Speed Windows Reboot Utility
============================================================
This script uses every possible method to force an immediate reboot.
No delays, no prompts, no mercy. Designed for Windows 11.

Methods employed (in order of aggressiveness):
1. NtShutdownSystem - Direct NT kernel call
2. ExitWindowsEx with FORCE flags
3. InitiateSystemShutdownEx
4. WMI Win32_OperatingSystem.Reboot
5. subprocess shutdown command
6. os.system fallback

Run as Administrator for full effectiveness.
"""

import ctypes
import sys
import os
import subprocess
import threading
import time
from ctypes import wintypes

# =============================================================================
# WINDOWS API CONSTANTS
# =============================================================================

# Token access rights
TOKEN_ADJUST_PRIVILEGES = 0x0020
TOKEN_QUERY = 0x0008
TOKEN_ALL_ACCESS = 0xF01FF

# Privilege constants
SE_PRIVILEGE_ENABLED = 0x00000002
SE_PRIVILEGE_REMOVED = 0x00000004

# Privilege names
SE_SHUTDOWN_NAME = "SeShutdownPrivilege"
SE_REMOTE_SHUTDOWN_NAME = "SeRemoteShutdownPrivilege"
SE_DEBUG_NAME = "SeDebugPrivilege"

# ExitWindowsEx flags
EWX_LOGOFF = 0x00000000
EWX_SHUTDOWN = 0x00000001
EWX_REBOOT = 0x00000002
EWX_FORCE = 0x00000004
EWX_POWEROFF = 0x00000008
EWX_FORCEIFHUNG = 0x00000010
EWX_QUICKRESOLVE = 0x00000020
EWX_RESTARTAPPS = 0x00000040
EWX_HYBRID_SHUTDOWN = 0x00400000
EWX_BOOTOPTIONS = 0x01000000

# Shutdown reason codes
SHTDN_REASON_MAJOR_OTHER = 0x00000000
SHTDN_REASON_MAJOR_HARDWARE = 0x00010000
SHTDN_REASON_MAJOR_OPERATINGSYSTEM = 0x00020000
SHTDN_REASON_MAJOR_SOFTWARE = 0x00030000
SHTDN_REASON_MAJOR_APPLICATION = 0x00040000
SHTDN_REASON_MAJOR_SYSTEM = 0x00050000
SHTDN_REASON_MAJOR_POWER = 0x00060000
SHTDN_REASON_MAJOR_LEGACY_API = 0x00070000

SHTDN_REASON_MINOR_OTHER = 0x00000000
SHTDN_REASON_MINOR_MAINTENANCE = 0x00000001
SHTDN_REASON_MINOR_INSTALLATION = 0x00000002
SHTDN_REASON_MINOR_UPGRADE = 0x00000003
SHTDN_REASON_MINOR_RECONFIG = 0x00000004
SHTDN_REASON_MINOR_HUNG = 0x00000005
SHTDN_REASON_MINOR_UNSTABLE = 0x00000006
SHTDN_REASON_MINOR_DISK = 0x00000007
SHTDN_REASON_MINOR_PROCESSOR = 0x00000008
SHTDN_REASON_MINOR_NETWORKCARD = 0x00000009
SHTDN_REASON_MINOR_POWER_SUPPLY = 0x0000000A
SHTDN_REASON_MINOR_CORDUNPLUGGED = 0x0000000B
SHTDN_REASON_MINOR_ENVIRONMENT = 0x0000000C
SHTDN_REASON_MINOR_HARDWARE_DRIVER = 0x0000000D
SHTDN_REASON_MINOR_OTHERDRIVER = 0x0000000E
SHTDN_REASON_MINOR_BLUESCREEN = 0x0000000F
SHTDN_REASON_MINOR_SERVICEPACK = 0x00000010
SHTDN_REASON_MINOR_HOTFIX = 0x00000011
SHTDN_REASON_MINOR_SECURITYFIX = 0x00000012
SHTDN_REASON_MINOR_SECURITY = 0x00000013
SHTDN_REASON_MINOR_NETWORK_CONNECTIVITY = 0x00000014
SHTDN_REASON_MINOR_WMI = 0x00000015
SHTDN_REASON_MINOR_SERVICEPACK_UNINSTALL = 0x00000016
SHTDN_REASON_MINOR_HOTFIX_UNINSTALL = 0x00000017
SHTDN_REASON_MINOR_SECURITYFIX_UNINSTALL = 0x00000018
SHTDN_REASON_MINOR_MMC = 0x00000019
SHTDN_REASON_MINOR_SYSTEMRESTORE = 0x0000001A
SHTDN_REASON_MINOR_TERMSRV = 0x00000020
SHTDN_REASON_MINOR_DC_PROMOTION = 0x00000021
SHTDN_REASON_MINOR_DC_DEMOTION = 0x00000022

SHTDN_REASON_FLAG_USER_DEFINED = 0x40000000
SHTDN_REASON_FLAG_PLANNED = 0x80000000

# NtShutdownSystem actions
ShutdownNoReboot = 0
ShutdownReboot = 1
ShutdownPowerOff = 2

# Process access rights
PROCESS_ALL_ACCESS = 0x1F0FFF
PROCESS_TERMINATE = 0x0001
PROCESS_QUERY_INFORMATION = 0x0400

# =============================================================================
# WINDOWS API STRUCTURES
# =============================================================================

class LUID(ctypes.Structure):
    """Locally Unique Identifier structure"""
    _fields_ = [
        ("LowPart", wintypes.DWORD),
        ("HighPart", wintypes.LONG)
    ]

class LUID_AND_ATTRIBUTES(ctypes.Structure):
    """LUID with attributes structure"""
    _fields_ = [
        ("Luid", LUID),
        ("Attributes", wintypes.DWORD)
    ]

class TOKEN_PRIVILEGES(ctypes.Structure):
    """Token privileges structure for single privilege"""
    _fields_ = [
        ("PrivilegeCount", wintypes.DWORD),
        ("Privileges", LUID_AND_ATTRIBUTES * 1)
    ]

class TOKEN_PRIVILEGES_ARRAY(ctypes.Structure):
    """Token privileges structure for multiple privileges"""
    _fields_ = [
        ("PrivilegeCount", wintypes.DWORD),
        ("Privileges", LUID_AND_ATTRIBUTES * 3)
    ]

class SECURITY_ATTRIBUTES(ctypes.Structure):
    """Security attributes structure"""
    _fields_ = [
        ("nLength", wintypes.DWORD),
        ("lpSecurityDescriptor", wintypes.LPVOID),
        ("bInheritHandle", wintypes.BOOL)
    ]

class STARTUPINFO(ctypes.Structure):
    """Startup info structure for CreateProcess"""
    _fields_ = [
        ("cb", wintypes.DWORD),
        ("lpReserved", wintypes.LPWSTR),
        ("lpDesktop", wintypes.LPWSTR),
        ("lpTitle", wintypes.LPWSTR),
        ("dwX", wintypes.DWORD),
        ("dwY", wintypes.DWORD),
        ("dwXSize", wintypes.DWORD),
        ("dwYSize", wintypes.DWORD),
        ("dwXCountChars", wintypes.DWORD),
        ("dwYCountChars", wintypes.DWORD),
        ("dwFillAttribute", wintypes.DWORD),
        ("dwFlags", wintypes.DWORD),
        ("wShowWindow", wintypes.WORD),
        ("cbReserved2", wintypes.WORD),
        ("lpReserved2", ctypes.POINTER(wintypes.BYTE)),
        ("hStdInput", wintypes.HANDLE),
        ("hStdOutput", wintypes.HANDLE),
        ("hStdError", wintypes.HANDLE)
    ]

class PROCESS_INFORMATION(ctypes.Structure):
    """Process information structure"""
    _fields_ = [
        ("hProcess", wintypes.HANDLE),
        ("hThread", wintypes.HANDLE),
        ("dwProcessId", wintypes.DWORD),
        ("dwThreadId", wintypes.DWORD)
    ]

# =============================================================================
# DLL HANDLES
# =============================================================================

kernel32 = ctypes.windll.kernel32
advapi32 = ctypes.windll.advapi32
user32 = ctypes.windll.user32
ntdll = ctypes.windll.ntdll

# =============================================================================
# FUNCTION PROTOTYPES
# =============================================================================

# Kernel32 functions
kernel32.GetCurrentProcess.restype = wintypes.HANDLE
kernel32.GetCurrentProcess.argtypes = []

kernel32.CloseHandle.restype = wintypes.BOOL
kernel32.CloseHandle.argtypes = [wintypes.HANDLE]

kernel32.GetLastError.restype = wintypes.DWORD
kernel32.GetLastError.argtypes = []

kernel32.SetLastError.restype = None
kernel32.SetLastError.argtypes = [wintypes.DWORD]

# Advapi32 functions
advapi32.OpenProcessToken.restype = wintypes.BOOL
advapi32.OpenProcessToken.argtypes = [
    wintypes.HANDLE,
    wintypes.DWORD,
    ctypes.POINTER(wintypes.HANDLE)
]

advapi32.LookupPrivilegeValueW.restype = wintypes.BOOL
advapi32.LookupPrivilegeValueW.argtypes = [
    wintypes.LPCWSTR,
    wintypes.LPCWSTR,
    ctypes.POINTER(LUID)
]

advapi32.AdjustTokenPrivileges.restype = wintypes.BOOL
advapi32.AdjustTokenPrivileges.argtypes = [
    wintypes.HANDLE,
    wintypes.BOOL,
    ctypes.POINTER(TOKEN_PRIVILEGES),
    wintypes.DWORD,
    ctypes.POINTER(TOKEN_PRIVILEGES),
    ctypes.POINTER(wintypes.DWORD)
]

advapi32.InitiateSystemShutdownExW.restype = wintypes.BOOL
advapi32.InitiateSystemShutdownExW.argtypes = [
    wintypes.LPCWSTR,
    wintypes.LPCWSTR,
    wintypes.DWORD,
    wintypes.BOOL,
    wintypes.BOOL,
    wintypes.DWORD
]

advapi32.AbortSystemShutdownW.restype = wintypes.BOOL
advapi32.AbortSystemShutdownW.argtypes = [wintypes.LPCWSTR]

# User32 functions
user32.ExitWindowsEx.restype = wintypes.BOOL
user32.ExitWindowsEx.argtypes = [wintypes.UINT, wintypes.DWORD]

# Ntdll functions
ntdll.NtShutdownSystem.restype = wintypes.LONG
ntdll.NtShutdownSystem.argtypes = [wintypes.ULONG]

ntdll.RtlAdjustPrivilege.restype = wintypes.LONG
ntdll.RtlAdjustPrivilege.argtypes = [
    wintypes.ULONG,
    wintypes.BOOLEAN,
    wintypes.BOOLEAN,
    ctypes.POINTER(wintypes.BOOLEAN)
]

# =============================================================================
# PRIVILEGE MANAGEMENT
# =============================================================================

class PrivilegeManager:
    """Manages Windows privileges for shutdown operations"""

    SE_SHUTDOWN_PRIVILEGE = 19
    SE_REMOTE_SHUTDOWN_PRIVILEGE = 24
    SE_DEBUG_PRIVILEGE = 20

    def __init__(self):
        """Initialize privilege manager"""
        self.token_handle = None
        self.privileges_enabled = []

    def enable_privilege_rtl(self, privilege_id):
        """Enable privilege using RtlAdjustPrivilege (fastest method)"""
        previous_state = wintypes.BOOLEAN()
        status = ntdll.RtlAdjustPrivilege(
            privilege_id,
            True,
            False,
            ctypes.byref(previous_state)
        )
        return status == 0

    def enable_privilege_token(self, privilege_name):
        """Enable privilege using token adjustment"""
        hToken = wintypes.HANDLE()

        if not advapi32.OpenProcessToken(
            kernel32.GetCurrentProcess(),
            TOKEN_ADJUST_PRIVILEGES | TOKEN_QUERY,
            ctypes.byref(hToken)
        ):
            return False

        luid = LUID()
        if not advapi32.LookupPrivilegeValueW(
            None,
            privilege_name,
            ctypes.byref(luid)
        ):
            kernel32.CloseHandle(hToken)
            return False

        tp = TOKEN_PRIVILEGES()
        tp.PrivilegeCount = 1
        tp.Privileges[0].Luid = luid
        tp.Privileges[0].Attributes = SE_PRIVILEGE_ENABLED

        result = advapi32.AdjustTokenPrivileges(
            hToken,
            False,
            ctypes.byref(tp),
            ctypes.sizeof(TOKEN_PRIVILEGES),
            None,
            None
        )

        error = kernel32.GetLastError()
        kernel32.CloseHandle(hToken)

        return result and error == 0

    def enable_all_shutdown_privileges(self):
        """Enable all privileges needed for shutdown"""
        success_count = 0

        # Method 1: RtlAdjustPrivilege (fastest)
        if self.enable_privilege_rtl(self.SE_SHUTDOWN_PRIVILEGE):
            success_count += 1
            self.privileges_enabled.append("SeShutdownPrivilege (RTL)")

        if self.enable_privilege_rtl(self.SE_REMOTE_SHUTDOWN_PRIVILEGE):
            success_count += 1
            self.privileges_enabled.append("SeRemoteShutdownPrivilege (RTL)")

        if self.enable_privilege_rtl(self.SE_DEBUG_PRIVILEGE):
            success_count += 1
            self.privileges_enabled.append("SeDebugPrivilege (RTL)")

        # Method 2: Token adjustment (fallback)
        if self.enable_privilege_token(SE_SHUTDOWN_NAME):
            success_count += 1
            self.privileges_enabled.append("SeShutdownPrivilege (Token)")

        if self.enable_privilege_token(SE_REMOTE_SHUTDOWN_NAME):
            success_count += 1
            self.privileges_enabled.append("SeRemoteShutdownPrivilege (Token)")

        if self.enable_privilege_token(SE_DEBUG_NAME):
            success_count += 1
            self.privileges_enabled.append("SeDebugPrivilege (Token)")

        return success_count > 0

# =============================================================================
# REBOOT METHODS
# =============================================================================

class RebootMethod:
    """Base class for reboot methods"""

    name = "Base"
    priority = 0

    def execute(self):
        """Execute the reboot method"""
        raise NotImplementedError

class NtShutdownSystemMethod(RebootMethod):
    """Direct NT kernel call - Most aggressive"""

    name = "NtShutdownSystem"
    priority = 1

    def execute(self):
        """Execute NtShutdownSystem reboot"""
        status = ntdll.NtShutdownSystem(ShutdownReboot)
        return status == 0

class ExitWindowsExMethod(RebootMethod):
    """ExitWindowsEx with maximum force flags"""

    name = "ExitWindowsEx"
    priority = 2

    def execute(self):
        """Execute ExitWindowsEx reboot"""
        flags = EWX_REBOOT | EWX_FORCE | EWX_FORCEIFHUNG
        reason = SHTDN_REASON_MAJOR_OTHER | SHTDN_REASON_MINOR_OTHER
        return bool(user32.ExitWindowsEx(flags, reason))

class ExitWindowsExHybridMethod(RebootMethod):
    """ExitWindowsEx with hybrid shutdown for faster boot"""

    name = "ExitWindowsEx Hybrid"
    priority = 3

    def execute(self):
        """Execute ExitWindowsEx with hybrid shutdown"""
        flags = EWX_REBOOT | EWX_FORCE | EWX_FORCEIFHUNG | EWX_HYBRID_SHUTDOWN
        reason = SHTDN_REASON_MAJOR_OTHER | SHTDN_REASON_MINOR_OTHER
        return bool(user32.ExitWindowsEx(flags, reason))

class InitiateSystemShutdownMethod(RebootMethod):
    """InitiateSystemShutdownEx method"""

    name = "InitiateSystemShutdownEx"
    priority = 4

    def execute(self):
        """Execute InitiateSystemShutdownEx reboot"""
        reason = (SHTDN_REASON_MAJOR_OTHER |
                  SHTDN_REASON_MINOR_OTHER |
                  SHTDN_REASON_FLAG_PLANNED)
        return bool(advapi32.InitiateSystemShutdownExW(
            None,       # Local machine
            None,       # No message
            0,          # No timeout
            True,       # Force apps closed
            True,       # Reboot after shutdown
            reason
        ))

class SubprocessShutdownMethod(RebootMethod):
    """Subprocess shutdown command"""

    name = "Subprocess Shutdown"
    priority = 5

    def execute(self):
        """Execute shutdown via subprocess"""
        try:
            subprocess.run(
                ["shutdown", "/r", "/f", "/t", "0"],
                creationflags=subprocess.CREATE_NO_WINDOW,
                timeout=5
            )
            return True
        except Exception:
            return False

class SubprocessShutdownPMethod(RebootMethod):
    """Subprocess shutdown with /p flag"""

    name = "Subprocess Shutdown /p"
    priority = 6

    def execute(self):
        """Execute shutdown with power off then reboot"""
        try:
            subprocess.run(
                ["shutdown", "/r", "/f", "/t", "0", "/d", "p:0:0"],
                creationflags=subprocess.CREATE_NO_WINDOW,
                timeout=5
            )
            return True
        except Exception:
            return False

class OsSystemShutdownMethod(RebootMethod):
    """os.system shutdown command"""

    name = "os.system Shutdown"
    priority = 7

    def execute(self):
        """Execute shutdown via os.system"""
        try:
            os.system("shutdown /r /f /t 0")
            return True
        except Exception:
            return False

class WMIRebootMethod(RebootMethod):
    """WMI Win32_OperatingSystem.Reboot method"""

    name = "WMI Reboot"
    priority = 8

    def execute(self):
        """Execute reboot via WMI"""
        try:
            import wmi
            c = wmi.WMI(privileges=["Shutdown"])
            for os_obj in c.Win32_OperatingSystem():
                os_obj.Reboot()
            return True
        except ImportError:
            return False
        except Exception:
            return False

class PowerShellRebootMethod(RebootMethod):
    """PowerShell Restart-Computer command"""

    name = "PowerShell Restart"
    priority = 9

    def execute(self):
        """Execute reboot via PowerShell"""
        try:
            subprocess.run(
                ["powershell", "-Command", "Restart-Computer", "-Force"],
                creationflags=subprocess.CREATE_NO_WINDOW,
                timeout=5
            )
            return True
        except Exception:
            return False

class CmdShutdownMethod(RebootMethod):
    """CMD shutdown via CreateProcess"""

    name = "CMD CreateProcess"
    priority = 10

    def execute(self):
        """Execute shutdown via CreateProcess API"""
        try:
            si = STARTUPINFO()
            si.cb = ctypes.sizeof(STARTUPINFO)
            si.dwFlags = 0x0001  # STARTF_USESHOWWINDOW
            si.wShowWindow = 0  # SW_HIDE

            pi = PROCESS_INFORMATION()

            cmd = ctypes.create_unicode_buffer("cmd.exe /c shutdown /r /f /t 0")

            result = kernel32.CreateProcessW(
                None,
                cmd,
                None,
                None,
                False,
                0x08000000,  # CREATE_NO_WINDOW
                None,
                None,
                ctypes.byref(si),
                ctypes.byref(pi)
            )

            if result:
                kernel32.CloseHandle(pi.hProcess)
                kernel32.CloseHandle(pi.hThread)

            return bool(result)
        except Exception:
            return False

# =============================================================================
# PARALLEL EXECUTION
# =============================================================================

class ParallelRebootExecutor:
    """Executes multiple reboot methods in parallel for maximum effect"""

    def __init__(self):
        """Initialize parallel executor"""
        self.methods = []
        self.results = {}
        self.lock = threading.Lock()

    def add_method(self, method):
        """Add a reboot method to execute"""
        self.methods.append(method)

    def execute_method(self, method):
        """Execute a single method in a thread"""
        try:
            result = method.execute()
            with self.lock:
                self.results[method.name] = result
        except Exception as e:
            with self.lock:
                self.results[method.name] = False

    def execute_all_parallel(self):
        """Execute all methods in parallel"""
        threads = []

        for method in self.methods:
            t = threading.Thread(target=self.execute_method, args=(method,))
            t.daemon = True
            threads.append(t)

        for t in threads:
            t.start()

        # Don't wait - we want immediate reboot
        return True

    def execute_sequential_fast(self):
        """Execute methods sequentially but fast"""
        for method in sorted(self.methods, key=lambda m: m.priority):
            try:
                method.execute()
            except Exception:
                continue
        return True

# =============================================================================
# PROCESS TERMINATOR
# =============================================================================

class ProcessTerminator:
    """Terminates blocking processes before reboot"""

    BLOCKING_PROCESSES = [
        "notepad.exe",
        "wordpad.exe",
        "excel.exe",
        "winword.exe",
        "powerpnt.exe",
        "outlook.exe",
        "thunderbird.exe",
        "firefox.exe",
        "chrome.exe",
        "msedge.exe",
        "brave.exe",
        "opera.exe",
        "vlc.exe",
        "spotify.exe",
        "discord.exe",
        "slack.exe",
        "teams.exe",
        "zoom.exe",
        "code.exe",
        "devenv.exe",
        "rider64.exe",
        "pycharm64.exe",
        "idea64.exe",
        "sublime_text.exe",
        "atom.exe",
    ]

    def terminate_blocking_processes(self):
        """Terminate processes that might block shutdown"""
        try:
            for proc in self.BLOCKING_PROCESSES:
                os.system(f'taskkill /F /IM {proc} /T 2>nul')
        except Exception:
            pass

    def terminate_all_user_processes(self):
        """Terminate all user processes aggressively"""
        try:
            subprocess.run(
                ['taskkill', '/F', '/FI', 'STATUS eq RUNNING', '/FI', 'USERNAME ne SYSTEM'],
                creationflags=subprocess.CREATE_NO_WINDOW,
                timeout=3
            )
        except Exception:
            pass

# =============================================================================
# SERVICE STOPPER
# =============================================================================

class ServiceStopper:
    """Stops services that might delay shutdown"""

    DELAY_SERVICES = [
        "wuauserv",         # Windows Update
        "BITS",             # Background Intelligent Transfer
        "TrustedInstaller", # Windows Modules Installer
        "wscsvc",           # Security Center
        "WSearch",          # Windows Search
        "SysMain",          # Superfetch
        "DiagTrack",        # Diagnostics Tracking
        "dmwappushservice", # WAP Push Service
        "WMPNetworkSvc",    # Windows Media Network
        "XblAuthManager",   # Xbox Live Auth
        "XblGameSave",      # Xbox Live Game Save
    ]

    def stop_delay_services(self):
        """Stop services that cause shutdown delays"""
        try:
            for service in self.DELAY_SERVICES:
                os.system(f'net stop {service} /y 2>nul')
        except Exception:
            pass

# =============================================================================
# CACHE FLUSHER
# =============================================================================

class CacheFlusher:
    """Flushes system caches before reboot"""

    def flush_file_buffers(self):
        """Flush file system buffers"""
        try:
            drives = ['C:', 'D:', 'E:', 'F:', 'G:', 'H:']
            for drive in drives:
                if os.path.exists(drive):
                    kernel32.FlushFileBuffers(
                        kernel32.CreateFileW(
                            f"\\\\.\\{drive}",
                            0x40000000,  # GENERIC_WRITE
                            0x3,         # FILE_SHARE_READ | FILE_SHARE_WRITE
                            None,
                            3,           # OPEN_EXISTING
                            0,
                            None
                        )
                    )
        except Exception:
            pass

    def sync_filesystems(self):
        """Sync all filesystems"""
        try:
            os.system('sync 2>nul')
        except Exception:
            pass

# =============================================================================
# MAIN REBOOT ORCHESTRATOR
# =============================================================================

class UltimateRebootOrchestrator:
    """Orchestrates the ultimate force reboot"""

    def __init__(self):
        """Initialize orchestrator"""
        self.privilege_manager = PrivilegeManager()
        self.parallel_executor = ParallelRebootExecutor()
        self.process_terminator = ProcessTerminator()
        self.service_stopper = ServiceStopper()
        self.cache_flusher = CacheFlusher()
        self._setup_methods()

    def _setup_methods(self):
        """Setup all reboot methods"""
        self.parallel_executor.add_method(NtShutdownSystemMethod())
        self.parallel_executor.add_method(ExitWindowsExMethod())
        self.parallel_executor.add_method(ExitWindowsExHybridMethod())
        self.parallel_executor.add_method(InitiateSystemShutdownMethod())
        self.parallel_executor.add_method(SubprocessShutdownMethod())
        self.parallel_executor.add_method(SubprocessShutdownPMethod())
        self.parallel_executor.add_method(OsSystemShutdownMethod())
        self.parallel_executor.add_method(WMIRebootMethod())
        self.parallel_executor.add_method(PowerShellRebootMethod())
        self.parallel_executor.add_method(CmdShutdownMethod())

    def execute_ultimate_reboot(self):
        """Execute the ultimate force reboot sequence"""

        # Step 1: Enable all privileges
        self.privilege_manager.enable_all_shutdown_privileges()

        # Step 2: Stop delay services (background)
        service_thread = threading.Thread(
            target=self.service_stopper.stop_delay_services
        )
        service_thread.daemon = True
        service_thread.start()

        # Step 3: Terminate blocking processes (background)
        process_thread = threading.Thread(
            target=self.process_terminator.terminate_blocking_processes
        )
        process_thread.daemon = True
        process_thread.start()

        # Step 4: Flush caches (background)
        cache_thread = threading.Thread(
            target=self.cache_flusher.flush_file_buffers
        )
        cache_thread.daemon = True
        cache_thread.start()

        # Step 5: Execute all reboot methods in parallel
        self.parallel_executor.execute_all_parallel()

        # Step 6: Also execute sequentially as backup
        self.parallel_executor.execute_sequential_fast()

        # Step 7: Final desperate attempts
        self._final_attempts()

    def _final_attempts(self):
        """Final desperate reboot attempts"""

        # Direct NT call
        ntdll.NtShutdownSystem(ShutdownReboot)

        # ExitWindowsEx with all flags
        user32.ExitWindowsEx(
            EWX_REBOOT | EWX_FORCE | EWX_FORCEIFHUNG,
            SHTDN_REASON_MAJOR_OTHER
        )

        # subprocess
        subprocess.Popen(
            ["shutdown", "/r", "/f", "/t", "0"],
            creationflags=subprocess.CREATE_NO_WINDOW
        )

        # os.system
        os.system("shutdown /r /f /t 0")

# =============================================================================
# QUICK REBOOT FUNCTIONS
# =============================================================================

def quick_nt_reboot():
    """Quickest possible reboot using NT call"""
    previous = wintypes.BOOLEAN()
    ntdll.RtlAdjustPrivilege(19, True, False, ctypes.byref(previous))
    ntdll.NtShutdownSystem(ShutdownReboot)

def quick_exitwindows_reboot():
    """Quick reboot using ExitWindowsEx"""
    previous = wintypes.BOOLEAN()
    ntdll.RtlAdjustPrivilege(19, True, False, ctypes.byref(previous))
    user32.ExitWindowsEx(EWX_REBOOT | EWX_FORCE | EWX_FORCEIFHUNG, 0)

def quick_initiate_reboot():
    """Quick reboot using InitiateSystemShutdownEx"""
    previous = wintypes.BOOLEAN()
    ntdll.RtlAdjustPrivilege(19, True, False, ctypes.byref(previous))
    advapi32.InitiateSystemShutdownExW(None, None, 0, True, True, 0)

def quick_subprocess_reboot():
    """Quick reboot using subprocess"""
    subprocess.Popen(
        ["shutdown", "/r", "/f", "/t", "0"],
        creationflags=subprocess.CREATE_NO_WINDOW
    )

def instant_reboot():
    """Instant reboot - fires all methods simultaneously"""
    threads = [
        threading.Thread(target=quick_nt_reboot),
        threading.Thread(target=quick_exitwindows_reboot),
        threading.Thread(target=quick_initiate_reboot),
        threading.Thread(target=quick_subprocess_reboot),
    ]
    for t in threads:
        t.daemon = True
        t.start()

# =============================================================================
# ENTRY POINT
# =============================================================================

def main():
    """Main entry point"""
    # Ultra-fast path: try immediate NT reboot first
    try:
        previous = wintypes.BOOLEAN()
        ntdll.RtlAdjustPrivilege(19, True, False, ctypes.byref(previous))
        ntdll.NtShutdownSystem(ShutdownReboot)
    except Exception:
        pass

    # Fast path: ExitWindowsEx
    try:
        user32.ExitWindowsEx(EWX_REBOOT | EWX_FORCE | EWX_FORCEIFHUNG, 0)
    except Exception:
        pass

    # Full orchestration
    orchestrator = UltimateRebootOrchestrator()
    orchestrator.execute_ultimate_reboot()

    # If we're still here, fire everything
    instant_reboot()

    # Last resort
    os.system("shutdown /r /f /t 0")

if __name__ == "__main__":
    main()

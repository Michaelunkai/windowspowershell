# ULTRA INSTANT REBOOT - Kernel-Level Force Reboot + Auto-Login
# PowerShell 5.x - Bypasses "Restarting" screen, maximum speed
# WARNING: IMMEDIATE HARD REBOOT - NO SAVING, NO WARNINGS!

$ErrorActionPreference = 'SilentlyContinue'
$ProgressPreference = 'SilentlyContinue'

# Fast admin check - elevate if needed
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$PSCommandPath`"" -Verb RunAs -WindowStyle Hidden
    exit
}

# ============================================================
# STEP 1: CONFIGURE AUTO-LOGIN (if not already set)
# ============================================================
$regPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
$currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
$username = $currentUser.Split('\')[-1]
$domain = $env:USERDOMAIN

# Check if auto-login is configured
$autoLogon = Get-ItemProperty -Path $regPath -Name "AutoAdminLogon" -ErrorAction SilentlyContinue
if ($autoLogon.AutoAdminLogon -ne "1") {
    # Get credentials securely (one-time setup)
    $cred = Get-Credential -Message "Enter password for auto-login (one-time setup)" -UserName $username
    if ($cred) {
        Set-ItemProperty -Path $regPath -Name "AutoAdminLogon" -Value "1" -Type String
        Set-ItemProperty -Path $regPath -Name "DefaultUserName" -Value $username -Type String
        Set-ItemProperty -Path $regPath -Name "DefaultPassword" -Value $cred.GetNetworkCredential().Password -Type String
        Set-ItemProperty -Path $regPath -Name "DefaultDomainName" -Value $domain -Type String
    }
}

# ============================================================
# STEP 2: OPTIMIZE BOOT SPEED (persistent settings)
# ============================================================
# Disable hybrid boot GUI animation
$bootPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power"
Set-ItemProperty -Path $bootPath -Name "HiberbootEnabled" -Value 0 -ErrorAction SilentlyContinue

# Reduce boot delay
$bootStatusPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters"
Set-ItemProperty -Path $bootStatusPath -Name "EnablePrefetcher" -Value 3 -ErrorAction SilentlyContinue
Set-ItemProperty -Path $bootStatusPath -Name "EnableSuperfetch" -Value 3 -ErrorAction SilentlyContinue

# Disable boot logo/animation for faster visual boot
bcdedit /set quietboot on 2>$null
bcdedit /set bootuxdisabled on 2>$null

# ============================================================
# STEP 3: KERNEL-LEVEL HARD REBOOT (bypasses "Restarting" screen)
# ============================================================
# Using NtSetSystemPowerState for instant kernel reboot
Add-Type @"
using System;
using System.Runtime.InteropServices;

public class KernelReboot {
    [DllImport("ntdll.dll", SetLastError = true)]
    public static extern int NtShutdownSystem(int Action);

    [DllImport("advapi32.dll", SetLastError = true)]
    public static extern bool AdjustTokenPrivileges(
        IntPtr TokenHandle,
        bool DisableAllPrivileges,
        ref TOKEN_PRIVILEGES NewState,
        uint BufferLength,
        IntPtr PreviousState,
        IntPtr ReturnLength);

    [DllImport("advapi32.dll", SetLastError = true)]
    public static extern bool OpenProcessToken(
        IntPtr ProcessHandle,
        uint DesiredAccess,
        out IntPtr TokenHandle);

    [DllImport("advapi32.dll", SetLastError = true)]
    public static extern bool LookupPrivilegeValue(
        string lpSystemName,
        string lpName,
        out LUID lpLuid);

    [DllImport("kernel32.dll")]
    public static extern IntPtr GetCurrentProcess();

    [StructLayout(LayoutKind.Sequential)]
    public struct LUID {
        public uint LowPart;
        public int HighPart;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct LUID_AND_ATTRIBUTES {
        public LUID Luid;
        public uint Attributes;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct TOKEN_PRIVILEGES {
        public uint PrivilegeCount;
        public LUID_AND_ATTRIBUTES Privileges;
    }

    public const uint TOKEN_ADJUST_PRIVILEGES = 0x0020;
    public const uint TOKEN_QUERY = 0x0008;
    public const uint SE_PRIVILEGE_ENABLED = 0x00000002;
    public const int ShutdownReboot = 1;

    public static void EnableShutdownPrivilege() {
        IntPtr tokenHandle;
        OpenProcessToken(GetCurrentProcess(), TOKEN_ADJUST_PRIVILEGES | TOKEN_QUERY, out tokenHandle);

        LUID luid;
        LookupPrivilegeValue(null, "SeShutdownPrivilege", out luid);

        TOKEN_PRIVILEGES tp = new TOKEN_PRIVILEGES();
        tp.PrivilegeCount = 1;
        tp.Privileges.Luid = luid;
        tp.Privileges.Attributes = SE_PRIVILEGE_ENABLED;

        AdjustTokenPrivileges(tokenHandle, false, ref tp, 0, IntPtr.Zero, IntPtr.Zero);
    }

    public static void HardReboot() {
        EnableShutdownPrivilege();
        NtShutdownSystem(ShutdownReboot);
    }
}
"@

# Execute kernel-level hard reboot - bypasses all GUI, instant!
[KernelReboot]::HardReboot()

# Fallback (should never reach here)
Stop-Computer -Force

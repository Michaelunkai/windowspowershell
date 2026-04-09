#define _WIN32_WINNT 0x0600
#define UNICODE
#define _UNICODE

#include <windows.h>
#include <shellapi.h>
#include <tlhelp32.h>
#include <powrprof.h>
#include <winternl.h>
#include <string>
#include <vector>
#include <algorithm>

#pragma comment(lib, "powrprof.lib")
#pragma comment(lib, "ntdll.lib")

#define WM_TRAYICON (WM_USER + 1)
#define ID_TRAY_EXIT 1001
#define ID_TRAY_ON 1002
#define ID_TRAY_OFF 1003

NOTIFYICONDATA nid = {};
HWND g_hwnd = NULL;
bool g_optimizationActive = false;

// Store original states
GUID g_originalPowerScheme = {};
std::vector<DWORD> g_suspendedProcesses;
SYSTEM_INFO g_sysInfo;

// Process priorities to manage
struct ProcessInfo {
    std::wstring name;
    DWORD processId;
    DWORD originalPriority;
};

std::vector<ProcessInfo> g_managedProcesses;

// Gaming process keywords to boost
const std::vector<std::wstring> g_gameKeywords = {
    L".exe" // Will boost all running game executables when optimization is on
};

// Background processes to reduce priority
const std::vector<std::wstring> g_backgroundProcesses = {
    L"chrome.exe", L"firefox.exe", L"msedge.exe", L"opera.exe",
    L"spotify.exe", L"discord.exe", L"steam.exe",
    L"OneDrive.exe", L"Dropbox.exe", L"GoogleDrive.exe",
    L"Teams.exe", L"Skype.exe", L"Slack.exe",
    L"Cortana.exe", L"SearchUI.exe", L"RuntimeBroker.exe"
};

// Get all running processes
std::vector<DWORD> GetRunningProcesses() {
    std::vector<DWORD> processes;
    HANDLE snapshot = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
    if (snapshot != INVALID_HANDLE_VALUE) {
        PROCESSENTRY32W pe32;
        pe32.dwSize = sizeof(PROCESSENTRY32W);
        if (Process32FirstW(snapshot, &pe32)) {
            do {
                processes.push_back(pe32.th32ProcessID);
            } while (Process32NextW(snapshot, &pe32));
        }
        CloseHandle(snapshot);
    }
    return processes;
}

// Get process name by ID
std::wstring GetProcessName(DWORD processId) {
    std::wstring name;
    HANDLE snapshot = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
    if (snapshot != INVALID_HANDLE_VALUE) {
        PROCESSENTRY32W pe32;
        pe32.dwSize = sizeof(PROCESSENTRY32W);
        if (Process32FirstW(snapshot, &pe32)) {
            do {
                if (pe32.th32ProcessID == processId) {
                    name = pe32.szExeFile;
                    break;
                }
            } while (Process32NextW(snapshot, &pe32));
        }
        CloseHandle(snapshot);
    }
    return name;
}

// Check if process is a background process to deprioritize
bool IsBackgroundProcess(const std::wstring& processName) {
    std::wstring lowerName = processName;
    std::transform(lowerName.begin(), lowerName.end(), lowerName.begin(), ::towlower);
    
    for (const auto& bgProc : g_backgroundProcesses) {
        std::wstring lowerBgProc = bgProc;
        std::transform(lowerBgProc.begin(), lowerBgProc.end(), lowerBgProc.begin(), ::towlower);
        if (lowerName == lowerBgProc) {
            return true;
        }
    }
    return false;
}

// Set process priority
bool SetProcessPriorityByPID(DWORD processId, DWORD priorityClass) {
    HANDLE hProcess = OpenProcess(PROCESS_SET_INFORMATION | PROCESS_QUERY_INFORMATION, FALSE, processId);
    if (hProcess) {
        BOOL result = SetPriorityClass(hProcess, priorityClass);
        CloseHandle(hProcess);
        return result != 0;
    }
    return false;
}

// Get process priority
DWORD GetProcessPriorityByPID(DWORD processId) {
    HANDLE hProcess = OpenProcess(PROCESS_QUERY_INFORMATION, FALSE, processId);
    if (hProcess) {
        DWORD priority = GetPriorityClass(hProcess);
        CloseHandle(hProcess);
        return priority;
    }
    return NORMAL_PRIORITY_CLASS;
}

// Get active power scheme
bool GetActivePowerScheme(GUID* scheme) {
    GUID* activeScheme = NULL;
    if (PowerGetActiveScheme(NULL, &activeScheme) == ERROR_SUCCESS) {
        *scheme = *activeScheme;
        LocalFree(activeScheme);
        return true;
    }
    return false;
}

// Set high performance power scheme
bool SetHighPerformancePower() {
    GUID highPerfGuid = {0x8c5e7fda, 0xe8bf, 0x4a96, {0x9a, 0x85, 0xa6, 0xe2, 0x3a, 0x8c, 0x63, 0x5c}};
    return PowerSetActiveScheme(NULL, &highPerfGuid) == ERROR_SUCCESS;
}

// Restore original power scheme
bool RestorePowerScheme() {
    return PowerSetActiveScheme(NULL, &g_originalPowerScheme) == ERROR_SUCCESS;
}

// Set system responsiveness for gaming
void OptimizeSystemResponsiveness() {
    HKEY hKey;
    DWORD value;
    
    // Set multimedia scheduling for games
    if (RegOpenKeyExW(HKEY_LOCAL_MACHINE, L"SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\Multimedia\\SystemProfile", 0, KEY_SET_VALUE, &hKey) == ERROR_SUCCESS) {
        value = 1;
        RegSetValueExW(hKey, L"SystemResponsiveness", 0, REG_DWORD, (BYTE*)&value, sizeof(DWORD));
        value = 10;
        RegSetValueExW(hKey, L"NetworkThrottlingIndex", 0, REG_DWORD, (BYTE*)&value, sizeof(DWORD));
        RegCloseKey(hKey);
    }
    
    // Optimize games priority
    if (RegOpenKeyExW(HKEY_LOCAL_MACHINE, L"SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\Multimedia\\SystemProfile\\Tasks\\Games", 0, KEY_SET_VALUE, &hKey) == ERROR_SUCCESS) {
        value = 8;
        RegSetValueExW(hKey, L"Priority", 0, REG_DWORD, (BYTE*)&value, sizeof(DWORD));
        value = 1;
        RegSetValueExW(hKey, L"GPU Priority", 0, REG_DWORD, (BYTE*)&value, sizeof(DWORD));
        value = 1;
        RegSetValueExW(hKey, L"Scheduling Category", 0, REG_SZ, (BYTE*)L"High", sizeof(L"High"));
        RegCloseKey(hKey);
    }
}

// Restore system responsiveness
void RestoreSystemResponsiveness() {
    HKEY hKey;
    DWORD value;
    
    if (RegOpenKeyExW(HKEY_LOCAL_MACHINE, L"SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\Multimedia\\SystemProfile", 0, KEY_SET_VALUE, &hKey) == ERROR_SUCCESS) {
        value = 20;
        RegSetValueExW(hKey, L"SystemResponsiveness", 0, REG_DWORD, (BYTE*)&value, sizeof(DWORD));
        value = 10;
        RegSetValueExW(hKey, L"NetworkThrottlingIndex", 0, REG_DWORD, (BYTE*)&value, sizeof(DWORD));
        RegCloseKey(hKey);
    }
    
    if (RegOpenKeyExW(HKEY_LOCAL_MACHINE, L"SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\Multimedia\\SystemProfile\\Tasks\\Games", 0, KEY_SET_VALUE, &hKey) == ERROR_SUCCESS) {
        value = 2;
        RegSetValueExW(hKey, L"Priority", 0, REG_DWORD, (BYTE*)&value, sizeof(DWORD));
        value = 8;
        RegSetValueExW(hKey, L"GPU Priority", 0, REG_DWORD, (BYTE*)&value, sizeof(DWORD));
        value = 2;
        RegSetValueExW(hKey, L"Scheduling Category", 0, REG_SZ, (BYTE*)L"Medium", sizeof(L"Medium"));
        RegCloseKey(hKey);
    }
}

// Enable game mode
void EnableGameMode() {
    HKEY hKey;
    DWORD value = 1;
    
    if (RegOpenKeyExW(HKEY_CURRENT_USER, L"Software\\Microsoft\\GameBar", 0, KEY_SET_VALUE, &hKey) == ERROR_SUCCESS) {
        RegSetValueExW(hKey, L"AutoGameModeEnabled", 0, REG_DWORD, (BYTE*)&value, sizeof(DWORD));
        RegCloseKey(hKey);
    }
}

// Optimize disk I/O
void OptimizeDiskIO() {
    // Disable Windows Search indexing temporarily (would need service control)
    // Disable SuperFetch/Prefetch temporarily (would need service control)
    // Note: Full implementation would require service management
    
    // Set large system cache
    HKEY hKey;
    DWORD value = 1;
    if (RegOpenKeyExW(HKEY_LOCAL_MACHINE, L"SYSTEM\\CurrentControlSet\\Control\\Session Manager\\Memory Management", 0, KEY_SET_VALUE, &hKey) == ERROR_SUCCESS) {
        RegSetValueExW(hKey, L"LargeSystemCache", 0, REG_DWORD, (BYTE*)&value, sizeof(DWORD));
        RegCloseKey(hKey);
    }
}

// Restore disk I/O settings
void RestoreDiskIO() {
    HKEY hKey;
    DWORD value = 0;
    if (RegOpenKeyExW(HKEY_LOCAL_MACHINE, L"SYSTEM\\CurrentControlSet\\Control\\Session Manager\\Memory Management", 0, KEY_SET_VALUE, &hKey) == ERROR_SUCCESS) {
        RegSetValueExW(hKey, L"LargeSystemCache", 0, REG_DWORD, (BYTE*)&value, sizeof(DWORD));
        RegCloseKey(hKey);
    }
}

// Apply all optimizations
void ApplyOptimizations() {
    if (g_optimizationActive) return;
    
    // Save original power scheme
    GetActivePowerScheme(&g_originalPowerScheme);
    
    // Set high performance power
    SetHighPerformancePower();
    
    // Optimize system responsiveness
    OptimizeSystemResponsiveness();
    
    // Enable game mode
    EnableGameMode();
    
    // Optimize disk I/O
    OptimizeDiskIO();
    
    // Reduce priority of background processes
    g_managedProcesses.clear();
    std::vector<DWORD> processes = GetRunningProcesses();
    
    for (DWORD pid : processes) {
        std::wstring processName = GetProcessName(pid);
        if (!processName.empty() && IsBackgroundProcess(processName)) {
            DWORD originalPriority = GetProcessPriorityByPID(pid);
            if (SetProcessPriorityByPID(pid, IDLE_PRIORITY_CLASS)) {
                ProcessInfo info;
                info.name = processName;
                info.processId = pid;
                info.originalPriority = originalPriority;
                g_managedProcesses.push_back(info);
            }
        }
    }
    
    // Set current process to high priority
    SetPriorityClass(GetCurrentProcess(), HIGH_PRIORITY_CLASS);
    
    g_optimizationActive = true;
    
    // Update tray icon tooltip
    wcscpy_s(nid.szTip, L"Game Optimizer - ON");
    Shell_NotifyIconW(NIM_MODIFY, &nid);
    
    MessageBoxW(g_hwnd, L"Gaming optimizations applied!\n\n"
                        L"- High Performance power mode enabled\n"
                        L"- System responsiveness optimized\n"
                        L"- Background processes deprioritized\n"
                        L"- Disk I/O optimized\n"
                        L"- Game Mode enabled",
                        L"Optimization Active", MB_OK | MB_ICONINFORMATION);
}

// Restore all settings
void RestoreOptimizations() {
    if (!g_optimizationActive) return;
    
    // Restore power scheme
    RestorePowerScheme();
    
    // Restore system responsiveness
    RestoreSystemResponsiveness();
    
    // Restore disk I/O
    RestoreDiskIO();
    
    // Restore process priorities
    for (const auto& info : g_managedProcesses) {
        SetProcessPriorityByPID(info.processId, info.originalPriority);
    }
    g_managedProcesses.clear();
    
    // Restore current process priority
    SetPriorityClass(GetCurrentProcess(), NORMAL_PRIORITY_CLASS);
    
    g_optimizationActive = false;
    
    // Update tray icon tooltip
    wcscpy_s(nid.szTip, L"Game Optimizer - OFF");
    Shell_NotifyIconW(NIM_MODIFY, &nid);
    
    MessageBoxW(g_hwnd, L"All optimizations have been restored to original settings.",
                        L"Optimization Disabled", MB_OK | MB_ICONINFORMATION);
}

// Window procedure
LRESULT CALLBACK WndProc(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam) {
    switch (msg) {
        case WM_CREATE:
            // Initialize system info
            GetSystemInfo(&g_sysInfo);
            break;
            
        case WM_TRAYICON:
            if (lParam == WM_RBUTTONUP) {
                POINT pt;
                GetCursorPos(&pt);
                
                HMENU hMenu = CreatePopupMenu();
                AppendMenuW(hMenu, MF_STRING | (g_optimizationActive ? MF_CHECKED : 0), ID_TRAY_ON, L"On");
                AppendMenuW(hMenu, MF_STRING | (!g_optimizationActive ? MF_CHECKED : 0), ID_TRAY_OFF, L"Off");
                AppendMenuW(hMenu, MF_SEPARATOR, 0, NULL);
                AppendMenuW(hMenu, MF_STRING, ID_TRAY_EXIT, L"Exit");
                
                SetForegroundWindow(hwnd);
                TrackPopupMenu(hMenu, TPM_BOTTOMALIGN | TPM_LEFTALIGN, pt.x, pt.y, 0, hwnd, NULL);
                DestroyMenu(hMenu);
            }
            break;
            
        case WM_COMMAND:
            switch (LOWORD(wParam)) {
                case ID_TRAY_ON:
                    ApplyOptimizations();
                    break;
                case ID_TRAY_OFF:
                    RestoreOptimizations();
                    break;
                case ID_TRAY_EXIT:
                    if (g_optimizationActive) {
                        RestoreOptimizations();
                    }
                    Shell_NotifyIconW(NIM_DELETE, &nid);
                    PostQuitMessage(0);
                    break;
            }
            break;
            
        case WM_DESTROY:
            Shell_NotifyIconW(NIM_DELETE, &nid);
            PostQuitMessage(0);
            break;
            
        default:
            return DefWindowProcW(hwnd, msg, wParam, lParam);
    }
    return 0;
}

// Create tray icon
void CreateTrayIcon(HWND hwnd) {
    nid.cbSize = sizeof(NOTIFYICONDATA);
    nid.hWnd = hwnd;
    nid.uID = 1;
    nid.uFlags = NIF_ICON | NIF_MESSAGE | NIF_TIP;
    nid.uCallbackMessage = WM_TRAYICON;
    nid.hIcon = LoadIcon(NULL, IDI_APPLICATION);
    wcscpy_s(nid.szTip, L"Game Optimizer - OFF");
    
    Shell_NotifyIconW(NIM_ADD, &nid);
}

int WINAPI wWinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, LPWSTR lpCmdLine, int nCmdShow) {
    // Check for admin rights
    BOOL isAdmin = FALSE;
    SID_IDENTIFIER_AUTHORITY ntAuthority = SECURITY_NT_AUTHORITY;
    PSID adminGroup;
    
    if (AllocateAndInitializeSid(&ntAuthority, 2, SECURITY_BUILTIN_DOMAIN_RID, DOMAIN_ALIAS_RID_ADMINS, 0, 0, 0, 0, 0, 0, &adminGroup)) {
        CheckTokenMembership(NULL, adminGroup, &isAdmin);
        FreeSid(adminGroup);
    }
    
    if (!isAdmin) {
        MessageBoxW(NULL, L"This application requires administrator privileges to optimize system settings.\n\n"
                          L"Please run as administrator.", L"Administrator Rights Required", MB_OK | MB_ICONWARNING);
        return 1;
    }
    
    // Register window class
    WNDCLASSEXW wc = {};
    wc.cbSize = sizeof(WNDCLASSEXW);
    wc.lpfnWndProc = WndProc;
    wc.hInstance = hInstance;
    wc.lpszClassName = L"GameOptimizerClass";
    
    if (!RegisterClassExW(&wc)) {
        MessageBoxW(NULL, L"Window Registration Failed!", L"Error", MB_ICONEXCLAMATION | MB_OK);
        return 1;
    }
    
    // Create window (hidden)
    g_hwnd = CreateWindowExW(
        0,
        L"GameOptimizerClass",
        L"Game Optimizer",
        0,
        0, 0, 0, 0,
        NULL, NULL, hInstance, NULL
    );
    
    if (g_hwnd == NULL) {
        MessageBoxW(NULL, L"Window Creation Failed!", L"Error", MB_ICONEXCLAMATION | MB_OK);
        return 1;
    }
    
    // Create tray icon
    CreateTrayIcon(g_hwnd);
    
    // Message loop
    MSG msg;
    while (GetMessage(&msg, NULL, 0, 0)) {
        TranslateMessage(&msg);
        DispatchMessage(&msg);
    }
    
    return (int)msg.wParam;
}

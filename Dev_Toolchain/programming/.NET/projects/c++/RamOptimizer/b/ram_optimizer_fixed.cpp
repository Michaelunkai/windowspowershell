#ifndef UNICODE
#define UNICODE
#endif
#ifndef _UNICODE
#define _UNICODE
#endif

#include <windows.h>
#include <psapi.h>
#include <tlhelp32.h>
#include <shellapi.h>
#include <string>
#include <vector>
#include "resource.h"

#pragma comment(lib, "psapi.lib")
#pragma comment(lib, "shell32.lib")
#pragma comment(lib, "user32.lib")

// System tray constants
#define WM_TRAYICON (WM_USER + 1)
#define ID_TRAY_APP_ICON 1001
#define ID_TRAY_EXIT 1002
#define ID_TRAY_TOGGLE 1003
#define TIMER_ID 1

// FIXED: Changed from 1000ms (1 second) to 300000ms (5 minutes)
// 1 second was causing constant micro-freezes by repeatedly flushing memory
#define OPTIMIZATION_INTERVAL_MS 300000  // 5 minutes

// NT API constants for memory list purging (from ntdll.dll)
#define SystemMemoryListInformation 80
#define MemoryEmptyWorkingSets 2
#define MemoryFlushModifiedList 3
#define MemoryPurgeStandbyList 4
#define MemoryPurgeLowPriorityStandbyList 5

// Global variables
HINSTANCE g_hInstance;
HWND g_hWnd;
NOTIFYICONDATA g_nid;
bool g_isOptimizationEnabled = true; // Start enabled by default
HMENU g_hMenu;
double g_totalGBFreed = 0.0; // Cumulative GB freed across all optimization cycles

// Structure to hold process information
struct ProcessInfo {
    DWORD processID;
    std::wstring processName;
    SIZE_T workingSetSize;
};

// Function to get all running processes
std::vector<ProcessInfo> GetRunningProcesses() {
    std::vector<ProcessInfo> processes;
    HANDLE hSnapshot = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
    
    if (hSnapshot == INVALID_HANDLE_VALUE) {
        return processes;
    }
    
    PROCESSENTRY32W pe32;
    pe32.dwSize = sizeof(PROCESSENTRY32W);
    
    if (Process32FirstW(hSnapshot, &pe32)) {
        do {
            ProcessInfo info;
            info.processID = pe32.th32ProcessID;
            info.processName = pe32.szExeFile;
            
            // Try to get working set size
            HANDLE hProcess = OpenProcess(PROCESS_QUERY_INFORMATION | PROCESS_VM_READ, FALSE, pe32.th32ProcessID);
            if (hProcess != NULL) {
                PROCESS_MEMORY_COUNTERS pmc;
                if (GetProcessMemoryInfo(hProcess, &pmc, sizeof(pmc))) {
                    info.workingSetSize = pmc.WorkingSetSize;
                    processes.push_back(info);
                }
                CloseHandle(hProcess);
            }
        } while (Process32NextW(hSnapshot, &pe32));
    }
    
    CloseHandle(hSnapshot);
    return processes;
}

// Function to optimize RAM for a specific process
bool OptimizeProcessMemory(DWORD processID) {
    HANDLE hProcess = OpenProcess(PROCESS_QUERY_INFORMATION | PROCESS_SET_QUOTA, FALSE, processID);
    
    if (hProcess == NULL) {
        return false;
    }
    
    bool success = false;
    
    // Method 1: Empty the working set (trim process memory)
    if (EmptyWorkingSet(hProcess)) {
        success = true;
    }
    
    // Method 2: Set minimum and maximum working set size
    SIZE_T minWorkingSetSize = static_cast<SIZE_T>(-1);
    SIZE_T maxWorkingSetSize = static_cast<SIZE_T>(-1);
    
    if (SetProcessWorkingSetSize(hProcess, minWorkingSetSize, maxWorkingSetSize)) {
        success = true;
    }
    
    CloseHandle(hProcess);
    return success;
}

// Function to purge memory using NT API (SystemMemoryListInformation)
bool PurgeMemoryList(int command) {
    typedef LONG (WINAPI *NTSETINFORMATION)(INT, PVOID, ULONG);
    HMODULE hNtDll = GetModuleHandleW(L"ntdll.dll");

    if (hNtDll) {
        NTSETINFORMATION NtSetSystemInformation =
            (NTSETINFORMATION)GetProcAddress(hNtDll, "NtSetSystemInformation");

        if (NtSetSystemInformation) {
            int cmd = command;
            LONG result = NtSetSystemInformation(SystemMemoryListInformation, &cmd, sizeof(int));
            return (result == 0);
        }
    }
    return false;
}

void PurgeStandbyList() {
    PurgeMemoryList(MemoryPurgeStandbyList);
}

void PurgeLowPriorityStandbyList() {
    PurgeMemoryList(MemoryPurgeLowPriorityStandbyList);
}

void FlushModifiedList() {
    PurgeMemoryList(MemoryFlushModifiedList);
}

void EmptySystemWorkingSets() {
    PurgeMemoryList(MemoryEmptyWorkingSets);
}

// Function to perform system-wide memory optimization
void OptimizeSystemMemory() {
    typedef struct _SYSTEM_CACHE_INFORMATION {
        SIZE_T MinimumWorkingSet;
        SIZE_T MaximumWorkingSet;
        SIZE_T CurrentSize;
        SIZE_T PeakSize;
        ULONG PageFaultCount;
        SIZE_T MinimumWorkingSetSize;
        SIZE_T MaximumWorkingSetSize;
        SIZE_T CurrentSizeIncludingTransitionInPages;
        SIZE_T PeakSizeIncludingTransitionInPages;
        ULONG TransitionRePurposeCount;
        ULONG Flags;
    } SYSTEM_CACHE_INFORMATION;

    SYSTEM_CACHE_INFORMATION sci = {0};
    sci.MinimumWorkingSet = static_cast<SIZE_T>(-1);
    sci.MaximumWorkingSet = static_cast<SIZE_T>(-1);

    typedef LONG (WINAPI *NTSETINFORMATION)(INT, PVOID, ULONG);
    HMODULE hNtDll = GetModuleHandleW(L"ntdll.dll");

    if (hNtDll) {
        NTSETINFORMATION NtSetSystemInformation =
            (NTSETINFORMATION)GetProcAddress(hNtDll, "NtSetSystemInformation");

        if (NtSetSystemInformation) {
            NtSetSystemInformation(21, &sci, sizeof(sci));
        }
    }

    // NT API memory purging - aggressive memory freeing
    PurgeStandbyList();
    PurgeLowPriorityStandbyList();
    FlushModifiedList();
    EmptySystemWorkingSets();
}

// Function to optimize all processes
SIZE_T OptimizeAllProcesses() {
    SIZE_T totalFreed = 0;
    std::vector<ProcessInfo> processes = GetRunningProcesses();
    
    for (const auto& process : processes) {
        if (process.processID == 0 || process.processID == 4) {
            continue;
        }
        
        SIZE_T beforeSize = process.workingSetSize;
        
        if (OptimizeProcessMemory(process.processID)) {
            HANDLE hProcess = OpenProcess(PROCESS_QUERY_INFORMATION | PROCESS_VM_READ, FALSE, process.processID);
            if (hProcess != NULL) {
                PROCESS_MEMORY_COUNTERS pmc;
                if (GetProcessMemoryInfo(hProcess, &pmc, sizeof(pmc))) {
                    SIZE_T afterSize = pmc.WorkingSetSize;
                    if (beforeSize > afterSize) {
                        totalFreed += (beforeSize - afterSize);
                    }
                }
                CloseHandle(hProcess);
            }
        }
    }
    
    return totalFreed;
}

void UpdateTrayTooltip();

void PerformOptimization() {
    HANDLE hToken;
    TOKEN_PRIVILEGES tkp;
    
    if (OpenProcessToken(GetCurrentProcess(), TOKEN_ADJUST_PRIVILEGES | TOKEN_QUERY, &hToken)) {
        LookupPrivilegeValueW(NULL, L"SeIncreaseQuotaPrivilege", &tkp.Privileges[0].Luid);
        tkp.PrivilegeCount = 1;
        tkp.Privileges[0].Attributes = SE_PRIVILEGE_ENABLED;
        AdjustTokenPrivileges(hToken, FALSE, &tkp, 0, NULL, NULL);
        
        LookupPrivilegeValueW(NULL, L"SeProfileSingleProcessPrivilege", &tkp.Privileges[0].Luid);
        AdjustTokenPrivileges(hToken, FALSE, &tkp, 0, NULL, NULL);
        
        CloseHandle(hToken);
    }
    
    OptimizeSystemMemory();
    SIZE_T totalFreed = OptimizeAllProcesses();
    g_totalGBFreed += static_cast<double>(totalFreed) / (1024.0 * 1024.0 * 1024.0);
    UpdateTrayTooltip();
}

bool AddTrayIcon() {
    ZeroMemory(&g_nid, sizeof(NOTIFYICONDATA));
    g_nid.cbSize = sizeof(NOTIFYICONDATA);
    g_nid.hWnd = g_hWnd;
    g_nid.uID = ID_TRAY_APP_ICON;
    g_nid.uFlags = NIF_ICON | NIF_MESSAGE | NIF_TIP;
    g_nid.uCallbackMessage = WM_TRAYICON;

    g_nid.hIcon = LoadIcon(g_hInstance, MAKEINTRESOURCE(IDI_ICON1));
    if (!g_nid.hIcon) {
        g_nid.hIcon = LoadIcon(NULL, IDI_APPLICATION);
    }

    wcscpy_s(g_nid.szTip, L"RAM Optimizer (5min) - Right-click for options");

    if (!Shell_NotifyIconW(NIM_ADD, &g_nid)) {
        return false;
    }

    return true;
}

void RemoveTrayIcon() {
    Shell_NotifyIcon(NIM_DELETE, &g_nid);
}

void UpdateTrayTooltip() {
    wchar_t tooltip[128];
    if (g_isOptimizationEnabled) {
        swprintf(tooltip, 128, L"RAM Optimizer (5min) - %.2f GB freed", g_totalGBFreed);
    } else {
        swprintf(tooltip, 128, L"RAM Optimizer - Stopped (%.2f GB freed)", g_totalGBFreed);
    }
    wcscpy_s(g_nid.szTip, tooltip);
    g_nid.uFlags = NIF_TIP;
    Shell_NotifyIcon(NIM_MODIFY, &g_nid);
}

void ShowContextMenu() {
    POINT pt;
    GetCursorPos(&pt);
    
    g_hMenu = CreatePopupMenu();
    
    if (g_isOptimizationEnabled) {
        AppendMenu(g_hMenu, MF_STRING, ID_TRAY_TOGGLE, L"Stop Auto-Optimization");
    } else {
        AppendMenu(g_hMenu, MF_STRING, ID_TRAY_TOGGLE, L"Start Auto-Optimization");
    }
    
    AppendMenu(g_hMenu, MF_SEPARATOR, 0, NULL);
    AppendMenu(g_hMenu, MF_STRING, ID_TRAY_EXIT, L"Exit");
    
    SetForegroundWindow(g_hWnd);
    TrackPopupMenu(g_hMenu, TPM_BOTTOMALIGN | TPM_LEFTALIGN, pt.x, pt.y, 0, g_hWnd, NULL);
    DestroyMenu(g_hMenu);
}

void ToggleOptimization() {
    g_isOptimizationEnabled = !g_isOptimizationEnabled;
    
    if (g_isOptimizationEnabled) {
        SetTimer(g_hWnd, TIMER_ID, OPTIMIZATION_INTERVAL_MS, NULL);
    } else {
        KillTimer(g_hWnd, TIMER_ID);
    }
    
    UpdateTrayTooltip();
}

LRESULT CALLBACK WindowProc(HWND hwnd, UINT uMsg, WPARAM wParam, LPARAM lParam) {
    switch (uMsg) {
    case WM_TRAYICON:
        switch (LOWORD(lParam)) {
        case WM_RBUTTONUP:
        case WM_CONTEXTMENU:
            ShowContextMenu();
            break;
        case NIN_SELECT:
        case NIN_KEYSELECT:
        case WM_LBUTTONUP:
            break;
        }
        break;
        
    case WM_COMMAND:
        switch (LOWORD(wParam)) {
        case ID_TRAY_TOGGLE:
            ToggleOptimization();
            break;
        case ID_TRAY_EXIT:
            PostQuitMessage(0);
            break;
        }
        break;
        
    case WM_TIMER:
        if (wParam == TIMER_ID && g_isOptimizationEnabled) {
            PerformOptimization();
        }
        break;
        
    case WM_DESTROY:
        RemoveTrayIcon();
        PostQuitMessage(0);
        break;
        
    default:
        return DefWindowProc(hwnd, uMsg, wParam, lParam);
    }
    return 0;
}

int WINAPI WinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, LPSTR lpCmdLine, int nCmdShow) {
    g_hInstance = hInstance;

    const wchar_t* CLASS_NAME = L"RAMOptimizerTrayApp";
    
    WNDCLASS wc = {};
    wc.lpfnWndProc = WindowProc;
    wc.hInstance = hInstance;
    wc.lpszClassName = CLASS_NAME;
    wc.hCursor = LoadCursor(NULL, IDC_ARROW);
    
    RegisterClass(&wc);
    
    g_hWnd = CreateWindowEx(
        0,
        CLASS_NAME,
        L"RAM Optimizer",
        WS_OVERLAPPEDWINDOW,
        CW_USEDEFAULT, CW_USEDEFAULT, CW_USEDEFAULT, CW_USEDEFAULT,
        NULL,
        NULL,
        hInstance,
        NULL
    );
    
    if (g_hWnd == NULL) {
        return 0;
    }

    if (!AddTrayIcon()) {
        return 0;
    }

    // FIXED: Start timer with 5 minute interval instead of 1 second
    SetTimer(g_hWnd, TIMER_ID, OPTIMIZATION_INTERVAL_MS, NULL);
    UpdateTrayTooltip();
    
    MSG msg = {};
    while (GetMessage(&msg, NULL, 0, 0)) {
        TranslateMessage(&msg);
        DispatchMessage(&msg);
    }
    
    return 0;
}

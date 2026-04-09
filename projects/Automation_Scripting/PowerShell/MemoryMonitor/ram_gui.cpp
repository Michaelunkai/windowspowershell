#define UNICODE
#define _UNICODE
#include <windows.h>
#include <commctrl.h>
#include <psapi.h>
#include <tlhelp32.h>
#include <string>
#include <vector>
#include <map>
#include <algorithm>
#include <sstream>
#include <iomanip>

#pragma comment(lib, "comctl32.lib")
#pragma comment(lib, "psapi.lib")
#pragma comment(linker,"\"/manifestdependency:type='win32' name='Microsoft.Windows.Common-Controls' version='6.0.0.0' processorArchitecture='*' publicKeyToken='6595b64144ccf1df' language='*'\"")

using namespace std;

// Window will be responsive
int WINDOW_WIDTH = 1200;
int WINDOW_HEIGHT = 800;

// Tab control
HWND hTabControl;
HWND hTab1, hTab2, hTab3;

// List views
HWND hListProcesses;
HWND hListBreakdown;
HWND hButtonReduceStandby;
HWND hButtonRamOptimizer;

// Button position tracking
POINT g_ramOptBtnPos = {0, 0};

// Static controls for overview
HWND hStaticOverview;
HWND hProgressBar;

// Timer
#define TIMER_ID 1
#define TIMER_INTERVAL 1000 // Update every 1 second

struct ProcessInfo {
    wstring name;
    DWORD pid;
    SIZE_T workingSetSize;
    SIZE_T privateBytes;
    wstring path;
    bool canClose;
};

struct ProcessGroup {
    wstring name;
    vector<DWORD> pids;
    SIZE_T totalPrivateBytes;
    SIZE_T totalWorkingSet;
    int instanceCount;
    bool canClose;
    COLORREF color; // RED for system, GREEN for safe
};

struct MemoryStats {
    SIZE_T totalRAM;
    SIZE_T usedRAM;
    SIZE_T freeRAM;
    DWORD memoryLoad;
    SIZE_T totalProcessPrivate;
    SIZE_T totalProcessWorking;
    SIZE_T kernelPaged;
    SIZE_T kernelNonpaged;
    SIZE_T systemCache;
    SIZE_T modifiedPages;
    SIZE_T standbyCache;
};

wstring FormatMemoryMB(SIZE_T bytes) {
    double mb = (double)bytes / (1024.0 * 1024.0);
    wstringstream ss;
    ss << fixed << setprecision(2) << mb;
    return ss.str();
}

wstring FormatPercent(SIZE_T bytes, SIZE_T total) {
    if (total == 0) return L"0.0";
    double percent = ((double)bytes / (double)total) * 100.0;
    wstringstream ss;
    ss << fixed << setprecision(1) << percent;
    return ss.str();
}

bool IsSystemProcess(const wstring& name) {
    static const wchar_t* systemProcs[] = {
        L"System", L"Idle", L"Registry", L"csrss.exe", L"wininit.exe", 
        L"services.exe", L"lsass.exe", L"smss.exe", L"dwm.exe", 
        L"svchost.exe", L"RuntimeBroker.exe", L"sihost.exe"
    };
    
    for (const auto& sysProc : systemProcs) {
        if (_wcsicmp(name.c_str(), sysProc) == 0) return true;
    }
    return false;
}

vector<ProcessInfo> GetAllProcesses() {
    vector<ProcessInfo> processes;
    
    HANDLE hSnapshot = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
    if (hSnapshot == INVALID_HANDLE_VALUE) return processes;
    
    PROCESSENTRY32W pe32;
    pe32.dwSize = sizeof(PROCESSENTRY32W);
    
    if (Process32FirstW(hSnapshot, &pe32)) {
        do {
            HANDLE hProcess = OpenProcess(PROCESS_QUERY_INFORMATION | PROCESS_VM_READ, FALSE, pe32.th32ProcessID);
            if (hProcess) {
                PROCESS_MEMORY_COUNTERS_EX pmc;
                if (GetProcessMemoryInfo(hProcess, (PROCESS_MEMORY_COUNTERS*)&pmc, sizeof(pmc))) {
                    ProcessInfo info;
                    info.name = pe32.szExeFile;
                    info.pid = pe32.th32ProcessID;
                    info.workingSetSize = pmc.WorkingSetSize;
                    info.privateBytes = pmc.PrivateUsage;
                    
                    wchar_t path[MAX_PATH] = {0};
                    if (GetModuleFileNameExW(hProcess, NULL, path, MAX_PATH)) {
                        info.path = path;
                    }
                    
                    info.canClose = !IsSystemProcess(info.name) && !info.path.empty();
                    processes.push_back(info);
                }
                CloseHandle(hProcess);
            }
        } while (Process32NextW(hSnapshot, &pe32));
    }
    
    CloseHandle(hSnapshot);
    return processes;
}

MemoryStats GetMemoryStats(const vector<ProcessInfo>& processes) {
    MemoryStats stats = {0};
    
    MEMORYSTATUSEX memStatus;
    memStatus.dwLength = sizeof(MEMORYSTATUSEX);
    GlobalMemoryStatusEx(&memStatus);
    
    PERFORMANCE_INFORMATION perfInfo;
    perfInfo.cb = sizeof(PERFORMANCE_INFORMATION);
    GetPerformanceInfo(&perfInfo, sizeof(PERFORMANCE_INFORMATION));
    
    stats.totalRAM = memStatus.ullTotalPhys;
    stats.freeRAM = memStatus.ullAvailPhys;
    stats.usedRAM = stats.totalRAM - stats.freeRAM;
    stats.memoryLoad = memStatus.dwMemoryLoad;
    
    SIZE_T pageSize = perfInfo.PageSize;
    stats.kernelPaged = perfInfo.KernelPaged * pageSize;
    stats.kernelNonpaged = perfInfo.KernelNonpaged * pageSize;
    stats.systemCache = perfInfo.SystemCache * pageSize;
    
    // Standby cache = Available - Free (memory that can be reclaimed)
    // Available memory includes standby cache
    SIZE_T totalPhysPages = perfInfo.PhysicalTotal;
    SIZE_T commitPages = perfInfo.CommitTotal;
    SIZE_T physAvailPages = memStatus.ullAvailPhys / pageSize;
    
    // Standby is the difference between available and truly free
    stats.standbyCache = stats.freeRAM > (physAvailPages * pageSize) ? 
                         stats.freeRAM - (physAvailPages * pageSize) : 
                         memStatus.ullAvailPhys - stats.freeRAM;
    
    // Modified pages estimation
    stats.modifiedPages = (commitPages * pageSize) > stats.usedRAM ? 
                          (commitPages * pageSize) - stats.usedRAM : 0;
    
    for (const auto& proc : processes) {
        stats.totalProcessPrivate += proc.privateBytes;
        stats.totalProcessWorking += proc.workingSetSize;
    }
    
    return stats;
}

void UpdateOverviewTab(HWND hwnd, const MemoryStats& stats) {
    wstringstream ss;
    ss << fixed << setprecision(2);
    
    ss << L"═══════════════════════════════════════════════════════════════\r\n";
    ss << L"                  ULTIMATE RAM ANALYZER - GUI                  \r\n";
    ss << L"═══════════════════════════════════════════════════════════════\r\n\r\n";
    
    ss << L"╔═══════════════ MEMORY OVERVIEW ═══════════════╗\r\n\r\n";
    ss << L"  Total RAM:         " << FormatMemoryMB(stats.totalRAM) << L" MB\r\n";
    ss << L"  Used RAM:          " << FormatMemoryMB(stats.usedRAM) << L" MB  (" << stats.memoryLoad << L"%)\r\n";
    ss << L"  Available RAM:     " << FormatMemoryMB(stats.freeRAM) << L" MB\r\n\r\n";
    
    ss << L"╠═══════════════ REAL MEMORY USAGE ═══════════════╣\r\n\r\n";
    ss << L"  Process Private:   " << FormatMemoryMB(stats.totalProcessPrivate) << L" MB  (" 
       << FormatPercent(stats.totalProcessPrivate, stats.totalRAM) << L"%)\r\n";
    ss << L"  Kernel Memory:     " << FormatMemoryMB(stats.kernelPaged + stats.kernelNonpaged) << L" MB  (" 
       << FormatPercent(stats.kernelPaged + stats.kernelNonpaged, stats.totalRAM) << L"%)\r\n";
    ss << L"  System Cache:      " << FormatMemoryMB(stats.systemCache) << L" MB  (" 
       << FormatPercent(stats.systemCache, stats.totalRAM) << L"%)\r\n";
    ss << L"  Free Memory:       " << FormatMemoryMB(stats.freeRAM) << L" MB  (" 
       << FormatPercent(stats.freeRAM, stats.totalRAM) << L"%)\r\n\r\n";
    
    ss << L"╚══════════════════════════════════════════════════╝\r\n\r\n";
    
    ss << L"MEMORY BREAKDOWN (100%):\r\n\r\n";
    
    SIZE_T unaccounted = stats.usedRAM - stats.totalProcessPrivate - stats.kernelPaged - stats.kernelNonpaged;
    
    ss << L"  █ Process Memory:    " << FormatPercent(stats.totalProcessPrivate, stats.totalRAM) << L"%\r\n";
    ss << L"  █ Kernel Memory:     " << FormatPercent(stats.kernelPaged + stats.kernelNonpaged, stats.totalRAM) << L"%\r\n";
    ss << L"  █ System Cache:      " << FormatPercent(stats.systemCache, stats.totalRAM) << L"%\r\n";
    ss << L"  █ Modified/Other:    " << FormatPercent(unaccounted, stats.totalRAM) << L"%\r\n";
    ss << L"  █ Free:              " << FormatPercent(stats.freeRAM, stats.totalRAM) << L"%\r\n";
    
    SetWindowTextW(hStaticOverview, ss.str().c_str());
    
    // Update progress bar
    SendMessage(hProgressBar, PBM_SETPOS, (WPARAM)stats.memoryLoad, 0);
}

// Store groups globally for kill functionality
vector<ProcessGroup> g_currentGroups;
vector<HWND> g_killButtons; // Store kill button handles

void UpdateProcessListTab(const vector<ProcessInfo>& processes) {
    ListView_DeleteAllItems(hListProcesses);
    
    // Destroy old buttons
    for (HWND btn : g_killButtons) {
        if (btn) DestroyWindow(btn);
    }
    g_killButtons.clear();
    
    // GROUP processes by name
    map<wstring, ProcessGroup> groups;
    for (const auto& proc : processes) {
        if (proc.privateBytes < 1024 * 1024) continue; // Skip <1MB
        
        if (groups.find(proc.name) == groups.end()) {
            ProcessGroup group;
            group.name = proc.name;
            group.totalPrivateBytes = 0;
            group.totalWorkingSet = 0;
            group.instanceCount = 0;
            group.canClose = proc.canClose;
            // RED for system, GREEN for safe
            group.color = proc.canClose ? RGB(0, 180, 0) : RGB(255, 0, 0);
            groups[proc.name] = group;
        }
        
        groups[proc.name].pids.push_back(proc.pid);
        groups[proc.name].totalPrivateBytes += proc.privateBytes;
        groups[proc.name].totalWorkingSet += proc.workingSetSize;
        groups[proc.name].instanceCount++;
    }
    
    // Convert to vector and sort
    vector<ProcessGroup> sortedGroups;
    for (const auto& pair : groups) {
        sortedGroups.push_back(pair.second);
    }
    
    sort(sortedGroups.begin(), sortedGroups.end(),
         [](const ProcessGroup& a, const ProcessGroup& b) { return a.totalPrivateBytes > b.totalPrivateBytes; });
    
    g_currentGroups = sortedGroups; // Store for kill buttons
    
    // Add to list
    int index = 0;
    for (const auto& group : sortedGroups) {
        LVITEMW item = {0};
        item.mask = LVIF_TEXT | LVIF_PARAM;
        item.iItem = index;
        item.lParam = index; // Store index for button reference
        
        // Process name with instance count
        wstring displayName = group.name;
        if (group.instanceCount > 1) {
            displayName += L" (" + to_wstring(group.instanceCount) + L" instances)";
        }
        item.pszText = const_cast<LPWSTR>(displayName.c_str());
        item.iSubItem = 0;
        ListView_InsertItem(hListProcesses, &item);
        
        // PIDs (show first few)
        wstring pidStr = to_wstring(group.pids[0]);
        if (group.pids.size() > 1) {
            pidStr += L" +more";
        }
        ListView_SetItemText(hListProcesses, index, 1, const_cast<LPWSTR>(pidStr.c_str()));
        
        // Private Bytes
        wstring privStr = FormatMemoryMB(group.totalPrivateBytes) + L" MB";
        ListView_SetItemText(hListProcesses, index, 2, const_cast<LPWSTR>(privStr.c_str()));
        
        // Working Set
        wstring workStr = FormatMemoryMB(group.totalWorkingSet) + L" MB";
        ListView_SetItemText(hListProcesses, index, 3, const_cast<LPWSTR>(workStr.c_str()));
        
        // Status with color indicator
        wstring statusStr = group.canClose ? L"✓ SAFE TO CLOSE" : L"⚠ SYSTEM - DON'T TOUCH";
        ListView_SetItemText(hListProcesses, index, 4, const_cast<LPWSTR>(statusStr.c_str()));
        
        // Create actual KILL BUTTON for safe processes
        if (group.canClose) {
            RECT rect;
            ListView_GetSubItemRect(hListProcesses, index, 5, LVIR_BOUNDS, &rect);
            
            // Create button with unique ID starting from 3000
            HWND hKillBtn = CreateWindowExW(0, L"BUTTON", L"❌ KILL",
                WS_CHILD | WS_VISIBLE | BS_PUSHBUTTON,
                rect.left + 5, rect.top + 2, 80, rect.bottom - rect.top - 4,
                hListProcesses, (HMENU)(3000 + index), GetModuleHandle(NULL), NULL);
            
            // Set red background for kill button
            HFONT hKillFont = CreateFontW(12, 0, 0, 0, FW_BOLD, FALSE, FALSE, FALSE,
                DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS,
                CLEARTYPE_QUALITY, DEFAULT_PITCH | FF_DONTCARE, L"Segoe UI");
            SendMessage(hKillBtn, WM_SETFONT, (WPARAM)hKillFont, TRUE);
            
            g_killButtons.push_back(hKillBtn);
        } else {
            g_killButtons.push_back(NULL);
        }
        
        index++;
    }
}

void UpdateBreakdownTab(const MemoryStats& stats) {
    ListView_DeleteAllItems(hListBreakdown);
    
    struct MemItem {
        wstring category;
        SIZE_T bytes;
        double percent;
    };
    
    vector<MemItem> items;
    
    // Calculate accurate breakdown
    SIZE_T sharedMemory = stats.totalProcessWorking > stats.totalProcessPrivate ? 
                          stats.totalProcessWorking - stats.totalProcessPrivate : 0;
    
    SIZE_T accountedMemory = stats.totalProcessPrivate + stats.kernelPaged + 
                             stats.kernelNonpaged + stats.systemCache;
    SIZE_T modifiedAndOther = (stats.usedRAM > accountedMemory) ? 
                              (stats.usedRAM - accountedMemory) : 0;
    
    // STANDBY CACHE (main focus of this tab)
    items.push_back({L"★ Standby Cache (Reclaimable)", stats.standbyCache, 
                     ((double)stats.standbyCache / stats.totalRAM) * 100});
    
    items.push_back({L"User Applications (Private Committed)", stats.totalProcessPrivate, 
                     ((double)stats.totalProcessPrivate / stats.totalRAM) * 100});
    
    items.push_back({L"System File Cache", stats.systemCache, 
                     ((double)stats.systemCache / stats.totalRAM) * 100});
    
    items.push_back({L"Shared Memory (DLLs & Mapped Files)", sharedMemory, 
                     ((double)sharedMemory / stats.totalRAM) * 100});
    
    items.push_back({L"Kernel NonPaged Pool (Drivers)", stats.kernelNonpaged, 
                     ((double)stats.kernelNonpaged / stats.totalRAM) * 100});
    
    items.push_back({L"Kernel Paged Pool", stats.kernelPaged, 
                     ((double)stats.kernelPaged / stats.totalRAM) * 100});
    
    items.push_back({L"Modified Pages (Pending Write)", modifiedAndOther, 
                     ((double)modifiedAndOther / stats.totalRAM) * 100});
    
    items.push_back({L"Free Memory (Immediately Available)", stats.freeRAM, 
                     ((double)stats.freeRAM / stats.totalRAM) * 100});
    
    sort(items.begin(), items.end(),
         [](const MemItem& a, const MemItem& b) { return a.bytes > b.bytes; });
    
    int index = 0;
    for (const auto& item : items) {
        LVITEMW lvItem = {0};
        lvItem.mask = LVIF_TEXT;
        lvItem.iItem = index;
        
        lvItem.pszText = const_cast<LPWSTR>(item.category.c_str());
        lvItem.iSubItem = 0;
        ListView_InsertItem(hListBreakdown, &lvItem);
        
        wstring mbStr = FormatMemoryMB(item.bytes) + L" MB";
        ListView_SetItemText(hListBreakdown, index, 1, const_cast<LPWSTR>(mbStr.c_str()));
        
        wstringstream ss;
        ss << fixed << setprecision(3) << item.percent << L"%";
        wstring pctStr = ss.str();
        ListView_SetItemText(hListBreakdown, index, 2, const_cast<LPWSTR>(pctStr.c_str()));
        
        index++;
    }
}

void UpdateAllData(HWND hwnd) {
    vector<ProcessInfo> processes = GetAllProcesses();
    MemoryStats stats = GetMemoryStats(processes);
    
    int currentTab = TabCtrl_GetCurSel(hTabControl);
    
    if (currentTab == 0) {
        UpdateOverviewTab(hwnd, stats);
    } else if (currentTab == 1) {
        UpdateProcessListTab(processes);
    } else if (currentTab == 2) {
        UpdateBreakdownTab(stats);
    }
}

void CreateOverviewTab(HWND hwndParent) {
    hTab1 = CreateWindowExW(0, L"STATIC", L"",
        WS_CHILD | WS_VISIBLE,
        10, 50, WINDOW_WIDTH - 40, WINDOW_HEIGHT - 100,
        hwndParent, NULL, GetModuleHandle(NULL), NULL);
    
    hStaticOverview = CreateWindowExW(0, L"EDIT", L"Loading...",
        WS_CHILD | WS_VISIBLE | WS_VSCROLL | ES_MULTILINE | ES_READONLY,
        10, 10, WINDOW_WIDTH - 60, WINDOW_HEIGHT - 200,
        hTab1, NULL, GetModuleHandle(NULL), NULL);
    
    HFONT hFont = CreateFontW(16, 0, 0, 0, FW_NORMAL, FALSE, FALSE, FALSE,
        DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS,
        CLEARTYPE_QUALITY, FIXED_PITCH | FF_MODERN, L"Consolas");
    SendMessage(hStaticOverview, WM_SETFONT, (WPARAM)hFont, TRUE);
    
    hProgressBar = CreateWindowExW(0, PROGRESS_CLASSW, NULL,
        WS_CHILD | WS_VISIBLE | PBS_SMOOTH,
        10, WINDOW_HEIGHT - 170, WINDOW_WIDTH - 60, 30,
        hTab1, NULL, GetModuleHandle(NULL), NULL);
    
    SendMessage(hProgressBar, PBM_SETRANGE, 0, MAKELPARAM(0, 100));
}

void CreateProcessListTab(HWND hwndParent) {
    hTab2 = CreateWindowExW(0, L"STATIC", L"",
        WS_CHILD,
        10, 50, WINDOW_WIDTH - 40, WINDOW_HEIGHT - 100,
        hwndParent, NULL, GetModuleHandle(NULL), NULL);
    
    hListProcesses = CreateWindowExW(0, WC_LISTVIEWW, L"",
        WS_CHILD | WS_VISIBLE | LVS_REPORT | LVS_SINGLESEL | WS_BORDER,
        10, 10, WINDOW_WIDTH - 60, WINDOW_HEIGHT - 200,
        hTab2, (HMENU)2001, GetModuleHandle(NULL), NULL);
    
    ListView_SetExtendedListViewStyle(hListProcesses, LVS_EX_FULLROWSELECT | LVS_EX_GRIDLINES);
    
    LVCOLUMNW col = {0};
    col.mask = LVCF_TEXT | LVCF_WIDTH;
    
    col.pszText = (LPWSTR)L"Process Name";
    col.cx = 280;
    ListView_InsertColumn(hListProcesses, 0, &col);
    
    col.pszText = (LPWSTR)L"PID";
    col.cx = 80;
    ListView_InsertColumn(hListProcesses, 1, &col);
    
    col.pszText = (LPWSTR)L"Private MB";
    col.cx = 110;
    ListView_InsertColumn(hListProcesses, 2, &col);
    
    col.pszText = (LPWSTR)L"Working Set MB";
    col.cx = 130;
    ListView_InsertColumn(hListProcesses, 3, &col);
    
    col.pszText = (LPWSTR)L"Status";
    col.cx = 180;
    ListView_InsertColumn(hListProcesses, 4, &col);
    
    col.pszText = (LPWSTR)L"Action";
    col.cx = 100;
    ListView_InsertColumn(hListProcesses, 5, &col);
    
    // Add RAM Optimizer button at bottom - positioned correctly
    int btnX = 10;
    int btnY = WINDOW_HEIGHT - 170;
    g_ramOptBtnPos.x = btnX;
    g_ramOptBtnPos.y = btnY;
    
    hButtonRamOptimizer = CreateWindowExW(0, L"BUTTON", L"⚡ RAM OPTIMIZER",
        WS_CHILD | WS_VISIBLE | BS_PUSHBUTTON,
        btnX, btnY, 300, 45,
        hTab2, (HMENU)1002, GetModuleHandle(NULL), NULL);
    
    HFONT hOptFont = CreateFontW(18, 0, 0, 0, FW_BOLD, FALSE, FALSE, FALSE,
        DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS,
        CLEARTYPE_QUALITY, DEFAULT_PITCH | FF_DONTCARE, L"Segoe UI");
    SendMessage(hButtonRamOptimizer, WM_SETFONT, (WPARAM)hOptFont, TRUE);
}

void CreateBreakdownTab(HWND hwndParent) {
    hTab3 = CreateWindowExW(0, L"STATIC", L"",
        WS_CHILD,
        10, 50, WINDOW_WIDTH - 40, WINDOW_HEIGHT - 100,
        hwndParent, NULL, GetModuleHandle(NULL), NULL);
    
    hListBreakdown = CreateWindowExW(0, WC_LISTVIEWW, L"",
        WS_CHILD | WS_VISIBLE | LVS_REPORT | LVS_SINGLESEL | WS_BORDER,
        10, 10, WINDOW_WIDTH - 60, WINDOW_HEIGHT - 200,
        hTab3, NULL, GetModuleHandle(NULL), NULL);
    
    ListView_SetExtendedListViewStyle(hListBreakdown, LVS_EX_FULLROWSELECT | LVS_EX_GRIDLINES);
    
    LVCOLUMNW col = {0};
    col.mask = LVCF_TEXT | LVCF_WIDTH;
    
    col.pszText = (LPWSTR)L"Memory Category";
    col.cx = 400;
    ListView_InsertColumn(hListBreakdown, 0, &col);
    
    col.pszText = (LPWSTR)L"Size (MB)";
    col.cx = 150;
    ListView_InsertColumn(hListBreakdown, 1, &col);
    
    col.pszText = (LPWSTR)L"Exact Percentage (%)";
    col.cx = 200;
    ListView_InsertColumn(hListBreakdown, 2, &col);
    
    // Add button to reduce standby memory
    hButtonReduceStandby = CreateWindowExW(0, L"BUTTON", L"🗑️ Clear Standby Memory Now",
        WS_CHILD | WS_VISIBLE | BS_PUSHBUTTON,
        (WINDOW_WIDTH - 400) / 2, WINDOW_HEIGHT - 170, 400, 50,
        hTab3, (HMENU)1001, GetModuleHandle(NULL), NULL);
    
    HFONT hBtnFont = CreateFontW(18, 0, 0, 0, FW_BOLD, FALSE, FALSE, FALSE,
        DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS,
        CLEARTYPE_QUALITY, DEFAULT_PITCH | FF_DONTCARE, L"Segoe UI");
    SendMessage(hButtonReduceStandby, WM_SETFONT, (WPARAM)hBtnFont, TRUE);
}

LRESULT CALLBACK WindowProc(HWND hwnd, UINT uMsg, WPARAM wParam, LPARAM lParam) {
    switch (uMsg) {
        case WM_CREATE: {
            InitCommonControls();
            
            hTabControl = CreateWindowExW(0, WC_TABCONTROLW, L"",
                WS_CHILD | WS_VISIBLE | TCS_TABS,
                10, 10, WINDOW_WIDTH - 30, WINDOW_HEIGHT - 60,
                hwnd, NULL, GetModuleHandle(NULL), NULL);
            
            TCITEMW tie = {0};
            tie.mask = TCIF_TEXT;
            
            tie.pszText = (LPWSTR)L"  Overview  ";
            TabCtrl_InsertItem(hTabControl, 0, &tie);
            
            tie.pszText = (LPWSTR)L"  Processes  ";
            TabCtrl_InsertItem(hTabControl, 1, &tie);
            
            tie.pszText = (LPWSTR)L"  Standby & Memory  ";
            TabCtrl_InsertItem(hTabControl, 2, &tie);
            
            CreateOverviewTab(hwnd);
            CreateProcessListTab(hwnd);
            CreateBreakdownTab(hwnd);
            
            ShowWindow(hTab1, SW_SHOW);
            ShowWindow(hTab2, SW_HIDE);
            ShowWindow(hTab3, SW_HIDE);
            
            SetTimer(hwnd, TIMER_ID, TIMER_INTERVAL, NULL);
            UpdateAllData(hwnd);
            
            break;
        }
        
        case WM_TIMER: {
            if (wParam == TIMER_ID) {
                UpdateAllData(hwnd);
            }
            break;
        }
        
        case WM_COMMAND: {
            int wmId = LOWORD(wParam);
            
            if (wmId == 1001) { // Reduce Standby button
                HINSTANCE result = ShellExecuteW(hwnd, L"open", 
                    L"F:\\study\\shells\\powershell\\scripts\\CheckMemoryRamUsage\\guiapp\\standby.exe",
                    NULL, NULL, SW_SHOW);
                
                if ((INT_PTR)result <= 32) {
                    MessageBoxW(hwnd, L"Failed to launch standby.exe\nMake sure the file exists at:\nF:\\study\\shells\\powershell\\scripts\\CheckMemoryRamUsage\\guiapp\\standby.exe", 
                               L"Error", MB_OK | MB_ICONERROR);
                }
            }
            else if (wmId == 1002) { // RAM Optimizer button
                HINSTANCE result = ShellExecuteW(hwnd, L"open", 
                    L"F:\\study\\shells\\powershell\\scripts\\CheckMemoryRamUsage\\guiapp\\ram_optimizer.exe",
                    NULL, NULL, SW_SHOW);
                
                if ((INT_PTR)result <= 32) {
                    MessageBoxW(hwnd, L"Failed to launch ram_optimizer.exe\nMake sure the file exists at:\nF:\\study\\shells\\powershell\\scripts\\CheckMemoryRamUsage\\guiapp\\ram_optimizer.exe", 
                               L"Error", MB_OK | MB_ICONERROR);
                }
            }
            else if (wmId >= 3000 && wmId < 3000 + (int)g_currentGroups.size()) { // Kill button clicked
                int index = wmId - 3000;
                if (index >= 0 && index < (int)g_currentGroups.size()) {
                    ProcessGroup& group = g_currentGroups[index];
                    if (group.canClose) {
                        wstring msg = L"Kill all " + to_wstring(group.instanceCount) + 
                                     L" instance(s) of " + group.name + L"?\n\nThis will free up approximately " +
                                     FormatMemoryMB(group.totalPrivateBytes) + L" MB of RAM.";
                        
                        int result = MessageBoxW(hwnd, msg.c_str(), L"Confirm Kill Process", 
                                                MB_YESNO | MB_ICONWARNING | MB_DEFBUTTON2);
                        
                        if (result == IDYES) {
                            int killed = 0;
                            for (DWORD pid : group.pids) {
                                HANDLE hProc = OpenProcess(PROCESS_TERMINATE, FALSE, pid);
                                if (hProc) {
                                    if (TerminateProcess(hProc, 0)) {
                                        killed++;
                                    }
                                    CloseHandle(hProc);
                                }
                            }
                            
                            wstring resultMsg = L"Successfully killed " + to_wstring(killed) + L" of " + 
                                               to_wstring(group.pids.size()) + L" instances.\n\n" +
                                               L"Freed approximately " + FormatMemoryMB(group.totalPrivateBytes) + L" MB of RAM!";
                            MessageBoxW(hwnd, resultMsg.c_str(), L"Process Terminated", MB_OK | MB_ICONINFORMATION);
                            
                            // Refresh list after 1 second
                            Sleep(1000);
                            UpdateAllData(hwnd);
                        }
                    }
                }
            }
            break;
        }
        
        case WM_NOTIFY: {
            LPNMHDR pnmh = (LPNMHDR)lParam;
            if (pnmh->hwndFrom == hTabControl && pnmh->code == TCN_SELCHANGE) {
                int sel = TabCtrl_GetCurSel(hTabControl);
                
                ShowWindow(hTab1, sel == 0 ? SW_SHOW : SW_HIDE);
                ShowWindow(hTab2, sel == 1 ? SW_SHOW : SW_HIDE);
                ShowWindow(hTab3, sel == 2 ? SW_SHOW : SW_HIDE);
                
                UpdateAllData(hwnd);
            }

            break;
        }
        
        case WM_CTLCOLORLISTBOX:
        case WM_DRAWITEM: {
            // Custom drawing for colored rows will be handled by owner draw if needed
            break;
        }
        
        case WM_SIZE: {
            // Handle window resize
            RECT rect;
            GetClientRect(hwnd, &rect);
            WINDOW_WIDTH = rect.right;
            WINDOW_HEIGHT = rect.bottom;
            
            // Resize tab control
            if (hTabControl) {
                SetWindowPos(hTabControl, NULL, 10, 10, WINDOW_WIDTH - 30, WINDOW_HEIGHT - 60, 
                            SWP_NOZORDER);
            }
            
            // Resize list views and buttons based on new size
            if (hListProcesses) {
                SetWindowPos(hListProcesses, NULL, 10, 10, WINDOW_WIDTH - 60, WINDOW_HEIGHT - 200, 
                            SWP_NOZORDER);
            }
            if (hListBreakdown) {
                SetWindowPos(hListBreakdown, NULL, 10, 10, WINDOW_WIDTH - 60, WINDOW_HEIGHT - 200, 
                            SWP_NOZORDER);
            }
            if (hStaticOverview) {
                SetWindowPos(hStaticOverview, NULL, 10, 10, WINDOW_WIDTH - 60, WINDOW_HEIGHT - 200, 
                            SWP_NOZORDER);
            }
            if (hProgressBar) {
                SetWindowPos(hProgressBar, NULL, 10, WINDOW_HEIGHT - 170, WINDOW_WIDTH - 60, 30, 
                            SWP_NOZORDER);
            }
            if (hButtonReduceStandby) {
                SetWindowPos(hButtonReduceStandby, NULL, (WINDOW_WIDTH - 400) / 2, WINDOW_HEIGHT - 170, 
                            400, 50, SWP_NOZORDER);
            }
            if (hButtonRamOptimizer) {
                int btnX = 10;
                int btnY = WINDOW_HEIGHT - 170;
                SetWindowPos(hButtonRamOptimizer, NULL, btnX, btnY, 300, 45, SWP_NOZORDER);
                g_ramOptBtnPos.x = btnX;
                g_ramOptBtnPos.y = btnY;
                
                // Ensure button is visible
                ShowWindow(hButtonRamOptimizer, SW_SHOW);
                BringWindowToTop(hButtonRamOptimizer);
            }
            
            break;
        }
        
        case WM_DESTROY:
            KillTimer(hwnd, TIMER_ID);
            PostQuitMessage(0);
            return 0;
    }
    
    return DefWindowProc(hwnd, uMsg, wParam, lParam);
}

int WINAPI WinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, LPSTR lpCmdLine, int nCmdShow) {
    const wchar_t CLASS_NAME[] = L"RAMAnalyzerGUI";
    
    WNDCLASSW wc = {0};
    wc.lpfnWndProc = WindowProc;
    wc.hInstance = hInstance;
    wc.lpszClassName = CLASS_NAME;
    wc.hbrBackground = CreateSolidBrush(RGB(240, 240, 245)); // Light beautiful background
    wc.hCursor = LoadCursor(NULL, IDC_ARROW);
    
    // Try to load custom icon, fallback to default
    HICON hIcon = (HICON)LoadImageW(hInstance, L"APP_ICON", IMAGE_ICON, 0, 0, LR_DEFAULTSIZE);
    if (!hIcon) {
        hIcon = LoadIcon(NULL, IDI_APPLICATION);
    }
    wc.hIcon = hIcon;
    
    RegisterClassW(&wc);
    
    // Get screen dimensions for better initial placement
    int screenWidth = GetSystemMetrics(SM_CXSCREEN);
    int screenHeight = GetSystemMetrics(SM_CYSCREEN);
    
    // Adjust window size based on screen resolution
    if (screenWidth < 1400) WINDOW_WIDTH = screenWidth - 100;
    if (screenHeight < 900) WINDOW_HEIGHT = screenHeight - 100;
    
    int posX = (screenWidth - WINDOW_WIDTH) / 2;
    int posY = (screenHeight - WINDOW_HEIGHT) / 2;
    
    HWND hwnd = CreateWindowExW(
        0,
        CLASS_NAME,
        L"⚡ Ultimate RAM Analyzer - Professional Edition",
        WS_OVERLAPPEDWINDOW,
        posX, posY, WINDOW_WIDTH, WINDOW_HEIGHT,
        NULL, NULL, hInstance, NULL
    );
    
    if (hwnd == NULL) return 0;
    
    ShowWindow(hwnd, nCmdShow);
    UpdateWindow(hwnd);
    
    MSG msg = {0};
    while (GetMessage(&msg, NULL, 0, 0)) {
        TranslateMessage(&msg);
        DispatchMessage(&msg);
    }
    
    return 0;
}

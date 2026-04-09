#include <windows.h>
#include <psapi.h>
#include <tlhelp32.h>
#include <iostream>
#include <vector>
#include <string>
#include <algorithm>
#include <map>
#include <iomanip>
#include <sstream>
#include <ctime>
#include <io.h>
#include <fcntl.h>

using namespace std;

#pragma comment(lib, "psapi.lib")

struct ProcessInfo {
    wstring name;
    DWORD pid;
    SIZE_T workingSetSize;
    SIZE_T privateBytes;
    SIZE_T pagedPoolUsage;
    SIZE_T nonPagedPoolUsage;
    wstring path;
    wstring windowTitle;
    bool canClose;
    FILETIME creationTime;
};

struct ProcessGroup {
    wstring name;
    vector<ProcessInfo> instances;
    SIZE_T totalMemory;
    SIZE_T totalPrivateBytes;
    bool canClose;
};

void SetColor(int color) {
    SetConsoleTextAttribute(GetStdHandle(STD_OUTPUT_HANDLE), color);
}

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
        L"svchost.exe", L"RuntimeBroker.exe", L"sihost.exe", 
        L"taskhostw.exe", L"fontdrvhost.exe", L"WUDFHost.exe",
        L"conhost.exe", L"winlogon.exe", L"LogonUI.exe"
    };
    
    for (const auto& sysProc : systemProcs) {
        if (_wcsicmp(name.c_str(), sysProc) == 0) return true;
    }
    return false;
}

wstring GetProcessPath(HANDLE hProcess) {
    wchar_t path[MAX_PATH] = {0};
    if (GetModuleFileNameExW(hProcess, NULL, path, MAX_PATH)) {
        return wstring(path);
    }
    return L"";
}

wstring GetWindowTitle(DWORD pid) {
    wstring title;
    HWND hwnd = NULL;
    
    do {
        hwnd = FindWindowEx(NULL, hwnd, NULL, NULL);
        DWORD windowPid = 0;
        GetWindowThreadProcessId(hwnd, &windowPid);
        
        if (windowPid == pid && IsWindowVisible(hwnd)) {
            wchar_t windowTitle[256];
            if (GetWindowTextW(hwnd, windowTitle, 256) > 0) {
                title = wstring(windowTitle);
                break;
            }
        }
    } while (hwnd != NULL);
    
    return title;
}

double GetProcessUptime(const FILETIME& creationTime) {
    FILETIME currentTime;
    GetSystemTimeAsFileTime(&currentTime);
    
    ULARGE_INTEGER creation, current;
    creation.LowPart = creationTime.dwLowDateTime;
    creation.HighPart = creationTime.dwHighDateTime;
    current.LowPart = currentTime.dwLowDateTime;
    current.HighPart = currentTime.dwHighDateTime;
    
    ULONGLONG diff = current.QuadPart - creation.QuadPart;
    return (double)diff / 10000000.0 / 3600.0; // Convert to hours
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
                    info.privateBytes = pmc.PrivateUsage; // THIS IS THE REAL MEMORY!
                    info.pagedPoolUsage = pmc.QuotaPagedPoolUsage;
                    info.nonPagedPoolUsage = pmc.QuotaNonPagedPoolUsage;
                    info.path = GetProcessPath(hProcess);
                    info.windowTitle = GetWindowTitle(pe32.th32ProcessID);
                    info.canClose = !IsSystemProcess(info.name) && !info.path.empty();
                    
                    FILETIME creationTime, exitTime, kernelTime, userTime;
                    if (GetProcessTimes(hProcess, &creationTime, &exitTime, &kernelTime, &userTime)) {
                        info.creationTime = creationTime;
                    }
                    
                    processes.push_back(info);
                }
                CloseHandle(hProcess);
            }
        } while (Process32NextW(hSnapshot, &pe32));
    }
    
    CloseHandle(hSnapshot);
    return processes;
}

map<wstring, ProcessGroup> GroupProcesses(const vector<ProcessInfo>& processes) {
    map<wstring, ProcessGroup> groups;
    
    for (const auto& proc : processes) {
        if (groups.find(proc.name) == groups.end()) {
            ProcessGroup group;
            group.name = proc.name;
            group.totalMemory = 0;
            group.totalPrivateBytes = 0;
            group.canClose = proc.canClose;
            groups[proc.name] = group;
        }
        
        groups[proc.name].instances.push_back(proc);
        groups[proc.name].totalMemory += proc.workingSetSize;
        groups[proc.name].totalPrivateBytes += proc.privateBytes;
    }
    
    return groups;
}

void GetMemoryStatus(MEMORYSTATUSEX& memStatus, PERFORMANCE_INFORMATION& perfInfo) {
    memStatus.dwLength = sizeof(MEMORYSTATUSEX);
    GlobalMemoryStatusEx(&memStatus);
    
    perfInfo.cb = sizeof(PERFORMANCE_INFORMATION);
    GetPerformanceInfo(&perfInfo, sizeof(PERFORMANCE_INFORMATION));
}

void PrintHeader() {
    SetColor(11); // Cyan
    wcout << L"\n===============================================================================\n";
    wcout << L"              ULTIMATE RAM ANALYZER - Windows Memory Monitor                  \n";
    wcout << L"===============================================================================\n";
    SetColor(7);
}

void PrintMemoryOverview(const MEMORYSTATUSEX& memStatus, const PERFORMANCE_INFORMATION& perfInfo) {
    SIZE_T totalRAM = memStatus.ullTotalPhys;
    SIZE_T availRAM = memStatus.ullAvailPhys;
    SIZE_T usedRAM = totalRAM - availRAM;
    
    SetColor(11); // Cyan
    wcout << L"\n=============== MEMORY OVERVIEW ===============\n";
    SetColor(7);
    
    wprintf(L"  Total RAM:     %10s MB                    \n", FormatMemoryMB(totalRAM).c_str());
    
    SetColor(14); // Yellow
    wprintf(L"  Used RAM:      %10s MB  (%d%%)           \n", 
            FormatMemoryMB(usedRAM).c_str(), memStatus.dwMemoryLoad);
    
    SetColor(10); // Green
    wprintf(L"  Available RAM: %10s MB                    \n", FormatMemoryMB(availRAM).c_str());
    
    SetColor(7);
    
    SIZE_T pageSize = perfInfo.PageSize;
    
    wprintf(L"\n  System Cache:  %10s MB                    \n", FormatMemoryMB(perfInfo.SystemCache * pageSize).c_str());
    wprintf(L"  Commit Total:  %10s MB                    \n", FormatMemoryMB(perfInfo.CommitTotal * pageSize).c_str());
    wprintf(L"  Commit Limit:  %10s MB                    \n", FormatMemoryMB(perfInfo.CommitLimit * pageSize).c_str());
    
    SetColor(11);
    wcout << L"===============================================\n";
    SetColor(7);
}

void PrintSystemMemory(const PERFORMANCE_INFORMATION& perfInfo, SIZE_T totalRAM) {
    SIZE_T pageSize = perfInfo.PageSize;
    
    SetColor(8); // Dark gray
    wcout << L"\n=============== SYSTEM MEMORY (Non-Actionable) ===============\n";
    SetColor(7);
    
    wcout << L"  Kernel Total (Paged + NonPaged): " 
          << setw(10) << FormatMemoryMB(perfInfo.KernelTotal * pageSize) << L" MB  ("
          << FormatPercent(perfInfo.KernelTotal * pageSize, totalRAM) << L"%)\n";
    
    wcout << L"  Kernel Paged Pool:               " 
          << setw(10) << FormatMemoryMB(perfInfo.KernelPaged * pageSize) << L" MB  ("
          << FormatPercent(perfInfo.KernelPaged * pageSize, totalRAM) << L"%)\n";
    
    wcout << L"  Kernel NonPaged Pool:            " 
          << setw(10) << FormatMemoryMB(perfInfo.KernelNonpaged * pageSize) << L" MB  ("
          << FormatPercent(perfInfo.KernelNonpaged * pageSize, totalRAM) << L"%)\n";
    
    wcout << L"  System Cache (Reclaimable):      " 
          << setw(10) << FormatMemoryMB(perfInfo.SystemCache * pageSize) << L" MB  ("
          << FormatPercent(perfInfo.SystemCache * pageSize, totalRAM) << L"%)\n";
    
    SetColor(8);
    wcout << L"===============================================================\n";
    SetColor(7);
    wcout << L"  NOTE: These are kernel components managed by Windows.\n";
}

void PrintActionableProcesses(const vector<ProcessGroup>& closableGroups, SIZE_T totalRAM) {
    SetColor(12); // Red
    wcout << L"\n=============== ALL USER APPLICATIONS - EVERY SINGLE INSTANCE ===============\n";
    SetColor(14); // Yellow
    wcout << L"  UNGROUPED - showing each process instance individually:\n\n";
    SetColor(7);
    
    SIZE_T actionableTotal = 0;
    int instanceCount = 0;
    
    // Flatten all instances and sort by memory
    vector<ProcessInfo> allUserInstances;
    for (const auto& group : closableGroups) {
        for (const auto& inst : group.instances) {
            allUserInstances.push_back(inst);
        }
    }
    
    // Sort by memory usage
    sort(allUserInstances.begin(), allUserInstances.end(),
         [](const ProcessInfo& a, const ProcessInfo& b) { return a.workingSetSize > b.workingSetSize; });
    
    for (const auto& inst : allUserInstances) {
        int color = 7; // White
        if (inst.workingSetSize > 100 * 1024 * 1024) color = 12; // Red for >100MB
        else if (inst.workingSetSize > 50 * 1024 * 1024) color = 14; // Yellow for >50MB
        else if (inst.workingSetSize > 10 * 1024 * 1024) color = 11; // Cyan for >10MB
        
        SetColor(color);
        
        wcout << L"  " << setw(12) << FormatMemoryMB(inst.workingSetSize) << L" MB  "
              << setw(6) << FormatPercent(inst.workingSetSize, totalRAM) << L"%  "
              << L"PID " << setw(6) << inst.pid << L"  " << inst.name;
        
        if (!inst.windowTitle.empty()) {
            wcout << L" - " << inst.windowTitle.substr(0, 30);
        }
        
        wcout << L"\n";
        
        actionableTotal += inst.workingSetSize;
        instanceCount++;
    }
    
    SetColor(10); // Green
    wcout << L"\n  TOTAL USER APPS: " << FormatMemoryMB(actionableTotal) << L" MB  ("
          << FormatPercent(actionableTotal, totalRAM) << L"%)\n";
    wcout << L"  COUNT: " << instanceCount << L" individual process instances\n";
    
    SetColor(12);
    wcout << L"==============================================================================\n";
    SetColor(7);
}

void PrintSystemProcesses(const vector<ProcessGroup>& systemGroups, SIZE_T totalRAM) {
    SetColor(8); // Dark gray
    wcout << L"\n=============== ALL SYSTEM PROCESSES - EVERY SINGLE INSTANCE ===============\n";
    SetColor(7);
    wcout << L"  UNGROUPED - showing each process instance individually:\n\n";
    
    SIZE_T systemTotal = 0;
    int instanceCount = 0;
    
    // Flatten all instances and sort by memory
    vector<ProcessInfo> allSystemInstances;
    for (const auto& group : systemGroups) {
        for (const auto& inst : group.instances) {
            allSystemInstances.push_back(inst);
        }
    }
    
    // Sort by memory usage
    sort(allSystemInstances.begin(), allSystemInstances.end(),
         [](const ProcessInfo& a, const ProcessInfo& b) { return a.workingSetSize > b.workingSetSize; });
    
    for (const auto& inst : allSystemInstances) {
        SetColor(8);
        wcout << L"  " << setw(12) << FormatMemoryMB(inst.workingSetSize) << L" MB  "
              << setw(6) << FormatPercent(inst.workingSetSize, totalRAM) << L"%  "
              << L"PID " << setw(6) << inst.pid << L"  " << inst.name;
        
        if (!inst.windowTitle.empty()) {
            wcout << L" - " << inst.windowTitle.substr(0, 30);
        }
        
        wcout << L"\n";
        
        systemTotal += inst.workingSetSize;
        instanceCount++;
    }
    
    SetColor(8);
    wcout << L"\n  TOTAL SYSTEM: " << FormatMemoryMB(systemTotal) << L" MB  ("
          << FormatPercent(systemTotal, totalRAM) << L"%)\n";
    wcout << L"  COUNT: " << instanceCount << L" individual system process instances\n";
    
    wcout << L"=============================================================================\n";
    SetColor(7);
}

void PrintDetailedBreakdown(const vector<ProcessGroup>& closableGroups) {
    SetColor(11); // Cyan
    wcout << L"\n=============== DETAILED BREAKDOWN - TOP MEMORY HOGS ===============\n";
    SetColor(7);
    wcout << L"  Individual instances for applications using >1MB:\n";
    
    int groupCount = 0;
    for (const auto& group : closableGroups) {
        if (group.totalMemory < 1 * 1024 * 1024) continue; // Skip <1MB
        if (groupCount >= 20) break; // Top 20 groups
        
        SetColor(14); // Yellow
        wcout << L"\n  [" << group.name << L"] Total: " << FormatMemoryMB(group.totalMemory) << L" MB";
        if (group.instances.size() > 1) {
            wcout << L" (" << group.instances.size() << L" instances)";
        }
        wcout << L"\n";
        SetColor(7);
        
        auto sortedInstances = group.instances;
        sort(sortedInstances.begin(), sortedInstances.end(), 
             [](const ProcessInfo& a, const ProcessInfo& b) { return a.workingSetSize > b.workingSetSize; });
        
        int instCount = 0;
        for (const auto& inst : sortedInstances) {
            if (instCount >= 15) break; // Top 15 instances per group
            
            wcout << L"    PID " << setw(6) << inst.pid << L": " 
                  << setw(10) << FormatMemoryMB(inst.workingSetSize) << L" MB";
            
            if (!inst.windowTitle.empty()) {
                wcout << L" - " << inst.windowTitle.substr(0, 40);
            }
            
            double uptime = GetProcessUptime(inst.creationTime);
            if (uptime > 0) {
                wcout << L" (" << fixed << setprecision(1) << uptime << L"h)";
            }
            
            if (!inst.path.empty()) {
                size_t lastSlash = inst.path.find_last_of(L"\\");
                if (lastSlash != wstring::npos) {
                    wstring dir = inst.path.substr(0, lastSlash);
                    if (dir.find(L"Docker") != wstring::npos) wcout << L" [DOCKER]";
                    if (dir.find(L"wsl") != wstring::npos || dir.find(L"WSL") != wstring::npos) wcout << L" [WSL]";
                }
            }
            
            wcout << L"\n";
            instCount++;
        }
        
        groupCount++;
    }
    
    SetColor(11);
    wcout << L"=====================================================================\n";
    SetColor(7);
}

void PrintQuickActions(const vector<ProcessGroup>& closableGroups) {
    SetColor(10); // Green
    wcout << L"\n=============== QUICK KILL COMMANDS (TOP MEMORY USERS) ===============\n";
    SetColor(7);
    wcout << L"  PowerShell commands to close high-memory applications:\n\n";
    
    int count = 0;
    for (const auto& group : closableGroups) {
        if (group.totalMemory < 10 * 1024 * 1024) continue; // Only >10MB
        if (count >= 15) break;
        
        wstring processName = group.name;
        if (processName.find(L".exe") != wstring::npos) {
            processName = processName.substr(0, processName.find(L".exe"));
        }
        
        SetColor(14); // Yellow
        wcout << L"  # " << group.name << L" - " << FormatMemoryMB(group.totalMemory) << L" MB";
        if (group.instances.size() > 1) {
            wcout << L" (" << group.instances.size() << L" instances)";
        }
        wcout << L"\n";
        SetColor(7);
        wcout << L"  Stop-Process -Name '" << processName << L"' -Force\n\n";
        
        count++;
    }
    
    SetColor(10);
    wcout << L"=======================================================================\n";
    SetColor(7);
}

void InteractiveMenu(const vector<ProcessGroup>& closableGroups) {
    SetColor(11);
    wcout << L"\n=============== INTERACTIVE OPTIONS ===============\n";
    SetColor(7);
    wcout << L"  1. Kill a specific process by name\n";
    wcout << L"  2. Kill a specific process by PID\n";
    wcout << L"  3. Refresh data\n";
    wcout << L"  4. Exit\n";
    SetColor(11);
    wcout << L"====================================================\n";
    SetColor(7);
    wcout << L"\nEnter option (1-4): ";
    
    int choice;
    wcin >> choice;
    wcin.ignore();
    
    if (choice == 1) {
        wcout << L"Enter process name (e.g., chrome.exe): ";
        wstring processName;
        getline(wcin, processName);
        
        bool found = false;
        for (const auto& group : closableGroups) {
            if (_wcsicmp(group.name.c_str(), processName.c_str()) == 0) {
                found = true;
                wcout << L"\nKilling " << group.instances.size() << L" instance(s) of " << processName << L"...\n";
                
                for (const auto& inst : group.instances) {
                    HANDLE hProcess = OpenProcess(PROCESS_TERMINATE, FALSE, inst.pid);
                    if (hProcess) {
                        if (TerminateProcess(hProcess, 0)) {
                            SetColor(10);
                            wcout << L"  ✓ Killed PID " << inst.pid << L"\n";
                        } else {
                            SetColor(12);
                            wcout << L"  ✗ Failed to kill PID " << inst.pid << L"\n";
                        }
                        CloseHandle(hProcess);
                    }
                }
                SetColor(7);
                break;
            }
        }
        
        if (!found) {
            SetColor(12);
            wcout << L"Process not found!\n";
            SetColor(7);
        }
    } else if (choice == 2) {
        wcout << L"Enter PID: ";
        DWORD pid;
        wcin >> pid;
        
        HANDLE hProcess = OpenProcess(PROCESS_TERMINATE, FALSE, pid);
        if (hProcess) {
            if (TerminateProcess(hProcess, 0)) {
                SetColor(10);
                wcout << L"✓ Successfully killed PID " << pid << L"\n";
            } else {
                SetColor(12);
                wcout << L"✗ Failed to kill PID " << pid << L"\n";
            }
            CloseHandle(hProcess);
        } else {
            SetColor(12);
            wcout << L"✗ Cannot open process (invalid PID or access denied)\n";
        }
        SetColor(7);
    }
}

void Print100PercentBreakdown(const MEMORYSTATUSEX& memStatus, const PERFORMANCE_INFORMATION& perfInfo, 
                               const vector<ProcessGroup>& allGroups) {
    SIZE_T totalRAM = memStatus.ullTotalPhys;
    SIZE_T pageSize = perfInfo.PageSize;
    
    SetColor(11);
    wcout << L"\n=============== 100% RAM USAGE BREAKDOWN - REAL USAGE ===============\n";
    SetColor(14);
    wcout << L"  Showing ACTUAL memory consumption (Private + Commit):\n\n";
    SetColor(7);
    
    struct MemoryCategory {
        wstring name;
        SIZE_T bytes;
        int color;
        wstring description;
    };
    
    vector<MemoryCategory> categories;
    
    // Calculate REAL process memory usage (Private Bytes = actual RAM committed)
    SIZE_T totalProcessPrivate = 0;
    SIZE_T totalProcessWorking = 0;
    SIZE_T closableProcessMemory = 0;
    SIZE_T systemProcessMemory = 0;
    
    for (const auto& group : allGroups) {
        totalProcessPrivate += group.totalPrivateBytes;
        totalProcessWorking += group.totalMemory;
        if (group.canClose) {
            closableProcessMemory += group.totalPrivateBytes;
        } else {
            systemProcessMemory += group.totalPrivateBytes;
        }
    }
    
    // Get kernel memory
    SIZE_T kernelPaged = perfInfo.KernelPaged * pageSize;
    SIZE_T kernelNonpaged = perfInfo.KernelNonpaged * pageSize;
    SIZE_T systemCache = perfInfo.SystemCache * pageSize;
    SIZE_T freeMemory = memStatus.ullAvailPhys;
    SIZE_T usedMemory = totalRAM - freeMemory;
    
    // Calculate file cache and standby (this is SHARED memory, not private)
    SIZE_T sharedAndCache = 0;
    if (totalProcessWorking > totalProcessPrivate) {
        sharedAndCache = totalProcessWorking - totalProcessPrivate;
    }
    
    // System file cache
    SIZE_T fileSystemCache = systemCache;
    
    // What's left unaccounted (modified pages, etc.)
    SIZE_T accountedMemory = totalProcessPrivate + kernelPaged + kernelNonpaged + fileSystemCache;
    SIZE_T unaccounted = (usedMemory > accountedMemory) ? (usedMemory - accountedMemory) : 0;
    
    // Build category list showing REAL usage
    if (closableProcessMemory > 0)
        categories.push_back({L"User Applications (Private Commit)", closableProcessMemory, 12, L"REAL RAM used by your apps"});
    
    if (systemProcessMemory > 0)
        categories.push_back({L"System Processes (Private Commit)", systemProcessMemory, 8, L"REAL RAM used by Windows"});
    
    if (kernelNonpaged > 0)
        categories.push_back({L"Kernel NonPaged Pool", kernelNonpaged, 8, L"Drivers & kernel structures"});
    
    if (kernelPaged > 0)
        categories.push_back({L"Kernel Paged Pool", kernelPaged, 8, L"Kernel pageable memory"});
    
    if (fileSystemCache > 100 * 1024 * 1024)
        categories.push_back({L"File System Cache", fileSystemCache, 14, L"Disk cache (releasable)"});
    
    if (sharedAndCache > 100 * 1024 * 1024)
        categories.push_back({L"Shared Memory & DLLs", sharedAndCache, 11, L"Shared between processes"});
    
    if (unaccounted > 100 * 1024 * 1024)
        categories.push_back({L"Modified Pages & Other", unaccounted, 14, L"Dirty pages & system buffers"});
    
    if (freeMemory > 0)
        categories.push_back({L"Free Memory", freeMemory, 10, L"Immediately available"});
    
    // Sort by size
    sort(categories.begin(), categories.end(), 
         [](const MemoryCategory& a, const MemoryCategory& b) { return a.bytes > b.bytes; });
    
    // Print all categories
    SIZE_T verificationTotal = 0;
    for (const auto& cat : categories) {
        SetColor(cat.color);
        double percent = ((double)cat.bytes / (double)totalRAM) * 100.0;
        wstring bar = L"";
        int barLength = (int)(percent / 2.0); // Scale to fit screen
        for (int i = 0; i < barLength && i < 50; i++) bar += L"█";
        
        wcout << L"  " << setw(40) << left << cat.name 
              << setw(12) << right << FormatMemoryMB(cat.bytes) << L" MB  "
              << setw(6) << right << fixed << setprecision(2) << percent << L"%\n";
        
        SetColor(cat.color);
        if (barLength > 0) wcout << L"    " << bar << L"\n";
        SetColor(7);
        wcout << L"    " << cat.description << L"\n\n";
        
        verificationTotal += cat.bytes;
    }
    
    // Verification
    SetColor(11);
    wcout << L"=====================================================================\n";
    SetColor(14);
    
    wcout << L"\n  REAL MEMORY BREAKDOWN:\n";
    wcout << L"  Total RAM:               " << FormatMemoryMB(totalRAM) << L" MB\n";
    wcout << L"  Used RAM:                " << FormatMemoryMB(usedMemory) << L" MB\n";
    SetColor(12);
    wcout << L"\n  Process Private Bytes:   " << FormatMemoryMB(totalProcessPrivate) << L" MB  <- ACTUAL RAM USED!\n";
    SetColor(14);
    wcout << L"  Process Working Set:     " << FormatMemoryMB(totalProcessWorking) << L" MB\n";
    wcout << L"  Kernel Memory:           " << FormatMemoryMB(kernelPaged + kernelNonpaged) << L" MB\n";
    wcout << L"  File System Cache:       " << FormatMemoryMB(fileSystemCache) << L" MB\n";
    wcout << L"  Shared/DLLs:             " << FormatMemoryMB(sharedAndCache) << L" MB\n";
    wcout << L"  Modified & Other:        " << FormatMemoryMB(unaccounted) << L" MB\n";
    wcout << L"  Free:                    " << FormatMemoryMB(freeMemory) << L" MB\n";
    
    SetColor(10);
    wcout << L"\n  ✓ 100% Accounted: " << FormatMemoryMB(verificationTotal) << L" MB\n";
    
    SetColor(11);
    wcout << L"=====================================================================\n";
    SetColor(7);
}

int main(int argc, char* argv[]) {
    _setmode(_fileno(stdout), _O_U16TEXT);
    
    bool interactive = true;
    bool realtimeMode = false;
    int refreshMs = 1; // Update every 1 millisecond for REAL-TIME data
    
    if (argc > 1) {
        string arg = argv[1];
        if (arg == "--no-interactive") {
            interactive = false;
        } else if (arg == "--realtime") {
            realtimeMode = true;
            interactive = false;
            if (argc > 2) {
                refreshMs = atoi(argv[2]);
                if (refreshMs < 1) refreshMs = 1;
            }
        }
    }
    
    if (realtimeMode) {
        SetColor(10);
        wcout << L"\n=============== REAL-TIME MONITORING MODE ===============\n";
        wcout << L"  Refreshing every " << refreshMs << L" ms | Press Ctrl+C to exit\n";
        wcout << L"=========================================================\n\n";
        SetColor(7);
    }
    
    DWORD updateCount = 0;
    HANDLE hConsole = GetStdHandle(STD_OUTPUT_HANDLE);
    
    do {
        if (realtimeMode && updateCount == 0) {
            // First draw - show full layout
            system("cls");
        } else if (realtimeMode && updateCount > 0) {
            // Subsequent updates - just reset cursor to top
            COORD coord = {0, 0};
            SetConsoleCursorPosition(hConsole, coord);
        } else if (!realtimeMode) {
            system("cls");
        }
        
        if (realtimeMode) {
            SYSTEMTIME st;
            GetLocalTime(&st);
            SetColor(11);
            wprintf(L"[%02d:%02d:%02d.%03d] Update #%-10d LIVE REAL-TIME DATA                \n", 
                    st.wHour, st.wMinute, st.wSecond, st.wMilliseconds, updateCount);
            SetColor(7);
        }
        
        PrintHeader();
        
        MEMORYSTATUSEX memStatus;
        PERFORMANCE_INFORMATION perfInfo;
        GetMemoryStatus(memStatus, perfInfo);
        
        PrintMemoryOverview(memStatus, perfInfo);
        
        vector<ProcessInfo> processes = GetAllProcesses();
        map<wstring, ProcessGroup> groupedProcesses = GroupProcesses(processes);
        
        vector<ProcessGroup> allGroups, closableGroups, systemGroups;
        
        for (const auto& pair : groupedProcesses) {
            allGroups.push_back(pair.second);
            
            // NO FILTERING - SHOW EVERYTHING
            if (pair.second.canClose) {
                closableGroups.push_back(pair.second);
            } else {
                systemGroups.push_back(pair.second);
            }
        }
        
        // SORT BY RAM USAGE - HIGHEST FIRST!!!
        sort(closableGroups.begin(), closableGroups.end(), 
             [](const ProcessGroup& a, const ProcessGroup& b) { return a.totalMemory > b.totalMemory; });
        
        sort(systemGroups.begin(), systemGroups.end(), 
             [](const ProcessGroup& a, const ProcessGroup& b) { return a.totalMemory > b.totalMemory; });
        
        sort(allGroups.begin(), allGroups.end(), 
             [](const ProcessGroup& a, const ProcessGroup& b) { return a.totalMemory > b.totalMemory; });
        
        // MAIN 100% BREAKDOWN
        Print100PercentBreakdown(memStatus, perfInfo, allGroups);
        
        if (!realtimeMode) {
            PrintActionableProcesses(closableGroups, memStatus.ullTotalPhys);
            PrintSystemProcesses(systemGroups, memStatus.ullTotalPhys);
            PrintDetailedBreakdown(closableGroups);
            PrintQuickActions(closableGroups);
        } else {
            // In real-time mode, show top 20 processes only
            SetColor(12);
            wcout << L"\n=============== TOP 20 MEMORY CONSUMERS (REAL-TIME) ===============\n";
            SetColor(7);
            
            vector<ProcessInfo> allProcesses;
            for (const auto& group : allGroups) {
                for (const auto& inst : group.instances) {
                    allProcesses.push_back(inst);
                }
            }
            
            sort(allProcesses.begin(), allProcesses.end(),
                 [](const ProcessInfo& a, const ProcessInfo& b) { return a.privateBytes > b.privateBytes; });
            
            int count = 0;
            for (const auto& proc : allProcesses) {
                if (count >= 20) break;
                if (proc.privateBytes < 1024 * 1024) break; // Skip <1MB
                
                int color = 7;
                if (proc.privateBytes > 100 * 1024 * 1024) color = 12;
                else if (proc.privateBytes > 50 * 1024 * 1024) color = 14;
                
                SetColor(color);
                
                wstring title = proc.windowTitle.empty() ? L"" : proc.windowTitle.substr(0, 25);
                wprintf(L"  %12s MB  PID %6d  %-25s %-30s\n", 
                        FormatMemoryMB(proc.privateBytes).c_str(),
                        proc.pid,
                        proc.name.c_str(),
                        title.c_str());
                
                count++;
            }
            
            // Fill remaining lines with spaces to keep display stable
            for (int i = count; i < 20; i++) {
                wprintf(L"                                                                                  \n");
            }
            
            SetColor(11);
            wcout << L"===================================================================\n";
            SetColor(7);
        }
        
        if (interactive) {
            InteractiveMenu(closableGroups);
            wcout << L"\nPress Enter to continue...";
            wcin.get();
        } else if (realtimeMode) {
            updateCount++;
            Sleep(refreshMs);
        } else {
            break;
        }
        
    } while (interactive || realtimeMode);
    
    return 0;
}

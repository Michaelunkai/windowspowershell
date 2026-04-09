#include <windows.h>
#include <psapi.h>
#include <tlhelp32.h>
#include <string>
#include <vector>

#pragma comment(lib, "psapi.lib")

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
    // This releases unused pages back to the system without terminating the process
    if (EmptyWorkingSet(hProcess)) {
        success = true;
    }
    
    // Method 2: Set minimum and maximum working set size
    // This encourages the system to trim the process's working set
    SIZE_T minWorkingSetSize = static_cast<SIZE_T>(-1);
    SIZE_T maxWorkingSetSize = static_cast<SIZE_T>(-1);
    
    if (SetProcessWorkingSetSize(hProcess, minWorkingSetSize, maxWorkingSetSize)) {
        success = true;
    }
    
    CloseHandle(hProcess);
    return success;
}

// Function to perform system-wide memory optimization
void OptimizeSystemMemory() {
    // Clear the system file cache
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
            // System cache information class = 21
            NtSetSystemInformation(21, &sci, sizeof(sci));
        }
    }
}

// Function to optimize all processes
SIZE_T OptimizeAllProcesses() {
    SIZE_T totalFreed = 0;
    std::vector<ProcessInfo> processes = GetRunningProcesses();
    
    for (const auto& process : processes) {
        // Skip critical system processes
        if (process.processID == 0 || process.processID == 4) {
            continue; // Skip System Idle Process and System Process
        }
        
        SIZE_T beforeSize = process.workingSetSize;
        
        if (OptimizeProcessMemory(process.processID)) {
            // Get the new working set size
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

// Main optimization routine
void PerformOptimization() {
    // Enable necessary privileges
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
    
    // Perform system-wide optimization
    OptimizeSystemMemory();
    
    // Optimize all processes
    SIZE_T totalFreed = OptimizeAllProcesses();
    
    // No GUI messages - silent operation
}

// Windows GUI entry point
int WINAPI WinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, LPSTR lpCmdLine, int nCmdShow) {
    // Check if running as administrator
    BOOL isAdmin = FALSE;
    PSID administratorsGroup = NULL;
    SID_IDENTIFIER_AUTHORITY NtAuthority = SECURITY_NT_AUTHORITY;
    
    if (AllocateAndInitializeSid(&NtAuthority, 2, SECURITY_BUILTIN_DOMAIN_RID,
                                  DOMAIN_ALIAS_RID_ADMINS, 0, 0, 0, 0, 0, 0, &administratorsGroup)) {
        CheckTokenMembership(NULL, administratorsGroup, &isAdmin);
        FreeSid(administratorsGroup);
    }
    
    if (!isAdmin) {
        // Get the current executable path
        wchar_t exePath[MAX_PATH];
        GetModuleFileNameW(NULL, exePath, MAX_PATH);
        
        // Restart with elevated privileges silently
        SHELLEXECUTEINFOW sei = {sizeof(sei)};
        sei.lpVerb = L"runas";
        sei.lpFile = exePath;
        sei.hwnd = NULL;
        sei.nShow = SW_HIDE;
        
        if (ShellExecuteExW(&sei)) {
            return 0;
        }
        return 0;
    }
    
    // Perform the optimization silently
    PerformOptimization();
    
    return 0;
}

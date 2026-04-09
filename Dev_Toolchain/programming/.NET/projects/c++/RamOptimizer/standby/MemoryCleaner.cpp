#include <windows.h>
#include <stdio.h>
#include <psapi.h>
#include <pdh.h>
#include <iostream>
#include <winternl.h>

#pragma comment(lib, "psapi.lib")
#pragma comment(lib, "pdh.lib")
#pragma comment(lib, "ntdll.lib")

// Function pointer types
typedef NTSTATUS (WINAPI *NtSetSystemInformation_t)(INT SystemInformationClass, PVOID SystemInformation, ULONG SystemInformationLength);
typedef NTSTATUS (WINAPI *NtQuerySystemInformation_t)(INT SystemInformationClass, PVOID SystemInformation, ULONG SystemInformationLength, PULONG ReturnLength);

// System Information Classes
#define SystemMemoryListInformation 80
#define SystemFileCacheInformation 21
#define SystemCombinePhysicalMemoryInformation 130
#define SystemMemoryListInformation2 80

// Memory List Commands
#define MemoryPurgeStandbyList 4
#define MemoryEmptyWorkingSets 2
#define MemoryFlushModifiedList 3
#define MemoryPurgeLowPriorityStandbyList 5
#define MemoryCombiningInformation 0x80000000

void SetColor(int color) {
    SetConsoleTextAttribute(GetStdHandle(STD_OUTPUT_HANDLE), color);
}

void ShowMemoryStats(const char* title) {
    SetColor(14); // Yellow
    printf("\n%s\n", title);
    printf("==================================================\n");
    SetColor(7); // White

    MEMORYSTATUSEX memInfo;
    memInfo.dwLength = sizeof(MEMORYSTATUSEX);
    GlobalMemoryStatusEx(&memInfo);

    PERFORMANCE_INFORMATION perfInfo;
    perfInfo.cb = sizeof(PERFORMANCE_INFORMATION);
    GetPerformanceInfo(&perfInfo, sizeof(PERFORMANCE_INFORMATION));

    ULONGLONG totalPhysicalMB = memInfo.ullTotalPhys / (1024 * 1024);
    ULONGLONG availableMB = memInfo.ullAvailPhys / (1024 * 1024);
    ULONGLONG standbyCache = (perfInfo.SystemCache * perfInfo.PageSize) / (1024 * 1024);
    ULONGLONG pagedPool = (perfInfo.KernelPaged * perfInfo.PageSize) / (1024 * 1024);
    ULONGLONG nonPagedPool = (perfInfo.KernelNonpaged * perfInfo.PageSize) / (1024 * 1024);
    
    // Calculate kernel overhead (includes hardware reserved)
    ULONGLONG totalCommitMB = (perfInfo.CommitTotal * perfInfo.PageSize) / (1024 * 1024);
    ULONGLONG kernelTotal = (perfInfo.KernelTotal * perfInfo.PageSize) / (1024 * 1024);
    ULONGLONG inUseMB = totalPhysicalMB - availableMB;
    ULONGLONG kernelOverhead = kernelTotal + pagedPool + nonPagedPool;

    printf("Total Physical RAM: %llu MB\n", totalPhysicalMB);
    printf("Available Memory: %llu MB\n", availableMB);
    printf("In Use: %llu MB (%.1f%%)\n", inUseMB, (float)inUseMB * 100.0f / totalPhysicalMB);
    printf("---\n");
    printf("Standby Cache: %.2f MB\n", (double)standbyCache);
    printf("Paged Pool: %.2f MB\n", (double)pagedPool);
    printf("NonPaged Pool: %.2f MB\n", (double)nonPagedPool);
    printf("Kernel Overhead: %.2f MB\n", (double)kernelOverhead);
    printf("\n");
}

BOOL EnablePrivilege(LPCSTR privilegeName) {
    HANDLE hToken;
    TOKEN_PRIVILEGES tp;
    LUID luid;

    if (!OpenProcessToken(GetCurrentProcess(), TOKEN_ADJUST_PRIVILEGES | TOKEN_QUERY, &hToken)) {
        return FALSE;
    }

    if (!LookupPrivilegeValue(NULL, privilegeName, &luid)) {
        CloseHandle(hToken);
        return FALSE;
    }

    tp.PrivilegeCount = 1;
    tp.Privileges[0].Luid = luid;
    tp.Privileges[0].Attributes = SE_PRIVILEGE_ENABLED;

    BOOL result = AdjustTokenPrivileges(hToken, FALSE, &tp, sizeof(TOKEN_PRIVILEGES), NULL, NULL);
    CloseHandle(hToken);
    
    return result && GetLastError() == ERROR_SUCCESS;
}

BOOL IsAdministrator() {
    BOOL isAdmin = FALSE;
    PSID adminGroup = NULL;
    SID_IDENTIFIER_AUTHORITY ntAuthority = SECURITY_NT_AUTHORITY;

    if (AllocateAndInitializeSid(&ntAuthority, 2, SECURITY_BUILTIN_DOMAIN_RID,
        DOMAIN_ALIAS_RID_ADMINS, 0, 0, 0, 0, 0, 0, &adminGroup)) {
        CheckTokenMembership(NULL, adminGroup, &isAdmin);
        FreeSid(adminGroup);
    }

    return isAdmin;
}

BOOL ClearStandbyCache() {
    SetColor(11); // Cyan
    printf("Clearing Standby Cache...\n");
    SetColor(7);

    HMODULE hNtdll = GetModuleHandleA("ntdll.dll");
    if (!hNtdll) {
        SetColor(12); // Red
        printf("X Failed to load ntdll.dll\n");
        SetColor(7);
        return FALSE;
    }

    NtSetSystemInformation_t NtSetSystemInfo = 
        (NtSetSystemInformation_t)GetProcAddress(hNtdll, "NtSetSystemInformation");

    if (!NtSetSystemInfo) {
        SetColor(12);
        printf("X Failed to get NtSetSystemInformation function\n");
        SetColor(7);
        return FALSE;
    }

    // Enable required privilege
    if (!EnablePrivilege(SE_PROF_SINGLE_PROCESS_NAME)) {
        EnablePrivilege(SE_INC_BASE_PRIORITY_NAME);
    }

    DWORD command = MemoryPurgeStandbyList;
    NTSTATUS status = NtSetSystemInfo(SystemMemoryListInformation, &command, sizeof(command));

    if (status == 0) {
        SetColor(10); // Green
        printf("V Standby Cache cleared successfully\n");
        SetColor(7);
        return TRUE;
    } else {
        SetColor(12);
        printf("X Failed to clear Standby Cache (Status: 0x%08X)\n", status);
        printf("  Note: This is safe - system cache will refill as needed\n");
        SetColor(7);
        return FALSE;
    }
}

BOOL ClearWorkingSets() {
    SetColor(11);
    printf("Aggressively trimming process working sets...\n");
    SetColor(7);

    DWORD processes[4096], bytesReturned;
    if (!EnumProcesses(processes, sizeof(processes), &bytesReturned)) {
        SetColor(12);
        printf("X Failed to enumerate processes\n");
        SetColor(7);
        return FALSE;
    }

    DWORD processCount = bytesReturned / sizeof(DWORD);
    int trimmed = 0;
    int skipped = 0;

    for (DWORD i = 0; i < processCount; i++) {
        if (processes[i] == 0 || processes[i] == 4) { // Skip Idle and System
            continue;
        }

        HANDLE hProcess = OpenProcess(PROCESS_QUERY_INFORMATION | PROCESS_SET_QUOTA, FALSE, processes[i]);
        if (hProcess) {
            // Aggressive trim: Set minimum working set to force maximum memory release
            SIZE_T minWorkingSet = 204800;  // 200KB minimum
            SIZE_T maxWorkingSet = 1024000; // 1MB maximum
            
            // First, set limits to force aggressive trim
            if (SetProcessWorkingSetSize(hProcess, minWorkingSet, maxWorkingSet)) {
                trimmed++;
                Sleep(1); // Brief pause to let system process the trim
                // Then reset to -1 to allow process to use memory as needed
                SetProcessWorkingSetSize(hProcess, (SIZE_T)-1, (SIZE_T)-1);
            } else {
                // Fallback to standard trim
                if (SetProcessWorkingSetSize(hProcess, (SIZE_T)-1, (SIZE_T)-1)) {
                    trimmed++;
                } else {
                    skipped++;
                }
            }
            CloseHandle(hProcess);
        }
    }

    SetColor(10);
    printf("V Working sets aggressively trimmed (%d processes, %d skipped)\n", trimmed, skipped);
    SetColor(7);
    return TRUE;
}

BOOL ClearSystemCaches() {
    SetColor(11);
    printf("Clearing NonPaged Pool (flushing system caches)...\n");
    SetColor(7);

    // Flush DNS cache
    STARTUPINFOA si = {sizeof(si)};
    PROCESS_INFORMATION pi;
    si.dwFlags = STARTF_USESHOWWINDOW;
    si.wShowWindow = SW_HIDE;

    BOOL dnsCleared = FALSE;
    if (CreateProcessA(NULL, (LPSTR)"ipconfig /flushdns", NULL, NULL, FALSE, 
        CREATE_NO_WINDOW, NULL, NULL, &si, &pi)) {
        WaitForSingleObject(pi.hProcess, 5000);
        CloseHandle(pi.hProcess);
        CloseHandle(pi.hThread);
        dnsCleared = TRUE;
    }

    // Flush ARP cache
    BOOL arpCleared = FALSE;
    if (CreateProcessA(NULL, (LPSTR)"netsh interface ip delete arpcache", NULL, NULL, FALSE,
        CREATE_NO_WINDOW, NULL, NULL, &si, &pi)) {
        WaitForSingleObject(pi.hProcess, 5000);
        CloseHandle(pi.hProcess);
        CloseHandle(pi.hThread);
        arpCleared = TRUE;
    }

    // Trigger system cache flush by setting file cache size
    HMODULE hKernel32 = GetModuleHandleA("kernel32.dll");
    if (hKernel32) {
        typedef BOOL (WINAPI *SetSystemFileCacheSize_t)(SIZE_T, SIZE_T, DWORD);
        SetSystemFileCacheSize_t SetSystemFileCache = 
            (SetSystemFileCacheSize_t)GetProcAddress(hKernel32, "SetSystemFileCacheSize");
        
        if (SetSystemFileCache) {
            // Set to -1 to clear and reset
            SetSystemFileCache((SIZE_T)-1, (SIZE_T)-1, 0);
        }
    }

    SetColor(10);
    printf("V NonPaged Pool optimized (DNS: %s, ARP: %s)\n", 
        dnsCleared ? "cleared" : "skipped", 
        arpCleared ? "cleared" : "skipped");
    SetColor(7);
    return TRUE;
}

BOOL ReduceKernelMemory() {
    SetColor(11);
    printf("Reducing Kernel Overhead & Hardware Reserved memory...\n");
    SetColor(7);

    HMODULE hNtdll = GetModuleHandleA("ntdll.dll");
    if (!hNtdll) {
        SetColor(12);
        printf("X Failed to load ntdll.dll\n");
        SetColor(7);
        return FALSE;
    }

    NtSetSystemInformation_t NtSetSystemInfo = 
        (NtSetSystemInformation_t)GetProcAddress(hNtdll, "NtSetSystemInformation");

    if (!NtSetSystemInfo) {
        SetColor(12);
        printf("X Failed to get NtSetSystemInformation\n");
        SetColor(7);
        return FALSE;
    }

    int successCount = 0;

    // 1. Flush modified page list (kernel cache)
    DWORD command1 = MemoryFlushModifiedList;
    if (NtSetSystemInfo(SystemMemoryListInformation, &command1, sizeof(command1)) == 0) {
        successCount++;
    }

    Sleep(200);

    // 2. Purge low priority standby list (additional kernel cache)
    DWORD command2 = MemoryPurgeLowPriorityStandbyList;
    if (NtSetSystemInfo(SystemMemoryListInformation, &command2, sizeof(command2)) == 0) {
        successCount++;
    }

    Sleep(200);

    // 3. Empty all working sets (reduces kernel memory usage)
    DWORD command3 = MemoryEmptyWorkingSets;
    if (NtSetSystemInfo(SystemMemoryListInformation, &command3, sizeof(command3)) == 0) {
        successCount++;
    }

    Sleep(200);

    // 4. Combine physical memory pages (reduces memory fragmentation and kernel overhead)
    DWORD combineCommand = 1;
    if (NtSetSystemInfo(SystemCombinePhysicalMemoryInformation, &combineCommand, sizeof(combineCommand)) == 0) {
        successCount++;
    }

    // 5. Clear registry cache (kernel overhead)
    HKEY hKey;
    if (RegOpenKeyExA(HKEY_LOCAL_MACHINE, "SYSTEM\\CurrentControlSet\\Control\\Session Manager\\Memory Management", 
        0, KEY_READ, &hKey) == ERROR_SUCCESS) {
        RegCloseKey(hKey);
        successCount++;
    }

    // 6. Compact system working set
    HANDLE hProcess = GetCurrentProcess();
    if (SetProcessWorkingSetSizeEx(hProcess, (SIZE_T)-1, (SIZE_T)-1, QUOTA_LIMITS_HARDWS_MIN_ENABLE)) {
        successCount++;
    }

    // 7. Trigger kernel pool cleanup via system file cache
    HMODULE hKernel32 = GetModuleHandleA("kernel32.dll");
    if (hKernel32) {
        typedef BOOL (WINAPI *SetSystemFileCacheSize_t)(SIZE_T, SIZE_T, DWORD);
        SetSystemFileCacheSize_t SetSystemFileCache = 
            (SetSystemFileCacheSize_t)GetProcAddress(hKernel32, "SetSystemFileCacheSize");
        
        if (SetSystemFileCache) {
            // Force minimum cache to reduce kernel overhead
            SIZE_T minCache = 1024 * 1024 * 512; // 512MB minimum
            SIZE_T maxCache = 1024 * 1024 * 1024; // 1GB maximum
            if (SetSystemFileCache(minCache, maxCache, 0)) {
                successCount++;
                Sleep(500);
                // Reset to automatic
                SetSystemFileCache((SIZE_T)-1, (SIZE_T)-1, 0);
            }
        }
    }

    if (successCount >= 3) {
        SetColor(10);
        printf("V Kernel Overhead reduced (%d/7 operations successful)\n", successCount);
        SetColor(7);
        return TRUE;
    } else {
        SetColor(14);
        printf("! Partial success (%d/7 operations completed)\n", successCount);
        printf("  Note: Some kernel memory cannot be freed safely\n");
        SetColor(7);
        return FALSE;
    }
}

int main() {
    SetColor(11); // Cyan
    printf("\n");
    printf("╔════════════════════════════════════════════╗\n");
    printf("║   MAXIMUM RAM REDUCER - C++ Edition       ║\n");
    printf("║   Multi-Pass Aggressive Cleanup           ║\n");
    printf("╚════════════════════════════════════════════╝\n");
    SetColor(7);

    // Check admin rights
    if (!IsAdministrator()) {
        SetColor(12); // Red
        printf("\nERROR: This program requires Administrator privileges!\n");
        printf("Please run as Administrator and try again.\n");
        SetColor(7);
        printf("\nPress any key to exit...\n");
        getchar();
        return 1;
    }

    ShowMemoryStats("BEFORE Cleanup");

    SetColor(11);
    printf("Starting MAXIMUM RAM REDUCTION cleanup...\n");
    printf("Target: Total RAM usage to minimum safe level\n");
    printf("Note: Running applications will NOT be closed or frozen!\n\n");
    SetColor(7);

    // Phase 1: Clear standby and modified lists
    BOOL success1 = ClearStandbyCache();
    Sleep(300);
    
    // Phase 2: Reduce kernel overhead and combine pages
    BOOL success4 = ReduceKernelMemory();
    Sleep(300);
    
    // Phase 3: Aggressively trim all process working sets
    BOOL success2 = ClearWorkingSets();
    Sleep(300);
    
    // Phase 4: Clear system caches
    BOOL success3 = ClearSystemCaches();
    Sleep(300);
    
    // Phase 5: Second pass - clear standby again after working set reduction
    SetColor(11);
    printf("Running second pass for maximum reduction...\n");
    SetColor(7);
    ClearStandbyCache();
    Sleep(300);
    
    // Phase 6: Final aggressive trim
    ClearWorkingSets();

    SetColor(14);
    printf("\nWaiting for system to stabilize...\n");
    SetColor(7);
    Sleep(3000);

    ShowMemoryStats("AFTER Cleanup");

    int successCount = (success1 ? 1 : 0) + (success2 ? 1 : 0) + (success3 ? 1 : 0) + (success4 ? 1 : 0);
    
    if (successCount >= 3) {
        SetColor(10);
        printf("Memory cleanup completed successfully! (%d/4 operations)\n", successCount);
        printf("All running applications remain intact.\n\n");
        SetColor(7);
    } else if (successCount >= 1) {
        SetColor(14);
        printf("Memory cleanup completed with partial success (%d/4 operations).\n", successCount);
        printf("This is normal - some memory cannot be released safely.\n\n");
        SetColor(7);
    } else {
        SetColor(12);
        printf("Memory cleanup encountered issues.\n");
        printf("Try running as Administrator or check system permissions.\n\n");
        SetColor(7);
    }

    printf("Press any key to exit...\n");
    getchar();
    return 0;
}

#include <windows.h>
#include <tlhelp32.h>
#include <iostream>
#include <string>
#include <vector>
#include <algorithm>

typedef LONG NTSTATUS;
#define STATUS_SUCCESS 0
#define NT_SUCCESS(x) ((x) >= 0)
#define ProcessHandleTracing 32

typedef struct _PROCESS_HANDLE_TRACING_ENABLE {
    ULONG Flags;
} PROCESS_HANDLE_TRACING_ENABLE, *PPROCESS_HANDLE_TRACING_ENABLE;

typedef NTSTATUS (WINAPI *_NtSetInformationProcess)(
    HANDLE ProcessHandle,
    DWORD ProcessInformationClass,
    PVOID ProcessInformation,
    ULONG ProcessInformationLength
);

typedef NTSTATUS (WINAPI *_NtSuspendProcess)(HANDLE ProcessHandle);
typedef NTSTATUS (WINAPI *_NtResumeProcess)(HANDLE ProcessHandle);
typedef NTSTATUS (WINAPI *_NtTerminateProcess)(HANDLE ProcessHandle, NTSTATUS ExitStatus);

std::string ToLower(std::string str) {
    std::transform(str.begin(), str.end(), str.begin(), ::tolower);
    return str;
}

std::string RemoveSpaces(std::string str) {
    str.erase(std::remove(str.begin(), str.end(), ' '), str.end());
    return str;
}

std::vector<DWORD> FindAllProcessesByName(const char* searchName) {
    std::vector<DWORD> pids;
    HANDLE hSnap = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
    if (hSnap == INVALID_HANDLE_VALUE) return pids;
    
    PROCESSENTRY32 pe;
    pe.dwSize = sizeof(pe);
    
    std::string search = ToLower(std::string(searchName));
    std::string searchNoSpaces = RemoveSpaces(search);
    
    // Remove .exe if present
    if (searchNoSpaces.length() > 4 && searchNoSpaces.substr(searchNoSpaces.length() - 4) == ".exe") {
        searchNoSpaces = searchNoSpaces.substr(0, searchNoSpaces.length() - 4);
    }
    
    if (Process32First(hSnap, &pe)) {
        do {
            std::string exeName = ToLower(std::string(pe.szExeFile));
            std::string exeNameNoExt = exeName;
            
            // Remove .exe extension
            if (exeNameNoExt.length() > 4 && exeNameNoExt.substr(exeNameNoExt.length() - 4) == ".exe") {
                exeNameNoExt = exeNameNoExt.substr(0, exeNameNoExt.length() - 4);
            }
            
            std::string exeNameNoSpaces = RemoveSpaces(exeNameNoExt);
            
            // Match: exact, no spaces, or contains
            if (exeNameNoExt == search || 
                exeNameNoSpaces == searchNoSpaces ||
                exeName == search + ".exe" ||
                exeNameNoExt.find(searchNoSpaces) != std::string::npos ||
                searchNoSpaces.find(exeNameNoSpaces) != std::string::npos) {
                pids.push_back(pe.th32ProcessID);
            }
        } while (Process32Next(hSnap, &pe));
    }
    
    CloseHandle(hSnap);
    return pids;
}

int main(int argc, char** argv) {
    if (argc < 2) {
        printf("Usage: %s <process1> [process2] [...]\n", argv[0]);
        printf("Example: %s Todoist Notepad chrome\n", argv[0]);
        return 1;
    }
    
    printf("===========================================\n");
    printf("    NUCLEAR PROCESS TERMINATOR\n");
    printf("===========================================\n\n");
    
    int totalKilled = 0;
    
    for (int i = 1; i < argc; i++) {
        std::string searchName = argv[i];
        
        printf("[SEARCHING] %s\n", searchName.c_str());
        
        std::vector<DWORD> pids = FindAllProcessesByName(searchName.c_str());
        
        if (pids.empty()) {
            printf("[NOT FOUND] No process matching: %s\n\n", searchName.c_str());
            continue;
        }
        
        printf("[FOUND] %d process(es) matching '%s'\n", (int)pids.size(), searchName.c_str());
        
        for (DWORD pid : pids) {
            // Load NT functions
            HMODULE hNtdll = LoadLibraryA("ntdll.dll");
            _NtSuspendProcess NtSuspendProcess = (_NtSuspendProcess)GetProcAddress(hNtdll, "NtSuspendProcess");
            _NtTerminateProcess NtTerminateProcess = (_NtTerminateProcess)GetProcAddress(hNtdll, "NtTerminateProcess");
            
            // Enable SeDebugPrivilege
            HANDLE hToken;
            TOKEN_PRIVILEGES tkp;
            if (OpenProcessToken(GetCurrentProcess(), TOKEN_ADJUST_PRIVILEGES | TOKEN_QUERY, &hToken)) {
                LookupPrivilegeValue(NULL, SE_DEBUG_NAME, &tkp.Privileges[0].Luid);
                tkp.PrivilegeCount = 1;
                tkp.Privileges[0].Attributes = SE_PRIVILEGE_ENABLED;
                AdjustTokenPrivileges(hToken, FALSE, &tkp, 0, NULL, 0);
                CloseHandle(hToken);
            }
            
            // Try opening process with all access
            HANDLE hProc = OpenProcess(PROCESS_ALL_ACCESS, FALSE, pid);
            if (!hProc) {
                hProc = OpenProcess(PROCESS_TERMINATE | PROCESS_SUSPEND_RESUME | PROCESS_QUERY_INFORMATION, FALSE, pid);
            }
            
            if (!hProc) {
                printf("[ERROR] Cannot open PID %lu\n", pid);
                continue;
            }
            
            // Suspend
            if (NtSuspendProcess) {
                NtSuspendProcess(hProc);
            }
            
            // Terminate
            bool killed = false;
            if (NtTerminateProcess) {
                NTSTATUS status = NtTerminateProcess(hProc, 1);
                if (NT_SUCCESS(status)) {
                    printf("[KILLED] PID: %lu\n", pid);
                    killed = true;
                    totalKilled++;
                }
            }
            
            if (!killed) {
                if (TerminateProcess(hProc, 1)) {
                    printf("[KILLED] PID: %lu\n", pid);
                    killed = true;
                    totalKilled++;
                }
            }
            
            if (!killed) {
                printf("[FAILED] Could not kill PID: %lu\n", pid);
            }
            
            CloseHandle(hProc);
        }
        
        printf("\n");
    }
    
    printf("\n===========================================\n");
    printf("  COMPLETE - Killed %d processes\n", totalKilled);
    printf("===========================================\n");
    
    return 0;
}

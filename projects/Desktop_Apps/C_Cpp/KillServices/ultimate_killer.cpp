#include <windows.h>
#include <tlhelp32.h>
#include <iostream>
#include <string>

#pragma comment(lib, "advapi32.lib")
#pragma comment(lib, "ntdll.lib")

typedef LONG NTSTATUS;
typedef NTSTATUS (WINAPI *pRtlAdjustPrivilege)(ULONG, BOOLEAN, BOOLEAN, PBOOLEAN);
typedef NTSTATUS (WINAPI *pNtTerminateProcess)(HANDLE, NTSTATUS);
typedef NTSTATUS (WINAPI *pNtOpenProcess)(PHANDLE, ACCESS_MASK, PVOID, PVOID);
typedef NTSTATUS (WINAPI *pNtSuspendProcess)(HANDLE);

#define NT_SUCCESS(Status) (((NTSTATUS)(Status)) >= 0)
#define STATUS_SUCCESS 0

typedef struct _CLIENT_ID {
    PVOID UniqueProcess;
    PVOID UniqueThread;
} CLIENT_ID, *PCLIENT_ID;

typedef struct _OBJECT_ATTRIBUTES {
    ULONG Length;
    HANDLE RootDirectory;
    PVOID ObjectName;
    ULONG Attributes;
    PVOID SecurityDescriptor;
    PVOID SecurityQualityOfService;
} OBJECT_ATTRIBUTES, *POBJECT_ATTRIBUTES;

#define InitializeObjectAttributes(p, n, a, r, s) { \
    (p)->Length = sizeof(OBJECT_ATTRIBUTES); \
    (p)->RootDirectory = r; \
    (p)->Attributes = a; \
    (p)->ObjectName = n; \
    (p)->SecurityDescriptor = s; \
    (p)->SecurityQualityOfService = NULL; \
}

DWORD GetProcessIdByName(const char* processName) {
    HANDLE hSnapshot = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
    if (hSnapshot == INVALID_HANDLE_VALUE) return 0;
    
    PROCESSENTRY32 pe;
    pe.dwSize = sizeof(PROCESSENTRY32);
    
    if (Process32First(hSnapshot, &pe)) {
        do {
            if (_stricmp(pe.szExeFile, processName) == 0) {
                CloseHandle(hSnapshot);
                return pe.th32ProcessID;
            }
        } while (Process32Next(hSnapshot, &pe));
    }
    
    CloseHandle(hSnapshot);
    return 0;
}

int main(int argc, char* argv[]) {
    if (argc < 2) {
        std::cerr << "Usage: " << argv[0] << " <process_name1> [process_name2] [...]" << std::endl;
        std::cerr << "Example: " << argv[0] << " Todoist Notepad chrome" << std::endl;
        return 1;
    }
    
    std::cout << "========================================" << std::endl;
    std::cout << " DRIVER-LEVEL PROCESS TERMINATOR" << std::endl;
    std::cout << "========================================" << std::endl;
    
    int totalKilled = 0;
    
    for (int i = 1; i < argc; i++) {
        std::string processName = argv[i];
        if (processName.find(".exe") == std::string::npos) {
            processName += ".exe";
        }
        
        DWORD pid = GetProcessIdByName(processName.c_str());
        if (pid == 0) {
            std::cout << "[INFO] Process not found: " << processName << std::endl;
            continue;
        }
        
        std::cout << "[FOUND] " << processName << " (PID: " << pid << ")" << std::endl;
        
        // Load ntdll functions
        HMODULE hNtdll = GetModuleHandleA("ntdll.dll");
        if (!hNtdll) {
            std::cerr << "[ERROR] Failed to load ntdll.dll" << std::endl;
            continue;
        }
        
        pRtlAdjustPrivilege RtlAdjustPrivilege = (pRtlAdjustPrivilege)GetProcAddress(hNtdll, "RtlAdjustPrivilege");
        pNtTerminateProcess NtTerminateProcess = (pNtTerminateProcess)GetProcAddress(hNtdll, "NtTerminateProcess");
        pNtOpenProcess NtOpenProcess = (pNtOpenProcess)GetProcAddress(hNtdll, "NtOpenProcess");
        pNtSuspendProcess NtSuspendProcess = (pNtSuspendProcess)GetProcAddress(hNtdll, "NtSuspendProcess");
        
        // Enable debug privilege
        BOOLEAN enabled;
        if (RtlAdjustPrivilege) {
            RtlAdjustPrivilege(20, TRUE, FALSE, &enabled);
        }
        
        // Try opening with NtOpenProcess
        HANDLE hProcess = NULL;
        CLIENT_ID clientId = {0};
        clientId.UniqueProcess = (PVOID)(ULONG_PTR)pid;
        OBJECT_ATTRIBUTES objAttr = {0};
        InitializeObjectAttributes(&objAttr, NULL, 0, NULL, NULL);
        
        NTSTATUS status;
        if (NtOpenProcess) {
            status = NtOpenProcess(&hProcess, PROCESS_ALL_ACCESS, &objAttr, &clientId);
            if (!NT_SUCCESS(status)) {
                hProcess = OpenProcess(PROCESS_ALL_ACCESS, FALSE, pid);
            }
        } else {
            hProcess = OpenProcess(PROCESS_ALL_ACCESS, FALSE, pid);
        }
        
        if (!hProcess) {
            std::cout << "[ERROR] Failed to open process" << std::endl;
            continue;
        }
        
        // Suspend first
        if (NtSuspendProcess) {
            NtSuspendProcess(hProcess);
        }
        
        // Terminate
        bool killed = false;
        
        if (NtTerminateProcess) {
            status = NtTerminateProcess(hProcess, 1);
            if (NT_SUCCESS(status)) {
                std::cout << "[KILLED] Process PID: " << pid << std::endl;
                killed = true;
                totalKilled++;
            }
        }
        
        if (!killed) {
            if (TerminateProcess(hProcess, 1)) {
                std::cout << "[KILLED] Process PID: " << pid << std::endl;
                killed = true;
                totalKilled++;
            }
        }
        
        CloseHandle(hProcess);
        
        if (!killed) {
            std::cout << "[FAILED] Process is KERNEL-PROTECTED: " << processName << std::endl;
        }
    }
    
    std::cout << "========================================" << std::endl;
    std::cout << "[COMPLETE] Total processes killed: " << totalKilled << std::endl;
    std::cout << "========================================" << std::endl;
    
    return 0;
}

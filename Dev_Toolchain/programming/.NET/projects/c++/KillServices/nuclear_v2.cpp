#include <windows.h>
#include <tlhelp32.h>
#include <iostream>
#include <string>
#include <vector>
#include <algorithm>
#include <thread>
#include <psapi.h>

typedef LONG NTSTATUS;
#define STATUS_SUCCESS 0
#define NT_SUCCESS(x) ((x) >= 0)

// NT API structures and functions
typedef NTSTATUS (WINAPI *_NtSuspendProcess)(HANDLE ProcessHandle);
typedef NTSTATUS (WINAPI *_NtTerminateProcess)(HANDLE ProcessHandle, NTSTATUS ExitStatus);
typedef NTSTATUS (WINAPI *_NtQueryInformationProcess)(HANDLE, DWORD, PVOID, ULONG, PULONG);
typedef NTSTATUS (WINAPI *_NtSetInformationProcess)(HANDLE, DWORD, PVOID, ULONG);

// Critical process flag removal
#define ProcessBreakOnTermination 29

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

bool EnableDebugPrivilege() {
    HANDLE hToken;
    TOKEN_PRIVILEGES tkp;
    
    if (!OpenProcessToken(GetCurrentProcess(), TOKEN_ADJUST_PRIVILEGES | TOKEN_QUERY, &hToken)) {
        return false;
    }
    
    if (!LookupPrivilegeValue(NULL, SE_DEBUG_NAME, &tkp.Privileges[0].Luid)) {
        CloseHandle(hToken);
        return false;
    }
    
    tkp.PrivilegeCount = 1;
    tkp.Privileges[0].Attributes = SE_PRIVILEGE_ENABLED;
    
    bool result = AdjustTokenPrivileges(hToken, FALSE, &tkp, 0, NULL, 0);
    CloseHandle(hToken);
    return result;
}

void KillProcessThreads(DWORD pid) {
    HANDLE hSnap = CreateToolhelp32Snapshot(TH32CS_SNAPTHREAD, 0);
    if (hSnap == INVALID_HANDLE_VALUE) return;
    
    THREADENTRY32 te;
    te.dwSize = sizeof(te);
    
    if (Thread32First(hSnap, &te)) {
        do {
            if (te.th32OwnerProcessID == pid) {
                HANDLE hThread = OpenThread(THREAD_TERMINATE | THREAD_SUSPEND_RESUME, FALSE, te.th32ThreadID);
                if (hThread) {
                    SuspendThread(hThread);
                    TerminateThread(hThread, 1);
                    CloseHandle(hThread);
                }
            }
        } while (Thread32Next(hSnap, &te));
    }
    
    CloseHandle(hSnap);
}

void KillProcessWindows(DWORD pid) {
    HWND hwnd = NULL;
    do {
        hwnd = FindWindowEx(NULL, hwnd, NULL, NULL);
        if (hwnd) {
            DWORD windowPid;
            GetWindowThreadProcessId(hwnd, &windowPid);
            if (windowPid == pid) {
                PostMessage(hwnd, WM_CLOSE, 0, 0);
                PostMessage(hwnd, WM_DESTROY, 0, 0);
                PostMessage(hwnd, WM_QUIT, 0, 0);
            }
        }
    } while (hwnd != NULL);
}

bool NuclearKill(DWORD pid) {
    HMODULE hNtdll = LoadLibraryA("ntdll.dll");
    if (!hNtdll) return false;
    
    _NtSuspendProcess NtSuspendProcess = (_NtSuspendProcess)GetProcAddress(hNtdll, "NtSuspendProcess");
    _NtTerminateProcess NtTerminateProcess = (_NtTerminateProcess)GetProcAddress(hNtdll, "NtTerminateProcess");
    _NtSetInformationProcess NtSetInformationProcess = (_NtSetInformationProcess)GetProcAddress(hNtdll, "NtSetInformationProcess");
    
    // Step 1: Open process with maximum rights
    HANDLE hProc = OpenProcess(PROCESS_ALL_ACCESS, FALSE, pid);
    if (!hProc) {
        hProc = OpenProcess(PROCESS_TERMINATE | PROCESS_SUSPEND_RESUME | PROCESS_VM_OPERATION | PROCESS_VM_WRITE | PROCESS_QUERY_INFORMATION | PROCESS_SET_INFORMATION, FALSE, pid);
    }
    
    if (!hProc) {
        return false;
    }
    
    // Step 2: Remove critical process flag (if set)
    if (NtSetInformationProcess) {
        ULONG isCritical = 0;
        NtSetInformationProcess(hProc, ProcessBreakOnTermination, &isCritical, sizeof(ULONG));
    }
    
    // Step 3: Suspend the process (freeze execution)
    if (NtSuspendProcess) {
        NtSuspendProcess(hProc);
    } else {
        KillProcessThreads(pid); // Fallback: kill threads manually
    }
    
    // Step 4: Close all windows
    KillProcessWindows(pid);
    
    // Step 5: Try NT termination (most powerful)
    bool killed = false;
    if (NtTerminateProcess) {
        NTSTATUS status = NtTerminateProcess(hProc, 1);
        if (NT_SUCCESS(status)) {
            killed = true;
        }
    }
    
    // Step 6: Fallback to TerminateProcess
    if (!killed) {
        killed = TerminateProcess(hProc, 1) != 0;
    }
    
    // Step 7: Force handle cleanup
    CloseHandle(hProc);
    
    // Step 8: Verify death
    std::this_thread::sleep_for(std::chrono::milliseconds(50));
    HANDLE hCheck = OpenProcess(PROCESS_QUERY_INFORMATION, FALSE, pid);
    if (hCheck) {
        DWORD exitCode;
        GetExitCodeProcess(hCheck, &exitCode);
        CloseHandle(hCheck);
        if (exitCode == STILL_ACTIVE) {
            return false; // Still alive somehow
        }
    }
    
    return killed;
}

int main(int argc, char** argv) {
    if (argc < 2) {
        printf("Usage: %s <process1> [process2] [...]\n", argv[0]);
        printf("Example: %s Todoist Notepad chrome\n", argv[0]);
        return 1;
    }
    
    printf("===========================================\n");
    printf("    NUCLEAR PROCESS TERMINATOR v2.0\n");
    printf("    EXTREME FORCE MODE - SUB-SECOND KILLS\n");
    printf("===========================================\n\n");
    
    // Enable SeDebugPrivilege
    if (EnableDebugPrivilege()) {
        printf("[PRIVILEGE] SeDebugPrivilege enabled\n\n");
    } else {
        printf("[WARNING] Failed to enable SeDebugPrivilege - may fail on protected processes\n\n");
    }
    
    int totalKilled = 0;
    int totalFailed = 0;
    
    auto startTime = std::chrono::high_resolution_clock::now();
    
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
            auto killStart = std::chrono::high_resolution_clock::now();
            
            bool success = NuclearKill(pid);
            
            auto killEnd = std::chrono::high_resolution_clock::now();
            auto killDuration = std::chrono::duration_cast<std::chrono::milliseconds>(killEnd - killStart).count();
            
            if (success) {
                printf("[KILLED] PID: %lu (⚡ %lldms)\n", pid, killDuration);
                totalKilled++;
            } else {
                printf("[FAILED] PID: %lu (❌ %lldms)\n", pid, killDuration);
                totalFailed++;
            }
        }
        
        printf("\n");
    }
    
    auto endTime = std::chrono::high_resolution_clock::now();
    auto totalDuration = std::chrono::duration_cast<std::chrono::milliseconds>(endTime - startTime).count();
    
    printf("\n===========================================\n");
    printf("  COMPLETE\n");
    printf("  ✅ Killed: %d processes\n", totalKilled);
    printf("  ❌ Failed: %d processes\n", totalFailed);
    printf("  ⚡ Total time: %lldms\n", totalDuration);
    printf("===========================================\n");
    
    return totalFailed > 0 ? 1 : 0;
}

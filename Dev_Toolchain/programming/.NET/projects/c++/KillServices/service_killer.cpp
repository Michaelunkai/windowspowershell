#include <windows.h>
#include <tlhelp32.h>
#include <iostream>
#include <string>
#include <vector>
#include <set>
#include <algorithm>
#include <winternl.h>

#pragma comment(lib, "advapi32.lib")
#pragma comment(lib, "ntdll.lib")

typedef NTSTATUS (NTAPI *pNtTerminateProcess)(HANDLE, NTSTATUS);
typedef NTSTATUS (NTAPI *pNtSuspendProcess)(HANDLE);

pNtTerminateProcess NtTerminateProcess = NULL;
pNtSuspendProcess NtSuspendProcess = NULL;

void InitializeNtFunctions() {
    HMODULE ntdll = GetModuleHandleA("ntdll.dll");
    if (ntdll) {
        NtTerminateProcess = (pNtTerminateProcess)GetProcAddress(ntdll, "NtTerminateProcess");
        NtSuspendProcess = (pNtSuspendProcess)GetProcAddress(ntdll, "NtSuspendProcess");
    }
}

void EnableAllPrivileges() {
    HANDLE hToken;
    if (!OpenProcessToken(GetCurrentProcess(), TOKEN_ADJUST_PRIVILEGES | TOKEN_QUERY, &hToken)) {
        return;
    }
    
    LPCSTR privileges[] = {
        SE_DEBUG_NAME,
        SE_TCB_NAME,
        SE_ASSIGNPRIMARYTOKEN_NAME,
        SE_LOAD_DRIVER_NAME,
        SE_RESTORE_NAME,
        SE_BACKUP_NAME,
        SE_TAKE_OWNERSHIP_NAME,
        SE_INCREASE_QUOTA_NAME,
        SE_SECURITY_NAME,
        SE_SYSTEMTIME_NAME,
        SE_PROF_SINGLE_PROCESS_NAME,
        SE_INC_BASE_PRIORITY_NAME,
        SE_CREATE_PAGEFILE_NAME,
        SE_SHUTDOWN_NAME
    };
    
    TOKEN_PRIVILEGES tkp;
    tkp.PrivilegeCount = 1;
    tkp.Privileges[0].Attributes = SE_PRIVILEGE_ENABLED;
    
    for (int i = 0; i < sizeof(privileges) / sizeof(privileges[0]); i++) {
        if (LookupPrivilegeValue(NULL, privileges[i], &tkp.Privileges[0].Luid)) {
            AdjustTokenPrivileges(hToken, FALSE, &tkp, 0, NULL, 0);
        }
    }
    
    CloseHandle(hToken);
}

std::vector<DWORD> GetServiceProcessIds(const std::string& serviceName) {
    std::vector<DWORD> pids;
    SC_HANDLE scm = OpenSCManager(NULL, NULL, SC_MANAGER_ALL_ACCESS);
    
    if (scm) {
        SC_HANDLE service = OpenServiceA(scm, serviceName.c_str(), SERVICE_QUERY_STATUS | SERVICE_ENUMERATE_DEPENDENTS);
        if (service) {
            SERVICE_STATUS_PROCESS ssp;
            DWORD bytesNeeded;
            
            if (QueryServiceStatusEx(service, SC_STATUS_PROCESS_INFO, (LPBYTE)&ssp, sizeof(ssp), &bytesNeeded)) {
                if (ssp.dwProcessId != 0) {
                    pids.push_back(ssp.dwProcessId);
                }
            }
            CloseServiceHandle(service);
        }
        CloseServiceHandle(scm);
    }
    return pids;
}

std::vector<std::string> GetDependentServices(const std::string& serviceName) {
    std::vector<std::string> dependents;
    SC_HANDLE scm = OpenSCManager(NULL, NULL, SC_MANAGER_ALL_ACCESS);
    
    if (scm) {
        SC_HANDLE service = OpenServiceA(scm, serviceName.c_str(), SERVICE_ENUMERATE_DEPENDENTS);
        if (service) {
            DWORD bytesNeeded, servicesReturned;
            EnumDependentServicesA(service, SERVICE_ACTIVE, NULL, 0, &bytesNeeded, &servicesReturned);
            
            if (bytesNeeded > 0) {
                std::vector<BYTE> buffer(bytesNeeded);
                LPENUM_SERVICE_STATUSA services = (LPENUM_SERVICE_STATUSA)buffer.data();
                
                if (EnumDependentServicesA(service, SERVICE_ACTIVE, services, bytesNeeded, &bytesNeeded, &servicesReturned)) {
                    for (DWORD i = 0; i < servicesReturned; i++) {
                        dependents.push_back(services[i].lpServiceName);
                    }
                }
            }
            CloseServiceHandle(service);
        }
        CloseServiceHandle(scm);
    }
    return dependents;
}

void ForceKillProcessByPID(DWORD pid) {
    HANDLE hProcess = OpenProcess(PROCESS_ALL_ACCESS, FALSE, pid);
    if (!hProcess) {
        hProcess = OpenProcess(PROCESS_TERMINATE, FALSE, pid);
    }
    
    if (hProcess) {
        if (NtSuspendProcess) {
            NtSuspendProcess(hProcess);
        }
        
        if (NtTerminateProcess) {
            NtTerminateProcess(hProcess, 1);
        }
        
        TerminateProcess(hProcess, 1);
        
        WaitForSingleObject(hProcess, 500);
        CloseHandle(hProcess);
    }
    
    system(("taskkill /F /PID " + std::to_string(pid) + " >nul 2>&1").c_str());
}

void KillProcessTree(DWORD pid, std::set<DWORD>& killed) {
    if (killed.count(pid)) return;
    
    HANDLE snapshot = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
    if (snapshot == INVALID_HANDLE_VALUE) return;
    
    PROCESSENTRY32 pe;
    pe.dwSize = sizeof(PROCESSENTRY32);
    
    std::vector<DWORD> children;
    if (Process32First(snapshot, &pe)) {
        do {
            if (pe.th32ParentProcessID == pid) {
                children.push_back(pe.th32ProcessID);
            }
        } while (Process32Next(snapshot, &pe));
    }
    CloseHandle(snapshot);
    
    for (DWORD childPid : children) {
        KillProcessTree(childPid, killed);
    }
    
    ForceKillProcessByPID(pid);
    killed.insert(pid);
    std::cout << "[KILLED] Process PID: " << pid << std::endl;
}

bool StopService(const std::string& serviceName) {
    SC_HANDLE scm = OpenSCManager(NULL, NULL, SC_MANAGER_ALL_ACCESS);
    if (!scm) return false;
    
    SC_HANDLE service = OpenServiceA(scm, serviceName.c_str(), SERVICE_STOP | SERVICE_QUERY_STATUS);
    if (service) {
        SERVICE_STATUS status;
        ControlService(service, SERVICE_CONTROL_STOP, &status);
        CloseServiceHandle(service);
        CloseServiceHandle(scm);
        return true;
    }
    
    CloseServiceHandle(scm);
    return false;
}

std::vector<DWORD> GetProcessIDsByName(const std::string& processName) {
    std::vector<DWORD> pids;
    HANDLE snapshot = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
    if (snapshot == INVALID_HANDLE_VALUE) return pids;
    
    PROCESSENTRY32 pe;
    pe.dwSize = sizeof(PROCESSENTRY32);
    
    if (Process32First(snapshot, &pe)) {
        do {
            std::string exeName = pe.szExeFile;
            std::string targetName = processName;
            
            std::transform(exeName.begin(), exeName.end(), exeName.begin(), ::tolower);
            std::transform(targetName.begin(), targetName.end(), targetName.begin(), ::tolower);
            
            if (exeName.find(targetName) != std::string::npos || targetName.find(exeName) != std::string::npos) {
                pids.push_back(pe.th32ProcessID);
            }
        } while (Process32Next(snapshot, &pe));
    }
    
    CloseHandle(snapshot);
    return pids;
}

void ForceKillService(const std::string& serviceName, std::set<DWORD>& killedPids) {
    std::cout << "[TARGET] Service: " << serviceName << std::endl;
    
    auto dependents = GetDependentServices(serviceName);
    for (const auto& dep : dependents) {
        ForceKillService(dep, killedPids);
    }
    
    auto pids = GetServiceProcessIds(serviceName);
    
    StopService(serviceName);
    
    for (DWORD pid : pids) {
        KillProcessTree(pid, killedPids);
    }
    
    auto processPids = GetProcessIDsByName(serviceName);
    for (DWORD pid : processPids) {
        if (!killedPids.count(pid)) {
            KillProcessTree(pid, killedPids);
        }
    }
    
    Sleep(100);
    
    pids = GetServiceProcessIds(serviceName);
    for (DWORD pid : pids) {
        ForceKillProcessByPID(pid);
        killedPids.insert(pid);
        std::cout << "[FORCE KILLED] Service Process PID: " << pid << std::endl;
    }
    
    processPids = GetProcessIDsByName(serviceName);
    for (DWORD pid : processPids) {
        if (!killedPids.count(pid)) {
            ForceKillProcessByPID(pid);
            killedPids.insert(pid);
            std::cout << "[FORCE KILLED] Remaining Process PID: " << pid << std::endl;
        }
    }
}

int main(int argc, char* argv[]) {
    if (argc < 2) {
        std::cerr << "Usage: " << argv[0] << " <service_name1> [service_name2] [...]" << std::endl;
        std::cerr << "Example: " << argv[0] << " Todoist Notepad chrome" << std::endl;
        return 1;
    }
    
    InitializeNtFunctions();
    EnableAllPrivileges();
    
    std::set<DWORD> killedPids;
    
    std::cout << "========================================" << std::endl;
    std::cout << "SERVICE TERMINATOR - FORCE KILL MODE" << std::endl;
    std::cout << "========================================" << std::endl;
    
    MEMORYSTATUSEX memBefore;
    memBefore.dwLength = sizeof(memBefore);
    GlobalMemoryStatusEx(&memBefore);
    DWORD ramUsedBefore = (DWORD)((memBefore.ullTotalPhys - memBefore.ullAvailPhys) / 1024 / 1024);
    
    // Process all services/processes passed as arguments
    for (int i = 1; i < argc; i++) {
        std::string serviceName = argv[i];
        ForceKillService(serviceName, killedPids);
    }
    
    Sleep(100);
    
    MEMORYSTATUSEX memAfter;
    memAfter.dwLength = sizeof(memAfter);
    GlobalMemoryStatusEx(&memAfter);
    DWORD ramUsedAfter = (DWORD)((memAfter.ullTotalPhys - memAfter.ullAvailPhys) / 1024 / 1024);
    
    std::cout << "========================================" << std::endl;
    std::cout << "[COMPLETE] Total processes killed: " << killedPids.size() << std::endl;
    std::cout << "[RAM] Before: " << ramUsedBefore << " MB" << std::endl;
    std::cout << "[RAM] After: " << ramUsedAfter << " MB" << std::endl;
    std::cout << "[RAM] Freed: " << (int)(ramUsedBefore - ramUsedAfter) << " MB" << std::endl;
    std::cout << "========================================" << std::endl;
    
    return 0;
}

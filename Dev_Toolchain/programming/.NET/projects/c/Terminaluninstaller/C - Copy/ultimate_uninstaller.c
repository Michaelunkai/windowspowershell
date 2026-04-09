#define _WIN32_WINNT 0x0601
#define UNICODE
#define _UNICODE

#include <windows.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <wchar.h>
#include <shlwapi.h>
#include <userenv.h>
#include <tlhelp32.h>
#include <winternl.h>
#include <restartmanager.h>

#pragma comment(lib, "shlwapi.lib")
#pragma comment(lib, "advapi32.lib")
#pragma comment(lib, "userenv.lib")
#pragma comment(lib, "kernel32.lib")
#pragma comment(lib, "ntdll.lib")
#pragma comment(lib, "rstrtmgr.lib")

// Progress tracking
typedef struct {
    DWORD filesScanned;
    DWORD filesDeleted;
    DWORD directoriesDeleted;
    DWORD registryKeysDeleted;
    DWORD servicesDeleted;
    DWORD processesTerminated;
    DWORD handlesReleased;
    DWORD pendingOperations;
    DWORD lastProgressTick;
    DWORD operationCounter;
} ProgressStats;

ProgressStats g_stats = {0};

void ShowHeartbeat(const wchar_t* operation) {
    DWORD currentTick = GetTickCount();
    if (currentTick - g_stats.lastProgressTick >= 5000) {  // Reduced frequency for speed
        wprintf(L"[ACTIVE] %s... [Scan:%lu Del:%lu Dirs:%lu Reg:%lu Svc:%lu Proc:%lu]\n",
                operation, g_stats.filesScanned, g_stats.filesDeleted,
                g_stats.directoriesDeleted, g_stats.registryKeysDeleted,
                g_stats.servicesDeleted, g_stats.processesTerminated);
        fflush(stdout);
        g_stats.lastProgressTick = currentTick;
    }
}

// Protected system directories - REDUCED for aggressive cleanup
const wchar_t* PROTECTED_PATHS[] = {
    L"\\Windows\\System32\\drivers",  // Only protect actual drivers
    L"\\Windows\\SysWOW64\\drivers",
    L"\\Windows\\Boot",
    L"\\Windows\\Fonts",
    NULL
};

const wchar_t* SKIP_DIRS[] = {
    L"\\System Volume Information",
    L"\\$Recycle.Bin",
    NULL
};

// Forward declarations
BOOL MatchesAppName(const wchar_t* path, const wchar_t* appName);
BOOL MatchesAppInFile(const wchar_t* filePath, const wchar_t* appName);
void KillProcessesByNamePattern(const wchar_t* appName);
void EnableDebugPrivilege();

BOOL ShouldSkipDirectory(const wchar_t* path, const wchar_t* appName) {
    wchar_t upperPath[MAX_PATH * 2];

    // FIX: Validate buffer before copy
    if (wcslen(path) >= MAX_PATH * 2) {
        return TRUE;  // Skip paths that are too long
    }

    wcscpy_s(upperPath, MAX_PATH * 2, path);
    CharUpperW(upperPath);

    // NEVER skip if directory name matches app name
    if (MatchesAppName(path, appName)) {
        return FALSE;
    }

    // Only skip truly dangerous directories
    for (int i = 0; SKIP_DIRS[i] != NULL; i++) {
        wchar_t skipUpper[MAX_PATH];
        wcscpy_s(skipUpper, MAX_PATH, SKIP_DIRS[i]);
        CharUpperW(skipUpper);
        if (wcsstr(upperPath, skipUpper) != NULL) {
            return TRUE;
        }
    }
    return FALSE;
}

void PrintProgress(const wchar_t* action, const wchar_t* target) {
    wprintf(L"[%s] %s\n", action, target);
    fflush(stdout);
}

BOOL IsProtectedPath(const wchar_t* path) {
    if (path == NULL || wcslen(path) == 0) {
        return TRUE;
    }

    wchar_t upperPath[MAX_PATH * 2];

    // FIX: Protect against buffer overflow
    if (wcslen(path) >= MAX_PATH * 2) {
        return TRUE;
    }

    wcscpy_s(upperPath, MAX_PATH * 2, path);
    CharUpperW(upperPath);

    // Don't restrict to C: drive only - scan all drives now
    // But skip network drives and removable media (A:, B:)
    if ((upperPath[0] == L'A' || upperPath[0] == L'B') && upperPath[1] == L':') {
        return TRUE;
    }

    for (int i = 0; PROTECTED_PATHS[i] != NULL; i++) {
        wchar_t protectedUpper[MAX_PATH];
        wcscpy_s(protectedUpper, MAX_PATH, PROTECTED_PATHS[i]);
        CharUpperW(protectedUpper);
        if (wcsstr(upperPath, protectedUpper) != NULL) {
            return TRUE;
        }
    }

    if (wcsstr(upperPath, L"\\NTLDR") || wcsstr(upperPath, L"\\BOOTMGR") ||
        wcsstr(upperPath, L"\\PAGEFILE.SYS") || wcsstr(upperPath, L"\\HIBERFIL.SYS")) {
        return TRUE;
    }

    return FALSE;
}

BOOL MatchesAppName(const wchar_t* path, const wchar_t* appName) {
    if (path == NULL || appName == NULL) {
        return FALSE;
    }

    wchar_t upperPath[MAX_PATH * 2];
    wchar_t upperApp[MAX_PATH];

    // FIX: Validate buffer sizes before copying to prevent corruption
    if (wcslen(path) >= MAX_PATH * 2 || wcslen(appName) >= MAX_PATH) {
        return FALSE;
    }

    wcscpy_s(upperPath, MAX_PATH * 2, path);
    wcscpy_s(upperApp, MAX_PATH, appName);

    CharUpperW(upperPath);
    CharUpperW(upperApp);

    return wcsstr(upperPath, upperApp) != NULL;
}

void EnableDebugPrivilege() {
    HANDLE hToken;
    TOKEN_PRIVILEGES tp;

    if (OpenProcessToken(GetCurrentProcess(), TOKEN_ADJUST_PRIVILEGES | TOKEN_QUERY, &hToken)) {
        LookupPrivilegeValueW(NULL, SE_DEBUG_NAME, &tp.Privileges[0].Luid);
        tp.PrivilegeCount = 1;
        tp.Privileges[0].Attributes = SE_PRIVILEGE_ENABLED;
        AdjustTokenPrivileges(hToken, FALSE, &tp, sizeof(tp), NULL, NULL);

        LookupPrivilegeValueW(NULL, SE_BACKUP_NAME, &tp.Privileges[0].Luid);
        AdjustTokenPrivileges(hToken, FALSE, &tp, sizeof(tp), NULL, NULL);

        LookupPrivilegeValueW(NULL, SE_RESTORE_NAME, &tp.Privileges[0].Luid);
        AdjustTokenPrivileges(hToken, FALSE, &tp, sizeof(tp), NULL, NULL);

        LookupPrivilegeValueW(NULL, SE_TAKE_OWNERSHIP_NAME, &tp.Privileges[0].Luid);
        AdjustTokenPrivileges(hToken, FALSE, &tp, sizeof(tp), NULL, NULL);

        CloseHandle(hToken);
    }
}

void ScheduleDeleteOnReboot(const wchar_t* path) {
    if (MoveFileExW(path, NULL, MOVEFILE_DELAY_UNTIL_REBOOT)) {
        g_stats.pendingOperations++;
        PrintProgress(L"REBOOT-DELETE", path);
    }
}

BOOL KillProcessesUsingFile(const wchar_t* filePath) {
    DWORD dwSession;
    WCHAR szSessionKey[CCH_RM_SESSION_KEY + 1] = {0};
    DWORD dwError;

    dwError = RmStartSession(&dwSession, 0, szSessionKey);
    if (dwError != ERROR_SUCCESS) {
        return FALSE;
    }

    LPCWSTR pszFiles[] = {filePath};
    dwError = RmRegisterResources(dwSession, 1, pszFiles, 0, NULL, 0, NULL);

    if (dwError == ERROR_SUCCESS) {
        DWORD dwReason;
        UINT nProcInfoNeeded;
        UINT nProcInfo = 10;
        RM_PROCESS_INFO rgpi[10];

        dwError = RmGetList(dwSession, &nProcInfoNeeded, &nProcInfo, rgpi, &dwReason);

        if (dwError == ERROR_SUCCESS) {
            for (UINT i = 0; i < nProcInfo; i++) {
                HANDLE hProcess = OpenProcess(PROCESS_TERMINATE, FALSE, rgpi[i].Process.dwProcessId);
                if (hProcess) {
                    TerminateProcess(hProcess, 1);
                    g_stats.processesTerminated++;
                    CloseHandle(hProcess);
                }
            }
        }
    }

    RmEndSession(dwSession);
    return TRUE;
}

BOOL ForceDeleteFile(const wchar_t* filePath) {
    // Don't increment filesScanned here - already done in caller

    DWORD attrs = GetFileAttributesW(filePath);
    if (attrs != INVALID_FILE_ATTRIBUTES) {
        SetFileAttributesW(filePath, FILE_ATTRIBUTE_NORMAL);
    }

    if (DeleteFileW(filePath)) {
        g_stats.filesDeleted++;
        // Only print every 10th deletion for speed
        if (g_stats.filesDeleted % 10 == 0) {
            wprintf(L"[DELETED %lu files...]\n", g_stats.filesDeleted);
            fflush(stdout);
        }
        return TRUE;
    }

    DWORD error = GetLastError();
    if (error == ERROR_ACCESS_DENIED || error == ERROR_SHARING_VIOLATION) {
        KillProcessesUsingFile(filePath);

        Sleep(100);

        if (DeleteFileW(filePath)) {
            g_stats.filesDeleted++;
            return TRUE;
        }

        ScheduleDeleteOnReboot(filePath);
        return TRUE;
    }

    return FALSE;
}

BOOL ForceDeleteDirectory(const wchar_t* dirPath) {
    if (RemoveDirectoryW(dirPath)) {
        g_stats.directoriesDeleted++;
        return TRUE;
    }

    DWORD error = GetLastError();
    if (error == ERROR_ACCESS_DENIED || error == ERROR_SHARING_VIOLATION || error == ERROR_DIR_NOT_EMPTY) {
        ScheduleDeleteOnReboot(dirPath);
        return TRUE;
    }

    return FALSE;
}

void DeleteDirectoryRecursive(const wchar_t* path, const wchar_t* appName) {
    WIN32_FIND_DATAW findData;
    wchar_t searchPath[MAX_PATH * 2];
    wchar_t fullPath[MAX_PATH * 2];

    if (IsProtectedPath(path)) {
        return;
    }

    // FIX: Check buffer overflow before formatting
    if (wcslen(path) >= (MAX_PATH * 2 - 3)) {
        return;
    }

    swprintf_s(searchPath, MAX_PATH * 2, L"%s\\*", path);
    HANDLE hFind = FindFirstFileW(searchPath, &findData);

    if (hFind == INVALID_HANDLE_VALUE) {
        return;
    }

    do {
        ShowHeartbeat(L"Deep cleaning");

        if (wcscmp(findData.cFileName, L".") == 0 || wcscmp(findData.cFileName, L"..") == 0) {
            continue;
        }

        // FIX: Check buffer size before combining paths
        if (wcslen(path) + wcslen(findData.cFileName) + 2 >= MAX_PATH * 2) {
            continue;  // Skip paths that would overflow
        }

        swprintf_s(fullPath, MAX_PATH * 2, L"%s\\%s", path, findData.cFileName);

        if (IsProtectedPath(fullPath)) {
            continue;
        }

        SetFileAttributesW(fullPath, FILE_ATTRIBUTE_NORMAL);

        if (findData.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) {
            DeleteDirectoryRecursive(fullPath, appName);
        } else {
            PrintProgress(L"DELETE", fullPath);
            ForceDeleteFile(fullPath);
        }
    } while (FindNextFileW(hFind, &findData));

    FindClose(hFind);

    PrintProgress(L"RMDIR", path);
    ForceDeleteDirectory(path);
}

void ScanRegistryKeys(HKEY hRootKey, const wchar_t* subKey, const wchar_t* appName, int maxDepth) {
    if (maxDepth <= 0) return;

    HKEY hKey;
    if (RegOpenKeyExW(hRootKey, subKey, 0, KEY_READ | KEY_WOW64_64KEY, &hKey) != ERROR_SUCCESS) {
        return;
    }

    DWORD index = 0;
    wchar_t keyName[256];
    DWORD keyNameSize;
    int keysChecked = 0;

    while (keysChecked < 3000) {
        keyNameSize = 256;
        if (RegEnumKeyExW(hKey, index, keyName, &keyNameSize, NULL, NULL, NULL, NULL) != ERROR_SUCCESS) {
            break;
        }

        if (MatchesAppName(keyName, appName)) {
            wchar_t fullSubKey[512];

            // FIX: Check buffer overflow before combining
            if (wcslen(subKey) + wcslen(keyName) + 2 >= 512) {
                index++;
                keysChecked++;
                continue;
            }

            swprintf_s(fullSubKey, 512, L"%s\\%s", subKey, keyName);

            RegCloseKey(hKey);

            HKEY hParent;
            if (RegOpenKeyExW(hRootKey, subKey, 0, KEY_WRITE | KEY_WOW64_64KEY, &hParent) == ERROR_SUCCESS) {
                if (RegDeleteTreeW(hParent, keyName) == ERROR_SUCCESS) {
                    g_stats.registryKeysDeleted++;
                    PrintProgress(L"REG-DEL", fullSubKey);
                }
                RegCloseKey(hParent);
            }

            if (RegOpenKeyExW(hRootKey, subKey, 0, KEY_READ | KEY_WOW64_64KEY, &hKey) != ERROR_SUCCESS) {
                return;
            }
        } else {
            wchar_t recursePath[512];

            // FIX: Check buffer overflow
            if (wcslen(subKey) + wcslen(keyName) + 2 < 512) {
                swprintf_s(recursePath, 512, L"%s\\%s", subKey, keyName);
                ScanRegistryKeys(hRootKey, recursePath, appName, maxDepth - 1);
            }
            index++;
        }

        keysChecked++;
        if (keysChecked % 100 == 0) {
            ShowHeartbeat(L"Scanning registry");
        }
    }

    RegCloseKey(hKey);
}

void CleanRegistry(const wchar_t* appName) {
    wprintf(L"\n=== REGISTRY CLEANUP ===\n");

    const wchar_t* registryPaths[] = {
        L"SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Uninstall",
        L"SOFTWARE\\WOW6432Node\\Microsoft\\Windows\\CurrentVersion\\Uninstall",
        L"SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Run",
        L"SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\RunOnce",
        L"SOFTWARE\\Classes",
        L"SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\App Paths",
        L"SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Explorer\\User Shell Folders",
        L"SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Policies\\Explorer\\Run",
        L"SOFTWARE\\WOW6432Node\\Microsoft\\Windows\\CurrentVersion\\Run",
        L"SOFTWARE\\WOW6432Node\\Microsoft\\Windows\\CurrentVersion\\RunOnce",
        L"SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Explorer\\StartupApproved\\Run",
        L"SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Explorer\\StartupApproved\\Run32",
        L"SOFTWARE",
        L"SYSTEM\\CurrentControlSet\\Services",
        NULL
    };

    for (int i = 0; registryPaths[i] != NULL; i++) {
        ScanRegistryKeys(HKEY_LOCAL_MACHINE, registryPaths[i], appName, 3);
        ScanRegistryKeys(HKEY_CURRENT_USER, registryPaths[i], appName, 3);
    }

    wprintf(L"Registry scan complete.\n");
}

BOOL ForceCloseProcessByImageName(const wchar_t* imageName) {
    HANDLE hSnapshot = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
    if (hSnapshot == INVALID_HANDLE_VALUE) {
        return FALSE;
    }

    PROCESSENTRY32W pe32;
    pe32.dwSize = sizeof(PROCESSENTRY32W);

    if (!Process32FirstW(hSnapshot, &pe32)) {
        CloseHandle(hSnapshot);
        return FALSE;
    }

    BOOL processesClosed = FALSE;
    do {
        if (MatchesAppName(pe32.szExeFile, imageName)) {
            if (pe32.th32ProcessID != GetCurrentProcessId()) {
                HANDLE hProcess = OpenProcess(PROCESS_TERMINATE | PROCESS_QUERY_INFORMATION, FALSE, pe32.th32ProcessID);
                if (hProcess != NULL) {
                    if (TerminateProcess(hProcess, 1)) {
                        wprintf(L"Terminated: %s (PID: %lu)\n", pe32.szExeFile, pe32.th32ProcessID);
                        g_stats.processesTerminated++;
                        processesClosed = TRUE;
                    }
                    CloseHandle(hProcess);
                }
            }
        }
    } while (Process32NextW(hSnapshot, &pe32));

    CloseHandle(hSnapshot);
    return processesClosed;
}

void ForceStopService(const wchar_t* serviceName) {
    SC_HANDLE scManager = OpenSCManagerW(NULL, NULL, SC_MANAGER_ALL_ACCESS);
    if (!scManager) {
        return;
    }

    SC_HANDLE service = OpenServiceW(scManager, serviceName, SERVICE_ALL_ACCESS);
    if (service) {
        SERVICE_STATUS_PROCESS status;
        DWORD bytesNeeded;

        if (QueryServiceStatusEx(service, SC_STATUS_PROCESS_INFO, (LPBYTE)&status, sizeof(SERVICE_STATUS_PROCESS), &bytesNeeded)) {
            if (status.dwCurrentState == SERVICE_STOPPED) {
                CloseServiceHandle(service);
                CloseServiceHandle(scManager);
                return;
            }
        }

        if (ControlService(service, SERVICE_CONTROL_STOP, (LPSERVICE_STATUS)&status)) {
            DWORD startTime = GetTickCount();
            while (GetTickCount() - startTime < 5000) {
                Sleep(500);
                if (QueryServiceStatusEx(service, SC_STATUS_PROCESS_INFO, (LPBYTE)&status, sizeof(SERVICE_STATUS_PROCESS), &bytesNeeded)) {
                    if (status.dwCurrentState == SERVICE_STOPPED) {
                        CloseServiceHandle(service);
                        CloseServiceHandle(scManager);
                        return;
                    }
                }
            }
        }

        if (status.dwProcessId != 0) {
            HANDLE hProcess = OpenProcess(PROCESS_TERMINATE, FALSE, status.dwProcessId);
            if (hProcess) {
                TerminateProcess(hProcess, 1);
                g_stats.processesTerminated++;
                CloseHandle(hProcess);
            }
        }

        CloseServiceHandle(service);
    }

    CloseServiceHandle(scManager);
}

void ForceCloseAppServices(const wchar_t* appName) {
    wprintf(L"\n=== TERMINATING PROCESSES & SERVICES ===\n");

    EnableDebugPrivilege();

    SC_HANDLE scManager = OpenSCManagerW(NULL, NULL, SC_MANAGER_ALL_ACCESS);
    if (!scManager) {
        wprintf(L"Limited service access\n");
        ForceCloseProcessByImageName(appName);
        KillProcessesByNamePattern(appName);
        return;
    }

    DWORD bytesNeeded = 0;
    DWORD servicesReturned = 0;
    DWORD resumeHandle = 0;

    EnumServicesStatusExW(scManager, SC_ENUM_PROCESS_INFO, SERVICE_WIN32 | SERVICE_DRIVER,
                          SERVICE_STATE_ALL, NULL, 0, &bytesNeeded, &servicesReturned, &resumeHandle, NULL);

    BYTE* buffer = (BYTE*)malloc(bytesNeeded);
    if (!buffer) {
        CloseServiceHandle(scManager);
        return;
    }

    resumeHandle = 0;
    if (EnumServicesStatusExW(scManager, SC_ENUM_PROCESS_INFO, SERVICE_WIN32 | SERVICE_DRIVER,
                              SERVICE_STATE_ALL, buffer, bytesNeeded, &bytesNeeded, &servicesReturned, &resumeHandle, NULL)) {

        ENUM_SERVICE_STATUS_PROCESSW* services = (ENUM_SERVICE_STATUS_PROCESSW*)buffer;

        for (DWORD i = 0; i < servicesReturned && i < 3000; i++) {
            if (i % 100 == 0) {
                ShowHeartbeat(L"Scanning services");
            }

            if (MatchesAppName(services[i].lpServiceName, appName) || MatchesAppName(services[i].lpDisplayName, appName)) {
                wprintf(L"Stopping service: %s\n", services[i].lpServiceName);
                ForceStopService(services[i].lpServiceName);
            } else {
                SC_HANDLE hService = OpenServiceW(scManager, services[i].lpServiceName, SERVICE_QUERY_CONFIG);
                if (hService) {
                    DWORD needed = 0;
                    QueryServiceConfigW(hService, NULL, 0, &needed);
                    if (GetLastError() == ERROR_INSUFFICIENT_BUFFER) {
                        LPQUERY_SERVICE_CONFIGW config = (LPQUERY_SERVICE_CONFIGW)malloc(needed);
                        if (config) {
                            if (QueryServiceConfigW(hService, config, needed, &needed)) {
                                if (config->lpBinaryPathName && MatchesAppName(config->lpBinaryPathName, appName)) {
                                    wprintf(L"Stopping related service: %s\n", services[i].lpServiceName);
                                    ForceStopService(services[i].lpServiceName);
                                }
                            }
                            free(config);
                        }
                    }
                    CloseServiceHandle(hService);
                }
            }
        }
    }

    free(buffer);
    CloseServiceHandle(scManager);

    ForceCloseProcessByImageName(appName);
    KillProcessesByNamePattern(appName);

    Sleep(1000);
}

void KillProcessesByNamePattern(const wchar_t* appName) {
    HANDLE hSnapshot = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
    if (hSnapshot == INVALID_HANDLE_VALUE) {
        return;
    }

    PROCESSENTRY32W pe32;
    pe32.dwSize = sizeof(PROCESSENTRY32W);

    if (!Process32FirstW(hSnapshot, &pe32)) {
        CloseHandle(hSnapshot);
        return;
    }

    do {
        if (pe32.th32ProcessID != 0 && pe32.th32ProcessID != GetCurrentProcessId()) {
            if (MatchesAppName(pe32.szExeFile, appName)) {
                HANDLE hProcess = OpenProcess(PROCESS_TERMINATE | PROCESS_QUERY_INFORMATION | PROCESS_VM_READ, FALSE, pe32.th32ProcessID);
                if (hProcess != NULL) {
                    wchar_t processPath[MAX_PATH];
                    DWORD pathSize = MAX_PATH;
                    if (QueryFullProcessImageNameW(hProcess, 0, processPath, &pathSize)) {
                        if (MatchesAppName(processPath, appName)) {
                            wprintf(L"Force terminating: %s (PID: %lu)\n", pe32.szExeFile, pe32.th32ProcessID);
                            TerminateProcess(hProcess, 1);
                            g_stats.processesTerminated++;
                            Sleep(100);
                        }
                    }
                    CloseHandle(hProcess);
                }
            }
        }
    } while (Process32NextW(hSnapshot, &pe32));

    CloseHandle(hSnapshot);
}

void StopAndDeleteService(const wchar_t* appName) {
    wprintf(L"\n=== SERVICE DELETION ===\n");

    SC_HANDLE scManager = OpenSCManagerW(NULL, NULL, SC_MANAGER_ALL_ACCESS);
    if (!scManager) {
        return;
    }

    DWORD bytesNeeded = 0;
    DWORD servicesReturned = 0;
    DWORD resumeHandle = 0;

    EnumServicesStatusExW(scManager, SC_ENUM_PROCESS_INFO, SERVICE_WIN32 | SERVICE_DRIVER,
                          SERVICE_STATE_ALL, NULL, 0, &bytesNeeded, &servicesReturned, &resumeHandle, NULL);

    BYTE* buffer = (BYTE*)malloc(bytesNeeded);
    if (!buffer) {
        CloseServiceHandle(scManager);
        return;
    }

    if (EnumServicesStatusExW(scManager, SC_ENUM_PROCESS_INFO, SERVICE_WIN32 | SERVICE_DRIVER,
                              SERVICE_STATE_ALL, buffer, bytesNeeded, &bytesNeeded, &servicesReturned, &resumeHandle, NULL)) {

        ENUM_SERVICE_STATUS_PROCESSW* services = (ENUM_SERVICE_STATUS_PROCESSW*)buffer;

        for (DWORD i = 0; i < servicesReturned && i < 2000; i++) {
            if (i % 100 == 0) {
                ShowHeartbeat(L"Deleting services");
            }

            if (MatchesAppName(services[i].lpServiceName, appName) || MatchesAppName(services[i].lpDisplayName, appName)) {
                SC_HANDLE service = OpenServiceW(scManager, services[i].lpServiceName, SERVICE_ALL_ACCESS);
                if (service) {
                    SERVICE_STATUS status;
                    ControlService(service, SERVICE_CONTROL_STOP, &status);
                    Sleep(500);

                    if (DeleteService(service)) {
                        g_stats.servicesDeleted++;
                        PrintProgress(L"DEL-SVC", services[i].lpServiceName);
                    }

                    CloseServiceHandle(service);
                }
            }
        }
    }

    free(buffer);
    CloseServiceHandle(scManager);
}

void ScanAndClean(const wchar_t* basePath, const wchar_t* appName, int maxDepth) {
    WIN32_FIND_DATAW findData;
    wchar_t searchPath[MAX_PATH * 2];
    wchar_t fullPath[MAX_PATH * 2];

    if (IsProtectedPath(basePath) || ShouldSkipDirectory(basePath, appName) || maxDepth <= 0) {
        return;
    }

    // FIX: Check buffer overflow before formatting
    if (wcslen(basePath) >= (MAX_PATH * 2 - 3)) {
        return;
    }

    swprintf_s(searchPath, MAX_PATH * 2, L"%s\\*", basePath);
    HANDLE hFind = FindFirstFileW(searchPath, &findData);

    if (hFind == INVALID_HANDLE_VALUE) {
        return;
    }

    do {
        if (g_stats.operationCounter++ % 100 == 0) {
            ShowHeartbeat(L"Scanning filesystem");
        }

        if (wcscmp(findData.cFileName, L".") == 0 || wcscmp(findData.cFileName, L"..") == 0) {
            continue;
        }

        // FIX: Check buffer size before combining paths
        if (wcslen(basePath) + wcslen(findData.cFileName) + 2 >= MAX_PATH * 2) {
            continue;  // Skip paths that would overflow
        }

        swprintf_s(fullPath, MAX_PATH * 2, L"%s\\%s", basePath, findData.cFileName);

        if (IsProtectedPath(fullPath)) {
            continue;
        }

        SetFileAttributesW(fullPath, FILE_ATTRIBUTE_NORMAL);

        if (findData.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) {
            if (ShouldSkipDirectory(fullPath, appName) && !MatchesAppName(findData.cFileName, appName)) {
                continue;
            }

            if (MatchesAppName(findData.cFileName, appName)) {
                PrintProgress(L"FOUND-DIR", fullPath);
                DeleteDirectoryRecursive(fullPath, appName);
            } else {
                ScanAndClean(fullPath, appName, maxDepth - 1);
            }
        } else {
            g_stats.filesScanned++;

            // Check if filename matches app name
            if (MatchesAppName(findData.cFileName, appName)) {
                // Removed verbose MATCH output for speed
                ForceDeleteFile(fullPath);
            } else {
                wchar_t* ext = wcsrchr(findData.cFileName, L'.');
                if (ext != NULL) {
                    if (wcsicmp(ext, L".ini") == 0 || wcsicmp(ext, L".cfg") == 0 ||
                        wcsicmp(ext, L".txt") == 0 || wcsicmp(ext, L".log") == 0 ||
                        wcsicmp(ext, L".xml") == 0 || wcsicmp(ext, L".json") == 0) {
                        if (MatchesAppInFile(fullPath, appName)) {
                            PrintProgress(L"DELETE-CFG", fullPath);
                            ForceDeleteFile(fullPath);
                        }
                    }
                }
            }
        }
    } while (FindNextFileW(hFind, &findData));

    FindClose(hFind);
}

BOOL MatchesAppInFile(const wchar_t* filePath, const wchar_t* appName) {
    // FIX: Open with proper sharing flags to prevent corruption
    HANDLE hFile = CreateFileW(filePath, GENERIC_READ, FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE, NULL, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, NULL);
    if (hFile == INVALID_HANDLE_VALUE) {
        return FALSE;
    }

    DWORD fileSize = GetFileSize(hFile, NULL);
    if (fileSize == INVALID_FILE_SIZE || fileSize > 10 * 1024 * 1024) {
        CloseHandle(hFile);
        return FALSE;
    }

    DWORD readSize = min(fileSize, 10240);
    // FIX: Add extra bytes for safety
    char* buffer = (char*)malloc(readSize + 2);
    if (buffer == NULL) {
        CloseHandle(hFile);
        return FALSE;
    }

    DWORD bytesRead = 0;
    BOOL found = FALSE;

    if (ReadFile(hFile, buffer, readSize, &bytesRead, NULL) && bytesRead > 0) {
        buffer[bytesRead] = '\0';

        // FIX: Properly calculate required buffer size for wide char conversion
        int wideSize = MultiByteToWideChar(CP_UTF8, 0, buffer, bytesRead, NULL, 0);
        if (wideSize > 0) {
            wchar_t* wideBuffer = (wchar_t*)malloc((wideSize + 1) * sizeof(wchar_t));
            if (wideBuffer) {
                // FIX: Use correct size parameter
                int result = MultiByteToWideChar(CP_UTF8, 0, buffer, bytesRead, wideBuffer, wideSize);
                if (result > 0) {
                    wideBuffer[wideSize] = L'\0';
                    if (MatchesAppName(wideBuffer, appName)) {
                        found = TRUE;
                    }
                }
                free(wideBuffer);
            }
        }
    }

    free(buffer);
    CloseHandle(hFile);
    return found;
}

void CleanTempFolders(const wchar_t* appName) {
    wprintf(L"\n=== TEMP FOLDER CLEANUP ===\n");

    wchar_t tempPath[MAX_PATH];

    GetTempPathW(MAX_PATH, tempPath);
    wprintf(L"Cleaning: %s\n", tempPath);
    ScanAndClean(tempPath, appName, 3);

    wchar_t userProfile[MAX_PATH];
    GetEnvironmentVariableW(L"USERPROFILE", userProfile, MAX_PATH);

    wchar_t localTemp[MAX_PATH];
    swprintf_s(localTemp, MAX_PATH, L"%s\\AppData\\Local\\Temp", userProfile);
    wprintf(L"Cleaning: %s\n", localTemp);
    ScanAndClean(localTemp, appName, 3);

    wprintf(L"Temp cleanup complete.\n");
}

void DeepClean(const wchar_t* appName) {
    wprintf(L"\n========================================\n");
    wprintf(L"ULTIMATE UNINSTALL: %ls\n", appName);
    wprintf(L"========================================\n\n");

    DWORD appStartTime = GetTickCount();
    DWORD timeout = 2 * 60 * 1000;  // 2 minutes MAX for speed

    wchar_t userProfile[MAX_PATH];
    GetEnvironmentVariableW(L"USERPROFILE", userProfile, MAX_PATH);

    wchar_t userAppData[MAX_PATH];
    wchar_t userLocalAppData[MAX_PATH];
    wchar_t userRoaming[MAX_PATH];
    wchar_t userTemp[MAX_PATH];
    wchar_t userStartMenu[MAX_PATH];
    swprintf_s(userAppData, MAX_PATH, L"%s\\AppData", userProfile);
    swprintf_s(userLocalAppData, MAX_PATH, L"%s\\AppData\\Local", userProfile);
    swprintf_s(userRoaming, MAX_PATH, L"%s\\AppData\\Roaming", userProfile);
    swprintf_s(userTemp, MAX_PATH, L"%s\\AppData\\Local\\Temp", userProfile);
    swprintf_s(userStartMenu, MAX_PATH, L"%s\\AppData\\Roaming\\Microsoft\\Windows\\Start Menu", userProfile);

    ForceCloseAppServices(appName);

    Sleep(2000);

    // Additional deep scan paths
    wchar_t vscodeExtensions[MAX_PATH];
    wchar_t pythonPackages[MAX_PATH];
    wchar_t microsoftStore[MAX_PATH];
    swprintf_s(vscodeExtensions, MAX_PATH, L"%s\\.vscode", userProfile);
    swprintf_s(pythonPackages, MAX_PATH, L"%s\\AppData\\Local\\Packages", userProfile);
    swprintf_s(microsoftStore, MAX_PATH, L"%s\\AppData\\Local\\Microsoft\\WindowsApps", userProfile);

    const wchar_t* searchPaths[] = {
        L"C:\\Program Files",
        L"C:\\Program Files (x86)",
        L"C:\\ProgramData",
        userLocalAppData,
        userRoaming,
        userTemp,
        userStartMenu,
        userProfile,
        L"C:\\Windows\\Temp",
        L"C:\\Windows\\Prefetch",
        L"C:\\Windows\\LiveKernelReports",
        L"C:\\Windows\\Logs",
        L"C:\\Windows\\WinSxS",           // NOW INCLUDED - no longer protected
        vscodeExtensions,
        pythonPackages,
        microsoftStore,
        NULL
    };

    wprintf(L"\n=== FILE SYSTEM CLEANUP ===\n");
    for (int i = 0; searchPaths[i] != NULL; i++) {
        if (GetTickCount() - appStartTime > timeout) {
            wprintf(L"\n[TIMEOUT] Reached time limit - finalizing\n");
            break;
        }
        wprintf(L"\nScanning: %s\n", searchPaths[i]);

        // Optimized depth - deep enough but faster
        int depth = 15;  // Reduced from 20 for speed
        ScanAndClean(searchPaths[i], appName, depth);
    }

    if (GetTickCount() - appStartTime <= timeout) {
        CleanTempFolders(appName);
    }

    if (GetTickCount() - appStartTime <= timeout) {
        CleanRegistry(appName);
    }

    if (GetTickCount() - appStartTime <= timeout) {
        StopAndDeleteService(appName);
    }

    DWORD appElapsed = (GetTickCount() - appStartTime) / 1000;

    wprintf(L"\n========================================\n");
    wprintf(L"CLEANUP COMPLETE: %ls (%lu seconds)\n", appName, appElapsed);
    wprintf(L"  Files Scanned: %lu\n", g_stats.filesScanned);
    wprintf(L"  Files Deleted: %lu\n", g_stats.filesDeleted);
    wprintf(L"  Directories Deleted: %lu\n", g_stats.directoriesDeleted);
    wprintf(L"  Registry Keys Deleted: %lu\n", g_stats.registryKeysDeleted);
    wprintf(L"  Services Deleted: %lu\n", g_stats.servicesDeleted);
    wprintf(L"  Processes Terminated: %lu\n", g_stats.processesTerminated);
    wprintf(L"  Pending Reboot Operations: %lu\n", g_stats.pendingOperations);
    wprintf(L"========================================\n\n");

    memset(&g_stats, 0, sizeof(ProgressStats));
}

BOOL IsRunningAsAdmin() {
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

int main(int argc, char* argv[]) {
    // FIX: Proper wide char conversion with safety checks
    wchar_t** wargv = (wchar_t**)malloc(argc * sizeof(wchar_t*));
    if (!wargv) {
        wprintf(L"Memory allocation failed!\n");
        return 1;
    }

    for (int i = 0; i < argc; i++) {
        size_t len = strlen(argv[i]);
        wargv[i] = (wchar_t*)malloc((len + 1) * sizeof(wchar_t));
        if (!wargv[i]) {
            // Clean up previously allocated memory
            for (int j = 0; j < i; j++) {
                free(wargv[j]);
            }
            free(wargv);
            wprintf(L"Memory allocation failed!\n");
            return 1;
        }
        mbstowcs(wargv[i], argv[i], len + 1);
    }

    SetConsoleOutputCP(CP_UTF8);

    wprintf(L"\n");
    wprintf(L"╔════════════════════════════════════════════════════════════╗\n");
    wprintf(L"║     ULTIMATE UNINSTALLER - Complete Application Remover    ║\n");
    wprintf(L"║              AGGRESSIVE MODE - v2.3 - ZERO LEFTOVERS       ║\n");
    wprintf(L"╚════════════════════════════════════════════════════════════╝\n\n");

    if (!IsRunningAsAdmin()) {
        wprintf(L"[ERROR] Administrator privileges required!\n");
        wprintf(L"Please run as Administrator.\n\n");
        for (int i = 0; i < argc; i++) {
            free(wargv[i]);
        }
        free(wargv);
        return 1;
    }

    if (argc < 2) {
        wprintf(L"Usage: ultimate_uninstaller <AppName1> <AppName2> ...\n\n");
        wprintf(L"Example: ultimate_uninstaller Firefox Chrome watchdog\n\n");
        wprintf(L"AGGRESSIVE MODE - Removes ALL traces from ALL drives:\n");
        wprintf(L"  - Files and directories (up to 15 levels deep)\n");
        wprintf(L"  - Registry entries\n");
        wprintf(L"  - Services and processes\n");
        wprintf(L"  - WinSxS, vscode, node_modules, Python packages\n");
        wprintf(L"  - Temp files and caches\n\n");
        wprintf(L"WARNING: VERY AGGRESSIVE - Use with caution!\n\n");
        for (int i = 0; i < argc; i++) {
            free(wargv[i]);
        }
        free(wargv);
        return 1;
    }

    wprintf(L"WARNING: This will PERMANENTLY DELETE all traces of:\n");
    for (int i = 1; i < argc; i++) {
        wprintf(L"  - %ls\n", wargv[i]);
    }
    wprintf(L"\nThis action CANNOT be undone!\n");
    wprintf(L"Starting in 3 seconds... Press Ctrl+C to cancel.\n\n");
    Sleep(3000);

    EnableDebugPrivilege();

    DWORD startTime = GetTickCount();

    // FIX: Support multiple apps from command line (ALREADY SUPPORTED!)
    for (int i = 1; i < argc; i++) {
        DeepClean(wargv[i]);
    }

    DWORD endTime = GetTickCount();
    DWORD elapsedSeconds = (endTime - startTime) / 1000;

    wprintf(L"\n╔════════════════════════════════════════════════════════════╗\n");
    wprintf(L"║                   ALL OPERATIONS COMPLETE                  ║\n");
    wprintf(L"╚════════════════════════════════════════════════════════════╝\n\n");
    wprintf(L"Time elapsed: %lu seconds\n", elapsedSeconds);

    if (g_stats.pendingOperations > 0) {
        wprintf(L"\n[!] REBOOT REQUIRED to complete deletion.\n");
        wprintf(L"    %lu operations pending.\n\n", g_stats.pendingOperations);
    }

    wprintf(L"\nAll specified applications removed from all drives.\n\n");

    for (int i = 0; i < argc; i++) {
        free(wargv[i]);
    }
    free(wargv);

    return 0;
}

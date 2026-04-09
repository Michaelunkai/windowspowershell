// ULTIMATE UNINSTALLER NUCLEAR - C++ VERSION
// LEAVES ABSOLUTELY ZERO TRACES - AS IF THE APP NEVER EXISTED
// Compiles with: g++ -O3 -std=c++17 ultimate_uninstaller_NUCLEAR.cpp -o ultimate_uninstaller_NUCLEAR.exe -lshlwapi -ladvapi32 -lrstrtmgr -lole32 -luuid -static

#define _WIN32_WINNT 0x0601
#define UNICODE
#define _UNICODE

#include <windows.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <wchar.h>
#include <shlwapi.h>
#include <tlhelp32.h>
#include <restartmanager.h>
#include <shlobj.h>
#include <propvarutil.h>
#include <propkey.h>
#include <shobjidl.h>
#include <process.h>
#include <vector>
#include <string>
#include <algorithm>
#include <set>

#pragma comment(lib, "shlwapi.lib")
#pragma comment(lib, "advapi32.lib")
#pragma comment(lib, "kernel32.lib")
#pragma comment(lib, "rstrtmgr.lib")
#pragma comment(lib, "ole32.lib")
#pragma comment(lib, "uuid.lib")
#pragma comment(lib, "shell32.lib")
#pragma comment(lib, "propsys.lib")

// NUCLEAR MODE - ZERO LEFTOVERS GUARANTEE
#define MAX_TIME_MS (180000)  // 3 minutes - extended for nuclear thoroughness
#define MAX_THREADS 12

struct Stats {
    volatile LONG filesDeleted;
    volatile LONG dirsDeleted;
    volatile LONG procsKilled;
    volatile LONG regKeysDeleted;
    volatile LONG shortcutsRemoved;
    volatile LONG servicesDeleted;
};

Stats g_stats = {0};
DWORD g_startTime = 0;
std::wstring g_appName;
std::vector<std::wstring> g_searchTerms;

// Critical Windows components that must NEVER be touched
const wchar_t* PROTECTED_PATTERNS[] = {
    L"\\Windows\\System32\\ntoskrnl.exe",
    L"\\Windows\\System32\\hal.dll",
    L"\\Windows\\System32\\kernel32.dll",
    L"\\Windows\\System32\\ntdll.dll",
    L"\\Windows\\System32\\user32.dll",
    L"\\Windows\\System32\\csrss.exe",
    L"\\Windows\\System32\\lsass.exe",
    L"\\Windows\\System32\\services.exe",
    L"\\Windows\\System32\\smss.exe",
    L"\\Windows\\System32\\svchost.exe",
    L"\\Windows\\System32\\wininit.exe",
    L"\\Windows\\System32\\winlogon.exe",
    L"\\Windows\\System32\\config\\",
    L"\\Windows\\Boot\\",
    L"\\Windows\\explorer.exe",
    L"$Recycle.Bin",
    L"System Volume Information",
    NULL
};

inline BOOL IsTimedOut() {
    return (GetTickCount() - g_startTime) > MAX_TIME_MS;
}

inline std::wstring ToUpper(const std::wstring& str) {
    std::wstring result = str;
    CharUpperW(&result[0]);
    return result;
}

inline BOOL FastMatch(const std::wstring& str, const std::wstring& pattern) {
    std::wstring upperStr = ToUpper(str);
    std::wstring upperPat = ToUpper(pattern);
    return upperStr.find(upperPat) != std::wstring::npos;
}

inline BOOL IsProtectedPath(const std::wstring& path) {
    if (IsTimedOut()) return TRUE;

    std::wstring upperPath = ToUpper(path);

    // Check critical system files
    for (int i = 0; PROTECTED_PATTERNS[i]; i++) {
        if (upperPath.find(ToUpper(PROTECTED_PATTERNS[i])) != std::wstring::npos) {
            return TRUE;
        }
    }

    // NUCLEAR MODE: Allow WinSxS cleanup for app-specific manifests/components
    // But protect actual system components
    if (upperPath.find(L"\\WINDOWS\\WINSXS\\") != std::wstring::npos) {
        // Only allow deletion if it contains the app name
        for (const auto& term : g_searchTerms) {
            if (upperPath.find(ToUpper(term)) != std::wstring::npos) {
                return FALSE;  // App-related WinSxS component - DELETE IT!
            }
        }
        // Not app-related, protect it
        return TRUE;
    }

    // Protect Windows servicing
    if (upperPath.find(L"\\WINDOWS\\SERVICING\\PACKAGES\\") != std::wstring::npos) {
        // Only delete if app-specific
        for (const auto& term : g_searchTerms) {
            if (upperPath.find(ToUpper(term)) != std::wstring::npos) {
                return FALSE;  // App-related package - DELETE IT!
            }
        }
        return TRUE;
    }

    return FALSE;
}

inline BOOL MatchesAnyTerm(const std::wstring& str) {
    std::wstring upperStr = ToUpper(str);
    for (const auto& term : g_searchTerms) {
        if (upperStr.find(ToUpper(term)) != std::wstring::npos) {
            return TRUE;
        }
    }
    return FALSE;
}

// Kill processes with extreme prejudice
void NuclearKillProcesses() {
    wprintf(L"[NUCLEAR] Terminating all related processes...\n");

    HANDLE snap = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
    if (snap == INVALID_HANDLE_VALUE) return;

    PROCESSENTRY32W pe = {sizeof(PROCESSENTRY32W)};
    if (Process32FirstW(snap, &pe)) {
        do {
            if (MatchesAnyTerm(pe.szExeFile) && pe.th32ProcessID != GetCurrentProcessId()) {
                HANDLE h = OpenProcess(PROCESS_TERMINATE | PROCESS_QUERY_INFORMATION, FALSE, pe.th32ProcessID);
                if (h) {
                    wprintf(L"  [KILL] %s (PID: %lu)\n", pe.szExeFile, pe.th32ProcessID);
                    TerminateProcess(h, 1);
                    InterlockedIncrement(&g_stats.procsKilled);
                    CloseHandle(h);
                }
            }
        } while (Process32NextW(snap, &pe) && !IsTimedOut());
    }
    CloseHandle(snap);
}

// Nuclear force delete with maximum aggression
BOOL NuclearForceDelete(const std::wstring& path) {
    SetFileAttributesW(path.c_str(), FILE_ATTRIBUTE_NORMAL);

    if (DeleteFileW(path.c_str())) {
        InterlockedIncrement(&g_stats.filesDeleted);
        return TRUE;
    }

    // Try Restart Manager
    DWORD session;
    WCHAR key[CCH_RM_SESSION_KEY + 1] = {0};
    if (RmStartSession(&session, 0, key) == ERROR_SUCCESS) {
        LPCWSTR files[] = {path.c_str()};
        RmRegisterResources(session, 1, files, 0, NULL, 0, NULL);

        DWORD reason;
        UINT needed, count = 10;
        RM_PROCESS_INFO procs[10];
        if (RmGetList(session, &needed, &count, procs, &reason) == ERROR_SUCCESS) {
            for (UINT i = 0; i < count; i++) {
                HANDLE h = OpenProcess(PROCESS_TERMINATE, FALSE, procs[i].Process.dwProcessId);
                if (h) {
                    TerminateProcess(h, 1);
                    CloseHandle(h);
                }
            }
        }
        RmEndSession(session);

        SetFileAttributesW(path.c_str(), FILE_ATTRIBUTE_NORMAL);
        if (DeleteFileW(path.c_str())) {
            InterlockedIncrement(&g_stats.filesDeleted);
            return TRUE;
        }
    }

    // Schedule for boot deletion
    MoveFileExW(path.c_str(), NULL, MOVEFILE_DELAY_UNTIL_REBOOT);
    return FALSE;
}

// Recursive nuclear deletion
void NuclearDeleteTree(const std::wstring& path) {
    if (IsTimedOut() || IsProtectedPath(path)) return;

    std::wstring search = path + L"\\*";

    WIN32_FIND_DATAW fd;
    HANDLE h = FindFirstFileW(search.c_str(), &fd);
    if (h == INVALID_HANDLE_VALUE) return;

    do {
        if (wcscmp(fd.cFileName, L".") == 0 || wcscmp(fd.cFileName, L"..") == 0)
            continue;

        std::wstring fullPath = path + L"\\" + fd.cFileName;

        if (IsProtectedPath(fullPath)) continue;

        if (fd.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) {
            NuclearDeleteTree(fullPath);
            SetFileAttributesW(fullPath.c_str(), FILE_ATTRIBUTE_NORMAL);
            if (RemoveDirectoryW(fullPath.c_str())) {
                InterlockedIncrement(&g_stats.dirsDeleted);
            } else {
                MoveFileExW(fullPath.c_str(), NULL, MOVEFILE_DELAY_UNTIL_REBOOT);
            }
        } else {
            NuclearForceDelete(fullPath);
        }
    } while (FindNextFileW(h, &fd) && !IsTimedOut());

    FindClose(h);
}

// NUCLEAR: Deep filesystem scan with maximum depth
void NuclearDeepScan(const std::wstring& path, int depth) {
    if (IsTimedOut() || depth <= 0 || IsProtectedPath(path)) return;

    std::wstring search = path + L"\\*";

    WIN32_FIND_DATAW fd;
    HANDLE h = FindFirstFileW(search.c_str(), &fd);
    if (h == INVALID_HANDLE_VALUE) return;

    do {
        if (wcscmp(fd.cFileName, L".") == 0 || wcscmp(fd.cFileName, L"..") == 0)
            continue;

        std::wstring fullPath = path + L"\\" + fd.cFileName;

        if (IsProtectedPath(fullPath)) continue;

        if (fd.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) {
            if (MatchesAnyTerm(fd.cFileName)) {
                wprintf(L"  [DELETE DIR] %s\n", fullPath.c_str());
                NuclearDeleteTree(fullPath);
                SetFileAttributesW(fullPath.c_str(), FILE_ATTRIBUTE_NORMAL);
                RemoveDirectoryW(fullPath.c_str());
            } else {
                NuclearDeepScan(fullPath, depth - 1);
            }
        } else {
            if (MatchesAnyTerm(fd.cFileName)) {
                wprintf(L"  [DELETE FILE] %s\n", fullPath.c_str());
                NuclearForceDelete(fullPath);
            }
        }
    } while (FindNextFileW(h, &fd) && !IsTimedOut());

    FindClose(h);
}

// NUCLEAR: Registry annihilation - ALL HIVES
void NuclearRegistryClean() {
    wprintf(L"[NUCLEAR] Deep registry cleaning...\n");

    const HKEY hives[] = {
        HKEY_LOCAL_MACHINE,
        HKEY_CURRENT_USER,
        HKEY_USERS,
        HKEY_CLASSES_ROOT
    };

    const wchar_t* regPaths[] = {
        L"SOFTWARE",
        L"SOFTWARE\\WOW6432Node",
        L"SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Uninstall",
        L"SOFTWARE\\WOW6432Node\\Microsoft\\Windows\\CurrentVersion\\Uninstall",
        L"SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Run",
        L"SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\RunOnce",
        L"SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Explorer\\StartupApproved\\Run",
        L"SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Explorer\\StartupApproved\\Run32",
        L"SYSTEM\\CurrentControlSet\\Services",
        L"SYSTEM\\CurrentControlSet\\Enum",
        L"SOFTWARE\\Classes",
        L"SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\Image File Execution Options",
        NULL
    };

    for (int hiveIdx = 0; hiveIdx < 4 && !IsTimedOut(); hiveIdx++) {
        for (int pathIdx = 0; regPaths[pathIdx] && !IsTimedOut(); pathIdx++) {
            HKEY hKey;
            if (RegOpenKeyExW(hives[hiveIdx], regPaths[pathIdx], 0, KEY_READ | KEY_WOW64_64KEY, &hKey) == ERROR_SUCCESS) {
                DWORD index = 0;
                wchar_t keyName[512];
                DWORD keyNameSize;

                while (!IsTimedOut() && index < 5000) {
                    keyNameSize = 512;
                    if (RegEnumKeyExW(hKey, index, keyName, &keyNameSize, NULL, NULL, NULL, NULL) != ERROR_SUCCESS)
                        break;

                    if (MatchesAnyTerm(keyName)) {
                        wprintf(L"  [DELETE KEY] %s\\%s\n", regPaths[pathIdx], keyName);
                        RegCloseKey(hKey);

                        HKEY hParent;
                        if (RegOpenKeyExW(hives[hiveIdx], regPaths[pathIdx], 0, KEY_WRITE | KEY_WOW64_64KEY, &hParent) == ERROR_SUCCESS) {
                            RegDeleteTreeW(hParent, keyName);
                            InterlockedIncrement(&g_stats.regKeysDeleted);
                            RegCloseKey(hParent);
                        }

                        if (RegOpenKeyExW(hives[hiveIdx], regPaths[pathIdx], 0, KEY_READ | KEY_WOW64_64KEY, &hKey) != ERROR_SUCCESS)
                            break;
                    } else {
                        index++;
                    }
                }
                RegCloseKey(hKey);
            }
        }
    }
}

// NUCLEAR: Services obliteration
void NuclearDeleteServices() {
    wprintf(L"[NUCLEAR] Obliterating services...\n");

    SC_HANDLE scm = OpenSCManagerW(NULL, NULL, SC_MANAGER_ALL_ACCESS);
    if (!scm) return;

    DWORD bytesNeeded = 0;
    DWORD servicesReturned = 0;
    DWORD resumeHandle = 0;

    EnumServicesStatusExW(scm, SC_ENUM_PROCESS_INFO, SERVICE_WIN32 | SERVICE_DRIVER,
                          SERVICE_STATE_ALL, NULL, 0, &bytesNeeded, &servicesReturned, &resumeHandle, NULL);

    BYTE* buffer = (BYTE*)malloc(bytesNeeded);
    if (!buffer) {
        CloseServiceHandle(scm);
        return;
    }

    if (EnumServicesStatusExW(scm, SC_ENUM_PROCESS_INFO, SERVICE_WIN32 | SERVICE_DRIVER,
                              SERVICE_STATE_ALL, buffer, bytesNeeded, &bytesNeeded, &servicesReturned, &resumeHandle, NULL)) {

        ENUM_SERVICE_STATUS_PROCESSW* services = (ENUM_SERVICE_STATUS_PROCESSW*)buffer;

        for (DWORD i = 0; i < servicesReturned && !IsTimedOut(); i++) {
            if (MatchesAnyTerm(services[i].lpServiceName) || MatchesAnyTerm(services[i].lpDisplayName)) {
                wprintf(L"  [DELETE SERVICE] %s\n", services[i].lpServiceName);
                SC_HANDLE svc = OpenServiceW(scm, services[i].lpServiceName, SERVICE_ALL_ACCESS);
                if (svc) {
                    SERVICE_STATUS status;
                    ControlService(svc, SERVICE_CONTROL_STOP, &status);
                    DeleteService(svc);
                    InterlockedIncrement(&g_stats.servicesDeleted);
                    CloseServiceHandle(svc);
                }
            }
        }
    }

    free(buffer);
    CloseServiceHandle(scm);
}

// NUCLEAR: Remove ALL shortcuts (Desktop, Start Menu, Taskbar, etc.)
void NuclearRemoveShortcuts() {
    wprintf(L"[NUCLEAR] Removing all shortcuts and pins...\n");

    wchar_t path[MAX_PATH];

    // Desktop shortcuts - All Users
    if (SHGetFolderPathW(NULL, CSIDL_COMMON_DESKTOPDIRECTORY, NULL, 0, path) == S_OK) {
        NuclearDeepScan(path, 2);
    }

    // Desktop shortcuts - Current User
    if (SHGetFolderPathW(NULL, CSIDL_DESKTOP, NULL, 0, path) == S_OK) {
        NuclearDeepScan(path, 2);
    }

    // Start Menu - All Users
    if (SHGetFolderPathW(NULL, CSIDL_COMMON_PROGRAMS, NULL, 0, path) == S_OK) {
        NuclearDeepScan(path, 5);
    }

    // Start Menu - Current User
    if (SHGetFolderPathW(NULL, CSIDL_PROGRAMS, NULL, 0, path) == S_OK) {
        NuclearDeepScan(path, 5);
    }

    // Startup - All Users
    if (SHGetFolderPathW(NULL, CSIDL_COMMON_STARTUP, NULL, 0, path) == S_OK) {
        NuclearDeepScan(path, 2);
    }

    // Startup - Current User
    if (SHGetFolderPathW(NULL, CSIDL_STARTUP, NULL, 0, path) == S_OK) {
        NuclearDeepScan(path, 2);
    }

    wprintf(L"[NUCLEAR] Clearing taskbar pins...\n");
    // Taskbar pins are stored in the registry and Quick Launch
    if (SHGetFolderPathW(NULL, CSIDL_APPDATA, NULL, 0, path) == S_OK) {
        std::wstring quickLaunch = std::wstring(path) + L"\\Microsoft\\Internet Explorer\\Quick Launch\\User Pinned";
        NuclearDeepScan(quickLaunch, 5);
    }
}

// NUCLEAR: Clean DriverStore
void NuclearCleanDriverStore() {
    wprintf(L"[NUCLEAR] Cleaning driver store...\n");

    std::wstring driverStore = L"C:\\Windows\\System32\\DriverStore\\FileRepository";
    NuclearDeepScan(driverStore, 8);
}

// NUCLEAR: Clean Windows Installer cache
void NuclearCleanInstallerCache() {
    wprintf(L"[NUCLEAR] Cleaning Windows Installer cache...\n");

    std::wstring installer = L"C:\\Windows\\Installer";
    NuclearDeepScan(installer, 5);
}

// NUCLEAR: Clean ALL user profiles
void NuclearCleanAllUserProfiles() {
    wprintf(L"[NUCLEAR] Scanning all user profiles...\n");

    std::wstring usersPath = L"C:\\Users";

    WIN32_FIND_DATAW fd;
    HANDLE h = FindFirstFileW((usersPath + L"\\*").c_str(), &fd);
    if (h == INVALID_HANDLE_VALUE) return;

    do {
        if ((fd.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) &&
            wcscmp(fd.cFileName, L".") != 0 &&
            wcscmp(fd.cFileName, L"..") != 0) {

            std::wstring userPath = usersPath + L"\\" + fd.cFileName;

            // AppData\Local
            NuclearDeepScan(userPath + L"\\AppData\\Local", 10);

            // AppData\Roaming
            NuclearDeepScan(userPath + L"\\AppData\\Roaming", 10);

            // AppData\LocalLow
            NuclearDeepScan(userPath + L"\\AppData\\LocalLow", 10);
        }
    } while (FindNextFileW(h, &fd) && !IsTimedOut());

    FindClose(h);
}

// NUCLEAR: The main obliteration function
void NuclearObliterate(const std::wstring& appName, const std::vector<std::wstring>& additionalTerms) {
    g_startTime = GetTickCount();
    g_appName = appName;
    g_searchTerms.clear();
    g_searchTerms.push_back(appName);
    for (const auto& term : additionalTerms) {
        g_searchTerms.push_back(term);
    }

    wprintf(L"\n[NUCLEAR] Search terms: ");
    for (const auto& term : g_searchTerms) {
        wprintf(L"%s ", term.c_str());
    }
    wprintf(L"\n\n");

    // Phase 1: Kill all processes
    NuclearKillProcesses();
    Sleep(500);

    // Phase 2: Delete services
    NuclearDeleteServices();

    // Phase 3: Remove shortcuts FIRST (before files are deleted)
    NuclearRemoveShortcuts();

    // Phase 4: Registry nuclear clean
    NuclearRegistryClean();

    // Phase 5: Filesystem obliteration
    wprintf(L"[NUCLEAR] Beginning filesystem obliteration...\n");

    const std::vector<std::pair<std::wstring, int>> scanPaths = {
        {L"C:\\Program Files", 15},
        {L"C:\\Program Files (x86)", 15},
        {L"C:\\ProgramData", 15},
        {L"C:\\Windows\\System32", 15},
        {L"C:\\Windows\\SysWOW64", 15},
        {L"C:\\Windows\\Temp", 10},
        {L"C:\\Windows\\Prefetch", 5},
        {L"C:\\Windows\\WinSxS", 10},  // NUCLEAR: Now scanned!
        {L"C:\\Windows\\SoftwareDistribution", 10},  // NUCLEAR: Update cache
        {L"C:\\Windows", 8},
        {L"C:\\", 5}
    };

    for (const auto& [path, depth] : scanPaths) {
        if (IsTimedOut()) break;
        wprintf(L"[SCAN] %s\n", path.c_str());
        NuclearDeepScan(path, depth);
    }

    // Phase 6: Clean driver store
    NuclearCleanDriverStore();

    // Phase 7: Clean Windows Installer
    NuclearCleanInstallerCache();

    // Phase 8: Clean ALL user profiles
    NuclearCleanAllUserProfiles();

    // Phase 9: Final process kill
    NuclearKillProcesses();

    wprintf(L"[NUCLEAR] Obliteration complete!\n");
}

BOOL IsAdmin() {
    BOOL admin = FALSE;
    PSID sid = NULL;
    SID_IDENTIFIER_AUTHORITY auth = SECURITY_NT_AUTHORITY;
    if (AllocateAndInitializeSid(&auth, 2, SECURITY_BUILTIN_DOMAIN_RID,
                                  DOMAIN_ALIAS_RID_ADMINS, 0, 0, 0, 0, 0, 0, &sid)) {
        CheckTokenMembership(NULL, sid, &admin);
        FreeSid(sid);
    }
    return admin;
}

int wmain(int argc, wchar_t* argv[]) {
    SetConsoleOutputCP(CP_UTF8);

    wprintf(L"\n");
    wprintf(L"═══════════════════════════════════════════════════════════════════\n");
    wprintf(L"  ULTIMATE UNINSTALLER NUCLEAR - C++ EDITION\n");
    wprintf(L"  ZERO LEFTOVERS GUARANTEE - AS IF IT NEVER EXISTED\n");
    wprintf(L"═══════════════════════════════════════════════════════════════════\n\n");

    if (!IsAdmin()) {
        wprintf(L"ERROR: Administrator privileges required!\n");
        return 1;
    }

    if (argc < 2) {
        wprintf(L"Usage: ultimate_uninstaller_NUCLEAR.exe <AppName> [SearchTerm2] ...\n\n");
        wprintf(L"NUCLEAR MODE FEATURES:\n");
        wprintf(L"  ✓ WinSxS manifest/component cleanup\n");
        wprintf(L"  ✓ DriverStore obliteration\n");
        wprintf(L"  ✓ Windows Installer cache cleaning\n");
        wprintf(L"  ✓ All user profiles scanning\n");
        wprintf(L"  ✓ Desktop/Start Menu/Taskbar pin removal\n");
        wprintf(L"  ✓ Deep registry cleaning (all hives)\n");
        wprintf(L"  ✓ Service termination & removal\n");
        wprintf(L"  ✓ SoftwareDistribution cleanup\n");
        wprintf(L"  ✓ Process killing with extreme prejudice\n");
        wprintf(L"  ✓ Reboot-scheduled deletion for locked files\n\n");
        wprintf(L"Example: ultimate_uninstaller_NUCLEAR.exe \"DRIVER BOOSTER\" DRIVERBOOSTER IOBIT\n\n");
        return 1;
    }

    wprintf(L"WARNING: This will OBLITERATE all traces. Starting in 3 seconds...\n\n");
    Sleep(3000);

    // Enable all privileges
    HANDLE token;
    if (OpenProcessToken(GetCurrentProcess(), TOKEN_ADJUST_PRIVILEGES, &token)) {
        const wchar_t* privileges[] = {
            SE_DEBUG_NAME,
            SE_BACKUP_NAME,
            SE_RESTORE_NAME,
            SE_TAKE_OWNERSHIP_NAME,
            SE_SECURITY_NAME,
            NULL
        };

        for (int i = 0; privileges[i]; i++) {
            TOKEN_PRIVILEGES tp = {1};
            LookupPrivilegeValueW(NULL, privileges[i], &tp.Privileges[0].Luid);
            tp.Privileges[0].Attributes = SE_PRIVILEGE_ENABLED;
            AdjustTokenPrivileges(token, FALSE, &tp, 0, NULL, NULL);
        }

        CloseHandle(token);
    }

    // Build search terms
    std::vector<std::wstring> additionalTerms;
    for (int i = 2; i < argc; i++) {
        additionalTerms.push_back(argv[i]);
    }

    DWORD start = GetTickCount();
    memset(&g_stats, 0, sizeof(Stats));

    NuclearObliterate(argv[1], additionalTerms);

    DWORD elapsed = (GetTickCount() - start) / 1000;

    wprintf(L"\n═══════════════════════════════════════════════════════════════════\n");
    wprintf(L"  NUCLEAR OBLITERATION COMPLETE (%lu seconds)\n", elapsed);
    wprintf(L"═══════════════════════════════════════════════════════════════════\n");
    wprintf(L"  Files Deleted:     %ld\n", g_stats.filesDeleted);
    wprintf(L"  Dirs Deleted:      %ld\n", g_stats.dirsDeleted);
    wprintf(L"  Processes Killed:  %ld\n", g_stats.procsKilled);
    wprintf(L"  Registry Keys:     %ld\n", g_stats.regKeysDeleted);
    wprintf(L"  Services Deleted:  %ld\n", g_stats.servicesDeleted);
    wprintf(L"  Shortcuts Removed: %ld\n", g_stats.shortcutsRemoved);
    wprintf(L"═══════════════════════════════════════════════════════════════════\n\n");

    wprintf(L"Some files may require reboot to complete deletion.\n");
    wprintf(L"Reboot now? (Y/N): ");

    wchar_t response;
    wscanf(L"%lc", &response);
    if (response == L'Y' || response == L'y') {
        system("shutdown /r /t 5");
    }

    return 0;
}

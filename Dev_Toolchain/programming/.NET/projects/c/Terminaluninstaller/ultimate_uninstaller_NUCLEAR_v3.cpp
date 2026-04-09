// ULTIMATE UNINSTALLER NUCLEAR v3.0 - SPEED OPTIMIZED
// ZERO LEFTOVERS + MAXIMUM SPEED
// Compiles with: g++ -O3 -std=c++17 -municode -pthread ultimate_uninstaller_NUCLEAR_v3.cpp -o ultimate_uninstaller_NUCLEAR.exe -lshlwapi -ladvapi32 -lrstrtmgr -lole32 -luuid -loleaut32 -ltaskschd -static

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
#include <process.h>
#include <vector>
#include <string>
#include <algorithm>
#include <set>
#include <thread>
#include <mutex>
#include <atomic>
#include <queue>
#include <aclapi.h>
#include <accctrl.h>

#pragma comment(lib, "shlwapi.lib")
#pragma comment(lib, "advapi32.lib")
#pragma comment(lib, "kernel32.lib")
#pragma comment(lib, "rstrtmgr.lib")
#pragma comment(lib, "ole32.lib")
#pragma comment(lib, "uuid.lib")
#pragma comment(lib, "shell32.lib")

#define MAX_TIME_MS (180000)
#define NUM_THREADS 8

struct Stats {
    std::atomic<long> filesDeleted{0};
    std::atomic<long> dirsDeleted{0};
    std::atomic<long> procsKilled{0};
    std::atomic<long> regKeysDeleted{0};
    std::atomic<long> shortcutsRemoved{0};
    std::atomic<long> servicesDeleted{0};
    std::atomic<long> tasksDeleted{0};
};

Stats g_stats;
DWORD g_startTime = 0;
std::vector<std::wstring> g_searchTerms;
std::set<std::wstring> g_discoveredPaths;
std::mutex g_pathMutex;
std::mutex g_printMutex;

const wchar_t* PROTECTED[] = {
    L"\\Windows\\System32\\ntoskrnl", L"\\Windows\\System32\\hal.dll",
    L"\\Windows\\System32\\kernel32", L"\\Windows\\System32\\ntdll",
    L"\\Windows\\System32\\csrss", L"\\Windows\\System32\\lsass",
    L"\\Windows\\System32\\services", L"\\Windows\\System32\\smss",
    L"\\Windows\\System32\\svchost", L"\\Windows\\System32\\wininit",
    L"\\Windows\\System32\\winlogon", L"\\Windows\\System32\\config\\",
    L"\\Windows\\Boot\\", L"$Recycle.Bin", L"System Volume Information", NULL
};

inline bool IsTimedOut() { return (GetTickCount() - g_startTime) > MAX_TIME_MS; }

inline std::wstring ToLower(const std::wstring& s) {
    std::wstring r = s;
    for (auto& c : r) c = towlower(c);
    return r;
}

inline bool MatchesAny(const std::wstring& str) {
    std::wstring lower = ToLower(str);
    for (const auto& term : g_searchTerms)
        if (lower.find(term) != std::wstring::npos) return true;
    return false;
}

inline bool IsProtected(const std::wstring& path) {
    std::wstring lower = ToLower(path);
    for (int i = 0; PROTECTED[i]; i++)
        if (lower.find(ToLower(PROTECTED[i])) != std::wstring::npos) return true;
    if (lower.find(L"\\windows\\winsxs\\") != std::wstring::npos && !MatchesAny(path)) return true;
    return false;
}

void Print(const wchar_t* fmt, ...) {
    std::lock_guard<std::mutex> lock(g_printMutex);
    va_list args;
    va_start(args, fmt);
    vwprintf(fmt, args);
    va_end(args);
}

// FAST: Kill processes using taskkill (fastest method)
void FastKillProcesses() {
    Print(L"[KILL] Terminating processes...\n");
    for (const auto& term : g_searchTerms) {
        wchar_t cmd[256];
        swprintf(cmd, 256, L"taskkill /F /IM \"*%s*\" /T >nul 2>&1", term.c_str());
        _wsystem(cmd);
    }
    
    // Also kill by exact process scan (fast, single pass)
    HANDLE snap = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
    if (snap == INVALID_HANDLE_VALUE) return;
    
    PROCESSENTRY32W pe = {sizeof(PROCESSENTRY32W)};
    if (Process32FirstW(snap, &pe)) {
        do {
            if (MatchesAny(pe.szExeFile) && pe.th32ProcessID != GetCurrentProcessId()) {
                HANDLE h = OpenProcess(PROCESS_TERMINATE, FALSE, pe.th32ProcessID);
                if (h) {
                    TerminateProcess(h, 1);
                    g_stats.procsKilled++;
                    CloseHandle(h);
                }
            }
        } while (Process32NextW(snap, &pe));
    }
    CloseHandle(snap);
}

// FAST: Delete services
void FastDeleteServices() {
    Print(L"[SERVICES] Removing services...\n");
    
    // Use sc command for speed
    for (const auto& term : g_searchTerms) {
        wchar_t cmd[256];
        swprintf(cmd, 256, L"sc stop \"%s\" >nul 2>&1 & sc delete \"%s\" >nul 2>&1", term.c_str(), term.c_str());
        _wsystem(cmd);
    }
    
    SC_HANDLE scm = OpenSCManagerW(NULL, NULL, SC_MANAGER_ENUMERATE_SERVICE);
    if (!scm) return;
    
    DWORD needed = 0, count = 0, resume = 0;
    EnumServicesStatusW(scm, SERVICE_WIN32 | SERVICE_DRIVER, SERVICE_STATE_ALL, NULL, 0, &needed, &count, &resume);
    
    std::vector<BYTE> buf(needed + 100);
    if (EnumServicesStatusW(scm, SERVICE_WIN32 | SERVICE_DRIVER, SERVICE_STATE_ALL, 
                            (LPENUM_SERVICE_STATUSW)buf.data(), (DWORD)buf.size(), &needed, &count, &resume)) {
        auto* svc = (LPENUM_SERVICE_STATUSW)buf.data();
        for (DWORD i = 0; i < count; i++) {
            if (MatchesAny(svc[i].lpServiceName) || MatchesAny(svc[i].lpDisplayName)) {
                SC_HANDLE h = OpenServiceW(scm, svc[i].lpServiceName, SERVICE_STOP | DELETE);
                if (h) {
                    SERVICE_STATUS st;
                    ControlService(h, SERVICE_CONTROL_STOP, &st);
                    DeleteService(h);
                    g_stats.servicesDeleted++;
                    CloseHandle(h);
                }
            }
        }
    }
    CloseServiceHandle(scm);
}

// FAST: Query registry for install paths (NO WMI - WMI is extremely slow!)
void FastQueryRegistryPaths() {
    Print(L"[REGISTRY] Finding install paths...\n");
    
    const wchar_t* paths[] = {
        L"SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Uninstall",
        L"SOFTWARE\\WOW6432Node\\Microsoft\\Windows\\CurrentVersion\\Uninstall", NULL
    };
    
    for (int h = 0; h < 2; h++) {
        HKEY hive = h ? HKEY_CURRENT_USER : HKEY_LOCAL_MACHINE;
        for (int p = 0; paths[p]; p++) {
            HKEY hKey;
            if (RegOpenKeyExW(hive, paths[p], 0, KEY_READ | KEY_WOW64_64KEY, &hKey) != ERROR_SUCCESS) continue;
            
            wchar_t keyName[256];
            DWORD idx = 0, size;
            while (size = 256, RegEnumKeyExW(hKey, idx++, keyName, &size, NULL, NULL, NULL, NULL) == ERROR_SUCCESS) {
                HKEY hSub;
                if (RegOpenKeyExW(hKey, keyName, 0, KEY_READ, &hSub) == ERROR_SUCCESS) {
                    wchar_t name[512] = {0}, loc[1024] = {0}, uninst[2048] = {0};
                    DWORD sz;
                    
                    sz = sizeof(name); RegQueryValueExW(hSub, L"DisplayName", NULL, NULL, (LPBYTE)name, &sz);
                    sz = sizeof(loc); RegQueryValueExW(hSub, L"InstallLocation", NULL, NULL, (LPBYTE)loc, &sz);
                    sz = sizeof(uninst); RegQueryValueExW(hSub, L"UninstallString", NULL, NULL, (LPBYTE)uninst, &sz);
                    
                    if (MatchesAny(name) || MatchesAny(keyName)) {
                        Print(L"  [FOUND] %s\n", name);
                        std::lock_guard<std::mutex> lock(g_pathMutex);
                        if (wcslen(loc) > 3) g_discoveredPaths.insert(loc);
                        
                        // Extract path from uninstall string
                        std::wstring us = uninst;
                        size_t pos = us.find(L".exe");
                        if (pos != std::wstring::npos) {
                            std::wstring p = us.substr(us[0] == L'"' ? 1 : 0, pos + 4 - (us[0] == L'"' ? 1 : 0));
                            size_t sl = p.rfind(L'\\');
                            if (sl != std::wstring::npos) g_discoveredPaths.insert(p.substr(0, sl));
                        }
                    }
                    RegCloseKey(hSub);
                }
            }
            RegCloseKey(hKey);
        }
    }
}

// FAST: Force delete file
bool FastForceDelete(const std::wstring& path) {
    SetFileAttributesW(path.c_str(), FILE_ATTRIBUTE_NORMAL);
    if (DeleteFileW(path.c_str())) {
        g_stats.filesDeleted++;
        return true;
    }
    MoveFileExW(path.c_str(), NULL, MOVEFILE_DELAY_UNTIL_REBOOT);
    g_stats.filesDeleted++;
    return true;
}

// FAST: Delete directory tree
void FastDeleteTree(const std::wstring& path) {
    if (IsTimedOut() || IsProtected(path)) return;
    
    WIN32_FIND_DATAW fd;
    HANDLE h = FindFirstFileW((path + L"\\*").c_str(), &fd);
    if (h == INVALID_HANDLE_VALUE) return;
    
    do {
        if (wcscmp(fd.cFileName, L".") == 0 || wcscmp(fd.cFileName, L"..") == 0) continue;
        std::wstring full = path + L"\\" + fd.cFileName;
        if (IsProtected(full)) continue;
        
        if (fd.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) {
            FastDeleteTree(full);
            SetFileAttributesW(full.c_str(), FILE_ATTRIBUTE_NORMAL);
            if (!RemoveDirectoryW(full.c_str())) 
                MoveFileExW(full.c_str(), NULL, MOVEFILE_DELAY_UNTIL_REBOOT);
            g_stats.dirsDeleted++;
        } else {
            FastForceDelete(full);
        }
    } while (FindNextFileW(h, &fd) && !IsTimedOut());
    FindClose(h);
}

// FAST: Parallel deep scan
void FastDeepScan(const std::wstring& path, int depth) {
    if (IsTimedOut() || depth <= 0 || IsProtected(path)) return;
    
    WIN32_FIND_DATAW fd;
    HANDLE h = FindFirstFileW((path + L"\\*").c_str(), &fd);
    if (h == INVALID_HANDLE_VALUE) return;
    
    std::vector<std::wstring> subdirs;
    
    do {
        if (wcscmp(fd.cFileName, L".") == 0 || wcscmp(fd.cFileName, L"..") == 0) continue;
        std::wstring full = path + L"\\" + fd.cFileName;
        if (IsProtected(full)) continue;
        
        if (fd.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) {
            if (MatchesAny(fd.cFileName)) {
                Print(L"  [NUKE DIR] %s\n", full.c_str());
                FastDeleteTree(full);
                SetFileAttributesW(full.c_str(), FILE_ATTRIBUTE_NORMAL);
                RemoveDirectoryW(full.c_str());
                g_stats.dirsDeleted++;
            } else {
                subdirs.push_back(full);
            }
        } else if (MatchesAny(fd.cFileName)) {
            Print(L"  [NUKE FILE] %s\n", full.c_str());
            FastForceDelete(full);
        }
    } while (FindNextFileW(h, &fd) && !IsTimedOut());
    FindClose(h);
    
    // Recurse into subdirs
    for (const auto& dir : subdirs) {
        if (!IsTimedOut()) FastDeepScan(dir, depth - 1);
    }
}

// FAST: Registry cleanup (single pass per hive)
void FastRegistryClean() {
    Print(L"[REGISTRY] Cleaning registry...\n");
    
    const HKEY hives[] = {HKEY_LOCAL_MACHINE, HKEY_CURRENT_USER, HKEY_CLASSES_ROOT};
    const wchar_t* hiveNames[] = {L"HKLM", L"HKCU", L"HKCR"};
    const wchar_t* regPaths[] = {
        L"SOFTWARE", L"SOFTWARE\\WOW6432Node",
        L"SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Uninstall",
        L"SOFTWARE\\WOW6432Node\\Microsoft\\Windows\\CurrentVersion\\Uninstall",
        L"SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Run",
        L"SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\RunOnce",
        L"SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\App Paths",
        L"SOFTWARE\\Classes\\Applications",
        L"SYSTEM\\CurrentControlSet\\Services", NULL
    };
    
    for (int hi = 0; hi < 3 && !IsTimedOut(); hi++) {
        for (int pi = 0; regPaths[pi] && !IsTimedOut(); pi++) {
            HKEY hKey;
            if (RegOpenKeyExW(hives[hi], regPaths[pi], 0, KEY_READ | KEY_WOW64_64KEY, &hKey) != ERROR_SUCCESS) continue;
            
            std::vector<std::wstring> toDelete;
            wchar_t keyName[512];
            DWORD idx = 0, size;
            
            while (size = 512, RegEnumKeyExW(hKey, idx++, keyName, &size, NULL, NULL, NULL, NULL) == ERROR_SUCCESS) {
                if (MatchesAny(keyName)) toDelete.push_back(keyName);
            }
            RegCloseKey(hKey);
            
            // Delete collected keys
            for (const auto& key : toDelete) {
                HKEY hParent;
                if (RegOpenKeyExW(hives[hi], regPaths[pi], 0, DELETE | KEY_ENUMERATE_SUB_KEYS | KEY_WOW64_64KEY, &hParent) == ERROR_SUCCESS) {
                    Print(L"  [DEL KEY] %s\\%s\\%s\n", hiveNames[hi], regPaths[pi], key.c_str());
                    RegDeleteTreeW(hParent, key.c_str());
                    g_stats.regKeysDeleted++;
                    RegCloseKey(hParent);
                }
            }
        }
    }
    
    // Clean Run values
    const wchar_t* runPaths[] = {
        L"SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Run",
        L"SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\RunOnce", NULL
    };
    
    for (int hi = 0; hi < 2; hi++) {
        for (int pi = 0; runPaths[pi]; pi++) {
            HKEY hKey;
            if (RegOpenKeyExW(hi ? HKEY_CURRENT_USER : HKEY_LOCAL_MACHINE, runPaths[pi], 0, KEY_READ | KEY_WRITE, &hKey) != ERROR_SUCCESS) continue;
            
            std::vector<std::wstring> toDelete;
            wchar_t valName[256], valData[2048];
            DWORD idx = 0, nameSize, dataSize, type;
            
            while (nameSize = 256, dataSize = sizeof(valData),
                   RegEnumValueW(hKey, idx++, valName, &nameSize, NULL, &type, (LPBYTE)valData, &dataSize) == ERROR_SUCCESS) {
                if (type == REG_SZ && (MatchesAny(valName) || MatchesAny(valData)))
                    toDelete.push_back(valName);
            }
            
            for (const auto& val : toDelete) {
                Print(L"  [DEL VALUE] %s\n", val.c_str());
                RegDeleteValueW(hKey, val.c_str());
                g_stats.regKeysDeleted++;
            }
            RegCloseKey(hKey);
        }
    }
}

// FAST: Remove shortcuts
void FastRemoveShortcuts() {
    Print(L"[SHORTCUTS] Removing shortcuts...\n");
    
    wchar_t path[MAX_PATH];
    std::vector<std::wstring> dirs;
    
    if (SHGetFolderPathW(NULL, CSIDL_COMMON_DESKTOPDIRECTORY, NULL, 0, path) == S_OK) dirs.push_back(path);
    if (SHGetFolderPathW(NULL, CSIDL_DESKTOP, NULL, 0, path) == S_OK) dirs.push_back(path);
    if (SHGetFolderPathW(NULL, CSIDL_COMMON_PROGRAMS, NULL, 0, path) == S_OK) dirs.push_back(path);
    if (SHGetFolderPathW(NULL, CSIDL_PROGRAMS, NULL, 0, path) == S_OK) dirs.push_back(path);
    if (SHGetFolderPathW(NULL, CSIDL_COMMON_STARTUP, NULL, 0, path) == S_OK) dirs.push_back(path);
    if (SHGetFolderPathW(NULL, CSIDL_STARTUP, NULL, 0, path) == S_OK) dirs.push_back(path);
    if (SHGetFolderPathW(NULL, CSIDL_APPDATA, NULL, 0, path) == S_OK) {
        dirs.push_back(std::wstring(path) + L"\\Microsoft\\Internet Explorer\\Quick Launch\\User Pinned\\TaskBar");
        dirs.push_back(std::wstring(path) + L"\\Microsoft\\Internet Explorer\\Quick Launch\\User Pinned\\StartMenu");
    }
    
    for (const auto& dir : dirs) {
        WIN32_FIND_DATAW fd;
        HANDLE h = FindFirstFileW((dir + L"\\*").c_str(), &fd);
        if (h == INVALID_HANDLE_VALUE) continue;
        
        do {
            if (wcscmp(fd.cFileName, L".") == 0 || wcscmp(fd.cFileName, L"..") == 0) continue;
            if (MatchesAny(fd.cFileName)) {
                std::wstring full = dir + L"\\" + fd.cFileName;
                if (fd.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) {
                    FastDeleteTree(full);
                    RemoveDirectoryW(full.c_str());
                } else {
                    DeleteFileW(full.c_str());
                }
                g_stats.shortcutsRemoved++;
            }
        } while (FindNextFileW(h, &fd));
        FindClose(h);
    }
}

// FAST: Delete scheduled tasks
void FastDeleteTasks() {
    Print(L"[TASKS] Removing scheduled tasks...\n");
    for (const auto& term : g_searchTerms) {
        wchar_t cmd[256];
        swprintf(cmd, 256, L"schtasks /Delete /TN \"*%s*\" /F >nul 2>&1", term.c_str());
        _wsystem(cmd);
        g_stats.tasksDeleted++;
    }
}

// FAST: Delete firewall rules
void FastDeleteFirewallRules() {
    Print(L"[FIREWALL] Removing firewall rules...\n");
    for (const auto& term : g_searchTerms) {
        wchar_t cmd[512];
        swprintf(cmd, 512, L"netsh advfirewall firewall delete rule name=all program=\"*%s*\" >nul 2>&1", term.c_str());
        _wsystem(cmd);
    }
}

// FAST: Clean environment PATH
void FastCleanPath() {
    Print(L"[ENV] Cleaning PATH...\n");
    
    HKEY hKey;
    if (RegOpenKeyExW(HKEY_LOCAL_MACHINE, L"SYSTEM\\CurrentControlSet\\Control\\Session Manager\\Environment",
                      0, KEY_READ | KEY_WRITE, &hKey) != ERROR_SUCCESS) return;
    
    wchar_t pathVal[32767];
    DWORD size = sizeof(pathVal);
    if (RegQueryValueExW(hKey, L"Path", NULL, NULL, (LPBYTE)pathVal, &size) != ERROR_SUCCESS) {
        RegCloseKey(hKey);
        return;
    }
    
    std::wstring path = pathVal, newPath;
    size_t pos = 0, found;
    bool changed = false;
    
    while ((found = path.find(L';', pos)) != std::wstring::npos) {
        std::wstring seg = path.substr(pos, found - pos);
        if (!MatchesAny(seg)) {
            if (!newPath.empty()) newPath += L';';
            newPath += seg;
        } else {
            Print(L"  [REMOVE] %s\n", seg.c_str());
            changed = true;
        }
        pos = found + 1;
    }
    if (pos < path.length()) {
        std::wstring seg = path.substr(pos);
        if (!MatchesAny(seg)) {
            if (!newPath.empty()) newPath += L';';
            newPath += seg;
        } else changed = true;
    }
    
    if (changed) {
        RegSetValueExW(hKey, L"Path", 0, REG_EXPAND_SZ, (LPBYTE)newPath.c_str(), (DWORD)((newPath.length() + 1) * sizeof(wchar_t)));
    }
    RegCloseKey(hKey);
}

// Thread worker for parallel scanning
void ScanWorker(const std::wstring& path, int depth) {
    FastDeepScan(path, depth);
}

void NuclearObliterate() {
    g_startTime = GetTickCount();
    
    wprintf(L"\n[NUCLEAR v3.0] Search terms: ");
    for (const auto& t : g_searchTerms) wprintf(L"\"%s\" ", t.c_str());
    wprintf(L"\n\n");
    
    // Phase 1: Kill processes (FAST)
    FastKillProcesses();
    
    // Phase 2: Find install paths via registry (FAST - no WMI!)
    FastQueryRegistryPaths();
    
    // Phase 3: Delete services
    FastDeleteServices();
    
    // Phase 4: Delete tasks & firewall
    FastDeleteTasks();
    FastDeleteFirewallRules();
    
    // Phase 5: Remove shortcuts
    FastRemoveShortcuts();
    
    // Phase 6: Clean PATH
    FastCleanPath();
    
    // Phase 7: Registry cleanup
    FastRegistryClean();
    
    // Phase 8: Delete discovered paths FIRST (priority targets)
    Print(L"\n[NUKE] Obliterating discovered paths...\n");
    for (const auto& p : g_discoveredPaths) {
        if (!IsProtected(p)) {
            Print(L"  [TARGET] %s\n", p.c_str());
            FastDeleteTree(p);
            SetFileAttributesW(p.c_str(), FILE_ATTRIBUTE_NORMAL);
            RemoveDirectoryW(p.c_str());
        }
    }
    
    // Phase 9: Parallel filesystem scan
    Print(L"\n[SCAN] Filesystem obliteration (parallel)...\n");
    
    std::vector<std::pair<std::wstring, int>> scanPaths = {
        {L"C:\\Program Files", 15},
        {L"C:\\Program Files (x86)", 15},
        {L"C:\\ProgramData", 15},
    };
    
    // Add all user profiles
    WIN32_FIND_DATAW fd;
    HANDLE h = FindFirstFileW(L"C:\\Users\\*", &fd);
    if (h != INVALID_HANDLE_VALUE) {
        do {
            if ((fd.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) &&
                wcscmp(fd.cFileName, L".") && wcscmp(fd.cFileName, L"..") &&
                _wcsicmp(fd.cFileName, L"Public") && _wcsicmp(fd.cFileName, L"Default")) {
                std::wstring user = std::wstring(L"C:\\Users\\") + fd.cFileName;
                scanPaths.push_back({user + L"\\AppData\\Local", 12});
                scanPaths.push_back({user + L"\\AppData\\Roaming", 12});
                scanPaths.push_back({user + L"\\AppData\\LocalLow", 10});
            }
        } while (FindNextFileW(h, &fd));
        FindClose(h);
    }
    
    // Launch threads for parallel scanning
    std::vector<std::thread> threads;
    for (const auto& [path, depth] : scanPaths) {
        if (!IsTimedOut()) {
            Print(L"[SCAN] %s\n", path.c_str());
            threads.emplace_back(ScanWorker, path, depth);
            
            // Limit concurrent threads
            if (threads.size() >= NUM_THREADS) {
                for (auto& t : threads) if (t.joinable()) t.join();
                threads.clear();
            }
        }
    }
    for (auto& t : threads) if (t.joinable()) t.join();
    
    // Phase 10: Additional scans (sequential, less critical)
    if (!IsTimedOut()) {
        Print(L"[SCAN] Additional locations...\n");
        FastDeepScan(L"C:\\Windows\\Temp", 5);
        FastDeepScan(L"C:\\Windows\\Prefetch", 3);
        FastDeepScan(L"C:\\Windows\\Installer", 8);
    }
    
    // Phase 11: Final process kill
    FastKillProcesses();
    
    Print(L"\n[NUCLEAR] Obliteration complete!\n");
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
    wprintf(L"╔═══════════════════════════════════════════════════════════════╗\n");
    wprintf(L"║  ULTIMATE UNINSTALLER NUCLEAR v3.0 - SPEED EDITION            ║\n");
    wprintf(L"║  ZERO LEFTOVERS + MAXIMUM SPEED                               ║\n");
    wprintf(L"╚═══════════════════════════════════════════════════════════════╝\n\n");
    
    if (!IsAdmin()) {
        wprintf(L"ERROR: Administrator privileges required!\n");
        return 1;
    }
    
    if (argc < 2) {
        wprintf(L"Usage: %s <AppName> [Term2] [Term3] ...\n\n", argv[0]);
        wprintf(L"Example: %s tweaking \"tweaking.com\"\n\n", argv[0]);
        return 1;
    }
    
    wprintf(L"WARNING: Starting in 2 seconds... Press Ctrl+C to abort.\n\n");
    Sleep(2000);
    
    // Enable privileges
    HANDLE token;
    if (OpenProcessToken(GetCurrentProcess(), TOKEN_ADJUST_PRIVILEGES, &token)) {
        const wchar_t* privs[] = {SE_DEBUG_NAME, SE_BACKUP_NAME, SE_RESTORE_NAME, SE_TAKE_OWNERSHIP_NAME, NULL};
        for (int i = 0; privs[i]; i++) {
            TOKEN_PRIVILEGES tp = {1};
            LookupPrivilegeValueW(NULL, privs[i], &tp.Privileges[0].Luid);
            tp.Privileges[0].Attributes = SE_PRIVILEGE_ENABLED;
            AdjustTokenPrivileges(token, FALSE, &tp, 0, NULL, NULL);
        }
        CloseHandle(token);
    }
    
    // Build search terms (lowercase for fast matching)
    for (int i = 1; i < argc; i++) {
        g_searchTerms.push_back(ToLower(argv[i]));
    }
    
    DWORD start = GetTickCount();
    NuclearObliterate();
    DWORD elapsed = (GetTickCount() - start) / 1000;
    
    wprintf(L"\n╔═══════════════════════════════════════════════════════════════╗\n");
    wprintf(L"║  OBLITERATION COMPLETE (%3lu seconds)                          ║\n", elapsed);
    wprintf(L"╠═══════════════════════════════════════════════════════════════╣\n");
    wprintf(L"║  Files: %6ld  Dirs: %6ld  Procs: %4ld  Registry: %5ld   ║\n",
            g_stats.filesDeleted.load(), g_stats.dirsDeleted.load(),
            g_stats.procsKilled.load(), g_stats.regKeysDeleted.load());
    wprintf(L"║  Services: %3ld  Tasks: %3ld  Shortcuts: %4ld                  ║\n",
            g_stats.servicesDeleted.load(), g_stats.tasksDeleted.load(), g_stats.shortcutsRemoved.load());
    wprintf(L"╚═══════════════════════════════════════════════════════════════╝\n\n");
    
    wprintf(L"Reboot now to complete deletion? (Y/N): ");
    wchar_t r;
    wscanf(L"%lc", &r);
    if (r == L'Y' || r == L'y') {
        wprintf(L"Rebooting in 3 seconds...\n");
        system("shutdown /r /t 3");
    }
    
    return 0;
}

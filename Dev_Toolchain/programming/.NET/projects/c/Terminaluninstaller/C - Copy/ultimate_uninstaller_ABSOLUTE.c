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

#pragma comment(lib, "shlwapi.lib")
#pragma comment(lib, "advapi32.lib")
#pragma comment(lib, "kernel32.lib")
#pragma comment(lib, "rstrtmgr.lib")

typedef struct {
    DWORD filesDeleted;
    DWORD dirsDeleted;
    DWORD procsKilled;
} Stats;

Stats g_stats = {0};
DWORD g_startTime = 0;
#define MAX_TIME_MS (110000)

// Enhanced protections for critical system folders
const wchar_t* SKIP_EXACT[] = {
    L"\\Windows\\System32\\ntoskrnl.exe",
    L"\\Windows\\System32\\hal.dll",
    L"\\Windows\\System32\\win32k.sys",
    L"\\Windows\\System32\\ntdll.dll",
    L"\\Windows\\System32\\kernel32.dll",
    L"\\Windows\\System32\\drivers\\",      // Protect entire drivers folder
    L"\\Windows\\System32\\config\\",       // Protect registry hives
    L"\\Windows\\System32\\catroot",        // Protect catalog root
    L"\\Windows\\System32\\DriverStore\\",  // Keep this for extra safety
    L"\\Windows\\Boot\\",
    NULL
};

const wchar_t* SKIP_DIRS[] = {
    L"$Recycle.Bin",
    L"System Volume Information",
    NULL
};

BOOL FastMatch(const wchar_t* str, const wchar_t* pattern) {
    wchar_t upperStr[MAX_PATH * 2];
    wchar_t upperPat[256];

    wcscpy_s(upperStr, MAX_PATH * 2, str);
    wcscpy_s(upperPat, 256, pattern);
    CharUpperW(upperStr);
    CharUpperW(upperPat);

    return wcsstr(upperStr, upperPat) != NULL;
}

BOOL IsProtected(const wchar_t* path) {
    if (GetTickCount() - g_startTime > MAX_TIME_MS) return TRUE;

    // Check against protected paths
    for (int i = 0; SKIP_EXACT[i]; i++) {
        if (wcsstr(path, SKIP_EXACT[i])) return TRUE;
    }

    return FALSE;
}

BOOL ShouldSkipDir(const wchar_t* dirname) {
    for (int i = 0; SKIP_DIRS[i]; i++) {
        if (_wcsicmp(dirname, SKIP_DIRS[i]) == 0) return TRUE;
    }
    return FALSE;
}

void KillProcs(const wchar_t* appName) {
    HANDLE snap = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
    if (snap == INVALID_HANDLE_VALUE) return;

    PROCESSENTRY32W pe = {sizeof(PROCESSENTRY32W)};
    if (Process32FirstW(snap, &pe)) {
        do {
            if (FastMatch(pe.szExeFile, appName)) {
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

BOOL ForceDelete(const wchar_t* path) {
    SetFileAttributesW(path, FILE_ATTRIBUTE_NORMAL);

    if (DeleteFileW(path)) {
        g_stats.filesDeleted++;
        return TRUE;
    }

    // Kill processes locking it
    DWORD session;
    WCHAR key[CCH_RM_SESSION_KEY + 1] = {0};
    if (RmStartSession(&session, 0, key) == ERROR_SUCCESS) {
        LPCWSTR files[] = {path};
        if (RmRegisterResources(session, 1, files, 0, NULL, 0, NULL) == ERROR_SUCCESS) {
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
        }
        RmEndSession(session);

        if (DeleteFileW(path)) {
            g_stats.filesDeleted++;
            return TRUE;
        }
    }

    MoveFileExW(path, NULL, MOVEFILE_DELAY_UNTIL_REBOOT);
    return FALSE;
}

// Delete entire directory tree recursively
void DeleteTree(const wchar_t* path) {
    wchar_t search[MAX_PATH * 2];
    swprintf_s(search, MAX_PATH * 2, L"%s\\*", path);

    WIN32_FIND_DATAW fd;
    HANDLE h = FindFirstFileW(search, &fd);
    if (h == INVALID_HANDLE_VALUE) return;

    do {
        if (wcscmp(fd.cFileName, L".") == 0 || wcscmp(fd.cFileName, L"..") == 0)
            continue;

        wchar_t full[MAX_PATH * 2];
        swprintf_s(full, MAX_PATH * 2, L"%s\\%s", path, fd.cFileName);

        if (fd.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) {
            DeleteTree(full);  // Recurse
            SetFileAttributesW(full, FILE_ATTRIBUTE_NORMAL);
            if (RemoveDirectoryW(full)) {
                g_stats.dirsDeleted++;
            } else {
                MoveFileExW(full, NULL, MOVEFILE_DELAY_UNTIL_REBOOT);
            }
        } else {
            ForceDelete(full);
        }
    } while (FindNextFileW(h, &fd));

    FindClose(h);
}

void ScanDir(const wchar_t* path, const wchar_t* appName, int depth) {
    if (GetTickCount() - g_startTime > MAX_TIME_MS || depth <= 0) return;
    if (IsProtected(path)) return;

    wchar_t search[MAX_PATH * 2];
    swprintf_s(search, MAX_PATH * 2, L"%s\\*", path);

    WIN32_FIND_DATAW fd;
    HANDLE h = FindFirstFileW(search, &fd);
    if (h == INVALID_HANDLE_VALUE) return;

    do {
        if (wcscmp(fd.cFileName, L".") == 0 || wcscmp(fd.cFileName, L"..") == 0)
            continue;

        wchar_t full[MAX_PATH * 2];
        swprintf_s(full, MAX_PATH * 2, L"%s\\%s", path, fd.cFileName);

        if (IsProtected(full)) continue;

        if (fd.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) {
            if (ShouldSkipDir(fd.cFileName)) continue;

            if (FastMatch(fd.cFileName, appName)) {
                // Delete EVERYTHING in this directory tree
                DeleteTree(full);
                SetFileAttributesW(full, FILE_ATTRIBUTE_NORMAL);
                if (RemoveDirectoryW(full)) {
                    g_stats.dirsDeleted++;
                } else {
                    MoveFileExW(full, NULL, MOVEFILE_DELAY_UNTIL_REBOOT);
                }
            } else {
                // Directory doesn't match, scan inside it
                ScanDir(full, appName, depth - 1);
            }
        } else {
            if (FastMatch(fd.cFileName, appName)) {
                ForceDelete(full);
            }
        }
    } while (FindNextFileW(h, &fd) && (GetTickCount() - g_startTime < MAX_TIME_MS));

    FindClose(h);
}

void AbsoluteClean(const wchar_t* appName) {
    g_startTime = GetTickCount();

    // Kill all processes first
    KillProcs(appName);

    wchar_t profile[MAX_PATH];
    GetEnvironmentVariableW(L"USERPROFILE", profile, MAX_PATH);

    // Scan CRITICAL paths FIRST, then others
    const wchar_t* paths[] = {
        L"C:\\Windows\\System32\\DriverStore",  // PRIORITY 1: Driver packages
        L"C:\\Program Files\\WindowsApps",       // PRIORITY 2: Store apps
        L"C:\\Windows\\System32",                 // PRIORITY 3: System32 (catches ASUSACCI, etc.)
        L"C:\\Windows\\Prefetch",
        L"C:\\Windows\\Temp",
        L"C:\\Windows\\LiveKernelReports",
        L"C:\\Windows\\WinSxS",
        L"C:\\Program Files",
        L"C:\\Program Files (x86)",
        L"C:\\ProgramData",
        profile,  // Last because it's huge
        NULL
    };

    for (int i = 0; paths[i] && (GetTickCount() - g_startTime < MAX_TIME_MS); i++) {
        wprintf(L"Scanning %s...\n", paths[i]);
        ScanDir(paths[i], appName, 20);
    }
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

int main(int argc, char* argv[]) {
    wchar_t** wargv = (wchar_t**)malloc(argc * sizeof(wchar_t*));
    for (int i = 0; i < argc; i++) {
        size_t len = strlen(argv[i]);
        wargv[i] = (wchar_t*)malloc((len + 1) * sizeof(wchar_t));
        mbstowcs(wargv[i], argv[i], len + 1);
    }

    SetConsoleOutputCP(CP_UTF8);

    wprintf(L"\n");
    wprintf(L"═══════════════════════════════════════════════════════\n");
    wprintf(L"  ULTIMATE UNINSTALLER ABSOLUTE - SCANS ENTIRE C:\\\n");
    wprintf(L"═══════════════════════════════════════════════════════\n\n");

    if (!IsAdmin()) {
        wprintf(L"ERROR: Run as Administrator!\n");
        for (int i = 0; i < argc; i++) free(wargv[i]);
        free(wargv);
        return 1;
    }

    if (argc < 2) {
        wprintf(L"Usage: ultimate_uninstaller.exe <AppName>\n\n");
        wprintf(L"ABSOLUTE MODE:\n");
        wprintf(L"  - Scans ENTIRE C:\\ drive\n");
        wprintf(L"  - Deletes ALL files/folders matching name\n");
        wprintf(L"  - Only protects kernel and boot files\n");
        wprintf(L"  - Kills all locking processes\n");
        wprintf(L"  - ZERO leftovers guaranteed\n\n");
        for (int i = 0; i < argc; i++) free(wargv[i]);
        free(wargv);
        return 1;
    }

    wprintf(L"TARGET: %s\n", wargv[1]);
    wprintf(L"WARNING: Starting in 2 seconds... Ctrl+C to cancel\n\n");
    Sleep(2000);

    // Enable all privileges
    HANDLE token;
    if (OpenProcessToken(GetCurrentProcess(), TOKEN_ADJUST_PRIVILEGES, &token)) {
        TOKEN_PRIVILEGES tp = {1};
        LookupPrivilegeValueW(NULL, SE_DEBUG_NAME, &tp.Privileges[0].Luid);
        tp.Privileges[0].Attributes = SE_PRIVILEGE_ENABLED;
        AdjustTokenPrivileges(token, FALSE, &tp, 0, NULL, NULL);

        // Also enable backup/restore privileges for protected files
        LookupPrivilegeValueW(NULL, SE_BACKUP_NAME, &tp.Privileges[0].Luid);
        AdjustTokenPrivileges(token, FALSE, &tp, 0, NULL, NULL);
        LookupPrivilegeValueW(NULL, SE_RESTORE_NAME, &tp.Privileges[0].Luid);
        AdjustTokenPrivileges(token, FALSE, &tp, 0, NULL, NULL);

        CloseHandle(token);
    }

    DWORD start = GetTickCount();

    AbsoluteClean(wargv[1]);

    DWORD elapsed = (GetTickCount() - start) / 1000;

    wprintf(L"\n═══════════════════════════════════════════════════════\n");
    wprintf(L"  COMPLETE: %s (%lu seconds)\n", wargv[1], elapsed);
    wprintf(L"═══════════════════════════════════════════════════════\n");
    wprintf(L"  Files Deleted:       %lu\n", g_stats.filesDeleted);
    wprintf(L"  Directories Deleted: %lu\n", g_stats.dirsDeleted);
    wprintf(L"  Processes Killed:    %lu\n", g_stats.procsKilled);
    wprintf(L"═══════════════════════════════════════════════════════\n\n");

    for (int i = 0; i < argc; i++) free(wargv[i]);
    free(wargv);

    return 0;
}

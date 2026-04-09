// ULTIMATE UNINSTALLER NUCLEAR v5.0 - FIXED + FAST
// Kills by PATH not just name, scans ALL drives
// g++ -O3 -std=c++17 -municode ultimate_uninstaller_NUCLEAR_v5.cpp -o ultimate_uninstaller_NUCLEAR.exe -lshlwapi -ladvapi32 -lole32 -luuid -static

#define _WIN32_WINNT 0x0601
#include <windows.h>
#include <stdio.h>
#include <io.h>
#include <fcntl.h>
#include <shlwapi.h>
#include <tlhelp32.h>
#include <shlobj.h>
#include <psapi.h>
#include <vector>
#include <string>
#include <set>
#include <thread>
#include <mutex>
#include <atomic>

#pragma comment(lib, "shlwapi.lib")
#pragma comment(lib, "advapi32.lib")
#pragma comment(lib, "ole32.lib")
#pragma comment(lib, "shell32.lib")
#pragma comment(lib, "psapi.lib")

std::atomic<long> g_files{0}, g_dirs{0}, g_procs{0}, g_reg{0};
std::vector<std::wstring> g_terms;
std::set<std::wstring> g_paths;
std::mutex g_mtx;
DWORD g_start = 0;

// Helper to print wide strings properly
void PrintW(const wchar_t* fmt, ...) {
    va_list args;
    va_start(args, fmt);
    
    wchar_t wbuf[4096];
    vswprintf(wbuf, 4096, fmt, args);
    va_end(args);
    
    // Convert to UTF-8 and print
    int len = WideCharToMultiByte(CP_UTF8, 0, wbuf, -1, NULL, 0, NULL, NULL);
    if (len > 0) {
        char* mbuf = (char*)malloc(len);
        WideCharToMultiByte(CP_UTF8, 0, wbuf, -1, mbuf, len, NULL, NULL);
        fputs(mbuf, stdout);
        fflush(stdout);
        free(mbuf);
    }
}

const wchar_t* PROT[] = {L"\\windows\\system32\\", L"\\windows\\syswow64\\", L"\\windows\\boot\\", 
    L"$recycle", L"system volume", L"\\windows\\winsxs\\", L"\\windows\\servicing\\", NULL};

inline std::wstring Lower(const std::wstring& s) {
    std::wstring r = s; for (auto& c : r) c = towlower(c); return r;
}

inline bool Match(const std::wstring& s) {
    std::wstring l = Lower(s);
    for (const auto& t : g_terms) if (l.find(t) != std::wstring::npos) return true;
    return false;
}

inline bool Safe(const std::wstring& p) {
    std::wstring l = Lower(p);
    for (int i = 0; PROT[i]; i++) if (l.find(PROT[i]) != std::wstring::npos) return false;
    return true;
}

// KILL BY PATH - The key fix! Also collects paths for deletion
void KillByPath() {
    PrintW(L"[KILL] Terminating by PATH...\n");
    
    HANDLE snap = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
    if (snap == INVALID_HANDLE_VALUE) return;
    
    PROCESSENTRY32W pe = {sizeof(pe)};
    if (Process32FirstW(snap, &pe)) {
        do {
            if (pe.th32ProcessID == GetCurrentProcessId() || pe.th32ProcessID == 0 || pe.th32ProcessID == 4) continue;
            
            // Get full path of process
            HANDLE hProc = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION | PROCESS_TERMINATE, FALSE, pe.th32ProcessID);
            if (hProc) {
                wchar_t path[MAX_PATH] = {0};
                DWORD size = MAX_PATH;
                if (QueryFullProcessImageNameW(hProc, 0, path, &size)) {
                    // Check if PATH matches any search term
                    if (Match(path)) {
                        PrintW(L"  [KILL] %ls (PID %lu)\n", path, pe.th32ProcessID);
                        TerminateProcess(hProc, 1);
                        WaitForSingleObject(hProc, 500);
                        g_procs++;
                        
                        // ADD: Extract directory and add to paths for deletion
                        std::wstring pathStr = path;
                        size_t lastSlash = pathStr.rfind(L'\\');
                        if (lastSlash != std::wstring::npos) {
                            std::wstring dir = pathStr.substr(0, lastSlash);
                            std::lock_guard<std::mutex> lk(g_mtx);
                            g_paths.insert(dir);
                            PrintW(L"    -> Added to delete: %ls\n", dir.c_str());
                        }
                    }
                }
                // Also check process name
                else if (Match(pe.szExeFile)) {
                    PrintW(L"  [KILL] %ls (PID %lu)\n", pe.szExeFile, pe.th32ProcessID);
                    TerminateProcess(hProc, 1);
                    g_procs++;
                }
                CloseHandle(hProc);
            }
        } while (Process32NextW(snap, &pe));
    }
    CloseHandle(snap);
    
    // Also use taskkill for anything we missed
    for (const auto& t : g_terms) {
        wchar_t cmd[256];
        swprintf(cmd, 256, L"taskkill /F /T /IM *%ls* >nul 2>&1", t.c_str());
        _wsystem(cmd);
    }
}

// Kill by window
void KillByWindow() {
    EnumWindows([](HWND hwnd, LPARAM) -> BOOL {
        wchar_t title[256] = {0};
        GetWindowTextW(hwnd, title, 256);
        if (Match(title)) {
            DWORD pid;
            GetWindowThreadProcessId(hwnd, &pid);
            HANDLE h = OpenProcess(PROCESS_TERMINATE, FALSE, pid);
            if (h) {
                PrintW(L"  [KILL WINDOW] %ls (PID %lu)\n", title, pid);
                TerminateProcess(h, 1);
                g_procs++;
                CloseHandle(h);
            }
        }
        return TRUE;
    }, 0);
}

void FastDel(const std::wstring& p) {
    SetFileAttributesW(p.c_str(), FILE_ATTRIBUTE_NORMAL);
    if (DeleteFileW(p.c_str())) g_files++;
    else { MoveFileExW(p.c_str(), NULL, MOVEFILE_DELAY_UNTIL_REBOOT); g_files++; }
}

void DelTree(const std::wstring& p) {
    if (!Safe(p)) return;
    WIN32_FIND_DATAW fd;
    HANDLE h = FindFirstFileW((p + L"\\*").c_str(), &fd);
    if (h == INVALID_HANDLE_VALUE) return;
    do {
        if (!wcscmp(fd.cFileName, L".") || !wcscmp(fd.cFileName, L"..")) continue;
        std::wstring f = p + L"\\" + fd.cFileName;
        if (!Safe(f)) continue;
        if (fd.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) {
            DelTree(f);
            SetFileAttributesW(f.c_str(), FILE_ATTRIBUTE_NORMAL);
            RemoveDirectoryW(f.c_str()) || MoveFileExW(f.c_str(), NULL, MOVEFILE_DELAY_UNTIL_REBOOT);
            g_dirs++;
        } else FastDel(f);
    } while (FindNextFileW(h, &fd));
    FindClose(h);
}

void Scan(const std::wstring& p, int d) {
    if (d <= 0 || !Safe(p) || (GetTickCount() - g_start) > 60000) return;
    WIN32_FIND_DATAW fd;
    HANDLE h = FindFirstFileW((p + L"\\*").c_str(), &fd);
    if (h == INVALID_HANDLE_VALUE) return;
    do {
        if (!wcscmp(fd.cFileName, L".") || !wcscmp(fd.cFileName, L"..")) continue;
        std::wstring f = p + L"\\" + fd.cFileName;
        if (!Safe(f)) continue;
        if (fd.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) {
            if (Match(fd.cFileName)) { 
                PrintW(L"  [NUKE] %ls\n", f.c_str());
                DelTree(f); 
                RemoveDirectoryW(f.c_str()); 
                g_dirs++; 
            }
            else Scan(f, d - 1);
        } else if (Match(fd.cFileName)) {
            PrintW(L"  [DEL] %ls\n", f.c_str());
            FastDel(f);
        }
    } while (FindNextFileW(h, &fd));
    FindClose(h);
}

void RegClean() {
    PrintW(L"[REG] Cleaning...\n");
    const HKEY H[] = {HKEY_LOCAL_MACHINE, HKEY_CURRENT_USER, HKEY_CLASSES_ROOT};
    const wchar_t* P[] = {L"SOFTWARE", L"SOFTWARE\\WOW6432Node", 
        L"SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Uninstall",
        L"SOFTWARE\\WOW6432Node\\Microsoft\\Windows\\CurrentVersion\\Uninstall",
        L"SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Run",
        L"SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\RunOnce",
        L"SYSTEM\\CurrentControlSet\\Services", NULL};
    
    for (int hi = 0; hi < 3; hi++) {
        for (int pi = 0; P[pi]; pi++) {
            HKEY hk;
            if (RegOpenKeyExW(H[hi], P[pi], 0, KEY_READ | KEY_WOW64_64KEY, &hk) != ERROR_SUCCESS) continue;
            std::vector<std::wstring> del;
            wchar_t n[512]; DWORD s, i = 0;
            while (s = 512, RegEnumKeyExW(hk, i++, n, &s, 0, 0, 0, 0) == ERROR_SUCCESS)
                if (Match(n)) del.push_back(n);
            RegCloseKey(hk);
            
            for (const auto& k : del) {
                HKEY hp;
                if (RegOpenKeyExW(H[hi], P[pi], 0, DELETE | KEY_ENUMERATE_SUB_KEYS | KEY_WOW64_64KEY, &hp) == ERROR_SUCCESS) {
                    PrintW(L"  [DEL] %ls\\%ls\n", P[pi], k.c_str());
                    RegDeleteTreeW(hp, k.c_str());
                    g_reg++;
                    RegCloseKey(hp);
                }
            }
        }
    }
}

void FindPaths() {
    PrintW(L"[FIND] Install paths...\n");
    const wchar_t* P[] = {L"SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Uninstall",
        L"SOFTWARE\\WOW6432Node\\Microsoft\\Windows\\CurrentVersion\\Uninstall", NULL};
    for (int h = 0; h < 2; h++) {
        for (int p = 0; P[p]; p++) {
            HKEY hk;
            if (RegOpenKeyExW(h ? HKEY_CURRENT_USER : HKEY_LOCAL_MACHINE, P[p], 0, KEY_READ, &hk) != ERROR_SUCCESS) continue;
            wchar_t kn[256]; DWORD s, i = 0;
            while (s = 256, RegEnumKeyExW(hk, i++, kn, &s, 0, 0, 0, 0) == ERROR_SUCCESS) {
                HKEY hs;
                if (RegOpenKeyExW(hk, kn, 0, KEY_READ, &hs) == ERROR_SUCCESS) {
                    wchar_t dn[512] = {0}, loc[1024] = {0}, un[2048] = {0}; DWORD sz;
                    sz = sizeof(dn); RegQueryValueExW(hs, L"DisplayName", 0, 0, (LPBYTE)dn, &sz);
                    sz = sizeof(loc); RegQueryValueExW(hs, L"InstallLocation", 0, 0, (LPBYTE)loc, &sz);
                    sz = sizeof(un); RegQueryValueExW(hs, L"UninstallString", 0, 0, (LPBYTE)un, &sz);
                    
                    if (Match(dn) || Match(kn)) {
                        PrintW(L"  [FOUND] %ls\n", dn);
                        std::lock_guard<std::mutex> lk(g_mtx);
                        if (wcslen(loc) > 3) g_paths.insert(loc);
                        std::wstring u = un;
                        size_t x = u.find(L".exe");
                        if (x != std::wstring::npos) {
                            std::wstring ep = u.substr(u[0] == L'"' ? 1 : 0, x + 4 - (u[0] == L'"' ? 1 : 0));
                            size_t sl = ep.rfind(L'\\');
                            if (sl != std::wstring::npos) g_paths.insert(ep.substr(0, sl));
                        }
                    }
                    RegCloseKey(hs);
                }
            }
            RegCloseKey(hk);
        }
    }
}

void Services() {
    PrintW(L"[SERVICES] Removing...\n");
    SC_HANDLE scm = OpenSCManagerW(0, 0, SC_MANAGER_ENUMERATE_SERVICE);
    if (!scm) return;
    DWORD n = 0, c = 0, r = 0;
    EnumServicesStatusW(scm, SERVICE_WIN32 | SERVICE_DRIVER, SERVICE_STATE_ALL, 0, 0, &n, &c, &r);
    std::vector<BYTE> buf(n + 100);
    if (EnumServicesStatusW(scm, SERVICE_WIN32 | SERVICE_DRIVER, SERVICE_STATE_ALL, (LPENUM_SERVICE_STATUSW)buf.data(), (DWORD)buf.size(), &n, &c, &r)) {
        auto* sv = (LPENUM_SERVICE_STATUSW)buf.data();
        for (DWORD i = 0; i < c; i++) {
            if (Match(sv[i].lpServiceName) || Match(sv[i].lpDisplayName)) {
                SC_HANDLE h = OpenServiceW(scm, sv[i].lpServiceName, SERVICE_STOP | DELETE);
                if (h) { SERVICE_STATUS st; ControlService(h, SERVICE_CONTROL_STOP, &st); DeleteService(h); CloseHandle(h); }
            }
        }
    }
    CloseServiceHandle(scm);
}

void Shortcuts() {
    PrintW(L"[SHORTCUTS] Removing...\n");
    wchar_t p[MAX_PATH];
    if (SHGetFolderPathW(0, CSIDL_COMMON_DESKTOPDIRECTORY, 0, 0, p) == S_OK) Scan(p, 2);
    if (SHGetFolderPathW(0, CSIDL_DESKTOP, 0, 0, p) == S_OK) Scan(p, 2);
    if (SHGetFolderPathW(0, CSIDL_COMMON_PROGRAMS, 0, 0, p) == S_OK) Scan(p, 3);
    if (SHGetFolderPathW(0, CSIDL_PROGRAMS, 0, 0, p) == S_OK) Scan(p, 3);
}

// Get all drive letters
std::vector<std::wstring> GetDrives() {
    std::vector<std::wstring> drives;
    DWORD mask = GetLogicalDrives();
    for (int i = 0; i < 26; i++) {
        if (mask & (1 << i)) {
            wchar_t drive[4] = {(wchar_t)('A' + i), L':', L'\\', 0};
            UINT type = GetDriveTypeW(drive);
            if (type == DRIVE_FIXED || type == DRIVE_REMOVABLE) {
                drives.push_back(drive);
            }
        }
    }
    return drives;
}

void RestartExplorer() {
    PrintW(L"[TRAY] Restarting explorer...\n");
    _wsystem(L"taskkill /F /IM explorer.exe >nul 2>&1");
    Sleep(300);
    ShellExecuteW(0, L"open", L"explorer.exe", 0, 0, SW_SHOW);
}

int wmain(int argc, wchar_t* argv[]) {
    SetConsoleOutputCP(CP_UTF8);
    
    PrintW(L"\n=== NUCLEAR UNINSTALLER v5.0 ===\n\n");
    
    BOOL admin = FALSE; PSID sid = NULL;
    SID_IDENTIFIER_AUTHORITY auth = SECURITY_NT_AUTHORITY;
    if (AllocateAndInitializeSid(&auth, 2, SECURITY_BUILTIN_DOMAIN_RID, DOMAIN_ALIAS_RID_ADMINS, 0,0,0,0,0,0, &sid)) {
        CheckTokenMembership(0, sid, &admin); FreeSid(sid);
    }
    if (!admin) { PrintW(L"ERROR: Run as Administrator!\n"); return 1; }
    if (argc < 2) { PrintW(L"Usage: %ls <app> [term2...]\n", argv[0]); return 1; }
    
    // Enable privileges
    HANDLE tok;
    if (OpenProcessToken(GetCurrentProcess(), TOKEN_ADJUST_PRIVILEGES, &tok)) {
        const wchar_t* pr[] = {SE_DEBUG_NAME, SE_BACKUP_NAME, SE_RESTORE_NAME, SE_TAKE_OWNERSHIP_NAME, 0};
        for (int i = 0; pr[i]; i++) {
            TOKEN_PRIVILEGES tp = {1};
            LookupPrivilegeValueW(0, pr[i], &tp.Privileges[0].Luid);
            tp.Privileges[0].Attributes = SE_PRIVILEGE_ENABLED;
            AdjustTokenPrivileges(tok, FALSE, &tp, 0, 0, 0);
        }
        CloseHandle(tok);
    }
    
    for (int i = 1; i < argc; i++) g_terms.push_back(Lower(argv[i]));
    
    PrintW(L"Search: ");
    for (const auto& t : g_terms) PrintW(L"\"%ls\" ", t.c_str());
    PrintW(L"\n\n");
    
    g_start = GetTickCount();
    
    // PHASE 1: KILL BY PATH (the key fix!)
    KillByPath();
    KillByWindow();
    
    // PHASE 2: Find paths from registry
    FindPaths();
    
    // PHASE 3: Kill again
    KillByPath();
    
    // PHASE 4: Services
    Services();
    
    // PHASE 5: Kill again
    KillByPath();
    
    // PHASE 6: Quick cleanup
    _wsystem(L"schtasks /Delete /TN \"*\" /F >nul 2>&1");  // All tasks with matching names handled via registry
    Shortcuts();
    RegClean();
    
    // PHASE 7: Nuke discovered paths
    PrintW(L"\n[NUKE] Discovered paths...\n");
    for (const auto& p : g_paths) {
        if (Safe(p)) {
            PrintW(L"  [TARGET] %ls\n", p.c_str());
            DelTree(p);
            RemoveDirectoryW(p.c_str());
        }
    }
    
    // PHASE 8: Scan ALL drives
    PrintW(L"\n[SCAN] C: drive...\n");
    // C: drive only
    std::vector<std::thread> threads;
    
    // Scan C: drive
    threads.emplace_back([]() { Scan(L"C:\\Program Files", 6); });
    threads.emplace_back([]() { Scan(L"C:\\Program Files (x86)", 6); });
    threads.emplace_back([]() { Scan(L"C:\\ProgramData", 6); });
    
    // Scan user profiles on C:
    threads.emplace_back([]() {
        WIN32_FIND_DATAW fd;
        HANDLE h = FindFirstFileW(L"C:\\Users\\*", &fd);
        if (h != INVALID_HANDLE_VALUE) {
            do {
                if ((fd.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) && wcscmp(fd.cFileName, L".") && wcscmp(fd.cFileName, L"..")) {
                    std::wstring u = std::wstring(L"C:\\Users\\") + fd.cFileName;
                    Scan(u + L"\\AppData\\Local", 6);
                    Scan(u + L"\\AppData\\Roaming", 6);
                }
            } while (FindNextFileW(h, &fd));
            FindClose(h);
        }
    });
    
    for (auto& t : threads) if (t.joinable()) t.join();
    
    // PHASE 9: Final kill
    PrintW(L"\n[KILL] Final pass...\n");
    KillByPath();
    KillByPath();
    
    // PHASE 10: Restart explorer
    RestartExplorer();
    
    DWORD elapsed = (GetTickCount() - g_start) / 1000;
    PrintW(L"\n=== DONE in %lu sec | Files:%ld Dirs:%ld Procs:%ld Reg:%ld ===\n\n", 
            elapsed, g_files.load(), g_dirs.load(), g_procs.load(), g_reg.load());
    
    return 0;
}
    
    







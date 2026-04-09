// ULTIMATE UNINSTALLER NUCLEAR v4.0 - BRUTAL SPEED
// Compiles: g++ -O3 -std=c++17 -municode ultimate_uninstaller_NUCLEAR_v4.cpp -o ultimate_uninstaller_NUCLEAR.exe -lshlwapi -ladvapi32 -lole32 -luuid -static

#define _WIN32_WINNT 0x0601
#include <windows.h>
#include <stdio.h>
#include <shlwapi.h>
#include <tlhelp32.h>
#include <shlobj.h>
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

std::atomic<long> g_files{0}, g_dirs{0}, g_procs{0}, g_reg{0};
std::vector<std::wstring> g_terms;
std::set<std::wstring> g_paths;
std::mutex g_mtx, g_pmtx;
DWORD g_start = 0;

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

// BRUTAL KILL - Multiple methods, no mercy
void BrutalKill() {
    // Method 1: taskkill with all flags
    for (const auto& t : g_terms) {
        wchar_t c[512];
        // Kill by image name pattern
        swprintf(c, 512, L"taskkill /F /T /IM *%s* >nul 2>&1", t.c_str());
        _wsystem(c);
        // Also try exact and partial matches
        swprintf(c, 512, L"taskkill /F /T /FI \"IMAGENAME eq *%s*\" >nul 2>&1", t.c_str());
        _wsystem(c);
        swprintf(c, 512, L"taskkill /F /T /FI \"WINDOWTITLE eq *%s*\" >nul 2>&1", t.c_str());
        _wsystem(c);
    }
    
    // Method 2: Direct API termination
    HANDLE snap = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
    if (snap != INVALID_HANDLE_VALUE) {
        PROCESSENTRY32W pe = {sizeof(pe)};
        if (Process32FirstW(snap, &pe)) {
            do {
                if (pe.th32ProcessID == GetCurrentProcessId()) continue;
                if (Match(pe.szExeFile)) {
                    HANDLE h = OpenProcess(PROCESS_TERMINATE | SYNCHRONIZE, FALSE, pe.th32ProcessID);
                    if (h) {
                        TerminateProcess(h, 1);
                        WaitForSingleObject(h, 100);
                        g_procs++;
                        CloseHandle(h);
                    }
                }
            } while (Process32NextW(snap, &pe));
        }
        CloseHandle(snap);
    }
    
    // Method 3: Kill by window enumeration
    EnumWindows([](HWND hwnd, LPARAM) -> BOOL {
        wchar_t title[256] = {0}, cls[256] = {0};
        GetWindowTextW(hwnd, title, 256);
        GetClassNameW(hwnd, cls, 256);
        if (Match(title) || Match(cls)) {
            DWORD pid;
            GetWindowThreadProcessId(hwnd, &pid);
            HANDLE h = OpenProcess(PROCESS_TERMINATE, FALSE, pid);
            if (h) { TerminateProcess(h, 1); g_procs++; CloseHandle(h); }
        }
        return TRUE;
    }, 0);
}

// Fast delete
void FastDel(const std::wstring& p) {
    SetFileAttributesW(p.c_str(), FILE_ATTRIBUTE_NORMAL);
    if (DeleteFileW(p.c_str())) g_files++;
    else MoveFileExW(p.c_str(), NULL, MOVEFILE_DELAY_UNTIL_REBOOT), g_files++;
}

// Fast tree delete
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

// Scan directory
void Scan(const std::wstring& p, int d) {
    if (d <= 0 || !Safe(p) || (GetTickCount() - g_start) > 120000) return;
    WIN32_FIND_DATAW fd;
    HANDLE h = FindFirstFileW((p + L"\\*").c_str(), &fd);
    if (h == INVALID_HANDLE_VALUE) return;
    do {
        if (!wcscmp(fd.cFileName, L".") || !wcscmp(fd.cFileName, L"..")) continue;
        std::wstring f = p + L"\\" + fd.cFileName;
        if (!Safe(f)) continue;
        if (fd.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) {
            if (Match(fd.cFileName)) { 
                wprintf(L"  [NUKE] %s\n", f.c_str());
                DelTree(f); 
                RemoveDirectoryW(f.c_str()); 
                g_dirs++; 
            }
            else Scan(f, d - 1);
        } else if (Match(fd.cFileName)) {
            wprintf(L"  [DEL] %s\n", f.c_str());
            FastDel(f);
        }
    } while (FindNextFileW(h, &fd));
    FindClose(h);
}

// Registry paths
void RegClean() {
    wprintf(L"[REG] Cleaning...\n");
    const HKEY H[] = {HKEY_LOCAL_MACHINE, HKEY_CURRENT_USER, HKEY_CLASSES_ROOT};
    const wchar_t* P[] = {L"SOFTWARE", L"SOFTWARE\\WOW6432Node", 
        L"SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Uninstall",
        L"SOFTWARE\\WOW6432Node\\Microsoft\\Windows\\CurrentVersion\\Uninstall",
        L"SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Run",
        L"SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\RunOnce",
        L"SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\App Paths",
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
                    wprintf(L"  [DEL] %s\\%s\n", P[pi], k.c_str());
                    RegDeleteTreeW(hp, k.c_str());
                    g_reg++;
                    RegCloseKey(hp);
                }
            }
        }
    }
    
    // Clean Run values
    for (int hi = 0; hi < 2; hi++) {
        HKEY hk;
        if (RegOpenKeyExW(hi ? HKEY_CURRENT_USER : HKEY_LOCAL_MACHINE, 
            L"SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Run", 0, KEY_READ | KEY_WRITE, &hk) != ERROR_SUCCESS) continue;
        std::vector<std::wstring> del;
        wchar_t vn[256], vd[2048]; DWORD ns, ds, t, i = 0;
        while (ns = 256, ds = sizeof(vd), RegEnumValueW(hk, i++, vn, &ns, 0, &t, (LPBYTE)vd, &ds) == ERROR_SUCCESS)
            if (t == REG_SZ && (Match(vn) || Match(vd))) del.push_back(vn);
        for (const auto& v : del) { RegDeleteValueW(hk, v.c_str()); g_reg++; }
        RegCloseKey(hk);
    }
}

// Find install paths from registry
void FindPaths() {
    wprintf(L"[FIND] Install paths...\n");
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
                        wprintf(L"  [FOUND] %s\n", dn);
                        std::lock_guard<std::mutex> lk(g_pmtx);
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

// Shortcuts
void Shortcuts() {
    wprintf(L"[SHORTCUTS] Removing...\n");
    wchar_t p[MAX_PATH];
    std::vector<std::wstring> dirs;
    if (SHGetFolderPathW(0, CSIDL_COMMON_DESKTOPDIRECTORY, 0, 0, p) == S_OK) dirs.push_back(p);
    if (SHGetFolderPathW(0, CSIDL_DESKTOP, 0, 0, p) == S_OK) dirs.push_back(p);
    if (SHGetFolderPathW(0, CSIDL_COMMON_PROGRAMS, 0, 0, p) == S_OK) dirs.push_back(p);
    if (SHGetFolderPathW(0, CSIDL_PROGRAMS, 0, 0, p) == S_OK) dirs.push_back(p);
    if (SHGetFolderPathW(0, CSIDL_APPDATA, 0, 0, p) == S_OK) {
        dirs.push_back(std::wstring(p) + L"\\Microsoft\\Internet Explorer\\Quick Launch\\User Pinned\\TaskBar");
        dirs.push_back(std::wstring(p) + L"\\Microsoft\\Internet Explorer\\Quick Launch\\User Pinned\\StartMenu");
    }
    for (const auto& d : dirs) Scan(d, 3);
}

// Services
void Services() {
    wprintf(L"[SERVICES] Removing...\n");
    for (const auto& t : g_terms) {
        wchar_t c[256];
        swprintf(c, 256, L"sc stop \"%s\" >nul 2>&1 & sc delete \"%s\" >nul 2>&1", t.c_str(), t.c_str());
        _wsystem(c);
    }
    
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
                if (h) {
                    SERVICE_STATUS st;
                    ControlService(h, SERVICE_CONTROL_STOP, &st);
                    DeleteService(h);
                    CloseHandle(h);
                    wprintf(L"  [DEL] %s\n", sv[i].lpServiceName);
                }
            }
        }
    }
    CloseServiceHandle(scm);
}

// Tasks & Firewall
void TasksFW() {
    wprintf(L"[TASKS/FW] Cleaning...\n");
    for (const auto& t : g_terms) {
        wchar_t c[256];
        swprintf(c, 256, L"schtasks /Delete /TN \"*%s*\" /F >nul 2>&1", t.c_str());
        _wsystem(c);
        swprintf(c, 256, L"netsh advfirewall firewall delete rule name=all program=\"*%s*\" >nul 2>&1", t.c_str());
        _wsystem(c);
    }
}

// Restart explorer to clear tray
void RestartExplorer() {
    wprintf(L"[TRAY] Clearing system tray...\n");
    _wsystem(L"taskkill /F /IM explorer.exe >nul 2>&1");
    Sleep(500);
    ShellExecuteW(0, L"open", L"explorer.exe", 0, 0, SW_SHOW);
}

int wmain(int argc, wchar_t* argv[]) {
    SetConsoleOutputCP(CP_UTF8);
    wprintf(L"\n╔════════════════════════════════════════════════════════╗\n");
    wprintf(L"║  NUCLEAR UNINSTALLER v4.0 - BRUTAL SPEED               ║\n");
    wprintf(L"╚════════════════════════════════════════════════════════╝\n\n");
    
    BOOL admin = FALSE; PSID sid = NULL;
    SID_IDENTIFIER_AUTHORITY auth = SECURITY_NT_AUTHORITY;
    if (AllocateAndInitializeSid(&auth, 2, SECURITY_BUILTIN_DOMAIN_RID, DOMAIN_ALIAS_RID_ADMINS, 0,0,0,0,0,0, &sid)) {
        CheckTokenMembership(0, sid, &admin); FreeSid(sid);
    }
    if (!admin) { wprintf(L"ERROR: Run as Administrator!\n"); return 1; }
    if (argc < 2) { wprintf(L"Usage: %s <app> [term2...]\nExample: %s tweaking \"tweaking.com\"\n", argv[0], argv[0]); return 1; }
    
    wprintf(L"Starting in 1 second...\n\n");
    Sleep(1000);
    
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
    g_start = GetTickCount();
    
    // PHASE 1: BRUTAL KILL (before anything else)
    wprintf(L"[KILL] Phase 1 - Initial termination...\n");
    BrutalKill();
    BrutalKill(); // Double tap
    
    // PHASE 2: Find paths
    FindPaths();
    
    // PHASE 3: Kill again (in case something respawned)
    wprintf(L"[KILL] Phase 2 - Post-discovery kill...\n");
    BrutalKill();
    
    // PHASE 4: Services (might restart processes)
    Services();
    
    // PHASE 5: Kill AGAIN
    BrutalKill();
    
    // PHASE 6: Quick cleanup
    TasksFW();
    Shortcuts();
    RegClean();
    
    // PHASE 7: Nuke discovered paths
    wprintf(L"\n[NUKE] Discovered paths...\n");
    for (const auto& p : g_paths) {
        if (Safe(p)) {
            wprintf(L"  [TARGET] %s\n", p.c_str());
            DelTree(p);
            RemoveDirectoryW(p.c_str());
        }
    }
    
    // PHASE 8: Fast parallel scan
    wprintf(L"\n[SCAN] Filesystem...\n");
    std::vector<std::thread> th;
    th.emplace_back([](){ Scan(L"C:\\Program Files", 8); });
    th.emplace_back([](){ Scan(L"C:\\Program Files (x86)", 8); });
    th.emplace_back([](){ Scan(L"C:\\ProgramData", 8); });
    
    // Scan user profiles
    WIN32_FIND_DATAW fd;
    HANDLE h = FindFirstFileW(L"C:\\Users\\*", &fd);
    if (h != INVALID_HANDLE_VALUE) {
        do {
            if ((fd.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) && wcscmp(fd.cFileName, L".") && wcscmp(fd.cFileName, L"..")) {
                std::wstring u = std::wstring(L"C:\\Users\\") + fd.cFileName;
                th.emplace_back([u](){ Scan(u + L"\\AppData\\Local", 8); });
                th.emplace_back([u](){ Scan(u + L"\\AppData\\Roaming", 8); });
            }
        } while (FindNextFileW(h, &fd));
        FindClose(h);
    }
    
    for (auto& t : th) if (t.joinable()) t.join();
    
    // PHASE 9: FINAL KILL
    wprintf(L"\n[KILL] Final termination...\n");
    BrutalKill();
    BrutalKill();
    BrutalKill();
    
    // PHASE 10: Restart explorer to clear tray
    RestartExplorer();
    
    DWORD elapsed = (GetTickCount() - g_start) / 1000;
    wprintf(L"\n╔════════════════════════════════════════════════════════╗\n");
    wprintf(L"║  DONE in %2lu seconds                                    ║\n", elapsed);
    wprintf(L"║  Files: %5ld  Dirs: %5ld  Procs: %4ld  Reg: %5ld    ║\n", 
            g_files.load(), g_dirs.load(), g_procs.load(), g_reg.load());
    wprintf(L"╚════════════════════════════════════════════════════════╝\n\n");
    
    wprintf(L"Reboot? (Y/N): ");
    wchar_t r; wscanf(L"%lc", &r);
    if (r == L'Y' || r == L'y') system("shutdown /r /t 2");
    return 0;
}

// ULTIMATE UNINSTALLER NUCLEAR v2.0 - C++ EDITION
// LEAVES ABSOLUTELY ZERO TRACES - AS IF THE APP NEVER EXISTED
// Compiles with: g++ -O3 -std=c++17 ultimate_uninstaller_NUCLEAR_v2.cpp -o ultimate_uninstaller_NUCLEAR.exe -lshlwapi -ladvapi32 -lrstrtmgr -lole32 -luuid -loleaut32 -lwbemuuid -lnetapi32 -ltaskschd -static

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
#include <comdef.h>
#include <Wbemidl.h>
#include <taskschd.h>
#include <netfw.h>
#include <msi.h>
#include <aclapi.h>
#include <accctrl.h>

#pragma comment(lib, "shlwapi.lib")
#pragma comment(lib, "advapi32.lib")
#pragma comment(lib, "kernel32.lib")
#pragma comment(lib, "rstrtmgr.lib")
#pragma comment(lib, "ole32.lib")
#pragma comment(lib, "uuid.lib")
#pragma comment(lib, "shell32.lib")
#pragma comment(lib, "propsys.lib")
#pragma comment(lib, "oleaut32.lib")
#pragma comment(lib, "wbemuuid.lib")
#pragma comment(lib, "taskschd.lib")
#pragma comment(lib, "msi.lib")

// NUCLEAR MODE v2.0 - ABSOLUTE ANNIHILATION
#define MAX_TIME_MS (300000)  // 5 minutes for thorough obliteration
#define MAX_THREADS 16

struct Stats {
    volatile LONG filesDeleted;
    volatile LONG dirsDeleted;
    volatile LONG procsKilled;
    volatile LONG regKeysDeleted;
    volatile LONG shortcutsRemoved;
    volatile LONG servicesDeleted;
    volatile LONG tasksDeleted;
    volatile LONG firewallRulesDeleted;
    volatile LONG msiProductsRemoved;
};

Stats g_stats = {0};
DWORD g_startTime = 0;
std::wstring g_appName;
std::vector<std::wstring> g_searchTerms;
std::set<std::wstring> g_discoveredPaths;
BOOL g_verbose = FALSE;

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
    L"\\Windows\\System32\\drivers\\etc\\",
    L"\\Windows\\Fonts\\",
    L"\\Windows\\assembly\\",
    NULL
};

// Protected process names that should never be killed
const wchar_t* PROTECTED_PROCESSES[] = {
    L"System",
    L"Registry",
    L"smss.exe",
    L"csrss.exe",
    L"wininit.exe",
    L"services.exe",
    L"lsass.exe",
    L"svchost.exe",
    L"dwm.exe",
    L"explorer.exe",
    L"winlogon.exe",
    L"fontdrvhost.exe",
    L"sihost.exe",
    L"taskhostw.exe",
    L"RuntimeBroker.exe",
    L"conhost.exe",
    L"ctfmon.exe",
    L"SearchIndexer.exe",
    L"SecurityHealthService.exe",
    L"MsMpEng.exe",
    L"NisSrv.exe",
    NULL
};

inline BOOL IsTimedOut() {
    return (GetTickCount() - g_startTime) > MAX_TIME_MS;
}

inline std::wstring ToLower(const std::wstring& str) {
    std::wstring result = str;
    for (auto& c : result) {
        c = towlower(c);
    }
    return result;
}

inline BOOL FastMatch(const std::wstring& str, const std::wstring& pattern) {
    return ToLower(str).find(ToLower(pattern)) != std::wstring::npos;
}

inline BOOL IsProtectedPath(const std::wstring& path) {
    if (IsTimedOut()) return TRUE;

    std::wstring lowerPath = ToLower(path);

    for (int i = 0; PROTECTED_PATTERNS[i]; i++) {
        if (lowerPath.find(ToLower(PROTECTED_PATTERNS[i])) != std::wstring::npos) {
            return TRUE;
        }
    }

    // Allow app-specific WinSxS cleanup
    if (lowerPath.find(L"\\windows\\winsxs\\") != std::wstring::npos) {
        for (const auto& term : g_searchTerms) {
            if (lowerPath.find(ToLower(term)) != std::wstring::npos) {
                return FALSE;
            }
        }
        return TRUE;
    }

    // Allow app-specific servicing packages
    if (lowerPath.find(L"\\windows\\servicing\\packages\\") != std::wstring::npos) {
        for (const auto& term : g_searchTerms) {
            if (lowerPath.find(ToLower(term)) != std::wstring::npos) {
                return FALSE;
            }
        }
        return TRUE;
    }

    return FALSE;
}

inline BOOL IsProtectedProcess(const std::wstring& procName) {
    std::wstring lower = ToLower(procName);
    for (int i = 0; PROTECTED_PROCESSES[i]; i++) {
        if (lower == ToLower(PROTECTED_PROCESSES[i])) {
            return TRUE;
        }
    }
    return FALSE;
}

inline BOOL MatchesAnyTerm(const std::wstring& str) {
    std::wstring lowerStr = ToLower(str);
    for (const auto& term : g_searchTerms) {
        if (lowerStr.find(ToLower(term)) != std::wstring::npos) {
            return TRUE;
        }
    }
    return FALSE;
}

// NUCLEAR: Take ownership and reset permissions
BOOL TakeOwnershipAndResetPermissions(const std::wstring& path) {
    HANDLE token;
    if (!OpenProcessToken(GetCurrentProcess(), TOKEN_ADJUST_PRIVILEGES | TOKEN_QUERY, &token)) {
        return FALSE;
    }

    TOKEN_PRIVILEGES tp;
    tp.PrivilegeCount = 1;
    tp.Privileges[0].Attributes = SE_PRIVILEGE_ENABLED;
    LookupPrivilegeValueW(NULL, SE_TAKE_OWNERSHIP_NAME, &tp.Privileges[0].Luid);
    AdjustTokenPrivileges(token, FALSE, &tp, 0, NULL, NULL);

    LookupPrivilegeValueW(NULL, SE_RESTORE_NAME, &tp.Privileges[0].Luid);
    AdjustTokenPrivileges(token, FALSE, &tp, 0, NULL, NULL);
    CloseHandle(token);

    // Set owner to Administrators
    PSID adminSID = NULL;
    SID_IDENTIFIER_AUTHORITY ntAuth = SECURITY_NT_AUTHORITY;
    if (AllocateAndInitializeSid(&ntAuth, 2, SECURITY_BUILTIN_DOMAIN_RID,
                                  DOMAIN_ALIAS_RID_ADMINS, 0, 0, 0, 0, 0, 0, &adminSID)) {
        SetNamedSecurityInfoW((LPWSTR)path.c_str(), SE_FILE_OBJECT, OWNER_SECURITY_INFORMATION,
                              adminSID, NULL, NULL, NULL);
        FreeSid(adminSID);
    }

    // Grant full control
    SetFileAttributesW(path.c_str(), FILE_ATTRIBUTE_NORMAL);
    return TRUE;
}

// NUCLEAR: Kill ALL matching processes with EXTREME prejudice
void NuclearKillProcesses() {
    wprintf(L"[NUCLEAR] Terminating all related processes (Round 1)...\n");

    // First pass: taskkill via command line for maximum effectiveness
    for (const auto& term : g_searchTerms) {
        wchar_t cmd[512];
        swprintf(cmd, 512, L"taskkill /F /IM *%s* 2>nul", term.c_str());
        _wsystem(cmd);
    }

    Sleep(500);

    // Second pass: Direct API termination
    for (int round = 0; round < 3; round++) {
        HANDLE snap = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
        if (snap == INVALID_HANDLE_VALUE) continue;

        PROCESSENTRY32W pe = {sizeof(PROCESSENTRY32W)};
        if (Process32FirstW(snap, &pe)) {
            do {
                if (pe.th32ProcessID == GetCurrentProcessId()) continue;
                if (IsProtectedProcess(pe.szExeFile)) continue;

                if (MatchesAnyTerm(pe.szExeFile)) {
                    // Try with different access levels
                    HANDLE h = OpenProcess(PROCESS_TERMINATE, FALSE, pe.th32ProcessID);
                    if (!h) {
                        h = OpenProcess(PROCESS_ALL_ACCESS, FALSE, pe.th32ProcessID);
                    }
                    if (h) {
                        wprintf(L"  [KILL] %s (PID: %lu)\n", pe.szExeFile, pe.th32ProcessID);
                        TerminateProcess(h, 1);
                        WaitForSingleObject(h, 1000);
                        InterlockedIncrement(&g_stats.procsKilled);
                        CloseHandle(h);
                    }
                }
            } while (Process32NextW(snap, &pe));
        }
        CloseHandle(snap);
        Sleep(300);
    }

    // Third pass: Kill by window titles
    wprintf(L"[NUCLEAR] Searching for related windows...\n");
    struct EnumData {
        std::vector<HWND>* windows;
    };
    std::vector<HWND> matchingWindows;
    EnumData data = {&matchingWindows};

    EnumWindows([](HWND hwnd, LPARAM lParam) -> BOOL {
        EnumData* pData = (EnumData*)lParam;
        wchar_t title[512];
        if (GetWindowTextW(hwnd, title, 512) > 0) {
            if (MatchesAnyTerm(title)) {
                pData->windows->push_back(hwnd);
            }
        }
        return TRUE;
    }, (LPARAM)&data);

    for (HWND hwnd : matchingWindows) {
        DWORD pid;
        GetWindowThreadProcessId(hwnd, &pid);
        if (pid != GetCurrentProcessId()) {
            HANDLE h = OpenProcess(PROCESS_TERMINATE, FALSE, pid);
            if (h) {
                wchar_t title[512];
                GetWindowTextW(hwnd, title, 512);
                wprintf(L"  [KILL BY WINDOW] \"%s\" (PID: %lu)\n", title, pid);
                TerminateProcess(h, 1);
                InterlockedIncrement(&g_stats.procsKilled);
                CloseHandle(h);
            }
        }
    }
}

// NUCLEAR: Query WMI for installed products
void NuclearQueryWMI() {
    wprintf(L"[NUCLEAR] Querying WMI for installed products...\n");

    CoInitializeEx(0, COINIT_MULTITHREADED);

    IWbemLocator* locator = NULL;
    IWbemServices* services = NULL;

    HRESULT hr = CoCreateInstance(CLSID_WbemLocator, 0, CLSCTX_INPROC_SERVER,
                                  IID_IWbemLocator, (LPVOID*)&locator);
    if (FAILED(hr)) {
        wprintf(L"  [WARN] Failed to create WMI locator\n");
        return;
    }

    hr = locator->ConnectServer(_bstr_t(L"ROOT\\CIMV2"), NULL, NULL, 0, 0, 0, 0, &services);
    if (FAILED(hr)) {
        locator->Release();
        wprintf(L"  [WARN] Failed to connect to WMI\n");
        return;
    }

    CoSetProxyBlanket(services, RPC_C_AUTHN_WINNT, RPC_C_AUTHZ_NONE, NULL,
                      RPC_C_AUTHN_LEVEL_CALL, RPC_C_IMP_LEVEL_IMPERSONATE, NULL, EOAC_NONE);

    IEnumWbemClassObject* enumerator = NULL;
    hr = services->ExecQuery(_bstr_t(L"WQL"),
                             _bstr_t(L"SELECT * FROM Win32_Product"),
                             WBEM_FLAG_FORWARD_ONLY | WBEM_FLAG_RETURN_IMMEDIATELY,
                             NULL, &enumerator);

    if (SUCCEEDED(hr)) {
        IWbemClassObject* obj = NULL;
        ULONG returned = 0;

        while (enumerator->Next(WBEM_INFINITE, 1, &obj, &returned) == S_OK) {
            VARIANT vtName, vtPath, vtIdentifier;
            VariantInit(&vtName);
            VariantInit(&vtPath);
            VariantInit(&vtIdentifier);

            obj->Get(L"Name", 0, &vtName, 0, 0);
            obj->Get(L"InstallLocation", 0, &vtPath, 0, 0);
            obj->Get(L"IdentifyingNumber", 0, &vtIdentifier, 0, 0);

            if (vtName.vt == VT_BSTR && MatchesAnyTerm(vtName.bstrVal)) {
                wprintf(L"  [WMI PRODUCT] %s\n", vtName.bstrVal);

                if (vtPath.vt == VT_BSTR && vtPath.bstrVal && wcslen(vtPath.bstrVal) > 0) {
                    wprintf(L"    Install Path: %s\n", vtPath.bstrVal);
                    g_discoveredPaths.insert(vtPath.bstrVal);
                }

                // Try to uninstall via MSI
                if (vtIdentifier.vt == VT_BSTR && vtIdentifier.bstrVal) {
                    wprintf(L"    [MSI UNINSTALL] %s\n", vtIdentifier.bstrVal);
                    wchar_t cmd[1024];
                    swprintf(cmd, 1024, L"msiexec /x %s /qn /norestart", vtIdentifier.bstrVal);
                    _wsystem(cmd);
                    InterlockedIncrement(&g_stats.msiProductsRemoved);
                }
            }

            VariantClear(&vtName);
            VariantClear(&vtPath);
            VariantClear(&vtIdentifier);
            obj->Release();
        }
        enumerator->Release();
    }

    services->Release();
    locator->Release();
}

// NUCLEAR: Query registry for install paths
void NuclearQueryRegistryPaths() {
    wprintf(L"[NUCLEAR] Searching registry for install paths...\n");

    const wchar_t* uninstallPaths[] = {
        L"SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Uninstall",
        L"SOFTWARE\\WOW6432Node\\Microsoft\\Windows\\CurrentVersion\\Uninstall",
        NULL
    };

    const HKEY hives[] = {HKEY_LOCAL_MACHINE, HKEY_CURRENT_USER};

    for (int h = 0; h < 2; h++) {
        for (int p = 0; uninstallPaths[p]; p++) {
            HKEY hKey;
            if (RegOpenKeyExW(hives[h], uninstallPaths[p], 0, KEY_READ | KEY_WOW64_64KEY, &hKey) == ERROR_SUCCESS) {
                DWORD index = 0;
                wchar_t keyName[512];
                DWORD keyNameSize;

                while (index < 10000) {
                    keyNameSize = 512;
                    if (RegEnumKeyExW(hKey, index++, keyName, &keyNameSize, NULL, NULL, NULL, NULL) != ERROR_SUCCESS)
                        break;

                    HKEY hSubKey;
                    std::wstring fullPath = std::wstring(uninstallPaths[p]) + L"\\" + keyName;
                    if (RegOpenKeyExW(hives[h], fullPath.c_str(), 0, KEY_READ | KEY_WOW64_64KEY, &hSubKey) == ERROR_SUCCESS) {
                        wchar_t displayName[512] = {0};
                        wchar_t installLocation[1024] = {0};
                        wchar_t uninstallString[2048] = {0};
                        DWORD size;

                        size = sizeof(displayName);
                        RegQueryValueExW(hSubKey, L"DisplayName", NULL, NULL, (LPBYTE)displayName, &size);

                        size = sizeof(installLocation);
                        RegQueryValueExW(hSubKey, L"InstallLocation", NULL, NULL, (LPBYTE)installLocation, &size);

                        size = sizeof(uninstallString);
                        RegQueryValueExW(hSubKey, L"UninstallString", NULL, NULL, (LPBYTE)uninstallString, &size);

                        if (MatchesAnyTerm(displayName) || MatchesAnyTerm(keyName)) {
                            wprintf(L"  [REGISTRY] %s\n", displayName);

                            if (wcslen(installLocation) > 0) {
                                wprintf(L"    Install Path: %s\n", installLocation);
                                g_discoveredPaths.insert(installLocation);
                            }

                            // Extract path from uninstall string
                            if (wcslen(uninstallString) > 0) {
                                std::wstring uninstStr = uninstallString;
                                size_t pos = uninstStr.find(L".exe");
                                if (pos != std::wstring::npos) {
                                    std::wstring exePath = uninstStr.substr(0, pos + 4);
                                    // Remove quotes
                                    if (exePath[0] == L'"') exePath = exePath.substr(1);
                                    // Get directory
                                    size_t lastSlash = exePath.rfind(L'\\');
                                    if (lastSlash != std::wstring::npos) {
                                        std::wstring dir = exePath.substr(0, lastSlash);
                                        wprintf(L"    From UninstallString: %s\n", dir.c_str());
                                        g_discoveredPaths.insert(dir);
                                    }
                                }
                            }
                        }

                        RegCloseKey(hSubKey);
                    }
                }
                RegCloseKey(hKey);
            }
        }
    }
}

// NUCLEAR: Delete scheduled tasks
void NuclearDeleteScheduledTasks() {
    wprintf(L"[NUCLEAR] Obliterating scheduled tasks...\n");

    CoInitializeEx(NULL, COINIT_MULTITHREADED);

    ITaskService* taskService = NULL;
    HRESULT hr = CoCreateInstance(CLSID_TaskScheduler, NULL, CLSCTX_INPROC_SERVER,
                                  IID_ITaskService, (void**)&taskService);
    if (FAILED(hr)) return;

    hr = taskService->Connect(_variant_t(), _variant_t(), _variant_t(), _variant_t());
    if (FAILED(hr)) {
        taskService->Release();
        return;
    }

    ITaskFolder* rootFolder = NULL;
    hr = taskService->GetFolder(_bstr_t(L"\\"), &rootFolder);
    if (SUCCEEDED(hr)) {
        IRegisteredTaskCollection* tasks = NULL;
        hr = rootFolder->GetTasks(TASK_ENUM_HIDDEN, &tasks);
        if (SUCCEEDED(hr)) {
            LONG count = 0;
            tasks->get_Count(&count);

            for (LONG i = 1; i <= count; i++) {
                IRegisteredTask* task = NULL;
                hr = tasks->get_Item(_variant_t(i), &task);
                if (SUCCEEDED(hr)) {
                    BSTR name = NULL;
                    task->get_Name(&name);

                    if (name && MatchesAnyTerm(name)) {
                        wprintf(L"  [DELETE TASK] %s\n", name);
                        rootFolder->DeleteTask(_bstr_t(name), 0);
                        InterlockedIncrement(&g_stats.tasksDeleted);
                    }

                    if (name) SysFreeString(name);
                    task->Release();
                }
            }
            tasks->Release();
        }
        rootFolder->Release();
    }

    taskService->Release();
}

// NUCLEAR: Delete firewall rules
void NuclearDeleteFirewallRules() {
    wprintf(L"[NUCLEAR] Removing firewall rules...\n");

    // Use netsh for reliability
    for (const auto& term : g_searchTerms) {
        wchar_t cmd[512];
        swprintf(cmd, 512, L"netsh advfirewall firewall delete rule name=all program=\"*%s*\" 2>nul", term.c_str());
        _wsystem(cmd);
        InterlockedIncrement(&g_stats.firewallRulesDeleted);
    }
}

// NUCLEAR: Clean environment variables
void NuclearCleanEnvironmentVariables() {
    wprintf(L"[NUCLEAR] Cleaning environment variables...\n");

    const HKEY envKeys[] = {HKEY_CURRENT_USER, HKEY_LOCAL_MACHINE};
    const wchar_t* envPaths[] = {
        L"Environment",
        L"SYSTEM\\CurrentControlSet\\Control\\Session Manager\\Environment"
    };

    for (int i = 0; i < 2; i++) {
        HKEY hKey;
        if (RegOpenKeyExW(envKeys[i], envPaths[i], 0, KEY_READ | KEY_WRITE, &hKey) == ERROR_SUCCESS) {
            wchar_t valueName[256];
            wchar_t valueData[32767];
            DWORD valueNameSize, valueDataSize;
            DWORD index = 0;
            DWORD type;

            while (TRUE) {
                valueNameSize = 256;
                valueDataSize = sizeof(valueData);
                if (RegEnumValueW(hKey, index, valueName, &valueNameSize, NULL, &type,
                                  (LPBYTE)valueData, &valueDataSize) != ERROR_SUCCESS) break;

                if (type == REG_SZ || type == REG_EXPAND_SZ) {
                    if (MatchesAnyTerm(valueName) || MatchesAnyTerm(valueData)) {
                        wprintf(L"  [DELETE ENVVAR] %s\n", valueName);
                        RegDeleteValueW(hKey, valueName);
                        continue;  // Don't increment, list shifted
                    }
                }
                index++;
            }
            RegCloseKey(hKey);
        }
    }

    // Clean PATH variable
    HKEY hKey;
    if (RegOpenKeyExW(HKEY_LOCAL_MACHINE,
                      L"SYSTEM\\CurrentControlSet\\Control\\Session Manager\\Environment",
                      0, KEY_READ | KEY_WRITE, &hKey) == ERROR_SUCCESS) {
        wchar_t pathValue[32767];
        DWORD size = sizeof(pathValue);
        if (RegQueryValueExW(hKey, L"Path", NULL, NULL, (LPBYTE)pathValue, &size) == ERROR_SUCCESS) {
            std::wstring path = pathValue;
            std::wstring newPath;
            size_t pos = 0, found;

            while ((found = path.find(L';', pos)) != std::wstring::npos) {
                std::wstring segment = path.substr(pos, found - pos);
                BOOL shouldRemove = FALSE;
                for (const auto& term : g_searchTerms) {
                    if (FastMatch(segment, term)) {
                        wprintf(L"  [CLEAN PATH] Removing: %s\n", segment.c_str());
                        shouldRemove = TRUE;
                        break;
                    }
                }
                if (!shouldRemove && !segment.empty()) {
                    if (!newPath.empty()) newPath += L';';
                    newPath += segment;
                }
                pos = found + 1;
            }

            // Handle last segment
            if (pos < path.length()) {
                std::wstring segment = path.substr(pos);
                BOOL shouldRemove = FALSE;
                for (const auto& term : g_searchTerms) {
                    if (FastMatch(segment, term)) {
                        shouldRemove = TRUE;
                        break;
                    }
                }
                if (!shouldRemove && !segment.empty()) {
                    if (!newPath.empty()) newPath += L';';
                    newPath += segment;
                }
            }

            if (newPath != path) {
                RegSetValueExW(hKey, L"Path", 0, REG_EXPAND_SZ,
                              (LPBYTE)newPath.c_str(), (DWORD)((newPath.length() + 1) * sizeof(wchar_t)));
            }
        }
        RegCloseKey(hKey);
    }
}

// NUCLEAR: Clean MRU and recent file lists
void NuclearCleanMRU() {
    wprintf(L"[NUCLEAR] Cleaning MRU and recent file lists...\n");

    const wchar_t* mruPaths[] = {
        L"SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Explorer\\ComDlg32\\OpenSaveMRU",
        L"SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Explorer\\ComDlg32\\OpenSavePidlMRU",
        L"SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Explorer\\RunMRU",
        L"SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Explorer\\RecentDocs",
        L"SOFTWARE\\Microsoft\\Office\\16.0\\Word\\File MRU",
        L"SOFTWARE\\Microsoft\\Office\\16.0\\Excel\\File MRU",
        NULL
    };

    for (int i = 0; mruPaths[i]; i++) {
        HKEY hKey;
        if (RegOpenKeyExW(HKEY_CURRENT_USER, mruPaths[i], 0, KEY_READ | KEY_WRITE, &hKey) == ERROR_SUCCESS) {
            // Read all values and delete matching ones
            wchar_t valueName[256];
            wchar_t valueData[2048];
            DWORD valueNameSize, valueDataSize;
            DWORD index = 0;
            DWORD type;

            while (TRUE) {
                valueNameSize = 256;
                valueDataSize = sizeof(valueData);
                if (RegEnumValueW(hKey, index, valueName, &valueNameSize, NULL, &type,
                                  (LPBYTE)valueData, &valueDataSize) != ERROR_SUCCESS) break;

                BOOL shouldDelete = FALSE;
                if (type == REG_SZ || type == REG_EXPAND_SZ) {
                    if (MatchesAnyTerm(valueData)) {
                        shouldDelete = TRUE;
                    }
                }

                if (shouldDelete) {
                    wprintf(L"  [DELETE MRU] %s\n", mruPaths[i]);
                    RegDeleteValueW(hKey, valueName);
                } else {
                    index++;
                }
            }
            RegCloseKey(hKey);
        }
    }

    // Clean Recent folder
    wchar_t recentPath[MAX_PATH];
    if (SHGetFolderPathW(NULL, CSIDL_RECENT, NULL, 0, recentPath) == S_OK) {
        WIN32_FIND_DATAW fd;
        std::wstring search = std::wstring(recentPath) + L"\\*";
        HANDLE h = FindFirstFileW(search.c_str(), &fd);
        if (h != INVALID_HANDLE_VALUE) {
            do {
                if (wcscmp(fd.cFileName, L".") == 0 || wcscmp(fd.cFileName, L"..") == 0)
                    continue;

                if (MatchesAnyTerm(fd.cFileName)) {
                    std::wstring fullPath = std::wstring(recentPath) + L"\\" + fd.cFileName;
                    wprintf(L"  [DELETE RECENT] %s\n", fd.cFileName);
                    DeleteFileW(fullPath.c_str());
                }
            } while (FindNextFileW(h, &fd));
            FindClose(h);
        }
    }
}

// NUCLEAR: Clean COM/TypeLib registrations
void NuclearCleanCOM() {
    wprintf(L"[NUCLEAR] Cleaning COM and TypeLib registrations...\n");

    const wchar_t* comPaths[] = {
        L"SOFTWARE\\Classes\\CLSID",
        L"SOFTWARE\\Classes\\TypeLib",
        L"SOFTWARE\\Classes\\Interface",
        L"SOFTWARE\\Classes\\AppID",
        L"SOFTWARE\\WOW6432Node\\Classes\\CLSID",
        L"SOFTWARE\\WOW6432Node\\Classes\\TypeLib",
        NULL
    };

    for (int i = 0; comPaths[i]; i++) {
        HKEY hKey;
        if (RegOpenKeyExW(HKEY_LOCAL_MACHINE, comPaths[i], 0, KEY_READ, &hKey) == ERROR_SUCCESS) {
            DWORD index = 0;
            wchar_t keyName[512];
            DWORD keyNameSize;

            while (index < 50000) {
                keyNameSize = 512;
                if (RegEnumKeyExW(hKey, index, keyName, &keyNameSize, NULL, NULL, NULL, NULL) != ERROR_SUCCESS)
                    break;

                // Check subkey for matching data
                HKEY hSubKey;
                if (RegOpenKeyExW(hKey, keyName, 0, KEY_READ, &hSubKey) == ERROR_SUCCESS) {
                    wchar_t defaultValue[1024] = {0};
                    DWORD size = sizeof(defaultValue);
                    RegQueryValueExW(hSubKey, NULL, NULL, NULL, (LPBYTE)defaultValue, &size);

                    // Also check InprocServer32 and LocalServer32
                    HKEY hServer;
                    wchar_t serverPath[1024] = {0};
                    if (RegOpenKeyExW(hSubKey, L"InprocServer32", 0, KEY_READ, &hServer) == ERROR_SUCCESS) {
                        size = sizeof(serverPath);
                        RegQueryValueExW(hServer, NULL, NULL, NULL, (LPBYTE)serverPath, &size);
                        RegCloseKey(hServer);
                    }
                    if (serverPath[0] == 0 && RegOpenKeyExW(hSubKey, L"LocalServer32", 0, KEY_READ, &hServer) == ERROR_SUCCESS) {
                        size = sizeof(serverPath);
                        RegQueryValueExW(hServer, NULL, NULL, NULL, (LPBYTE)serverPath, &size);
                        RegCloseKey(hServer);
                    }

                    if (MatchesAnyTerm(defaultValue) || MatchesAnyTerm(serverPath)) {
                        wprintf(L"  [DELETE COM] %s\\%s\n", comPaths[i], keyName);
                        RegCloseKey(hSubKey);
                        RegCloseKey(hKey);

                        HKEY hParent;
                        if (RegOpenKeyExW(HKEY_LOCAL_MACHINE, comPaths[i], 0, DELETE | KEY_ENUMERATE_SUB_KEYS, &hParent) == ERROR_SUCCESS) {
                            RegDeleteTreeW(hParent, keyName);
                            InterlockedIncrement(&g_stats.regKeysDeleted);
                            RegCloseKey(hParent);
                        }

                        if (RegOpenKeyExW(HKEY_LOCAL_MACHINE, comPaths[i], 0, KEY_READ, &hKey) != ERROR_SUCCESS)
                            break;
                        continue;
                    }

                    RegCloseKey(hSubKey);
                }
                index++;
            }
            RegCloseKey(hKey);
        }
    }
}

// NUCLEAR: Services obliteration
void NuclearDeleteServices() {
    wprintf(L"[NUCLEAR] Obliterating services...\n");

    // First stop services via sc command
    for (const auto& term : g_searchTerms) {
        wchar_t cmd[512];
        swprintf(cmd, 512, L"sc stop \"%s\" 2>nul", term.c_str());
        _wsystem(cmd);
    }

    SC_HANDLE scm = OpenSCManagerW(NULL, NULL, SC_MANAGER_ALL_ACCESS);
    if (!scm) return;

    DWORD bytesNeeded = 0;
    DWORD servicesReturned = 0;
    DWORD resumeHandle = 0;

    EnumServicesStatusExW(scm, SC_ENUM_PROCESS_INFO, SERVICE_WIN32 | SERVICE_DRIVER,
                          SERVICE_STATE_ALL, NULL, 0, &bytesNeeded, &servicesReturned, &resumeHandle, NULL);

    BYTE* buffer = (BYTE*)malloc(bytesNeeded + 1000);
    if (!buffer) {
        CloseServiceHandle(scm);
        return;
    }

    if (EnumServicesStatusExW(scm, SC_ENUM_PROCESS_INFO, SERVICE_WIN32 | SERVICE_DRIVER,
                              SERVICE_STATE_ALL, buffer, bytesNeeded + 1000, &bytesNeeded, &servicesReturned, &resumeHandle, NULL)) {

        ENUM_SERVICE_STATUS_PROCESSW* services = (ENUM_SERVICE_STATUS_PROCESSW*)buffer;

        for (DWORD i = 0; i < servicesReturned && !IsTimedOut(); i++) {
            if (MatchesAnyTerm(services[i].lpServiceName) || MatchesAnyTerm(services[i].lpDisplayName)) {
                wprintf(L"  [DELETE SERVICE] %s (%s)\n", services[i].lpServiceName, services[i].lpDisplayName);
                SC_HANDLE svc = OpenServiceW(scm, services[i].lpServiceName, SERVICE_ALL_ACCESS);
                if (svc) {
                    SERVICE_STATUS status;
                    ControlService(svc, SERVICE_CONTROL_STOP, &status);
                    Sleep(500);
                    DeleteService(svc);
                    InterlockedIncrement(&g_stats.servicesDeleted);
                    CloseServiceHandle(svc);
                }

                // Also delete from registry
                std::wstring regPath = L"SYSTEM\\CurrentControlSet\\Services\\" + std::wstring(services[i].lpServiceName);
                RegDeleteTreeW(HKEY_LOCAL_MACHINE, regPath.c_str());
            }
        }
    }

    free(buffer);
    CloseServiceHandle(scm);
}

// NUCLEAR: Remove ALL shortcuts
void NuclearRemoveShortcuts() {
    wprintf(L"[NUCLEAR] Removing all shortcuts and pins...\n");

    wchar_t path[MAX_PATH];
    std::vector<std::wstring> shortcutPaths;

    // Collect all shortcut locations
    if (SHGetFolderPathW(NULL, CSIDL_COMMON_DESKTOPDIRECTORY, NULL, 0, path) == S_OK)
        shortcutPaths.push_back(path);
    if (SHGetFolderPathW(NULL, CSIDL_DESKTOP, NULL, 0, path) == S_OK)
        shortcutPaths.push_back(path);
    if (SHGetFolderPathW(NULL, CSIDL_COMMON_PROGRAMS, NULL, 0, path) == S_OK)
        shortcutPaths.push_back(path);
    if (SHGetFolderPathW(NULL, CSIDL_PROGRAMS, NULL, 0, path) == S_OK)
        shortcutPaths.push_back(path);
    if (SHGetFolderPathW(NULL, CSIDL_COMMON_STARTUP, NULL, 0, path) == S_OK)
        shortcutPaths.push_back(path);
    if (SHGetFolderPathW(NULL, CSIDL_STARTUP, NULL, 0, path) == S_OK)
        shortcutPaths.push_back(path);
    if (SHGetFolderPathW(NULL, CSIDL_APPDATA, NULL, 0, path) == S_OK) {
        shortcutPaths.push_back(std::wstring(path) + L"\\Microsoft\\Internet Explorer\\Quick Launch");
        shortcutPaths.push_back(std::wstring(path) + L"\\Microsoft\\Internet Explorer\\Quick Launch\\User Pinned\\TaskBar");
        shortcutPaths.push_back(std::wstring(path) + L"\\Microsoft\\Internet Explorer\\Quick Launch\\User Pinned\\StartMenu");
    }

    // Scan and delete matching shortcuts
    for (const auto& shortcutPath : shortcutPaths) {
        WIN32_FIND_DATAW fd;
        std::wstring search = shortcutPath + L"\\*";
        HANDLE h = FindFirstFileW(search.c_str(), &fd);
        if (h != INVALID_HANDLE_VALUE) {
            do {
                if (wcscmp(fd.cFileName, L".") == 0 || wcscmp(fd.cFileName, L"..") == 0)
                    continue;

                std::wstring fullPath = shortcutPath + L"\\" + fd.cFileName;

                if (fd.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) {
                    if (MatchesAnyTerm(fd.cFileName)) {
                        wprintf(L"  [DELETE SHORTCUT DIR] %s\n", fullPath.c_str());
                        // Delete recursively
                        WIN32_FIND_DATAW fd2;
                        std::wstring search2 = fullPath + L"\\*";
                        HANDLE h2 = FindFirstFileW(search2.c_str(), &fd2);
                        if (h2 != INVALID_HANDLE_VALUE) {
                            do {
                                if (wcscmp(fd2.cFileName, L".") && wcscmp(fd2.cFileName, L"..")) {
                                    std::wstring file = fullPath + L"\\" + fd2.cFileName;
                                    DeleteFileW(file.c_str());
                                }
                            } while (FindNextFileW(h2, &fd2));
                            FindClose(h2);
                        }
                        RemoveDirectoryW(fullPath.c_str());
                        InterlockedIncrement(&g_stats.shortcutsRemoved);
                    }
                } else {
                    if (MatchesAnyTerm(fd.cFileName)) {
                        wprintf(L"  [DELETE SHORTCUT] %s\n", fullPath.c_str());
                        DeleteFileW(fullPath.c_str());
                        InterlockedIncrement(&g_stats.shortcutsRemoved);
                    }
                }
            } while (FindNextFileW(h, &fd));
            FindClose(h);
        }
    }
}

// NUCLEAR: Force delete with all techniques
BOOL NuclearForceDelete(const std::wstring& path) {
    TakeOwnershipAndResetPermissions(path);
    SetFileAttributesW(path.c_str(), FILE_ATTRIBUTE_NORMAL);

    if (DeleteFileW(path.c_str())) {
        InterlockedIncrement(&g_stats.filesDeleted);
        wprintf(L"  [DELETE FILE] %s\n", path.c_str());
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
                if (!IsProtectedProcess(procs[i].strAppName)) {
                    HANDLE h = OpenProcess(PROCESS_TERMINATE, FALSE, procs[i].Process.dwProcessId);
                    if (h) {
                        wprintf(L"    [UNLOCK] Killing %s holding file\n", procs[i].strAppName);
                        TerminateProcess(h, 1);
                        CloseHandle(h);
                    }
                }
            }
        }
        RmEndSession(session);

        Sleep(200);
        SetFileAttributesW(path.c_str(), FILE_ATTRIBUTE_NORMAL);
        if (DeleteFileW(path.c_str())) {
            InterlockedIncrement(&g_stats.filesDeleted);
            wprintf(L"  [DELETE FILE] %s\n", path.c_str());
            return TRUE;
        }
    }

    // Schedule for boot deletion
    if (MoveFileExW(path.c_str(), NULL, MOVEFILE_DELAY_UNTIL_REBOOT)) {
        wprintf(L"  [SCHEDULE DELETE] %s (on reboot)\n", path.c_str());
        InterlockedIncrement(&g_stats.filesDeleted);
        return TRUE;
    }

    return FALSE;
}

// NUCLEAR: Recursive deletion
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
            TakeOwnershipAndResetPermissions(fullPath);
            SetFileAttributesW(fullPath.c_str(), FILE_ATTRIBUTE_NORMAL);
            if (RemoveDirectoryW(fullPath.c_str())) {
                InterlockedIncrement(&g_stats.dirsDeleted);
                wprintf(L"  [DELETE DIR] %s\n", fullPath.c_str());
            } else {
                MoveFileExW(fullPath.c_str(), NULL, MOVEFILE_DELAY_UNTIL_REBOOT);
                InterlockedIncrement(&g_stats.dirsDeleted);
                wprintf(L"  [SCHEDULE DELETE DIR] %s\n", fullPath.c_str());
            }
        } else {
            NuclearForceDelete(fullPath);
        }
    } while (FindNextFileW(h, &fd) && !IsTimedOut());

    FindClose(h);
}

// NUCLEAR: Deep filesystem scan
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
                wprintf(L"[NUCLEAR] Found matching directory: %s\n", fullPath.c_str());
                NuclearDeleteTree(fullPath);
                TakeOwnershipAndResetPermissions(fullPath);
                SetFileAttributesW(fullPath.c_str(), FILE_ATTRIBUTE_NORMAL);
                if (!RemoveDirectoryW(fullPath.c_str())) {
                    MoveFileExW(fullPath.c_str(), NULL, MOVEFILE_DELAY_UNTIL_REBOOT);
                }
                InterlockedIncrement(&g_stats.dirsDeleted);
            } else {
                NuclearDeepScan(fullPath, depth - 1);
            }
        } else {
            if (MatchesAnyTerm(fd.cFileName)) {
                NuclearForceDelete(fullPath);
            }
        }
    } while (FindNextFileW(h, &fd) && !IsTimedOut());

    FindClose(h);
}

// NUCLEAR: Registry annihilation
void NuclearRegistryClean() {
    wprintf(L"[NUCLEAR] Deep registry obliteration...\n");

    const HKEY hives[] = {
        HKEY_LOCAL_MACHINE,
        HKEY_CURRENT_USER,
        HKEY_USERS,
        HKEY_CLASSES_ROOT
    };
    const wchar_t* hiveNames[] = {L"HKLM", L"HKCU", L"HKU", L"HKCR"};

    const wchar_t* regPaths[] = {
        L"SOFTWARE",
        L"SOFTWARE\\WOW6432Node",
        L"SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Uninstall",
        L"SOFTWARE\\WOW6432Node\\Microsoft\\Windows\\CurrentVersion\\Uninstall",
        L"SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Run",
        L"SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\RunOnce",
        L"SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Explorer\\StartupApproved\\Run",
        L"SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Explorer\\StartupApproved\\Run32",
        L"SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\App Paths",
        L"SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\SharedDLLs",
        L"SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Installer\\Folders",
        L"SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\AppCompatFlags\\Layers",
        L"SYSTEM\\CurrentControlSet\\Services",
        L"SYSTEM\\CurrentControlSet\\Enum\\ROOT",
        L"SOFTWARE\\Classes",
        L"SOFTWARE\\Classes\\Applications",
        L"SOFTWARE\\Classes\\Local Settings\\Software\\Microsoft\\Windows\\Shell\\MuiCache",
        L"SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\Image File Execution Options",
        L"SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Explorer\\FileExts",
        L"SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\UFH\\SHC",
        NULL
    };

    for (int hiveIdx = 0; hiveIdx < 4 && !IsTimedOut(); hiveIdx++) {
        for (int pathIdx = 0; regPaths[pathIdx] && !IsTimedOut(); pathIdx++) {
            HKEY hKey;
            if (RegOpenKeyExW(hives[hiveIdx], regPaths[pathIdx], 0, KEY_READ | KEY_WOW64_64KEY, &hKey) == ERROR_SUCCESS) {
                DWORD index = 0;
                wchar_t keyName[512];
                DWORD keyNameSize;

                while (!IsTimedOut() && index < 10000) {
                    keyNameSize = 512;
                    if (RegEnumKeyExW(hKey, index, keyName, &keyNameSize, NULL, NULL, NULL, NULL) != ERROR_SUCCESS)
                        break;

                    if (MatchesAnyTerm(keyName)) {
                        wprintf(L"  [DELETE KEY] %s\\%s\\%s\n", hiveNames[hiveIdx], regPaths[pathIdx], keyName);
                        RegCloseKey(hKey);

                        HKEY hParent;
                        if (RegOpenKeyExW(hives[hiveIdx], regPaths[pathIdx], 0, DELETE | KEY_ENUMERATE_SUB_KEYS | KEY_WOW64_64KEY, &hParent) == ERROR_SUCCESS) {
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

    // Also clean registry values that match
    wprintf(L"[NUCLEAR] Scanning registry values...\n");
    const wchar_t* valuePaths[] = {
        L"SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Run",
        L"SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\RunOnce",
        L"SOFTWARE\\WOW6432Node\\Microsoft\\Windows\\CurrentVersion\\Run",
        NULL
    };

    for (int hiveIdx = 0; hiveIdx < 2 && !IsTimedOut(); hiveIdx++) {
        for (int pathIdx = 0; valuePaths[pathIdx]; pathIdx++) {
            HKEY hKey;
            if (RegOpenKeyExW(hives[hiveIdx], valuePaths[pathIdx], 0, KEY_READ | KEY_WRITE | KEY_WOW64_64KEY, &hKey) == ERROR_SUCCESS) {
                wchar_t valueName[256];
                wchar_t valueData[2048];
                DWORD valueNameSize, valueDataSize;
                DWORD type;
                DWORD index = 0;

                while (TRUE) {
                    valueNameSize = 256;
                    valueDataSize = sizeof(valueData);
                    if (RegEnumValueW(hKey, index, valueName, &valueNameSize, NULL, &type,
                                      (LPBYTE)valueData, &valueDataSize) != ERROR_SUCCESS) break;

                    if (MatchesAnyTerm(valueName) || (type == REG_SZ && MatchesAnyTerm(valueData))) {
                        wprintf(L"  [DELETE VALUE] %s\\%s = %s\n", valuePaths[pathIdx], valueName, valueData);
                        RegDeleteValueW(hKey, valueName);
                        InterlockedIncrement(&g_stats.regKeysDeleted);
                    } else {
                        index++;
                    }
                }
                RegCloseKey(hKey);
            }
        }
    }
}

// NUCLEAR: Restart Explorer to release handles
void NuclearRestartExplorer() {
    wprintf(L"[NUCLEAR] Restarting Explorer to release handles...\n");

    // Find and terminate explorer
    HANDLE snap = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
    if (snap != INVALID_HANDLE_VALUE) {
        PROCESSENTRY32W pe = {sizeof(PROCESSENTRY32W)};
        if (Process32FirstW(snap, &pe)) {
            do {
                if (_wcsicmp(pe.szExeFile, L"explorer.exe") == 0) {
                    HANDLE h = OpenProcess(PROCESS_TERMINATE, FALSE, pe.th32ProcessID);
                    if (h) {
                        TerminateProcess(h, 0);
                        CloseHandle(h);
                    }
                }
            } while (Process32NextW(snap, &pe));
        }
        CloseHandle(snap);
    }

    Sleep(1000);

    // Restart explorer
    ShellExecuteW(NULL, L"open", L"explorer.exe", NULL, NULL, SW_SHOW);
}

// NUCLEAR: Main obliteration
void NuclearObliterate(const std::wstring& appName, const std::vector<std::wstring>& additionalTerms) {
    g_startTime = GetTickCount();
    g_appName = appName;
    g_searchTerms.clear();
    g_searchTerms.push_back(appName);
    for (const auto& term : additionalTerms) {
        g_searchTerms.push_back(term);
    }
    g_discoveredPaths.clear();

    wprintf(L"\n[NUCLEAR v2.0] Search terms: ");
    for (const auto& term : g_searchTerms) {
        wprintf(L"\"%s\" ", term.c_str());
    }
    wprintf(L"\n\n");

    // Phase 1: Kill all processes (multiple rounds)
    NuclearKillProcesses();
    Sleep(500);

    // Phase 2: Query WMI and registry for install paths
    NuclearQueryWMI();
    NuclearQueryRegistryPaths();

    // Phase 3: Delete services
    NuclearDeleteServices();

    // Phase 4: Delete scheduled tasks
    NuclearDeleteScheduledTasks();

    // Phase 5: Delete firewall rules
    NuclearDeleteFirewallRules();

    // Phase 6: Remove shortcuts
    NuclearRemoveShortcuts();

    // Phase 7: Clean environment variables
    NuclearCleanEnvironmentVariables();

    // Phase 8: Clean MRU/Recent files
    NuclearCleanMRU();

    // Phase 9: Clean COM/TypeLib
    NuclearCleanCOM();

    // Phase 10: Registry obliteration
    NuclearRegistryClean();

    // Phase 11: Delete discovered paths first
    wprintf(L"\n[NUCLEAR] Obliterating discovered install paths...\n");
    for (const auto& path : g_discoveredPaths) {
        if (!IsProtectedPath(path)) {
            wprintf(L"  [DISCOVERED PATH] %s\n", path.c_str());
            NuclearDeleteTree(path);
            TakeOwnershipAndResetPermissions(path);
            RemoveDirectoryW(path.c_str());
        }
    }

    // Phase 12: Filesystem obliteration - C: drive
    wprintf(L"\n[NUCLEAR] Beginning filesystem obliteration...\n");

    const std::vector<std::pair<std::wstring, int>> scanPaths = {
        {L"C:\\Program Files", 20},
        {L"C:\\Program Files (x86)", 20},
        {L"C:\\ProgramData", 20},
        {L"C:\\Users", 20},  // Will scan all users' AppData
        {L"C:\\Windows\\System32\\config\\systemprofile", 10},
        {L"C:\\Windows\\Temp", 10},
        {L"C:\\Windows\\Prefetch", 5},
        {L"C:\\Windows\\Installer", 10},
        {L"C:\\Windows\\SoftwareDistribution\\Download", 10},
        {L"C:\\Windows\\ServiceProfiles", 10},
        {L"C:\\Windows\\Logs", 5},
        {L"C:\\", 3}  // Shallow scan of root
    };

    for (const auto& [path, depth] : scanPaths) {
        if (IsTimedOut()) break;
        wprintf(L"[SCAN] %s (depth %d)\n", path.c_str(), depth);
        NuclearDeepScan(path, depth);
    }

    // Phase 13: Kill processes again
    wprintf(L"\n");
    NuclearKillProcesses();

    // Phase 14: Restart Explorer to release handles
    NuclearRestartExplorer();
    Sleep(2000);

    // Phase 15: Final filesystem pass
    wprintf(L"\n[NUCLEAR] Final cleanup pass...\n");
    for (const auto& path : g_discoveredPaths) {
        if (!IsProtectedPath(path) && GetFileAttributesW(path.c_str()) != INVALID_FILE_ATTRIBUTES) {
            wprintf(L"  [RETRY] %s\n", path.c_str());
            NuclearDeleteTree(path);
            RemoveDirectoryW(path.c_str());
        }
    }

    wprintf(L"\n[NUCLEAR] Obliteration complete!\n");
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
    wprintf(L"╔═══════════════════════════════════════════════════════════════════╗\n");
    wprintf(L"║  ULTIMATE UNINSTALLER NUCLEAR v2.0 - C++ EDITION                  ║\n");
    wprintf(L"║  ABSOLUTE ZERO LEFTOVERS - AS IF IT NEVER EXISTED                 ║\n");
    wprintf(L"╚═══════════════════════════════════════════════════════════════════╝\n\n");

    if (!IsAdmin()) {
        wprintf(L"ERROR: Administrator privileges required!\n");
        wprintf(L"Right-click and 'Run as administrator'\n");
        return 1;
    }

    if (argc < 2) {
        wprintf(L"Usage: ultimate_uninstaller_NUCLEAR.exe <AppName> [Term2] [Term3] ...\n\n");
        wprintf(L"NUCLEAR v2.0 FEATURES:\n");
        wprintf(L"  ✓ WMI product detection & MSI uninstall\n");
        wprintf(L"  ✓ Registry install path discovery\n");
        wprintf(L"  ✓ Scheduled task obliteration\n");
        wprintf(L"  ✓ Firewall rule removal\n");
        wprintf(L"  ✓ COM/TypeLib registry cleanup\n");
        wprintf(L"  ✓ Environment variable cleaning\n");
        wprintf(L"  ✓ MRU/Recent files cleaning\n");
        wprintf(L"  ✓ Service termination & deletion\n");
        wprintf(L"  ✓ Process killing by name AND window title\n");
        wprintf(L"  ✓ Take ownership & reset permissions\n");
        wprintf(L"  ✓ Explorer restart to release handles\n");
        wprintf(L"  ✓ Multi-round process termination\n");
        wprintf(L"  ✓ Discovered path prioritization\n");
        wprintf(L"  ✓ Boot-time deletion for locked files\n\n");
        wprintf(L"Example: ultimate_uninstaller_NUCLEAR.exe tweaking \"tweaking.com\"\n\n");
        return 1;
    }

    wprintf(L"WARNING: This will OBLITERATE all traces. Starting in 3 seconds...\n");
    wprintf(L"Press Ctrl+C to abort.\n\n");
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
            SE_LOAD_DRIVER_NAME,
            SE_SYSTEM_PROFILE_NAME,
            SE_SHUTDOWN_NAME,
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

    // Initialize COM
    CoInitializeEx(0, COINIT_MULTITHREADED);

    // Build search terms
    std::vector<std::wstring> additionalTerms;
    for (int i = 2; i < argc; i++) {
        additionalTerms.push_back(argv[i]);
    }

    DWORD start = GetTickCount();
    memset(&g_stats, 0, sizeof(Stats));

    NuclearObliterate(argv[1], additionalTerms);

    CoUninitialize();

    DWORD elapsed = (GetTickCount() - start) / 1000;

    wprintf(L"\n╔═══════════════════════════════════════════════════════════════════╗\n");
    wprintf(L"║  NUCLEAR OBLITERATION COMPLETE (%3lu seconds)                      ║\n", elapsed);
    wprintf(L"╠═══════════════════════════════════════════════════════════════════╣\n");
    wprintf(L"║  Files Deleted:      %6ld                                       ║\n", g_stats.filesDeleted);
    wprintf(L"║  Dirs Deleted:       %6ld                                       ║\n", g_stats.dirsDeleted);
    wprintf(L"║  Processes Killed:   %6ld                                       ║\n", g_stats.procsKilled);
    wprintf(L"║  Registry Keys:      %6ld                                       ║\n", g_stats.regKeysDeleted);
    wprintf(L"║  Services Deleted:   %6ld                                       ║\n", g_stats.servicesDeleted);
    wprintf(L"║  Tasks Deleted:      %6ld                                       ║\n", g_stats.tasksDeleted);
    wprintf(L"║  Shortcuts Removed:  %6ld                                       ║\n", g_stats.shortcutsRemoved);
    wprintf(L"║  Firewall Rules:     %6ld                                       ║\n", g_stats.firewallRulesDeleted);
    wprintf(L"║  MSI Products:       %6ld                                       ║\n", g_stats.msiProductsRemoved);
    wprintf(L"╚═══════════════════════════════════════════════════════════════════╝\n\n");

    wprintf(L"Some files may require reboot to complete deletion.\n");
    wprintf(L"Reboot now? (Y/N): ");

    wchar_t response;
    wscanf(L"%lc", &response);
    if (response == L'Y' || response == L'y') {
        wprintf(L"\nRebooting in 5 seconds...\n");
        system("shutdown /r /t 5");
    }

    return 0;
}

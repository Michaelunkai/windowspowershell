#define _WIN32_WINNT 0x0601
#define UNICODE
#define _UNICODE

#include <windows.h>
#include <stdio.h>
#include <wchar.h>

BOOL FastMatch(const wchar_t* str, const wchar_t* pattern) {
    wchar_t upperStr[MAX_PATH * 2];
    wchar_t upperPat[256];
    wcscpy_s(upperStr, MAX_PATH * 2, str);
    wcscpy_s(upperPat, 256, pattern);
    CharUpperW(upperStr);
    CharUpperW(upperPat);
    return wcsstr(upperStr, upperPat) != NULL;
}

void QuickScan(const wchar_t* path, const wchar_t* appName, int depth, int* found) {
    if (depth <= 0) return;

    wchar_t search[MAX_PATH * 2];
    swprintf_s(search, MAX_PATH * 2, L"%s\\*", path);

    WIN32_FIND_DATAW fd;
    HANDLE h = FindFirstFileW(search, &fd);
    if (h == INVALID_HANDLE_VALUE) return;

    do {
        if (wcscmp(fd.cFileName, L".") == 0 || wcscmp(fd.cFileName, L"..") == 0)
            continue;

        if (FastMatch(fd.cFileName, appName)) {
            wprintf(L"[FOUND] %s\\%s\n", path, fd.cFileName);
            (*found)++;
        }

        wchar_t full[MAX_PATH * 2];
        swprintf_s(full, MAX_PATH * 2, L"%s\\%s", path, fd.cFileName);

        if (fd.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) {
            if (_wcsicmp(fd.cFileName, L"$Recycle.Bin") != 0 &&
                _wcsicmp(fd.cFileName, L"System Volume Information") != 0)
                QuickScan(full, appName, depth - 1, found);
        }
    } while (FindNextFileW(h, &fd));

    FindClose(h);
}

int main() {
    SetConsoleOutputCP(CP_UTF8);
    wprintf(L"Final comprehensive scan for Armoury...\n\n");

    int found = 0;
    wchar_t profile[MAX_PATH];
    GetEnvironmentVariableW(L"USERPROFILE", profile, MAX_PATH);

    const wchar_t* paths[] = {
        L"C:\\Program Files",
        L"C:\\Program Files (x86)",
        L"C:\\ProgramData",
        L"C:\\Windows\\System32\\DriverStore",
        L"C:\\Program Files\\WindowsApps",
        L"C:\\Windows\\System32",              // Added to catch ASUSACCI folder
        L"C:\\Windows\\Prefetch",
        L"C:\\Windows\\Temp",
        L"C:\\Windows\\WinSxS",
        profile,
        NULL
    };

    for (int i = 0; paths[i]; i++) {
        wprintf(L"Scanning %s...\n", paths[i]);
        QuickScan(paths[i], L"Armoury", 20, &found);
    }

    wprintf(L"\n========================================\n");
    wprintf(L"TOTAL ARMOURY ITEMS REMAINING: %d\n", found);
    wprintf(L"========================================\n");

    return 0;
}

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

void TestScan(const wchar_t* path, const wchar_t* appName, int depth, int* found) {
    if (depth <= 0) {
        wprintf(L"[DEPTH LIMIT] %s\n", path);
        return;
    }

    wchar_t search[MAX_PATH * 2];
    swprintf_s(search, MAX_PATH * 2, L"%s\\*", path);

    WIN32_FIND_DATAW fd;
    HANDLE h = FindFirstFileW(search, &fd);
    if (h == INVALID_HANDLE_VALUE) {
        DWORD err = GetLastError();
        if (err != ERROR_ACCESS_DENIED && err != ERROR_FILE_NOT_FOUND)
            wprintf(L"[ERROR %lu] %s\n", err, path);
        return;
    }

    int count = 0;
    do {
        if (wcscmp(fd.cFileName, L".") == 0 || wcscmp(fd.cFileName, L"..") == 0)
            continue;

        count++;

        if (FastMatch(fd.cFileName, appName)) {
            wprintf(L"[MATCH] %s\\%s\n", path, fd.cFileName);
            (*found)++;
        }

        wchar_t full[MAX_PATH * 2];
        swprintf_s(full, MAX_PATH * 2, L"%s\\%s", path, fd.cFileName);

        if (fd.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) {
            TestScan(full, appName, depth - 1, found);
        }
    } while (FindNextFileW(h, &fd));

    if (count > 0)
        wprintf(L"[SCANNED] %s - %d items\n", path, count);

    FindClose(h);
}

int main() {
    SetConsoleOutputCP(CP_UTF8);

    wprintf(L"Testing scan for 'Armoury' files...\n\n");

    int found = 0;

    // Test specific paths
    TestScan(L"C:\\Windows\\System32\\DriverStore", L"Armoury", 10, &found);
    TestScan(L"C:\\Program Files\\WindowsApps", L"Armoury", 10, &found);

    wprintf(L"\n\nTOTAL MATCHES FOUND: %d\n", found);

    return 0;
}

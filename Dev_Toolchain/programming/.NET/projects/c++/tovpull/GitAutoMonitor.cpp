#ifndef UNICODE
#define UNICODE
#endif

#include <windows.h>
#include <shellapi.h>
#include <commctrl.h>
#include <string>
#include <vector>
#include <sstream>
#include <chrono>
#include <thread>
#include <mutex>
#include <ctime>
#include <iomanip>

#pragma comment(lib, "comctl32.lib")
#pragma comment(lib, "shell32.lib")

#define WM_TRAYICON (WM_USER + 1)
#define ID_TRAY_EXIT 1001
#define ID_TRAY_SHOW 1002
#define IDT_TIMER1 1003
#define IDI_APPICON 101

std::wstring logs;
std::mutex logMutex;
HWND g_hDashboard = NULL;
HWND g_hLogEdit = NULL;
bool g_running = true;

struct RepoConfig {
    std::wstring path;
    std::vector<std::wstring> branches;
};

std::vector<RepoConfig> repos = {
    {L"F:\\tovplay\\tovplay-frontend", {L"main", L"staging"}},
    {L"F:\\tovplay\\tovplay-backend", {L"main", L"staging"}}
};
int checkInterval = 5;

std::wstring GetCurrentTimeStr() {
    auto now = std::chrono::system_clock::now();
    auto time = std::chrono::system_clock::to_time_t(now);
    struct tm timeinfo;
    localtime_s(&timeinfo, &time);
    wchar_t buffer[32];
    wcsftime(buffer, 32, L"%H:%M:%S", &timeinfo);
    return buffer;
}

void AppendLog(const std::wstring& message) {
    std::lock_guard<std::mutex> lock(logMutex);
    logs += message + L"\r\n";
    if (g_hLogEdit && IsWindow(g_hLogEdit)) {
        SetWindowTextW(g_hLogEdit, logs.c_str());
        SendMessage(g_hLogEdit, WM_VSCROLL, SB_BOTTOM, 0);
    }
}

std::wstring ExecuteCommand(const std::wstring& cmd, const std::wstring& workDir = L"") {
    SECURITY_ATTRIBUTES sa;
    sa.nLength = sizeof(SECURITY_ATTRIBUTES);
    sa.bInheritHandle = TRUE;
    sa.lpSecurityDescriptor = NULL;

    HANDLE hRead, hWrite;
    if (!CreatePipe(&hRead, &hWrite, &sa, 0))
        return L"";

    SetHandleInformation(hRead, HANDLE_FLAG_INHERIT, 0);

    STARTUPINFOW si = {};
    si.cb = sizeof(STARTUPINFOW);
    si.hStdOutput = hWrite;
    si.hStdError = hWrite;
    si.dwFlags |= STARTF_USESTDHANDLES | STARTF_USESHOWWINDOW;
    si.wShowWindow = SW_HIDE;

    PROCESS_INFORMATION pi = {};

    std::wstring cmdLine = L"cmd.exe /C " + cmd;
    
    BOOL success = CreateProcessW(
        NULL,
        (LPWSTR)cmdLine.c_str(),
        NULL, NULL, TRUE, CREATE_NO_WINDOW,
        NULL,
        workDir.empty() ? NULL : workDir.c_str(),
        &si, &pi
    );

    CloseHandle(hWrite);

    std::wstring result;
    if (success) {
        char buffer[4096];
        DWORD bytesRead;
        while (ReadFile(hRead, buffer, sizeof(buffer) - 1, &bytesRead, NULL) && bytesRead > 0) {
            buffer[bytesRead] = '\0';
            int size = MultiByteToWideChar(CP_UTF8, 0, buffer, bytesRead, NULL, 0);
            std::wstring wbuffer(size, 0);
            MultiByteToWideChar(CP_UTF8, 0, buffer, bytesRead, &wbuffer[0], size);
            result += wbuffer;
        }
        WaitForSingleObject(pi.hProcess, INFINITE);
        CloseHandle(pi.hProcess);
        CloseHandle(pi.hThread);
    }

    CloseHandle(hRead);
    return result;
}

void CheckRepository(const RepoConfig& repo) {
    AppendLog(L"[" + GetCurrentTimeStr() + L"] Checking " + repo.path + L"...");

    WIN32_FIND_DATAW findData;
    HANDLE hFind = FindFirstFileW((repo.path + L"\\*").c_str(), &findData);
    if (hFind == INVALID_HANDLE_VALUE) {
        AppendLog(L"[" + GetCurrentTimeStr() + L"] Repository not found: " + repo.path);
        return;
    }
    FindClose(hFind);

    std::wstring currentBranch = ExecuteCommand(L"git rev-parse --abbrev-ref HEAD", repo.path);
    currentBranch.erase(currentBranch.find_last_not_of(L"\r\n") + 1);
    
    AppendLog(L"Current branch: " + currentBranch);

    bool onMonitoredBranch = false;
    for (const auto& branch : repo.branches) {
        if (currentBranch == branch) {
            onMonitoredBranch = true;
            break;
        }
    }

    if (!onMonitoredBranch) {
        AppendLog(L"Not on monitored branch (" + currentBranch + L") - skipping");
        AppendLog(L"---");
        return;
    }

    std::wstring status = ExecuteCommand(L"git status --porcelain", repo.path);
    bool hasChanges = !status.empty() && status.find_first_not_of(L"\r\n\t ") != std::wstring::npos;

    if (hasChanges) {
        AppendLog(L"[" + GetCurrentTimeStr() + L"] Uncommitted changes detected");
        AppendLog(L"Stashing changes...");
        ExecuteCommand(L"git stash save \"Auto-stash before pull\"", repo.path);
    }

    AppendLog(L"Fetching from origin...");
    ExecuteCommand(L"git fetch origin", repo.path);

    std::wstring localCommit = ExecuteCommand(L"git rev-parse HEAD", repo.path);
    std::wstring remoteCommit = ExecuteCommand(L"git rev-parse origin/" + currentBranch, repo.path);
    
    localCommit.erase(localCommit.find_last_not_of(L"\r\n") + 1);
    remoteCommit.erase(remoteCommit.find_last_not_of(L"\r\n") + 1);

    AppendLog(L"Local:  " + localCommit);
    AppendLog(L"Remote: " + remoteCommit);

    if (localCommit != remoteCommit) {
        AppendLog(L"[" + GetCurrentTimeStr() + L"] CHANGES DETECTED - PULLING");
        std::wstring pullResult = ExecuteCommand(L"git pull origin " + currentBranch + L" --rebase", repo.path);
        
        if (pullResult.find(L"error") == std::wstring::npos && pullResult.find(L"fatal") == std::wstring::npos) {
            AppendLog(L"[" + GetCurrentTimeStr() + L"] PULL COMPLETED SUCCESSFULLY");
            if (hasChanges) {
                AppendLog(L"Reapplying stashed changes...");
                ExecuteCommand(L"git stash pop", repo.path);
            }
        } else {
            AppendLog(L"[" + GetCurrentTimeStr() + L"] PULL FAILED - ABORTING");
            ExecuteCommand(L"git rebase --abort", repo.path);
            if (hasChanges) {
                AppendLog(L"Restoring stashed changes...");
                ExecuteCommand(L"git stash pop", repo.path);
            }
        }
    } else {
        AppendLog(L"No changes detected - up to date");
    }

    AppendLog(L"---");
}

void MonitorThread() {
    AppendLog(L"Starting auto-pull monitor");
    AppendLog(L"Monitoring repositories:");
    for (const auto& repo : repos) {
        AppendLog(L"  - " + repo.path);
    }
    AppendLog(L"Check interval: " + std::to_wstring(checkInterval) + L" seconds\n");

    while (g_running) {
        for (const auto& repo : repos) {
            if (!g_running) break;
            CheckRepository(repo);
        }
        
        if (g_running) {
            AppendLog(L"\nWaiting " + std::to_wstring(checkInterval) + L" seconds...\n");
            for (int i = 0; i < checkInterval && g_running; i++) {
                std::this_thread::sleep_for(std::chrono::seconds(1));
            }
        }
    }
}

LRESULT CALLBACK DashboardProc(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam) {
    switch (msg) {
        case WM_CREATE: {
            g_hLogEdit = CreateWindowExW(
                WS_EX_CLIENTEDGE,
                L"EDIT",
                L"",
                WS_CHILD | WS_VISIBLE | WS_VSCROLL | ES_MULTILINE | ES_AUTOVSCROLL | ES_READONLY,
                10, 10, 760, 540,
                hwnd, NULL, GetModuleHandle(NULL), NULL
            );
            
            HFONT hFont = CreateFontW(
                16, 0, 0, 0, FW_NORMAL, FALSE, FALSE, FALSE,
                DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS,
                DEFAULT_QUALITY, DEFAULT_PITCH | FF_DONTCARE, L"Consolas"
            );
            SendMessage(g_hLogEdit, WM_SETFONT, (WPARAM)hFont, TRUE);
            
            SetWindowTextW(g_hLogEdit, logs.c_str());
            break;
        }
        case WM_SIZE: {
            RECT rc;
            GetClientRect(hwnd, &rc);
            MoveWindow(g_hLogEdit, 10, 10, rc.right - 20, rc.bottom - 20, TRUE);
            break;
        }
        case WM_CLOSE:
            ShowWindow(hwnd, SW_HIDE);
            return 0;
        case WM_DESTROY:
            g_hDashboard = NULL;
            g_hLogEdit = NULL;
            break;
    }
    return DefWindowProcW(hwnd, msg, wParam, lParam);
}

void ShowDashboard(HINSTANCE hInstance) {
    if (g_hDashboard && IsWindow(g_hDashboard)) {
        ShowWindow(g_hDashboard, SW_RESTORE);
        SetForegroundWindow(g_hDashboard);
        SetWindowTextW(g_hLogEdit, logs.c_str());
        SendMessage(g_hLogEdit, WM_VSCROLL, SB_BOTTOM, 0);
        return;
    }

    WNDCLASSW wc = {};
    wc.lpfnWndProc = DashboardProc;
    wc.hInstance = hInstance;
    wc.lpszClassName = L"GitMonitorDashboard";
    wc.hbrBackground = (HBRUSH)(COLOR_WINDOW + 1);
    wc.hCursor = LoadCursor(NULL, IDC_ARROW);
    RegisterClassW(&wc);

    g_hDashboard = CreateWindowExW(
        0,
        L"GitMonitorDashboard",
        L"Git Auto Monitor - Dashboard",
        WS_OVERLAPPEDWINDOW,
        CW_USEDEFAULT, CW_USEDEFAULT, 800, 600,
        NULL, NULL, hInstance, NULL
    );

    ShowWindow(g_hDashboard, SW_SHOW);
    UpdateWindow(g_hDashboard);
}

LRESULT CALLBACK WndProc(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam) {
    static NOTIFYICONDATAW nid;
    static HINSTANCE hInstance;

    switch (msg) {
        case WM_CREATE: {
            hInstance = ((LPCREATESTRUCT)lParam)->hInstance;
            
            nid.cbSize = sizeof(NOTIFYICONDATAW);
            nid.hWnd = hwnd;
            nid.uID = 1;
            nid.uFlags = NIF_ICON | NIF_MESSAGE | NIF_TIP;
            nid.uCallbackMessage = WM_TRAYICON;
            nid.hIcon = LoadIconW(hInstance, MAKEINTRESOURCEW(IDI_APPICON));
            if (!nid.hIcon) nid.hIcon = LoadIcon(NULL, IDI_APPLICATION);
            wcscpy_s(nid.szTip, L"Git Auto Monitor");
            Shell_NotifyIconW(NIM_ADD, &nid);

            std::thread(MonitorThread).detach();
            break;
        }

        case WM_TRAYICON: {
            if (lParam == WM_LBUTTONUP || lParam == WM_RBUTTONUP) {
                POINT pt;
                GetCursorPos(&pt);
                
                HMENU hMenu = CreatePopupMenu();
                AppendMenuW(hMenu, MF_STRING, ID_TRAY_SHOW, L"Show Dashboard");
                AppendMenuW(hMenu, MF_SEPARATOR, 0, NULL);
                AppendMenuW(hMenu, MF_STRING, ID_TRAY_EXIT, L"Exit");
                
                SetForegroundWindow(hwnd);
                TrackPopupMenu(hMenu, TPM_BOTTOMALIGN | TPM_LEFTALIGN, pt.x, pt.y, 0, hwnd, NULL);
                DestroyMenu(hMenu);
            } else if (lParam == WM_LBUTTONDBLCLK) {
                ShowDashboard(hInstance);
            }
            break;
        }

        case WM_COMMAND: {
            if (LOWORD(wParam) == ID_TRAY_SHOW) {
                ShowDashboard(hInstance);
            } else if (LOWORD(wParam) == ID_TRAY_EXIT) {
                g_running = false;
                Shell_NotifyIconW(NIM_DELETE, &nid);
                PostQuitMessage(0);
            }
            break;
        }

        case WM_DESTROY:
            g_running = false;
            Shell_NotifyIconW(NIM_DELETE, &nid);
            PostQuitMessage(0);
            break;
    }
    return DefWindowProcW(hwnd, msg, wParam, lParam);
}

int WINAPI WinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, LPSTR lpCmdLine, int nCmdShow) {
    WNDCLASSW wc = {};
    wc.lpfnWndProc = WndProc;
    wc.hInstance = hInstance;
    wc.lpszClassName = L"GitAutoMonitor";
    RegisterClassW(&wc);

    HWND hwnd = CreateWindowExW(
        0, L"GitAutoMonitor", L"Git Auto Monitor",
        0, 0, 0, 0, 0,
        NULL, NULL, hInstance, NULL
    );

    MSG msg;
    while (GetMessage(&msg, NULL, 0, 0)) {
        TranslateMessage(&msg);
        DispatchMessage(&msg);
    }

    return 0;
}

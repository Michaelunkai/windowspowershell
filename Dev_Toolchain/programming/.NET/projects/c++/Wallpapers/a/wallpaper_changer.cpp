#include <windows.h>
#include <winhttp.h>
#include <urlmon.h>
#include <iostream>
#include <fstream>
#include <string>
#include <vector>
#include <set>
#include <random>
#include <shlobj.h>
#include <algorithm>

#pragma comment(lib, "winhttp.lib")
#pragma comment(lib, "user32.lib")
#pragma comment(lib, "urlmon.lib")
#pragma comment(lib, "ole32.lib")

// Dark neon themes - ONLY dark aesthetics
const std::vector<std::string> THEMES = {
    "dark+neon", "black+neon", "purple+neon", "red+neon", "dark+cyberpunk",
    "neon+noir", "dark+synthwave", "dark+retrowave", "crimson+neon", "violet+neon",
    "dark+city+lights", "neon+rain", "dark+abstract", "black+purple", "dark+red+glow"
};

// 100+ dark neon wallpaper IDs from Wallhaven - curated for dark/neon/cyberpunk aesthetics
const std::vector<std::string> DARK_NEON_IDS = {
    // Dark purple/blue neon cyberpunk
    "pkz5w7", "5wxy31", "8xlmm3", "we7rl3", "m35zq3", "5gg9l1", "l3z2k7", "wq6d1l",
    "1pdo5m", "z8dg9y", "j5q73w", "8oxy5j", "dpqlg6", "eymdx6", "6qz2gp", "x8dvgl",
    "j3mozy", "6dwyzl", "72e36m", "ymwd93", "nkgomv", "2e8mdz", "rdwo3v", "g8eewe",
    // Dark red/crimson neon
    "d887pg", "qrr8w7", "zppr1w", "8gg12y", "gww1gq", "gww9lq", "jeekow", "xe6ggz",
    "21y1vy", "d866vl", "5y7qd7", "yq8r5k", "qr25xq", "ly3qr2", "7j26xo",
    // Dark galaxy/space purple
    "k88m2m", "1qq7r9", "kxgvx6", "839zjk", "og3zgl", "zyj3qj", "qr9o3d", "yqj6xx",
    "lqe1k2", "949mwn",
    // Dark synthwave/retrowave
    "ox2wkp", "eyg8v8", "9mjoy1", "e7k6go", "83w2v1", "q2mrdg", "4l67wk", "xlvw1k",
    // Dark neon animals (wolf, etc)
    "73y2gy", "j8m9gq", "ymz86g", "7pzggy", "og5xmm", "zx6pkj", "mpzomm", "lmxmxy",
    "j8rvxw", "nek29o",
    // Dark music visualizer neon
    "0j5zlm", "odwqkp", "kwr9x7", "5wz395", "xlpv8v", "5wmkz7", "g82v3e", "ox67qm",
    "q6m7e5", "p8yqke",
    // Dark cyberpunk city night
    "dgpxel", "eo6prl", "r2m8rw", "5ggoym", "x8o6z6", "g7l2lq", "pk7q3m", "e7l6xk",
    "y8vk67", "lmyo3y", "3zvjw3", "85j2k1", "v9xjpq", "e7qg2r", "rd89om",
    // Dark abstract geometric neon
    "vg7ylq", "j5mpey", "83271w", "l8ypdq", "dp1xjl", "yxmzjk", "4xmd17", "od7wxl",
    "pk8zxj", "x86zwj", "n6qv5m", "3k2do7", "yxkq3y", "dgwxy7", "gpm3ek",
    // Dark neon cars
    "w823zy", "rd8evk", "lg3qry", "pk8yrw", "4y7mjq", "e7g3ok", "83k7zy", "4x1q9l",
    "dp3wyv", "y81pdq",
    // Dark samurai/oni mask neon
    "3zy3gm", "e7lzxy", "x81p7m", "wq3zdl", "pk2x3m", "rd1k7y", "lg8e3m", "4y3qkv"
};

// Global history tracking
std::set<std::string> g_usedIds;
std::wstring g_historyFilePath;

std::wstring StringToWString(const std::string& str) {
    if (str.empty()) return std::wstring();
    int size = MultiByteToWideChar(CP_UTF8, 0, str.c_str(), -1, nullptr, 0);
    std::wstring wstr(size, 0);
    MultiByteToWideChar(CP_UTF8, 0, str.c_str(), -1, &wstr[0], size);
    return wstr;
}

std::string WStringToString(const std::wstring& wstr) {
    if (wstr.empty()) return std::string();
    int size = WideCharToMultiByte(CP_UTF8, 0, wstr.c_str(), -1, nullptr, 0, nullptr, nullptr);
    std::string str(size, 0);
    WideCharToMultiByte(CP_UTF8, 0, wstr.c_str(), -1, &str[0], size, nullptr, nullptr);
    return str;
}

void InitializeHistoryFilePath() {
    WCHAR exePath[MAX_PATH];
    GetModuleFileNameW(NULL, exePath, MAX_PATH);
    std::wstring wstrPath(exePath);
    size_t lastBackslash = wstrPath.find_last_of(L"\\");
    if (lastBackslash != std::wstring::npos) {
        wstrPath = wstrPath.substr(0, lastBackslash + 1);
    }
    g_historyFilePath = wstrPath + L"wallpaper_history.txt";
}

void LoadHistory() {
    if (g_historyFilePath.empty()) {
        InitializeHistoryFilePath();
    }
    g_usedIds.clear();

    std::ifstream file;
    file.open(g_historyFilePath);
    if (file.is_open()) {
        std::string line;
        while (std::getline(file, line)) {
            if (!line.empty()) {
                g_usedIds.insert(line);
            }
        }
        file.close();
    }
}

void SaveHistory() {
    if (g_historyFilePath.empty()) {
        InitializeHistoryFilePath();
    }

    std::ofstream file;
    file.open(g_historyFilePath, std::ios::trunc);
    if (file.is_open()) {
        for (const auto& id : g_usedIds) {
            file << id << "\n";
        }
        file.close();
    }
}

std::string GetRandomTheme() {
    std::random_device rd;
    std::mt19937 gen(rd());
    std::uniform_int_distribution<> dis(0, THEMES.size() - 1);
    return THEMES[dis(gen)];
}

std::string GetUnusedWallpaperId() {
    // Filter out used IDs
    std::vector<std::string> availableIds;
    for (const auto& id : DARK_NEON_IDS) {
        if (g_usedIds.find(id) == g_usedIds.end()) {
            availableIds.push_back(id);
        }
    }

    // If all used, clear history and pick from full list
    if (availableIds.empty()) {
        g_usedIds.clear();
        availableIds = DARK_NEON_IDS;
    }

    // Select random ID
    std::random_device rd;
    std::mt19937 gen(rd());
    std::uniform_int_distribution<> dis(0, availableIds.size() - 1);

    std::string selectedId = availableIds[dis(gen)];
    g_usedIds.insert(selectedId);
    SaveHistory();

    return selectedId;
}

std::string GetWorkingImageUrl(const std::string& wallpaperId) {
    std::string prefix = wallpaperId.substr(0, 2);
    std::string baseUrl = "https://w.wallhaven.cc/full/" + prefix + "/wallhaven-" + wallpaperId;

    // Try JPG first (most common)
    std::string jpgUrl = baseUrl + ".jpg";
    std::wstring wideJpgUrl = StringToWString(jpgUrl);

    WCHAR tempPath[MAX_PATH];
    GetTempPathW(MAX_PATH, tempPath);
    std::wstring testFile = std::wstring(tempPath) + L"test_wallhaven.tmp";

    HRESULT hr = URLDownloadToFileW(nullptr, wideJpgUrl.c_str(), testFile.c_str(), 0, nullptr);
    if (SUCCEEDED(hr)) {
        DeleteFileW(testFile.c_str());
        return jpgUrl;
    }

    // Try PNG
    std::string pngUrl = baseUrl + ".png";
    std::wstring widePngUrl = StringToWString(pngUrl);

    hr = URLDownloadToFileW(nullptr, widePngUrl.c_str(), testFile.c_str(), 0, nullptr);
    if (SUCCEEDED(hr)) {
        DeleteFileW(testFile.c_str());
        return pngUrl;
    }

    DeleteFileW(testFile.c_str());
    return "";
}

bool DownloadImage(const std::string& imageUrl, const std::wstring& savePath) {
    std::wstring wideUrl = StringToWString(imageUrl);
    DeleteFileW(savePath.c_str());
    HRESULT hr = URLDownloadToFileW(nullptr, wideUrl.c_str(), savePath.c_str(), 0, nullptr);
    return SUCCEEDED(hr);
}

bool DownloadWithRetry(const std::wstring& savePath, int maxRetries = 5) {
    for (int attempt = 0; attempt < maxRetries; ++attempt) {
        std::string wallpaperId = GetUnusedWallpaperId();
        std::string imageUrl = GetWorkingImageUrl(wallpaperId);

        if (!imageUrl.empty() && DownloadImage(imageUrl, savePath)) {
            return true;
        }
    }
    return false;
}

bool SetWallpaper(const std::wstring& imagePath) {
    WCHAR absolutePath[MAX_PATH];
    GetFullPathNameW(imagePath.c_str(), MAX_PATH, absolutePath, nullptr);

    if (SystemParametersInfoW(SPI_SETDESKWALLPAPER, 0, absolutePath,
                             SPIF_UPDATEINIFILE | SPIF_SENDCHANGE)) {
        return true;
    }
    return false;
}

void ChangeWallpaper() {
    CoInitialize(nullptr);

    // Initialize and load history
    InitializeHistoryFilePath();
    LoadHistory();

    // Get executable directory for saving wallpaper
    WCHAR exePath[MAX_PATH];
    GetModuleFileNameW(nullptr, exePath, MAX_PATH);
    std::wstring exeDir = exePath;
    size_t lastSlash = exeDir.find_last_of(L"\\/");
    if (lastSlash != std::wstring::npos) {
        exeDir = exeDir.substr(0, lastSlash);
    }
    std::wstring imagePath = exeDir + L"\\wallpaper.jpg";

    // Try to download with retry logic
    bool downloaded = DownloadWithRetry(imagePath, 5);

    // Dark fallback if all attempts fail
    if (!downloaded) {
        std::string fallbackUrl = "https://picsum.photos/3840/2160?grayscale";
        downloaded = DownloadImage(fallbackUrl, imagePath);
    }

    if (downloaded) {
        SetWallpaper(imagePath);
    }

    CoUninitialize();
}

int WINAPI WinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance,
                   LPSTR lpCmdLine, int nCmdShow) {
    ChangeWallpaper();
    return 0;
}

int main() {
    ChangeWallpaper();
    return 0;
}

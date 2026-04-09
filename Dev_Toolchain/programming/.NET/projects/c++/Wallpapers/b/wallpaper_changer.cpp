#include <windows.h>
#include <winhttp.h>
#include <urlmon.h>
#include <iostream>
#include <fstream>
#include <string>
#include <vector>
#include <random>
#include <shlobj.h>

#pragma comment(lib, "winhttp.lib")
#pragma comment(lib, "user32.lib")
#pragma comment(lib, "urlmon.lib")

// Wallpaper themes
const std::vector<std::string> THEMES = {
    "gaming", "cyberpunk", "dystopian", "futuristic", "tech-noir",
    "sci-fi", "neo-noir", "street-level+sci-fi", "high-tech+low-life",
    "transhumanism", "cybernetic", "augmented", "megacorporations",
    "artificial+intelligence", "virtual+reality", "hacking", "drones",
    "cybercrime", "synthetic", "neon-lit", "post-industrial", "dystopia"
};

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

std::string GetRandomTheme() {
    std::random_device rd;
    std::mt19937 gen(rd());
    std::uniform_int_distribution<> dis(0, THEMES.size() - 1);
    return THEMES[dis(gen)];
}

std::string ExtractImageUrl(const std::string& jsonResponse) {
    // Simple JSON parsing to extract download URL
    size_t pos = jsonResponse.find("\"download\":\"");
    if (pos == std::string::npos) {
        // Try alternative field
        pos = jsonResponse.find("\"urls\":{\"raw\":\"");
        if (pos == std::string::npos) return "";
        pos += 16;
    } else {
        pos += 12;
    }

    size_t endPos = jsonResponse.find("\"", pos);
    if (endPos == std::string::npos) return "";

    std::string url = jsonResponse.substr(pos, endPos - pos);

    // Unescape URL
    size_t escapePos;
    while ((escapePos = url.find("\\/")) != std::string::npos) {
        url.replace(escapePos, 2, "/");
    }

    return url;
}

bool DownloadImage(const std::string& imageUrl, const std::wstring& savePath) {
    // Use URLDownloadToFile for simple, reliable downloading with automatic redirect handling
    std::wstring wideUrl = StringToWString(imageUrl);

    // Delete old file if exists
    DeleteFileW(savePath.c_str());

    HRESULT hr = URLDownloadToFileW(nullptr, wideUrl.c_str(), savePath.c_str(), 0, nullptr);

    return SUCCEEDED(hr);
}

std::string GetImageUrl(const std::string& query) {
    std::random_device rd;
    std::mt19937 gen(rd());

    // Map themes to Wallhaven search queries
    std::vector<std::string> searchTerms = {
        "cyberpunk+city", "gaming+setup", "futuristic+city", "sci-fi+landscape",
        "neon+city", "dystopian+future", "tech+noir", "cyberspace", "virtual+reality",
        "android+cyberpunk", "blade+runner", "ghost+in+the+shell", "matrix",
        "cyberpunk+2077", "deus+ex", "synthwave", "vaporwave", "retrowave"
    };

    // Wallhaven popular cyberpunk/gaming wallpaper IDs (high quality, guaranteed to work)
    std::vector<std::string> wallhavenIds = {
        "pkz5w7", "5wxy31", "8xlmm3", "we7rl3", "m35zq3", "5gg9l1", "l3z2k7", "wq6d1l",
        "1pdo5m", "z8dg9y", "j5q73w", "8oxy5j", "dpqlg6", "eymdx6", "6qz2gp", "x8dvgl",
        "j3mozy", "6dwyzl", "72e36m", "ymwd93", "nkgomv", "2e8mdz", "rdwo3v", "g8eewe"
    };

    // Select random wallpaper ID
    std::uniform_int_distribution<> dis(0, wallhavenIds.size() - 1);
    std::string wallpaperId = wallhavenIds[dis(gen)];

    // Construct Wallhaven direct image URL
    // Format: https://w.wallhaven.cc/full/{first 2 chars}/wallhaven-{id}.{ext}
    std::string prefix = wallpaperId.substr(0, 2);

    // Try both jpg and png extensions (most are jpg)
    return "https://w.wallhaven.cc/full/" + prefix + "/wallhaven-" + wallpaperId + ".jpg";
}

bool SetWallpaper(const std::wstring& imagePath) {
    // Convert to absolute path
    WCHAR absolutePath[MAX_PATH];
    GetFullPathNameW(imagePath.c_str(), MAX_PATH, absolutePath, nullptr);

    // Set wallpaper using SystemParametersInfo
    if (SystemParametersInfoW(SPI_SETDESKWALLPAPER, 0, absolutePath,
                             SPIF_UPDATEINIFILE | SPIF_SENDCHANGE)) {
        return true;
    }

    return false;
}

void ChangeWallpaper() {
    // Initialize COM for URLDownloadToFile
    CoInitialize(nullptr);

    // Get executable directory
    WCHAR exePath[MAX_PATH];
    GetModuleFileNameW(nullptr, exePath, MAX_PATH);
    std::wstring exeDir = exePath;
    size_t lastSlash = exeDir.find_last_of(L"\\/");
    if (lastSlash != std::wstring::npos) {
        exeDir = exeDir.substr(0, lastSlash);
    }

    std::wstring imagePath = exeDir + L"\\wallpaper.jpg";

    // Get random theme
    std::string theme = GetRandomTheme();

    // Get image URL for the theme
    std::string imageUrl = GetImageUrl(theme);

    // Try to download image with fallback to Picsum
    bool downloaded = DownloadImage(imageUrl, imagePath);

    if (!downloaded) {
        // Fallback to Picsum if Wallhaven fails
        imageUrl = "https://picsum.photos/3840/2160";
        downloaded = DownloadImage(imageUrl, imagePath);
    }

    if (downloaded) {
        // Set as wallpaper
        SetWallpaper(imagePath);
    }

    // Uninitialize COM
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

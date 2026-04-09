#include <windows.h>
#include <urlmon.h>
#include <iostream>
#include <fstream>
#include <string>
#include <vector>
#include <random>

#pragma comment(lib, "urlmon.lib")
#pragma comment(lib, "user32.lib")

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

std::string GetRandomTheme() {
    std::random_device rd;
    std::mt19937 gen(rd());
    std::uniform_int_distribution<> dis(0, THEMES.size() - 1);
    return THEMES[dis(gen)];
}

int main() {
    std::cout << "Starting wallpaper changer..." << std::endl;

    CoInitialize(nullptr);

    // Get executable directory
    WCHAR exePath[MAX_PATH];
    GetModuleFileNameW(nullptr, exePath, MAX_PATH);
    std::wstring exeDir = exePath;
    std::wcout << L"Exe path: " << exeDir << std::endl;

    size_t lastSlash = exeDir.find_last_of(L"\\/");
    if (lastSlash != std::wstring::npos) {
        exeDir = exeDir.substr(0, lastSlash);
    }
    std::wcout << L"Exe dir: " << exeDir << std::endl;

    std::wstring imagePath = exeDir + L"\\wallpaper.jpg";
    std::wcout << L"Image path: " << imagePath << std::endl;

    // Get random theme
    std::string theme = GetRandomTheme();
    std::cout << "Theme: " << theme << std::endl;

    // Try multiple image sources
    std::vector<std::string> imageUrls = {
        "https://picsum.photos/3840/2160",
        "https://source.unsplash.com/random/3840x2160",
        "https://source.unsplash.com/3840x2160/?" + theme
    };

    std::string imageUrl = imageUrls[0];  // Start with Picsum
    std::cout << "URL: " << imageUrl << std::endl;

    std::wstring wideUrl = StringToWString(imageUrl);

    // Download image
    std::cout << "Downloading..." << std::endl;
    HRESULT hr = URLDownloadToFileW(nullptr, wideUrl.c_str(), imagePath.c_str(), 0, nullptr);

    if (SUCCEEDED(hr)) {
        std::cout << "Download successful!" << std::endl;

        // Set wallpaper
        WCHAR absolutePath[MAX_PATH];
        GetFullPathNameW(imagePath.c_str(), MAX_PATH, absolutePath, nullptr);
        std::wcout << L"Absolute path: " << absolutePath << std::endl;

        if (SystemParametersInfoW(SPI_SETDESKWALLPAPER, 0, absolutePath,
                                 SPIF_UPDATEINIFILE | SPIF_SENDCHANGE)) {
            std::cout << "Wallpaper set successfully!" << std::endl;
        } else {
            std::cout << "Failed to set wallpaper. Error: " << GetLastError() << std::endl;
        }
    } else {
        std::cout << "Download failed. HRESULT: 0x" << std::hex << hr << std::endl;
    }

    CoUninitialize();

    return 0;
}

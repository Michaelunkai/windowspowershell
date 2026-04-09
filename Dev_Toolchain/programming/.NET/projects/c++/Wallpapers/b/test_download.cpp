#include <windows.h>
#include <urlmon.h>
#include <iostream>

#pragma comment(lib, "urlmon.lib")

int main() {
    const wchar_t* url = L"https://picsum.photos/1920/1080";
    const wchar_t* file = L"F:\\Downloads\\wall\\test_image.jpg";

    std::wcout << L"Downloading from: " << url << std::endl;
    std::wcout << L"Saving to: " << file << std::endl;

    HRESULT hr = URLDownloadToFileW(nullptr, url, file, 0, nullptr);

    if (SUCCEEDED(hr)) {
        std::wcout << L"Download successful!" << std::endl;
    } else {
        std::wcout << L"Download failed with error: 0x" << std::hex << hr << std::endl;
    }

    return 0;
}

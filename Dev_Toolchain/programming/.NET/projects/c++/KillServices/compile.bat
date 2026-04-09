@echo off
echo Compiling service_killer.exe...
F:\DevKit\compilers\mingw64\bin\g++.exe -O3 -std=c++11 -o service_killer.exe service_killer.cpp -ladvapi32 -lntdll -static-libgcc -static-libstdc++
if %errorlevel% equ 0 (
    echo Success! service_killer.exe compiled.
) else (
    echo Compilation failed!
)

echo.
echo Compiling ultimate_killer.exe...
F:\DevKit\compilers\mingw64\bin\g++.exe -O3 -std=c++11 -o ultimate_killer.exe ultimate_killer.cpp -ladvapi32 -lntdll -static-libgcc -static-libstdc++
if %errorlevel% equ 0 (
    echo Success! ultimate_killer.exe compiled.
) else (
    echo Compilation failed!
)

echo.
echo Compiling nuclear.exe...
F:\DevKit\compilers\mingw64\bin\g++.exe -O3 -std=c++11 -o nuclear.exe nuclear.cpp -ladvapi32 -lntdll -static-libgcc -static-libstdc++
if %errorlevel% equ 0 (
    echo Success! nuclear.exe compiled.
) else (
    echo Compilation failed!
)

echo.
echo All done!
pause

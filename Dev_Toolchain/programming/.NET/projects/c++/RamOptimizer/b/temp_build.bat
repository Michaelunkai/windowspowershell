@echo off
call "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvarsall.bat" x64
cl.exe /EHsc /O2 /W3 /DNDEBUG /DUNICODE /D_UNICODE ram_optimizer.cpp /link /SUBSYSTEM:WINDOWS /OUT:ram_optimizer.exe user32.lib shell32.lib advapi32.lib psapi.lib

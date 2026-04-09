@echo off
echo Testing CPU Monitor EXE...
cd /d "F:\study\Dev_Toolchain\programming\python\apps\CpuManager\build\exe.win-amd64-3.12"
echo Current directory: %CD%
echo Files in directory:
dir
echo.
echo Running CpuMonitorPro.exe...
CpuMonitorPro.exe 2>&1
echo Return code: %ERRORLEVEL%
echo.
echo Checking for debug logs...
dir *.log 2>nul
if exist cpu_monitor_debug.log (
    echo Found debug log:
    type cpu_monitor_debug.log
)
pause
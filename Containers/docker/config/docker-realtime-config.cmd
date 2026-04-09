@echo off
REM ============================================================
REM Docker Real-Time Progress Configuration (FIXED)
REM Include this at the top of ANY batch script that uses Docker
REM ============================================================
REM
REM Usage: call "%~dp0docker-realtime-config.cmd"
REM Or simply copy these lines to the top of your batch file
REM
REM IMPORTANT: --progress flag is ONLY for "docker build"
REM            DO NOT use --progress with: pull, push, run, etc.
REM

REM Force Docker to use BuildKit with plain progress output (for builds only)
set DOCKER_BUILDKIT=1
set BUILDKIT_PROGRESS=plain
set DOCKER_CLI_EXPERIMENTAL=enabled
set COMPOSE_DOCKER_CLI_BUILD=1

REM Disable buffering in Windows console
set PYTHONUNBUFFERED=1

REM Force UTF-8 output for proper progress characters
chcp 65001 >nul 2>&1

echo [CONFIG] Docker real-time progress enabled (builds only)

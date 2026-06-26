@echo off
setlocal enabledelayedexpansion

echo =====================================================================
echo                Grading System - Docker Compose Run Script
echo =====================================================================
echo.

REM Check if Docker is running
docker info >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Docker daemon is not running! Please start Docker Desktop first.
    pause
    exit /b 1
)

echo Starting Docker containers (rebuilding)...
docker-compose up --build

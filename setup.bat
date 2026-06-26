@echo off
setlocal enabledelayedexpansion

echo =====================================================================
echo                Grading System - Project Setup Script
echo =====================================================================
echo.

REM Check if Git is installed
git --version >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Git is not installed or not in PATH! Please install Git first.
    pause
    exit /b 1
)

REM Check if .NET SDK is installed
dotnet --version >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo [ERROR] .NET SDK is not installed or not in PATH! Please install .NET SDK first.
    pause
    exit /b 1
)

if not exist "git_config.txt" (
    echo [ERROR] git_config.txt not found! Please create it.
    pause
    exit /b 1
)

set "ALL_ENGINE_DIR=All Engine"
if not exist "%ALL_ENGINE_DIR%" (
    echo Creating directory "%ALL_ENGINE_DIR%"...
    mkdir "%ALL_ENGINE_DIR%"
)

for /f "usebackq eol=# tokens=1,* delims==" %%A in ("git_config.txt") do (
    set "SERVICE_NAME=%%A"
    set "CONFIG_VAL=%%B"
    
    if not "!CONFIG_VAL!"=="" (
        REM Parse REPO_URL and BRANCH split by |
        for /f "tokens=1,2 delims=|" %%I in ("!CONFIG_VAL!") do (
            set "REPO_URL=%%I"
            set "BRANCH=%%J"
        )
        
        echo.
        echo =============================================================
        echo Configuring Service: !SERVICE_NAME!
        echo Branch:             !BRANCH!
        echo URL:                !REPO_URL!
        echo =============================================================
        
        set "TARGET_PATH=%ALL_ENGINE_DIR%\!SERVICE_NAME!"
        
        if exist "!TARGET_PATH!\.git" (
            echo Folder "!TARGET_PATH!" exists. Fetching and pulling...
            pushd "!TARGET_PATH!"
            git fetch origin
            git checkout !BRANCH!
            git pull origin !BRANCH!
            popd
        ) else (
            echo Folder "!TARGET_PATH!" does not exist. Cloning repository...
            git clone -b !BRANCH! !REPO_URL! "!TARGET_PATH!"
        )
        
        REM Restore and Build the project
        if exist "!TARGET_PATH!" (
            echo.
            echo Restoring NuGet packages for !SERVICE_NAME!...
            pushd "!TARGET_PATH!"
            dotnet restore
            if !ERRORLEVEL! neq 0 (
                echo [WARNING] dotnet restore failed for !SERVICE_NAME!
            ) else (
                echo Building !SERVICE_NAME!...
                dotnet build
                if !ERRORLEVEL! neq 0 (
                    echo [WARNING] dotnet build failed for !SERVICE_NAME!
                ) else (
                    echo Build succeeded for !SERVICE_NAME!!
                )
            )
            popd
        )
    )
)

echo.
echo =====================================================================
echo                Setup and Build completed!
echo =====================================================================
echo.
pause

@echo off
setlocal enabledelayedexpansion

echo =====================================================================
echo                Grading System - Pull Dev and Update Script
echo =====================================================================
echo.

REM --- Step 1: Pull Main System-Repo Repository ---
echo === [1/2] Updating Main System Repository ===
git status >nul 2>&1
if %ERRORLEVEL% equ 0 (
    echo Pulling latest changes for main repository...
    git pull
) else (
    echo [WARNING] Main folder is not a Git repository or Git is not installed.
)
echo.

REM --- Step 2: Read git_config.txt and Pull/Clone Services ---
echo === [2/2] Updating Child Services in "All Engine" ===
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
        echo -------------------------------------------------------------
        echo Service: !SERVICE_NAME! [Branch: !BRANCH!]
        echo URL:     !REPO_URL!
        echo -------------------------------------------------------------
        
        set "TARGET_PATH=%ALL_ENGINE_DIR%\!SERVICE_NAME!"
        
        if exist "!TARGET_PATH!\.git" (
            echo Folder "!TARGET_PATH!" exists. Updating...
            pushd "!TARGET_PATH!"
            git fetch origin
            git checkout !BRANCH!
            git pull origin !BRANCH!
            popd
        ) else (
            echo Folder "!TARGET_PATH!" does not exist. Cloning...
            git clone -b !BRANCH! !REPO_URL! "!TARGET_PATH!"
        )
    )
)

echo.
echo =====================================================================
echo                Git pull and updates completed!
echo =====================================================================
echo.
pause

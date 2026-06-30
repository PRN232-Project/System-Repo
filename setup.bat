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

REM --- Auto Initialize Git for Main Directory ---
echo === [1/4] Khoi tao va dong bo Git cho thu muc goc ===
if not exist ".git" (
    echo [INFO] Dang khoi tao Git repository...
    git init
    git remote add origin https://github.com/PRN232-Project/System-Repo.git
) else (
    echo [INFO] Git da duoc khoi tao tu truoc. Cap nhat remote origin...
    git remote remove origin >nul 2>&1
    git remote add origin https://github.com/PRN232-Project/System-Repo.git
)

REM Kiem tra xem co commit nao chua, neu chua thi commit de lam baseline
git rev-parse --verify HEAD >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo [INFO] Chua co commit nao. Dang tao commit lam moc khoi dau...
    git add -A
    git commit -m "Initial commit from ZIP extract" >nul 2>&1
)

echo Dang lay thong tin tu repository goc - git fetch origin...
git fetch origin

REM Kiem tra nhanh mac dinh tren remote (master hoac main)
set "DEFAULT_BRANCH=master"
git rev-parse --verify origin/master >nul 2>&1
if %ERRORLEVEL% neq 0 (
    set "DEFAULT_BRANCH=main"
)

echo Dang thiet lap nhanh !DEFAULT_BRANCH!...
git branch -M !DEFAULT_BRANCH!
git branch --set-upstream-to=origin/!DEFAULT_BRANCH! !DEFAULT_BRANCH!

echo Dang dong bo va gop code tu repository goc...
git pull origin !DEFAULT_BRANCH! --allow-unrelated-histories -X ours
echo Dong bo code goc hoan tat.
echo.

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

echo === [2/4] Configuring Service Repositories ===
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
            pushd "!TARGET_PATH!"
            if /i "!SERVICE_NAME!"=="FE_Service" (
                echo Cài đặt Node dependencies cho !SERVICE_NAME!...
                call npm install
                if !ERRORLEVEL! neq 0 (
                    echo [WARNING] npm install failed for !SERVICE_NAME!
                ) else (
                    echo Building !SERVICE_NAME!...
                    call npm run build
                    if !ERRORLEVEL! neq 0 (
                        echo [WARNING] npm run build failed for !SERVICE_NAME!
                    ) else (
                        echo Build succeeded for !SERVICE_NAME!!
                    )
                )
            ) else (
                echo Restoring NuGet packages for !SERVICE_NAME!...
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

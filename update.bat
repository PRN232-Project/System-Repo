@echo off
setlocal enabledelayedexpansion

echo =====================================================================
echo                Grading System - Git Auto Update Tool
echo =====================================================================
echo.

if not exist "git_config.txt" (
    echo [LOI] Khong tim thay file git_config.txt!
    echo.
    goto END
)

set "ALL_ENGINE_DIR=All Engine"

for /f "usebackq eol=# tokens=1,* delims==" %%A in ("git_config.txt") do (
    set "SERVICE_NAME=%%A"
    set "CONFIG_VAL=%%B"
    
    if not "!CONFIG_VAL!"=="" (
        REM Parse REPO_URL and BRANCH split by |
        for /f "tokens=1,2 delims=|" %%I in ("!CONFIG_VAL!") do (
            set "REPO_URL=%%I"
            set "BRANCH=%%J"
        )
        
        set "TARGET_PATH=%ALL_ENGINE_DIR%\!SERVICE_NAME!"
        
        echo.
        echo -------------------------------------------------------------
        echo Kiem tra: !SERVICE_NAME! - Nhanh: !BRANCH!
        echo Duong dan: !TARGET_PATH!
        echo -------------------------------------------------------------
        
        if exist "!TARGET_PATH!\.git" (
            pushd "!TARGET_PATH!"
            
            REM Check for uncommitted changes
            set HAS_CHANGES=0
            for /f "tokens=*" %%i in ('git status --porcelain') do (
                set HAS_CHANGES=1
            )
            
            if !HAS_CHANGES! equ 1 (
                echo [CANH BAO] Co code chua commit trong !SERVICE_NAME!.
                echo Vui long chon mot trong cac lua chon sau:
                echo   [1] Commit code vao mot NHANH MOI - New Branch - va pull
                echo   [2] Commit code vao NHANH HIEN TAI - Current Branch - va pull
                echo   [3] Khong commit code va thuc hien pull luon
                echo.
                
                set /p CHOICE="Nhap lua chon cua ban [1, 2, 3]: "
                
                if "!CHOICE!"=="1" (
                    echo.
                    set /p NEW_BRANCH="Nhap ten nhanh moi: "
                    if "!NEW_BRANCH!"=="" (
                        echo [LOI] Ten nhanh khong duoc de trong.
                    ) else (
                        set /p COMMIT_MSG="Nhap commit message - Nhan Enter de lay mac dinh: "
                        if "!COMMIT_MSG!"=="" set "COMMIT_MSG=Auto update before pull"
                        
                        echo Dang tao nhanh moi: !NEW_BRANCH!...
                        git checkout -b !NEW_BRANCH!
                        
                        echo Dang commit code...
                        git add -A
                        git commit -m "!COMMIT_MSG!"
                        
                        echo Dang pull tu upstream...
                        git pull origin !BRANCH!
                    )
                ) else if "!CHOICE!"=="2" (
                    echo.
                    set /p COMMIT_MSG="Nhap commit message - Nhan Enter de lay mac dinh: "
                    if "!COMMIT_MSG!"=="" set "COMMIT_MSG=Auto update before pull"
                    
                    echo Dang commit code vao nhanh hien tai...
                    git add -A
                    git commit -m "!COMMIT_MSG!"
                    
                    echo Dang pull code...
                    git pull origin !BRANCH!
                ) else if "!CHOICE!"=="3" (
                    echo.
                    echo Thuc hien pull luon...
                    git pull origin !BRANCH!
                ) else (
                    echo [LOI] Lua chon khong hop le.
                )
            ) else (
                echo [INFO] Nguon code sach se. Dang pull code...
                git checkout !BRANCH!
                git pull origin !BRANCH!
            )
            
            popd
        ) else (
            echo [WARNING] Thu muc "!TARGET_PATH!" chua duoc clone hoac khong phai repository Git.
            echo Dang thuc hien clone moi ve...
            git clone -b !BRANCH! !REPO_URL! "!TARGET_PATH!"
        )
        echo.
    )
)

:END
echo.
echo =====================================================================
echo Nhan phim ENTER de thoat...
set /p DUMMY=

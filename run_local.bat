@echo off
setlocal enabledelayedexpansion

echo =====================================================================
echo                Grading System - Local Run Script
echo =====================================================================
echo.

REM --- Step 1: Release Ports 5173, 5174, 5175, 5176, 5177 if in use ---
for %%P in (5173 5174 5175 5176 5177) do (
    echo Checking if port %%P is currently occupied...
    for /f "tokens=5" %%a in ('netstat -aon ^| findstr ":%%P" ^| findstr "LISTENING"') do (
        echo Found process ID %%a occupying port %%P. Terminating process...
        taskkill /f /pid %%a
    )
)
echo.

REM --- Step 2: Run local APIs ---
echo Starting Grading Engine API locally...
start "Engine Service" dotnet run --project "All Engine\Engine_Service\PRN232.GradingEngine.Api\PRN232.GradingEngine.Api.csproj"

echo Starting Plagiarism Service API locally...
start "Plagiarism Service" dotnet run --project "All Engine\Plagiarism_Service\PRN232.PlagiarismService.Api\PRN232.PlagiarismService.Api.csproj"

echo Starting Notification Service API locally...
start "Notification Service" dotnet run --project "All Engine\Notification_Service\PRN232.NotificationService.Api\PRN232.NotificationService.Api.csproj"

echo Starting Exam Account Service API locally...
start "Exam Account Service" dotnet run --project "All Engine\Exam_Account_Service\PRN232.ExamAccountService.Api\PRN232.ExamAccountService.Api.csproj"

echo Starting FE Service locally...
start "FE Service" cmd /k "cd /d "%~dp0All Engine\FE_Service" && npm install && npm run dev"

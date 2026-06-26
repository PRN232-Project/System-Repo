@echo off
setlocal enabledelayedexpansion

echo =====================================================================
echo                Grading System - Local Run Script
echo =====================================================================
echo.

REM --- Step 1: Release Port 5174 if in use ---
echo Checking if port 5174 is currently occupied...
for /f "tokens=5" %%a in ('netstat -aon ^| findstr ":5174" ^| findstr "LISTENING"') do (
    echo Found process ID %%a occupying port 5174. Terminating process...
    taskkill /f /pid %%a
)
echo.

REM --- Step 2: Run local API ---
echo Starting Grading Engine API locally...
dotnet run --project "All Engine\Engine_Service\PRN232.GradingEngine.Api\PRN232.GradingEngine.Api.csproj"

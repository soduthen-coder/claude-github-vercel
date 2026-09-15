@echo off
REM ship.cmd - launcher for PowerShell / Command Prompt / double-click
REM ASCII only: cmd.exe misreads UTF-8 Korean and tries to run it.
setlocal
set "SH="
for %%P in (
  "%ProgramFiles%\Git\bin\bash.exe"
  "%ProgramFiles(x86)%\Git\bin\bash.exe"
  "%LocalAppData%\Programs\Git\bin\bash.exe"
) do if not defined SH if exist %%P set "SH=%%~P"
if not defined SH for /f "delims=" %%P in (
'where bash 2^>nul'
) do if not defined SH set "SH=%%P"
if not defined SH (
  echo.
  echo   Git is not installed. Get it from https://git-scm.com/downloads
  echo.
  pause
  exit /b 1
)
"%SH%" "%~dp0ship.sh" %*
if errorlevel 1 pause

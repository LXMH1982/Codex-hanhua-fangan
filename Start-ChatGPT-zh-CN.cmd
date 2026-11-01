@echo off
setlocal

set "SCRIPT_PATH=%~dp0launch-chatgpt-zh-cn-cdp.ps1"
set "LOG_PATH=%LOCALAPPDATA%\Codex\locale-patch\chatgpt-zh-cn-cdp.log"

if not exist "%SCRIPT_PATH%" (
  echo [ERROR] Launcher script not found:
  echo         %SCRIPT_PATH%
  echo.
  pause
  exit /b 1
)

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_PATH%" %*
set "EXIT_CODE=%ERRORLEVEL%"

if not "%EXIT_CODE%"=="0" (
  echo.
  echo [ERROR] ChatGPT could not be started with the Chinese UI patch.
  echo Diagnostic log:
  echo %LOG_PATH%
  echo.
  pause
)

exit /b %EXIT_CODE%

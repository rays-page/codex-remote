@echo off
setlocal
cd /d "%~dp0"

set "BUNDLED_PYTHON=%USERPROFILE%\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe"
if exist "%BUNDLED_PYTHON%" (
    "%BUNDLED_PYTHON%" "%~dp0codex_remote_desktop.py" launch %*
    exit /b %errorlevel%
)

where py >nul 2>nul
if not errorlevel 1 (
    py -3 "%~dp0codex_remote_desktop.py" launch %*
    exit /b %errorlevel%
)

where python >nul 2>nul
if not errorlevel 1 (
    python "%~dp0codex_remote_desktop.py" launch %*
    exit /b %errorlevel%
)

echo Could not find a usable Python interpreter.
echo Install Python 3 or run this from the Codex desktop environment.
exit /b 1

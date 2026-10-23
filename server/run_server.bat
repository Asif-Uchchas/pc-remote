@echo off
setlocal enabledelayedexpansion
cd /d "%~dp0"
title Mobile Remote server

rem ---------------------------------------------------------------------------
rem Find a Python that actually runs. Plain "python" is unreliable on Windows:
rem C:\Users\<you>\AppData\Local\Microsoft\WindowsApps\python.exe is a 0-byte
rem Microsoft Store stub that prints "Python was not found..." and exits 9009,
rem and it often sits earlier in PATH than the real install. So each candidate
rem below is executed before it is accepted.
rem ---------------------------------------------------------------------------
set "PY="
set "PYARGS="

rem python.org "Python Install Manager" shims
call :check "%LOCALAPPDATA%\Python\bin\python.exe"

rem the py launcher
if not defined PY call :check "py" "-3"

rem per-user and machine-wide python.org installs
for /d %%D in ("%LOCALAPPDATA%\Programs\Python\Python3*") do call :check "%%~D\python.exe"
for /d %%D in ("%ProgramFiles%\Python3*") do call :check "%%~D\python.exe"
for /d %%D in ("C:\Python3*") do call :check "%%~D\python.exe"

rem whatever is on PATH, last (this is where the Store stub lives)
if not defined PY call :check "python"

if not defined PY (
    echo.
    echo   Could not find a working Python installation.
    echo.
    echo   If "python" opens the Microsoft Store or says "Python was not found",
    echo   that is Windows' app alias, not a real Python. Either:
    echo     * install Python from https://www.python.org/downloads/  ^(tick
    echo       "Add python.exe to PATH" during setup^), or
    echo     * turn the alias off: Settings ^> Apps ^> Advanced app settings ^>
    echo       App execution aliases ^> switch off python.exe and python3.exe
    echo.
    pause
    exit /b 1
)

echo Using: %PY% %PYARGS%

rem Install the dependencies the first time.
"%PY%" %PYARGS% -c "import pynput, pystray, PIL" >nul 2>&1
if errorlevel 1 (
    echo Installing dependencies, this takes a minute...
    "%PY%" %PYARGS% -m pip install -r requirements.txt
    if errorlevel 1 (
        echo.
        echo   Installing the dependencies failed. Check your internet connection.
        pause
        exit /b 1
    )
)

echo.
"%PY%" %PYARGS% server.py
echo.
pause
exit /b 0

rem ---------------------------------------------------------------------------
:check
if defined PY goto :eof
set "CAND=%~1"
set "CARG=%~2"
if /i "%CAND%"=="py" goto :run
if /i "%CAND%"=="python" goto :run
if not exist "%CAND%" goto :eof
:run
"%CAND%" %CARG% -c "import sys" >nul 2>&1
if errorlevel 1 goto :eof
set "PY=%CAND%"
set "PYARGS=%CARG%"
goto :eof

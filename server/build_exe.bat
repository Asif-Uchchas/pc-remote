@echo off
rem Builds dist\MobileRemote.exe (single file, no console). Needs: pip install pyinstaller -r requirements.txt
cd /d "%~dp0"
python -m PyInstaller --noconfirm --clean MobileRemote.spec
if errorlevel 1 (echo Build failed & pause & exit /b 1)
echo.
echo Built: %~dp0dist\MobileRemote.exe
pause

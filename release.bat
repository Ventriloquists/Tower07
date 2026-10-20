@echo off
rem ======================================================================
rem  TOWER 07 // RELEASE BUILD
rem  Packs the game into Tower07.love, fuses it with love.exe into
rem  Tower07.exe, copies the LOVE runtime DLLs next to it and zips the
rem  folder into Release\Tower07-win64-<date>.zip, ready to share.
rem
rem  Needs: LOVE 11.x installed (default: C:\Program Files\LOVE, or set
rem         LOVE_DIR), and tar.exe (built into Windows 10 1803+ / 11).
rem ======================================================================
setlocal EnableExtensions
cd /d "%~dp0"

set "NAME=Tower07"

rem --- find LOVE ----------------------------------------------------------
if not defined LOVE_DIR set "LOVE_DIR=%ProgramFiles%\LOVE"
if not exist "%LOVE_DIR%\love.exe" set "LOVE_DIR=%ProgramFiles(x86)%\LOVE"
if not exist "%LOVE_DIR%\love.exe" (
  echo [!] love.exe not found. Install LOVE 11.4 or run:  set LOVE_DIR=C:\path\to\LOVE
  goto :fail
)
where tar >nul 2>nul
if errorlevel 1 (
  echo [!] tar.exe not found. It ships with Windows 10 ^(1803+^) and Windows 11.
  goto :fail
)

for /f %%d in ('powershell -NoProfile -Command "Get-Date -Format yyyy-MM-dd"') do set "STAMP=%%d"
set "BUILD=Release\build"
set "OUT=Release\%NAME%"
set "ZIP=Release\%NAME%-win64-%STAMP%.zip"

echo.
echo  TOWER 07 // RELEASE BUILD
echo  LOVE:   %LOVE_DIR%
echo  Output: %ZIP%
echo.

rem --- clean ---------------------------------------------------------------
if exist "%BUILD%" rmdir /s /q "%BUILD%"
if exist "%OUT%" rmdir /s /q "%OUT%"
mkdir "%BUILD%" || goto :fail
mkdir "%OUT%" || goto :fail

rem --- 1. game files -> Tower07.love (a zip with main.lua at its root) -----
echo [1/4] Packing game files...
set "ITEMS=conf.lua main.lua game lib ui"

rem *.sfk are waveform caches from audio editors, not needed by the game
tar -a -c -f "%BUILD%\%NAME%.zip" --exclude=*.sfk %ITEMS%
if errorlevel 1 goto :fail
move /y "%BUILD%\%NAME%.zip" "%BUILD%\%NAME%.love" >nul || goto :fail

rem --- 2. fuse: love.exe + game = standalone exe ---------------------------
echo [2/4] Fusing %NAME%.exe...
copy /b "%LOVE_DIR%\love.exe"+"%BUILD%\%NAME%.love" "%OUT%\%NAME%.exe" >nul
if errorlevel 1 goto :fail

rem --- 3. runtime DLLs the exe needs, plus the LOVE license (zlib) ----------
echo [3/4] Copying runtime...
for %%f in (love.dll lua51.dll mpg123.dll msvcp120.dll msvcr120.dll OpenAL32.dll SDL2.dll) do (
  if not exist "%LOVE_DIR%\%%f" (
    echo [!] missing %%f in %LOVE_DIR%
    goto :fail
  )
  copy /y "%LOVE_DIR%\%%f" "%OUT%\" >nul || goto :fail
)
if exist "%LOVE_DIR%\license.txt" copy /y "%LOVE_DIR%\license.txt" "%OUT%\LOVE-license.txt" >nul
(
  echo TOWER 07 // HARVEST PROTOCOL
  echo.
  echo Start: double-click %NAME%.exe. Keep all files in this folder together.
  echo Saves: %%APPDATA%%\tower_harvest
  echo Settings: ESC on the CORE screen. F9 always resets the theme. F12 = boss key.
  echo.
  echo Made with LOVE ^(https://love2d.org^), see LOVE-license.txt.
) > "%OUT%\README.txt"

rem --- 4. shareable zip ------------------------------------------------------
echo [4/4] Zipping...
if exist "%ZIP%" del /q "%ZIP%"
tar -a -c -f "%ZIP%" -C Release %NAME%
if errorlevel 1 goto :fail
rmdir /s /q "%BUILD%"

for %%z in ("%ZIP%") do set "SIZE=%%~zz"
echo.
echo  DONE: %ZIP%  (%SIZE% bytes)
echo  Folder: %OUT%  (run %NAME%.exe to test)
echo.
if not defined NOPAUSE pause
exit /b 0

:fail
echo.
echo  BUILD FAILED
echo.
if not defined NOPAUSE pause
exit /b 1

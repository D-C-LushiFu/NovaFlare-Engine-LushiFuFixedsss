@echo off
rem ============================================================
rem  make_payload_rar.bat
rem  Builds payload.rar automatically from the engine's windows
rem  build output (export\legacy-gc\windows\bin) - no manual
rem  WinRAR step needed any more.
rem
rem  The archive is FLAT (engine files sit at the archive root),
rem  because the installer extracts it straight into the target
rem  folder with:  unrar x -y -o+ -p- -idq payload.rar <dest>
rem
rem  RAR5 is used explicitly to match the embedded UnRAR 7.00.
rem
rem  Only the files needed to run the game are included. User and
rem  run-time data is excluded, as are the leftover archives the
rem  old manual workflow used to leave inside bin\.
rem
rem  NOTE: absolute paths are used for the archive location, because
rem        the packing runs with the working directory set to bin\.
rem ============================================================
setlocal
set "INSTDIR=%~dp0"
cd /d "%INSTDIR%"

set "RAR=C:\Program Files\WinRAR\Rar.exe"
set "BIN=..\export\legacy-gc\windows\bin"
set "OUT=%INSTDIR%payload.rar"
set "TMP=%INSTDIR%payload.new.rar"

if not exist "%RAR%" (
  echo [ERROR] Rar.exe not found: "%RAR%"
  echo         Install WinRAR, or edit RAR= in this file.
  exit /b 1
)
if not exist "%BIN%\" (
  echo [ERROR] engine build output not found: %BIN%
  echo         Build the windows target first.
  exit /b 1
)

if exist "%TMP%" del /f /q "%TMP%"

echo [payload] packing "%BIN%" -^> payload.rar ...
echo           (only what the game needs; user data and archives skipped)

pushd "%BIN%"
"%RAR%" a -cfg- -r -m5 -ep1 -idq -ol -y ^
  "-xcrash" "-xlogs" "-xmods" "-xsaves" "-xreplays" ^
  "-xmodsList.txt" "-xmodsList.txt.bak_debug" "-xemk_bind_log.txt" ^
  "-xui_mark.log" "-x*.zip" "-x*.rar" "-x*.bak" "-x*.bak_debug" ^
  "%TMP%" "*"
set "RC=%ERRORLEVEL%"
popd

if not "%RC%"=="0" (
  echo [ERROR] Rar.exe failed with exit code %RC%
  if exist "%TMP%" del /f /q "%TMP%"
  exit /b 1
)

if not exist "%TMP%" (
  echo [ERROR] archive was not created: %TMP%
  exit /b 1
)

move /y "%TMP%" "%OUT%" >nul || exit /b 1

echo [payload] OK
for %%F in ("%OUT%") do echo           %%~nxF  %%~zF bytes
endlocal

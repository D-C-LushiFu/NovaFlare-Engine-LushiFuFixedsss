@echo off
rem ============================================================
rem  One-click rebuild of the NovaFlare installer.
rem  (filename is Chinese on purpose; content stays pure ASCII so
rem   cmd can parse it on any locale - no codepage issues)
rem
rem  Workflow: update resources -> re-export windows build ->
rem  re-create "NovaFlare Engine.rar" inside
rem  export\legacy-gc\windows\bin with WinRAR -> run this file.
rem ============================================================
setlocal
cd /d "%~dp0"

echo ================================================
echo   NovaFlare Installer - one-click rebuild
echo   (???????? - see file name)
echo ================================================
echo  [1/1] calling NovaFlareEngineInstaller\build.bat ...
echo        (refreshes payload.rar, compiles, appends the
echo         payload, verifies the footer, updates dist\)
echo.

call "NovaFlareEngineInstaller\build.bat"
if errorlevel 1 (
  echo.
  echo  [FAILED] build error - see log above.
  pause
  exit /b 1
)

echo.
echo ================================================
echo  DONE. Latest single-file installer:
echo    NovaFlareEngineInstaller\dist\NovaFlareEngine-1.2.1ButLushiFuFixedsss-Installer.exe
for %%F in ("NovaFlareEngineInstaller\dist\NovaFlareEngine-1.2.1ButLushiFuFixedsss-Installer.exe") do echo    size: %%~zF bytes
echo ================================================
pause
endlocal
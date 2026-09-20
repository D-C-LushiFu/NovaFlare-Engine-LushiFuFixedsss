@echo off
rem ============================================================
rem  build.bat - full installer build (RAR payload distribution)
rem  1) (re)generate icon.res from icon.rc if missing
rem  2) pack payload.rar AUTOMATICALLY from the engine windows
rem     build output (export\legacy-gc\windows\bin) - only the
rem     files the game needs; no manual WinRAR step any more
rem  3) compile installer (embeds unrar.exe + icon)
rem  4) copy result and append the payload to the exe itself
rem  5) verify appended footer and refresh dist\ (single file)
rem ============================================================
setlocal
cd /d "%~dp0"

set "BIN=..\export\legacy-gc\windows\bin"
set "VCVARS=C:\Program Files\Microsoft Visual Studio\18\Community\VC\Auxiliary\Build\vcvars64.bat"
set "OUT_EXE=NovaFlareEngine-1.2.1ButLushiFuFixedsss-Installer.exe"

if not exist icon.res (
  if not exist "%VCVARS%" (
    echo [ERROR] icon.res missing and Visual Studio not found - run rc.exe manually:
    echo         rc /fo icon.res icon.rc
    exit /b 1
  )
  echo [0/5] building icon.res ...
  call "%VCVARS%" >nul 2>&1
  rc /fo icon.res icon.rc || exit /b 1
)

echo [1/5] building payload.rar from "%BIN%" ^(automatic^) ...
if exist payload.zip del /f /q payload.zip
call make_payload_rar.bat || exit /b 1

echo [2/5] compiling installer (unrar.exe + icon embedded)...
haxe -cp src -main Main -cpp bin\cpp -D HXCPP_M64 -resource unrar.exe@unrar || exit /b 1

echo [3/5] copying exe ...
copy /y bin\cpp\Main.exe "%OUT_EXE%" >nul || exit /b 1

echo [4/5] appending payload.rar to exe ...
powershell -NoProfile -ExecutionPolicy Bypass -File tools\append_payload.ps1 -Exe "%OUT_EXE%" -Payload payload.rar || exit /b 1

echo [5/5] verifying appended payload footer ...
powershell -NoProfile -Command "$b=[IO.File]::ReadAllBytes('%OUT_EXE%'); $m=[Text.Encoding]::ASCII.GetString($b, $b.Length-24, 8); if ($m -ne 'NFPL0100') { Write-Output 'FOOTER CHECK FAILED'; exit 1 } else { Write-Output 'footer OK' }" || exit /b 1

echo [5/5] refreshing dist\ ...
if not exist dist mkdir dist
copy /y "%OUT_EXE%" "dist\%OUT_EXE%" >nul || exit /b 1

echo.
echo Build OK: dist\%OUT_EXE%
endlocal

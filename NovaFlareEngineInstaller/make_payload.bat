@echo off
rem ============================================================
rem  make_payload.bat
rem  Packs the payload\ folder into payload.zip using the
rem  STORE method (no compression), with a cpp-built pack tool
rem  (UTF-8 safe on every Windows locale).
rem ============================================================
setlocal
cd /d "%~dp0"

if not exist payload\ (
  echo [ERROR] "payload\" folder not found - nothing to pack.
  exit /b 1
)

if not exist bin\packtool\PackStore.exe (
  echo [1/2] building pack tool (cpp)...
  haxe -cp tools -main PackStore -cpp bin\packtool -D HXCPP_M64 || exit /b 1
)

echo [2/2] packing payload\ -^> payload.zip (store)...
bin\packtool\PackStore.exe payload payload.zip || exit /b 1
echo OK: payload.zip
endlocal

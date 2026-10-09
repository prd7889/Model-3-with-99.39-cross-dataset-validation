@echo off
setlocal

where flutter >nul 2>nul
if errorlevel 1 (
  echo Flutter was not found on PATH.
  exit /b 1
)

call flutter pub get || exit /b 1
call flutter build windows --release || exit /b 1

set "BUNDLE=build\windows\x64\runner\Release"
set "ARCHIVE=OCT-Sort-windows-x64.zip"

if exist "%ARCHIVE%" del "%ARCHIVE%"
powershell -NoProfile -Command "Compress-Archive -Path '%BUNDLE%\*' -DestinationPath '%ARCHIVE%'" || exit /b 1

echo.
echo Windows build complete:
echo   Executable: %BUNDLE%\oct_classifier.exe
echo   Portable bundle: %ARCHIVE%

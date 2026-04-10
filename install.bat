@echo off

set INSTALL_DIR=%USERPROFILE%\cpp-cli

echo Installing cpp-cli in %INSTALL_DIR%...

if not exist %INSTALL_DIR% (
    mkdir %INSTALL_DIR%
)

xcopy /E /I /Y * %INSTALL_DIR%

echo Adding to PATH...
setx PATH "%PATH%;%INSTALL_DIR%\bin"

echo Done. You can now use: cgen
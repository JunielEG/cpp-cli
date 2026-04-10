@echo off
setlocal

set "TOOL_NAME=cpp-cli"
set "REPO_URL=https://github.com/JunielEG/cpp-cli.git"
set "INSTALL_DIR=%USERPROFILE%\ScaffoldingTools\%TOOL_NAME%"

:: Si no encuentra los archivos los clona
if exist "%~dp0windows\cppx.bat" (
    echo Source found locally, installing from current folder...
    set "SOURCE_DIR=%~dp0"
) else (
    echo Cloning %TOOL_NAME%...
    git clone "%REPO_URL%" "%TEMP%\%TOOL_NAME%-install"
    if errorlevel 1 (
        echo ERROR: git clone failed.
        pause & exit /b 1
    )
    set "SOURCE_DIR=%TEMP%\%TOOL_NAME%-install\"
)

:: Crear carpeta destino
echo Installing in %INSTALL_DIR%...
if not exist "%INSTALL_DIR%" mkdir "%INSTALL_DIR%"

:: Copiar archivos necesarios
xcopy /E /I /Y "%SOURCE_DIR%templates"  "%INSTALL_DIR%\templates\" > nul
copy /Y "%SOURCE_DIR%windows\cppx.bat"          "%INSTALL_DIR%\cppx.bat"   > nul
copy /Y "%SOURCE_DIR%windows\cppx.ps1"          "%INSTALL_DIR%\cppx.ps1"   > nul

:: Limpiar carpeta temporal si se clono
if exist "%TEMP%\%TOOL_NAME%-install" (
    rmdir /s /q "%TEMP%\%TOOL_NAME%-install"
)

:: Agregar al PATH sin romperlo
echo Adding to PATH...
for /f "skip=2 tokens=3*" %%A in (
    'reg query "HKCU\Environment" /v PATH 2^>nul'
) do set "CURRENT_PATH=%%A %%B"

echo %CURRENT_PATH% | findstr /i /c:"%INSTALL_DIR%" > nul
if errorlevel 1 (
    setx PATH "%CURRENT_PATH%;%INSTALL_DIR%"
) else (
    echo PATH already contains %INSTALL_DIR%, skipping.
)

echo.
echo Done. Restart your terminal and use: cppx
endlocal
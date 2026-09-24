@echo off
setlocal EnableExtensions DisableDelayedExpansion

pushd "%~dp0"
if errorlevel 1 (
    echo ERROR: cannot enter MCP directory.
    exit /b 1
)

echo ============================================================
echo MCP - UPDATE
echo ============================================================
echo.

call "%CD%\bat\01_prepare.bat"
if errorlevel 1 goto :fail

call "%CD%\bat\02_dump_config.bat"
if errorlevel 1 goto :fail

call "%CD%\bat\03_pack.bat"
if errorlevel 1 goto :fail

call "%CD%\bat\04_upload.bat"
if errorlevel 1 goto :fail

echo.
echo ============================================================
echo MCP UPDATE COMPLETED
echo ============================================================
popd
exit /b 0

:fail
set "RC=%errorlevel%"
echo.
echo ============================================================
echo MCP UPDATE FAILED. Code: %RC%
echo ============================================================
popd
exit /b %RC%

@echo off
setlocal EnableExtensions DisableDelayedExpansion

echo ============================================================
echo MCP - UPDATE
echo ============================================================
echo.

call "%~dp0bat\01_prepare.bat"
if errorlevel 1 exit /b %errorlevel%

call "%~dp0bat\02_dump_config.bat"
if errorlevel 1 exit /b %errorlevel%

call "%~dp0bat\03_pack.bat"
if errorlevel 1 exit /b %errorlevel%

call "%~dp0bat\04_upload.bat"
if errorlevel 1 exit /b %errorlevel%

echo.
echo ============================================================
echo MCP UPDATE COMPLETED
echo ============================================================
exit /b 0

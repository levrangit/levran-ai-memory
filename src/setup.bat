@echo off
setlocal EnableExtensions DisableDelayedExpansion
title MCP - Setup

rem ============================================================
rem MCP setup wizard
rem Configuration is stored only in JSON files.
rem This BAT contains the setup logic.
rem ============================================================

set "SCRIPT_DIR=%~dp0"
set "MCP_PROJECT=%SCRIPT_DIR%"
set "CONFIG_DIR=%MCP_PROJECT%config"
set "TERMINALS_DIR=%CONFIG_DIR%terminals"
set "DATABASES_DIR=%CONFIG_DIR%databases"

if not exist "%CONFIG_DIR%" mkdir "%CONFIG_DIR%"
if not exist "%TERMINALS_DIR%" mkdir "%TERMINALS_DIR%"
if not exist "%DATABASES_DIR%" mkdir "%DATABASES_DIR%"

set "COMMON_JSON=%CONFIG_DIR%common.json"
set "COMPUTER=%COMPUTERNAME%"
set "USER_NAME=%USERNAME%"
set "TERMINAL_JSON=%TERMINALS_DIR%%COMPUTER%.json"
set "DATABASE_DIR=%DATABASES_DIR%%COMPUTER%"

echo.
echo ============================================================
echo  MCP - НАСТРОЙКА
echo ============================================================
echo.
echo Компьютер: %COMPUTER%
echo Пользователь: %USER_NAME%
echo.

call :LoadCommon
if errorlevel 1 exit /b 1

call :LoadTerminal
if errorlevel 1 exit /b 1

:MENU
echo.
echo ============================================================
echo  ТЕКУЩАЯ НАСТРОЙКА
echo ============================================================
echo.
echo [1] Настроить терминал
echo [2] Добавить базу
echo [3] Выход
echo.
set "MENU_CHOICE="
set /p "MENU_CHOICE=Выберите действие [1-3]: "

if "%MENU_CHOICE%"=="1" goto TERMINAL_SETUP
if "%MENU_CHOICE%"=="2" goto DATABASE_SETUP
if "%MENU_CHOICE%"=="3" goto DONE

echo Неверный выбор.
goto MENU

:TERMINAL_SETUP
echo.
echo ------------------------------------------------------------
echo  НАСТРОЙКА ОБЩИХ ПАРАМЕТРОВ
echo ------------------------------------------------------------
echo.

set "NEW_RDP_DRIVE=%RDP_DRIVE%"
echo RDP-диск:
echo [%RDP_DRIVE%]
set /p "NEW_RDP_DRIVE=Новый RDP-диск (Enter - оставить текущее): "
if not defined NEW_RDP_DRIVE set "NEW_RDP_DRIVE=%RDP_DRIVE%"

if not exist "%NEW_RDP_DRIVE%\" (
    echo.
    echo ВНИМАНИЕ: путь "%NEW_RDP_DRIVE%" сейчас недоступен.
    echo Проверьте, что RDP-диск подключен.
    echo.
    set "CONFIRM="
    set /p "CONFIRM=Сохранить этот путь всё равно? [Y/N]: "
    if /I not "%CONFIRM%"=="Y" goto MENU
)

set "RDP_DRIVE=%NEW_RDP_DRIVE%"

set "NEW_MCP_PATH=%MCP_PATH%"
echo.
echo Путь MCP на RDP-диске:
echo [%MCP_PATH%]
set /p "NEW_MCP_PATH=Новый путь (Enter - оставить текущее): "
if not defined NEW_MCP_PATH set "NEW_MCP_PATH=%MCP_PATH%"
set "MCP_PATH=%NEW_MCP_PATH%"

call :SaveCommon
if errorlevel 1 exit /b 1

echo.
echo Рабочий каталог терминала:
echo [%MCP_WORK%]
set "NEW_MCP_WORK="
set /p "NEW_MCP_WORK=Новый путь (Enter - оставить текущее): "
if not defined NEW_MCP_WORK set "NEW_MCP_WORK=%MCP_WORK%"

echo.
echo Путь к 1cv8.exe:
echo [%ONEC_BIN%]
set "NEW_ONEC_BIN="
set /p "NEW_ONEC_BIN=Новый путь (Enter - оставить текущее): "
if not defined NEW_ONEC_BIN set "NEW_ONEC_BIN=%ONEC_BIN%"

set "MCP_WORK=%NEW_MCP_WORK%"
set "ONEC_BIN=%NEW_ONEC_BIN%"

if not exist "%MCP_WORK%\" (
    echo.
    set "CREATE_WORK="
    set /p "CREATE_WORK=Рабочего каталога нет. Создать его? [Y/N]: "
    if /I "%CREATE_WORK%"=="Y" (
        mkdir "%MCP_WORK%" 2>nul
        if errorlevel 1 (
            echo Не удалось создать "%MCP_WORK%".
            exit /b 1
        )
    )
)

if not exist "%MCP_WORK%\" (
    echo Рабочий каталог не найден: "%MCP_WORK%"
    echo.
    goto MENU
)

if not exist "%ONEC_BIN%" (
    echo.
    echo ВНИМАНИЕ: 1cv8.exe не найден:
    echo "%ONEC_BIN%"
    echo.
)

call :SaveTerminal
if errorlevel 1 exit /b 1

echo.
echo Терминал сохранён:
echo "%TERMINAL_JSON%"
goto MENU

:DATABASE_SETUP
echo.
echo ------------------------------------------------------------
echo  ДОБАВЛЕНИЕ БАЗЫ
echo ------------------------------------------------------------
echo.

if not exist "%DATABASE_DIR%\" mkdir "%DATABASE_DIR%"

set "DB_SOURCE_ID="
set /p "DB_SOURCE_ID=DB_SOURCE_ID: "
if not defined DB_SOURCE_ID (
    echo DB_SOURCE_ID не может быть пустым.
    goto MENU
)

echo(%DB_SOURCE_ID%| findstr /r /x "[A-Za-z0-9][A-Za-z0-9_-]*" >nul
if errorlevel 1 (
    echo Некорректный DB_SOURCE_ID.
    echo Разрешены только латинские буквы, цифры, "_" и "-".
    goto MENU
)

call :ValidateSourceId "%DB_SOURCE_ID%"
if errorlevel 1 goto MENU

set "DB_SERVER="
set /p "DB_SERVER=Сервер 1С: "
if not defined DB_SERVER (
    echo Сервер 1С не может быть пустым.
    goto MENU
)

set "DB_DATABASE="
set /p "DB_DATABASE=Имя базы: "
if not defined DB_DATABASE (
    echo Имя базы не может быть пустым.
    goto MENU
)

set "DB_USER="
set /p "DB_USER=Пользователь 1С: "
if not defined DB_USER (
    echo Пользователь не может быть пустым.
    goto MENU
)

set "DB_PASSWORD="
set /p "DB_PASSWORD=Пароль 1С: "

set "EXTENSIONS="
set /a EXT_INDEX=0

:EXTENSION_INPUT
set /a EXT_INDEX+=1
set "EXTENSION_VALUE="
set /p "EXTENSION_VALUE=Имя расширения %EXT_INDEX%: "

if not defined EXTENSION_VALUE (
    if %EXT_INDEX% EQU 1 (
        echo Первое расширение должно быть указано.
        set /a EXT_INDEX-=1
        goto EXTENSION_INPUT
    ) else (
        set /a EXT_INDEX-=1
        goto SAVE_DATABASE
    )
)

if defined EXTENSIONS (
    set "EXTENSIONS=%EXTENSIONS%|%EXTENSION_VALUE%"
) else (
    set "EXTENSIONS=%EXTENSION_VALUE%"
)

echo.
set "CONTINUE_EXT="
set /p "CONTINUE_EXT=Продолжить? (N - ввести имя следующего расширения, Enter - закончить): "
if /I "%CONTINUE_EXT%"=="N" goto EXTENSION_INPUT

:SAVE_DATABASE
set "DB_JSON=%DATABASE_DIR%\%DB_SOURCE_ID%.json"

call :SaveDatabase
if errorlevel 1 exit /b 1

echo.
echo База сохранена:
echo "%DB_JSON%"
echo.

set "ADD_MORE="
set /p "ADD_MORE=Добавить ещё одну базу на этом терминале? [Y/N]: "
if /I "%ADD_MORE%"=="Y" goto DATABASE_SETUP
goto MENU

:DONE
echo.
echo Настройка завершена.
echo.
goto :END

:LoadCommon
if not exist "%COMMON_JSON%" (
    echo Файл common.json отсутствует. Будет создан мастерoм настройки.
    set "RDP_DRIVE=\\tsclient\L"
    set "MCP_PATH=!work\RAU_IT\MCP"
    call :SaveCommon
    if errorlevel 1 exit /b 1
    exit /b 0
)

for /f "usebackq delims=" %%A in (`powershell.exe -NoProfile -Command "$j=Get-Content -Raw -LiteralPath '%COMMON_JSON%' | ConvertFrom-Json; [Console]::WriteLine($j.rdp_drive); [Console]::WriteLine($j.mcp_path)"`) do (
    if not defined RDP_DRIVE (
        set "RDP_DRIVE=%%A"
    ) else if not defined MCP_PATH (
        set "MCP_PATH=%%A"
    )
)

if not defined RDP_DRIVE set "RDP_DRIVE=\\tsclient\L"
if not defined MCP_PATH set "MCP_PATH=!work\RAU_IT\MCP"
exit /b 0

:LoadTerminal
if not exist "%TERMINAL_JSON%" (
    set "MCP_WORK="
    set "ONEC_BIN="
    exit /b 0
)

for /f "usebackq tokens=1,* delims==" %%A in (`powershell.exe -NoProfile -Command "$j=Get-Content -Raw -LiteralPath '%TERMINAL_JSON%' | ConvertFrom-Json; 'MCP_WORK='+$j.mcp_work; 'ONEC_BIN='+$j.onec_bin"`) do (
    if "%%A"=="MCP_WORK" set "MCP_WORK=%%B"
    if "%%A"=="ONEC_BIN" set "ONEC_BIN=%%B"
)
exit /b 0

:SaveCommon
powershell.exe -NoProfile -Command "$o=[ordered]@{rdp_drive=$env:RDP_DRIVE;mcp_path=$env:MCP_PATH}; $o|ConvertTo-Json -Depth 5|Set-Content -LiteralPath $env:COMMON_JSON -Encoding UTF8"
if errorlevel 1 (
    echo Ошибка записи common.json.
    exit /b 1
)
exit /b 0

:SaveTerminal
set "MCP_PROJECT=%RDP_DRIVE%\%MCP_PATH%"
set "TERMINAL_NAME=%COMPUTER%"
set "TERMINAL_USER=%USER_NAME%"
powershell.exe -NoProfile -Command "$o=[ordered]@{computer_name=$env:TERMINAL_NAME;username=$env:TERMINAL_USER;mcp_work=$env:MCP_WORK;onec_bin=$env:ONEC_BIN}; $o|ConvertTo-Json -Depth 5|Set-Content -LiteralPath $env:TERMINAL_JSON -Encoding UTF8"
if errorlevel 1 (
    echo Ошибка записи файла терминала.
    exit /b 1
)
exit /b 0

:ValidateSourceId
set "CHECK_ID=%~1"
if not defined CHECK_ID exit /b 1

for /f "usebackq delims=" %%A in (`powershell.exe -NoProfile -Command "$id=[Environment]::GetEnvironmentVariable('CHECK_ID'); $files=Get-ChildItem -LiteralPath '%DATABASES_DIR%' -Filter '*.json' -File -Recurse -ErrorAction SilentlyContinue; foreach($f in $files){try{$j=Get-Content -Raw -LiteralPath $f.FullName|ConvertFrom-Json;if($j.db_source_id -eq $id){$f.FullName; exit 10}}catch{}}"`) do (
    echo.
    echo ОШИБКА: DB_SOURCE_ID "%CHECK_ID%" уже используется:
    echo %%A
    echo.
    exit /b 1
)

exit /b 0

:SaveDatabase
set "EXT_JSON="
for %%E in ("%EXTENSIONS:|=" "%") do (
    if defined EXT_JSON (
        set "EXT_JSON=%EXT_JSON%,"
    )
    set "EXT_JSON=%EXT_JSON%"%%~E""
)

set "DB_JSON=%DATABASE_DIR%\%DB_SOURCE_ID%.json"
set "EXT_JSON=%EXTENSIONS%"

powershell.exe -NoProfile -Command "$ext=if([string]::IsNullOrWhiteSpace($env:EXT_JSON)){@()}else{$env:EXT_JSON -split '\|'}; $o=[ordered]@{db_source_id=$env:DB_SOURCE_ID;db_server=$env:DB_SERVER;db_database=$env:DB_DATABASE;db_user=$env:DB_USER;db_password=$env:DB_PASSWORD;extensions=@($ext)}; $o|ConvertTo-Json -Depth 5|Set-Content -LiteralPath $env:DB_JSON -Encoding UTF8"
if errorlevel 1 (
    echo Ошибка записи файла базы.
    exit /b 1
)

exit /b 0

:END
endlocal
exit /b 0

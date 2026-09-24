#Requires -Version 5.1
# Если PowerShell запрещает запуск скрипта, выполните:
# Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
# Проверить текущую политику:
# Get-ExecutionPolicy -List

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$configDir = Join-Path $root 'config'
$computer = $env:COMPUTERNAME

Write-Host "------------------------------------------------------------"
Write-Host "MCP - DUMP CONFIG"
Write-Host "------------------------------------------------------------"

$terminalPath = Join-Path (Join-Path $configDir 'terminals') ($computer + '.json')
if (-not (Test-Path -LiteralPath $terminalPath -PathType Leaf)) { throw "Не найден файл терминала: $terminalPath" }
$terminal = Get-Content -Raw -LiteralPath $terminalPath -Encoding UTF8 | ConvertFrom-Json
$mcpWork = [string]$terminal.mcp_work
$onecBin = [string]$terminal.onec_bin
if (-not (Test-Path -LiteralPath $mcpWork -PathType Container)) { throw "Рабочий каталог не найден: $mcpWork" }
if (-not (Test-Path -LiteralPath $onecBin -PathType Leaf)) { throw "Не найден 1cv8.exe: $onecBin" }

$dbDir = Join-Path (Join-Path $configDir 'databases') $computer
$dbFiles = @(Get-ChildItem -LiteralPath $dbDir -Filter '*.json' -File)
if ($dbFiles.Count -eq 0) { throw "В каталоге нет JSON баз: $dbDir" }

$dumpDir = Join-Path $mcpWork 'dump'
$logsDir = Join-Path $mcpWork 'logs'
New-Item -ItemType Directory -Force -Path $dumpDir, $logsDir | Out-Null

foreach ($dbFile in $dbFiles) {
    $db = Get-Content -Raw -LiteralPath $dbFile.FullName -Encoding UTF8 | ConvertFrom-Json
    $id = [string]$db.db_source_id
    $server = [string]$db.db_server
    $database = [string]$db.db_database
    $user = [string]$db.db_user
    $password = [string]$db.db_password

    if ([string]::IsNullOrWhiteSpace($id) -or [string]::IsNullOrWhiteSpace($server) -or [string]::IsNullOrWhiteSpace($database) -or [string]::IsNullOrWhiteSpace($user)) {
        throw "Не заполнены обязательные параметры базы: $($dbFile.FullName)"
    }

    $finalRoot = Join-Path $dumpDir $id
    $stagingRoot = Join-Path $dumpDir ($id + '.__new')
    if (Test-Path -LiteralPath $stagingRoot) { Remove-Item -LiteralPath $stagingRoot -Recurse -Force }

    $configOut = Join-Path $stagingRoot 'config'
    $extensionsOut = Join-Path $stagingRoot 'extensions'
    New-Item -ItemType Directory -Force -Path $configOut, $extensionsOut | Out-Null

    $stamp = (Get-Date).ToString('yyyyMMdd_HHmmss')
    $logFile = Join-Path $logsDir ($id + '_dump_' + $stamp + '.log')

    Write-Host ""
    Write-Host "Выгрузка базы: $id"
    Write-Host "Сервер: $server"
    Write-Host "База: $database"

    $mainArgs = @('DESIGNER','/S' + $server + '\' + $database,'/N' + $user,'/P' + $password,'/DisableStartupDialogs','/DumpConfigToFiles',$configOut,'-Format','Hierarchical','/Out',$logFile)
    & $onecBin @mainArgs
    $rc = $LASTEXITCODE
    if ($rc -ne 0) { throw "Ошибка DumpConfigToFiles для $id. Код: $rc. Лог: $logFile" }

    $configItems = @(Get-ChildItem -LiteralPath $configOut -Force)
    if ($configItems.Count -eq 0) { throw "Каталог основной конфигурации пуст: $configOut" }

    $extensions = @($db.extensions)
    if ($extensions.Count -eq 0) { throw "Для $id не задано расширений." }

    foreach ($extValue in $extensions) {
        $ext = [string]$extValue
        $extOut = Join-Path $extensionsOut $ext
        New-Item -ItemType Directory -Force -Path $extOut | Out-Null
        Write-Host "  Расширение: $ext"

        $safeExt = $ext -replace '[^A-Za-z0-9_-]', '_'
        $extLog = Join-Path $logsDir ($id + '_extension_' + $stamp + '_' + $safeExt + '.log')
        $extArgs = @('DESIGNER','/S' + $server + '\' + $database,'/N' + $user,'/P' + $password,'/DisableStartupDialogs','/DumpConfigToFiles',$extOut,'-Format','Hierarchical','-Extension',$ext,'/Out',$extLog)

        & $onecBin @extArgs
        $extRc = $LASTEXITCODE
        if ($extRc -ne 0) { throw "Ошибка выгрузки расширения $ext для $id. Код: $extRc. Лог: $extLog" }

        $extItems = @(Get-ChildItem -LiteralPath $extOut -Force)
        if ($extItems.Count -eq 0) { throw "Каталог расширения пуст: $extOut" }
    }

    if (Test-Path -LiteralPath $finalRoot) { Remove-Item -LiteralPath $finalRoot -Recurse -Force }
    Move-Item -LiteralPath $stagingRoot -Destination $finalRoot
    Write-Host "Готово: $finalRoot"
}

Write-Host ""
Write-Host "DUMP CONFIG завершён."
exit 0

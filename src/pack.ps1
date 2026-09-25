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
Write-Host "MCP - PACK"
Write-Host "------------------------------------------------------------"

$terminalPath = Join-Path (Join-Path $configDir 'terminals') ($computer + '.json')
if (-not (Test-Path -LiteralPath $terminalPath -PathType Leaf)) { throw "Не найден файл терминала: $terminalPath" }

$terminal = Get-Content -Raw -LiteralPath $terminalPath -Encoding UTF8 | ConvertFrom-Json
$mcpWork = [string]$terminal.mcp_work

if ([string]::IsNullOrWhiteSpace($mcpWork)) {
    throw "В конфигурации терминала не указан mcp_work: $terminalPath"
}

# Исходный 7za.exe находится в MCP на RDP-диске.
$sourceSevenZip = Join-Path (Join-Path $root 'tools') '7za.exe'
if (-not (Test-Path -LiteralPath $sourceSevenZip -PathType Leaf)) {
    throw "Не найден исходный 7za.exe: $sourceSevenZip"
}

# Локальный 7za.exe. Он остается после завершения упаковки.
$localToolsDir = Join-Path $mcpWork 'tools'
$localSevenZip = Join-Path $localToolsDir '7za.exe'

New-Item -ItemType Directory -Force -Path $localToolsDir | Out-Null

Write-Host ""
Write-Host "Копирование 7za.exe на локальный диск:"
Write-Host "  FROM: $sourceSevenZip"
Write-Host "  TO:   $localSevenZip"

Copy-Item -LiteralPath $sourceSevenZip -Destination $localSevenZip -Force

if (-not (Test-Path -LiteralPath $localSevenZip -PathType Leaf)) {
    throw "Не удалось скопировать 7za.exe: $localSevenZip"
}

Write-Host "Локальный 7za.exe готов."

$dbDir = Join-Path (Join-Path $configDir 'databases') $computer
$dbFiles = @(Get-ChildItem -LiteralPath $dbDir -Filter '*.json' -File)
if ($dbFiles.Count -eq 0) { throw "В каталоге нет JSON баз: $dbDir" }

$dumpDir = Join-Path $mcpWork 'dump'
$archiveDir = Join-Path $mcpWork 'archive'
New-Item -ItemType Directory -Force -Path $archiveDir | Out-Null

foreach ($dbFile in $dbFiles) {
    $db = Get-Content -Raw -LiteralPath $dbFile.FullName -Encoding UTF8 | ConvertFrom-Json
    $id = [string]$db.db_source_id
    $dumpRoot = Join-Path $dumpDir $id

    if (-not (Test-Path -LiteralPath $dumpRoot -PathType Container)) {
        throw "Не найден dump для ${id}: $dumpRoot"
    }

    $items = @(Get-ChildItem -LiteralPath $dumpRoot -Force)
    if ($items.Count -eq 0) { throw "Dump пуст: $dumpRoot" }

    $stamp = (Get-Date).ToString('yyyyMMdd_HHmmss')
    $archive = Join-Path $archiveDir ($id + '_' + $stamp + '.7z')
    $shaFile = [IO.Path]::ChangeExtension($archive, '.sha256')

    Write-Host ""
    Write-Host "Упаковка: $id"
    Write-Host "Источник: $dumpRoot"
    Write-Host "Архив:    $archive"
    Write-Host "7za:      $localSevenZip"

    # ВАЖНО: 7za и dump находятся на локальном диске терминала.
    & $localSevenZip 'a' '-t7z' '-mx=5' '-mmt=on' $archive ($dumpRoot + '\*')
    $rc = $LASTEXITCODE

    if ($rc -ne 0) { throw "7za завершился с кодом $rc для $id" }
    if (-not (Test-Path -LiteralPath $archive -PathType Leaf)) { throw "Архив не создан: $archive" }

    $hash = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash.ToLowerInvariant()
    ($hash + '  ' + [IO.Path]::GetFileName($archive)) | Set-Content -LiteralPath $shaFile -Encoding ASCII

    Write-Host "Архив: $archive"
    Write-Host "SHA-256: $hash"
}

Write-Host ""
Write-Host "PACK завершён."
Write-Host "Локальный 7za.exe оставлен: $localSevenZip"
exit 0

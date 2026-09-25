#Requires -Version 5.1
# blitcp upload variant.
# blitcp.exe must be available locally on the terminal.

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$configDir = Join-Path $root 'config'
$commonPath = Join-Path $configDir 'common.json'

Write-Host "------------------------------------------------------------"
Write-Host "MCP - UPLOAD (blitcp)"
Write-Host "------------------------------------------------------------"

if (-not (Test-Path -LiteralPath $commonPath -PathType Leaf)) {
    throw "Не найден common.json: $commonPath"
}

$common = Get-Content -Raw -LiteralPath $commonPath -Encoding UTF8 | ConvertFrom-Json
$rdpDrive = [string]$common.rdp_drive
$mcpPath = [string]$common.mcp_path

if (-not (Test-Path -LiteralPath $rdpDrive)) {
    throw "RDP-диск недоступен: $rdpDrive"
}

$rdpMcp = Join-Path $rdpDrive $mcpPath
if (-not (Test-Path -LiteralPath $rdpMcp -PathType Container)) {
    throw "Каталог MCP на RDP-диске не найден: $rdpMcp"
}

$computer = $env:COMPUTERNAME
$terminalPath = Join-Path (Join-Path $configDir 'terminals') ($computer + '.json')
if (-not (Test-Path -LiteralPath $terminalPath -PathType Leaf)) {
    throw "Не найден файл терминала: $terminalPath"
}

$terminal = Get-Content -Raw -LiteralPath $terminalPath -Encoding UTF8 | ConvertFrom-Json
$mcpWork = [string]$terminal.mcp_work
if ([string]::IsNullOrWhiteSpace($mcpWork)) {
    throw "В конфигурации терминала не указан mcp_work: $terminalPath"
}

$dumpDir = Join-Path $mcpWork 'dump'
if (-not (Test-Path -LiteralPath $dumpDir -PathType Container)) {
    throw "Локальный каталог dump не найден: $dumpDir"
}

# blitcp запускаем с локального диска терминала, а не через \\tsclient.
$blitcp = Join-Path (Join-Path $mcpWork 'tools') 'blitcp\blitcp-windows.exe'
if (-not (Test-Path -LiteralPath $blitcp -PathType Leaf)) {
    throw "blitcp-windows.exe не найден: $blitcp"
}

$version = (& $blitcp --version 2>&1 | Select-Object -First 1)
Write-Host "blitcp: $version"

$dbDir = Join-Path (Join-Path $configDir 'databases') $computer
if (-not (Test-Path -LiteralPath $dbDir -PathType Container)) {
    throw "Каталог баз не найден: $dbDir"
}

$dbFiles = @(Get-ChildItem -LiteralPath $dbDir -Filter '*.json' -File)
if ($dbFiles.Count -eq 0) {
    throw "В каталоге нет JSON баз: $dbDir"
}

foreach ($dbFile in $dbFiles) {
    $db = Get-Content -Raw -LiteralPath $dbFile.FullName -Encoding UTF8 | ConvertFrom-Json
    $id = [string]$db.db_source_id
    if ([string]::IsNullOrWhiteSpace($id)) {
        throw "В файле базы не указан db_source_id: $($dbFile.FullName)"
    }

    $dumpRoot = Join-Path $dumpDir $id
    if (-not (Test-Path -LiteralPath $dumpRoot -PathType Container)) {
        throw "Не найден локальный dump для $($id): $dumpRoot"
    }

    $items = @(Get-ChildItem -LiteralPath $dumpRoot -Force)
    if ($items.Count -eq 0) {
        throw "Dump пуст: $dumpRoot"
    }

    $destination = Join-Path (Join-Path $rdpMcp 'dump') $id
    New-Item -ItemType Directory -Force -Path $destination | Out-Null

    Write-Host ""
    Write-Host "Передача dump: $id"
    Write-Host "  blitcp: $blitcp"
    Write-Host "  FROM:   $dumpRoot"
    Write-Host "  TO:     $destination"
    Write-Host "  Режим:  incremental + no-verify + no-cache + small-files parallel"
    Write-Host ""

    & $blitcp -p --no-verify --no-cache --small-files parallel --threads 16 $dumpRoot $destination
    $rc = $LASTEXITCODE

    Write-Host ""
    Write-Host "  blitcp завершён. EXIT CODE: $rc"

    if ($rc -ne 0) {
        throw "blitcp завершился с кодом $rc для $id"
    }

    Write-Host "Передача завершена: $id"
}

Write-Host ""
Write-Host "UPLOAD завершён. Архивирование не выполнялось. Использовался blitcp."
exit 0

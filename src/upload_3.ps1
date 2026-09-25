#Requires -Version 5.1
# FastCopy upload variant.
# Requires FastCopy.exe on the RDP-mounted MCP tools directory.

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$configDir = Join-Path $root 'config'
$commonPath = Join-Path $configDir 'common.json'

Write-Host "------------------------------------------------------------"
Write-Host "MCP - UPLOAD (FastCopy)"
Write-Host "------------------------------------------------------------"

if (-not (Test-Path -LiteralPath $commonPath -PathType Leaf)) { throw "Не найден common.json: $commonPath" }

$common = Get-Content -Raw -LiteralPath $commonPath -Encoding UTF8 | ConvertFrom-Json
$rdpDrive = [string]$common.rdp_drive
$mcpPath = [string]$common.mcp_path
if (-not (Test-Path -LiteralPath $rdpDrive)) { throw "RDP-диск недоступен: $rdpDrive" }

$rdpMcp = Join-Path $rdpDrive $mcpPath
if (-not (Test-Path -LiteralPath $rdpMcp -PathType Container)) { throw "Каталог MCP на RDP-диске не найден: $rdpMcp" }

$computer = $env:COMPUTERNAME
$terminalPath = Join-Path (Join-Path $configDir 'terminals') ($computer + '.json')
if (-not (Test-Path -LiteralPath $terminalPath -PathType Leaf)) { throw "Не найден файл терминала: $terminalPath" }

$terminal = Get-Content -Raw -LiteralPath $terminalPath -Encoding UTF8 | ConvertFrom-Json
$mcpWork = [string]$terminal.mcp_work
if ([string]::IsNullOrWhiteSpace($mcpWork)) { throw "В конфигурации терминала не указан mcp_work: $terminalPath" }

$dumpDir = Join-Path $mcpWork 'dump'
if (-not (Test-Path -LiteralPath $dumpDir -PathType Container)) { throw "Локальный каталог dump не найден: $dumpDir" }

$fastCopy = Join-Path $rdpMcp 'tools\FastCopy\FastCopy.exe'
if (-not (Test-Path -LiteralPath $fastCopy -PathType Leaf)) { throw "FastCopy.exe не найден: $fastCopy" }

function Get-DumpStatistics {
    param([string]$Path)
    $files = @(Get-ChildItem -LiteralPath $Path -Recurse -File -ErrorAction SilentlyContinue)
    $sum = ($files | Measure-Object Length -Sum).Sum
    if ($null -eq $sum) { $sum = 0 }
    $last = $files | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    [PSCustomObject]@{ Count=$files.Count; TotalBytes=[int64]$sum; LastWrite=$last.LastWriteTime }
}

function Format-Bytes {
    param([int64]$Bytes)
    if ($Bytes -ge 1TB) { return ("{0:N2} TB" -f ($Bytes / 1TB)) }
    if ($Bytes -ge 1GB) { return ("{0:N2} GB" -f ($Bytes / 1GB)) }
    if ($Bytes -ge 1MB) { return ("{0:N2} MB" -f ($Bytes / 1MB)) }
    if ($Bytes -ge 1KB) { return ("{0:N2} KB" -f ($Bytes / 1KB)) }
    "{0} B" -f $Bytes
}

function Start-FastCopy {
    param([string]$Source,[string]$Destination)

    Write-Host "  Запуск FastCopy..."
    Write-Host "  FROM: $Source"
    Write-Host "  TO:   $Destination"
    Write-Host "  Режим: /cmd=update"
    Write-Host ""

    New-Item -ItemType Directory -Force -Path $Destination | Out-Null
    & $fastCopy /cmd=update "$Source" "to=$Destination"
    $rc = $LASTEXITCODE

    Write-Host ""
    Write-Host "  FastCopy завершён. EXIT CODE: $rc"
    if ($rc -ne 0) { return $rc }
    return 0
}

$dbDir = Join-Path (Join-Path $configDir 'databases') $computer
$dbFiles = @(Get-ChildItem -LiteralPath $dbDir -Filter '*.json' -File)
if ($dbFiles.Count -eq 0) { throw "В каталоге нет JSON баз: $dbDir" }

foreach ($dbFile in $dbFiles) {
    $db = Get-Content -Raw -LiteralPath $dbFile.FullName -Encoding UTF8 | ConvertFrom-Json
    $id = [string]$db.db_source_id
    $dumpRoot = Join-Path $dumpDir $id

    if (-not (Test-Path -LiteralPath $dumpRoot -PathType Container)) { throw "Не найден локальный dump для $($id): $dumpRoot" }
    if (@(Get-ChildItem -LiteralPath $dumpRoot -Force).Count -eq 0) { throw "Dump пуст: $dumpRoot" }

    $destination = Join-Path (Join-Path $rdpMcp 'dump') $id
    New-Item -ItemType Directory -Force -Path $destination | Out-Null
    $stats = Get-DumpStatistics -Path $dumpRoot

    Write-Host ""
    Write-Host "Передача dump: $id"
    Write-Host "  FROM: $dumpRoot"
    Write-Host "  TO:   $destination"
    Write-Host "  Файлов: $($stats.Count)"
    Write-Host "  Размер: $(Format-Bytes $stats.TotalBytes)"

    $rc = Start-FastCopy -Source $dumpRoot -Destination $destination
    if ($rc -ne 0) { throw "FastCopy завершился с кодом $rc для $id" }
    Write-Host "Передача завершена: $id"
}

Write-Host ""
Write-Host "UPLOAD завершён. Архивирование не выполнялось. Использовался FastCopy."
exit 0

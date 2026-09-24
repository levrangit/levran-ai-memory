#Requires -Version 5.1
# Если PowerShell запрещает запуск скрипта, выполните:
# Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
# Проверить текущую политику:
# Get-ExecutionPolicy -List

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$configDir = Join-Path $root 'config'
$commonPath = Join-Path $configDir 'common.json'

Write-Host "------------------------------------------------------------"
Write-Host "MCP - UPLOAD"
Write-Host "------------------------------------------------------------"

if (-not (Test-Path -LiteralPath $commonPath -PathType Leaf)) { throw "Не найден common.json: $commonPath" }

$common = Get-Content -Raw -LiteralPath $commonPath -Encoding UTF8 | ConvertFrom-Json
$rdpDrive = [string]$common.rdp_drive
$mcpPath = [string]$common.mcp_path
if (-not (Test-Path -LiteralPath $rdpDrive)) { throw "RDP-диск недоступен: $rdpDrive" }

$rdpMcp = Join-Path $rdpDrive $mcpPath
if (-not (Test-Path -LiteralPath $rdpMcp -PathType Container)) { throw "Каталог MCP на RDP-диске не найден: $rdpMcp" }

$rclone = Join-Path (Join-Path $root 'tools') 'rclone.exe'
if (-not (Test-Path -LiteralPath $rclone -PathType Leaf)) { throw "Не найден rclone.exe: $rclone" }

$computer = $env:COMPUTERNAME
$terminalPath = Join-Path (Join-Path $configDir 'terminals') ($computer + '.json')
if (-not (Test-Path -LiteralPath $terminalPath -PathType Leaf)) { throw "Не найден файл терминала: $terminalPath" }

$terminal = Get-Content -Raw -LiteralPath $terminalPath -Encoding UTF8 | ConvertFrom-Json
$mcpWork = [string]$terminal.mcp_work
$archiveDir = Join-Path $mcpWork 'archive'

$dbDir = Join-Path (Join-Path $configDir 'databases') $computer
$dbFiles = @(Get-ChildItem -LiteralPath $dbDir -Filter '*.json' -File)
if ($dbFiles.Count -eq 0) { throw "В каталоге нет JSON баз: $dbDir" }

foreach ($dbFile in $dbFiles) {
    $db = Get-Content -Raw -LiteralPath $dbFile.FullName -Encoding UTF8 | ConvertFrom-Json
    $id = [string]$db.db_source_id
    $archives = @(Get-ChildItem -LiteralPath $archiveDir -Filter ($id + '_*.7z') -File | Sort-Object LastWriteTime -Descending)
    if ($archives.Count -eq 0) { throw "Не найден архив для $id" }

    $archive = $archives[0]
    $shaFile = [IO.Path]::ChangeExtension($archive.FullName, '.sha256')
    if (-not (Test-Path -LiteralPath $shaFile -PathType Leaf)) { throw "Не найден SHA-256 файл: $shaFile" }

    Write-Host ""
    Write-Host "Передача: $($archive.Name)"

    & $rclone 'copy' $archive.FullName $rdpMcp
    $rc = $LASTEXITCODE
    if ($rc -ne 0) { throw "rclone завершился с кодом $rc для $($archive.Name)" }

    & $rclone 'copy' $shaFile $rdpMcp
    $rc = $LASTEXITCODE
    if ($rc -ne 0) { throw "rclone завершился с кодом $rc для $([IO.Path]::GetFileName($shaFile))" }

    Write-Host "Передано: $rdpMcp"
}

Write-Host ""
Write-Host "UPLOAD завершён."
exit 0

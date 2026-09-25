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

$rclone = Join-Path (Join-Path $root 'tools') 'rclone.exe'
if (-not (Test-Path -LiteralPath $rclone -PathType Leaf)) {
    throw "Не найден rclone.exe: $rclone"
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


function Get-DumpStatistics {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
        return [PSCustomObject]@{ Count = 0; TotalBytes = [int64]0; LastWrite = $null }
    }
    $files = @(Get-ChildItem -LiteralPath $Path -Recurse -File -ErrorAction SilentlyContinue)
    $sum = ($files | Measure-Object Length -Sum).Sum
    if ($null -eq $sum) { $sum = 0 }
    $last = $files | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    return [PSCustomObject]@{ Count = $files.Count; TotalBytes = [int64]$sum; LastWrite = if ($null -ne $last) { $last.LastWriteTime } else { $null } }
}

function Format-Bytes {
    param([int64]$Bytes)
    if ($Bytes -ge 1TB) { return ("{0:N2} TB" -f ($Bytes / 1TB)) }
    if ($Bytes -ge 1GB) { return ("{0:N2} GB" -f ($Bytes / 1GB)) }
    if ($Bytes -ge 1MB) { return ("{0:N2} MB" -f ($Bytes / 1MB)) }
    if ($Bytes -ge 1KB) { return ("{0:N2} KB" -f ($Bytes / 1KB)) }
    return ("{0} B" -f $Bytes)
}

function Start-RcloneCopyWithProgress {
    param([string]$Rclone,[string]$Source,[string]$Destination)
    $started = Get-Date
    $sourceStats = Get-DumpStatistics $Source
    $totalBytes = $sourceStats.TotalBytes
    $totalFiles = $sourceStats.Count
    $barWidth = 40
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $Rclone
    $psi.Arguments = 'copy "' + $Source + '" "' + $Destination + '" --verbose'
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $psi
    Write-Host "  Запуск rclone..."
    Write-Host "  Контроль назначения: $Destination"
    Write-Host ("  Всего: {0:N0} файлов, {1}" -f $totalFiles,(Format-Bytes $totalBytes))
    Write-Host ""
    if (-not $process.Start()) { throw "Не удалось запустить rclone." }
    $previousBytes = 0
    $lastLineLength = 0
    while (-not $process.HasExited) {
        Start-Sleep -Seconds 5
        $current = Get-DumpStatistics $Destination
        $elapsed = (Get-Date) - $started
        if ($totalBytes -gt 0) { $percent = [math]::Min(100,[math]::Max(0,($current.TotalBytes * 100.0 / $totalBytes))) }
        elseif ($totalFiles -gt 0) { $percent = [math]::Min(100,($current.Count * 100.0 / $totalFiles)) }
        else { $percent = 100 }
        $filled = [int][math]::Floor($barWidth * $percent / 100)
        $bar = ('|' * $filled) + ('.' * ($barWidth - $filled))
        $deltaBytes = $current.TotalBytes - $previousBytes
        $speed = 0
        if ($deltaBytes -gt 0) { $speed = [int64]($deltaBytes / 5) }
        $line = "  [$bar] {0,6:N2}%  {1} / {2}  {3}/с  {4}" -f $percent,(Format-Bytes $current.TotalBytes),(Format-Bytes $totalBytes),(Format-Bytes $speed),$elapsed.ToString('hh\:mm\:ss')
        if ($line.Length -lt $lastLineLength) { $line += (' ' * ($lastLineLength - $line.Length)) }
        Write-Host (([char]13).ToString() + $line) -NoNewline
        $lastLineLength = $line.Length
        $previousBytes = $current.TotalBytes
    }
    $process.WaitForExit()
    $final = Get-DumpStatistics $Destination
    $elapsed = (Get-Date) - $started
    if ($totalBytes -gt 0) { $finalPercent = [math]::Min(100,($final.TotalBytes * 100.0 / $totalBytes)) } else { $finalPercent = 100 }
    $filled = [int][math]::Floor($barWidth * $finalPercent / 100)
    $bar = ('|' * $filled) + ('.' * ($barWidth - $filled))
    $finalLine = "  [$bar] {0,6:N2}%  {1} / {2}  завершено за {3}" -f $finalPercent,(Format-Bytes $final.TotalBytes),(Format-Bytes $totalBytes),$elapsed.ToString('hh\:mm\:ss')
    if ($finalLine.Length -lt $lastLineLength) { $finalLine += (' ' * ($lastLineLength - $finalLine.Length)) }
    Write-Host (([char]13).ToString() + $finalLine)
    Write-Host ("  Файлов: {0:N0} / {1:N0}" -f $final.Count,$totalFiles)
    Write-Host ("  rclone завершён. EXIT CODE: {0}" -f $process.ExitCode)
    return $process.ExitCode
}
$dbDir = Join-Path (Join-Path $configDir 'databases') $computer
$dbFiles = @(Get-ChildItem -LiteralPath $dbDir -Filter '*.json' -File)
if ($dbFiles.Count -eq 0) {
    throw "В каталоге нет JSON баз: $dbDir"
}

foreach ($dbFile in $dbFiles) {
    $db = Get-Content -Raw -LiteralPath $dbFile.FullName -Encoding UTF8 | ConvertFrom-Json
    $id = [string]$db.db_source_id
    $dumpRoot = Join-Path $dumpDir $id

    if (-not (Test-Path -LiteralPath $dumpRoot -PathType Container)) {
        throw "Не найден локальный dump для ${id}: $dumpRoot"
    }

    $items = @(Get-ChildItem -LiteralPath $dumpRoot -Force)
    if ($items.Count -eq 0) {
        throw "Dump пуст: $dumpRoot"
    }

    $destination = Join-Path (Join-Path $rdpMcp 'dump') $id
    New-Item -ItemType Directory -Force -Path $destination | Out-Null

    Write-Host ""
    Write-Host "Передача dump: $id"
    Write-Host "  FROM: $dumpRoot"
    Write-Host "  TO:   $destination"

    # rclone работает отдельным процессом, а PowerShell контролирует destination.
    $rc = Start-RcloneCopyWithProgress -Rclone $rclone -Source $dumpRoot -Destination $destination

    if ($rc -ne 0) {
        throw "rclone завершился с кодом $rc для $id"
    }

    Write-Host "Передача завершена: $id"
}

Write-Host ""
Write-Host "UPLOAD завершён. Архивирование не выполнялось."
exit 0

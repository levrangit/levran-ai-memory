#Requires -Version 5.1

$ErrorActionPreference = 'Stop'

$path = 'L:\!work\RAU_IT\MCP'
$controlPath = Join-Path $path 'control\control.json'

if (-not (Test-Path -LiteralPath $path -PathType Container)) { throw "Папка назначения не найдена: $path" }
if (-not (Test-Path -LiteralPath $controlPath -PathType Leaf)) { throw "Не найден контрольный файл: $controlPath" }

$control = Get-Content -Raw -LiteralPath $controlPath -Encoding UTF8 | ConvertFrom-Json
$targetArchives = [int]$control.ArchiveCount
$targetSha256 = [int]$control.Sha256Count
$targetBytes = [int64]$control.TotalArchiveBytes
if ($targetArchives -le 0) { throw "В control.json ArchiveCount должен быть больше 0." }
if ($targetBytes -le 0) { throw "В control.json TotalArchiveBytes должен быть больше 0." }

$expected = @($control.Archives)
if ($expected.Count -ne $targetArchives) { throw "Количество Archives в control.json не совпадает с ArchiveCount." }

$archiveDir = Join-Path $path 'archive'
if (-not (Test-Path -LiteralPath $archiveDir -PathType Container)) {
    New-Item -ItemType Directory -Force -Path $archiveDir | Out-Null
}

function Format-Bytes {
    param([int64]$Bytes)
    if ($Bytes -ge 1TB) { return ("{0:N2} TB" -f ($Bytes / 1TB)) }
    if ($Bytes -ge 1GB) { return ("{0:N2} GB" -f ($Bytes / 1GB)) }
    if ($Bytes -ge 1MB) { return ("{0:N2} MB" -f ($Bytes / 1MB)) }
    if ($Bytes -ge 1KB) { return ("{0:N2} KB" -f ($Bytes / 1KB)) }
    return ("{0} B" -f $Bytes)
}

Write-Host "------------------------------------------------------------"
Write-Host "MCP - CONTROL"
Write-Host "------------------------------------------------------------"
Write-Host "Каталог: $path"
Write-Host "Контрольный файл: $controlPath"
Write-Host ("Ожидается архивов: {0:N0}" -f $targetArchives)
Write-Host ("Ожидается SHA256: {0:N0}" -f $targetSha256)
Write-Host ("Ожидаемый размер: {0}" -f (Format-Bytes $targetBytes))
Write-Host ""

$startTime = Get-Date
$previousBytes = [int64]0
$previousTime = $startTime
$averageBytesPerSec = 0

while ($true) {
    $receivedBytes = [int64]0
    $receivedArchives = 0
    $completeArchives = 0

    foreach ($item in $expected) {
        $filePath = Join-Path $archiveDir ([string]$item.Name)
        if (Test-Path -LiteralPath $filePath -PathType Leaf) {
            $file = Get-Item -LiteralPath $filePath
            $receivedArchives++
            $receivedBytes += [int64]$file.Length
            if ([int64]$file.Length -eq [int64]$item.SizeBytes) { $completeArchives++ }
        }
    }

    $shaCount = @(Get-ChildItem -LiteralPath $archiveDir -Filter '*.sha256' -File -ErrorAction SilentlyContinue).Count
    $now = Get-Date
    $deltaSeconds = ($now - $previousTime).TotalSeconds

    if ($deltaSeconds -gt 0) {
        $deltaBytes = $receivedBytes - $previousBytes
        $currentBytesPerSec = $deltaBytes / $deltaSeconds
        if ($currentBytesPerSec -gt 0) {
            if ($averageBytesPerSec -eq 0) {
                $averageBytesPerSec = $currentBytesPerSec
            }
            else {
                $averageBytesPerSec = ($averageBytesPerSec * 0.8) + ($currentBytesPerSec * 0.2)
            }
        }
    }

    $previousBytes = $receivedBytes
    $previousTime = $now

    $percent = ($receivedBytes / $targetBytes) * 100
    if ($percent -gt 100) { $percent = 100 }

    $barLength = 40
    $filled = [int][Math]::Floor(($percent / 100) * $barLength)
    if ($filled -gt $barLength) { $filled = $barLength }
    if ($filled -lt 0) { $filled = 0 }
    $progressBar = ('█' * $filled) + ('░' * ($barLength - $filled))

    $elapsedSeconds = ($now - $startTime).TotalSeconds
    if ($elapsedSeconds -gt 0) {
        $mbPerMin = ($receivedBytes / 1MB) / $elapsedSeconds * 60
    }
    else {
        $mbPerMin = 0
    }

    $remainingBytes = $targetBytes - $receivedBytes
    if ($remainingBytes -lt 0) { $remainingBytes = 0 }

    if ($averageBytesPerSec -gt 0 -and $remainingBytes -gt 0) {
        $remainingSeconds = $remainingBytes / $averageBytesPerSec
        $remainingTime = [TimeSpan]::FromSeconds($remainingSeconds)
        $remainingText = "{0} ч {1} мин" -f [int]$remainingTime.TotalHours, $remainingTime.Minutes
        $finishText = $now.AddSeconds($remainingSeconds).ToString("HH:mm:ss")
    }
    elseif ($receivedBytes -ge $targetBytes -and $completeArchives -eq $targetArchives -and $shaCount -ge $targetSha256) {
        $remainingText = 'ЗАВЕРШЕНО'
        $finishText = $now.ToString("HH:mm:ss")
    }
    elseif ($receivedBytes -ge $targetBytes) {
        $remainingText = 'проверка файлов'
        $finishText = '--:--:--'
    }
    else {
        $remainingText = 'расчёт...'
        $finishText = '--:--:--'
    }

    $line = "[{0}] [{1}] {2,6:N2}% | Файлов: {3:N0}/{4:N0} | Полных: {5:N0}/{4:N0} | Размер: {6} / {7} | {8:N1} MB/мин | SHA256: {9:N0}/{10:N0} | Осталось: {11} | Конец: {12}" -f $now.ToString("HH:mm:ss"), $progressBar, $percent, $receivedArchives, $targetArchives, $completeArchives, (Format-Bytes $receivedBytes), (Format-Bytes $targetBytes), $mbPerMin, $shaCount, $targetSha256, $remainingText, $finishText
    Write-Host $line

    if ($receivedBytes -ge $targetBytes -and $completeArchives -eq $targetArchives -and $shaCount -ge $targetSha256) {
        Write-Host ""
        Write-Host "Получение архивов завершено."
        Write-Host ("Архивов: {0:N0}/{1:N0}" -f $completeArchives, $targetArchives)
        Write-Host ("SHA256: {0:N0}/{1:N0}" -f $shaCount, $targetSha256)
        Write-Host ("Размер: {0}" -f (Format-Bytes $receivedBytes))
        Write-Host ("Время завершения: {0}" -f $now.ToString("HH:mm:ss"))
        break
    }

    Start-Sleep -Seconds 1
}
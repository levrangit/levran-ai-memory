#Requires -Version 5.1

$path = Read-Host "Введите путь к папке назначения"

$targetFiles = [int](Read-Host "Введите общее количество файлов в источнике")

if ($targetFiles -le 0) {
    Write-Host "Количество файлов должно быть больше 0."
    .
}

Write-Host ""
Write-Host "Начинаю мониторинг..."
Write-Host "Для остановки нажмите Ctrl+C."
Write-Host ""

$startTime = Get-Date
$previousCount = 0
$previousBytes = 0
$previousTime = $startTime

$averageFilesPerSec = 0
$averageBytesPerSec = 0

while ($true) {
    $files = @(Get-ChildItem -LiteralPath $path -Recurse -File -ErrorAction SilentlyContinue)
    $count = $files.Count
    $bytes = ($files | Measure-Object Length -Sum).Sum

    if ($null -eq $bytes) {
        $bytes = 0
    }

    $now = Get-Date
    $deltaSeconds = ($now - $previousTime).TotalSeconds

    if ($deltaSeconds -gt 0) {
        $deltaFiles = $count - $previousCount
        $deltaBytes = $bytes - $previousBytes
        $currentFilesPerSec = $deltaFiles / $deltaSeconds
        $currentBytesPerSec = $deltaBytes / $deltaSeconds

        if ($averageFilesPerSec -eq 0) {
            $averageFilesPerSec = $currentFilesPerSec
        }
        else {
            $averageFilesPerSec = ($averageFilesPerSec * 0.8) + ($currentFilesPerSec * 0.2)
        }

        if ($averageBytesPerSec -eq 0) {
            $averageBytesPerSec = $currentBytesPerSec
        }
        else {
            $averageBytesPerSec = ($averageBytesPerSec * 0.8) + ($currentBytesPerSec * 0.2)
        }
    }

    $previousCount = $count
    $previousBytes = $bytes
    $previousTime = $now

    $percent = ($count / $targetFiles) * 100

    if ($percent -gt 100) {
        $percent = 100
    }

    $barLength = 40
    $filled = [int][Math]::Floor(($percent / 100) * $barLength)

    if ($filled -gt $barLength) {
        $filled = $barLength
    }

    if ($filled -lt 0) {
        $filled = 0
    }

    $empty = $barLength - $filled
    $progressBar = ("█" * $filled) + ("░" * $empty)

    $elapsedSeconds = ($now - $startTime).TotalSeconds

    if ($elapsedSeconds -gt 0) {
        $filesPerMin = $count / $elapsedSeconds * 60
        $mbPerMin = ($bytes / 1MB) / $elapsedSeconds * 60
    }
    else {
        $filesPerMin = 0
        $mbPerMin = 0
    }

    $remainingFiles = $targetFiles - $count

    if ($remainingFiles -lt 0) {
        $remainingFiles = 0
    }

    if ($averageFilesPerSec -gt 0 -and $remainingFiles -gt 0) {
        $remainingSeconds = $remainingFiles / $averageFilesPerSec
        $remainingTime = [TimeSpan]::FromSeconds($remainingSeconds)
        $finishTime = $now.AddSeconds($remainingSeconds)

        $remainingText = "{0} ч {1} мин" -f [int]$remainingTime.TotalHours, $remainingTime.Minutes
        $finishText = $finishTime.ToString("HH:mm:ss")
    }
    elseif ($count -ge $targetFiles) {
        $remainingText = "ЗАВЕРШЕНО"
        $finishText = $now.ToString("HH:mm:ss")
    }
    else {
        $remainingText = "расчёт..."
        $finishText = "--:--:--"
    }

    $line = "[{0}] [{1}] {2,6:N2}% | Файлов: {3:N0}/{4:N0} | Размер: {5:N2} MB | {6:N1} файлов/мин | {7:N1} MB/мин | Осталось: {8} | Конец: {9}" -f `
        $now.ToString("HH:mm:ss"), `
        $progressBar, `
        $percent, `
        $count, `
        $targetFiles, `
        ($bytes / 1MB), `
        $filesPerMin, `
        $mbPerMin, `
        $remainingText, `
        $finishText

    Write-Host "`r$line" -NoNewline

    if ($count -ge $targetFiles) {
        Write-Host ""
        Write-Host ""
        Write-Host "Копирование завершено."
        Write-Host ("Файлов: {0:N0}" -f $count)
        Write-Host ("Размер: {0:N2} MB" -f ($bytes / 1MB))
        Write-Host ("Время завершения: {0}" -f $now.ToString("HH:mm:ss"))
        break
    }

    Start-Sleep -Seconds 1
}
.

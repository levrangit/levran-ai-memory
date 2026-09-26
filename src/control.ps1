#Requires -Version 5.1

$path = Read-Host "Введите путь к папке назначения"

$targetArchives = [int](Read-Host "Введите общее количество архивов (.7z) в источнике")

if ($targetArchives -le 0) {
    Write-Host "Количество архивов должно быть больше 0."
    exit 1
}

if (-not (Test-Path -LiteralPath $path -PathType Container)) {
    Write-Host "Папка назначения не найдена: $path"
    exit 1
}

Write-Host ""
Write-Host "Контроль получения архивов..."
Write-Host "Учитываются только файлы *.7z."
Write-Host "Файлы *.sha256 контролируются отдельно."
Write-Host "Для остановки нажмите Ctrl+C."
Write-Host ""

$startTime = Get-Date
$previousCount = 0
$previousBytes = 0
$previousTime = $startTime

$averageArchivesPerSec = 0
$averageBytesPerSec = 0

while ($true) {
    $archives = @(Get-ChildItem -LiteralPath $path -Filter "*.7z" -File -ErrorAction SilentlyContinue)

    $count = $archives.Count
    $bytes = ($archives | Measure-Object Length -Sum).Sum

    if ($null -eq $bytes) {
        $bytes = 0
    }

    $shaFiles = @(Get-ChildItem -LiteralPath $path -Filter "*.sha256" -File -ErrorAction SilentlyContinue)
    $shaCount = $shaFiles.Count

    $now = Get-Date
    $deltaSeconds = ($now - $previousTime).TotalSeconds

    if ($deltaSeconds -gt 0) {
        $deltaArchives = $count - $previousCount
        $deltaBytes = $bytes - $previousBytes

        $currentArchivesPerSec = $deltaArchives / $deltaSeconds
        $currentBytesPerSec = $deltaBytes / $deltaSeconds

        if ($averageArchivesPerSec -eq 0) {
            $averageArchivesPerSec = $currentArchivesPerSec
        }
        else {
            $averageArchivesPerSec = ($averageArchivesPerSec * 0.8) + ($currentArchivesPerSec * 0.2)
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

    $percent = ($count / $targetArchives) * 100

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
        $archivesPerMin = $count / $elapsedSeconds * 60
        $mbPerMin = ($bytes / 1MB) / $elapsedSeconds * 60
    }
    else {
        $archivesPerMin = 0
        $mbPerMin = 0
    }

    $remainingArchives = $targetArchives - $count

    if ($remainingArchives -lt 0) {
        $remainingArchives = 0
    }

    if ($averageArchivesPerSec -gt 0 -and $remainingArchives -gt 0) {
        $remainingSeconds = $remainingArchives / $averageArchivesPerSec
        $remainingTime = [TimeSpan]::FromSeconds($remainingSeconds)
        $finishTime = $now.AddSeconds($remainingSeconds)

        $remainingText = "{0} ч {1} мин" -f [int]$remainingTime.TotalHours, $remainingTime.Minutes
        $finishText = $finishTime.ToString("HH:mm:ss")
    }
    elseif ($count -ge $targetArchives) {
        $remainingText = "ЗАВЕРШЕНО"
        $finishText = $now.ToString("HH:mm:ss")
    }
    else {
        $remainingText = "расчёт..."
        $finishText = "--:--:--"
    }

    $line = "[{0}] [{1}] {2,6:N2}% | Архивов: {3:N0}/{4:N0} | Размер: {5:N2} MB | {6:N1} архивов/мин | {7:N1} MB/мин | SHA256: {8:N0} | Осталось: {9} | Конец: {10}" -f `
        $now.ToString("HH:mm:ss"), `
        $progressBar, `
        $percent, `
        $count, `
        $targetArchives, `
        ($bytes / 1MB), `
        $archivesPerMin, `
        $mbPerMin, `
        $shaCount, `
        $remainingText, `
        $finishText

    Write-Host "`r$line" -NoNewline

    if ($count -ge $targetArchives) {
        Write-Host ""
        Write-Host ""
        Write-Host "Получение архивов завершено."
        Write-Host ("Архивов .7z: {0:N0}" -f $count)
        Write-Host ("Файлов .sha256: {0:N0}" -f $shaCount)
        Write-Host ("Размер архивов: {0:N2} MB" -f ($bytes / 1MB))
        Write-Host ("Время завершения: {0}" -f $now.ToString("HH:mm:ss"))
        break
    }

    Start-Sleep -Seconds 1
}

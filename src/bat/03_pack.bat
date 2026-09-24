@echo off
setlocal EnableExtensions DisableDelayedExpansion

pushd "%~dp0"
if errorlevel 1 (
    echo ERROR: cannot enter BAT directory.
    exit /b 1
)
set "MCP_ROOT=%CD%\.."

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; $root=[IO.Path]::GetFullPath($env:MCP_ROOT); $configDir=Join-Path $root 'config'; $computer=$env:COMPUTERNAME; Write-Host '------------------------------------------------------------'; Write-Host 'MCP 03 - PACK'; Write-Host '------------------------------------------------------------'; $terminalPath=Join-Path (Join-Path $configDir 'terminals') ($computer+'.json'); if(-not(Test-Path -LiteralPath $terminalPath -PathType Leaf)){throw ('Не найден файл терминала: '+$terminalPath)}; $terminal=Get-Content -Raw -LiteralPath $terminalPath -Encoding UTF8 | ConvertFrom-Json; $mcpWork=[string]$terminal.mcp_work; $sevenZip=Join-Path (Join-Path $root 'tools') '7za.exe'; if(-not(Test-Path -LiteralPath $sevenZip -PathType Leaf)){throw ('Не найден 7za.exe: '+$sevenZip)}; $dbDir=Join-Path (Join-Path $configDir 'databases') $computer; $dbFiles=@(Get-ChildItem -LiteralPath $dbDir -Filter '*.json' -File); if($dbFiles.Count -eq 0){throw ('В каталоге нет JSON баз: '+$dbDir)}; $dumpDir=Join-Path $mcpWork 'dump'; $archiveDir=Join-Path $mcpWork 'archive'; New-Item -ItemType Directory -Force -Path $archiveDir | Out-Null; foreach($dbFile in $dbFiles){ $db=Get-Content -Raw -LiteralPath $dbFile.FullName -Encoding UTF8 | ConvertFrom-Json; $id=[string]$db.db_source_id; $dumpRoot=Join-Path $dumpDir $id; if(-not(Test-Path -LiteralPath $dumpRoot -PathType Container)){throw ('Не найден dump для '+$id+': '+$dumpRoot)}; $items=@(Get-ChildItem -LiteralPath $dumpRoot -Force); if($items.Count -eq 0){throw ('Dump пуст: '+$dumpRoot)}; $stamp=(Get-Date).ToString('yyyyMMdd_HHmmss'); $archive=Join-Path $archiveDir ($id+'_'+$stamp+'.7z'); $shaFile=[IO.Path]::ChangeExtension($archive,'.sha256'); Write-Host ''; Write-Host ('Упаковка: '+$id); & $sevenZip 'a' '-t7z' '-mx=5' '-mmt=on' $archive ($dumpRoot+'\*'); $rc=$LASTEXITCODE; if($rc -ne 0){throw ('7za завершился с кодом '+$rc+' для '+$id)}; if(-not(Test-Path -LiteralPath $archive -PathType Leaf)){throw ('Архив не создан: '+$archive)}; $hash=(Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash.ToLowerInvariant(); ($hash+'  '+[IO.Path]::GetFileName($archive)) | Set-Content -LiteralPath $shaFile -Encoding ASCII; Write-Host ('Архив: '+$archive); Write-Host ('SHA-256: '+$hash) }; Write-Host ''; Write-Host '03_pack завершён.'"
set "RC=%errorlevel%"
popd
if not "%RC%"=="0" (
    echo.
    echo ERROR: 03_pack failed. Code: %RC%
    exit /b %RC%
)
exit /b 0

# MCP-дамп 1С — актуальная архитектура

Дата фиксации: 2026-09-25

## Назначение

Система должна позволять на удалённом Windows RDP-терминале одной командой:

`update.bat`

определить терминал, найти все настроенные базы, выгрузить конфигурацию 1С и расширения, собрать архив 7z, посчитать SHA-256 и перенести архив через RDP-диск на локальный компьютер клиента. С локального компьютера архив отправляется по SSH на leoVM, где проверяется и безопасно обновляет `MCP_clean`.

## Главное архитектурное правило

**JSON — единственный источник конфигурации. BAT-файлы выполняют действия и не содержат настроек окружения.**

Не хардкодить в BAT:

- путь MCP;
- имя терминала;
- `mcp_work`;
- путь к `1cv8.exe`;
- сервер 1С;
- имя базы;
- пользователя и пароль;
- имена расширений.

## Текущая структура

```
MCP\
├── setup.ps1
├── update.bat
├── bat\
│   ├── 01_prepare.bat
│   ├── 02_dump_config.bat
│   ├── 03_pack.bat
│   └── 04_upload.bat
├── config\
│   ├── common.json
│   ├── terminals\
│   │   └── DEV-RDS-01.json
│   └── databases\
│       └── DEV-RDS-01\
│           ├── DO_AKK.json
│           └── ERP_AKK.json
├── tools\
│   ├── rclone.exe
│   └── 7za.exe
└── terminals\
    └── DEV-RDS-01__r.latypov\
        ├── archive\
        └── logs\
```

## Общая конфигурация

`config/common.json`:

```json
{
    "rdp_drive": "\\\\tsclient\\L",
    "mcp_path": "!work\\RAU_IT\\MCP"
}
```

В результате MCP на RDP-диске:

```
\\tsclient\L\!work\RAU_IT\MCP
```

BAT не должен заменять этот источник жёстким `L:\\!work\\RAU_IT\\MCP`.

`%~dp0` допустимо использовать для определения расположения самого BAT; это не заменяет `common.json` как источник конфигурации.

## Текущий терминал

`config/terminals/DEV-RDS-01.json`:

```json
{
    "computer_name": "DEV-RDS-01",
    "username": "r.latypov",
    "mcp_work": "F:\\Users\\LatypovRR\\MCP",
    "onec_bin": "C:\\Program Files\\1cv8\\8.3.27.2214\\bin\\1cv8.exe"
}
```

Терминал определяется автоматически через `%COMPUTERNAME%`.

## Текущие базы

### DO_AKK

`config/databases/DEV-RDS-01/DO_AKK.json`:

```json
{
  "db_source_id": "DO_AKK",
  "db_server": "dev-1c-01",
  "db_database": "akkuyu_zni12_do1",
  "db_user": "Rauit",
  "db_password": "***",
  "extensions": [
    "РАУ"
  ]
}
```

### ERP_AKK

`config/databases/DEV-RDS-01/ERP_AKK.json`:

```json
{
  "db_source_id": "ERP_AKK",
  "db_server": "dev-1c-01",
  "db_database": "akkuyu_zni12_cpm1",
  "db_user": "Rauit",
  "db_password": "***",
  "extensions": [
    "РАУ"
  ]
}
```

На текущем этапе пароль хранится непосредственно в JSON. Credential Manager, DPAPI и шифрование пока не вводятся.

## DB_SOURCE_ID

`DB_SOURCE_ID` глобально уникален среди всех источников.

Текущие:

- `DO_AKK`
- `ERP_AKK`

Он используется как имя JSON, каталог dump, идентификатор архива и каталог в `MCP_clean`.

Количество баз не хранится отдельной настройкой: `update.bat` перебирает:

```
config\\databases\\%COMPUTERNAME%\\*.json
```

Никакого конфигурационного `DB_COUNT` нет.

## Расширения

Расширения задаются JSON-массивом:

```json
"extensions": [
  "РАУ"
]
```

Никакого `DB_EXTENSION_COUNT` и набора `DB_EXTENSION_1...` нет.

В мастере настройки после ввода расширения используется:

```
Продолжить? (N — ввести имя следующего расширения, Enter — закончить):
```

`N` продолжает ввод, Enter завершает.

## Рабочий каталог терминала

Для текущего терминала:

```
F:\Users\LatypovRR\MCP
```

Временные данные формируются локально на удалённом терминале:

```
F:\Users\LatypovRR\MCP\
├── dump\
├── archive\
└── logs\
```

Для базы:

```
dump\DO_AKK\
├── config\
└── extensions\
    └── РАУ\
```

и аналогично для `ERP_AKK`.

## Инструменты

```
tools\rclone.exe
tools\7za.exe
```

Текущий rclone: `v1.75.1`.

Оба инструмента portable, установка 7-Zip в Windows не требуется.

## Этапы BAT

### 01_prepare.bat

Только:

- определить MCP;
- прочитать `common.json`;
- определить `COMPUTERNAME`;
- загрузить terminal JSON;
- проверить `mcp_work`;
- проверить `onec_bin`;
- проверить `rclone.exe` и `7za.exe`;
- найти JSON баз;
- подготовить каталоги.

Не выполняет выгрузку 1С, архивирование или upload.

### 02_dump_config.bat

Для конкретной базы:

- читает database JSON;
- подключается к базе 1С;
- выполняет DumpConfigToFiles;
- выгружает указанные расширения;
- проверяет результат.

Перед окончательной реализацией нужно отдельно подтвердить фактический CLI-синтаксис `1cv8.exe DESIGNER /DumpConfigToFiles` и механизм выгрузки расширений на текущей версии 1С 8.3.27.2214.

### 03_pack.bat

```
dump
  ↓
7za
  ↓
archive/<DB_SOURCE_ID>_<YYYYMMDD>_<HHMMSS>.7z
  ↓
SHA-256
```

Рядом создаётся:

```
<DB_SOURCE_ID>_<YYYYMMDD>_<HHMMSS>.sha256
```

UUID не используется.

### 04_upload.bat

Готовый большой архив переносится через rclone на:

```
\\tsclient\L\!work\RAU_IT\MCP
```

То есть сначала файл формируется локально на удалённом терминале, и только готовый архив передаётся через RDP redirection.

## Передача на leoVM

После появления архива на локальном компьютере клиента:

```
archive.7z
archive.sha256
    ↓ SSH/SCP
leoVM:/home/leo/incoming/
```

## Безопасное обновление MCP

Целевая директория:

```
/home/leo/1c-dumps/MCP_clean
```

Новый dump сначала попадает в staging:

```
MCP_clean.new
```

Последовательность:

```
archive
  ↓
SHA-256
  ↓
7z test
  ↓
распаковка
  ↓
проверка структуры
  ↓
MCP_clean.new
  ↓
MCP_clean → MCP_clean.old
  ↓
MCP_clean.new → MCP_clean
```

При любой ошибке существующий `MCP_clean` не изменяется.

## Итоговая схема

```
JSON
 │
 ├── common.json
 ├── terminals/<COMPUTERNAME>.json
 └── databases/<COMPUTERNAME>/*.json
 │
 ▼
update.bat
 │
 ├── 01_prepare.bat
 ├── 02_dump_config.bat
 ├── 03_pack.bat
 └── 04_upload.bat
 │
 ▼
локальный рабочий каталог терминала
 │
 ▼
7z + SHA-256
 │
 ▼
rclone → \\tsclient\L
 │
 ▼
локальный ПК клиента
 │
 ▼
SSH/SCP
 │
 ▼
leoVM:/home/leo/incoming
 │
 ▼
проверка + staging
 │
 ▼
/home/leo/1c-dumps/MCP_clean
```

## Зафиксированные текущие решения

1. Конфигурация только JSON.
2. BAT-файлы только исполняют действия.
3. `DB_SOURCE_ID` глобально уникален.
4. Количество баз определяется JSON-файлами.
5. Расширения определяются JSON-массивом.
6. Рабочие dump-файлы создаются локально на удалённом терминале.
7. Большой готовый архив передаётся через RDP-диск только после упаковки.
8. Для передачи используется portable rclone.
9. Для архива используется portable `7za.exe`.
10. На leoVM обновление выполняется через staging и атомарную замену.
11. `mcp.json` менять не требуется, если он уже использует `/home/leo/1c-dumps/MCP_clean`.
12. Следующий практический файл для реализации — исправленный `01_prepare.bat` без хардкода путей и параметров.

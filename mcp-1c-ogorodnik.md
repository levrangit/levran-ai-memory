# mcp-1c-ogorodnik

## Назначение

Отдельный экземпляр MCP-сервера `mcp-1c` для конфигурации **Ogorodnik**.

## Конфигурация

- Основная конфигурация: **ERP**
- Расширение: **ERP_RAU**
- Архив исходной выгрузки на leosrv: `/home/leo/1c-dumps/MCP_Ogorodnik.rar`
- Распакованная выгрузка: `/home/leo/1c-dumps/Ogorodnik/ERP`
- Структура выгрузки: ERP — корень dump, ERP_RAU — вложенное расширение.

## MCP-сервер

Отдельная копия бинарника:

`/home/leo/mcp-1c-ogorodnik/mcp-1c`

Запуск:

`/home/leo/mcp-1c-ogorodnik/start.sh`

Фактический dump:

`/home/leo/1c-dumps/Ogorodnik/ERP`

Сервер работает в dump-only режиме; HTTP `--base` для этой копии не настроен.

## Индекс

- Индекс построен успешно.
- Проиндексировано: **26 271 модуль**.
- Кэш индекса: `/home/leo/.cache/mcp-1c/44957d00342573bb`.

## Проверка

MCP `initialize`, `tools/list` и вызов `search_code` были проверены через Desktop Commander.

Поиск по `РАУ` с namespace `ext` вернул модули расширения, в том числе вида:

`ext.РАУ_ИТ....`

## Важно

Этот экземпляр относится только к конфигурации Ogorodnik (ERP + ERP_RAU) и не заменяет существующий экземпляр `mcp-1c` для Документооборота.

Дата настройки: 2026-09-22.
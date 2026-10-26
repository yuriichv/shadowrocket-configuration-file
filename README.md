# shadowrocket-configuration-file (ветка `main`)

Форк конфигураций для [Shadowrocket](https://apps.apple.com/app/shadowrocket/id932747118) на базе
проекта [misha-tgshv/shadowrocket-configuration-file](https://github.com/misha-tgshv/shadowrocket-configuration-file).

## Зачем этот форк

Upstream со временем стал очень тяжёлым: большие списки `domains_refilter` (~2.5 МБ / 82 000 строк),
`ips_refilter` (~730 КБ), `domains_geo_detect` и `domains_banking` заметно увеличивают нагрузку на
CPU/память и расход батареи на мобильных устройствах.

Задачи форка:

1. **Проверенный независимый конфиг** — правила раздаются из этого же репозитория (через cdn.jsdelivr.net),
   без зависимости от доступности upstream.
2. **Облегчённая версия** — конфиг с минимальным влиянием на нагрузку устройства.

## Конфиги

| Конфиг | Описание |
|---|---|
| `conf/sr_ru_public_lists.conf` | **lite** — лёгкая версия. Apple, YouTube, antifilter, OpenAI, Discord, Telegram + пользовательские правила. Тяжёлые списки не используются. |
| `conf/sr_ru_public_lists_full.conf` | **full** — расширенное покрытие: + сообщество (`domains_community`) и банки (`domains_banking`). По-прежнему без refilter/geo_detect. |
| `conf/sr_ru_extended.conf` | Файл **пользовательских правил**. Подключается к lite/full через `include` и не перезаписывается при обновлении. |

Общая логика: `GEOIP,RU` → `DIRECT`, финальное правило `FINAL,DIRECT`; заблокированные ресурсы идут через `PROXY`.

### Установка

1. Shadowrocket → Config → «+» → **Download from URL** и вставьте ссылку на нужный конфиг
   (raw или cdn.jsdelivr.net, ветка `main`).
2. Для пользовательских правил скачайте также `conf/sr_ru_extended.conf` и отредактируйте секцию `[Rule]`.
3. В Settings выберите способ проверки, нажмите Connectivity Test и включите соединение.

### GeoLite2 (для `GEOIP,RU`)

Settings → GeoLite2 Database → `country`:
`https://cdn.jsdelivr.net/gh/Loyalsoldier/geoip@release/Country-without-asn.mmdb`

Без базы RU-трафик всё равно пойдёт напрямую по `FINAL,DIRECT`, просто правило `GEOIP,RU` не будет работать.

## Списки правил

Динамические списки обновляются автоматически (GitHub Actions, ежедневно) из открытых источников:

| Файл | Источник |
|---|---|
| `rules/domain_antifilter.list` | `community.antifilter.download/list/domains.lst` |
| `rules/geoip_antifilter.list` | `community.antifilter.download/list/community.lst` |
| `rules/domains_community.list` | `source/community.list` |
| `rules/domains_banking.list` | сайты банков с `cbr.ru` |

Курируются вручную (не перегенерируются автоматически): `apple`, `domain_youtube`, `openai`,
`domain_discord`, `telegram`, `domain_custom`.

## Разработка

```bash
bash scripts/update-lists.sh     # обновить динамические списки
bash scripts/validate-lists.sh   # проверить формат списков и ссылки в конфигах
```

`validate-lists.sh` проверяет формат правил, отсутствие дубликатов и пробелов в начале строк, а также
что все `RULE-SET`/`include` в конфигах ссылаются на существующие локальные файлы. Запускается в CI перед коммитом.

## Отличия от upstream

- Нет тяжёлых списков `refilter`, `ips_refilter`, `domains_geo_detect` — меньше нагрузки на устройство.
- Одна плоская lite-версия + full + отдельный файл пользовательских правил вместо набора `include`-конфигов.
- Правила и конфиги раздаются из этого форка; автообновление списков и валидация — в `.github/workflows/update-lists.yml`.

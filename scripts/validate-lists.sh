#!/usr/bin/env bash
#
# Валидация списков правил и конфигов main.
#
# Проверяет:
#   - все строки rules/*.list имеют допустимый тип правила и значение;
#   - нет лишних пробелов в начале строк;
#   - нет дубликатов правил внутри файла;
#   - каждый RULE-SET/include в conf/*.conf ссылается на существующий локальный файл.
#
# Запуск из корня репозитория: bash scripts/validate-lists.sh

set -uo pipefail

RULES_DIR="rules"
CONF_DIR="conf"
OWN_MARKERS='github.com/yuriichv/shadowrocket-configuration-file|cdn.jsdelivr.net/gh/yuriichv/shadowrocket-configuration-file'

ALLOWED_TYPES='^(DOMAIN|DOMAIN-SUFFIX|DOMAIN-KEYWORD|IP-CIDR|IP-CIDR6)$'

errors=0
fail() { echo "  ✗ $*"; errors=$((errors + 1)); }

echo "==> Проверка списков в ${RULES_DIR}/"
for file in "${RULES_DIR}"/*.list; do
  [ -e "${file}" ] || continue
  name="${file##*/}"

  dupes="$(sed -E 's/[[:space:]]+#.*$//' "${file}" \
    | sed -E 's/[[:space:]]+$//' \
    | grep -Ev '^[[:space:]]*(#|;|$)' \
    | sort | uniq -d || true)"
  if [ -n "${dupes}" ]; then
    fail "${name}: дубликаты правил:"
    printf '%s\n' "${dupes}" | sed 's/^/      /'
  fi

  line_no=0
  while IFS= read -r raw || [ -n "${raw}" ]; do
    line_no=$((line_no + 1))
    line="$(printf '%s' "${raw}" | sed -E 's/[[:space:]]+#.*$//; s/[[:space:]]+$//')"
    [ -z "${line}" ] && continue
    case "${line}" in \#*|\;*) continue ;; esac
    if [ "${line}" != "${line#"${line%%[![:space:]]*}"}" ]; then
      fail "${name}:${line_no}: строка начинается с пробела: ${raw}"
      continue
    fi
    if ! printf '%s\n' "${line}" | grep -Eq '^[A-Z0-9-]+,[^,]+$'; then
      fail "${name}:${line_no}: неверный формат правила: ${raw}"
      continue
    fi
    type="${line%%,*}"
    if ! printf '%s\n' "${type}" | grep -Eq "${ALLOWED_TYPES}"; then
      fail "${name}:${line_no}: недопустимый тип '${type}'"
    fi
  done < "${file}"
done

echo "==> Проверка конфигов в ${CONF_DIR}/"
for conf in "${CONF_DIR}"/*.conf; do
  [ -e "${conf}" ] || continue
  cname="${conf##*/}"

  while IFS= read -r inc; do
    inc_name="$(printf '%s' "${inc}" | sed -E 's/^[[:space:]]*//; s/[[:space:]]*$//')"
    if [ ! -f "${CONF_DIR}/${inc_name}" ]; then
      fail "${cname}: include указывает на отсутствующий файл '${inc_name}'"
    fi
  done < <(grep -E '^[[:space:]]*include[[:space:]]*=' "${conf}" | sed -E 's/.*=[[:space:]]*//' || true)

  while IFS= read -r url; do
    fname="${url##*/}"
    if [ ! -f "${RULES_DIR}/${fname}" ]; then
      fail "${cname}: RULE-SET ссылается на отсутствующий локальный список '${fname}'"
    fi
  done < <(grep -E '^[[:space:]]*RULE-SET[[:space:]]*,' "${conf}" \
    | grep -Eo "https?://[^,]+" \
    | grep -E "${OWN_MARKERS}" || true)
done

if [ "${errors}" -gt 0 ]; then
  echo "==> Ошибок: ${errors}"
  exit 1
fi
echo "==> OK: списки и конфиги валидны."

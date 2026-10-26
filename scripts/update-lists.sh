#!/usr/bin/env bash
#
# Регенерация динамических списков правил main.
#
# Обновляет:
#   rules/domain_antifilter.list  <- community.antifilter.download/list/domains.lst
#   rules/geoip_antifilter.list   <- community.antifilter.download/list/community.lst
#   rules/domains_community.list  <- source/community.list
#   rules/domains_banking.list    <- cbr.ru/banking_sector/credit/cowebsites/
#
# Курируемые вручную списки (apple, youtube, telegram, openai, discord, custom)
# не трогаются этим скриптом.
#
# Запуск из корня репозитория: bash scripts/update-lists.sh

set -euo pipefail

REPO_URL="https://github.com/yuriichv/shadowrocket-configuration-file"
BRANCH="main"
RULES_DIR="rules"
SOURCE_DIR="source"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

now_msk() { TZ='Europe/Moscow' date '+%Y-%m-%d %H:%M:%S'; }

echo "==> Генерируем: domain_antifilter.list"
curl -sSL https://community.antifilter.download/list/domains.lst \
  | tr -d '\r' \
  | sed -E 's/^\+\./DOMAIN-SUFFIX,/; s/^[^D]/DOMAIN-SUFFIX,&/' \
  | sed '/www|spotify.com/d' \
  | awk '!seen[$0]++' \
  | sort -u > "${TMP_DIR}/af_domains.txt"
{
  echo "# NAME: domain_antifilter.list"
  echo "# REPO: ${REPO_URL}"
  echo "# UPDATED: $(now_msk) MSK"
  echo "# SOURCE: https://community.antifilter.download/list/domains.lst"
  echo "# Количество доменов: $(wc -l < "${TMP_DIR}/af_domains.txt" | tr -d ' ')"
  cat "${TMP_DIR}/af_domains.txt"
} > "${RULES_DIR}/domain_antifilter.list"

echo "==> Генерируем: geoip_antifilter.list"
curl -sSL https://community.antifilter.download/list/community.lst \
  | tr -d '\r' \
  | sed 's/^/IP-CIDR,/g' \
  | sort -u > "${TMP_DIR}/af_ips.txt"
{
  echo "# NAME: geoip_antifilter.list"
  echo "# REPO: ${REPO_URL}"
  echo "# UPDATED: $(now_msk) MSK"
  echo "# SOURCE: https://community.antifilter.download/list/community.lst"
  echo "# Количество IP-адресов: $(wc -l < "${TMP_DIR}/af_ips.txt" | tr -d ' ')"
  cat "${TMP_DIR}/af_ips.txt"
} > "${RULES_DIR}/geoip_antifilter.list"

echo "==> Генерируем: domains_community.list"
tr -d '\r' < "${SOURCE_DIR}/community.list" | \
awk -v repo="${REPO_URL}" -v branch="${BRANCH}" '
  BEGIN {
    print "# NAME: domains_community.list";
    print "# REPO: " repo;
    print "# SOURCE: " repo "/blob/" branch "/source/community.list";
    before_youtube=1
  }
  /^#/ {
    print;
    if ($0 == "# youtube") { before_youtube=0 }
    next
  }
  NF == 0 { next }
  {
    if (before_youtube) {
      print "DOMAIN-KEYWORD," $0
    } else {
      print "DOMAIN-SUFFIX," $0
    }
  }
' > "${RULES_DIR}/domains_community.list"

echo "==> Генерируем: domains_banking.list"
cat > "${TMP_DIR}/decode_idn.py" << 'PYEOF'
import sys, urllib.parse
for line in sys.stdin:
    line = line.strip().lower()
    if not line:
        continue
    try:
        decoded = urllib.parse.unquote(line)
        parts = decoded.split('.')
        has_cyrillic = any(ord(c) > 127 for p in parts for c in p)
        encoded_parts = [
            p.encode('idna').decode('ascii') if any(ord(c) > 127 for c in p) else p
            for p in parts
        ]
        punycode = '.'.join(encoded_parts)
        if has_cyrillic:
            print(f"{punycode} # {decoded}")
        else:
            print(punycode)
    except Exception:
        print(line)
PYEOF
curl -sL https://www.cbr.ru/banking_sector/credit/cowebsites/ \
  | grep -oE 'href="[^"]+' \
  | sed -E 's/^href="//' \
  | grep -E '^https?://' \
  | sed -E 's~https?://~~' \
  | sed -E 's~/.*~~' \
  | tr '[:upper:]' '[:lower:]' \
  | sed -E 's/^www\.//' \
  | grep -E '^[a-zA-Z0-9%._-]+\.[a-zA-Z0-9%_-]+$' \
  | grep -vE '(t\.me|vk\.com|ok\.ru|telegram|dzen|twitter|youtube|zen\.yandex|rutube|linkedin|play\.google|apps\.apple|appgallery|market\.yandex|max\.ru)' \
  | python3 "${TMP_DIR}/decode_idn.py" \
  | sort -u > "${TMP_DIR}/banking.txt"
{
  echo "# NAME: domains_banking.list"
  echo "# REPO: ${REPO_URL}"
  echo "# UPDATED: $(now_msk) MSK"
  echo "# SOURCE: https://www.cbr.ru/banking_sector/credit/cowebsites/"
  echo "# TOTAL: $(wc -l < "${TMP_DIR}/banking.txt" | tr -d ' ')"
  awk '{
    if ($2) print "DOMAIN-SUFFIX," $1 " " $2 " " $3
    else print "DOMAIN-SUFFIX," $1
  }' "${TMP_DIR}/banking.txt"
} > "${RULES_DIR}/domains_banking.list"

echo "==> Готово."

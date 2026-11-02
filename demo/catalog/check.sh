#!/usr/bin/env bash
# Часть общего сценария: запускается через demo/check-backend.sh.

echo '1.1. Публичный каталог без авторизации'
command_line "curl -sS -X GET $BASE_URL/api/samples?species=Triticum&country=RU"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' \
    -X GET "$BASE_URL/api/samples?species=Triticum&country=RU")
output
http_status
[ "$STATUS" = '200' ] || { echo 'ОШИБКА: ожидался HTTP 200' >&2; exit 1; }
check_json 'all(.[]; (keys | sort) == ["accessionCode", "collectionYear", "depositorName", "latinName", "localName", "originCountry", "seedQuantity"])' 'Каталог содержит неожиданные поля'

echo
echo '1.2. Справочник видов для заполнения паспорта'
command_line "curl -sS -X GET $BASE_URL/api/samples/species"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' \
    -X GET "$BASE_URL/api/samples/species")
output
http_status
[ "$STATUS" = '200' ] || { echo 'ОШИБКА: ожидался HTTP 200' >&2; exit 1; }
SPECIES_ID=$(jq -er '.[0].id' "$RESPONSE")

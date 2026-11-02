#!/usr/bin/env bash
# Часть общего сценария: запускается через demo/check-backend.sh.

echo '1.1. Публичный каталог без авторизации'
command_line "curl -sS -X GET $BASE_URL/api/samples?species=Triticum&country=RU"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' \
    -X GET "$BASE_URL/api/samples?species=Triticum&country=RU")
output
http_status
[ "$STATUS" = '200' ] || { echo 'ОШИБКА: ожидался HTTP 200' >&2; exit 1; }
python3 - "$RESPONSE" <<'CHECK'
import json, sys
for sample in json.load(open(sys.argv[1])):
    assert set(sample) == {'accessionCode', 'latinName', 'localName', 'originCountry',
                           'collectionYear', 'seedQuantity', 'depositorName'}, sample
CHECK

echo
echo '1.2. Справочник видов для заполнения паспорта'
command_line "curl -sS -X GET $BASE_URL/api/samples/species"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' \
    -X GET "$BASE_URL/api/samples/species")
output
http_status
[ "$STATUS" = '200' ] || { echo 'ОШИБКА: ожидался HTTP 200' >&2; exit 1; }
SPECIES_ID=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))[0]["id"])' "$RESPONSE")

#!/usr/bin/env bash
# Часть общего сценария: запускается через demo/check-backend.sh.

echo '14.1. Депозитор добавляет отсутствующий вид'
NEW_SPECIES_JSON=$(cat <<JSON
{"latinName":"  Demo species $RUN_ID  ","localName":"  Демо-вид $RUN_ID  ","family":"  Demoaceae  "}
JSON
)
command_line "curl -sS -X POST $BASE_URL/api/depositors/me/species -b <applicant-cookies> -H 'Content-Type: application/json' -d '$NEW_SPECIES_JSON'"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' \
    -X POST "$BASE_URL/api/depositors/me/species" \
    -b "$APPLICANT_COOKIES" -H "$APPLICANT_CSRF_HEADER: $APPLICANT_CSRF_TOKEN" \
    -H 'Content-Type: application/json' -d "$NEW_SPECIES_JSON")
output
http_status
[ "$STATUS" = '201' ] || { echo 'ОШИБКА: ожидался HTTP 201' >&2; exit 1; }
SPECIES_ID=$(jq -er '.id' "$RESPONSE")
check_json '.latinName == $latin and .localName == $local and .family == "Demoaceae"' 'Названия вида не нормализованы' --arg latin "Demo species $RUN_ID" --arg local "Демо-вид $RUN_ID"

echo
echo '14.2. Повтор того же вида с другим регистром отклоняется: HTTP 409'
DUPLICATE_SPECIES_JSON=$(jq -c '.latinName |= ascii_upcase' <<< "$NEW_SPECIES_JSON")
command_line "curl -sS -X POST $BASE_URL/api/depositors/me/species -b <applicant-cookies> -d '$DUPLICATE_SPECIES_JSON'"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' \
    -X POST "$BASE_URL/api/depositors/me/species" \
    -b "$APPLICANT_COOKIES" -H "$APPLICANT_CSRF_HEADER: $APPLICANT_CSRF_TOKEN" \
    -H 'Content-Type: application/json' -d "$DUPLICATE_SPECIES_JSON")
output
http_status
[ "$STATUS" = '409' ] || { echo 'ОШИБКА: ожидался HTTP 409' >&2; exit 1; }

echo
echo '14.3. Пустое название отклоняется: HTTP 400'
command_line "curl -sS -X POST $BASE_URL/api/depositors/me/species -b <applicant-cookies> -d '{\"latinName\":\" \",\"localName\":\"Демо\"}'"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' \
    -X POST "$BASE_URL/api/depositors/me/species" \
    -b "$APPLICANT_COOKIES" -H "$APPLICANT_CSRF_HEADER: $APPLICANT_CSRF_TOKEN" \
    -H 'Content-Type: application/json' -d '{"latinName":" ","localName":"Демо"}')
output
http_status
[ "$STATUS" = '400' ] || { echo 'ОШИБКА: ожидался HTTP 400' >&2; exit 1; }

echo
echo '14.4. Новый вид появился в общем справочнике без авторизации'
command_line "curl -sS $BASE_URL/api/samples/species"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' "$BASE_URL/api/samples/species")
output
http_status
[ "$STATUS" = '200' ] || { echo 'ОШИБКА: ожидался HTTP 200' >&2; exit 1; }
check_json 'any(.[]; .id == $id)' 'Новый вид отсутствует в справочнике' --argjson id "$SPECIES_ID"

# Используем только что созданный вид в паспортах следующей партии.
BATCH_JSON=$(jq -c --argjson id "$SPECIES_ID" '(.boxes[].samples[].speciesId) = $id' <<< "$BATCH_JSON")

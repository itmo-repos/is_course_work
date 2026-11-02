#!/usr/bin/env bash
# Часть общего сценария: запускается через demo/check-backend.sh.

. "$DEMO_DIR/catalog/add-species.sh"

echo
echo '15. Создаём партию с двумя коробками и паспортами: FORMED'
command_line "curl -sS -X POST $BASE_URL/api/depositors/me/batches -b <applicant-cookies> -H 'Content-Type: application/json' -d '$BATCH_JSON'"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' \
    -X POST "$BASE_URL/api/depositors/me/batches" \
    -b "$APPLICANT_COOKIES" \
    -H "$APPLICANT_CSRF_HEADER: $APPLICANT_CSRF_TOKEN" \
    -H 'Content-Type: application/json' \
    -d "$BATCH_JSON")
output
http_status
[ "$STATUS" = '201' ] || { echo 'ОШИБКА: ожидался HTTP 201' >&2; exit 1; }
BATCH_ID=$(jq -er '.id' "$RESPONSE")
check_json '.status == "FORMED" and .boxCount == 2' 'Ожидалась сформированная партия с двумя коробками'
check_json '.number | test("^B-[0-9]{6,}$")' 'Некорректный номер партии'
check_json 'all(.boxes[].samples[]; .accessionCode | test("^S-[0-9]{6,}$"))' 'Некорректный код образца'
check_json 'all(.boxes[].samples[]; .speciesId == $id)' 'В паспорте не использован новый вид' --argjson id "$SPECIES_ID"
check_json 'all(.boxes[]; .status == "FORMED" and .barcode == null and (.samples | length) > 0)' 'У новых коробок неверный статус или состав'

echo
echo '16. Депозитору запрещено подтверждать партию: HTTP 403'
command_line "curl -sS -X POST $BASE_URL/api/curator/batches/$BATCH_ID/confirm"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' \
    -X POST "$BASE_URL/api/curator/batches/$BATCH_ID/confirm" \
    -b "$APPLICANT_COOKIES" \
    -H "$APPLICANT_CSRF_HEADER: $APPLICANT_CSRF_TOKEN")
output
http_status
[ "$STATUS" = '403' ] || { echo 'ОШИБКА: ожидался HTTP 403' >&2; exit 1; }

echo
echo '17. Куратор видит сформированные партии'
command_line "curl -sS -X GET $BASE_URL/api/curator/batches?status=FORMED"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' \
    -X GET "$BASE_URL/api/curator/batches?status=FORMED" \
    -b "$ADMIN_COOKIES")
output
http_status
[ "$STATUS" = '200' ] || { echo 'ОШИБКА: ожидался HTTP 200' >&2; exit 1; }
check_json 'any(.[]; .id == $id)' 'Созданная партия отсутствует в списке' --argjson id "$BATCH_ID"

echo
echo '18. Куратор отклоняет партию с причиной'
command_line "curl -sS -X POST $BASE_URL/api/curator/batches/$BATCH_ID/reject -b <admin-cookies> -H 'Content-Type: application/json' -d '{\"reason\":\"Уточните паспорта (демо)\"}'"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' \
    -X POST "$BASE_URL/api/curator/batches/$BATCH_ID/reject" \
    -b "$ADMIN_COOKIES" \
    -H "$ADMIN_CSRF_HEADER: $ADMIN_CSRF_TOKEN" \
    -H 'Content-Type: application/json' \
    -d '{"reason":"Уточните паспорта (демо)"}')
output
http_status
[ "$STATUS" = '200' ] || { echo 'ОШИБКА: ожидался HTTP 200' >&2; exit 1; }
check_json '.status == "REJECTED" and (.rejectionReason | length) > 0' 'Партия не отклонена с причиной'

echo
echo '19. Депозитор исправляет и повторно отправляет партию'
command_line "curl -sS -X PUT $BASE_URL/api/depositors/me/batches/$BATCH_ID -b <applicant-cookies> -d '$BATCH_JSON'"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' \
    -X PUT "$BASE_URL/api/depositors/me/batches/$BATCH_ID" \
    -b "$APPLICANT_COOKIES" \
    -H "$APPLICANT_CSRF_HEADER: $APPLICANT_CSRF_TOKEN" \
    -H 'Content-Type: application/json' \
    -d "$BATCH_JSON")
output
http_status
[ "$STATUS" = '200' ] || { echo 'ОШИБКА: ожидался HTTP 200' >&2; exit 1; }
check_json '.status == "FORMED" and .boxCount == 2' 'Партия не отправлена повторно'
BOX_ID=$(jq -er '.boxes[0].id' "$RESPONSE")

echo
echo '20. До подтверждения штрихкод недоступен: HTTP 409'
command_line "curl -sS -X GET $BASE_URL/api/depositors/me/batches/$BATCH_ID/boxes/$BOX_ID/barcode"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' \
    -X GET "$BASE_URL/api/depositors/me/batches/$BATCH_ID/boxes/$BOX_ID/barcode" \
    -b "$APPLICANT_COOKIES")
output
http_status
[ "$STATUS" = '409' ] || { echo 'ОШИБКА: ожидался HTTP 409' >&2; exit 1; }

echo
echo '21. Куратор подтверждает партию: CONFIRMED, уникальные штрихкоды'
command_line "curl -sS -X POST $BASE_URL/api/curator/batches/$BATCH_ID/confirm"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' \
    -X POST "$BASE_URL/api/curator/batches/$BATCH_ID/confirm" \
    -b "$ADMIN_COOKIES" \
    -H "$ADMIN_CSRF_HEADER: $ADMIN_CSRF_TOKEN")
output
http_status
[ "$STATUS" = '200' ] || { echo 'ОШИБКА: ожидался HTTP 200' >&2; exit 1; }
check_json '.status == "CONFIRMED" and .confirmedAt != null' 'Партия не подтверждена'
BATCH_NUMBER=$(jq -er '.number' "$RESPONSE")
BARCODE_PREFIX=${BATCH_NUMBER//-/}
check_json '.boxes[0].barcode == $first and .boxes[1].barcode == $second' 'Неверные штрихкоды коробок' --arg first "$BARCODE_PREFIX-001" --arg second "$BARCODE_PREFIX-002"

echo
echo '22. Депозитор скачивает Code 128 для печати'
command_line "curl -sS -b <applicant-cookies> -o <barcode.svg> $BASE_URL/api/depositors/me/batches/$BATCH_ID/boxes/$BOX_ID/barcode"
STATUS=$(curl -sS -b "$APPLICANT_COOKIES" -o "$TEMP_DIR/barcode.svg" -w '%{http_code}' "$BASE_URL/api/depositors/me/batches/$BATCH_ID/boxes/$BOX_ID/barcode")
http_status
[ "$STATUS" = '200' ] || { echo 'ОШИБКА: штрихкод не скачан' >&2; exit 1; }
grep -q '<svg ' "$TEMP_DIR/barcode.svg" || { echo 'ОШИБКА: ответ не содержит SVG' >&2; exit 1; }
grep -q '<rect ' "$TEMP_DIR/barcode.svg" || { echo 'ОШИБКА: в SVG нет полос штрихкода' >&2; exit 1; }
echo 'Получен SVG со штрихкодом Code 128'

echo
echo '23. Повторное подтверждение запрещено: HTTP 409'
command_line "curl -sS -X POST $BASE_URL/api/curator/batches/$BATCH_ID/confirm"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' \
    -X POST "$BASE_URL/api/curator/batches/$BATCH_ID/confirm" \
    -b "$ADMIN_COOKIES" \
    -H "$ADMIN_CSRF_HEADER: $ADMIN_CSRF_TOKEN")
output
http_status
[ "$STATUS" = '409' ] || { echo 'ОШИБКА: ожидался HTTP 409' >&2; exit 1; }

echo
echo '24. Нельзя перескочить сразу в ARRIVED: HTTP 409'
command_line "curl -sS -X PATCH $BASE_URL/api/curator/batches/$BATCH_ID/tracking-status"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' \
    -X PATCH "$BASE_URL/api/curator/batches/$BATCH_ID/tracking-status" \
    -b "$ADMIN_COOKIES" \
    -H "$ADMIN_CSRF_HEADER: $ADMIN_CSRF_TOKEN" \
    -H 'Content-Type: application/json' \
    -d '{"status":"ARRIVED"}')
output
http_status
[ "$STATUS" = '409' ] || { echo 'ОШИБКА: ожидался HTTP 409' >&2; exit 1; }

echo
. "$DEMO_DIR/intake/plan.sh"

echo
echo '25. Перевозчик принял партию: IN_TRANSIT'
command_line "curl -sS -X PATCH $BASE_URL/api/curator/batches/$BATCH_ID/tracking-status"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' \
    -X PATCH "$BASE_URL/api/curator/batches/$BATCH_ID/tracking-status" \
    -b "$ADMIN_COOKIES" \
    -H "$ADMIN_CSRF_HEADER: $ADMIN_CSRF_TOKEN" \
    -H 'Content-Type: application/json' \
    -d '{"status":"IN_TRANSIT","trackingNumber":"DEMO-TRACK"}')
output
http_status
[ "$STATUS" = '200' ] || { echo 'ОШИБКА: ожидался HTTP 200' >&2; exit 1; }
check_json '.status == "IN_TRANSIT"' 'Партия не переведена в путь'

echo
echo '26. Партия прибыла: ARRIVED'
command_line "curl -sS -X PATCH $BASE_URL/api/curator/batches/$BATCH_ID/tracking-status"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' \
    -X PATCH "$BASE_URL/api/curator/batches/$BATCH_ID/tracking-status" \
    -b "$ADMIN_COOKIES" \
    -H "$ADMIN_CSRF_HEADER: $ADMIN_CSRF_TOKEN" \
    -H 'Content-Type: application/json' \
    -d '{"status":"ARRIVED"}')
output
http_status
[ "$STATUS" = '200' ] || { echo 'ОШИБКА: ожидался HTTP 200' >&2; exit 1; }

echo
echo '27. Депозитор видит путь и состав своей партии'
command_line "curl -sS -X GET $BASE_URL/api/depositors/me/batches/$BATCH_ID"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' \
    -X GET "$BASE_URL/api/depositors/me/batches/$BATCH_ID" \
    -b "$APPLICANT_COOKIES")
output
http_status
[ "$STATUS" = '200' ] || { echo 'ОШИБКА: ожидался HTTP 200' >&2; exit 1; }
check_json '.status == "ARRIVED" and .formedAt != null and .confirmedAt != null and .arrivedAt != null and .trackingNumber == "DEMO-TRACK"' 'Не сохранены статус, даты пути или номер отслеживания'

echo
echo '28. Список своих партий содержит новую партию'
command_line "curl -sS -X GET $BASE_URL/api/depositors/me/batches"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' \
    -X GET "$BASE_URL/api/depositors/me/batches" \
    -b "$APPLICANT_COOKIES")
output
http_status
[ "$STATUS" = '200' ] || { echo 'ОШИБКА: ожидался HTTP 200' >&2; exit 1; }
check_json 'any(.[]; .id == $id)' 'Созданная партия отсутствует в списке' --argjson id "$BATCH_ID"

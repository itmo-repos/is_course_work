#!/usr/bin/env bash
# Часть общего сценария: запускается через demo/check-backend.sh.

SINGLE_BOX_JSON=$(jq -c '.boxes = .boxes[:1]' <<< "$BATCH_JSON")

echo
echo 'Дополнительно: готовим отдельную партию для итога PLACED'
command_line "curl -sS -X POST $BASE_URL/api/depositors/me/batches -b <cookies>"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' \
    -X POST "$BASE_URL/api/depositors/me/batches" \
    -b "$APPLICANT_COOKIES" \
    -H "$APPLICANT_CSRF_HEADER: $APPLICANT_CSRF_TOKEN" \
    -H 'Content-Type: application/json' \
    -d "$SINGLE_BOX_JSON")
output
http_status
[ "$STATUS" = '201' ] || { echo 'ОШИБКА: ожидался HTTP 201' >&2; exit 1; }
OUTCOME_BATCH_ID=$(jq -er '.id' "$RESPONSE")
OUTCOME_BOX_ID=$(jq -er '.boxes[0].id' "$RESPONSE")

echo
echo 'Подтверждаем дополнительную партию'
command_line "curl -sS -X POST $BASE_URL/api/curator/batches/$OUTCOME_BATCH_ID/confirm -b <cookies>"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' \
    -X POST "$BASE_URL/api/curator/batches/$OUTCOME_BATCH_ID/confirm" \
    -b "$ADMIN_COOKIES" \
    -H "$ADMIN_CSRF_HEADER: $ADMIN_CSRF_TOKEN")
output
http_status
[ "$STATUS" = '200' ] || { echo 'ОШИБКА: ожидался HTTP 200' >&2; exit 1; }
OUTCOME_BARCODE=$(jq -er '.boxes[0].barcode' "$RESPONSE")

echo
echo 'Создаём дополнительную сессию'
command_line "curl -sS -X POST $BASE_URL/api/curator/batches/$OUTCOME_BATCH_ID/intake-sessions -b <cookies>"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' \
    -X POST "$BASE_URL/api/curator/batches/$OUTCOME_BATCH_ID/intake-sessions" \
    -b "$ADMIN_COOKIES" \
    -H "$ADMIN_CSRF_HEADER: $ADMIN_CSRF_TOKEN" \
    -H 'Content-Type: application/json' \
    -d "{\"chamberId\":$CHAMBER_ID,\"plannedDate\":\"$(date +%F)\"}")
output
http_status
[ "$STATUS" = '201' ] || { echo 'ОШИБКА: ожидался HTTP 201' >&2; exit 1; }
OUTCOME_SESSION_ID=$(jq -er '.id' "$RESPONSE")

echo
echo 'Дополнительная партия в пути'
command_line "curl -sS -X PATCH $BASE_URL/api/curator/batches/$OUTCOME_BATCH_ID/tracking-status -b <cookies>"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' \
    -X PATCH "$BASE_URL/api/curator/batches/$OUTCOME_BATCH_ID/tracking-status" \
    -b "$ADMIN_COOKIES" \
    -H "$ADMIN_CSRF_HEADER: $ADMIN_CSRF_TOKEN" \
    -H 'Content-Type: application/json' \
    -d '{"status":"IN_TRANSIT"}')
output
http_status
[ "$STATUS" = '200' ] || { echo 'ОШИБКА: ожидался HTTP 200' >&2; exit 1; }

echo
echo 'Дополнительная партия прибыла'
command_line "curl -sS -X PATCH $BASE_URL/api/curator/batches/$OUTCOME_BATCH_ID/tracking-status -b <cookies>"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' \
    -X PATCH "$BASE_URL/api/curator/batches/$OUTCOME_BATCH_ID/tracking-status" \
    -b "$ADMIN_COOKIES" \
    -H "$ADMIN_CSRF_HEADER: $ADMIN_CSRF_TOKEN" \
    -H 'Content-Type: application/json' \
    -d '{"status":"ARRIVED"}')
output
http_status
[ "$STATUS" = '200' ] || { echo 'ОШИБКА: ожидался HTTP 200' >&2; exit 1; }

echo
echo 'Регистрируем её досмотр'
command_line "curl -sS -X POST $BASE_URL/api/curator/batches/by-barcode/$OUTCOME_BARCODE/arrive -b <cookies>"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' \
    -X POST "$BASE_URL/api/curator/batches/by-barcode/$OUTCOME_BARCODE/arrive" \
    -b "$ADMIN_COOKIES" \
    -H "$ADMIN_CSRF_HEADER: $ADMIN_CSRF_TOKEN")
output
http_status
[ "$STATUS" = '200' ] || { echo 'ОШИБКА: ожидался HTTP 200' >&2; exit 1; }

echo
echo 'Обрабатываем единственную коробку: PLACED'
command_line "curl -sS -X POST $BASE_URL/api/curator/boxes/$OUTCOME_BOX_ID/place -b <cookies>"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' \
    -X POST "$BASE_URL/api/curator/boxes/$OUTCOME_BOX_ID/place" \
    -b "$ADMIN_COOKIES" \
    -H "$ADMIN_CSRF_HEADER: $ADMIN_CSRF_TOKEN")
output
http_status
[ "$STATUS" = '200' ] || { echo 'ОШИБКА: ожидался HTTP 200' >&2; exit 1; }

echo
echo 'Проверяем итог PLACED и завершение сессии'
command_line "curl -sS -X GET $BASE_URL/api/curator/intake-sessions/$OUTCOME_SESSION_ID -b <cookies>"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' \
    -X GET "$BASE_URL/api/curator/intake-sessions/$OUTCOME_SESSION_ID" \
    -b "$ADMIN_COOKIES")
output
http_status
[ "$STATUS" = '200' ] || { echo 'ОШИБКА: ожидался HTTP 200' >&2; exit 1; }
check_json '.status == "COMPLETED" and .batchStatus == "PLACED" and .completedAt != null' 'Приём не завершился полным размещением'

echo
echo 'Дополнительно: готовим отдельную партию для итога WRITTEN_OFF'
command_line "curl -sS -X POST $BASE_URL/api/depositors/me/batches -b <cookies>"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' \
    -X POST "$BASE_URL/api/depositors/me/batches" \
    -b "$APPLICANT_COOKIES" \
    -H "$APPLICANT_CSRF_HEADER: $APPLICANT_CSRF_TOKEN" \
    -H 'Content-Type: application/json' \
    -d "$SINGLE_BOX_JSON")
output
http_status
[ "$STATUS" = '201' ] || { echo 'ОШИБКА: ожидался HTTP 201' >&2; exit 1; }
OUTCOME_BATCH_ID=$(jq -er '.id' "$RESPONSE")
OUTCOME_BOX_ID=$(jq -er '.boxes[0].id' "$RESPONSE")

echo
echo 'Подтверждаем дополнительную партию'
command_line "curl -sS -X POST $BASE_URL/api/curator/batches/$OUTCOME_BATCH_ID/confirm -b <cookies>"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' \
    -X POST "$BASE_URL/api/curator/batches/$OUTCOME_BATCH_ID/confirm" \
    -b "$ADMIN_COOKIES" \
    -H "$ADMIN_CSRF_HEADER: $ADMIN_CSRF_TOKEN")
output
http_status
[ "$STATUS" = '200' ] || { echo 'ОШИБКА: ожидался HTTP 200' >&2; exit 1; }
OUTCOME_BARCODE=$(jq -er '.boxes[0].barcode' "$RESPONSE")

echo
echo 'Создаём дополнительную сессию'
command_line "curl -sS -X POST $BASE_URL/api/curator/batches/$OUTCOME_BATCH_ID/intake-sessions -b <cookies>"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' \
    -X POST "$BASE_URL/api/curator/batches/$OUTCOME_BATCH_ID/intake-sessions" \
    -b "$ADMIN_COOKIES" \
    -H "$ADMIN_CSRF_HEADER: $ADMIN_CSRF_TOKEN" \
    -H 'Content-Type: application/json' \
    -d "{\"chamberId\":$CHAMBER_ID,\"plannedDate\":\"$(date +%F)\"}")
output
http_status
[ "$STATUS" = '201' ] || { echo 'ОШИБКА: ожидался HTTP 201' >&2; exit 1; }
OUTCOME_SESSION_ID=$(jq -er '.id' "$RESPONSE")

echo
echo 'Дополнительная партия в пути'
command_line "curl -sS -X PATCH $BASE_URL/api/curator/batches/$OUTCOME_BATCH_ID/tracking-status -b <cookies>"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' \
    -X PATCH "$BASE_URL/api/curator/batches/$OUTCOME_BATCH_ID/tracking-status" \
    -b "$ADMIN_COOKIES" \
    -H "$ADMIN_CSRF_HEADER: $ADMIN_CSRF_TOKEN" \
    -H 'Content-Type: application/json' \
    -d '{"status":"IN_TRANSIT"}')
output
http_status
[ "$STATUS" = '200' ] || { echo 'ОШИБКА: ожидался HTTP 200' >&2; exit 1; }

echo
echo 'Дополнительная партия прибыла'
command_line "curl -sS -X PATCH $BASE_URL/api/curator/batches/$OUTCOME_BATCH_ID/tracking-status -b <cookies>"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' \
    -X PATCH "$BASE_URL/api/curator/batches/$OUTCOME_BATCH_ID/tracking-status" \
    -b "$ADMIN_COOKIES" \
    -H "$ADMIN_CSRF_HEADER: $ADMIN_CSRF_TOKEN" \
    -H 'Content-Type: application/json' \
    -d '{"status":"ARRIVED"}')
output
http_status
[ "$STATUS" = '200' ] || { echo 'ОШИБКА: ожидался HTTP 200' >&2; exit 1; }

echo
echo 'Регистрируем её досмотр'
command_line "curl -sS -X POST $BASE_URL/api/curator/batches/by-barcode/$OUTCOME_BARCODE/arrive -b <cookies>"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' \
    -X POST "$BASE_URL/api/curator/batches/by-barcode/$OUTCOME_BARCODE/arrive" \
    -b "$ADMIN_COOKIES" \
    -H "$ADMIN_CSRF_HEADER: $ADMIN_CSRF_TOKEN")
output
http_status
[ "$STATUS" = '200' ] || { echo 'ОШИБКА: ожидался HTTP 200' >&2; exit 1; }

echo
echo 'Обрабатываем единственную коробку: WRITTEN_OFF'
command_line "curl -sS -X POST $BASE_URL/api/curator/boxes/$OUTCOME_BOX_ID/write-off -b <cookies>"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' \
    -X POST "$BASE_URL/api/curator/boxes/$OUTCOME_BOX_ID/write-off" \
    -b "$ADMIN_COOKIES" \
    -H "$ADMIN_CSRF_HEADER: $ADMIN_CSRF_TOKEN" \
    -H 'Content-Type: application/json' \
    -d '{"reason":"Повреждение упаковки (демо)"}')
output
http_status
[ "$STATUS" = '200' ] || { echo 'ОШИБКА: ожидался HTTP 200' >&2; exit 1; }

echo
echo 'Проверяем итог WRITTEN_OFF и завершение сессии'
command_line "curl -sS -X GET $BASE_URL/api/curator/intake-sessions/$OUTCOME_SESSION_ID -b <cookies>"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' \
    -X GET "$BASE_URL/api/curator/intake-sessions/$OUTCOME_SESSION_ID" \
    -b "$ADMIN_COOKIES")
output
http_status
[ "$STATUS" = '200' ] || { echo 'ОШИБКА: ожидался HTTP 200' >&2; exit 1; }
check_json '.status == "COMPLETED" and .batchStatus == "WRITTEN_OFF" and .completedAt != null' 'Приём не завершился полным списанием'

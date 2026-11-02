#!/usr/bin/env bash
# Часть общего сценария: запускается через demo/check-backend.sh.

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
BATCH_ID=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["id"])' "$RESPONSE")
python3 - "$RESPONSE" <<'CHECK'
import json, sys
batch = json.load(open(sys.argv[1]))
assert batch['status'] == 'FORMED' and batch['boxCount'] == 2
assert all(b['status'] == 'FORMED' and b['barcode'] is None and b['samples'] for b in batch['boxes'])
CHECK

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
python3 - "$RESPONSE" "$BATCH_ID" <<'CHECK'
import json, sys
assert any(b['id'] == int(sys.argv[2]) for b in json.load(open(sys.argv[1])))
CHECK

echo
echo '18. Куратор отклоняет партию с причиной'
command_line "curl -sS -X POST $BASE_URL/api/curator/batches/$BATCH_ID/reject"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' \
    -X POST "$BASE_URL/api/curator/batches/$BATCH_ID/reject" \
    -b "$ADMIN_COOKIES" \
    -H "$ADMIN_CSRF_HEADER: $ADMIN_CSRF_TOKEN" \
    -H 'Content-Type: application/json' \
    -d '{"reason":"Уточните паспорта (демо)"}')
output
http_status
[ "$STATUS" = '200' ] || { echo 'ОШИБКА: ожидался HTTP 200' >&2; exit 1; }
python3 -c 'import json,sys; b=json.load(open(sys.argv[1])); assert b["status"] == "REJECTED" and b["rejectionReason"]' "$RESPONSE"

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
python3 -c 'import json,sys; b=json.load(open(sys.argv[1])); assert b["status"] == "FORMED" and b["boxCount"] == 2' "$RESPONSE"
BOX_ID=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["boxes"][0]["id"])' "$RESPONSE")

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
python3 - "$RESPONSE" <<'CHECK'
import json, sys
batch = json.load(open(sys.argv[1]))
codes = [box['barcode'] for box in batch['boxes']]
assert batch['status'] == 'CONFIRMED' and batch['confirmedAt']
assert all(codes) and len(set(codes)) == len(codes)
CHECK

echo
echo '22. Депозитор скачивает Code 128 для печати'
command_line "curl -sS -b <applicant-cookies> -o <barcode.svg> $BASE_URL/api/depositors/me/batches/$BATCH_ID/boxes/$BOX_ID/barcode"
STATUS=$(curl -sS -b "$APPLICANT_COOKIES" -o "$TEMP_DIR/barcode.svg" -w '%{http_code}' "$BASE_URL/api/depositors/me/batches/$BATCH_ID/boxes/$BOX_ID/barcode")
http_status
[ "$STATUS" = '200' ] || { echo 'ОШИБКА: штрихкод не скачан' >&2; exit 1; }
python3 - "$TEMP_DIR/barcode.svg" <<'CHECK'
import sys, xml.etree.ElementTree as ET
svg = ET.parse(sys.argv[1]).getroot()
assert svg.tag == '{http://www.w3.org/2000/svg}svg'
assert len(svg.findall('.//{http://www.w3.org/2000/svg}rect')) > 20
print('Получен SVG со штрихкодом Code 128')
CHECK

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
python3 -c 'import json,sys; assert json.load(open(sys.argv[1]))["status"] == "IN_TRANSIT"' "$RESPONSE"

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
python3 -c 'import json,sys; b=json.load(open(sys.argv[1])); assert b["status"] == "ARRIVED" and b["formedAt"] and b["confirmedAt"] and b["arrivedAt"] and b["trackingNumber"] == "DEMO-TRACK"' "$RESPONSE"

echo
echo '28. Список своих партий содержит новую партию'
command_line "curl -sS -X GET $BASE_URL/api/depositors/me/batches"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' \
    -X GET "$BASE_URL/api/depositors/me/batches" \
    -b "$APPLICANT_COOKIES")
output
http_status
[ "$STATUS" = '200' ] || { echo 'ОШИБКА: ожидался HTTP 200' >&2; exit 1; }
python3 - "$RESPONSE" "$BATCH_ID" <<'CHECK'
import json, sys
assert any(b['id'] == int(sys.argv[2]) for b in json.load(open(sys.argv[1])))
CHECK

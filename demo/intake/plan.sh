#!/usr/bin/env bash
# Часть общего сценария: запускается через demo/check-backend.sh.

echo '24.1. Планируем приём подтверждённой партии до отправки'
command_line "curl -sS $BASE_URL/api/curator/chambers -b <admin-cookies>"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' "$BASE_URL/api/curator/chambers" -b "$ADMIN_COOKIES")
output
http_status
[ "$STATUS" = '200' ] || { echo 'ОШИБКА: ожидался HTTP 200' >&2; exit 1; }
CHAMBER_ID=$(jq -er 'first(.[] | select(.freePlaceCount >= 3)) | .id' "$RESPONSE")
CHAMBER_CODE=$(jq -er --argjson id "$CHAMBER_ID" '.[] | select(.id == $id) | .code' "$RESPONSE")
FREE_BEFORE_PLAN=$(jq -er --argjson id "$CHAMBER_ID" '.[] | select(.id == $id) | .freePlaceCount' "$RESPONSE")

command_line "curl -sS -X POST $BASE_URL/api/curator/batches/$BATCH_ID/intake-sessions -b <admin-cookies>"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' \
    -X POST "$BASE_URL/api/curator/batches/$BATCH_ID/intake-sessions" \
    -b "$ADMIN_COOKIES" -H "$ADMIN_CSRF_HEADER: $ADMIN_CSRF_TOKEN" \
    -H 'Content-Type: application/json' \
    -d "{\"chamberId\":$CHAMBER_ID,\"plannedDate\":\"$(date +%F)\"}")
output
http_status
[ "$STATUS" = '201' ] || { echo 'ОШИБКА: ожидался HTTP 201' >&2; exit 1; }
SESSION_ID=$(jq -er '.id' "$RESPONSE")
INTAKE_PASS_ID=$(jq -er '.issuedPass.pass.id' "$RESPONSE")
INTAKE_PASS_CODE=$(jq -er '.issuedPass.code' "$RESPONSE")
jq -er '.issuedPass.qrSvg' "$RESPONSE" > "$TEMP_DIR/intake-pass.svg"
check_json '.issuedPass.code | test("^[A-Za-z0-9_-]{43}$")' 'Пропуск должен содержать случайный код'
printf "${OUTPUT_COLOR}QR временного пропуска создан; секрет сохранён только для текущего демо и скрыт в выводе.${RESET_COLOR}\n"
BOX_ID=$(jq -er '.boxes[0].id' "$RESPONSE")
SECOND_BOX_ID=$(jq -er '.boxes[1].id' "$RESPONSE")
check_json '.status == "PLANNED" and .batchStatus == "CONFIRMED" and all(.boxes[]; .status == "FORMED" and .storagePlace == null)' 'Планирование не должно менять коробки и занимать места'

echo
echo '24.2. Планирование не заняло места в камере'
command_line "curl -sS $BASE_URL/api/curator/chambers/$CHAMBER_ID/free-places -b <admin-cookies>"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' \
    "$BASE_URL/api/curator/chambers/$CHAMBER_ID/free-places" -b "$ADMIN_COOKIES")
http_status
[ "$STATUS" = '200' ] || { output; echo 'ОШИБКА: ожидался HTTP 200' >&2; exit 1; }
FREE_AFTER_PLAN=$(jq 'length' "$RESPONSE")
[ "$FREE_AFTER_PLAN" -eq "$FREE_BEFORE_PLAN" ] || {
    echo "ОШИБКА: свободных мест было $FREE_BEFORE_PLAN, стало $FREE_AFTER_PLAN" >&2
    exit 1
}
printf "${OUTPUT_COLOR}Камера: %s\nСвободных мест до планирования: %s\nСвободных мест после планирования: %s\nПроверка пройдена: планирование не заняло места.${RESET_COLOR}\n" \
    "$CHAMBER_CODE" "$FREE_BEFORE_PLAN" "$FREE_AFTER_PLAN"

MAP_STAGE=PLANNED
. "$DEMO_DIR/intake/map.sh"

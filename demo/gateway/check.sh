#!/usr/bin/env bash
# Часть общего сценария: запускается через demo/check-backend.sh.

echo 'Шлюз. Администратор выдаёт ключ только для выбранной камеры'
command_line "curl -sS -X POST $BASE_URL/api/admin/chambers/$CHAMBER_ID/gateway-keys -b <admin-cookies> -d '{\"name\":\"Демо-шлюз\"}'"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' -X POST "$BASE_URL/api/admin/chambers/$CHAMBER_ID/gateway-keys" \
    -b "$ADMIN_COOKIES" -H "$ADMIN_CSRF_HEADER: $ADMIN_CSRF_TOKEN" -H 'Content-Type: application/json' -d '{"name":"Демо-шлюз"}')
http_status
[ "$STATUS" = 201 ] || { output; exit 1; }
GATEWAY_TOKEN=$(jq -er '.token' "$RESPONSE")
GATEWAY_KEY_ID=$(jq -er '.key.id' "$RESPONSE")
check_json '.key.chamberId == $id and (.token | test("^sgw_[A-Za-z0-9_-]{43}$"))' 'Неверный ключ или камера' --argjson id "$CHAMBER_ID"
jq '.token = "<ключ скрыт; выдаётся один раз>"' "$RESPONSE" > "$TEMP_DIR/visible-key.json"
cp "$TEMP_DIR/visible-key.json" "$RESPONSE"
output

GATEWAY_TIME=$(date -u -d '1 minute ago' +%s)
GATEWAY_NORMAL=$(jq -cn --arg time "$(date -u -d "@$GATEWAY_TIME" +%Y-%m-%dT%H:%M:%SZ)" '{measuredAt:$time,temperature:-18,humidity:25}')
GATEWAY_BAD=$(jq -cn --arg time "$(date -u -d "@$((GATEWAY_TIME + 1))" +%Y-%m-%dT%H:%M:%SZ)" '{measuredAt:$time,temperature:-10,humidity:45}')
GATEWAY_BAD_AGAIN=$(jq -cn --arg time "$(date -u -d "@$((GATEWAY_TIME + 2))" +%Y-%m-%dT%H:%M:%SZ)" '{measuredAt:$time,temperature:-9,humidity:46}')

echo 'Без ключа измерение не принимается: 401'
command_line "curl -sS -X POST $BASE_URL/api/gateway/readings -d '$GATEWAY_NORMAL'"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' -X POST "$BASE_URL/api/gateway/readings" \
    -H 'Content-Type: application/json' -d "$GATEWAY_NORMAL")
output
http_status
[ "$STATUS" = 401 ] || exit 1

echo 'Ключ отправляет нормальное измерение без cookie и CSRF'
command_line "curl -sS -X POST $BASE_URL/api/gateway/readings -H 'Authorization: Bearer <ключ шлюза>' -d '$GATEWAY_NORMAL'"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' -X POST "$BASE_URL/api/gateway/readings" \
    -H "Authorization: Bearer $GATEWAY_TOKEN" -H 'Content-Type: application/json' -d "$GATEWAY_NORMAL")
output
http_status
[ "$STATUS" = 200 ] || exit 1
GATEWAY_NORMAL_ID=$(jq -er '.id' "$RESPONSE")
check_json '.chamberId == $id' 'Измерение попало не в камеру ключа' --argjson id "$CHAMBER_ID"

echo 'Повторное измерение возвращает прежний ID'
command_line "curl -sS -X POST $BASE_URL/api/gateway/readings -H 'Authorization: Bearer <ключ шлюза>' -d '$GATEWAY_NORMAL'"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' -X POST "$BASE_URL/api/gateway/readings" \
    -H "Authorization: Bearer $GATEWAY_TOKEN" -H 'Content-Type: application/json' -d "$GATEWAY_NORMAL")
output
http_status
[ "$STATUS" = 200 ] || exit 1
check_json '.id == $id' 'Дубликат измерения' --argjson id "$GATEWAY_NORMAL_ID"

echo 'Выбирать камеру через JSON запрещено: 400'
GATEWAY_OTHER_CAMERA=$(jq -c '.chamberId = 99999999' <<< "$GATEWAY_NORMAL")
command_line "curl -sS -X POST $BASE_URL/api/gateway/readings -H 'Authorization: Bearer <ключ шлюза>' -d '$GATEWAY_OTHER_CAMERA'"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' -X POST "$BASE_URL/api/gateway/readings" \
    -H "Authorization: Bearer $GATEWAY_TOKEN" -H 'Content-Type: application/json' -d "$GATEWAY_OTHER_CAMERA")
output
http_status
[ "$STATUS" = 400 ] || exit 1

echo 'Ключ шлюза не даёт смотреть климат: 401'
command_line "curl -sS $BASE_URL/api/engineer/chambers -H 'Authorization: Bearer <ключ шлюза>'"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' "$BASE_URL/api/engineer/chambers" -H "Authorization: Bearer $GATEWAY_TOKEN")
output
http_status
[ "$STATUS" = 401 ] || exit 1

echo 'Первое плохое измерение создаёт уведомление инженерам'
command_line "curl -sS -X POST $BASE_URL/api/gateway/readings -H 'Authorization: Bearer <ключ шлюза>' -d '$GATEWAY_BAD'"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' -X POST "$BASE_URL/api/gateway/readings" \
    -H "Authorization: Bearer $GATEWAY_TOKEN" -H 'Content-Type: application/json' -d "$GATEWAY_BAD")
output
http_status
[ "$STATUS" = 200 ] || exit 1
GATEWAY_BAD_ID=$(jq -er '.id' "$RESPONSE")

echo 'Следующее плохое измерение также создаёт уведомление'
command_line "curl -sS -X POST $BASE_URL/api/gateway/readings -H 'Authorization: Bearer <ключ шлюза>' -d '$GATEWAY_BAD_AGAIN'"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' -X POST "$BASE_URL/api/gateway/readings" \
    -H "Authorization: Bearer $GATEWAY_TOKEN" -H 'Content-Type: application/json' -d "$GATEWAY_BAD_AGAIN")
output
http_status
[ "$STATUS" = 200 ] || exit 1
GATEWAY_LAST_BAD_ID=$(jq -er '.id' "$RESPONSE")

command_line "curl -sS $BASE_URL/api/notifications -b <engineer-cookies>"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' "$BASE_URL/api/notifications" -b "$ENGINEER_COOKIES")
output
http_status
[ "$STATUS" = 200 ] || exit 1
check_json '[.items[] | select(.readingId == $first or .readingId == $second)] | length == 2 and all(.[]; .parameter == "BOTH")' \
    'Ожидалось по уведомлению на каждое плохое измерение' --argjson first "$GATEWAY_BAD_ID" --argjson second "$GATEWAY_LAST_BAD_ID"
check_json 'all(.items[]; .readingId != $id)' 'Нормальное измерение вызвало тревогу' --argjson id "$GATEWAY_NORMAL_ID"

echo 'Инженер не может удалить ключ: 403'
command_line "curl -sS -X DELETE $BASE_URL/api/admin/gateway-keys/$GATEWAY_KEY_ID -b <engineer-cookies>"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' -X DELETE "$BASE_URL/api/admin/gateway-keys/$GATEWAY_KEY_ID" \
    -b "$ENGINEER_COOKIES" -H "$ENGINEER_CSRF_HEADER: $ENGINEER_CSRF_TOKEN")
output
http_status
[ "$STATUS" = 403 ] || exit 1

echo 'Администратор видит только описание ключа; ни ключа, ни хеша в списке нет'
command_line "curl -sS $BASE_URL/api/admin/chambers/$CHAMBER_ID/gateway-keys -b <admin-cookies>"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' "$BASE_URL/api/admin/chambers/$CHAMBER_ID/gateway-keys" -b "$ADMIN_COOKIES")
output
http_status
[ "$STATUS" = 200 ] || exit 1
check_json 'any(.[]; .id == $id) and all(.[]; (has("token") | not) and (has("keyHash") | not))' 'Ключ отсутствует или раскрыт в списке' --argjson id "$GATEWAY_KEY_ID"

echo 'Администратор просто удаляет ключ из БД: 204'
command_line "curl -sS -X DELETE $BASE_URL/api/admin/gateway-keys/$GATEWAY_KEY_ID -b <admin-cookies>"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' -X DELETE "$BASE_URL/api/admin/gateway-keys/$GATEWAY_KEY_ID" \
    -b "$ADMIN_COOKIES" -H "$ADMIN_CSRF_HEADER: $ADMIN_CSRF_TOKEN")
http_status
[ "$STATUS" = 204 ] || exit 1

echo 'Удалённый ключ больше не работает: 401'
command_line "curl -sS -X POST $BASE_URL/api/gateway/readings -H 'Authorization: Bearer <удалённый ключ>' -d '$GATEWAY_NORMAL'"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' -X POST "$BASE_URL/api/gateway/readings" \
    -H "Authorization: Bearer $GATEWAY_TOKEN" -H 'Content-Type: application/json' -d "$GATEWAY_NORMAL")
output
http_status
[ "$STATUS" = 401 ] || exit 1
unset GATEWAY_TOKEN

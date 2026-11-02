#!/usr/bin/env bash
# Проверяем, что другой депозитор не видит заявку и не может выбрать чужие коробки.

OTHER_COOKIES="$TEMP_DIR/withdrawal-other-cookies.txt"

echo
echo '93. Получаем CSRF для другого депозитора'
command_line "curl -sS -X GET $BASE_URL/api/auth/csrf -b <other-cookies>"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' \
    -X GET "$BASE_URL/api/auth/csrf" \
    -b "$OTHER_COOKIES" -c "$OTHER_COOKIES")
output
http_status
[ "$STATUS" = '200' ] || { echo 'ОШИБКА: ожидался HTTP 200' >&2; exit 1; }
OTHER_CSRF_HEADER=$(jq -er '.headerName' "$RESPONSE")
OTHER_CSRF_TOKEN=$(jq -er '.token' "$RESPONSE")

echo
echo '94. Входим seed-депозитором'
WITHDRAWAL_BODY='{"email":"vir@example.org","password":"Demo123!"}'
command_line "curl -sS -X POST $BASE_URL/api/auth/login -b <other-cookies> -H 'Content-Type: application/json' -d '$WITHDRAWAL_BODY'"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' \
    -X POST "$BASE_URL/api/auth/login" \
    -b "$OTHER_COOKIES" -c "$OTHER_COOKIES" \
    -H "$OTHER_CSRF_HEADER: $OTHER_CSRF_TOKEN" \
    -H 'Content-Type: application/json' -d "$WITHDRAWAL_BODY")
output
http_status
[ "$STATUS" = '200' ] || { echo 'ОШИБКА: ожидался HTTP 200' >&2; exit 1; }

echo
echo '95. Обновляем CSRF после входа'
command_line "curl -sS -X GET $BASE_URL/api/auth/csrf -b <other-cookies>"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' \
    -X GET "$BASE_URL/api/auth/csrf" \
    -b "$OTHER_COOKIES" -c "$OTHER_COOKIES")
output
http_status
[ "$STATUS" = '200' ] || { echo 'ОШИБКА: ожидался HTTP 200' >&2; exit 1; }
OTHER_CSRF_HEADER=$(jq -er '.headerName' "$RESPONSE")
OTHER_CSRF_TOKEN=$(jq -er '.token' "$RESPONSE")

echo
echo '96. Чужая заявка недоступна'
command_line "curl -sS -X GET $BASE_URL/api/depositors/me/withdrawal-requests/$WITHDRAWAL_ID -b <other-cookies>"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' \
    -X GET "$BASE_URL/api/depositors/me/withdrawal-requests/$WITHDRAWAL_ID" \
    -b "$OTHER_COOKIES" -c "$OTHER_COOKIES")
output
http_status
[ "$STATUS" = '404' ] || { echo 'ОШИБКА: ожидался HTTP 404' >&2; exit 1; }

echo
echo '97. Нельзя подать заявку от имени чужой партии'
WITHDRAWAL_BODY="$WITHDRAWAL_JSON"
command_line "curl -sS -X POST $BASE_URL/api/depositors/me/withdrawal-requests -b <other-cookies> -H 'Content-Type: application/json' -d '$WITHDRAWAL_BODY'"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' \
    -X POST "$BASE_URL/api/depositors/me/withdrawal-requests" \
    -b "$OTHER_COOKIES" -c "$OTHER_COOKIES" \
    -H "$OTHER_CSRF_HEADER: $OTHER_CSRF_TOKEN" \
    -H 'Content-Type: application/json' -d "$WITHDRAWAL_BODY")
output
http_status
[ "$STATUS" = '404' ] || { echo 'ОШИБКА: ожидался HTTP 404' >&2; exit 1; }

echo
echo '98. Нельзя включить чужую коробку в свою партию'
WITHDRAWAL_BODY="$(jq -c '.batchId = 1' <<< "$WITHDRAWAL_JSON")"
command_line "curl -sS -X POST $BASE_URL/api/depositors/me/withdrawal-requests -b <other-cookies> -H 'Content-Type: application/json' -d '$WITHDRAWAL_BODY'"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' \
    -X POST "$BASE_URL/api/depositors/me/withdrawal-requests" \
    -b "$OTHER_COOKIES" -c "$OTHER_COOKIES" \
    -H "$OTHER_CSRF_HEADER: $OTHER_CSRF_TOKEN" \
    -H 'Content-Type: application/json' -d "$WITHDRAWAL_BODY")
output
http_status
[ "$STATUS" = '404' ] || { echo 'ОШИБКА: ожидался HTTP 404' >&2; exit 1; }

echo
echo '99. Закрываем сессию другого депозитора'
command_line "curl -sS -X POST $BASE_URL/api/auth/logout -b <other-cookies>"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' \
    -X POST "$BASE_URL/api/auth/logout" \
    -b "$OTHER_COOKIES" -c "$OTHER_COOKIES" \
    -H "$OTHER_CSRF_HEADER: $OTHER_CSRF_TOKEN")
output
http_status
[ "$STATUS" = '204' ] || { echo 'ОШИБКА: ожидался HTTP 204' >&2; exit 1; }

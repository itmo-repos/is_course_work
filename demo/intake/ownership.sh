#!/usr/bin/env bash
# Часть общего сценария: запускается через demo/check-backend.sh.

OTHER_COOKIES="$TEMP_DIR/other-depositor-cookies.txt"

echo
echo 'Проверяем доступ другого депозитора: получаем CSRF'
command_line "curl -sS -X GET $BASE_URL/api/auth/csrf"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' \
    -X GET "$BASE_URL/api/auth/csrf" -c "$OTHER_COOKIES")
output
http_status
[ "$STATUS" = '200' ] || { echo 'ОШИБКА: ожидался HTTP 200' >&2; exit 1; }
OTHER_CSRF_HEADER=$(jq -er '.headerName' "$RESPONSE")
OTHER_CSRF_TOKEN=$(jq -er '.token' "$RESPONSE")

echo
echo 'Входим существующим депозитором из тестовых данных'
command_line "curl -sS -X POST $BASE_URL/api/auth/login -b <cookies>"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' \
    -X POST "$BASE_URL/api/auth/login" -c "$OTHER_COOKIES" \
    -b "$OTHER_COOKIES" \
    -H "$OTHER_CSRF_HEADER: $OTHER_CSRF_TOKEN" \
    -H 'Content-Type: application/json' \
    -d '{"email":"vir@example.org","password":"Demo123!"}')
output
http_status
[ "$STATUS" = '200' ] || { echo 'ОШИБКА: ожидался HTTP 200' >&2; exit 1; }

echo
echo 'Чужие коробки с координатами недоступны: HTTP 404'
command_line "curl -sS -X GET $BASE_URL/api/depositors/me/batches/$BATCH_ID/boxes -b <cookies>"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' \
    -X GET "$BASE_URL/api/depositors/me/batches/$BATCH_ID/boxes" \
    -b "$OTHER_COOKIES")
output
http_status
[ "$STATUS" = '404' ] || { echo 'ОШИБКА: ожидался HTTP 404' >&2; exit 1; }

echo
echo 'Чужой паспорт партии тоже недоступен: HTTP 404'
command_line "curl -sS -X GET $BASE_URL/api/depositors/me/batches/$BATCH_ID -b <cookies>"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' \
    -X GET "$BASE_URL/api/depositors/me/batches/$BATCH_ID" \
    -b "$OTHER_COOKIES")
output
http_status
[ "$STATUS" = '404' ] || { echo 'ОШИБКА: ожидался HTTP 404' >&2; exit 1; }

echo
echo 'Депозитору полная карта камеры недоступна: HTTP 403'
command_line "curl -sS $BASE_URL/api/curator/chambers/$CHAMBER_ID/places -b <other-cookies>"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' \
    "$BASE_URL/api/curator/chambers/$CHAMBER_ID/places" -b "$OTHER_COOKIES")
output
http_status
[ "$STATUS" = '403' ] || { echo 'ОШИБКА: ожидался HTTP 403' >&2; exit 1; }

echo
echo 'Обновляем CSRF перед выходом другого депозитора'
command_line "curl -sS -X GET $BASE_URL/api/auth/csrf -b <cookies>"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' \
    -X GET "$BASE_URL/api/auth/csrf" \
    -b "$OTHER_COOKIES")
output
http_status
[ "$STATUS" = '200' ] || { echo 'ОШИБКА: ожидался HTTP 200' >&2; exit 1; }
OTHER_CSRF_HEADER=$(jq -er '.headerName' "$RESPONSE")
OTHER_CSRF_TOKEN=$(jq -er '.token' "$RESPONSE")

echo
echo 'Закрываем сессию другого депозитора'
command_line "curl -sS -X POST $BASE_URL/api/auth/logout -b <cookies>"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' \
    -X POST "$BASE_URL/api/auth/logout" \
    -b "$OTHER_COOKIES" \
    -H "$OTHER_CSRF_HEADER: $OTHER_CSRF_TOKEN")
output
http_status
[ "$STATUS" = '204' ] || { echo 'ОШИБКА: ожидался HTTP 204' >&2; exit 1; }

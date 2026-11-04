#!/usr/bin/env bash
# Проверка после завершения приёмки.

echo 'Завершение приёмки автоматически погасило временный пропуск куратора'
command_line "curl -sS $BASE_URL/api/security/passes/$INTAKE_PASS_ID -b <security-cookies>"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' -b "$SECURITY_COOKIES" \
    "$BASE_URL/api/security/passes/$INTAKE_PASS_ID")
output
http_status
[ "$STATUS" = 200 ] || exit 1
check_json '.status == "EXPIRED"' 'Пропуск закрытой приёмки остался активным'

command_line "curl -sS -X POST $BASE_URL/api/security/access-events -b <security-cookies> -d '{\"passCode\":\"<код из QR скрыт>\",\"chamberId\":$CHAMBER_ID,\"direction\":\"IN\"}'"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' -b "$SECURITY_COOKIES" \
    -X POST "$BASE_URL/api/security/access-events" -H "$SECURITY_CSRF_HEADER: $SECURITY_CSRF_TOKEN" \
    -H 'Content-Type: application/json' \
    -d "{\"passCode\":\"$INTAKE_PASS_CODE\",\"chamberId\":$CHAMBER_ID,\"direction\":\"IN\"}")
output
http_status
[ "$STATUS" = 409 ] || exit 1

command_line "curl -sS -X POST $BASE_URL/api/auth/logout -b <security-cookies> -H '$SECURITY_CSRF_HEADER: <csrf-токен>'"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' -b "$SECURITY_COOKIES" -c "$SECURITY_COOKIES" \
    -X POST "$BASE_URL/api/auth/logout" -H "$SECURITY_CSRF_HEADER: $SECURITY_CSRF_TOKEN")
http_status
[ "$STATUS" = 204 ] || exit 1

#!/usr/bin/env bash
# Часть общего сценария: запускается через demo/check-backend.sh.

echo '55. Выходим и проверяем отказ без авторизации: ожидаем HTTP 401'
command_line "curl -sS -X POST $BASE_URL/api/auth/logout -H '$APPLICANT_CSRF_HEADER: <csrf-токен>' -b <applicant-cookies>"
STATUS=$(curl -sS -b "$APPLICANT_COOKIES" -c "$APPLICANT_COOKIES" -o "$RESPONSE" -w '%{http_code}' \
    -X POST "$BASE_URL/api/auth/logout" -H "$APPLICANT_CSRF_HEADER: $APPLICANT_CSRF_TOKEN")
http_status
[ "$STATUS" = '204' ] || { echo 'ОШИБКА: выход не выполнен' >&2; exit 1; }
command_line "curl -sS -b <applicant-cookies> $BASE_URL/api/depositors/me"
STATUS=$(curl -sS -b "$APPLICANT_COOKIES" -c "$APPLICANT_COOKIES" -o "$RESPONSE" \
    -w '%{http_code}' "$BASE_URL/api/depositors/me")
output
http_status
[ "$STATUS" = '401' ] || { echo 'ОШИБКА: сессия всё ещё активна' >&2; exit 1; }

command_line "curl -sS -X POST $BASE_URL/api/auth/logout -H '$ADMIN_CSRF_HEADER: <csrf-токен>' -b <admin-cookies>"
STATUS=$(curl -sS -b "$ADMIN_COOKIES" -c "$ADMIN_COOKIES" -o "$RESPONSE" -w '%{http_code}' \
    -X POST "$BASE_URL/api/auth/logout" -H "$ADMIN_CSRF_HEADER: $ADMIN_CSRF_TOKEN")
http_status
[ "$STATUS" = '204' ] || { echo 'ОШИБКА: не удалось закрыть сессию администратора' >&2; exit 1; }

echo

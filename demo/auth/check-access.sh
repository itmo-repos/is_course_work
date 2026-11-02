#!/usr/bin/env bash
# Часть общего сценария: запускается через demo/check-backend.sh.

echo '1. Проверяем запрос профиля без авторизации: ожидаем HTTP 401'
command_line "curl -sS $BASE_URL/api/auth/me"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' "$BASE_URL/api/auth/me")
output
http_status
[ "$STATUS" = '401' ] || { echo 'ОШИБКА: ожидался HTTP 401' >&2; exit 1; }

echo

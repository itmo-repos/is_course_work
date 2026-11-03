#!/usr/bin/env bash
# Часть общего сценария: запускается через demo/check-backend.sh.

echo 'Приём, размещение и изъятие прошли с выключенным климат-контролем. История осталась доступна.'
command_line "curl -sS -b <engineer-cookies> $BASE_URL/api/engineer/chambers/$CHAMBER_ID"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' -b "$ENGINEER_COOKIES" "$BASE_URL/api/engineer/chambers/$CHAMBER_ID")
output
http_status
[ "$STATUS" = 200 ] || exit 1
check_json '(.climateControlled | not) and .latestReading == $latest' 'Изменились последние показания' --argjson latest "$CLIMATE_LATEST_READING"

echo 'Возвращаем настройки камеры, которые были до климатического демо'
command_line "curl -sS -X PUT $BASE_URL/api/admin/chambers/$CHAMBER_ID/settings -b <admin-cookies> -d '$CLIMATE_ORIGINAL_SETTINGS'"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' -X PUT "$BASE_URL/api/admin/chambers/$CHAMBER_ID/settings" \
    -b "$ADMIN_COOKIES" -H "$ADMIN_CSRF_HEADER: $ADMIN_CSRF_TOKEN" -H 'Content-Type: application/json' -d "$CLIMATE_ORIGINAL_SETTINGS")
output
http_status
[ "$STATUS" = 200 ] || exit 1

echo 'Закрываем сессию инженера'
command_line "curl -sS -X POST $BASE_URL/api/auth/logout -b <engineer-cookies> -H '$ENGINEER_CSRF_HEADER: <csrf-токен>'"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' -X POST "$BASE_URL/api/auth/logout" \
    -b "$ENGINEER_COOKIES" -H "$ENGINEER_CSRF_HEADER: $ENGINEER_CSRF_TOKEN")
http_status
[ "$STATUS" = 204 ] || exit 1

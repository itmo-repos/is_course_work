#!/usr/bin/env bash
# Часть общего сценария: запускается через demo/check-backend.sh.

ENGINEER_COOKIES="$TEMP_DIR/engineer-cookies.txt"
echo 'Климат. Входим инженером: m.serg@example.com'
command_line "curl -sS -c <engineer-cookies> $BASE_URL/api/auth/csrf"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' -c "$ENGINEER_COOKIES" "$BASE_URL/api/auth/csrf")
output
http_status
[ "$STATUS" = 200 ] || exit 1
ENGINEER_CSRF_HEADER=$(jq -er '.headerName' "$RESPONSE")
ENGINEER_CSRF_TOKEN=$(jq -er '.token' "$RESPONSE")
command_line "curl -sS -X POST $BASE_URL/api/auth/login -b <engineer-cookies> -H 'Content-Type: application/json' -d '{\"email\":\"m.serg@example.com\",\"password\":\"<скрыт>\"}'"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' -b "$ENGINEER_COOKIES" -c "$ENGINEER_COOKIES" \
    -X POST "$BASE_URL/api/auth/login" -H "$ENGINEER_CSRF_HEADER: $ENGINEER_CSRF_TOKEN" \
    -H 'Content-Type: application/json' -d '{"email":"m.serg@example.com","password":"Demo123!"}')
output
http_status
[ "$STATUS" = 200 ] || exit 1

echo 'Получаем новый CSRF-токен после входа инженера'
command_line "curl -sS -b <engineer-cookies> $BASE_URL/api/auth/csrf"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' -b "$ENGINEER_COOKIES" "$BASE_URL/api/auth/csrf")
output
http_status
[ "$STATUS" = 200 ] || exit 1
ENGINEER_CSRF_HEADER=$(jq -er '.headerName' "$RESPONSE")
ENGINEER_CSRF_TOKEN=$(jq -er '.token' "$RESPONSE")

echo 'Смотрим климат всех камер, включая выключенные и законсервированные'
command_line "curl -sS -b <engineer-cookies> $BASE_URL/api/engineer/chambers"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' -b "$ENGINEER_COOKIES" "$BASE_URL/api/engineer/chambers")
output
http_status
[ "$STATUS" = 200 ] || exit 1
CLIMATE_ORIGINAL_SETTINGS=$(jq -ce --argjson id "$CHAMBER_ID" '.[] | select(.id == $id) | {status,climateControlled,minTemperature,maxTemperature,minHumidity,maxHumidity}' "$RESPONSE")
CLIMATE_SETTINGS='{"status":"ACTIVE","climateControlled":true,"minTemperature":-20,"maxTemperature":-16,"minHumidity":20,"maxHumidity":30}'

echo 'Администратор задаёт допустимые границы выбранной камеры'
command_line "curl -sS -X PUT $BASE_URL/api/admin/chambers/$CHAMBER_ID/settings -b <admin-cookies> -H 'Content-Type: application/json' -d '$CLIMATE_SETTINGS'"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' -X PUT "$BASE_URL/api/admin/chambers/$CHAMBER_ID/settings" \
    -b "$ADMIN_COOKIES" -H "$ADMIN_CSRF_HEADER: $ADMIN_CSRF_TOKEN" -H 'Content-Type: application/json' -d "$CLIMATE_SETTINGS")
output
http_status
[ "$STATUS" = 200 ] || exit 1
check_json '.climateControlled and .minTemperature == -20 and .maxHumidity == 30' 'Настройки не сохранились'

echo 'Инженер может смотреть климат, но менять настройки администратора не может: 403'
command_line "curl -sS -X PUT $BASE_URL/api/admin/chambers/$CHAMBER_ID/settings -b <engineer-cookies> -d '$CLIMATE_SETTINGS'"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' -X PUT "$BASE_URL/api/admin/chambers/$CHAMBER_ID/settings" \
    -b "$ENGINEER_COOKIES" -H "$ENGINEER_CSRF_HEADER: $ENGINEER_CSRF_TOKEN" -H 'Content-Type: application/json' -d "$CLIMATE_SETTINGS")
output
http_status
[ "$STATUS" = 403 ] || exit 1

CLIMATE_FROM='2000-01-01T00:00:00Z'
CLIMATE_TO=$(date -u +%Y-%m-%dT%H:%M:%SZ)

echo 'Просматриваем последние показания камеры; без данных latestReading будет null'
command_line "curl -sS -b <engineer-cookies> $BASE_URL/api/engineer/chambers/$CHAMBER_ID"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' -b "$ENGINEER_COOKIES" "$BASE_URL/api/engineer/chambers/$CHAMBER_ID")
output
http_status
[ "$STATUS" = 200 ] || exit 1
CLIMATE_LATEST_READING=$(jq -c '.latestReading' "$RESPONSE")

echo 'Смотрим историю измерений за период'
command_line "curl -sS -G $BASE_URL/api/engineer/chambers/$CHAMBER_ID/readings -b <engineer-cookies> --data-urlencode 'from=$CLIMATE_FROM' --data-urlencode 'to=$CLIMATE_TO' --data-urlencode size=2"
STATUS=$(curl -sS -G -o "$RESPONSE" -w '%{http_code}' "$BASE_URL/api/engineer/chambers/$CHAMBER_ID/readings" \
    -b "$ENGINEER_COOKIES" --data-urlencode "from=$CLIMATE_FROM" --data-urlencode "to=$CLIMATE_TO" --data-urlencode size=2)
output
http_status
[ "$STATUS" = 200 ] || exit 1
check_json '.total >= 0 and (.items | length) <= 2 and .page == 0' 'Неверная история или пагинация'

echo 'Скачиваем историю в CSV; при отсутствии данных останется заголовок'
command_line "curl -sS -G $BASE_URL/api/engineer/chambers/$CHAMBER_ID/readings.csv -b <engineer-cookies> --data-urlencode 'from=$CLIMATE_FROM' --data-urlencode 'to=$CLIMATE_TO'"
STATUS=$(curl -sS -G -o "$RESPONSE" -w '%{http_code}' "$BASE_URL/api/engineer/chambers/$CHAMBER_ID/readings.csv" \
    -b "$ENGINEER_COOKIES" --data-urlencode "from=$CLIMATE_FROM" --data-urlencode "to=$CLIMATE_TO")
output
http_status
[ "$STATUS" = 200 ] || exit 1
grep -q 'chamberId,measuredAt,temperature,humidity' "$RESPONSE" || { echo 'ОШИБКА: неверный CSV'; exit 1; }

echo 'Смотрим личные уведомления инженера'
command_line "curl -sS -b <engineer-cookies> '$BASE_URL/api/notifications?unreadOnly=true'"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' -b "$ENGINEER_COOKIES" "$BASE_URL/api/notifications?unreadOnly=true")
output
http_status
[ "$STATUS" = 200 ] || exit 1
check_json 'all(.items[]; (.read | not))' 'Среди непрочитанных есть прочитанное уведомление'

echo 'Депозитору климат недоступен: 403'
command_line "curl -sS -b <applicant-cookies> $BASE_URL/api/engineer/chambers"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' -b "$APPLICANT_COOKIES" "$BASE_URL/api/engineer/chambers")
output
http_status
[ "$STATUS" = 403 ] || exit 1

echo 'Выключаем климат-контроль; следующий приём, размещение и изъятие должны работать'
DISABLED_CLIMATE_SETTINGS=$(jq -c '.climateControlled = false' <<< "$CLIMATE_SETTINGS")
command_line "curl -sS -X PUT $BASE_URL/api/admin/chambers/$CHAMBER_ID/settings -b <admin-cookies> -d '$DISABLED_CLIMATE_SETTINGS'"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' -X PUT "$BASE_URL/api/admin/chambers/$CHAMBER_ID/settings" \
    -b "$ADMIN_COOKIES" -H "$ADMIN_CSRF_HEADER: $ADMIN_CSRF_TOKEN" -H 'Content-Type: application/json' -d "$DISABLED_CLIMATE_SETTINGS")
output
http_status
[ "$STATUS" = 200 ] || exit 1
check_json '(.climateControlled | not) and .status == "ACTIVE"' 'Климат не выключен'

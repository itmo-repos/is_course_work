#!/usr/bin/env bash
# Часть общего сценария: запускается через demo/check-backend.sh.

echo 'Входим сотрудником охраны (пароль скрыт)'
SECURITY_COOKIES="$TEMP_DIR/security-cookies.txt"
command_line "curl -sS -c <security-cookies> $BASE_URL/api/auth/csrf"
curl -fsS -c "$SECURITY_COOKIES" "$BASE_URL/api/auth/csrf" > "$RESPONSE"
SECURITY_CSRF_HEADER=$(jq -er '.headerName' "$RESPONSE")
SECURITY_CSRF_TOKEN=$(jq -er '.token' "$RESPONSE")
command_line "curl -sS -X POST $BASE_URL/api/auth/login -b <security-cookies> -d '<email охраны; пароль скрыт>'"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' -b "$SECURITY_COOKIES" -c "$SECURITY_COOKIES" \
    -X POST "$BASE_URL/api/auth/login" -H "$SECURITY_CSRF_HEADER: $SECURITY_CSRF_TOKEN" \
    -H 'Content-Type: application/json' -d '{"email":"p.petrova@example.com","password":"Demo123!"}')
output
http_status
[ "$STATUS" = 200 ] || exit 1
command_line "curl -sS $BASE_URL/api/auth/csrf -b <security-cookies>"
curl -fsS -b "$SECURITY_COOKIES" -c "$SECURITY_COOKIES" "$BASE_URL/api/auth/csrf" > "$RESPONSE"
SECURITY_CSRF_HEADER=$(jq -er '.headerName' "$RESPONSE")
SECURITY_CSRF_TOKEN=$(jq -er '.token' "$RESPONSE")

echo
echo 'Куратор получает автоматически выданный на дату приёмки пропуск'
command_line "curl -sS $BASE_URL/api/curator/intake-sessions/$SESSION_ID/passes -b <admin-cookies>"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' -b "$ADMIN_COOKIES" \
    "$BASE_URL/api/curator/intake-sessions/$SESSION_ID/passes")
output
http_status
[ "$STATUS" = 200 ] || exit 1
check_json 'length == 1 and .[0].status == "ACTIVE" and .[0].employeeId == 1 and .[0].chamberIds == [$chamber]' \
    'Не выдан пропуск куратору в камеру сессии' --argjson chamber "$CHAMBER_ID"
check_json '.[0].id == $id and all(.[]; has("code") == false and has("codeHash") == false and has("qrSvg") == false)' \
    'При повторном чтении не должны возвращаться секрет или QR' --argjson id "$INTAKE_PASS_ID"

echo
echo 'Охрана регистрирует вход куратора в разрешённую камеру'
command_line "curl -sS -X POST $BASE_URL/api/security/access-events -b <security-cookies> -d '{\"passCode\":\"<код из QR скрыт>\",\"chamberId\":$CHAMBER_ID,\"direction\":\"IN\",\"comment\":\"Приём партии\"}'"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' -b "$SECURITY_COOKIES" \
    -X POST "$BASE_URL/api/security/access-events" -H "$SECURITY_CSRF_HEADER: $SECURITY_CSRF_TOKEN" \
    -H 'Content-Type: application/json' \
    -d "{\"passCode\":\"$INTAKE_PASS_CODE\",\"chamberId\":$CHAMBER_ID,\"direction\":\"IN\",\"comment\":\"Приём партии\"}")
output
http_status
[ "$STATUS" = 201 ] || exit 1
check_json '.employeeId == 1 and .registeredBy == 6 and .direction == "IN" and .occurredAt != null' 'Неверные данные прохода'

echo
echo 'В другую камеру пропуск не разрешает проход: HTTP 409'
OTHER_CHAMBER_ID=2
[ "$CHAMBER_ID" != 2 ] || OTHER_CHAMBER_ID=1
command_line "curl -sS -X POST $BASE_URL/api/security/access-events -b <security-cookies> -d '{\"passCode\":\"<код из QR скрыт>\",\"chamberId\":$OTHER_CHAMBER_ID,\"direction\":\"IN\"}'"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' -b "$SECURITY_COOKIES" \
    -X POST "$BASE_URL/api/security/access-events" -H "$SECURITY_CSRF_HEADER: $SECURITY_CSRF_TOKEN" \
    -H 'Content-Type: application/json' \
    -d "{\"passCode\":\"$INTAKE_PASS_CODE\",\"chamberId\":$OTHER_CHAMBER_ID,\"direction\":\"IN\"}")
output
http_status
[ "$STATUS" = 409 ] || exit 1

echo
echo 'Фиксируем выход куратора'
command_line "curl -sS -X POST $BASE_URL/api/security/access-events -b <security-cookies> -d '{\"passCode\":\"<код из QR скрыт>\",\"chamberId\":$CHAMBER_ID,\"direction\":\"OUT\"}'"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' -b "$SECURITY_COOKIES" \
    -X POST "$BASE_URL/api/security/access-events" -H "$SECURITY_CSRF_HEADER: $SECURITY_CSRF_TOKEN" \
    -H 'Content-Type: application/json' \
    -d "{\"passCode\":\"$INTAKE_PASS_CODE\",\"chamberId\":$CHAMBER_ID,\"direction\":\"OUT\"}")
output
http_status
[ "$STATUS" = 201 ] || exit 1

echo
echo 'Выдаём гостевой пропуск без привязки к сотруднику'
PASS_FROM=$(date -u -d '1 minute ago' +%Y-%m-%dT%H:%M:%SZ)
PASS_TO=$(date -u -d '1 hour' +%Y-%m-%dT%H:%M:%SZ)
command_line "curl -sS -X POST $BASE_URL/api/security/passes -b <security-cookies> -d '{\"validFrom\":\"$PASS_FROM\",\"validTo\":\"$PASS_TO\",\"chamberIds\":[$CHAMBER_ID],\"comment\":\"Посещение подрядчика\"}'"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' -b "$SECURITY_COOKIES" \
    -X POST "$BASE_URL/api/security/passes" -H "$SECURITY_CSRF_HEADER: $SECURITY_CSRF_TOKEN" \
    -H 'Content-Type: application/json' \
    -d "{\"validFrom\":\"$PASS_FROM\",\"validTo\":\"$PASS_TO\",\"chamberIds\":[$CHAMBER_ID],\"comment\":\"Посещение подрядчика\"}")
output
http_status
[ "$STATUS" = 201 ] || exit 1
check_json '.pass.employeeId == null and .pass.status == "ACTIVE" and .pass.issuedBy == 6 and (.code | test("^[A-Za-z0-9_-]{43}$"))' 'Гостевой пропуск не создан'
GUEST_PASS_ID=$(jq -er '.pass.id' "$RESPONSE")
GUEST_PASS_CODE=$(jq -er '.code' "$RESPONSE")
jq -er '.qrSvg' "$RESPONSE" > "$TEMP_DIR/guest-pass.svg"

echo
echo 'Отзываем гостевой пропуск'
command_line "curl -sS -X POST $BASE_URL/api/security/passes/$GUEST_PASS_ID/revoke -b <security-cookies>"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' -b "$SECURITY_COOKIES" \
    -X POST "$BASE_URL/api/security/passes/$GUEST_PASS_ID/revoke" -H "$SECURITY_CSRF_HEADER: $SECURITY_CSRF_TOKEN")
output
http_status
[ "$STATUS" = 200 ] || exit 1
check_json '.status == "REVOKED" and .revokedBy == 6 and .revokedAt != null' 'Пропуск не отозван'

echo
echo 'Отозванный пропуск не позволяет зарегистрировать проход: HTTP 409'
command_line "curl -sS -X POST $BASE_URL/api/security/access-events -b <security-cookies> -d '{\"passCode\":\"<код из QR скрыт>\",\"chamberId\":$CHAMBER_ID,\"direction\":\"IN\"}'"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' -b "$SECURITY_COOKIES" \
    -X POST "$BASE_URL/api/security/access-events" -H "$SECURITY_CSRF_HEADER: $SECURITY_CSRF_TOKEN" \
    -H 'Content-Type: application/json' \
    -d "{\"passCode\":\"$GUEST_PASS_CODE\",\"chamberId\":$CHAMBER_ID,\"direction\":\"IN\"}")
output
http_status
[ "$STATUS" = 409 ] || exit 1

echo
echo 'В журнале по пропуску остались только два успешных прохода'
JOURNAL_FROM=$(date -u -d '1 day ago' +%Y-%m-%dT%H:%M:%SZ)
JOURNAL_TO=$(date -u -d '1 day' +%Y-%m-%dT%H:%M:%SZ)
command_line "curl -sS '$BASE_URL/api/security/access-events?passId=$INTAKE_PASS_ID&from=$JOURNAL_FROM&to=$JOURNAL_TO' -b <security-cookies>"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' -b "$SECURITY_COOKIES" \
    "$BASE_URL/api/security/access-events?passId=$INTAKE_PASS_ID&from=$JOURNAL_FROM&to=$JOURNAL_TO")
output
http_status
[ "$STATUS" = 200 ] || exit 1
check_json '.total == 2 and [.items[].direction] == ["OUT","IN"]' 'В журнале должны быть только успешные вход и выход'

echo
echo 'Депозитор не видит пропуска: HTTP 403'
command_line "curl -sS $BASE_URL/api/security/passes -b <applicant-cookies>"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' -b "$APPLICANT_COOKIES" "$BASE_URL/api/security/passes")
output
http_status
[ "$STATUS" = 403 ] || exit 1

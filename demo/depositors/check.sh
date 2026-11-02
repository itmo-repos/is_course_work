#!/usr/bin/env bash
# Часть общего сценария: запускается через demo/check-backend.sh.

echo '2. Получаем CSRF-токен для публичной заявки депозитора'
command_line "curl -sS -c <cookies> $BASE_URL/api/auth/csrf"
STATUS=$(curl -sS -c "$APPLICANT_COOKIES" -b "$APPLICANT_COOKIES" \
    -o "$RESPONSE" -w '%{http_code}' "$BASE_URL/api/auth/csrf")
output
http_status
[ "$STATUS" = '200' ] || { echo 'ОШИБКА: не удалось получить CSRF-токен' >&2; exit 1; }
APPLICANT_CSRF_HEADER=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["headerName"])' "$RESPONSE")
APPLICANT_CSRF_TOKEN=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["token"])' "$RESPONSE")

echo
echo '3. Отправляем заявку: ожидаем статус NEW_REQUEST и HTTP 201'
echo "Email новой демо-заявки: $APPLICANT_EMAIL"
APPLICATION_JSON=$(cat <<JSON
{"legalName":"Демо-организация $RUN_ID","countryCode":"RU","registrationNumber":"DEMO-$RUN_ID","legalAddress":"Россия, Санкт-Петербург, Университетская набережная, 7","contactPerson":"Демо Представитель","contactEmail":"$APPLICANT_EMAIL","contactPhone":"+78120000000","password":"$APPLICANT_PASSWORD"}
JSON
)
command_line "curl -sS -X POST $BASE_URL/api/depositors/applications -H '$APPLICANT_CSRF_HEADER: <csrf-токен>' -d '<данные заявки; пароль скрыт>'"
STATUS=$(printf '%s' "$APPLICATION_JSON" | curl -sS -b "$APPLICANT_COOKIES" -c "$APPLICANT_COOKIES" \
    -o "$RESPONSE" -w '%{http_code}' -X POST "$BASE_URL/api/depositors/applications" \
    -H 'Content-Type: application/json' -H "$APPLICANT_CSRF_HEADER: $APPLICANT_CSRF_TOKEN" \
    --data-binary @-)
output
http_status
[ "$STATUS" = '201' ] || { echo 'ОШИБКА: заявка не создана' >&2; exit 1; }
APPLICANT_ID=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["id"])' "$RESPONSE")
FINAL_STATUS=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["status"])' "$RESPONSE")
[ "$FINAL_STATUS" = 'NEW_REQUEST' ] || { echo "ОШИБКА: ожидался NEW_REQUEST, получен $FINAL_STATUS" >&2; exit 1; }

echo
echo '4. Получаем CSRF-токен и входим администратором'
command_line "curl -sS -c <admin-cookies> $BASE_URL/api/auth/csrf"
STATUS=$(curl -sS -c "$ADMIN_COOKIES" -b "$ADMIN_COOKIES" -o "$RESPONSE" \
    -w '%{http_code}' "$BASE_URL/api/auth/csrf")
output
http_status
[ "$STATUS" = '200' ] || { echo 'ОШИБКА: не удалось получить CSRF-токен администратора' >&2; exit 1; }
ADMIN_CSRF_HEADER=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["headerName"])' "$RESPONSE")
ADMIN_CSRF_TOKEN=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["token"])' "$RESPONSE")
command_line "curl -sS -X POST $BASE_URL/api/auth/login -H '$ADMIN_CSRF_HEADER: <csrf-токен>' -d '{\"email\":\"$ADMIN_EMAIL\",\"password\":\"<скрыт>\"}'"
STATUS=$(printf '{"email":"%s","password":"%s"}' "$ADMIN_EMAIL" "$ADMIN_PASSWORD" | \
    curl -sS -b "$ADMIN_COOKIES" -c "$ADMIN_COOKIES" -o "$RESPONSE" -w '%{http_code}' \
    -X POST "$BASE_URL/api/auth/login" -H 'Content-Type: application/json' \
    -H "$ADMIN_CSRF_HEADER: $ADMIN_CSRF_TOKEN" --data-binary @-)
output
http_status
[ "$STATUS" = '200' ] || { echo 'ОШИБКА: вход администратора не выполнен' >&2; exit 1; }

echo
echo '5. Получаем новый CSRF-токен после входа администратора'
command_line "curl -sS -b <admin-cookies> $BASE_URL/api/auth/csrf"
STATUS=$(curl -sS -b "$ADMIN_COOKIES" -c "$ADMIN_COOKIES" -o "$RESPONSE" \
    -w '%{http_code}' "$BASE_URL/api/auth/csrf")
output
http_status
[ "$STATUS" = '200' ] || { echo 'ОШИБКА: не удалось обновить CSRF-токен администратора' >&2; exit 1; }
ADMIN_CSRF_HEADER=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["headerName"])' "$RESPONSE")
ADMIN_CSRF_TOKEN=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["token"])' "$RESPONSE")

echo
echo '6. Администратор одобряет заявку: ожидаем AWAITING_CONTRACT'
command_line "curl -sS -X POST $BASE_URL/api/admin/depositors/$APPLICANT_ID/approve -b <admin-cookies>"
STATUS=$(curl -sS -b "$ADMIN_COOKIES" -c "$ADMIN_COOKIES" -o "$RESPONSE" -w '%{http_code}' \
    -X POST "$BASE_URL/api/admin/depositors/$APPLICANT_ID/approve" \
    -H "$ADMIN_CSRF_HEADER: $ADMIN_CSRF_TOKEN")
output
http_status
[ "$STATUS" = '200' ] || { echo 'ОШИБКА: администратор не одобрил заявку' >&2; exit 1; }
FINAL_STATUS=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["status"])' "$RESPONSE")
[ "$FINAL_STATUS" = 'AWAITING_CONTRACT' ] || { echo "ОШИБКА: ожидался AWAITING_CONTRACT, получен $FINAL_STATUS" >&2; exit 1; }

echo
echo '7. Входим депозитора'
command_line "curl -sS -X POST $BASE_URL/api/auth/login -H '$APPLICANT_CSRF_HEADER: <csrf-токен>' -d '{\"email\":\"$APPLICANT_EMAIL\",\"password\":\"<скрыт>\"}'"
STATUS=$(printf '{"email":"%s","password":"%s"}' "$APPLICANT_EMAIL" "$APPLICANT_PASSWORD" | \
    curl -sS -b "$APPLICANT_COOKIES" -c "$APPLICANT_COOKIES" -o "$RESPONSE" -w '%{http_code}' \
    -X POST "$BASE_URL/api/auth/login" -H 'Content-Type: application/json' \
    -H "$APPLICANT_CSRF_HEADER: $APPLICANT_CSRF_TOKEN" --data-binary @-)
output
http_status
[ "$STATUS" = '200' ] || { echo 'ОШИБКА: вход депозитора не выполнен' >&2; exit 1; }

command_line "curl -sS -b <applicant-cookies> $BASE_URL/api/depositors/me"
STATUS=$(curl -sS -b "$APPLICANT_COOKIES" -c "$APPLICANT_COOKIES" -o "$RESPONSE" \
    -w '%{http_code}' "$BASE_URL/api/depositors/me")
output
http_status
[ "$STATUS" = '200' ] || { echo 'ОШИБКА: не удалось прочитать статус заявки депозитора' >&2; exit 1; }
FINAL_STATUS=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["status"])' "$RESPONSE")
[ "$FINAL_STATUS" = 'AWAITING_CONTRACT' ] || { echo "ОШИБКА: ожидался AWAITING_CONTRACT, получен $FINAL_STATUS" >&2; exit 1; }

echo
echo '8. Получаем новый CSRF-токен после входа депозитора'
command_line "curl -sS -b <applicant-cookies> $BASE_URL/api/auth/csrf"
STATUS=$(curl -sS -b "$APPLICANT_COOKIES" -c "$APPLICANT_COOKIES" -o "$RESPONSE" \
    -w '%{http_code}' "$BASE_URL/api/auth/csrf")
output
http_status
[ "$STATUS" = '200' ] || { echo 'ОШИБКА: не удалось обновить CSRF-токен депозитора' >&2; exit 1; }
APPLICANT_CSRF_HEADER=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["headerName"])' "$RESPONSE")
APPLICANT_CSRF_TOKEN=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["token"])' "$RESPONSE")

echo
. "$DEMO_DIR/batches/check-pending.sh"

echo
echo '9. Скачиваем шаблон договора'
command_line "curl -sS -b <applicant-cookies> -o <contract.pdf> $BASE_URL/api/depositors/me/contract"
STATUS=$(curl -sS -b "$APPLICANT_COOKIES" -c "$APPLICANT_COOKIES" \
    -o "$GENERATED_CONTRACT" -w '%{http_code}' "$BASE_URL/api/depositors/me/contract")
printf "${OUTPUT_COLOR}PDF скачан, размер: %s байт${RESET_COLOR}\n" "$(wc -c < "$GENERATED_CONTRACT")"
http_status
[ "$STATUS" = '200' ] || { echo 'ОШИБКА: договор не скачан' >&2; exit 1; }
command_line 'cp <contract.pdf> <signed-contract.pdf> (демо-имитация подписанного скана)'
cp "$GENERATED_CONTRACT" "$SIGNED_SCAN"

echo
echo '10. Загружаем скан подписанного договора: ожидаем VERIFICATION'
command_line "curl -sS -X POST $BASE_URL/api/depositors/me/contract/scan -F file=@<signed-contract.pdf> -b <applicant-cookies>"
STATUS=$(curl -sS -b "$APPLICANT_COOKIES" -c "$APPLICANT_COOKIES" -o "$RESPONSE" -w '%{http_code}' \
    -X POST "$BASE_URL/api/depositors/me/contract/scan" \
    -H "$APPLICANT_CSRF_HEADER: $APPLICANT_CSRF_TOKEN" \
    -F "file=@$SIGNED_SCAN;type=application/pdf")
output
http_status
[ "$STATUS" = '200' ] || { echo 'ОШИБКА: скан не загружен' >&2; exit 1; }
FINAL_STATUS=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["status"])' "$RESPONSE")
[ "$FINAL_STATUS" = 'VERIFICATION' ] || { echo "ОШИБКА: ожидался VERIFICATION, получен $FINAL_STATUS" >&2; exit 1; }

echo
echo '11. Администратор проверяет скан и возвращает договор на переподписание'
command_line "curl -sS -b <admin-cookies> -o <admin-scan.pdf> $BASE_URL/api/admin/depositors/$APPLICANT_ID/contract/scan"
STATUS=$(curl -sS -b "$ADMIN_COOKIES" -c "$ADMIN_COOKIES" -o "$ADMIN_SCAN" \
    -w '%{http_code}' "$BASE_URL/api/admin/depositors/$APPLICANT_ID/contract/scan")
printf "${OUTPUT_COLOR}Скан получен, размер: %s байт${RESET_COLOR}\n" "$(wc -c < "$ADMIN_SCAN")"
http_status
[ "$STATUS" = '200' ] || { echo 'ОШИБКА: администратор не получил скан' >&2; exit 1; }

command_line "curl -sS -X POST $BASE_URL/api/admin/depositors/$APPLICANT_ID/contract/reject -d '{\"reason\":\"Нужна повторная подпись (демо)\"}'"
STATUS=$(curl -sS -b "$ADMIN_COOKIES" -c "$ADMIN_COOKIES" -o "$RESPONSE" -w '%{http_code}' \
    -X POST "$BASE_URL/api/admin/depositors/$APPLICANT_ID/contract/reject" \
    -H 'Content-Type: application/json' -H "$ADMIN_CSRF_HEADER: $ADMIN_CSRF_TOKEN" \
    -d '{"reason":"Нужна повторная подпись (демо)"}')
output
http_status
[ "$STATUS" = '200' ] || { echo 'ОШИБКА: отклонение договора не обработано' >&2; exit 1; }
FINAL_STATUS=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["status"])' "$RESPONSE")
[ "$FINAL_STATUS" = 'CONTRACT_REJECTED' ] || { echo "ОШИБКА: ожидался CONTRACT_REJECTED, получен $FINAL_STATUS" >&2; exit 1; }

command_line "curl -sS -X POST $BASE_URL/api/admin/depositors/$APPLICANT_ID/contract/return-for-signing"
STATUS=$(curl -sS -b "$ADMIN_COOKIES" -c "$ADMIN_COOKIES" -o "$RESPONSE" -w '%{http_code}' \
    -X POST "$BASE_URL/api/admin/depositors/$APPLICANT_ID/contract/return-for-signing" \
    -H "$ADMIN_CSRF_HEADER: $ADMIN_CSRF_TOKEN")
output
http_status
[ "$STATUS" = '200' ] || { echo 'ОШИБКА: договор не возвращен на переподписание' >&2; exit 1; }
FINAL_STATUS=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["status"])' "$RESPONSE")
[ "$FINAL_STATUS" = 'AWAITING_CONTRACT' ] || { echo "ОШИБКА: ожидался AWAITING_CONTRACT, получен $FINAL_STATUS" >&2; exit 1; }

echo
echo '12. Повторно загружаем скан после переподписания'
command_line "curl -sS -X POST $BASE_URL/api/depositors/me/contract/scan -F file=@<signed-contract.pdf>"
STATUS=$(curl -sS -b "$APPLICANT_COOKIES" -c "$APPLICANT_COOKIES" -o "$RESPONSE" -w '%{http_code}' \
    -X POST "$BASE_URL/api/depositors/me/contract/scan" \
    -H "$APPLICANT_CSRF_HEADER: $APPLICANT_CSRF_TOKEN" \
    -F "file=@$SIGNED_SCAN;type=application/pdf")
output
http_status
[ "$STATUS" = '200' ] || { echo 'ОШИБКА: повторная загрузка скана не выполнена' >&2; exit 1; }

echo
echo '13. Администратор подтверждает договор: ожидаем ACTIVE'

command_line "curl -sS -X POST $BASE_URL/api/admin/depositors/$APPLICANT_ID/contract/verify -b <admin-cookies>"
STATUS=$(curl -sS -b "$ADMIN_COOKIES" -c "$ADMIN_COOKIES" -o "$RESPONSE" -w '%{http_code}' \
    -X POST "$BASE_URL/api/admin/depositors/$APPLICANT_ID/contract/verify" \
    -H "$ADMIN_CSRF_HEADER: $ADMIN_CSRF_TOKEN")
output
http_status
[ "$STATUS" = '200' ] || { echo 'ОШИБКА: договор не верифицирован' >&2; exit 1; }

echo
echo '14. Проверяем, что депозитор стал ACTIVE и авторизован'
command_line "curl -sS -b <applicant-cookies> $BASE_URL/api/depositors/me"
STATUS=$(curl -sS -b "$APPLICANT_COOKIES" -c "$APPLICANT_COOKIES" -o "$RESPONSE" \
    -w '%{http_code}' "$BASE_URL/api/depositors/me")
output
http_status
[ "$STATUS" = '200' ] || { echo 'ОШИБКА: профиль депозитора недоступен' >&2; exit 1; }
FINAL_STATUS=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["status"])' "$RESPONSE")
[ "$FINAL_STATUS" = 'ACTIVE' ] || { echo "ОШИБКА: ожидался ACTIVE, получен $FINAL_STATUS" >&2; exit 1; }

echo

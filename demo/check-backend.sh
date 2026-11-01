#!/usr/bin/env bash
set -eu

# Адрес и демо-аккаунты заданы здесь: скрипт не принимает аргументы.
BASE_URL='http://127.0.0.1:8080'
ADMIN_EMAIL='i.ivanovich@example.com'
ADMIN_PASSWORD='Demo123!'
APPLICANT_PASSWORD='Demo123!'
RUN_ID="$(date +%s)-$RANDOM"
APPLICANT_EMAIL="demo-$RUN_ID@example.org"

COMMAND_COLOR='\033[36m'
OUTPUT_COLOR='\033[32m'
ERROR_COLOR='\033[31m'
RESET_COLOR='\033[0m'

command_line() {
    printf "${COMMAND_COLOR}> %s${RESET_COLOR}\n" "$1"
}

output() {
    printf "${OUTPUT_COLOR}"
    python3 -m json.tool --no-ensure-ascii "$RESPONSE" 2>/dev/null || cat "$RESPONSE"
    printf "${RESET_COLOR}\n"
}

http_status() {
    printf "${OUTPUT_COLOR}HTTP %s${RESET_COLOR}\n" "$STATUS"
}

TEMP_DIR=$(mktemp -d)
ADMIN_COOKIES="$TEMP_DIR/admin-cookies.txt"
APPLICANT_COOKIES="$TEMP_DIR/applicant-cookies.txt"
RESPONSE="$TEMP_DIR/response.json"
TUNNEL_LOG="$TEMP_DIR/tunnel.log"
GENERATED_CONTRACT="$TEMP_DIR/generated-contract.pdf"
SIGNED_SCAN="$TEMP_DIR/signed-contract.pdf"
ADMIN_SCAN="$TEMP_DIR/admin-scan.pdf"
TUNNEL_PID=''

cleanup() {
    if [ -n "$TUNNEL_PID" ]; then
        kill "$TUNNEL_PID" 2>/dev/null || true
        wait "$TUNNEL_PID" 2>/dev/null || true
    fi
    rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

echo '0. Открываем SSH-туннель к Helios'
command_line 'ssh -F ~/.ssh/config -N -L 8080:127.0.0.1:8080 helios'
ssh -F "$HOME/.ssh/config" -o BatchMode=yes -o ExitOnForwardFailure=yes \
    -o ConnectTimeout=10 -N -L 8080:127.0.0.1:8080 helios \
    >"$TUNNEL_LOG" 2>&1 &
TUNNEL_PID=$!
sleep 3
if ! kill -0 "$TUNNEL_PID" 2>/dev/null; then
    printf "${ERROR_COLOR}"
    cat "$TUNNEL_LOG" >&2
    printf "${RESET_COLOR}"
    echo 'ОШИБКА: не удалось открыть SSH-туннель' >&2
    exit 1
fi

echo 'Проверка backend на Helios'
echo "Адрес: $BASE_URL"

echo
echo '1. Проверяем запрос профиля без авторизации: ожидаем HTTP 401'
command_line "curl -sS $BASE_URL/api/auth/me"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' "$BASE_URL/api/auth/me")
output
http_status
[ "$STATUS" = '401' ] || { echo 'ОШИБКА: ожидался HTTP 401' >&2; exit 1; }

echo
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
echo '15. Выходим и проверяем отказ без авторизации: ожидаем HTTP 401'
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
echo "Все проверки прошли. Демо-заявка $APPLICANT_ID оставлена в ACTIVE."

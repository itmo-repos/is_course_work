#!/usr/bin/env bash
set -eu

BASE_URL='http://127.0.0.1:8080'
EMAIL='i.ivanovich@example.com'
PASSWORD='Demo123!'
COMMAND_COLOR='\033[36m'
OUTPUT_COLOR='\033[32m'
ERROR_COLOR='\033[31m'
RESET_COLOR='\033[0m'

command_line() {
    printf "${COMMAND_COLOR}> %s${RESET_COLOR}\n" "$1"
}

output() {
    printf "${OUTPUT_COLOR}"
    cat "$RESPONSE"
    printf "${RESET_COLOR}"
}

http_status() {
    printf "${OUTPUT_COLOR}HTTP %s${RESET_COLOR}\n" "$STATUS"
}

TEMP_DIR=$(mktemp -d)
COOKIES="$TEMP_DIR/cookies.txt"
RESPONSE="$TEMP_DIR/response.txt"
TUNNEL_LOG="$TEMP_DIR/tunnel.log"
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

echo 'Проверка backend'
echo "Адрес: $BASE_URL"
echo "Аккаунт: $EMAIL"

echo
echo '1. Профиль без авторизации: ожидаем HTTP 401'
command_line "curl -sS $BASE_URL/api/auth/me"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' "$BASE_URL/api/auth/me")
output
http_status
[ "$STATUS" = '401' ] || { echo 'ОШИБКА: ожидался HTTP 401' >&2; exit 1; }

echo
echo '2. Получаем CSRF-токен для входа: ожидаем HTTP 200'
command_line "curl -sS -c <cookies> $BASE_URL/api/auth/csrf"
STATUS=$(curl -sS -c "$COOKIES" -b "$COOKIES" -o "$RESPONSE" -w '%{http_code}' \
    "$BASE_URL/api/auth/csrf")
output
http_status
[ "$STATUS" = '200' ] || { echo 'ОШИБКА: ожидался HTTP 200' >&2; exit 1; }
CSRF_HEADER=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["headerName"])' "$RESPONSE")
CSRF_TOKEN=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["token"])' "$RESPONSE")

echo
echo '3. Входим с email, паролем и CSRF-токеном: ожидаем HTTP 200'
command_line "curl -sS -X POST $BASE_URL/api/auth/login -H '$CSRF_HEADER: $CSRF_TOKEN' -d '{\"email\":\"$EMAIL\",\"password\":\"<скрыт>\"}'"
STATUS=$(curl -sS -b "$COOKIES" -c "$COOKIES" -o "$RESPONSE" -w '%{http_code}' \
    -X POST "$BASE_URL/api/auth/login" \
    -H 'Content-Type: application/json' \
    -H "$CSRF_HEADER: $CSRF_TOKEN" \
    -d "{\"email\":\"$EMAIL\",\"password\":\"$PASSWORD\"}")
output
http_status
[ "$STATUS" = '200' ] || { echo 'ОШИБКА: вход не выполнен' >&2; exit 1; }

echo
echo '4. Запрашиваем профиль с cookie сессии: ожидаем HTTP 200'
command_line "curl -sS -b <cookies> $BASE_URL/api/auth/me"
STATUS=$(curl -sS -b "$COOKIES" -c "$COOKIES" -o "$RESPONSE" -w '%{http_code}' \
    "$BASE_URL/api/auth/me")
output
http_status
[ "$STATUS" = '200' ] || { echo 'ОШИБКА: профиль недоступен после входа' >&2; exit 1; }

echo
echo '5. Получаем новый CSRF-токен после входа: ожидаем HTTP 200'
command_line "curl -sS -b <cookies> $BASE_URL/api/auth/csrf"
STATUS=$(curl -sS -b "$COOKIES" -c "$COOKIES" -o "$RESPONSE" -w '%{http_code}' \
    "$BASE_URL/api/auth/csrf")
output
http_status
[ "$STATUS" = '200' ] || { echo 'ОШИБКА: CSRF-токен не получен' >&2; exit 1; }
CSRF_HEADER=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["headerName"])' "$RESPONSE")
CSRF_TOKEN=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["token"])' "$RESPONSE")

echo
echo '6. Выходим из системы: ожидаем HTTP 204'
command_line "curl -sS -X POST $BASE_URL/api/auth/logout -H '$CSRF_HEADER: $CSRF_TOKEN' -b <cookies>"
STATUS=$(curl -sS -b "$COOKIES" -c "$COOKIES" -o "$RESPONSE" -w '%{http_code}' \
    -X POST "$BASE_URL/api/auth/logout" \
    -H "$CSRF_HEADER: $CSRF_TOKEN")
output
http_status
[ "$STATUS" = '204' ] || { echo 'ОШИБКА: выход не выполнен' >&2; exit 1; }

echo
echo '7. Профиль после выхода: ожидаем HTTP 401'
command_line "curl -sS -b <cookies> $BASE_URL/api/auth/me"
STATUS=$(curl -sS -b "$COOKIES" -c "$COOKIES" -o "$RESPONSE" -w '%{http_code}' \
    "$BASE_URL/api/auth/me")
output
http_status
[ "$STATUS" = '401' ] || { echo 'ОШИБКА: сессия осталась активной' >&2; exit 1; }

echo
echo 'Все проверки прошли.'

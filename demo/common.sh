#!/usr/bin/env bash
# Общие функции демонстрационного сценария.
set -euo pipefail
for dependency in curl jq ssh; do
    command -v "$dependency" >/dev/null || { echo "Нужна команда: $dependency" >&2; exit 1; }
done
BASE_URL=${DEMO_BASE_URL:-http://127.0.0.1:8080}
RUN_ID="$(date +%s)-$RANDOM"
APPLICANT_EMAIL="demo-$RUN_ID@example.org"
TEMP_DIR=$(mktemp -d)
RESPONSE="$TEMP_DIR/response"
TUNNEL_LOG="$TEMP_DIR/tunnel.log"
TUNNEL_PID=''
STEP=0
REQUEST_COUNT=0
ROLE=PUBLIC
QUIET=0
RESET_COLOR=$'\033[0m'
ERROR_COLOR=$'\033[31m'
COMMAND_COLOR=$'\033[1;36m'
TITLE_COLOR=$'\033[1m'
SUCCESS_COLOR=$'\033[32m'
EXPECTED_COLOR=$'\033[33m'
if [ ! -t 1 ] || [ -n "${NO_COLOR:-}" ]; then
    RESET_COLOR='' ERROR_COLOR='' COMMAND_COLOR='' TITLE_COLOR='' SUCCESS_COLOR='' EXPECTED_COLOR=''
fi
cleanup() {
    restore_temporary_state
    if [ -n "$TUNNEL_PID" ]; then
        kill "$TUNNEL_PID" 2>/dev/null || true
        wait "$TUNNEL_PID" 2>/dev/null || true
    fi
    rm -rf -- "$TEMP_DIR"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
fail() { printf '%sОшибка: %s%s\n' "$ERROR_COLOR" "$*" "$RESET_COLOR" >&2; exit 1; }
# При остановке посреди сценария возвращаем временные настройки и закрываем сессии.
# Бизнес-записи не удаляем: заявка и партия остаются в достигнутом состоянии.
restore_temporary_state() {
    local code path method data actor cookie_var header_var token_var
    if [ -n "${ADMIN_CSRF_TOKEN:-}" ]; then
        while IFS='|' read -r method path data; do
            [ -n "$path" ] || continue
            code=$(curl -sS --connect-timeout 2 --max-time 8 -o /dev/null -w '%{http_code}' \
                -X "$method" "$BASE_URL$path" -b "$ADMIN_COOKIES" \
                -H "$ADMIN_CSRF_HEADER: $ADMIN_CSRF_TOKEN" -H 'Content-Type: application/json' \
                --data-binary "$data") || code=000
            case "$code" in 200|204) ;; *) printf 'Не удалось восстановить %s: HTTP %s\n' "$path" "$code" >&2 ;; esac
        done < <(
            if [ -n "${GATEWAY_KEY_ID:-}" ]; then printf 'DELETE|/api/admin/gateway-keys/%s|\n' "$GATEWAY_KEY_ID"; fi
            if [ -n "${CLIMATE_ORIGINAL_SETTINGS:-}" ]; then printf 'PUT|/api/admin/chambers/%s/settings|%s\n' "$CHAMBER_ID" "$CLIMATE_ORIGINAL_SETTINGS"; fi
            if [ -n "${ORIGINAL_ROLES:-}" ]; then printf 'PUT|/api/admin/employees/5/roles|{"roles":%s}\n' "$ORIGINAL_ROLES"; fi
            if [ "${STAFF_DISABLED:-0}" = 1 ]; then printf 'PATCH|/api/admin/employees/5/status|{"active":true}\n'; fi
        )
    fi
    for actor in APPLICANT CURATOR SECURITY ENGINEER ADMIN; do
        cookie_var="${actor}_COOKIES" header_var="${actor}_CSRF_HEADER" token_var="${actor}_CSRF_TOKEN"
        if [ -n "${!token_var:-}" ]; then
            curl -sS --connect-timeout 2 --max-time 5 -o /dev/null -X POST "$BASE_URL/api/auth/logout" \
                -b "${!cookie_var}" -H "${!header_var}: ${!token_var}" >/dev/null 2>&1 || true
        fi
    done
}
role() {
    ROLE=$1
    case "$ROLE" in
        PUBLIC) ROLE_NAME='Посетитель'; ROLE_COLOR=$'\033[1m' ;;
        APPLICANT) ROLE_NAME='Депозитор'; ROLE_COLOR=$'\033[1;96m' ;;
        ADMIN) ROLE_NAME='Администратор'; ROLE_COLOR=$'\033[1;95m' ;;
        CURATOR) ROLE_NAME='Куратор'; ROLE_COLOR=$'\033[1;94m' ;;
        SECURITY) ROLE_NAME='Охрана'; ROLE_COLOR=$'\033[1;93m' ;;
        ENGINEER) ROLE_NAME='Инженер'; ROLE_COLOR=$'\033[1;92m' ;;
        GATEWAY) ROLE_NAME='Шлюз'; ROLE_COLOR=$'\033[1;96m' ;;
        *) fail "Неизвестная роль: $ROLE" ;;
    esac
    if [ ! -t 1 ] || [ -n "${NO_COLOR:-}" ]; then ROLE_COLOR=''; fi
}
step() {
    role "$1"
    STEP=$((STEP + 1))
    printf '\n%s%02d. [%s]%s %s%s%s\n' "$ROLE_COLOR" "$STEP" "$ROLE_NAME" "$RESET_COLOR" "$TITLE_COLOR" "$2" "$RESET_COLOR"
}
section() { printf '\n%s=== %s ===%s\n' "$TITLE_COLOR" "$1" "$RESET_COLOR"; }
command_line() { printf '%s> %s%s\n' "$COMMAND_COLOR" "$1" "$RESET_COLOR"; }
output() {
    if [ ! -s "$RESPONSE" ]; then return; fi
    printf '← Ответ (фрагмент):\n'
    if ! jq -M --arg scenario "${DEMO_SCENARIO:-}" --arg path "${1:-}" \
        --argjson box "${BOX_ID:-null}" --argjson secondBox "${SECOND_BOX_ID:-null}" \
        --argjson firstPlace "${FIRST_PLACE_ID:-null}" --argjson secondPlace "${SECOND_PLACE_ID:-null}" \
        --argjson replacementPlace "${REPLACEMENT_PLACE_ID:-null}" \
        -f "${DEMO_DIR:-demo}/output.jq" "$RESPONSE" 2>/dev/null; then
        if jq -e . "$RESPONSE" >/dev/null 2>&1; then
            fail 'Не удалось подготовить JSON для показа'
        fi
        cat "$RESPONSE"; printf '\n'
    fi
}
check_json() {
    local filter=$1 message=$2
    shift 2
    jq -e "$@" "$filter" "$RESPONSE" >/dev/null || fail "$message (шаг $STEP)"
}
# request METHOD PATH EXPECTED [JSON [OUTPUT_FILE]]
# COOKIES/CSRF selected by role. Gateway uses its separate Bearer credential.
request() {
    local method=$1 path=$2 expected=$3 data=${4:-} destination=${5:-$RESPONSE}
    local -a args=(-sS --connect-timeout 10 --max-time 60 -o "$destination" -w '%{http_code}' -X "$method")
    if [ "$ROLE" = GATEWAY ]; then
        args+=(-H "Authorization: Bearer $GATEWAY_TOKEN")
    elif [ "$ROLE" != PUBLIC ]; then
        local cookie_var="${ROLE}_COOKIES" header_var="${ROLE}_CSRF_HEADER" token_var="${ROLE}_CSRF_TOKEN"
        args+=(-b "${!cookie_var}" -c "${!cookie_var}")
        if [ "$method" != GET ]; then args+=(-H "${!header_var}: ${!token_var}"); fi
    fi
    if [ -n "${UPLOAD_FILE:-}" ]; then
        args+=(-F "file=@$UPLOAD_FILE;type=application/pdf")
    elif [ -n "$data" ]; then
        args+=(-H 'Content-Type: application/json' --data-binary "$data")
    fi
    if [ "$QUIET" = 0 ]; then
        command_line "$method $path"
        if [ "${AUTH_DEMO:-0}" = 1 ]; then
            printf 'Cookie: SESSION=<сессия из cookie-файла>\n'
            if [ "$method" != GET ]; then
                printf '%s: <полученный CSRF-токен>\n' "${!header_var}"
            fi
            args+=(-D "$TEMP_DIR/auth-headers")
        fi
        if [ -n "$data" ]; then
            printf '→ Данные:\n'
            printf '%s\n' "$data" | jq -M 'if type == "object" then (if has("password") then .password="<пароль, выбранный при регистрации>" else . end) | (if has("passCode") then .passCode="<код QR скрыт>" else . end) else . end'
        fi
    fi
    STATUS=$(curl "${args[@]}" "$BASE_URL$path") || fail "Не удалось выполнить $method $path"
    REQUEST_COUNT=$((REQUEST_COUNT + 1))
    if [ "${AUTH_DEMO:-0}" = 1 ] && [ "$QUIET" = 0 ]; then
        if grep -qi '^set-cookie: SESSION=' "$TEMP_DIR/auth-headers"; then
            printf 'Set-Cookie: SESSION=<новый идентификатор; сохранён в cookie-файл>\n'
        fi
    fi
    if [ "$QUIET" = 0 ] || [ "$STATUS" != "$expected" ]; then
        if [ "$destination" = "$RESPONSE" ]; then output "$path"
        else printf 'Файл получен: %s (%s байт)\n' "${destination##*/}" "$(wc -c < "$destination")"; fi
        local status_color=$SUCCESS_COLOR
        if [ "$STATUS" != "$expected" ]; then status_color=$ERROR_COLOR
        elif [ "$STATUS" -ge 400 ]; then status_color=$EXPECTED_COLOR; fi
        printf '%sHTTP %s%s\n' "$status_color" "$STATUS" "$RESET_COLOR"
    fi
    [ "$STATUS" = "$expected" ] || fail "$method $path: ожидался HTTP $expected, получен $STATUS (шаг $STEP)"
}
csrf() {
    local prefix=$1 cookie_var="${1}_COOKIES"
    if [ "${AUTH_DEMO:-0}" = 1 ]; then command_line 'GET /api/auth/csrf'; fi
    curl -fsS --connect-timeout 10 --max-time 30 -b "${!cookie_var}" -c "${!cookie_var}" "$BASE_URL/api/auth/csrf" > "$RESPONSE" || fail 'Не получен CSRF-токен'
    REQUEST_COUNT=$((REQUEST_COUNT + 1))
    printf -v "${prefix}_CSRF_HEADER" '%s' "$(jq -er '.headerName' "$RESPONSE")"
    printf -v "${prefix}_CSRF_TOKEN" '%s' "$(jq -er '.token' "$RESPONSE")"
    if [ "${AUTH_DEMO:-0}" = 1 ]; then
        jq -M '.token = "<CSRF-токен; сохранён для заголовка>"' "$RESPONSE"
        printf 'Cookie SESSION сохраняется curl в cookie-файл (-c), отправляется обратно через -b.\n'
    fi
}
login() {
    local prefix=$1 email=$2
    printf -v "${prefix}_COOKIES" '%s' "$TEMP_DIR/${prefix,,}-cookies.txt"
    role "$prefix"
    csrf "$prefix"
    QUIET=$((1 - ${AUTH_DEMO:-0}))
    request POST /api/auth/login 200 "$(jq -cn --arg email "$email" '{email:$email,password:"Demo123!"}')"
    QUIET=0
    if [ "${AUTH_DEMO:-0}" = 1 ]; then printf 'После входа сервер сменил SESSION и сбросил прежний CSRF. Получаем новый:\n'; fi
    csrf "$prefix"
}
next_part() {
    local answer
    printf '\n'
    while true; do
        printf 'Enter — далее · q — выход: '
        if ! read -r answer; then printf '\nДемо остановлено.\n'; exit 0; fi
        case "$answer" in
            ''|1) break ;;
            q|Q|й|Й) printf 'Демо остановлено.\n'; exit 0 ;;
        esac
    done
}
role PUBLIC

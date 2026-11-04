#!/usr/bin/env bash
# Часть общего сценария: запускается через demo/check-backend.sh.

command -v jq >/dev/null || { echo 'Нужен jq: sudo dnf install jq' >&2; exit 1; }

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
    jq '
        if type == "object" then
            (if has("qrSvg") then .code = "<код скрыт>" | .qrSvg = "<QR SVG скрыт>" else . end)
            | if .issuedPass? != null then
                .issuedPass.code = "<код скрыт>" | .issuedPass.qrSvg = "<QR SVG скрыт>"
              else . end
        else . end
    ' "$RESPONSE" 2>/dev/null || cat "$RESPONSE"
    printf "${RESET_COLOR}\n"
}

http_status() {
    printf "${OUTPUT_COLOR}HTTP %s${RESET_COLOR}\n" "$STATUS"
}

check_json() {
    local filter="$1"
    local message="$2"
    shift 2
    if ! jq -e "$@" "$filter" "$RESPONSE" >/dev/null; then
        printf "${ERROR_COLOR}ОШИБКА: %s${RESET_COLOR}\n" "$message" >&2
        exit 1
    fi
}

section() {
    printf "\n${ERROR_COLOR}=== %s ===${RESET_COLOR}\n" "$1"
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

next_part() {
    echo
    while true; do
        printf "${ERROR_COLOR}Порция проверок завершена. Нажмите Enter или введите 1, чтобы продолжить: ${RESET_COLOR}"
        if ! read -r answer; then
            echo
            echo 'Демо остановлено.'
            exit 0
        fi
        if [ -z "$answer" ] || [ "$answer" = '1' ]; then
            break
        fi
        printf "${ERROR_COLOR}Для продолжения нажмите Enter или введите 1.${RESET_COLOR}\n"
    done
}

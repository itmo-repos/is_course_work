#!/usr/bin/env bash
# Часть общего сценария: запускается через demo/check-backend.sh.

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

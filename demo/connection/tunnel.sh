#!/usr/bin/env bash
# Часть общего сценария: запускается через demo/check-backend.sh.

ssh -F "$HOME/.ssh/config" -o BatchMode=yes -o ExitOnForwardFailure=yes \
    -o ConnectTimeout=10 -N -L 8080:127.0.0.1:46701 helios \
    >"$TUNNEL_LOG" 2>&1 &
TUNNEL_PID=$!
# Ждём готовности туннеля и HTTP backend, а не фиксированные три секунды.
for attempt in {1..30}; do
    if ! kill -0 "$TUNNEL_PID" 2>/dev/null; then break; fi
    if curl -fsS --connect-timeout 1 --max-time 2 "$BASE_URL/api/samples?species=__demo_readiness__" >/dev/null 2>&1; then
        return 0
    fi
    sleep 1
done
if ! kill -0 "$TUNNEL_PID" 2>/dev/null; then
    printf "${ERROR_COLOR}"
    cat "$TUNNEL_LOG" >&2
    printf "${RESET_COLOR}"
    echo 'ОШИБКА: не удалось открыть SSH-туннель' >&2
    exit 1
fi
fail 'Туннель открыт, но backend не отвечает. Проверьте, что backend на Helios запущен.'

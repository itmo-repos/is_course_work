#!/bin/sh
set -eu

APP_DIR=/home/studs/s467669/seedbank-backend
ACTION=${1:?Usage: helios-control.sh restart|status|stop|clean-db|reset-db}
ENV_FILE="$HOME/.config/seedbank/backend.env"

running() {
    [ -s "$APP_DIR/backend.pid" ] && kill -0 "$(cat "$APP_DIR/backend.pid")" 2>/dev/null
}

stop() {
    if running; then
        kill "$(cat "$APP_DIR/backend.pid")"
        while running; do sleep 1; done
    fi
    rm -f "$APP_DIR/backend.pid"
}

case "$ACTION" in
    clean-db|reset-db)
        set -a
        . "$ENV_FILE"
        set +a
        export PGPASSWORD="$SPRING_DATASOURCE_PASSWORD"
        stop
        cd "$APP_DIR/sql"
        echo 'Пересоздаём таблицы проекта в studs, схема s467669 (старые данные удаляются)'
        psql -X -w -h 127.0.0.1 -U s467669 -d studs -v ON_ERROR_STOP=1 \
            -c 'SET search_path TO s467669' \
            -f 06_drop.sql -f 01_create.sql -f 02_triggers.sql \
            -f 03_functions.sql -f 04_indexes.sql
        if [ "$ACTION" = reset-db ]; then
            echo 'Загружаем тестовые данные'
            psql -X -w -h 127.0.0.1 -U s467669 -d studs -v ON_ERROR_STOP=1 \
                -c 'SET search_path TO s467669' -f 05_fill.sql
        fi
        sh "$APP_DIR/helios-control.sh" restart
        ;;
    status)
        if running; then
            echo "Backend is running (PID $(cat "$APP_DIR/backend.pid")). Log: $APP_DIR/backend.log"
        else
            echo "Backend is not running"
            exit 1
        fi
        ;;
    stop)
        stop
        echo "Backend stopped"
        ;;
    restart)
        [ -r "$ENV_FILE" ] || { echo "Create $ENV_FILE with the backend settings first" >&2; exit 1; }
        [ -r "$APP_DIR/backend.jar" ] || { echo "Missing $APP_DIR/backend.jar; run publishHelios first" >&2; exit 1; }
        stop
        cd "$APP_DIR"
        set -a
        . "$ENV_FILE"
        set +a
        nohup java -Xms64m -Xmx512m -jar backend.jar >> backend.log 2>&1 </dev/null &
        echo "$!" > "$APP_DIR/backend.pid"
        sleep 2
        if running; then
            echo "Backend started (PID $(cat "$APP_DIR/backend.pid")). Log: $APP_DIR/backend.log"
        else
            rm -f "$APP_DIR/backend.pid"
            echo "Backend failed to start; check $APP_DIR/backend.log" >&2
            exit 1
        fi
        ;;
    *)
        echo "Unknown action: $ACTION" >&2
        exit 2
        ;;
esac

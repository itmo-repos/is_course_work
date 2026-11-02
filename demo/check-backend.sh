#!/usr/bin/env bash
set -eu

DEMO_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
. "$DEMO_DIR/common.sh"
. "$DEMO_DIR/connection/tunnel.sh"

echo 'Проверка backend на Helios'
echo "Адрес: $BASE_URL"

echo
echo '=== Доступ без авторизации и публичный каталог ==='
. "$DEMO_DIR/auth/check-access.sh"
. "$DEMO_DIR/catalog/check.sh"

next_part
echo
echo '=== Регистрация депозитора и договор ==='
. "$DEMO_DIR/depositors/check.sh"

next_part
echo
echo '=== Партии, штрихкоды и транспортные статусы ==='
. "$DEMO_DIR/batches/check.sh"

next_part
echo
echo '=== Выход и проверка закрытия сессий ==='
. "$DEMO_DIR/auth/logout.sh"

echo "Все проверки прошли. Демо-заявка $APPLICANT_ID оставлена в ACTIVE, партия $BATCH_ID — в ARRIVED."

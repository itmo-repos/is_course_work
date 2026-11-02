#!/usr/bin/env bash
set -eu

DEMO_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
. "$DEMO_DIR/common.sh"
. "$DEMO_DIR/connection/tunnel.sh"

echo 'Проверка backend на Helios'
echo "Адрес: $BASE_URL"

section 'Доступ без авторизации и публичный каталог'
. "$DEMO_DIR/auth/check-access.sh"
. "$DEMO_DIR/catalog/check.sh"

next_part
section 'Регистрация депозитора и договор'
. "$DEMO_DIR/depositors/check.sh"

next_part
section 'Партии, штрихкоды и транспортные статусы'
. "$DEMO_DIR/batches/check.sh"

next_part
section 'Приём, размещение и перемещение коробок'
. "$DEMO_DIR/intake/check.sh"

next_part
section 'Заявки и сессии изъятия'
. "$DEMO_DIR/withdrawal/check.sh"

next_part
section 'Выход и проверка закрытия сессий'
. "$DEMO_DIR/auth/logout.sh"

echo "Все проверки прошли. Демо-заявка $APPLICANT_ID оставлена в ACTIVE, партия $BATCH_ID — PARTIALLY_PLACED; заявка на изъятие $WITHDRAWAL_ID — FULFILLED, коробка #$WITHDRAWAL_BOX_ID — WITHDRAWN."

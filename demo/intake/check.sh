#!/usr/bin/env bash
# Часть общего сценария: запускается через demo/check-backend.sh.

echo
echo '30. Получаем коробки и штрихкод прибывшей партии'
command_line "curl -sS -X GET $BASE_URL/api/depositors/me/batches/$BATCH_ID -b <cookies>"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' \
    -X GET "$BASE_URL/api/depositors/me/batches/$BATCH_ID" \
    -b "$APPLICANT_COOKIES")
output
http_status
[ "$STATUS" = '200' ] || { echo 'ОШИБКА: ожидался HTTP 200' >&2; exit 1; }
BOX_ID=$(jq -er '.boxes[0].id' "$RESPONSE")
SECOND_BOX_ID=$(jq -er '.boxes[1].id' "$RESPONSE")
BARCODE=$(jq -er '.boxes[0].barcode' "$RESPONSE")

echo
echo '31. По любой коробке находим всю партию'
command_line "curl -sS -X GET $BASE_URL/api/curator/batches/by-barcode/$BARCODE -b <cookies>"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' \
    -X GET "$BASE_URL/api/curator/batches/by-barcode/$BARCODE" \
    -b "$ADMIN_COOKIES")
output
http_status
[ "$STATUS" = '200' ] || { echo 'ОШИБКА: ожидался HTTP 200' >&2; exit 1; }
check_json '.batchId == $id and .boxCount == 2 and .currentStatus == "ARRIVED"' 'По штрихкоду найдена неверная партия' --argjson id "$BATCH_ID"

echo
echo '32. Неизвестный штрихкод: HTTP 404'
command_line "curl -sS -X GET $BASE_URL/api/curator/batches/by-barcode/UNKNOWN-DEMO-BARCODE -b <cookies>"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' \
    -X GET "$BASE_URL/api/curator/batches/by-barcode/UNKNOWN-DEMO-BARCODE" \
    -b "$ADMIN_COOKIES")
output
http_status
[ "$STATUS" = '404' ] || { echo 'ОШИБКА: ожидался HTTP 404' >&2; exit 1; }

echo
echo '33. Депозитор не может регистрировать досмотр: HTTP 403'
command_line "curl -sS -X POST $BASE_URL/api/curator/batches/by-barcode/$BARCODE/arrive -b <cookies>"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' \
    -X POST "$BASE_URL/api/curator/batches/by-barcode/$BARCODE/arrive" \
    -b "$APPLICANT_COOKIES" \
    -H "$APPLICANT_CSRF_HEADER: $APPLICANT_CSRF_TOKEN")
output
http_status
[ "$STATUS" = '403' ] || { echo 'ОШИБКА: ожидался HTTP 403' >&2; exit 1; }

echo
echo '35. До досмотра сессия запланирована, коробки ещё FORMED'
command_line "curl -sS $BASE_URL/api/curator/intake-sessions/$SESSION_ID -b <admin-cookies>"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' \
    "$BASE_URL/api/curator/intake-sessions/$SESSION_ID" -b "$ADMIN_COOKIES")
output
http_status
[ "$STATUS" = '200' ] || { echo 'ОШИБКА: ожидался HTTP 200' >&2; exit 1; }
check_json '.status == "PLANNED" and .batchStatus == "ARRIVED" and all(.boxes[]; .status == "FORMED" and .storagePlace == null)' 'До досмотра план не должен менять коробки и занимать места'

echo
echo '36. Регистрируем досмотр по штрихкоду: INSPECTION'
command_line "curl -sS -X POST $BASE_URL/api/curator/batches/by-barcode/$BARCODE/arrive -b <cookies>"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' \
    -X POST "$BASE_URL/api/curator/batches/by-barcode/$BARCODE/arrive" \
    -b "$ADMIN_COOKIES" \
    -H "$ADMIN_CSRF_HEADER: $ADMIN_CSRF_TOKEN")
output
http_status
[ "$STATUS" = '200' ] || { echo 'ОШИБКА: ожидался HTTP 200' >&2; exit 1; }
check_json '.currentStatus == "INSPECTION"' 'Досмотр не начался'

echo
echo '37. Досмотр зарезервировал два разных места в запланированной сессии'
command_line "curl -sS $BASE_URL/api/curator/intake-sessions/$SESSION_ID -b <admin-cookies>"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' \
    "$BASE_URL/api/curator/intake-sessions/$SESSION_ID" -b "$ADMIN_COOKIES")
output
http_status
[ "$STATUS" = '200' ] || { echo 'ОШИБКА: ожидался HTTP 200' >&2; exit 1; }
SESSION_ID=$(jq -er '.id' "$RESPONSE")
FIRST_PLACE_ID=$(jq -er '.boxes[0].storagePlace.id' "$RESPONSE")
SECOND_PLACE_ID=$(jq -er '.boxes[1].storagePlace.id' "$RESPONSE")
check_json '.status == "PLANNED" and .batchStatus == "INSPECTION"' 'Неверное состояние сессии при досмотре'
check_json 'all(.boxes[]; .status == "AWAITING_PLACEMENT" and .storagePlace != null)' 'Коробкам не назначены места'
check_json '(.boxes | length) == ([.boxes[].storagePlace.id] | unique | length)' 'Разным коробкам назначено одно место'

echo
MAP_STAGE=RESERVED
. "$DEMO_DIR/intake/map.sh"

echo
echo '38. Дублировать сессию нельзя: HTTP 409'
command_line "curl -sS -X POST $BASE_URL/api/curator/batches/$BATCH_ID/intake-sessions -b <cookies>"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' \
    -X POST "$BASE_URL/api/curator/batches/$BATCH_ID/intake-sessions" \
    -b "$ADMIN_COOKIES" \
    -H "$ADMIN_CSRF_HEADER: $ADMIN_CSRF_TOKEN" \
    -H 'Content-Type: application/json' \
    -d "{\"chamberId\":$CHAMBER_ID,\"plannedDate\":\"$(date +%F)\"}")
output
http_status
[ "$STATUS" = '409' ] || { echo 'ОШИБКА: ожидался HTTP 409' >&2; exit 1; }

echo
echo '39. Депозитор пока не видит координаты резервов'
command_line "curl -sS -X GET $BASE_URL/api/depositors/me/batches/$BATCH_ID/boxes -b <cookies>"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' \
    -X GET "$BASE_URL/api/depositors/me/batches/$BATCH_ID/boxes" \
    -b "$APPLICANT_COOKIES")
output
http_status
[ "$STATUS" = '200' ] || { echo 'ОШИБКА: ожидался HTTP 200' >&2; exit 1; }
check_json 'all(.[]; .storagePlace == null)' 'Депозитор видит координаты неподтверждённых назначений'

echo
echo '40. Резервы исчезли из списка свободных мест'
command_line "curl -sS -X GET $BASE_URL/api/curator/chambers/$CHAMBER_ID/free-places -b <cookies>"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' \
    -X GET "$BASE_URL/api/curator/chambers/$CHAMBER_ID/free-places" \
    -b "$ADMIN_COOKIES")
http_status
[ "$STATUS" = '200' ] || { output; echo 'ОШИБКА: ожидался HTTP 200' >&2; exit 1; }
check_json 'all(.[]; .id != $first and .id != $second)' 'Назначенные места всё ещё доступны как свободные' --argjson first "$FIRST_PLACE_ID" --argjson second "$SECOND_PLACE_ID"
FREE_AFTER_INTAKE=$(jq 'length' "$RESPONSE")
[ "$FREE_AFTER_INTAKE" -eq "$((FREE_BEFORE_PLAN - 2))" ] || {
    echo "ОШИБКА: ожидалось $((FREE_BEFORE_PLAN - 2)) свободных мест, получено $FREE_AFTER_INTAKE" >&2
    exit 1
}
printf "${OUTPUT_COLOR}Камера: %s\nСвободных мест до досмотра: %s\nПосле назначения двух коробок: %s\nМеста #%s и #%s зарезервированы этой партией и больше не свободны.${RESET_COLOR}\n" \
    "$CHAMBER_CODE" "$FREE_BEFORE_PLAN" "$FREE_AFTER_INTAKE" "$FIRST_PLACE_ID" "$SECOND_PLACE_ID"
REPLACEMENT_PLACE_ID=$(jq -er '.[0].id' "$RESPONSE")

echo
echo '41. Чужой резерв занять нельзя: HTTP 409'
command_line "curl -sS -X PATCH $BASE_URL/api/curator/boxes/$BOX_ID/storage-place -b <cookies>"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' \
    -X PATCH "$BASE_URL/api/curator/boxes/$BOX_ID/storage-place" \
    -b "$ADMIN_COOKIES" \
    -H "$ADMIN_CSRF_HEADER: $ADMIN_CSRF_TOKEN" \
    -H 'Content-Type: application/json' \
    -d "{\"storagePlaceId\":$SECOND_PLACE_ID}")
output
http_status
[ "$STATUS" = '409' ] || { echo 'ОШИБКА: ожидался HTTP 409' >&2; exit 1; }

echo
echo '42. Куратор меняет назначенное место на свободное'
command_line "curl -sS -X PATCH $BASE_URL/api/curator/boxes/$BOX_ID/storage-place -b <cookies>"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' \
    -X PATCH "$BASE_URL/api/curator/boxes/$BOX_ID/storage-place" \
    -b "$ADMIN_COOKIES" \
    -H "$ADMIN_CSRF_HEADER: $ADMIN_CSRF_TOKEN" \
    -H 'Content-Type: application/json' \
    -d "{\"storagePlaceId\":$REPLACEMENT_PLACE_ID}")
output
http_status
[ "$STATUS" = '200' ] || { echo 'ОШИБКА: ожидался HTTP 200' >&2; exit 1; }

echo
echo '43. Подтверждаем размещение первой коробки'
command_line "curl -sS -X POST $BASE_URL/api/curator/boxes/$BOX_ID/place -b <cookies>"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' \
    -X POST "$BASE_URL/api/curator/boxes/$BOX_ID/place" \
    -b "$ADMIN_COOKIES" \
    -H "$ADMIN_CSRF_HEADER: $ADMIN_CSRF_TOKEN")
output
http_status
[ "$STATUS" = '200' ] || { echo 'ОШИБКА: ожидался HTTP 200' >&2; exit 1; }
check_json '.status == "PLACED" and .storagePlace != null and .placedAt != null' 'Коробка не размещена'

echo
MAP_STAGE=PLACED_FIRST
. "$DEMO_DIR/intake/map.sh"

echo
echo '44. Приём не завершён, пока осталась вторая коробка'
command_line "curl -sS -X GET $BASE_URL/api/curator/intake-sessions/$SESSION_ID -b <cookies>"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' \
    -X GET "$BASE_URL/api/curator/intake-sessions/$SESSION_ID" \
    -b "$ADMIN_COOKIES")
output
http_status
[ "$STATUS" = '200' ] || { echo 'ОШИБКА: ожидался HTTP 200' >&2; exit 1; }
check_json '.status == "PLANNED" and .batchStatus == "INSPECTION" and .completedAt == null' 'Приём завершился до обработки всех коробок'

echo
echo '45. Списание без причины отклоняется: HTTP 400'
command_line "curl -sS -X POST $BASE_URL/api/curator/boxes/$SECOND_BOX_ID/write-off -b <cookies>"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' \
    -X POST "$BASE_URL/api/curator/boxes/$SECOND_BOX_ID/write-off" \
    -b "$ADMIN_COOKIES" \
    -H "$ADMIN_CSRF_HEADER: $ADMIN_CSRF_TOKEN" \
    -H 'Content-Type: application/json' \
    -d '{"reason":" "}')
output
http_status
[ "$STATUS" = '400' ] || { echo 'ОШИБКА: ожидался HTTP 400' >&2; exit 1; }

echo
echo '46. Списываем вторую коробку с причиной'
command_line "curl -sS -X POST $BASE_URL/api/curator/boxes/$SECOND_BOX_ID/write-off -b <cookies>"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' \
    -X POST "$BASE_URL/api/curator/boxes/$SECOND_BOX_ID/write-off" \
    -b "$ADMIN_COOKIES" \
    -H "$ADMIN_CSRF_HEADER: $ADMIN_CSRF_TOKEN" \
    -H 'Content-Type: application/json' \
    -d '{"reason":"Повреждение упаковки (демо)"}')
output
http_status
[ "$STATUS" = '200' ] || { echo 'ОШИБКА: ожидался HTTP 200' >&2; exit 1; }
check_json '.status == "WRITTEN_OFF" and .storagePlace == null and (.writeOffReason | length) > 0' 'Коробка не списана или резерв не освобождён'

echo
MAP_STAGE=WRITTEN_OFF
. "$DEMO_DIR/intake/map.sh"

echo
echo '47. Последнее решение завершило приём: PARTIALLY_PLACED'
command_line "curl -sS -X GET $BASE_URL/api/curator/intake-sessions/$SESSION_ID -b <cookies>"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' \
    -X GET "$BASE_URL/api/curator/intake-sessions/$SESSION_ID" \
    -b "$ADMIN_COOKIES")
output
http_status
[ "$STATUS" = '200' ] || { echo 'ОШИБКА: ожидался HTTP 200' >&2; exit 1; }
check_json '.status == "COMPLETED" and .batchStatus == "PARTIALLY_PLACED" and .completedAt != null' 'Приём не завершился частичным размещением'

echo
echo '48. Владелец видит координаты только размещённой коробки'
command_line "curl -sS -X GET $BASE_URL/api/depositors/me/batches/$BATCH_ID/boxes -b <cookies>"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' \
    -X GET "$BASE_URL/api/depositors/me/batches/$BATCH_ID/boxes" \
    -b "$APPLICANT_COOKIES")
output
http_status
[ "$STATUS" = '200' ] || { echo 'ОШИБКА: ожидался HTTP 200' >&2; exit 1; }
check_json '.[0].status == "PLACED" and .[0].storagePlace.rackNo > 0 and .[1].status == "WRITTEN_OFF" and .[1].storagePlace == null' 'Владелец должен видеть координаты только размещённой коробки'

echo
echo '49. Перемещаем коробку на освободившееся место'
command_line "curl -sS -X POST $BASE_URL/api/curator/boxes/$BOX_ID/move -b <cookies>"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' \
    -X POST "$BASE_URL/api/curator/boxes/$BOX_ID/move" \
    -b "$ADMIN_COOKIES" \
    -H "$ADMIN_CSRF_HEADER: $ADMIN_CSRF_TOKEN" \
    -H 'Content-Type: application/json' \
    -d "{\"storagePlaceId\":$SECOND_PLACE_ID}")
output
http_status
[ "$STATUS" = '200' ] || { echo 'ОШИБКА: ожидался HTTP 200' >&2; exit 1; }
check_json '.status == "AWAITING_PLACEMENT" and .placedAt == null' 'Перемещение не началось'

echo
MAP_STAGE=MOVING
. "$DEMO_DIR/intake/map.sh"

echo
echo '50. До подтверждения перемещения координаты скрыты'
command_line "curl -sS -X GET $BASE_URL/api/depositors/me/batches/$BATCH_ID/boxes -b <cookies>"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' \
    -X GET "$BASE_URL/api/depositors/me/batches/$BATCH_ID/boxes" \
    -b "$APPLICANT_COOKIES")
output
http_status
[ "$STATUS" = '200' ] || { echo 'ОШИБКА: ожидался HTTP 200' >&2; exit 1; }
check_json '.[0].storagePlace == null' 'До подтверждения перемещения координаты должны быть скрыты'

echo
echo '51. Подтверждаем размещение после перемещения'
command_line "curl -sS -X POST $BASE_URL/api/curator/boxes/$BOX_ID/place -b <cookies>"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' \
    -X POST "$BASE_URL/api/curator/boxes/$BOX_ID/place" \
    -b "$ADMIN_COOKIES" \
    -H "$ADMIN_CSRF_HEADER: $ADMIN_CSRF_TOKEN")
output
http_status
[ "$STATUS" = '200' ] || { echo 'ОШИБКА: ожидался HTTP 200' >&2; exit 1; }

echo
MAP_STAGE=MOVED
. "$DEMO_DIR/intake/map.sh"

echo
echo '52. Новые координаты видны владельцу'
command_line "curl -sS -X GET $BASE_URL/api/depositors/me/batches/$BATCH_ID/boxes -b <cookies>"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' \
    -X GET "$BASE_URL/api/depositors/me/batches/$BATCH_ID/boxes" \
    -b "$APPLICANT_COOKIES")
output
http_status
[ "$STATUS" = '200' ] || { echo 'ОШИБКА: ожидался HTTP 200' >&2; exit 1; }
check_json '.[0].status == "PLACED" and .[0].storagePlace.id == $id' 'Коробка не размещена на новом месте' --argjson id "$SECOND_PLACE_ID"

echo
echo '53. Перемещение не изменило завершённую сессию'
command_line "curl -sS -X GET $BASE_URL/api/curator/intake-sessions/$SESSION_ID -b <cookies>"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' \
    -X GET "$BASE_URL/api/curator/intake-sessions/$SESSION_ID" \
    -b "$ADMIN_COOKIES")
output
http_status
[ "$STATUS" = '200' ] || { echo 'ОШИБКА: ожидался HTTP 200' >&2; exit 1; }
check_json '.status == "COMPLETED" and .batchStatus == "PARTIALLY_PLACED"' 'Перемещение изменило итог завершённого приёма'

echo
echo '54. Без авторизации координаты недоступны: HTTP 401'
command_line "curl -sS -X GET $BASE_URL/api/depositors/me/batches/$BATCH_ID/boxes"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' \
    -X GET "$BASE_URL/api/depositors/me/batches/$BATCH_ID/boxes")
output
http_status
[ "$STATUS" = '401' ] || { echo 'ОШИБКА: ожидался HTTP 401' >&2; exit 1; }

. "$DEMO_DIR/intake/ownership.sh"
. "$DEMO_DIR/intake/outcomes.sh"

echo
echo 'Без авторизации полная карта камеры недоступна: HTTP 401'
command_line "curl -sS $BASE_URL/api/curator/chambers/$CHAMBER_ID/places"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' "$BASE_URL/api/curator/chambers/$CHAMBER_ID/places")
output
http_status
[ "$STATUS" = '401' ] || { echo 'ОШИБКА: ожидался HTTP 401' >&2; exit 1; }

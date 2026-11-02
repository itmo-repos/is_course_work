#!/usr/bin/env bash
# Вызывается из сценариев планирования и приёма с переменной MAP_STAGE.

check_box_on_map() {
    local box_id="$1"
    local occupancy="$2"
    local place_id="${3:-0}"
    check_json '
        any(.places[];
            .box.id == $box and .occupancy == $occupancy
            and ($place == 0 or .id == $place)
            and .box.batchId == $batch and .box.depositorId == $depositor)
    ' "Коробка #$box_id: ожидалось $occupancy на месте #$place_id" \
        --argjson box "$box_id" --arg occupancy "$occupancy" --argjson place "$place_id" \
        --argjson batch "$BATCH_ID" --argjson depositor "$APPLICANT_ID"
}

check_free_place_on_map() {
    check_json 'any(.places[]; .id == $id and .occupancy == "FREE" and .box == null)' \
        "Место #$1 должно быть свободным" --argjson id "$1"
}

check_box_absent_on_map() {
    check_json 'all(.places[]; .box.id != $id)' \
        "Коробка #$1 не должна занимать место на карте" --argjson id "$1"
}

echo
command_line "curl -sS $BASE_URL/api/curator/chambers/$CHAMBER_ID/places -b <admin-cookies>"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' \
    "$BASE_URL/api/curator/chambers/$CHAMBER_ID/places" -b "$ADMIN_COOKIES")
http_status
[ "$STATUS" = '200' ] || { output; echo 'ОШИБКА: карта камеры не получена' >&2; exit 1; }

check_json '.summary.total == (.places | length)' 'Сводка не совпадает с количеством мест'
check_json '.summary.total == (.summary.free + .summary.reserved + .summary.occupied)' \
    'Сумма состояний не совпадает с количеством мест'
check_json '
    .status as $status |
    all(.places[];
        .available == ($status == "ACTIVE" and .serviceable and .occupancy == "FREE"))
' 'Неверно рассчитана доступность мест'

case "$MAP_STAGE" in
    PLANNED)
        check_box_absent_on_map "$BOX_ID"
        check_box_absent_on_map "$SECOND_BOX_ID"
        MAP_LABEL='Планирование: у партии пока нет назначенных мест'
        ;;
    RESERVED)
        check_box_on_map "$BOX_ID" RESERVED "$FIRST_PLACE_ID"
        check_box_on_map "$SECOND_BOX_ID" RESERVED "$SECOND_PLACE_ID"
        MAP_LABEL='Досмотр: обе коробки зарезервировали места'
        ;;
    PLACED_FIRST)
        check_box_on_map "$BOX_ID" OCCUPIED "$REPLACEMENT_PLACE_ID"
        check_box_on_map "$SECOND_BOX_ID" RESERVED "$SECOND_PLACE_ID"
        check_free_place_on_map "$FIRST_PLACE_ID"
        MAP_LABEL='Первая коробка размещена, вторая ожидает'
        ;;
    WRITTEN_OFF)
        check_box_on_map "$BOX_ID" OCCUPIED "$REPLACEMENT_PLACE_ID"
        check_box_absent_on_map "$SECOND_BOX_ID"
        check_free_place_on_map "$SECOND_PLACE_ID"
        MAP_LABEL='Списание: место второй коробки освободилось'
        ;;
    MOVING)
        check_box_on_map "$BOX_ID" RESERVED "$SECOND_PLACE_ID"
        check_free_place_on_map "$REPLACEMENT_PLACE_ID"
        MAP_LABEL='Перемещение: новое место зарезервировано, старое свободно'
        ;;
    MOVED)
        check_box_on_map "$BOX_ID" OCCUPIED "$SECOND_PLACE_ID"
        check_free_place_on_map "$REPLACEMENT_PLACE_ID"
        MAP_LABEL='Перемещение завершено: новое место занято'
        ;;
    *)
        echo "ОШИБКА: неизвестный этап карты $MAP_STAGE" >&2
        exit 1
        ;;
esac

printf "${OUTPUT_COLOR}%s\n" "$MAP_LABEL"
jq -r '.summary | "Всего: \(.total); без коробок: \(.free); резерв: \(.reserved); размещено: \(.occupied)",
    "Неисправно: \(.unserviceable); доступно для назначения: \(.available)"' "$RESPONSE"
jq -r --argjson first "$BOX_ID" --argjson second "$SECOND_BOX_ID" '
    .places[] | select(.box.id == $first or .box.id == $second) |
    "Коробка #\(.box.id) → место #\(.id) (\(.rackNo)/\(.shelfNo)/\(.rowNo)): \(.occupancy)"
' "$RESPONSE"
printf "Проверка карты пройдена.${RESET_COLOR}\n"

#!/usr/bin/env bash
# Часть общего сценария: запускается через demo/check-backend.sh.

echo
echo '56. Выбираем свою размещённую коробку для изъятия'
command_line "curl -sS -X GET $BASE_URL/api/depositors/me/batches/$BATCH_ID/boxes -b <applicant-cookies>"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' \
    -X GET "$BASE_URL/api/depositors/me/batches/$BATCH_ID/boxes" \
    -b "$APPLICANT_COOKIES" -c "$APPLICANT_COOKIES")
output
http_status
[ "$STATUS" = '200' ] || { echo 'ОШИБКА: ожидался HTTP 200' >&2; exit 1; }
WITHDRAWAL_BOX_ID=$(jq -er 'first(.[] | select(.status == "PLACED")) | .id' "$RESPONSE")
WITHDRAWAL_PLACE_ID=$(jq -er --argjson id "$WITHDRAWAL_BOX_ID" '.[] | select(.id == $id) | .storagePlace.id' "$RESPONSE")
WITHDRAWAL_JSON=$(jq -cn --argjson batch "$BATCH_ID" --argjson box "$WITHDRAWAL_BOX_ID" --arg date "$(date +%F)" \
    '{batchId:$batch, boxIds:[$box], reason:"Восстановление коллекции (демо)", desiredDate:$date}')

echo
echo '57. Заявка без причины отклоняется'
WITHDRAWAL_BODY="$(jq -c '.reason = " "' <<< "$WITHDRAWAL_JSON")"
command_line "curl -sS -X POST $BASE_URL/api/depositors/me/withdrawal-requests -b <applicant-cookies> -H 'Content-Type: application/json' -d '$WITHDRAWAL_BODY'"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' \
    -X POST "$BASE_URL/api/depositors/me/withdrawal-requests" \
    -b "$APPLICANT_COOKIES" -c "$APPLICANT_COOKIES" \
    -H "$APPLICANT_CSRF_HEADER: $APPLICANT_CSRF_TOKEN" \
    -H 'Content-Type: application/json' -d "$WITHDRAWAL_BODY")
output
http_status
[ "$STATUS" = '400' ] || { echo 'ОШИБКА: ожидался HTTP 400' >&2; exit 1; }

echo
echo '58. Повтор коробки в одном списке отклоняется'
WITHDRAWAL_BODY="$(jq -c '.boxIds = [.boxIds[0], .boxIds[0]]' <<< "$WITHDRAWAL_JSON")"
command_line "curl -sS -X POST $BASE_URL/api/depositors/me/withdrawal-requests -b <applicant-cookies> -H 'Content-Type: application/json' -d '$WITHDRAWAL_BODY'"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' \
    -X POST "$BASE_URL/api/depositors/me/withdrawal-requests" \
    -b "$APPLICANT_COOKIES" -c "$APPLICANT_COOKIES" \
    -H "$APPLICANT_CSRF_HEADER: $APPLICANT_CSRF_TOKEN" \
    -H 'Content-Type: application/json' -d "$WITHDRAWAL_BODY")
output
http_status
[ "$STATUS" = '400' ] || { echo 'ОШИБКА: ожидался HTTP 400' >&2; exit 1; }

echo
echo '59. Списанную коробку изъять нельзя'
WITHDRAWAL_BODY="$(jq -c --argjson box "$SECOND_BOX_ID" '.boxIds = [$box]' <<< "$WITHDRAWAL_JSON")"
command_line "curl -sS -X POST $BASE_URL/api/depositors/me/withdrawal-requests -b <applicant-cookies> -H 'Content-Type: application/json' -d '$WITHDRAWAL_BODY'"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' \
    -X POST "$BASE_URL/api/depositors/me/withdrawal-requests" \
    -b "$APPLICANT_COOKIES" -c "$APPLICANT_COOKIES" \
    -H "$APPLICANT_CSRF_HEADER: $APPLICANT_CSRF_TOKEN" \
    -H 'Content-Type: application/json' -d "$WITHDRAWAL_BODY")
output
http_status
[ "$STATUS" = '409' ] || { echo 'ОШИБКА: ожидался HTTP 409' >&2; exit 1; }

echo
echo '60. Владелец подаёт заявку на изъятие'
WITHDRAWAL_BODY="$WITHDRAWAL_JSON"
command_line "curl -sS -X POST $BASE_URL/api/depositors/me/withdrawal-requests -b <applicant-cookies> -H 'Content-Type: application/json' -d '$WITHDRAWAL_BODY'"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' \
    -X POST "$BASE_URL/api/depositors/me/withdrawal-requests" \
    -b "$APPLICANT_COOKIES" -c "$APPLICANT_COOKIES" \
    -H "$APPLICANT_CSRF_HEADER: $APPLICANT_CSRF_TOKEN" \
    -H 'Content-Type: application/json' -d "$WITHDRAWAL_BODY")
output
http_status
[ "$STATUS" = '201' ] || { echo 'ОШИБКА: ожидался HTTP 201' >&2; exit 1; }
WITHDRAWAL_ID=$(jq -er '.id' "$RESPONSE")
check_json '.status == "SUBMITTED" and .session == null' 'Заявка не подана'

echo
echo '61. Одна коробка не может быть в двух активных заявках'
WITHDRAWAL_BODY="$WITHDRAWAL_JSON"
command_line "curl -sS -X POST $BASE_URL/api/depositors/me/withdrawal-requests -b <applicant-cookies> -H 'Content-Type: application/json' -d '$WITHDRAWAL_BODY'"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' \
    -X POST "$BASE_URL/api/depositors/me/withdrawal-requests" \
    -b "$APPLICANT_COOKIES" -c "$APPLICANT_COOKIES" \
    -H "$APPLICANT_CSRF_HEADER: $APPLICANT_CSRF_TOKEN" \
    -H 'Content-Type: application/json' -d "$WITHDRAWAL_BODY")
output
http_status
[ "$STATUS" = '409' ] || { echo 'ОШИБКА: ожидался HTTP 409' >&2; exit 1; }

echo
echo '62. Депозитор не может рассматривать заявку'
command_line "curl -sS -X POST $BASE_URL/api/curator/withdrawal-requests/$WITHDRAWAL_ID/review -b <applicant-cookies>"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' \
    -X POST "$BASE_URL/api/curator/withdrawal-requests/$WITHDRAWAL_ID/review" \
    -b "$APPLICANT_COOKIES" -c "$APPLICANT_COOKIES" \
    -H "$APPLICANT_CSRF_HEADER: $APPLICANT_CSRF_TOKEN")
output
http_status
[ "$STATUS" = '403' ] || { echo 'ОШИБКА: ожидался HTTP 403' >&2; exit 1; }

echo
echo '63. Нельзя пропустить первичную проверку'
command_line "curl -sS -X POST $BASE_URL/api/admin/withdrawal-requests/$WITHDRAWAL_ID/approve -b <admin-cookies>"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' \
    -X POST "$BASE_URL/api/admin/withdrawal-requests/$WITHDRAWAL_ID/approve" \
    -b "$ADMIN_COOKIES" -c "$ADMIN_COOKIES" \
    -H "$ADMIN_CSRF_HEADER: $ADMIN_CSRF_TOKEN")
output
http_status
[ "$STATUS" = '409' ] || { echo 'ОШИБКА: ожидался HTTP 409' >&2; exit 1; }

echo
echo '64. Куратор видит заявку в очереди'
command_line "curl -sS -X GET $BASE_URL/api/curator/withdrawal-requests?status=SUBMITTED -b <admin-cookies>"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' \
    -X GET "$BASE_URL/api/curator/withdrawal-requests?status=SUBMITTED" \
    -b "$ADMIN_COOKIES" -c "$ADMIN_COOKIES")
output
http_status
[ "$STATUS" = '200' ] || { echo 'ОШИБКА: ожидался HTTP 200' >&2; exit 1; }
check_json 'any(.[]; .id == $id)' 'Заявка отсутствует в очереди' --argjson id "$WITHDRAWAL_ID"

echo
echo '65. Куратор начинает проверку'
command_line "curl -sS -X POST $BASE_URL/api/curator/withdrawal-requests/$WITHDRAWAL_ID/review -b <admin-cookies>"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' \
    -X POST "$BASE_URL/api/curator/withdrawal-requests/$WITHDRAWAL_ID/review" \
    -b "$ADMIN_COOKIES" -c "$ADMIN_COOKIES" \
    -H "$ADMIN_CSRF_HEADER: $ADMIN_CSRF_TOKEN")
output
http_status
[ "$STATUS" = '200' ] || { echo 'ОШИБКА: ожидался HTTP 200' >&2; exit 1; }
check_json '.status == "CURATOR_REVIEW" and .curatorId != null' 'Проверка не начата'

echo
echo '66. Отказ без причины отклоняется'
WITHDRAWAL_BODY='{"reason":" "}'
command_line "curl -sS -X POST $BASE_URL/api/curator/withdrawal-requests/$WITHDRAWAL_ID/reject -b <admin-cookies> -H 'Content-Type: application/json' -d '$WITHDRAWAL_BODY'"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' \
    -X POST "$BASE_URL/api/curator/withdrawal-requests/$WITHDRAWAL_ID/reject" \
    -b "$ADMIN_COOKIES" -c "$ADMIN_COOKIES" \
    -H "$ADMIN_CSRF_HEADER: $ADMIN_CSRF_TOKEN" \
    -H 'Content-Type: application/json' -d "$WITHDRAWAL_BODY")
output
http_status
[ "$STATUS" = '400' ] || { echo 'ОШИБКА: ожидался HTTP 400' >&2; exit 1; }

echo
echo '67. Куратор отклоняет заявку с причиной'
WITHDRAWAL_BODY='{"reason":"Нужно уточнить цель изъятия (демо)"}'
command_line "curl -sS -X POST $BASE_URL/api/curator/withdrawal-requests/$WITHDRAWAL_ID/reject -b <admin-cookies> -H 'Content-Type: application/json' -d '$WITHDRAWAL_BODY'"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' \
    -X POST "$BASE_URL/api/curator/withdrawal-requests/$WITHDRAWAL_ID/reject" \
    -b "$ADMIN_COOKIES" -c "$ADMIN_COOKIES" \
    -H "$ADMIN_CSRF_HEADER: $ADMIN_CSRF_TOKEN" \
    -H 'Content-Type: application/json' -d "$WITHDRAWAL_BODY")
output
http_status
[ "$STATUS" = '200' ] || { echo 'ОШИБКА: ожидался HTTP 200' >&2; exit 1; }
check_json '.status == "REJECTED" and (.rejectionReason | length) > 0' 'Отказ куратора не сохранён'

echo
echo '68. После отказа можно подать новую заявку на ту же коробку'
WITHDRAWAL_BODY="$WITHDRAWAL_JSON"
command_line "curl -sS -X POST $BASE_URL/api/depositors/me/withdrawal-requests -b <applicant-cookies> -H 'Content-Type: application/json' -d '$WITHDRAWAL_BODY'"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' \
    -X POST "$BASE_URL/api/depositors/me/withdrawal-requests" \
    -b "$APPLICANT_COOKIES" -c "$APPLICANT_COOKIES" \
    -H "$APPLICANT_CSRF_HEADER: $APPLICANT_CSRF_TOKEN" \
    -H 'Content-Type: application/json' -d "$WITHDRAWAL_BODY")
output
http_status
[ "$STATUS" = '201' ] || { echo 'ОШИБКА: ожидался HTTP 201' >&2; exit 1; }
WITHDRAWAL_ID=$(jq -er '.id' "$RESPONSE")

echo
echo '69. Начинаем повторную проверку'
command_line "curl -sS -X POST $BASE_URL/api/curator/withdrawal-requests/$WITHDRAWAL_ID/review -b <admin-cookies>"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' \
    -X POST "$BASE_URL/api/curator/withdrawal-requests/$WITHDRAWAL_ID/review" \
    -b "$ADMIN_COOKIES" -c "$ADMIN_COOKIES" \
    -H "$ADMIN_CSRF_HEADER: $ADMIN_CSRF_TOKEN")
output
http_status
[ "$STATUS" = '200' ] || { echo 'ОШИБКА: ожидался HTTP 200' >&2; exit 1; }

echo
echo '70. Куратор передаёт заявку на юридическое утверждение'
command_line "curl -sS -X POST $BASE_URL/api/curator/withdrawal-requests/$WITHDRAWAL_ID/approve -b <admin-cookies>"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' \
    -X POST "$BASE_URL/api/curator/withdrawal-requests/$WITHDRAWAL_ID/approve" \
    -b "$ADMIN_COOKIES" -c "$ADMIN_COOKIES" \
    -H "$ADMIN_CSRF_HEADER: $ADMIN_CSRF_TOKEN")
output
http_status
[ "$STATUS" = '200' ] || { echo 'ОШИБКА: ожидался HTTP 200' >&2; exit 1; }
check_json '.status == "LEGAL_APPROVAL" and .curatorDecisionAt != null' 'Заявка не передана администратору'

echo
echo '71. Администратор видит юридическую очередь'
command_line "curl -sS -X GET $BASE_URL/api/admin/withdrawal-requests?status=LEGAL_APPROVAL -b <admin-cookies>"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' \
    -X GET "$BASE_URL/api/admin/withdrawal-requests?status=LEGAL_APPROVAL" \
    -b "$ADMIN_COOKIES" -c "$ADMIN_COOKIES")
output
http_status
[ "$STATUS" = '200' ] || { echo 'ОШИБКА: ожидался HTTP 200' >&2; exit 1; }
check_json 'any(.[]; .id == $id)' 'Заявка отсутствует в юридической очереди' --argjson id "$WITHDRAWAL_ID"

echo
echo '72. Администратор отклоняет заявку с причиной'
WITHDRAWAL_BODY='{"reason":"Нужно юридическое уточнение (демо)"}'
command_line "curl -sS -X POST $BASE_URL/api/admin/withdrawal-requests/$WITHDRAWAL_ID/reject -b <admin-cookies> -H 'Content-Type: application/json' -d '$WITHDRAWAL_BODY'"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' \
    -X POST "$BASE_URL/api/admin/withdrawal-requests/$WITHDRAWAL_ID/reject" \
    -b "$ADMIN_COOKIES" -c "$ADMIN_COOKIES" \
    -H "$ADMIN_CSRF_HEADER: $ADMIN_CSRF_TOKEN" \
    -H 'Content-Type: application/json' -d "$WITHDRAWAL_BODY")
output
http_status
[ "$STATUS" = '200' ] || { echo 'ОШИБКА: ожидался HTTP 200' >&2; exit 1; }
check_json '.status == "REJECTED" and .adminDecisionAt != null and (.rejectionReason | length) > 0' 'Юридический отказ не сохранён'

echo
echo '73. Подаём заявку для полного сценария выдачи'
WITHDRAWAL_BODY="$WITHDRAWAL_JSON"
command_line "curl -sS -X POST $BASE_URL/api/depositors/me/withdrawal-requests -b <applicant-cookies> -H 'Content-Type: application/json' -d '$WITHDRAWAL_BODY'"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' \
    -X POST "$BASE_URL/api/depositors/me/withdrawal-requests" \
    -b "$APPLICANT_COOKIES" -c "$APPLICANT_COOKIES" \
    -H "$APPLICANT_CSRF_HEADER: $APPLICANT_CSRF_TOKEN" \
    -H 'Content-Type: application/json' -d "$WITHDRAWAL_BODY")
output
http_status
[ "$STATUS" = '201' ] || { echo 'ОШИБКА: ожидался HTTP 201' >&2; exit 1; }
WITHDRAWAL_ID=$(jq -er '.id' "$RESPONSE")

echo
echo '74. Сессию нельзя создать до согласования'
WITHDRAWAL_BODY="{\"plannedDate\":\"$(date +%F)\"}"
command_line "curl -sS -X POST $BASE_URL/api/curator/withdrawal-requests/$WITHDRAWAL_ID/sessions -b <admin-cookies> -H 'Content-Type: application/json' -d '$WITHDRAWAL_BODY'"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' \
    -X POST "$BASE_URL/api/curator/withdrawal-requests/$WITHDRAWAL_ID/sessions" \
    -b "$ADMIN_COOKIES" -c "$ADMIN_COOKIES" \
    -H "$ADMIN_CSRF_HEADER: $ADMIN_CSRF_TOKEN" \
    -H 'Content-Type: application/json' -d "$WITHDRAWAL_BODY")
output
http_status
[ "$STATUS" = '409' ] || { echo 'ОШИБКА: ожидался HTTP 409' >&2; exit 1; }

echo
echo '75. Куратор начинает финальную проверку'
command_line "curl -sS -X POST $BASE_URL/api/curator/withdrawal-requests/$WITHDRAWAL_ID/review -b <admin-cookies>"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' \
    -X POST "$BASE_URL/api/curator/withdrawal-requests/$WITHDRAWAL_ID/review" \
    -b "$ADMIN_COOKIES" -c "$ADMIN_COOKIES" \
    -H "$ADMIN_CSRF_HEADER: $ADMIN_CSRF_TOKEN")
output
http_status
[ "$STATUS" = '200' ] || { echo 'ОШИБКА: ожидался HTTP 200' >&2; exit 1; }

echo
echo '76. Куратор одобряет заявку'
command_line "curl -sS -X POST $BASE_URL/api/curator/withdrawal-requests/$WITHDRAWAL_ID/approve -b <admin-cookies>"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' \
    -X POST "$BASE_URL/api/curator/withdrawal-requests/$WITHDRAWAL_ID/approve" \
    -b "$ADMIN_COOKIES" -c "$ADMIN_COOKIES" \
    -H "$ADMIN_CSRF_HEADER: $ADMIN_CSRF_TOKEN")
output
http_status
[ "$STATUS" = '200' ] || { echo 'ОШИБКА: ожидался HTTP 200' >&2; exit 1; }

echo
echo '77. Администратор даёт окончательное согласие'
command_line "curl -sS -X POST $BASE_URL/api/admin/withdrawal-requests/$WITHDRAWAL_ID/approve -b <admin-cookies>"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' \
    -X POST "$BASE_URL/api/admin/withdrawal-requests/$WITHDRAWAL_ID/approve" \
    -b "$ADMIN_COOKIES" -c "$ADMIN_COOKIES" \
    -H "$ADMIN_CSRF_HEADER: $ADMIN_CSRF_TOKEN")
output
http_status
[ "$STATUS" = '200' ] || { echo 'ОШИБКА: ожидался HTTP 200' >&2; exit 1; }
check_json '.status == "APPROVED" and .adminId != null and .adminDecisionAt != null' 'Заявка не одобрена администратором'

echo
echo '78. Планируем сессию на завтра, коробки пока остаются на месте'
WITHDRAWAL_BODY="{\"plannedDate\":\"$(date -d tomorrow +%F)\"}"
command_line "curl -sS -X POST $BASE_URL/api/curator/withdrawal-requests/$WITHDRAWAL_ID/sessions -b <admin-cookies> -H 'Content-Type: application/json' -d '$WITHDRAWAL_BODY'"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' \
    -X POST "$BASE_URL/api/curator/withdrawal-requests/$WITHDRAWAL_ID/sessions" \
    -b "$ADMIN_COOKIES" -c "$ADMIN_COOKIES" \
    -H "$ADMIN_CSRF_HEADER: $ADMIN_CSRF_TOKEN" \
    -H 'Content-Type: application/json' -d "$WITHDRAWAL_BODY")
output
http_status
[ "$STATUS" = '201' ] || { echo 'ОШИБКА: ожидался HTTP 201' >&2; exit 1; }
WITHDRAWAL_SESSION_ID=$(jq -er '.id' "$RESPONSE")
check_json '.status == "PLANNED" and .requestStatus == "APPROVED" and all(.boxes[]; .status == "PLACED" and .storagePlace != null)' 'Планирование не должно выдавать коробки'

echo
echo '79. У заявки может быть только одна сессия'
WITHDRAWAL_BODY="{\"plannedDate\":\"$(date +%F)\"}"
command_line "curl -sS -X POST $BASE_URL/api/curator/withdrawal-requests/$WITHDRAWAL_ID/sessions -b <admin-cookies> -H 'Content-Type: application/json' -d '$WITHDRAWAL_BODY'"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' \
    -X POST "$BASE_URL/api/curator/withdrawal-requests/$WITHDRAWAL_ID/sessions" \
    -b "$ADMIN_COOKIES" -c "$ADMIN_COOKIES" \
    -H "$ADMIN_CSRF_HEADER: $ADMIN_CSRF_TOKEN" \
    -H 'Content-Type: application/json' -d "$WITHDRAWAL_BODY")
output
http_status
[ "$STATUS" = '409' ] || { echo 'ОШИБКА: ожидался HTTP 409' >&2; exit 1; }

echo
echo '80. До даты сессии выдавать коробки нельзя'
command_line "curl -sS -X POST $BASE_URL/api/curator/withdrawal-sessions/$WITHDRAWAL_SESSION_ID/complete -b <admin-cookies>"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' \
    -X POST "$BASE_URL/api/curator/withdrawal-sessions/$WITHDRAWAL_SESSION_ID/complete" \
    -b "$ADMIN_COOKIES" -c "$ADMIN_COOKIES" \
    -H "$ADMIN_CSRF_HEADER: $ADMIN_CSRF_TOKEN")
output
http_status
[ "$STATUS" = '409' ] || { echo 'ОШИБКА: ожидался HTTP 409' >&2; exit 1; }

echo
echo '81. Депозитор не может завершать сессию'
command_line "curl -sS -X POST $BASE_URL/api/curator/withdrawal-sessions/$WITHDRAWAL_SESSION_ID/complete -b <applicant-cookies>"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' \
    -X POST "$BASE_URL/api/curator/withdrawal-sessions/$WITHDRAWAL_SESSION_ID/complete" \
    -b "$APPLICANT_COOKIES" -c "$APPLICANT_COOKIES" \
    -H "$APPLICANT_CSRF_HEADER: $APPLICANT_CSRF_TOKEN")
output
http_status
[ "$STATUS" = '403' ] || { echo 'ОШИБКА: ожидался HTTP 403' >&2; exit 1; }

echo
echo '82. Владелец видит одобрение и запланированную сессию'
command_line "curl -sS -X GET $BASE_URL/api/depositors/me/withdrawal-requests/$WITHDRAWAL_ID -b <applicant-cookies>"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' \
    -X GET "$BASE_URL/api/depositors/me/withdrawal-requests/$WITHDRAWAL_ID" \
    -b "$APPLICANT_COOKIES" -c "$APPLICANT_COOKIES")
output
http_status
[ "$STATUS" = '200' ] || { echo 'ОШИБКА: ожидался HTTP 200' >&2; exit 1; }
check_json '.status == "APPROVED" and .session.status == "PLANNED"' 'Владелец не видит план сессии'

echo
echo '83. Переносим сессию на сегодня'
WITHDRAWAL_BODY="{\"plannedDate\":\"$(date +%F)\"}"
command_line "curl -sS -X PATCH $BASE_URL/api/curator/withdrawal-sessions/$WITHDRAWAL_SESSION_ID -b <admin-cookies> -H 'Content-Type: application/json' -d '$WITHDRAWAL_BODY'"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' \
    -X PATCH "$BASE_URL/api/curator/withdrawal-sessions/$WITHDRAWAL_SESSION_ID" \
    -b "$ADMIN_COOKIES" -c "$ADMIN_COOKIES" \
    -H "$ADMIN_CSRF_HEADER: $ADMIN_CSRF_TOKEN" \
    -H 'Content-Type: application/json' -d "$WITHDRAWAL_BODY")
output
http_status
[ "$STATUS" = '200' ] || { echo 'ОШИБКА: ожидался HTTP 200' >&2; exit 1; }
check_json '.status == "PLANNED" and .requestStatus == "APPROVED"' 'Перенос даты изменил состояние выдачи'

echo
echo '84. Сохраняем количество доступных мест перед выдачей'
command_line "curl -sS -X GET $BASE_URL/api/curator/chambers/$CHAMBER_ID/places -b <admin-cookies>"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' \
    -X GET "$BASE_URL/api/curator/chambers/$CHAMBER_ID/places" \
    -b "$ADMIN_COOKIES" -c "$ADMIN_COOKIES")
http_status
[ "$STATUS" = '200' ] || { output; echo 'ОШИБКА: ожидался HTTP 200' >&2; exit 1; }
FREE_BEFORE_WITHDRAWAL=$(jq -er '.summary.available' "$RESPONSE")
printf "${OUTPUT_COLOR}Доступных мест перед выдачей: %s${RESET_COLOR}\n" "$FREE_BEFORE_WITHDRAWAL"

echo
echo '85. Завершаем выдачу: триггер изымает коробки и выполняет заявку'
command_line "curl -sS -X POST $BASE_URL/api/curator/withdrawal-sessions/$WITHDRAWAL_SESSION_ID/complete -b <admin-cookies>"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' \
    -X POST "$BASE_URL/api/curator/withdrawal-sessions/$WITHDRAWAL_SESSION_ID/complete" \
    -b "$ADMIN_COOKIES" -c "$ADMIN_COOKIES" \
    -H "$ADMIN_CSRF_HEADER: $ADMIN_CSRF_TOKEN")
output
http_status
[ "$STATUS" = '200' ] || { echo 'ОШИБКА: ожидался HTTP 200' >&2; exit 1; }
check_json '.status == "COMPLETED" and .completedAt != null and .requestStatus == "FULFILLED"' 'Сессия или заявка не завершена'
check_json 'all(.boxes[]; .status == "WITHDRAWN" and .storagePlace == null and .withdrawnAt != null)' 'Коробки не изъяты или место не освобождено'

echo
echo '86. Повторное завершение запрещено'
command_line "curl -sS -X POST $BASE_URL/api/curator/withdrawal-sessions/$WITHDRAWAL_SESSION_ID/complete -b <admin-cookies>"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' \
    -X POST "$BASE_URL/api/curator/withdrawal-sessions/$WITHDRAWAL_SESSION_ID/complete" \
    -b "$ADMIN_COOKIES" -c "$ADMIN_COOKIES" \
    -H "$ADMIN_CSRF_HEADER: $ADMIN_CSRF_TOKEN")
output
http_status
[ "$STATUS" = '409' ] || { echo 'ОШИБКА: ожидался HTTP 409' >&2; exit 1; }

echo
echo '87. Владелец видит выполненную заявку'
command_line "curl -sS -X GET $BASE_URL/api/depositors/me/withdrawal-requests/$WITHDRAWAL_ID -b <applicant-cookies>"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' \
    -X GET "$BASE_URL/api/depositors/me/withdrawal-requests/$WITHDRAWAL_ID" \
    -b "$APPLICANT_COOKIES" -c "$APPLICANT_COOKIES")
output
http_status
[ "$STATUS" = '200' ] || { echo 'ОШИБКА: ожидался HTTP 200' >&2; exit 1; }
check_json '.status == "FULFILLED" and .session.status == "COMPLETED"' 'Заявка не выполнена'

echo
echo '88. В истории владельца есть выполненная заявка'
command_line "curl -sS -X GET $BASE_URL/api/depositors/me/withdrawal-requests -b <applicant-cookies>"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' \
    -X GET "$BASE_URL/api/depositors/me/withdrawal-requests" \
    -b "$APPLICANT_COOKIES" -c "$APPLICANT_COOKIES")
output
http_status
[ "$STATUS" = '200' ] || { echo 'ОШИБКА: ожидался HTTP 200' >&2; exit 1; }
check_json 'any(.[]; .id == $id and .status == "FULFILLED")' 'Заявка отсутствует в истории' --argjson id "$WITHDRAWAL_ID"

echo
echo '89. Карта показывает освобождённое место'
command_line "curl -sS -X GET $BASE_URL/api/curator/chambers/$CHAMBER_ID/places -b <admin-cookies>"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' \
    -X GET "$BASE_URL/api/curator/chambers/$CHAMBER_ID/places" \
    -b "$ADMIN_COOKIES" -c "$ADMIN_COOKIES")
http_status
[ "$STATUS" = '200' ] || { output; echo 'ОШИБКА: ожидался HTTP 200' >&2; exit 1; }
check_json 'any(.places[]; .id == $id and .occupancy == "FREE" and .box == null and .available)' 'Изъятая коробка всё ещё занимает место' --argjson id "$WITHDRAWAL_PLACE_ID"
FREE_AFTER_WITHDRAWAL=$(jq -er '.summary.available' "$RESPONSE")
[ "$FREE_AFTER_WITHDRAWAL" -eq "$((FREE_BEFORE_WITHDRAWAL + 1))" ] || {
    echo 'ОШИБКА: количество свободных мест не увеличилось' >&2
    exit 1
}
printf "${OUTPUT_COLOR}Выдача освободила место #%s. Доступных мест: %s → %s.${RESET_COLOR}\n" \
    "$WITHDRAWAL_PLACE_ID" "$FREE_BEFORE_WITHDRAWAL" "$FREE_AFTER_WITHDRAWAL"

echo
echo '90. Итог приёма партии сохранился после изъятия'
command_line "curl -sS -X GET $BASE_URL/api/depositors/me/batches/$BATCH_ID -b <applicant-cookies>"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' \
    -X GET "$BASE_URL/api/depositors/me/batches/$BATCH_ID" \
    -b "$APPLICANT_COOKIES" -c "$APPLICANT_COOKIES")
output
http_status
[ "$STATUS" = '200' ] || { echo 'ОШИБКА: ожидался HTTP 200' >&2; exit 1; }
check_json '.status == "PARTIALLY_PLACED"' 'Изъятие изменило исторический итог приёма'

echo
echo '91. Изъятую коробку нельзя включить в новую заявку'
WITHDRAWAL_BODY="$WITHDRAWAL_JSON"
command_line "curl -sS -X POST $BASE_URL/api/depositors/me/withdrawal-requests -b <applicant-cookies> -H 'Content-Type: application/json' -d '$WITHDRAWAL_BODY'"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' \
    -X POST "$BASE_URL/api/depositors/me/withdrawal-requests" \
    -b "$APPLICANT_COOKIES" -c "$APPLICANT_COOKIES" \
    -H "$APPLICANT_CSRF_HEADER: $APPLICANT_CSRF_TOKEN" \
    -H 'Content-Type: application/json' -d "$WITHDRAWAL_BODY")
output
http_status
[ "$STATUS" = '409' ] || { echo 'ОШИБКА: ожидался HTTP 409' >&2; exit 1; }

echo
echo '92. Без авторизации история изъятий недоступна'
command_line "curl -sS -X GET $BASE_URL/api/depositors/me/withdrawal-requests"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' \
    -X GET "$BASE_URL/api/depositors/me/withdrawal-requests")
output
http_status
[ "$STATUS" = '401' ] || { echo 'ОШИБКА: ожидался HTTP 401' >&2; exit 1; }

. "$DEMO_DIR/withdrawal/ownership.sh"

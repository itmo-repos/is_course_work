#!/usr/bin/env bash
# Часть общего сценария: запускается через demo/check-backend.sh.

echo 'Депозитор читает историю своей партии от формирования до изъятия'
command_line "curl -sS $BASE_URL/api/depositors/me/batches/$BATCH_ID/history?size=200 -b <applicant-cookies>"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' -b "$APPLICANT_COOKIES" \
    "$BASE_URL/api/depositors/me/batches/$BATCH_ID/history?size=200")
output
http_status
[ "$STATUS" = 200 ] || exit 1
check_json '.items[0].action=="BATCH_CREATED" and all(.items[]; keys==["action","entityId","entityType","id","message","occurredAt"])' 'История раскрывает внутренние поля или нарушен порядок'
check_json '[.items[].action] as $actions | all(["BATCH_CONFIRMED","BATCH_IN_TRANSIT","BATCH_ARRIVED","BATCH_INSPECTION","BOX_PLACED","BOX_WRITTEN_OFF","BOX_MOVE_STARTED","INTAKE_COMPLETED","WITHDRAWAL_FULFILLED","BOX_WITHDRAWN"][]; . as $a | $actions | index($a)!=null)' 'В истории потеряны этапы партии'
FIRST_EVENT_ID=$(jq -er '.items[0].id' "$RESPONSE")

echo
echo 'Администратор видит аудит по партии вместе с автором и техническими деталями'
AUDIT_FROM='2000-01-01T00:00:00Z'
AUDIT_TO=$(date -u -d tomorrow +%Y-%m-%dT%H:%M:%SZ)
command_line "curl -sS '$BASE_URL/api/admin/audit?batchId=$BATCH_ID&from=$AUDIT_FROM&to=$AUDIT_TO&size=200' -b <admin-cookies>"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' -b "$ADMIN_COOKIES" \
    "$BASE_URL/api/admin/audit?batchId=$BATCH_ID&from=$AUDIT_FROM&to=$AUDIT_TO&size=200")
output
http_status
[ "$STATUS" = 200 ] || exit 1
check_json 'all(.items[]; .batchId==$id) and any(.items[]; .action=="BOX_PLACED" and .details!=null and .actorType=="EMPLOYEE")' 'Не найдены автор и детали размещения' --argjson id "$BATCH_ID"

echo
echo 'Депозитору недоступен полный аудит: HTTP 403'
command_line "curl -sS '$BASE_URL/api/admin/audit?from=$AUDIT_FROM&to=$AUDIT_TO' -b <applicant-cookies>"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' -b "$APPLICANT_COOKIES" \
    "$BASE_URL/api/admin/audit?from=$AUDIT_FROM&to=$AUDIT_TO")
output
http_status
[ "$STATUS" = 403 ] || exit 1

echo
echo 'Чужая партия скрыта: HTTP 404'
command_line "curl -sS $BASE_URL/api/depositors/me/batches/1/history -b <applicant-cookies>"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' -b "$APPLICANT_COOKIES" \
    "$BASE_URL/api/depositors/me/batches/1/history")
output
http_status
[ "$STATUS" = 404 ] || exit 1

echo
echo 'Депозитор получает личные бизнес-уведомления'
command_line "curl -sS $BASE_URL/api/notifications?size=200 -b <applicant-cookies>"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' -b "$APPLICANT_COOKIES" "$BASE_URL/api/notifications?size=200")
output
http_status
[ "$STATUS" = 200 ] || exit 1
check_json 'any(.items[]; .type=="CONTRACT") and any(.items[]; .type=="BATCH") and any(.items[]; .type=="WITHDRAWAL") and all(.items[]; .type!="CLIMATE_ALERT" and .eventId!=null)' 'Неполная рассылка или чужие климатические уведомления'
OWN_NOTIFICATION_ID=$(jq -er '.items[0].id' "$RESPONSE")

echo
echo 'Отмечаем своё уведомление прочитанным'
command_line "curl -sS -X PATCH $BASE_URL/api/notifications/$OWN_NOTIFICATION_ID/read -b <applicant-cookies>"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' -X PATCH \
    "$BASE_URL/api/notifications/$OWN_NOTIFICATION_ID/read" -b "$APPLICANT_COOKIES" \
    -H "$APPLICANT_CSRF_HEADER: $APPLICANT_CSRF_TOKEN")
output
http_status
[ "$STATUS" = 200 ] || exit 1
check_json '.read==true' 'Уведомление не прочитано'

echo
echo 'Администратор не может отметить чужое уведомление, даже имея ADMIN: HTTP 404'
command_line "curl -sS -X PATCH $BASE_URL/api/notifications/$OWN_NOTIFICATION_ID/read -b <admin-cookies>"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' -X PATCH \
    "$BASE_URL/api/notifications/$OWN_NOTIFICATION_ID/read" -b "$ADMIN_COOKIES" \
    -H "$ADMIN_CSRF_HEADER: $ADMIN_CSRF_TOKEN")
output
http_status
[ "$STATUS" = 404 ] || exit 1

echo
echo 'Фильтр непрочитанных больше не возвращает прочитанное уведомление'
command_line "curl -sS '$BASE_URL/api/notifications?unreadOnly=true&size=200' -b <applicant-cookies>"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' -b "$APPLICANT_COOKIES" \
    "$BASE_URL/api/notifications?unreadOnly=true&size=200")
output
http_status
[ "$STATUS" = 200 ] || exit 1
check_json 'all(.items[]; .read==false and .id!=$id)' 'Прочитанное осталось в непрочитанных' --argjson id "$OWN_NOTIFICATION_ID"

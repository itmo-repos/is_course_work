#!/usr/bin/env bash
# Самостоятельный сценарий работы хранилища на исходных тестовых данных.
section '1. Сотрудники и роли'
login ADMIN i.ivanovich@example.com
step ADMIN 'Администратор смотрит сотрудников и доступные роли'
request GET /api/admin/roles 200
request GET /api/admin/employees 200
# Сохраняем роли сотрудника #5, чтобы в конце вернуть их без потери исходных прав.
ORIGINAL_ROLES=$(jq -ce '.items[] | select(.id == 5) | .roles' "$RESPONSE")
check_json 'any(.items[]; .id == 5 and .active)' 'Для демо нужен активный сотрудник #5'
step ADMIN 'Для приёмки коллекции сотруднику #5 назначена дополнительная роль CURATOR'
CURATOR_ROLES=$(jq -cn --argjson roles "$ORIGINAL_ROLES" '{roles:($roles + ["CURATOR"] | unique)}')
request PUT /api/admin/employees/5/roles 200 "$CURATOR_ROLES"
login CURATOR k.vasil@example.com

next_part
section '2. Пропуска и журнал проходов'
login SECURITY p.petrova@example.com
CHAMBER_ID=1
step SECURITY 'Охрана выдаёт сотруднику пропуск в камеру'
request POST /api/security/passes 201 "{\"employeeId\":5,\"validFrom\":\"$(date -u -d '1 minute ago' +%Y-%m-%dT%H:%M:%SZ)\",\"validTo\":\"$(date -u -d '1 hour' +%Y-%m-%dT%H:%M:%SZ)\",\"chamberIds\":[1],\"comment\":\"Демонстрация доступа\"}"
PASS_ID=$(jq -er '.pass.id' "$RESPONSE")
PASS_CODE=$(jq -er '.code' "$RESPONSE")
step SECURITY 'Охрана регистрирует вход и выход по QR-коду'
request POST /api/security/access-events 201 "{\"passCode\":\"$PASS_CODE\",\"chamberId\":1,\"direction\":\"IN\"}"
request POST /api/security/access-events 201 "{\"passCode\":\"$PASS_CODE\",\"chamberId\":1,\"direction\":\"OUT\"}"
step SECURITY 'Пропуск отозван, история проходов сохранена'
request POST "/api/security/passes/$PASS_ID/revoke" 200
request GET "/api/security/access-events?passId=$PASS_ID&from=$(date -u -d yesterday +%Y-%m-%dT%H:%M:%SZ)&to=$(date -u -d tomorrow +%Y-%m-%dT%H:%M:%SZ)" 200
check_json '(.items | length) == 2' 'В журнале отсутствуют вход или выход'
next_part
section '3. Климат и шлюз'
login ENGINEER m.serg@example.com
step ENGINEER 'Инженер открывает климат камеры, в которой хранится коллекция'
request GET "/api/engineer/chambers/$CHAMBER_ID" 200
CLIMATE_ORIGINAL_SETTINGS=$(jq -ce '{status,climateControlled,minTemperature,maxTemperature,minHumidity,maxHumidity}' "$RESPONSE")
step ADMIN 'Администратор задаёт допустимые температуру и влажность'
request PUT "/api/admin/chambers/$CHAMBER_ID/settings" 200 '{"status":"ACTIVE","climateControlled":true,"minTemperature":-20,"maxTemperature":-16,"minHumidity":20,"maxHumidity":30}'
step ADMIN 'Администратор выдаёт ключ шлюзу этой камеры'
request POST "/api/admin/chambers/$CHAMBER_ID/gateway-keys" 201 '{"name":"Шлюз демо-коллекции"}'
GATEWAY_TOKEN=$(jq -er '.token' "$RESPONSE")
GATEWAY_KEY_ID=$(jq -er '.key.id' "$RESPONSE")
step GATEWAY 'Датчики сначала передают норму, затем превышение обоих порогов'
GATEWAY_TIME=$(date -u -d '1 minute ago' +%s)
request POST /api/gateway/readings 200 "{\"measuredAt\":\"$(date -u -d "@$GATEWAY_TIME" +%Y-%m-%dT%H:%M:%SZ)\",\"temperature\":-18,\"humidity\":25}"
request POST /api/gateway/readings 200 "{\"measuredAt\":\"$(date -u -d "@$((GATEWAY_TIME + 1))" +%Y-%m-%dT%H:%M:%SZ)\",\"temperature\":-10,\"humidity\":45}"
GATEWAY_BAD_ID=$(jq -er '.id' "$RESPONSE")
step ENGINEER 'Нарушение появилось в истории и в личных уведомлениях инженера'
CLIMATE_PERIOD="from=$(date -u -d '1 day ago' +%Y-%m-%dT%H:%M:%SZ)&to=$(date -u -d tomorrow +%Y-%m-%dT%H:%M:%SZ)"
request GET "/api/engineer/chambers/$CHAMBER_ID/readings?$CLIMATE_PERIOD&size=5" 200
request GET /api/notifications 200
check_json 'any(.items[]; .readingId == $id)' 'Инженер не получил климатическое уведомление' --argjson id "$GATEWAY_BAD_ID"
CLIMATE_NOTIFICATION_ID=$(jq -er --argjson id "$GATEWAY_BAD_ID" 'first(.items[] | select(.readingId == $id)) | .id' "$RESPONSE")
request PATCH "/api/notifications/$CLIMATE_NOTIFICATION_ID/read" 200
step ENGINEER 'Инженер скачивает историю показаний в CSV'
request GET "/api/engineer/chambers/$CHAMBER_ID/readings.csv?$CLIMATE_PERIOD" 200 '' "$TEMP_DIR/climate.csv"
head -n 3 "$TEMP_DIR/climate.csv"
step ADMIN 'Шлюз отключён, прежние настройки восстановлены; история измерений сохранена'
request DELETE "/api/admin/gateway-keys/$GATEWAY_KEY_ID" 204
unset GATEWAY_TOKEN GATEWAY_KEY_ID
request PUT "/api/admin/chambers/$CHAMBER_ID/settings" 200 "$CLIMATE_ORIGINAL_SETTINGS"
unset CLIMATE_ORIGINAL_SETTINGS


next_part
section '4. Аудит и административные отчёты'
step ADMIN 'Администратор видит действия сотрудников и шлюза в полном аудите'
REPORT_FROM='2000-01-01T00:00:00Z'
REPORT_TO=$(date -u -d tomorrow +%Y-%m-%dT%H:%M:%SZ)
request GET "/api/admin/audit?from=$REPORT_FROM&to=$REPORT_TO&size=100" 200
check_json '.total > 0' 'Аудит действий хранилища пуст'
step ADMIN 'Пять отчётов показывают результат: места, депозитор, перевозка, выдача и климат'
request GET /api/admin/reports/occupancy 200
request GET "/api/admin/reports/depositors?depositorId=1" 200
request GET "/api/admin/reports/shipments?batchId=1&from=$REPORT_FROM&to=$REPORT_TO" 200
request GET "/api/admin/reports/withdrawals?batchId=1&from=$REPORT_FROM&to=$REPORT_TO" 200
check_json '.total == 1 and .items[0].requestId == $id' 'Выдача отсутствует в отчёте' --argjson id 1
request GET "/api/admin/reports/climate-incidents?chamberId=$CHAMBER_ID&from=$REPORT_FROM&to=$REPORT_TO" 200
check_json 'any(.items[]; .parameter == "BOTH")' 'Климатический инцидент отсутствует в отчёте'
step ADMIN 'Отчёт об изъятиях можно выгрузить в CSV'
request GET "/api/admin/reports/withdrawals.csv?batchId=1&from=$REPORT_FROM&to=$REPORT_TO" 200 '' "$TEMP_DIR/withdrawals.csv"
head -n 3 "$TEMP_DIR/withdrawals.csv"
login APPLICANT vir@example.org
step APPLICANT 'Депозитор не может читать административный аудит'
request GET "/api/admin/audit?from=$REPORT_FROM&to=$REPORT_TO" 403

next_part
section '5. Завершение и отзыв сессии сотрудника'
step ADMIN 'Приёмка закончена — администратор возвращает сотруднику исходные роли'
request PUT /api/admin/employees/5/roles 200 "$(jq -cn --argjson roles "$ORIGINAL_ROLES" '{roles:$roles}')"
unset ORIGINAL_ROLES
step ADMIN 'Отключение учётной записи сотрудника отзывает его действующую сессию'
STAFF_DISABLED=1
request PATCH /api/admin/employees/5/status 200 '{"active":false}'
step CURATOR 'В прежней сессии сотрудник больше не авторизован'
request GET /api/auth/me 401
step ADMIN 'Администратор вновь включает сотрудника; для работы потребуется новый вход'
request PATCH /api/admin/employees/5/status 200 '{"active":true}'
STAFF_DISABLED=0
echo "Сценарий хранилища завершён: $STEP шагов."

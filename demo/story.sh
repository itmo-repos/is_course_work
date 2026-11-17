#!/usr/bin/env bash
# Один сквозной сценарий. Подключается из check-backend.sh.

section '1. Новая организация получает право передать коллекцию'
step PUBLIC 'Представитель организации смотрит каталог и справочники для паспортов'
request GET '/api/samples?species=Triticum&country=RU' 200
request GET /api/samples/species 200
request GET /api/samples/countries 200

# CSRF — техническая подготовка регистрации, без отдельного шага в показе.
APPLICANT_COOKIES="$TEMP_DIR/applicant-cookies.txt"
csrf APPLICANT
step APPLICANT 'Представитель регистрирует организацию: указывает контактный email и задаёт пароль'
APPLICATION_JSON=$(jq -cn --arg run "$RUN_ID" --arg email "$APPLICANT_EMAIL" \
    '{legalName:("Демо-коллекция "+$run),countryCode:"RU",registrationNumber:("DEMO-"+$run),legalAddress:"Санкт-Петербург, Университетская набережная, 7",contactPerson:"Представитель коллекции",contactEmail:$email,contactPhone:"+78120000000",password:"Demo123!"}')
request POST /api/depositors/applications 201 "$APPLICATION_JSON"
APPLICANT_ID=$(jq -er '.id' "$RESPONSE")
check_json '.status == "NEW_REQUEST"' 'Заявка не зарегистрирована'
login ADMIN i.ivanovich@example.com
step ADMIN 'Новая заявка появилась в очереди администратора'
request GET '/api/admin/depositors?status=NEW_REQUEST' 200
check_json 'any(.[]; .id == $id)' 'Заявка отсутствует в очереди' --argjson id "$APPLICANT_ID"
step ADMIN 'Администратор одобряет сотрудничество — можно подписывать договор'
request POST "/api/admin/depositors/$APPLICANT_ID/approve" 200
step APPLICANT 'Депозитор входит по email и паролю, получает договор и загружает тестовый PDF'
AUTH_DEMO=1
login APPLICANT "$APPLICANT_EMAIL"
request GET /api/depositors/me/contract 200 '' "$TEMP_DIR/contract.pdf"
AUTH_DEMO=0
# Для демонстрации загрузки документа PDF служит имитацией подписанного скана.
UPLOAD_FILE="$TEMP_DIR/contract.pdf"
request POST /api/depositors/me/contract/scan 200
unset UPLOAD_FILE
step ADMIN 'Администратор открывает скан; подпись нужно исправить'
request GET "/api/admin/depositors/$APPLICANT_ID/contract/scan" 200 '' "$TEMP_DIR/admin-scan.pdf"
request POST "/api/admin/depositors/$APPLICANT_ID/contract/reject" 200 '{"reason":"Не хватает подписи на последней странице"}'
request POST "/api/admin/depositors/$APPLICANT_ID/contract/return-for-signing" 200
step APPLICANT 'После замечания депозитор повторно загружает скан'
UPLOAD_FILE="$TEMP_DIR/contract.pdf"
request POST /api/depositors/me/contract/scan 200
unset UPLOAD_FILE
step ADMIN 'Исправленный договор принят — организация становится ACTIVE'
request POST "/api/admin/depositors/$APPLICANT_ID/contract/verify" 200
check_json '.status == "ACTIVE"' 'Договор не активирован'

next_part
section '2. Администратор назначает куратора, депозитор готовит партию'
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
step APPLICANT 'В справочнике нет нужного вида — депозитор добавляет его'
SPECIES_NAME="Demo species $RUN_ID"
request POST /api/depositors/me/species 201 "$(jq -cn --arg name "$SPECIES_NAME" '{latinName:$name,localName:"Демонстрационный вид",family:"Demoaceae"}')"
SPECIES_ID=$(jq -er '.id' "$RESPONSE")
BATCH_JSON=$(jq -cn --argjson species "$SPECIES_ID" --arg date "$(date +%F)" \
    '{desiredShipmentDate:$date,boxes:[{samples:[{speciesId:$species,originCountryCode:"RU",collectionYear:2025,seedQuantity:100,note:"Коллекция для восстановления"}]},{samples:[{speciesId:$species,originCountryCode:"NO",collectionYear:2024,seedQuantity:200,note:"Резервная коробка"}]}]}')
step APPLICANT 'Депозитор составляет партию: две коробки с паспортами образцов'
request POST /api/depositors/me/batches 201 "$BATCH_JSON"
BATCH_ID=$(jq -er '.id' "$RESPONSE")
step CURATOR 'Партия появилась в очереди куратора'
request GET '/api/curator/batches?status=FORMED' 200
check_json 'any(.[]; .id == $id)' 'Партия отсутствует в очереди' --argjson id "$BATCH_ID"
step CURATOR 'Куратор просит уточнить паспорт второй коробки'
request POST "/api/curator/batches/$BATCH_ID/reject" 200 '{"reason":"Уточните примечание в паспорте второй коробки"}'
step APPLICANT 'Депозитор исправляет паспорт и повторно отправляет партию'
BATCH_JSON=$(jq -c '.boxes[1].samples[0].note = "Резервная коробка: упаковка требует досмотра"' <<< "$BATCH_JSON")
request PUT "/api/depositors/me/batches/$BATCH_ID" 200 "$BATCH_JSON"
step CURATOR 'Куратор подтверждает партию — коробкам присвоены штрихкоды'
request POST "/api/curator/batches/$BATCH_ID/confirm" 200
BOX_ID=$(jq -er '.boxes[0].id' "$RESPONSE")
SECOND_BOX_ID=$(jq -er '.boxes[1].id' "$RESPONSE")
BARCODE=$(jq -er '.boxes[0].barcode' "$RESPONSE")
ACCESSION_CODE=$(jq -er '.boxes[0].samples[0].accessionCode' "$RESPONSE")
step APPLICANT 'Депозитор скачивает этикетку Code 128 для первой коробки'
request GET "/api/depositors/me/batches/$BATCH_ID/boxes/$BOX_ID/barcode" 200 '' "$TEMP_DIR/barcode.svg"

next_part
section '3. Куратор планирует приём, охрана оформляет проход'
step CURATOR 'Куратор выбирает камеру со свободными местами'
request GET /api/curator/chambers 200
CHAMBER_ID=$(jq -er 'first(.[] | select(.freePlaceCount >= 3)) | .id' "$RESPONSE")
step CURATOR 'Приём назначен на сегодня; вместе с планом выдан QR-пропуск'
request POST "/api/curator/batches/$BATCH_ID/intake-sessions" 201 "{\"chamberId\":$CHAMBER_ID,\"plannedDate\":\"$(date +%F)\"}"
SESSION_ID=$(jq -er '.id' "$RESPONSE")
INTAKE_PASS_ID=$(jq -er '.issuedPass.pass.id' "$RESPONSE")
INTAKE_PASS_CODE=$(jq -er '.issuedPass.code' "$RESPONSE")
jq -er '.issuedPass.qrSvg' "$RESPONSE" > "$TEMP_DIR/intake-pass.svg"
check_json 'all(.boxes[]; .storagePlace == null)' 'Планирование преждевременно заняло места'
step CURATOR 'Куратор отмечает отправку и прибытие партии по данным перевозчика'
request PATCH "/api/curator/batches/$BATCH_ID/tracking-status" 200 '{"status":"IN_TRANSIT","trackingNumber":"DEMO-TRACK"}'
request PATCH "/api/curator/batches/$BATCH_ID/tracking-status" 200 '{"status":"ARRIVED"}'
login SECURITY p.petrova@example.com
step SECURITY 'Охрана сканирует QR и регистрирует вход куратора в камеру'
request POST /api/security/access-events 201 "{\"passCode\":\"$INTAKE_PASS_CODE\",\"chamberId\":$CHAMBER_ID,\"direction\":\"IN\",\"comment\":\"Приём демо-коллекции\"}"
step SECURITY 'Для сопровождающего выдан отдельный гостевой пропуск'
request POST /api/security/passes 201 "{\"validFrom\":\"$(date -u -d '1 minute ago' +%Y-%m-%dT%H:%M:%SZ)\",\"validTo\":\"$(date -u -d '1 hour' +%Y-%m-%dT%H:%M:%SZ)\",\"chamberIds\":[$CHAMBER_ID],\"comment\":\"Сопровождение коллекции\"}"
GUEST_PASS_ID=$(jq -er '.pass.id' "$RESPONSE")

next_part
section '4. Досмотр, размещение и публикация образцов в каталоге'
step CURATOR 'По штрихкоду куратор находит всю прибывшую партию'
request GET "/api/curator/batches/by-barcode/$BARCODE" 200
step CURATOR 'Куратор начинает досмотр — система резервирует места коробкам'
request POST "/api/curator/batches/by-barcode/$BARCODE/arrive" 200
request GET "/api/curator/intake-sessions/$SESSION_ID" 200
FIRST_PLACE_ID=$(jq -er '.boxes[0].storagePlace.id' "$RESPONSE")
SECOND_PLACE_ID=$(jq -er '.boxes[1].storagePlace.id' "$RESPONSE")
step CURATOR 'Первой коробке подобрано другое свободное место'
request GET "/api/curator/chambers/$CHAMBER_ID/free-places" 200
REPLACEMENT_PLACE_ID=$(jq -er '.[0].id' "$RESPONSE")
request PATCH "/api/curator/boxes/$BOX_ID/storage-place" 200 "{\"storagePlaceId\":$REPLACEMENT_PLACE_ID}"
step CURATOR 'Первая коробка размещена; у второй при досмотре обнаружено повреждение'
request POST "/api/curator/boxes/$BOX_ID/place" 200
step SECURITY 'Работа в камере закончена — охрана регистрирует выход куратора'
request POST /api/security/access-events 201 "{\"passCode\":\"$INTAKE_PASS_CODE\",\"chamberId\":$CHAMBER_ID,\"direction\":\"OUT\"}"
step CURATOR 'Куратор оформляет списание повреждённой коробки и закрывает приём'
request POST "/api/curator/boxes/$SECOND_BOX_ID/write-off" 200 '{"reason":"При досмотре обнаружено повреждение упаковки"}'
step CURATOR 'Обработка обеих коробок автоматически завершила приём'
request GET "/api/curator/intake-sessions/$SESSION_ID" 200
check_json '.status == "COMPLETED" and .batchStatus == "PARTIALLY_PLACED"' 'Приём не завершился'
step APPLICANT 'Депозитор видит результат и точные координаты размещённой коробки'
request GET "/api/depositors/me/batches/$BATCH_ID/boxes" 200
check_json 'any(.[]; .id == $id and .status == "PLACED" and .storagePlace != null)' 'Владелец не видит размещённую коробку' --argjson id "$BOX_ID"
step PUBLIC 'Образец первой коробки появился в публичном каталоге без координат хранения'
SPECIES_QUERY=$(jq -rn --arg name "$SPECIES_NAME" '$name | @uri')
request GET "/api/samples?species=$SPECIES_QUERY&country=RU" 200
check_json 'any(.[]; .accessionCode == $code) and all(.[]; has("storagePlace") | not)' 'Размещённый образец не появился в публичном каталоге' --arg code "$ACCESSION_CODE"
step CURATOR 'После приёмки коробку перемещают на освободившееся место'
request POST "/api/curator/boxes/$BOX_ID/move" 200 "{\"storagePlaceId\":$SECOND_PLACE_ID}"
request POST "/api/curator/boxes/$BOX_ID/place" 200
step CURATOR 'На карте камеры видно новое расположение коробки'
request GET "/api/curator/chambers/$CHAMBER_ID/places" 200
check_json 'any(.places[]; .id == $place and .box.id == $box and .occupancy == "OCCUPIED")' 'Карта не показывает перемещение' --argjson place "$SECOND_PLACE_ID" --argjson box "$BOX_ID"
step SECURITY 'Гостевой пропуск отозван; вход и выход куратора остались в журнале'
request POST "/api/security/passes/$GUEST_PASS_ID/revoke" 200
request GET "/api/security/access-events?passId=$INTAKE_PASS_ID&from=$(date -u -d '1 day ago' +%Y-%m-%dT%H:%M:%SZ)&to=$(date -u -d '1 day' +%Y-%m-%dT%H:%M:%SZ)" 200

next_part
section '5. Климат камеры: настройка, измерения и реакция инженера'
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
section '6. Депозитор запрашивает коллекцию обратно'
step APPLICANT 'Депозитор подаёт заявку на изъятие размещённой коробки'
WITHDRAWAL_JSON=$(jq -cn --argjson batch "$BATCH_ID" --argjson box "$BOX_ID" --arg date "$(date +%F)" '{batchId:$batch,boxIds:[$box],reason:"Восстановление коллекции",desiredDate:$date}')
request POST /api/depositors/me/withdrawal-requests 201 "$WITHDRAWAL_JSON"
WITHDRAWAL_ID=$(jq -er '.id' "$RESPONSE")
step CURATOR 'Заявка появилась у куратора — он проверяет состав и согласует изъятие'
request GET '/api/curator/withdrawal-requests?status=SUBMITTED' 200
check_json 'any(.[]; .id == $id)' 'Заявка на изъятие отсутствует в очереди' --argjson id "$WITHDRAWAL_ID"
request POST "/api/curator/withdrawal-requests/$WITHDRAWAL_ID/review" 200
request POST "/api/curator/withdrawal-requests/$WITHDRAWAL_ID/approve" 200
step ADMIN 'Заявка перешла в юридическую очередь — администратор разрешает выдачу'
request GET '/api/admin/withdrawal-requests?status=LEGAL_APPROVAL' 200
check_json 'any(.[]; .id == $id)' 'Заявка не передана администратору' --argjson id "$WITHDRAWAL_ID"
request POST "/api/admin/withdrawal-requests/$WITHDRAWAL_ID/approve" 200
step CURATOR 'Куратор планирует выдачу на завтра'
request POST "/api/curator/withdrawal-requests/$WITHDRAWAL_ID/sessions" 201 "{\"plannedDate\":\"$(date -d tomorrow +%F)\"}"
WITHDRAWAL_SESSION_ID=$(jq -er '.id' "$RESPONSE")
step APPLICANT 'Владелец видит согласованную заявку и назначенную дату выдачи'
request GET "/api/depositors/me/withdrawal-requests/$WITHDRAWAL_ID" 200
step CURATOR 'По договорённости выдачу перенесли на сегодня и завершили'
request PATCH "/api/curator/withdrawal-sessions/$WITHDRAWAL_SESSION_ID" 200 "{\"plannedDate\":\"$(date +%F)\"}"
request POST "/api/curator/withdrawal-sessions/$WITHDRAWAL_SESSION_ID/complete" 200
check_json '.requestStatus == "FULFILLED" and all(.boxes[]; .status == "WITHDRAWN" and .storagePlace == null)' 'Выдача не завершена'
step CURATOR 'На карте освободилось место выданной коробки'
request GET "/api/curator/chambers/$CHAMBER_ID/places" 200
check_json 'any(.places[]; .id == $id and .occupancy == "FREE" and .box == null)' 'После выдачи место осталось занятым' --argjson id "$SECOND_PLACE_ID"
step PUBLIC 'Выданный образец больше не предлагается в каталоге хранилища'
request GET "/api/samples?species=$SPECIES_QUERY&country=RU" 200
check_json 'all(.[]; .accessionCode != $code)' 'Изъятый образец остался в каталоге' --arg code "$ACCESSION_CODE"

next_part
section '7. Участники видят итоги, администратор — аудит и отчёты'
step APPLICANT 'В истории партии виден весь путь коллекции от создания до выдачи'
request GET "/api/depositors/me/batches/$BATCH_ID/history?size=100" 200
check_json 'any(.items[]; .action == "BOX_WITHDRAWN")' 'В истории отсутствует выдача'
step APPLICANT 'В личных уведомлениях остались решения по договору, партии и изъятию'
request GET '/api/notifications?size=100' 200
OWN_NOTIFICATION_ID=$(jq -er '.items[0].id' "$RESPONSE")
request PATCH "/api/notifications/$OWN_NOTIFICATION_ID/read" 200
step ADMIN 'Администратор видит тех же участников и действия в полном аудите'
REPORT_FROM='2000-01-01T00:00:00Z'
REPORT_TO=$(date -u -d tomorrow +%Y-%m-%dT%H:%M:%SZ)
request GET "/api/admin/audit?batchId=$BATCH_ID&from=$REPORT_FROM&to=$REPORT_TO&size=100" 200
step ADMIN 'Пять отчётов показывают результат: места, депозитор, перевозка, выдача и климат'
request GET /api/admin/reports/occupancy 200
request GET "/api/admin/reports/depositors?depositorId=$APPLICANT_ID" 200
request GET "/api/admin/reports/shipments?batchId=$BATCH_ID&from=$REPORT_FROM&to=$REPORT_TO" 200
request GET "/api/admin/reports/withdrawals?batchId=$BATCH_ID&from=$REPORT_FROM&to=$REPORT_TO" 200
check_json '.total == 1 and .items[0].requestId == $id' 'Выдача отсутствует в отчёте' --argjson id "$WITHDRAWAL_ID"
request GET "/api/admin/reports/climate-incidents?chamberId=$CHAMBER_ID&from=$REPORT_FROM&to=$REPORT_TO" 200
check_json 'any(.items[]; .parameter == "BOTH")' 'Климатический инцидент отсутствует в отчёте'
step ADMIN 'Отчёт об изъятиях можно выгрузить в CSV'
request GET "/api/admin/reports/withdrawals.csv?batchId=$BATCH_ID&from=$REPORT_FROM&to=$REPORT_TO" 200 '' "$TEMP_DIR/withdrawals.csv"
head -n 3 "$TEMP_DIR/withdrawals.csv"
step APPLICANT 'Проверка границы ролей: депозитор не может читать административный аудит'
request GET "/api/admin/audit?from=$REPORT_FROM&to=$REPORT_TO" 403

next_part
section '8. Завершение работы и управление доступом сотрудника'
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
step APPLICANT 'Депозитор выходит из системы, его сессия закрыта'
request POST /api/auth/logout 204
request GET /api/depositors/me 401
unset APPLICANT_CSRF_TOKEN CURATOR_CSRF_TOKEN
# Оставшиеся технические сессии закрываем без отдельных демонстрационных шагов.
QUIET=1
for actor in SECURITY ENGINEER ADMIN; do
    role "$actor"
    request POST /api/auth/logout 204
    unset "${actor}_CSRF_TOKEN"
done
QUIET=0

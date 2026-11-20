#!/usr/bin/env bash
# Путь депозитора: регистрация, хранение, возврат коллекции.

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
section '2. Первая партия'
login CURATOR i.berg@example.com
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
section '3. Приёмка и хранение'
step CURATOR 'Куратор выбирает камеру со свободными местами'
request GET /api/curator/chambers 200
CHAMBER_ID=$(jq -er 'first(.[] | select(.freePlaceCount >= 3)) | .id' "$RESPONSE")
step CURATOR 'Куратор назначает приём на сегодня'
request POST "/api/curator/batches/$BATCH_ID/intake-sessions" 201 "{\"chamberId\":$CHAMBER_ID,\"plannedDate\":\"$(date +%F)\"}"
SESSION_ID=$(jq -er '.id' "$RESPONSE")
check_json 'all(.boxes[]; .storagePlace == null)' 'Планирование преждевременно заняло места'
step CURATOR 'Куратор отмечает отправку и прибытие партии по данным перевозчика'
request PATCH "/api/curator/batches/$BATCH_ID/tracking-status" 200 '{"status":"IN_TRANSIT","trackingNumber":"DEMO-TRACK"}'
request PATCH "/api/curator/batches/$BATCH_ID/tracking-status" 200 '{"status":"ARRIVED"}'
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

next_part
section '4. Согласование изъятия и выдача'
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
section '5. История и завершение'
step APPLICANT 'В истории партии виден весь путь коллекции от создания до выдачи'
request GET "/api/depositors/me/batches/$BATCH_ID/history?size=100" 200
check_json 'any(.items[]; .action == "BOX_WITHDRAWN")' 'В истории отсутствует выдача'
step APPLICANT 'В личных уведомлениях остались решения по договору, партии и изъятию'
request GET '/api/notifications?size=100' 200
OWN_NOTIFICATION_ID=$(jq -er '.items[0].id' "$RESPONSE")
request PATCH "/api/notifications/$OWN_NOTIFICATION_ID/read" 200
step APPLICANT 'Депозитор выходит, прежняя сессия больше не действует'
request POST /api/auth/logout 204
request GET /api/depositors/me 401
unset APPLICANT_CSRF_TOKEN
echo "Сценарий депозитора завершён: $STEP шагов, партия $BATCH_ID, заявка $WITHDRAWAL_ID выдана."

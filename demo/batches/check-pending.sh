#!/usr/bin/env bash
# Часть общего сценария: запускается через demo/check-backend.sh.

BATCH_JSON=$(cat <<JSON
{"desiredShipmentDate":"$(date +%F)","boxes":[{"samples":[{"speciesId":$SPECIES_ID,"originCountryCode":"RU","collectionYear":2025,"seedQuantity":100,"note":"Демо-паспорт $RUN_ID"}]},{"samples":[{"speciesId":$SPECIES_ID,"originCountryCode":"NO","collectionYear":2024,"seedQuantity":200}]}]}
JSON
)


echo '8.1. До активации создание партии запрещено: HTTP 403'
command_line "curl -sS -X POST $BASE_URL/api/depositors/me/batches -b <applicant-cookies> -H 'Content-Type: application/json' -d '$BATCH_JSON'"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' \
    -X POST "$BASE_URL/api/depositors/me/batches" \
    -b "$APPLICANT_COOKIES" \
    -H "$APPLICANT_CSRF_HEADER: $APPLICANT_CSRF_TOKEN" \
    -H 'Content-Type: application/json' \
    -d "$BATCH_JSON")
output
http_status
[ "$STATUS" = '403' ] || { echo 'ОШИБКА: ожидался HTTP 403' >&2; exit 1; }

#!/usr/bin/env bash
# Часть общего сценария: запускается через demo/check-backend.sh.

echo 'Администратор получает справочник ролей и список сотрудников'
command_line "curl -sS $BASE_URL/api/admin/roles -b <admin-cookies>"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' -b "$ADMIN_COOKIES" "$BASE_URL/api/admin/roles")
output
http_status
[ "$STATUS" = 200 ] || exit 1
check_json '[.[].code] | sort == ["ADMIN","CURATOR","ENGINEER","SECURITY"]' 'Неполный справочник ролей'

command_line "curl -sS $BASE_URL/api/admin/employees -b <admin-cookies>"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' -b "$ADMIN_COOKIES" "$BASE_URL/api/admin/employees")
output
http_status
[ "$STATUS" = 200 ] || exit 1
check_json '.total == 7 and all(.items[]; keys == ["active","email","fullName","hiredAt","id","phone","roles"])' 'Неверный список сотрудников или лишние закрытые поля'

echo
echo 'Депозитор не может просматривать сотрудников: HTTP 403'
command_line "curl -sS $BASE_URL/api/admin/employees -b <applicant-cookies>"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' -b "$APPLICANT_COOKIES" "$BASE_URL/api/admin/employees")
output
http_status
[ "$STATUS" = 403 ] || exit 1

echo
echo 'Входим вторым инженером; пароль скрыт'
STAFF_COOKIES="$TEMP_DIR/roles-employee-cookies.txt"
command_line "curl -sS $BASE_URL/api/auth/csrf -c <employee-cookies>"
curl -fsS -c "$STAFF_COOKIES" "$BASE_URL/api/auth/csrf" > "$RESPONSE"
STAFF_CSRF_HEADER=$(jq -er '.headerName' "$RESPONSE")
STAFF_CSRF_TOKEN=$(jq -er '.token' "$RESPONSE")
command_line "curl -sS -X POST $BASE_URL/api/auth/login -b <employee-cookies> -d '<email инженера; пароль скрыт>'"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' -b "$STAFF_COOKIES" -c "$STAFF_COOKIES" \
    -X POST "$BASE_URL/api/auth/login" -H "$STAFF_CSRF_HEADER: $STAFF_CSRF_TOKEN" \
    -H 'Content-Type: application/json' -d '{"email":"k.vasil@example.com","password":"Demo123!"}')
output
http_status
[ "$STATUS" = 200 ] || exit 1
check_json '.id == 5 and .roles == ["ENGINEER"]' 'У инженера неожиданные исходные роли'

echo
echo 'Даём этому инженеру дополнительную роль охраны'
command_line "curl -sS -X PUT $BASE_URL/api/admin/employees/5/roles -b <admin-cookies> -d '{\"roles\":[\"ENGINEER\",\"SECURITY\"]}'"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' -b "$ADMIN_COOKIES" \
    -X PUT "$BASE_URL/api/admin/employees/5/roles" -H "$ADMIN_CSRF_HEADER: $ADMIN_CSRF_TOKEN" \
    -H 'Content-Type: application/json' -d '{"roles":["ENGINEER","SECURITY"]}')
output
http_status
[ "$STATUS" = 200 ] || exit 1
check_json '(.roles|sort) == ["ENGINEER","SECURITY"]' 'Роли не назначены'

echo
echo 'В той же сессии появилась новая роль, повторного входа не было'
command_line "curl -sS $BASE_URL/api/auth/me -b <employee-cookies>"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' -b "$STAFF_COOKIES" "$BASE_URL/api/auth/me")
output
http_status
[ "$STATUS" = 200 ] || exit 1
check_json '(.roles|sort) == ["ENGINEER","SECURITY"]' 'Сессия не получила новую роль'
command_line "curl -sS $BASE_URL/api/security/passes?size=2 -b <employee-cookies>"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' -b "$STAFF_COOKIES" "$BASE_URL/api/security/passes?size=2")
output
http_status
[ "$STATUS" = 200 ] || exit 1

echo
echo 'Снимаем роль охраны, возвращая исходный набор'
command_line "curl -sS -X PUT $BASE_URL/api/admin/employees/5/roles -b <admin-cookies> -d '{\"roles\":[\"ENGINEER\"]}'"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' -b "$ADMIN_COOKIES" \
    -X PUT "$BASE_URL/api/admin/employees/5/roles" -H "$ADMIN_CSRF_HEADER: $ADMIN_CSRF_TOKEN" \
    -H 'Content-Type: application/json' -d '{"roles":["ENGINEER"]}')
output
http_status
[ "$STATUS" = 200 ] || exit 1
command_line "curl -sS $BASE_URL/api/security/passes -b <employee-cookies>"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' -b "$STAFF_COOKIES" "$BASE_URL/api/security/passes")
output
http_status
[ "$STATUS" = 403 ] || exit 1

echo
echo 'Отключаем учётную запись инженера'
command_line "curl -sS -X PATCH $BASE_URL/api/admin/employees/5/status -b <admin-cookies> -d '{\"active\":false}'"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' -b "$ADMIN_COOKIES" \
    -X PATCH "$BASE_URL/api/admin/employees/5/status" -H "$ADMIN_CSRF_HEADER: $ADMIN_CSRF_TOKEN" \
    -H 'Content-Type: application/json' -d '{"active":false}')
output
http_status
[ "$STATUS" = 200 ] || exit 1
check_json '.active == false' 'Сотрудник не отключён'
command_line "curl -sS $BASE_URL/api/auth/me -b <employee-cookies>"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' -b "$STAFF_COOKIES" "$BASE_URL/api/auth/me")
output
http_status
[ "$STATUS" = 401 ] || exit 1

echo
echo 'Включаем сотрудника обратно: прежняя сессия остаётся закрытой'
command_line "curl -sS -X PATCH $BASE_URL/api/admin/employees/5/status -b <admin-cookies> -d '{\"active\":true}'"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' -b "$ADMIN_COOKIES" \
    -X PATCH "$BASE_URL/api/admin/employees/5/status" -H "$ADMIN_CSRF_HEADER: $ADMIN_CSRF_TOKEN" \
    -H 'Content-Type: application/json' -d '{"active":true}')
output
http_status
[ "$STATUS" = 200 ] || exit 1
command_line "curl -sS $BASE_URL/api/auth/me -b <employee-cookies>"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' -b "$STAFF_COOKIES" "$BASE_URL/api/auth/me")
output
http_status
[ "$STATUS" = 401 ] || exit 1

echo
echo 'После повторного входа активный инженер снова работает'
command_line "curl -sS $BASE_URL/api/auth/csrf -c <employee-cookies>"
curl -fsS -c "$STAFF_COOKIES" "$BASE_URL/api/auth/csrf" > "$RESPONSE"
STAFF_CSRF_HEADER=$(jq -er '.headerName' "$RESPONSE")
STAFF_CSRF_TOKEN=$(jq -er '.token' "$RESPONSE")
command_line "curl -sS -X POST $BASE_URL/api/auth/login -b <employee-cookies> -d '<email инженера; пароль скрыт>'"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' -b "$STAFF_COOKIES" -c "$STAFF_COOKIES" \
    -X POST "$BASE_URL/api/auth/login" -H "$STAFF_CSRF_HEADER: $STAFF_CSRF_TOKEN" \
    -H 'Content-Type: application/json' -d '{"email":"k.vasil@example.com","password":"Demo123!"}')
output
http_status
[ "$STATUS" = 200 ] || exit 1
check_json '.roles == ["ENGINEER"]' 'После входа неверные роли'
command_line "curl -sS $BASE_URL/api/auth/csrf -b <employee-cookies>"
curl -fsS -b "$STAFF_COOKIES" -c "$STAFF_COOKIES" "$BASE_URL/api/auth/csrf" > "$RESPONSE"
STAFF_CSRF_HEADER=$(jq -er '.headerName' "$RESPONSE")
STAFF_CSRF_TOKEN=$(jq -er '.token' "$RESPONSE")
command_line "curl -sS -X POST $BASE_URL/api/auth/logout -b <employee-cookies> -H '$STAFF_CSRF_HEADER: <csrf-токен>'"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' -b "$STAFF_COOKIES" -c "$STAFF_COOKIES" \
    -X POST "$BASE_URL/api/auth/logout" -H "$STAFF_CSRF_HEADER: $STAFF_CSRF_TOKEN")
http_status
[ "$STATUS" = 204 ] || exit 1

echo
echo 'Нельзя снять ADMIN у последнего активного администратора: HTTP 409'
command_line "curl -sS -X PUT $BASE_URL/api/admin/employees/1/roles -b <admin-cookies> -d '{\"roles\":[\"CURATOR\"]}'"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' -b "$ADMIN_COOKIES" \
    -X PUT "$BASE_URL/api/admin/employees/1/roles" -H "$ADMIN_CSRF_HEADER: $ADMIN_CSRF_TOKEN" \
    -H 'Content-Type: application/json' -d '{"roles":["CURATOR"]}')
output
http_status
[ "$STATUS" = 409 ] || exit 1
command_line "curl -sS -X PATCH $BASE_URL/api/admin/employees/1/status -b <admin-cookies> -d '{\"active\":false}'"
STATUS=$(curl -sS -o "$RESPONSE" -w '%{http_code}' -b "$ADMIN_COOKIES" \
    -X PATCH "$BASE_URL/api/admin/employees/1/status" -H "$ADMIN_CSRF_HEADER: $ADMIN_CSRF_TOKEN" \
    -H 'Content-Type: application/json' -d '{"active":false}')
output
http_status
[ "$STATUS" = 409 ] || exit 1

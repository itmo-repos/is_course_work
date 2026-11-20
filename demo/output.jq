# Display only: assertions and ID extraction always use the original response.
def preview($limit):
    if length > $limit then
        {totalInResponse:length, items: .[:$limit], omitted: (length - $limit)}
    else . end;
def brief:
    walk(if type == "object" then
        del(.password, .token, .codeHash, .keyHash, .qrSvg,
            .phone, .contactPhone, .legalAddress, .registrationNumber,
            .hiredAt, .formedAt, .confirmedAt, .arrivedAt,
            .createdAt, .updatedAt, .curatorDecisionAt, .adminDecisionAt)
        | if has("code") and (has("pass") or has("issuedPass")) then .code="<QR скрыт>" else . end
        | if has("issuedPass") and .issuedPass != null then .issuedPass.code="<QR скрыт>" else . end
    else . end);
brief
| if $scenario == "depositor" then walk(if type == "object" then del(.issuedPass) else . end) else . end
| if type == "object" and has("places") and has("summary") then
    .places |= map(select(.box.id == $box or .box.id == $secondBox
        or .id == $firstPlace or .id == $secondPlace or .id == $replacementPlace))
  elif type == "object" and has("boxes") then .boxes |= map(
    if has("samples") then .samples |= map({accessionCode,latinName,originCountryCode,collectionYear,seedQuantity,note}) else . end)
  elif $path == "/api/admin/employees" and type == "object" and (.items | type) == "array" then
    .items |= map(select(.id == 1 or .id == 5))
  elif type == "object" and has("items") and (.items | type) == "array" then
    .items as $items
    | .items = $items[:4]
    | if ($items | length) > 4 then . + {omitted:(($items | length)-4)} else . end
  elif type == "array" then preview(4)
  else . end

BEGIN;

-- проверка роли сотрудника
CREATE OR REPLACE FUNCTION has_role(
    p_employee_id bigint,
    p_role_code varchar
) RETURNS boolean
LANGUAGE plpgsql STABLE AS $$
BEGIN
RETURN EXISTS (
    SELECT 1
    FROM employee_role er
             JOIN employee e ON e.id = er.employee_id AND e.is_active
    WHERE er.employee_id = p_employee_id
      AND er.role_code = p_role_code
);
END;
$$;

-- поиск партии по штрих-коду коробки
CREATE OR REPLACE FUNCTION identify_batch_by_barcode(
    p_barcode varchar
) RETURNS TABLE (
    batch_id bigint,
    batch_number varchar,
    depositor_name varchar,
    current_status batch_status,
    box_count bigint
)
LANGUAGE plpgsql STABLE AS $$
BEGIN
RETURN QUERY
SELECT btch.id, btch.number, dep.legal_name, btch.status, count(bx2.id)
FROM box bx
         JOIN batch btch ON btch.id = bx.batch_id
         JOIN depositor dep ON dep.id = btch.depositor_id
         JOIN box bx2 ON bx2.batch_id = btch.id
WHERE bx.barcode = upper(p_barcode)
GROUP BY btch.id, btch.number, dep.legal_name, btch.status;
END;
$$;

-- поиск образцов по происхождению или по виду в публичном каталоге
CREATE OR REPLACE FUNCTION search_sample(
    p_species varchar DEFAULT NULL,
    p_country char(2) DEFAULT NULL
) RETURNS TABLE (
    accession_code varchar,
    latin_name varchar,
    local_name varchar,
    origin_country varchar,
    collection_year smallint,
    seed_quantity integer,
    depositor_name varchar
)
LANGUAGE plpgsql STABLE AS $$
DECLARE
v_limit integer := 50;
BEGIN
RETURN QUERY
SELECT s.accession_code, sp.latin_name, sp.local_name, cntr.name,
       s.collection_year, s.seed_quantity, dep.legal_name
FROM sample s
         JOIN species sp ON sp.id = s.species_id
         JOIN country cntr ON cntr.code = s.origin_country_code
         JOIN box bx ON bx.id = s.box_id
         JOIN batch btch ON btch.id = bx.batch_id
         JOIN depositor dep ON dep.id = btch.depositor_id
WHERE bx.status IN ('PLACED', 'AWAITING_PLACEMENT')
  AND (p_species IS NULL OR sp.latin_name ILIKE p_species || '%' OR sp.local_name ILIKE p_species || '%')
  AND (p_country IS NULL OR s.origin_country_code = upper(p_country))
ORDER BY sp.latin_name
    LIMIT v_limit;
END;
$$;

COMMIT;
-- Тестовые данные.
-- Прежняя версия этого файла опиралась на хранимые процедуры бизнес-логики
-- (register_depositor, create_batch, submit_withdrawal_request и т.п.), которых
-- в текущей схеме (01_create.sql/03_functions.sql) больше нет — весь workflow
-- сведен к трем справочным функциям. Поэтому ниже те же сценарии выражены
-- напрямую через INSERT/UPDATE по текущим таблицам и ограничениям.

BEGIN;

INSERT INTO country (code, name) VALUES
    ('RU', 'Россия'),
    ('NO', 'Норвегия'),
    ('SY', 'Сирия'),
    ('US', 'США'),
    ('PE', 'Перу'),
    ('IN', 'Индия'),
    ('ET', 'Эфиопия'),
    ('JP', 'Япония');

INSERT INTO species (latin_name, local_name, family) VALUES
    ('Triticum aestivum',   'Пшеница мягкая',       'Poaceae'),
    ('Hordeum vulgare',     'Ячмень обыкновенный',  'Poaceae'),
    ('Oryza sativa',        'Рис посевной',         'Poaceae'),
    ('Zea mays',            'Кукуруза',             'Poaceae'),
    ('Solanum tuberosum',   'Картофель',            'Solanaceae'),
    ('Pisum sativum',       'Горох посевной',       'Fabaceae'),
    ('Glycine max',         'Соя культурная',       'Fabaceae'),
    ('Secale cereale',      'Рожь посевная',        'Poaceae'),
    ('Linum usitatissimum', 'Лён обыкновенный',     'Linaceae'),
    ('Helianthus annuus',   'Подсолнечник',         'Asteraceae');

INSERT INTO role (code, name, description) VALUES
    ('CURATOR',  'Курирующий сотрудник', 'Прием, размещение, перемещение и отгрузка партий'),
    ('ENGINEER', 'Штатный инженер',      'Обслуживание климатического оборудования и мониторинг'),
    ('SECURITY', 'Сотрудник охраны',     'Пропускной режим и журнал событий доступа'),
    ('ADMIN',    'Администратор системы','Роли, депозиторы, финальные согласования, отчетность');

INSERT INTO employee (full_name, email, phone, password_hash, hired_at) VALUES
    ('Иванов Иван Иванович',      'i.ivanovich@example.com',  '+4779001001', '$2a$10$seedhash000000000000001', '2019-03-11'),
    ('Берг Ингрид Мария',         'i.berg@example.com',       '+4779001002', '$2a$10$seedhash000000000000002', '2020-06-01'),
    ('Соловьев Артем Игоревич',   'a.solovyev@example.com',   '+4779001003', '$2a$10$seedhash000000000000003', '2021-09-15'),
    ('Иванов Сергей Николаевич',  'm.serg@example.com',       '+4779001004', '$2a$10$seedhash000000000000004', '2018-01-22'),
    ('Васильева Елена Игоревна',  'k.vasil@example.com',      '+4779001005', '$2a$10$seedhash000000000000005', '2022-02-14'),
    ('Петрова Ольга Сергеевна',   'p.petrova@example.com',    '+4779001006', '$2a$10$seedhash000000000000006', '2023-05-03'),
    ('Ковалева Мария Сергеевна',  'm.kovaleva@example.com',   '+4779001007', '$2a$10$seedhash000000000000007', '2023-11-20');

-- id: 1 Иванов И.И. (руководитель, ADMIN+CURATOR), 2 Берг И.М. (CURATOR),
--     3 Соловьев А.И. (CURATOR), 4 Иванов С.Н. (ENGINEER), 5 Васильева Е.И. (ENGINEER),
--     6 Петрова О.С. (SECURITY), 7 Ковалева М.С. (SECURITY)
INSERT INTO employee_role (employee_id, role_code) VALUES
    (1, 'ADMIN'),
    (1, 'CURATOR'),
    (2, 'CURATOR'),
    (3, 'CURATOR'),
    (4, 'ENGINEER'),
    (5, 'ENGINEER'),
    (6, 'SECURITY'),
    (7, 'SECURITY');

-- Камеры, места хранения

INSERT INTO chamber (code, name, status, climate_controlled, min_temperature, max_temperature, min_humidity, max_humidity) VALUES
    ('CH-1', 'Камера хранения № 1 (основная)',  'ACTIVE',     true,  -20.0, -16.0, 20.0, 30.0),
    ('CH-2', 'Камера хранения № 2 (резервная)', 'ACTIVE',     true,  -20.0, -16.0, 20.0, 30.0);

INSERT INTO chamber (code, name, status, climate_controlled) VALUES
    ('CH-3', 'Камера хранения № 3 (законсервирована)', 'MOTHBALLED', false);

-- Места хранения: CH-1 - 5 стеллажей x 4 полки x 5 рядов = 100 мест,
--                 CH-2 - 3 x 3 x 4 = 36 мест, CH-3 - 2 x 2 x 2 = 8 мест
INSERT INTO storage_place (chamber_id, rack_no, shelf_no, row_no)
SELECT 1, r, s, w FROM generate_series(1,5) r, generate_series(1,4) s, generate_series(1,5) w;
INSERT INTO storage_place (chamber_id, rack_no, shelf_no, row_no)
SELECT 2, r, s, w FROM generate_series(1,3) r, generate_series(1,3) s, generate_series(1,4) w;
INSERT INTO storage_place (chamber_id, rack_no, shelf_no, row_no)
SELECT 3, r, s, w FROM generate_series(1,2) r, generate_series(1,2) s, generate_series(1,2) w;

COMMIT;

-- Институт Вавилова проходит весь путь от заявки до активного депозитора:
-- заявка -> договор сформирован -> скан подписанного договора загружен -> договор верифицирован.
BEGIN;

DO $$
DECLARE
    v_dep      bigint;
    v_contract bigint;
BEGIN
    -- Депозитор подает заявку на регистрацию, заявка одобрена
    INSERT INTO depositor (legal_name, country_code, registration_number, legal_address,
                            contact_person, contact_email, contact_phone, password_hash, status)
    VALUES ('Всероссийский институт генетических ресурсов растений имени Н.И. Вавилова', 'RU', '1027810324487',
            'Россия, Санкт-Петербург, ул. Большая Морская, 42/44', 'Тарасов Савелий Дмитриевич',
            'vir@example.org', '+78125712548', '$2a$10$dephash0000000000000001', 'AWAITING_CONTRACT')
    RETURNING id INTO v_dep;

    -- Система формирует типовой договор хранения
    INSERT INTO contract (depositor_id, number, generated_doc_uri)
    VALUES (v_dep, 'CN-0001', '/contracts/cn-0001.pdf')
    RETURNING id INTO v_contract;
    UPDATE depositor SET status = 'VERIFICATION' WHERE id = v_dep;

    -- Депозитор подписывает договор и загружает скан
    UPDATE contract SET status = 'SCAN_UPLOADED',
                         signed_scan_uri = '/scans/vir-signed.pdf',
                         signed_uploaded_at = now()
     WHERE id = v_contract;

    -- Администратор проверяет скан и верифицирует договор -> депозитор становится активным
    UPDATE contract SET status = 'VERIFIED',
                         verified_by = 1,
                         verified_at = now(),
                         valid_from = CURRENT_DATE,
                         valid_to = CURRENT_DATE + INTERVAL '5 years'
     WHERE id = v_contract;
    UPDATE depositor SET status = 'ACTIVE' WHERE id = v_dep;
END $$;

COMMIT;

-- Формирование, подтверждение, прием и размещение партий
BEGIN;

DO $$
DECLARE
    v_dep    bigint;
    v_batch  bigint;
    v_number varchar;
    v_box    bigint;
    v_place  bigint;
    v_i      integer;
BEGIN
    SELECT id INTO v_dep FROM depositor WHERE legal_name LIKE 'Всероссийский%';

    -- Партия 1: 6 коробок, принимается и размещается полностью ----
    v_number := 'B-' || lpad(nextval('batch_number_seq')::text, 6, '0');
	INSERT INTO batch (depositor_id, number, status, desired_shipment_date)
    VALUES (v_dep, v_number, 'FORMED', CURRENT_DATE + 14)
    RETURNING id INTO v_batch;

    INSERT INTO box (batch_id, seq_no, barcode) VALUES
        (v_batch, 1, v_number || '-01'),
        (v_batch, 2, v_number || '-02'),
        (v_batch, 3, v_number || '-03'),
        (v_batch, 4, v_number || '-04'),
        (v_batch, 5, v_number || '-05'),
        (v_batch, 6, v_number || '-06');

    INSERT INTO sample (box_id, species_id, origin_country_code, collection_year, seed_quantity, accession_code)
    SELECT bx.id, sp.id, 'RU', v.year, v.qty, v.accession
      FROM (VALUES
                (1, 'Triticum aestivum',   2023, 500, 'VIR-W-0001'),
                (1, 'Secale cereale',      2023, 450, 'VIR-R-0002'),
                (2, 'Hordeum vulgare',     2022, 600, 'VIR-B-0003'),
                (3, 'Pisum sativum',       2024, 300, 'VIR-P-0004'),
                (3, 'Linum usitatissimum', 2024, 280, 'VIR-L-0005'),
                (4, 'Helianthus annuus',   2023, 350, 'VIR-H-0006'),
                (5, 'Glycine max',         2022, 420, 'VIR-G-0007'),
                (6, 'Triticum aestivum',   2021, 510, 'VIR-W-0008')
           ) AS v(seq_no, species, year, qty, accession)
      JOIN box bx ON bx.batch_id = v_batch AND bx.seq_no = v.seq_no
      JOIN species sp ON sp.latin_name = v.species;

    UPDATE batch SET status = 'CONFIRMED', confirmed_by = 2, confirmed_at = now() WHERE id = v_batch;

    -- прием партии: сессия в камере CH-1, все коробки ожидают размещения
    INSERT INTO intake_session (batch_id, curator_id, chamber_id, planned_date, status, completed_at)
    VALUES (v_batch, 2, 1, CURRENT_DATE, 'COMPLETED', now());
    UPDATE batch SET status = 'ARRIVED', arrived_at = now() WHERE id = v_batch;
    UPDATE box SET status = 'AWAITING_PLACEMENT' WHERE batch_id = v_batch;

    FOR v_box IN SELECT id FROM box WHERE batch_id = v_batch ORDER BY seq_no LOOP
        SELECT sp.id INTO v_place FROM storage_place sp
         WHERE sp.chamber_id = 1 AND sp.is_serviceable
           AND NOT EXISTS (SELECT 1 FROM box b2 WHERE b2.storage_place_id = sp.id)
         ORDER BY sp.rack_no, sp.shelf_no, sp.row_no LIMIT 1;
        UPDATE box SET status = 'PLACED', storage_place_id = v_place, placed_at = now() WHERE id = v_box;
    END LOOP;
    UPDATE batch SET status = 'PLACED' WHERE id = v_batch;

END $$;

COMMIT;

-- Заявка на изъятие: подана -> проверена куратором -> утверждена -> сессия
-- изъятия проведена -> коробки изъяты
BEGIN;

DO $$
DECLARE
    v_dep     bigint;
    v_batch   bigint;
    v_boxes   bigint[];
    v_request bigint;
    v_session bigint;
BEGIN
    SELECT id INTO v_dep FROM depositor WHERE legal_name LIKE 'Всероссийский%';
    SELECT id INTO v_batch FROM batch WHERE depositor_id = v_dep AND status = 'PLACED';
    SELECT array_agg(id) INTO v_boxes
      FROM (SELECT id FROM box WHERE batch_id = v_batch AND status = 'PLACED' ORDER BY seq_no LIMIT 2) t;

    -- Депозитор подает заявку на изъятие двух коробок
    INSERT INTO withdrawal_request (depositor_id, batch_id, reason, desired_date, status)
    VALUES (v_dep, v_batch, 'Восстановление национальной коллекции после утраты доступа к генбанку',
            CURRENT_DATE + 20, 'SUBMITTED')
    RETURNING id INTO v_request;
    INSERT INTO withdrawal_request_box (request_id, box_id) SELECT v_request, unnest(v_boxes);

    -- Куратор рассматривает и одобряет заявку
    UPDATE withdrawal_request SET status = 'CURATOR_REVIEW' WHERE id = v_request;
    UPDATE withdrawal_request SET status = 'LEGAL_APPROVAL', curator_id = 2, curator_decision_at = now()
     WHERE id = v_request;

    -- Администратор дает окончательное согласование
    UPDATE withdrawal_request SET status = 'APPROVED', admin_id = 1, admin_decision_at = now()
     WHERE id = v_request;

    -- Проводится сессия изъятия: коробки выданы, места освобождены
    INSERT INTO withdrawal_session (request_id, curator_id, planned_date, status)
    VALUES (v_request, 2, CURRENT_DATE + 18, 'PLANNED')
    RETURNING id INTO v_session;
    INSERT INTO withdrawal_session_box (session_id, box_id) SELECT v_session, unnest(v_boxes);

    UPDATE withdrawal_session SET status = 'COMPLETED', completed_at = now() WHERE id = v_session;
    UPDATE withdrawal_request SET status = 'FULFILLED' WHERE id = v_request;
    UPDATE box SET status = 'WITHDRAWN', storage_place_id = NULL, withdrawn_at = now()
     WHERE id = ANY(v_boxes);
END $$;

COMMIT;

-- Пропускной режим: постоянный пропуск сотрудника, временный пропуск без
-- привязки к сотруднику, события доступа по ним, отзыв временного пропуска
BEGIN;

DO $$
DECLARE
    v_pass_eng  bigint;
    v_pass_temp bigint;
    v_code      varchar;
BEGIN
    -- Постоянный пропуск штатного инженера в камеру CH-1
    v_code := 'P-' || to_char(nextval('pass_code_seq'), 'FM000000');
    INSERT INTO vault_pass (code, employee_id, issued_by, valid_from, valid_to, comment)
    VALUES (v_code, 4, 6, now() - interval '180 days', NULL,
            'Постоянный пропуск: обслуживание климатического оборудования')
    RETURNING id INTO v_pass_eng;
    INSERT INTO pass_chamber (pass_id, chamber_id) VALUES (v_pass_eng, 1);

    -- Временный пропуск подрядчика без привязки к сотруднику (п. 1.5.3)
    v_code := 'P-' || to_char(nextval('pass_code_seq'), 'FM000000');
    INSERT INTO vault_pass (code, employee_id, issued_by, valid_from, valid_to, comment)
    VALUES (v_code, NULL, 6, now() - interval '2 days', now() + interval '1 day',
            'Временный пропуск подрядчика по монтажу стеллажей')
    RETURNING id INTO v_pass_temp;
    INSERT INTO pass_chamber (pass_id, chamber_id) VALUES (v_pass_temp, 1);

    -- Инженер заходит и выходит из камеры по своему пропуску
    INSERT INTO access_event (pass_id, employee_id, chamber_id, direction, comment, registered_by)
    VALUES (v_pass_eng, 4, 1, 'IN',  'Съем показаний датчиков', 6);
    INSERT INTO access_event (pass_id, employee_id, chamber_id, direction, comment, registered_by)
    VALUES (v_pass_eng, 4, 1, 'OUT', NULL, 6);

    -- Отзыв временного пропуска сотрудником охраны — работы завершены досрочно (п. 1.5.4)
    UPDATE vault_pass
       SET status = 'REVOKED', revoked_by = 6, revoked_at = now(),
           comment = comment || ' | Отозван: работы подрядчика завершены досрочно'
     WHERE id = v_pass_temp;
END $$;

COMMIT;

ANALYZE;

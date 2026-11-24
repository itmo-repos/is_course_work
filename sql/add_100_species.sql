BEGIN;

CREATE TEMP TABLE vir_seed_species (
    n integer PRIMARY KEY,
    latin_name varchar(160) UNIQUE NOT NULL,
    local_name varchar(160) NOT NULL,
    family varchar(120) NOT NULL
) ON COMMIT DROP;

INSERT INTO vir_seed_species VALUES
    (1, 'Avena sativa', 'Овёс посевной', 'Poaceae'),
    (2, 'Avena strigosa', 'Овёс щетинистый', 'Poaceae'),
    (3, 'Triticum durum', 'Пшеница твёрдая', 'Poaceae'),
    (4, 'Triticum monococcum', 'Пшеница однозернянка', 'Poaceae'),
    (5, 'Panicum miliaceum', 'Просо посевное', 'Poaceae'),
    (6, 'Setaria italica', 'Щетинник итальянский', 'Poaceae'),
    (7, 'Sorghum bicolor', 'Сорго двуцветное', 'Poaceae'),
    (8, 'Eleusine coracana', 'Элевсина коракана', 'Poaceae'),
    (9, 'Eragrostis tef', 'Теф', 'Poaceae'),
    (10, 'Phleum pratense', 'Тимофеевка луговая', 'Poaceae'),
    (11, 'Festuca pratensis', 'Овсяница луговая', 'Poaceae'),
    (12, 'Lolium perenne', 'Плевел многолетний', 'Poaceae'),
    (13, 'Dactylis glomerata', 'Ежа сборная', 'Poaceae'),
    (14, 'Poa pratensis', 'Мятлик луговой', 'Poaceae'),
    (15, 'Oryza glaberrima', 'Рис африканский', 'Poaceae'),
    (16, 'Phaseolus vulgaris', 'Фасоль обыкновенная', 'Fabaceae'),
    (17, 'Phaseolus coccineus', 'Фасоль огненно-красная', 'Fabaceae'),
    (18, 'Phaseolus lunatus', 'Фасоль луновидная', 'Fabaceae'),
    (19, 'Vigna radiata', 'Маш', 'Fabaceae'),
    (20, 'Vigna angularis', 'Адзуки', 'Fabaceae'),
    (21, 'Vigna unguiculata', 'Вигна китайская', 'Fabaceae'),
    (22, 'Cicer arietinum', 'Нут бараний', 'Fabaceae'),
    (23, 'Lens culinaris', 'Чечевица пищевая', 'Fabaceae'),
    (24, 'Vicia faba', 'Бобы садовые', 'Fabaceae'),
    (25, 'Vicia sativa', 'Вика посевная', 'Fabaceae'),
    (26, 'Lupinus albus', 'Люпин белый', 'Fabaceae'),
    (27, 'Lupinus angustifolius', 'Люпин узколистный', 'Fabaceae'),
    (28, 'Trifolium pratense', 'Клевер луговой', 'Fabaceae'),
    (29, 'Trifolium repens', 'Клевер ползучий', 'Fabaceae'),
    (30, 'Medicago sativa', 'Люцерна посевная', 'Fabaceae'),
    (31, 'Arachis hypogaea', 'Арахис культурный', 'Fabaceae'),
    (32, 'Cajanus cajan', 'Голубиный горох', 'Fabaceae'),
    (33, 'Trigonella foenum-graecum', 'Пажитник сенной', 'Fabaceae'),
    (34, 'Brassica oleracea', 'Капуста огородная', 'Brassicaceae'),
    (35, 'Brassica rapa', 'Репа', 'Brassicaceae'),
    (36, 'Brassica napus', 'Рапс', 'Brassicaceae'),
    (37, 'Brassica juncea', 'Горчица сарептская', 'Brassicaceae'),
    (38, 'Brassica nigra', 'Горчица чёрная', 'Brassicaceae'),
    (39, 'Sinapis alba', 'Горчица белая', 'Brassicaceae'),
    (40, 'Raphanus sativus', 'Редька посевная', 'Brassicaceae'),
    (41, 'Lepidium sativum', 'Кресс-салат', 'Brassicaceae'),
    (42, 'Camelina sativa', 'Рыжик посевной', 'Brassicaceae'),
    (43, 'Nasturtium officinale', 'Жеруха лекарственная', 'Brassicaceae'),
    (44, 'Daucus carota', 'Морковь обыкновенная', 'Apiaceae'),
    (45, 'Apium graveolens', 'Сельдерей пахучий', 'Apiaceae'),
    (46, 'Petroselinum crispum', 'Петрушка кудрявая', 'Apiaceae'),
    (47, 'Anethum graveolens', 'Укроп пахучий', 'Apiaceae'),
    (48, 'Coriandrum sativum', 'Кориандр посевной', 'Apiaceae'),
    (49, 'Carum carvi', 'Тмин обыкновенный', 'Apiaceae'),
    (50, 'Foeniculum vulgare', 'Фенхель обыкновенный', 'Apiaceae'),
    (51, 'Pastinaca sativa', 'Пастернак посевной', 'Apiaceae'),
    (52, 'Pimpinella anisum', 'Анис обыкновенный', 'Apiaceae'),
    (53, 'Cuminum cyminum', 'Кумин', 'Apiaceae'),
    (54, 'Cucumis sativus', 'Огурец посевной', 'Cucurbitaceae'),
    (55, 'Cucumis melo', 'Дыня', 'Cucurbitaceae'),
    (56, 'Citrullus lanatus', 'Арбуз обыкновенный', 'Cucurbitaceae'),
    (57, 'Cucurbita pepo', 'Тыква обыкновенная', 'Cucurbitaceae'),
    (58, 'Cucurbita maxima', 'Тыква крупноплодная', 'Cucurbitaceae'),
    (59, 'Cucurbita moschata', 'Тыква мускатная', 'Cucurbitaceae'),
    (60, 'Lagenaria siceraria', 'Лагенария обыкновенная', 'Cucurbitaceae'),
    (61, 'Momordica charantia', 'Момордика харанция', 'Cucurbitaceae'),
    (62, 'Solanum lycopersicum', 'Томат', 'Solanaceae'),
    (63, 'Solanum melongena', 'Баклажан', 'Solanaceae'),
    (64, 'Capsicum annuum', 'Перец однолетний', 'Solanaceae'),
    (65, 'Capsicum chinense', 'Перец китайский', 'Solanaceae'),
    (66, 'Capsicum baccatum', 'Перец ягодный', 'Solanaceae'),
    (67, 'Physalis peruviana', 'Физалис перуанский', 'Solanaceae'),
    (68, 'Lactuca sativa', 'Латук посевной', 'Asteraceae'),
    (69, 'Cichorium intybus', 'Цикорий обыкновенный', 'Asteraceae'),
    (70, 'Cichorium endivia', 'Эндивий', 'Asteraceae'),
    (71, 'Carthamus tinctorius', 'Сафлор красильный', 'Asteraceae'),
    (72, 'Calendula officinalis', 'Календула лекарственная', 'Asteraceae'),
    (73, 'Matricaria chamomilla', 'Ромашка аптечная', 'Asteraceae'),
    (74, 'Tagetes patula', 'Бархатцы отклонённые', 'Asteraceae'),
    (75, 'Echinacea purpurea', 'Эхинацея пурпурная', 'Asteraceae'),
    (76, 'Ocimum basilicum', 'Базилик душистый', 'Lamiaceae'),
    (77, 'Salvia officinalis', 'Шалфей лекарственный', 'Lamiaceae'),
    (78, 'Salvia hispanica', 'Шалфей испанский', 'Lamiaceae'),
    (79, 'Origanum vulgare', 'Душица обыкновенная', 'Lamiaceae'),
    (80, 'Origanum majorana', 'Майоран', 'Lamiaceae'),
    (81, 'Thymus vulgaris', 'Тимьян обыкновенный', 'Lamiaceae'),
    (82, 'Melissa officinalis', 'Мелисса лекарственная', 'Lamiaceae'),
    (83, 'Lavandula angustifolia', 'Лаванда узколистная', 'Lamiaceae'),
    (84, 'Satureja hortensis', 'Чабер садовый', 'Lamiaceae'),
    (85, 'Beta vulgaris', 'Свёкла обыкновенная', 'Amaranthaceae'),
    (86, 'Spinacia oleracea', 'Шпинат огородный', 'Amaranthaceae'),
    (87, 'Chenopodium quinoa', 'Киноа', 'Amaranthaceae'),
    (88, 'Amaranthus caudatus', 'Амарант хвостатый', 'Amaranthaceae'),
    (89, 'Amaranthus cruentus', 'Амарант багряный', 'Amaranthaceae'),
    (90, 'Allium cepa', 'Лук репчатый', 'Amaryllidaceae'),
    (91, 'Allium fistulosum', 'Лук-батун', 'Amaryllidaceae'),
    (92, 'Allium schoenoprasum', 'Шнитт-лук', 'Amaryllidaceae'),
    (93, 'Allium tuberosum', 'Лук клубненосный', 'Amaryllidaceae'),
    (94, 'Fagopyrum esculentum', 'Гречиха посевная', 'Polygonaceae'),
    (95, 'Fagopyrum tataricum', 'Гречиха татарская', 'Polygonaceae'),
    (96, 'Rumex acetosa', 'Щавель кислый', 'Polygonaceae'),
    (97, 'Sesamum indicum', 'Кунжут индийский', 'Pedaliaceae'),
    (98, 'Abelmoschus esculentus', 'Бамия', 'Malvaceae'),
    (99, 'Gossypium hirsutum', 'Хлопчатник обыкновенный', 'Malvaceae'),
    (100, 'Hibiscus sabdariffa', 'Розелла', 'Malvaceae');

INSERT INTO species (latin_name, local_name, family)
SELECT latin_name, local_name, family FROM vir_seed_species ORDER BY n
ON CONFLICT (latin_name) DO NOTHING;

DO $$
DECLARE
    batch_no CONSTANT text := 'B-VIR-SEED-100';
    dep_id bigint;
    curator bigint;
    chamber_no bigint;
    new_batch bigint;
    box_id_to_place bigint;
    place_id bigint;
BEGIN
    SELECT id INTO STRICT dep_id FROM depositor
     WHERE contact_email = 'vir@example.org' AND status = 'ACTIVE';

    INSERT INTO batch (depositor_id, number, desired_shipment_date)
    VALUES (dep_id, batch_no, CURRENT_DATE)
    ON CONFLICT (number) DO NOTHING RETURNING id INTO new_batch;

    -- Вся партия создаётся атомарно. Повторный запуск сохраняет её текущее состояние.
    IF new_batch IS NULL THEN
        IF (SELECT count(*) FROM batch b
              JOIN box bx ON bx.batch_id = b.id
              JOIN sample s ON s.box_id = bx.id
              JOIN species sp ON sp.id = s.species_id
              JOIN vir_seed_species v ON v.latin_name = sp.latin_name
             WHERE b.number = batch_no AND b.depositor_id = dep_id
               AND s.accession_code = 'VIR-' || left(v.latin_name, 1) || '-' || lpad((8 + v.n)::text, 4, '0')) <> 100 THEN
            RAISE EXCEPTION 'Номер % занят другой или неполной партией', batch_no;
        END IF;
        RETURN;
    END IF;

    SELECT e.id INTO STRICT curator FROM employee e
      JOIN employee_role r ON r.employee_id = e.id
     WHERE e.email = 'i.berg@example.com' AND r.role_code = 'CURATOR';
    SELECT id INTO STRICT chamber_no FROM chamber WHERE code = 'CH-1' AND status = 'ACTIVE';

    -- По пять образцов в каждой из двадцати коробок.
    INSERT INTO box (batch_id, seq_no, barcode)
    SELECT new_batch, n, batch_no || '-' || lpad(n::text, 2, '0') FROM generate_series(1, 20) n;

    INSERT INTO sample (box_id, species_id, origin_country_code, collection_year, seed_quantity, accession_code)
    SELECT bx.id, sp.id, 'RU', 2021 + v.n % 4, 250 + 5 * v.n,
           'VIR-' || left(v.latin_name, 1) || '-' || lpad((8 + v.n)::text, 4, '0')
      FROM vir_seed_species v
      JOIN species sp ON sp.latin_name = v.latin_name
      JOIN box bx ON bx.batch_id = new_batch AND bx.seq_no = 1 + (v.n - 1) / 5;

    UPDATE batch SET status = 'CONFIRMED', confirmed_by = curator, confirmed_at = now() WHERE id = new_batch;
    INSERT INTO intake_session (batch_id, curator_id, chamber_id, planned_date, status, completed_at)
    VALUES (new_batch, curator, chamber_no, CURRENT_DATE, 'COMPLETED', now());
    UPDATE batch SET status = 'ARRIVED', arrived_at = now() WHERE id = new_batch;
    UPDATE box SET status = 'AWAITING_PLACEMENT' WHERE batch_id = new_batch;

    FOR box_id_to_place IN SELECT id FROM box WHERE batch_id = new_batch ORDER BY seq_no LOOP
        SELECT p.id INTO place_id FROM storage_place p
         WHERE p.chamber_id = chamber_no AND p.is_serviceable
           AND NOT EXISTS (SELECT 1 FROM box occupied WHERE occupied.storage_place_id = p.id)
         ORDER BY p.rack_no, p.shelf_no, p.row_no LIMIT 1 FOR UPDATE OF p SKIP LOCKED;
        IF place_id IS NULL THEN
            RAISE EXCEPTION 'Для партии % нужно 20 свободных мест в CH-1', batch_no;
        END IF;
        UPDATE box SET status = 'PLACED', storage_place_id = place_id, placed_at = now()
         WHERE id = box_id_to_place;
    END LOOP;
    UPDATE batch SET status = 'PLACED' WHERE id = new_batch;
END $$;

COMMIT;

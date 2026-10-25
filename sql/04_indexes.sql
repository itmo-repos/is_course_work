-- Климат 

-- поиск записей климата по камере и времени замера
CREATE INDEX idx_climate_recent
    ON climate_reading (chamber_id, measured_at DESC);


-- Образцы

-- поиск всех образцов коробки
CREATE INDEX idx_sample_box ON sample (box_id);
-- поиск всех образцов по коду страны происхождения
CREATE INDEX idx_sample_country ON sample (origin_country_code);
-- поиск всех образцов по году сбора
CREATE INDEX idx_sample_year ON sample (collection_year);


-- Событие доступа

-- поиск всех записей доступа(на вход или выход) работника
CREATE INDEX idx_access_employee ON access_event (employee_id, direction);
-- поиск всех записей доступа к камере хранения
CREATE INDEX idx_access_chamber_id ON access_event (chamber_id, occurred_at DESC);


-- Коробки

-- поиск всех коробок партии
CREATE INDEX idx_box_batch ON box (batch_id);
-- поиск всех коробок ожидающих размещения
CREATE INDEX idx_box_awaiting
    ON box (status) WHERE status = 'AWAITING_PLACEMENT';
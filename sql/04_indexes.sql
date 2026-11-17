-- Климат 
-- Отчёты: владельцы партий, последний проверенный договор, фактические события.
CREATE INDEX idx_report_batch_depositor ON batch (depositor_id);
CREATE INDEX idx_report_contract_verified ON contract (depositor_id, verified_at DESC, id DESC)
    WHERE status='VERIFIED';
CREATE INDEX idx_report_withdrawal_completed ON withdrawal_session (completed_at, id)
    WHERE status='COMPLETED';
CREATE INDEX idx_report_shipment ON audit_event (occurred_at, batch_id, id)
    WHERE action IN ('BATCH_IN_TRANSIT','BATCH_ARRIVED');
CREATE INDEX idx_report_climate_incident ON climate_reading (measured_at, id, chamber_id)
    WHERE temperature < min_temperature OR temperature > max_temperature
       OR humidity < min_humidity OR humidity > max_humidity;
CREATE INDEX idx_audit_time ON audit_event (occurred_at DESC, id DESC);
CREATE INDEX idx_audit_batch ON audit_event (batch_id, occurred_at, id);
CREATE INDEX idx_audit_object ON audit_event (entity_type, entity_id, occurred_at DESC);
CREATE INDEX idx_notification_depositor ON notification (depositor_id, created_at DESC, id DESC);

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

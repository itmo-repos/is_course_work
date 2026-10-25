
BEGIN;

-- таблицы + триггеры удалятся автоматически
DROP TABLE IF EXISTS access_event;
DROP TABLE IF EXISTS pass_chamber;
DROP TABLE IF EXISTS vault_pass;

DROP TABLE IF EXISTS withdrawal_session_box;
DROP TABLE IF EXISTS withdrawal_session;
DROP TABLE IF EXISTS withdrawal_request_box;
DROP TABLE IF EXISTS withdrawal_request;
DROP TABLE IF EXISTS intake_session;

DROP TABLE IF EXISTS sample;
DROP TABLE IF EXISTS box;
DROP TABLE IF EXISTS batch;

DROP TABLE IF EXISTS notification;
DROP TABLE IF EXISTS climate_reading;
DROP TABLE IF EXISTS storage_place;
DROP TABLE IF EXISTS chamber;

DROP TABLE IF EXISTS contract;
DROP TABLE IF EXISTS depositor;

DROP TABLE IF EXISTS employee_role;
DROP TABLE IF EXISTS employee;

DROP TABLE IF EXISTS role;
DROP TABLE IF EXISTS species;
DROP TABLE IF EXISTS country;

-- функции и процедуры

DROP FUNCTION IF EXISTS has_role(bigint, varchar) CASCADE;
DROP FUNCTION IF EXISTS identify_batch_by_barcode(varchar) CASCADE;
DROP FUNCTION IF EXISTS search_sample(varchar, char(2)) CASCADE;
DROP FUNCTION IF EXISTS trg_set_updated_at() CASCADE;
DROP FUNCTION IF EXISTS trg_access_event_immutable() CASCADE;
DROP FUNCTION IF EXISTS trg_ws_complete() CASCADE;
DROP FUNCTION IF EXISTS trg_batch_generate_barcodes() CASCADE;
DROP FUNCTION IF EXISTS trg_intake_session_close_passes() CASCADE;

-- Последовательности и типы

DROP SEQUENCE IF EXISTS batch_number_seq;
DROP SEQUENCE IF EXISTS pass_code_seq;

DROP TYPE IF EXISTS notification_type;
DROP TYPE IF EXISTS climate_parameter;
DROP TYPE IF EXISTS access_direction;
DROP TYPE IF EXISTS pass_status;
DROP TYPE IF EXISTS chamber_status;
DROP TYPE IF EXISTS withdrawal_status;
DROP TYPE IF EXISTS session_status;
DROP TYPE IF EXISTS box_status;
DROP TYPE IF EXISTS batch_status;
DROP TYPE IF EXISTS contract_status;
DROP TYPE IF EXISTS depositor_status;

COMMIT;
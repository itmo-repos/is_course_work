BEGIN;

-- отметка изменения
CREATE OR REPLACE FUNCTION trg_set_updated_at() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    NEW.updated_at := now();
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_depositor_updated_at
    BEFORE UPDATE ON depositor
    FOR EACH ROW EXECUTE FUNCTION trg_set_updated_at();

CREATE TRIGGER trg_contract_updated_at
    BEFORE UPDATE ON contract
    FOR EACH ROW EXECUTE FUNCTION trg_set_updated_at();

CREATE TRIGGER trg_batch_updated_at
    BEFORE UPDATE ON batch
    FOR EACH ROW EXECUTE FUNCTION trg_set_updated_at();

CREATE TRIGGER trg_box_updated_at
    BEFORE UPDATE ON box
    FOR EACH ROW EXECUTE FUNCTION trg_set_updated_at();

CREATE TRIGGER trg_intake_session_updated_at
    BEFORE UPDATE ON intake_session
    FOR EACH ROW EXECUTE FUNCTION trg_set_updated_at();

CREATE TRIGGER trg_withdrawal_request_updated_at
    BEFORE UPDATE ON withdrawal_request
    FOR EACH ROW EXECUTE FUNCTION trg_set_updated_at();

CREATE TRIGGER trg_vault_pass_updated_at
    BEFORE UPDATE ON vault_pass
    FOR EACH ROW EXECUTE FUNCTION trg_set_updated_at();

CREATE TRIGGER trg_chamber_updated_at
    BEFORE UPDATE ON chamber
    FOR EACH ROW EXECUTE FUNCTION trg_set_updated_at();


-- журнал доступа
CREATE OR REPLACE FUNCTION trg_access_event_immutable() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN
        RAISE EXCEPTION 'Удаление события доступа запрещено';
    END IF;

    IF (NEW.pass_id, NEW.chamber_id, NEW.direction, NEW.occurred_at, NEW.employee_id)
       IS DISTINCT FROM
       (OLD.pass_id, OLD.chamber_id, OLD.direction, OLD.occurred_at, OLD.employee_id) THEN
        RAISE EXCEPTION 'В событии доступа разрешено изменять только комментарий';
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_access_event_protect
    BEFORE UPDATE OR DELETE ON access_event
    FOR EACH ROW EXECUTE FUNCTION trg_access_event_immutable();



-- когда завершается сессия изъятия, все коробки причастные к ней помечаются как изъятые
CREATE OR REPLACE FUNCTION trg_ws_complete() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.status = 'COMPLETED' AND OLD.status IS DISTINCT FROM 'COMPLETED' THEN
        UPDATE box
           SET status = 'WITHDRAWN'
         WHERE id IN (SELECT box_id FROM withdrawal_session_box WHERE session_id = NEW.id);

        UPDATE withdrawal_request SET status = 'FULFILLED' WHERE id = NEW.request_id;
    END IF;
    RETURN NULL;
END;
$$;

CREATE TRIGGER trg_ws_completed
    AFTER UPDATE OF status ON withdrawal_session
    FOR EACH ROW EXECUTE FUNCTION trg_ws_complete();


-- Генерация штрихкодов Code 128 после подтверждения партии
CREATE OR REPLACE FUNCTION trg_batch_generate_barcodes() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.status = 'CONFIRMED' AND OLD.status IS DISTINCT FROM 'CONFIRMED' THEN
        UPDATE box b
           SET barcode = upper(regexp_replace(NEW.number, '[^0-9A-Za-z]', '', 'g'))
                         || '-' || lpad(b.seq_no::text, 3, '0')
         WHERE b.batch_id = NEW.id AND b.barcode IS NULL;
    END IF;
    RETURN NULL;
END;
$$;

CREATE TRIGGER trg_batch_barcodes
    AFTER UPDATE OF status ON batch
    FOR EACH ROW EXECUTE FUNCTION trg_batch_generate_barcodes();


-- Временный пропуск выдается под конкретную сессию приема
-- действует только пока она идет. Как только сессия завершена или отменена,
-- все выданные под нее пропуска гасятся
CREATE OR REPLACE FUNCTION trg_intake_session_close_passes() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    IF OLD.status = 'PLANNED' AND NEW.status IN ('COMPLETED', 'CANCELLED') THEN
        UPDATE vault_pass
           SET status   = 'EXPIRED',
               -- конец действия подтягиваем к моменту закрытия сессии,
               -- но только если пропуск успел начать действовать
               valid_to = CASE WHEN now() > valid_from THEN now() ELSE valid_to END
         WHERE intake_session_id = NEW.id
           AND status = 'ACTIVE';
    END IF;
    RETURN NULL;
END;
$$;

CREATE TRIGGER trg_intake_session_passes
    AFTER UPDATE OF status ON intake_session
    FOR EACH ROW EXECUTE FUNCTION trg_intake_session_close_passes();

COMMIT;

BEGIN;

-- Статус депозитора
CREATE TYPE depositor_status AS ENUM (
    'NEW_REQUEST',        -- новая заявка
    'AWAITING_CONTRACT',  -- ожидает подписания договора
    'VERIFICATION',       -- на верификации
    'CONTRACT_REJECTED',  -- договор отклонен
    'ACTIVE',             -- активен
    'REJECTED'            -- отклонен окончательно
);

-- Статус договора хранения
CREATE TYPE contract_status AS ENUM (
    'GENERATED',          -- типовой договор сформирован системой
    'SCAN_UPLOADED',      -- загружен скан подписанного договора
    'VERIFIED',           -- верифицирован администратором
    'REJECTED',           -- отклонен администратором
    'TERMINATED'          -- расторгнут
);

-- Статус партии
CREATE TYPE batch_status AS ENUM (
    'FORMED',             -- сформирована
    'CONFIRMED',          -- подтверждена курирующим сотрудником
    'REJECTED',           -- отклонена курирующим сотрудником (ALT2 прецедента 3)
    'IN_TRANSIT',         -- в пути
    'ARRIVED',            -- прибыла
    'INSPECTION',         -- на досмотре
    'PLACED',             -- размещена
    'PARTIALLY_PLACED',   -- размещена частично
    'WRITTEN_OFF'         -- списана
);

-- Статус коробки
CREATE TYPE box_status AS ENUM (
    'FORMED',             -- сформирована
    'AWAITING_PLACEMENT', -- ожидает размещения
    'PLACED',             -- размещена
    'WRITTEN_OFF',        -- списана
    'WITHDRAWN'           -- изъята
);

-- Статус сессии приема / сессии изъятия
CREATE TYPE session_status AS ENUM (
    'PLANNED',            -- запланирована
    'COMPLETED',          -- завершена
    'CANCELLED'           -- отменена
);

-- Статус заявки на изъятие
CREATE TYPE withdrawal_status AS ENUM (
    'SUBMITTED',          -- подана
    'CURATOR_REVIEW',     -- на проверке у курирующего сотрудника
    'LEGAL_APPROVAL',     -- на юридическом утверждении
    'APPROVED',           -- одобрена
    'REJECTED',           -- отклонена
    'FULFILLED'           -- выполнена
);

-- Статус камеры хранения
CREATE TYPE chamber_status AS ENUM (
    'ACTIVE',             -- активна
    'MOTHBALLED'          -- законсервирована
);

-- Статус пропуска
CREATE TYPE pass_status AS ENUM (
    'ACTIVE',             -- активен
    'EXPIRED',            -- истек
    'REVOKED'             -- отозван
);

-- Направление прохода в/из хранилища
CREATE TYPE access_direction AS ENUM ('IN', 'OUT');

-- Контролируемый климатический параметр
CREATE TYPE climate_parameter AS ENUM ('TEMPERATURE', 'HUMIDITY', 'BOTH');

-- Повод оповещения сотрудника
CREATE TYPE notification_type AS ENUM (
    'CLIMATE_ALERT',      -- выход климата за допустимые границы
    'WITHDRAWAL',         -- события по заявкам на изъятие
    'BATCH',              -- события по партиям
    'CONTRACT'            -- события по договорам и депозиторам
);

-- Начало с 1, потому что будет исопльзовано в том числе для отображения человеку
CREATE SEQUENCE batch_number_seq START 1;
CREATE SEQUENCE pass_code_seq    START 1;

-- всякие справочники, типа стран, описания ролей и видов растений

CREATE TABLE country (
    code char(2)      PRIMARY KEY,
    name varchar(120) NOT NULL UNIQUE,
    CONSTRAINT chk_country_code CHECK (code = upper(code) AND code ~ '^[A-Z]{2}$')
);

CREATE TABLE species (
    id         bigserial PRIMARY KEY,
    latin_name varchar(160) NOT NULL UNIQUE,
    local_name varchar(160) NOT NULL,
    family     varchar(120),
    CONSTRAINT chk_species_names CHECK (btrim(latin_name) <> '' AND btrim(local_name) <> '')
);

CREATE TABLE role (
    code        varchar(32)  PRIMARY KEY,
    name        varchar(120) NOT NULL,
    description text,
    CONSTRAINT chk_role_code CHECK (code IN ('CURATOR', 'ENGINEER', 'SECURITY', 'ADMIN'))
);

-- любой сотрудник

CREATE TABLE employee (
    id            bigserial PRIMARY KEY,
    full_name     varchar(200) NOT NULL,
    email         varchar(254) NOT NULL UNIQUE,
    phone         varchar(32),
    password_hash varchar(255) NOT NULL,
    hired_at      date         NOT NULL DEFAULT CURRENT_DATE,
    is_active     boolean      NOT NULL DEFAULT true,
    created_at    timestamp  NOT NULL DEFAULT now(),
    CONSTRAINT chk_employee_name  CHECK (btrim(full_name) <> '')
);

-- многие ко многим, соединение роли и сотрудника
CREATE TABLE employee_role (
    employee_id bigint      NOT NULL REFERENCES employee(id) ON DELETE CASCADE,
    role_code   varchar(32) NOT NULL REFERENCES role(code)   ON DELETE RESTRICT,
    assigned_at timestamp NOT NULL DEFAULT now(),
    assigned_by bigint      REFERENCES employee(id) ON DELETE SET NULL,
    CONSTRAINT pk_employee_role PRIMARY KEY (employee_id, role_code)
);

-- депозитор и юридические контракты/договоры хранения

CREATE TABLE depositor (
    id                  bigserial PRIMARY KEY,
    legal_name          varchar(300)     NOT NULL UNIQUE,
    country_code        char(2)          NOT NULL REFERENCES country(code) ON DELETE RESTRICT,
    registration_number varchar(64)      NOT NULL,
    legal_address       text             NOT NULL,
    contact_person      varchar(200)     NOT NULL,
    contact_email       varchar(254)     NOT NULL UNIQUE,
    contact_phone       varchar(32),
    password_hash       varchar(255)     NOT NULL,
    status              depositor_status NOT NULL DEFAULT 'NEW_REQUEST',
    rejection_reason    text,
    created_at          timestamp      NOT NULL DEFAULT now(),
    updated_at          timestamp      NOT NULL DEFAULT now(),
    CONSTRAINT chk_depositor_reject CHECK (
        status NOT IN ('REJECTED', 'CONTRACT_REJECTED') OR rejection_reason IS NOT NULL
    ),
    CONSTRAINT uq_depositor_reg UNIQUE (country_code, registration_number)
);

CREATE TABLE contract (
    id                 bigserial PRIMARY KEY,
    depositor_id       bigint          NOT NULL REFERENCES depositor(id) ON DELETE CASCADE,
    number             varchar(40)     NOT NULL UNIQUE,
    status             contract_status NOT NULL DEFAULT 'GENERATED',
    generated_at       timestamp     NOT NULL DEFAULT now(),
    updated_at          timestamp      NOT NULL DEFAULT now(),
    generated_doc_uri  varchar(512),
    signed_scan_uri    varchar(512),
    signed_uploaded_at timestamp,
    verified_by        bigint          REFERENCES employee(id) ON DELETE SET NULL,
    verified_at        timestamp,
    rejection_reason   text,
    valid_from         date,
    valid_to           date,
    CONSTRAINT chk_contract_scan CHECK (status = 'GENERATED' OR signed_scan_uri IS NOT NULL),
    CONSTRAINT chk_contract_verified CHECK (
        status <> 'VERIFIED' OR (verified_by IS NOT NULL AND verified_at IS NOT NULL)
    ),
    CONSTRAINT chk_contract_rejected CHECK (status <> 'REJECTED' OR rejection_reason IS NOT NULL),
    CONSTRAINT chk_contract_period CHECK (valid_to IS NULL OR valid_from IS NULL OR valid_to > valid_from)
);

-- хранилище

CREATE TABLE chamber (
    id                 bigserial PRIMARY KEY,
    code               varchar(20)    NOT NULL UNIQUE,
    name               varchar(160)   NOT NULL,
    status             chamber_status NOT NULL DEFAULT 'ACTIVE',
    climate_controlled boolean        NOT NULL DEFAULT true,
    min_temperature    numeric(5,2),
    max_temperature    numeric(5,2),
    min_humidity       numeric(5,2),
    max_humidity       numeric(5,2),
    created_at         timestamp    NOT NULL DEFAULT now(),
    updated_at          timestamp      NOT NULL DEFAULT now(),
    CONSTRAINT chk_chamber_hum_range  CHECK (
        (min_humidity IS NULL OR min_humidity BETWEEN 0 AND 100) AND
        (max_humidity IS NULL OR max_humidity BETWEEN 0 AND 100)
    ),
    CONSTRAINT chk_chamber_temp_range CHECK (
        (min_temperature IS NULL OR min_temperature BETWEEN -80 AND 60) AND
        (max_temperature IS NULL OR max_temperature BETWEEN -80 AND 60)
    )
);

CREATE TABLE storage_place (
    id             bigserial PRIMARY KEY,
    chamber_id     bigint   NOT NULL REFERENCES chamber(id) ON DELETE RESTRICT,
    rack_no        smallint NOT NULL,
    shelf_no       smallint NOT NULL,
    row_no         smallint NOT NULL,
    is_serviceable boolean  NOT NULL DEFAULT true,
    CONSTRAINT uq_storage_place UNIQUE (chamber_id, rack_no, shelf_no, row_no),
    CONSTRAINT chk_storage_place_pos CHECK (rack_no > 0 AND shelf_no > 0 AND row_no > 0)
);

CREATE TABLE climate_reading (
    id          bigserial PRIMARY KEY,
    chamber_id  bigint       NOT NULL REFERENCES chamber(id) ON DELETE CASCADE,
    measured_at timestamp  NOT NULL DEFAULT now(),
    temperature numeric(5,2) NOT NULL,
    humidity    numeric(5,2) NOT NULL,
    CONSTRAINT uq_climate_reading UNIQUE (chamber_id, measured_at),
    CONSTRAINT chk_climate_hum  CHECK (humidity BETWEEN 0 AND 100),
    CONSTRAINT chk_climate_temp CHECK (temperature BETWEEN -80 AND 60)
);

-- оповещение как закрепляет и фиксирует инцидент, так и запускает рассылку по ответственным

CREATE TABLE notification (
    id          bigserial PRIMARY KEY,
    employee_id bigint            NOT NULL REFERENCES employee(id)        ON DELETE CASCADE,
    reading_id  bigint            REFERENCES climate_reading(id)          ON DELETE CASCADE,
    type        notification_type NOT NULL,
    parameter   climate_parameter,
    message     text              NOT NULL,
    is_read     boolean           NOT NULL DEFAULT false,
    created_at  timestamp       NOT NULL DEFAULT now(),
    -- один и тот же инцидент не рассылается сотруднику дважды
    CONSTRAINT uq_notification_incident UNIQUE (employee_id, reading_id, parameter)
);

-- партия, коробки, образцы. Последовательное уточнение, слоситая структура

CREATE TABLE batch (
    id                    bigserial PRIMARY KEY,
    depositor_id          bigint       NOT NULL REFERENCES depositor(id) ON DELETE RESTRICT,
    number                varchar(40)  NOT NULL UNIQUE,
    status                batch_status NOT NULL DEFAULT 'FORMED',
    formed_at             timestamp  NOT NULL DEFAULT now(),
    updated_at          timestamp      NOT NULL DEFAULT now(),
    desired_shipment_date date         NOT NULL,
    confirmed_by          bigint       REFERENCES employee(id) ON DELETE SET NULL,
    confirmed_at          timestamp,
    rejection_reason      text,
    tracking_number       varchar(64),
    arrived_at            timestamp,
    CONSTRAINT chk_batch_rejected CHECK (status <> 'REJECTED' OR rejection_reason IS NOT NULL)
);

CREATE TABLE box (
    id               bigserial PRIMARY KEY,
    batch_id         bigint     NOT NULL REFERENCES batch(id) ON DELETE CASCADE,
    seq_no           smallint   NOT NULL,
    barcode          varchar(64) UNIQUE,
    status           box_status NOT NULL DEFAULT 'FORMED',
    storage_place_id bigint     REFERENCES storage_place(id) ON DELETE RESTRICT,
    write_off_reason text,
    placed_at        timestamp,
    written_off_at   timestamp,
    withdrawn_at     timestamp,
    updated_at          timestamp      NOT NULL DEFAULT now(),
    CONSTRAINT uq_box_in_batch UNIQUE (batch_id, seq_no),
    -- одно место хранения занимает не более одной коробки
    CONSTRAINT uq_box_place UNIQUE (storage_place_id),
    CONSTRAINT chk_box_seq CHECK (seq_no > 0),
    CONSTRAINT chk_box_place_by_status CHECK (
        (status = 'PLACED'                              AND storage_place_id IS NOT NULL) OR
        (status IN ('FORMED','WRITTEN_OFF','WITHDRAWN') AND storage_place_id IS NULL)     OR
        (status = 'AWAITING_PLACEMENT')
    ),
    CONSTRAINT chk_box_write_off CHECK (
        status <> 'WRITTEN_OFF' OR (write_off_reason IS NOT NULL AND written_off_at IS NOT NULL)
    ),
    CONSTRAINT chk_box_withdrawn CHECK (status <> 'WITHDRAWN' OR withdrawn_at IS NOT NULL)
);

CREATE TABLE sample (
    id                  bigserial PRIMARY KEY,
    box_id              bigint      NOT NULL REFERENCES box(id) ON DELETE CASCADE,
    species_id          bigint      NOT NULL REFERENCES species(id) ON DELETE RESTRICT,
    origin_country_code char(2)     NOT NULL REFERENCES country(code) ON DELETE RESTRICT,
    collection_year     smallint    NOT NULL,
    seed_quantity       integer     NOT NULL,
    accession_code      varchar(64) NOT NULL UNIQUE,
    note                text,
    CONSTRAINT chk_sample_year CHECK (collection_year BETWEEN 1850 AND 2900),
    CONSTRAINT chk_sample_qty  CHECK (seed_quantity > 0)
);

-- сессии приема/отгрузки

CREATE TABLE intake_session (
    id           bigserial PRIMARY KEY,
    batch_id     bigint         NOT NULL UNIQUE REFERENCES batch(id)    ON DELETE CASCADE,
    curator_id   bigint         NOT NULL        REFERENCES employee(id) ON DELETE RESTRICT,
    chamber_id   bigint         NOT NULL        REFERENCES chamber(id)  ON DELETE RESTRICT,
    planned_date date           NOT NULL,
    status       session_status NOT NULL DEFAULT 'PLANNED',
    completed_at timestamp,
    updated_at          timestamp      NOT NULL DEFAULT now(),
    CONSTRAINT chk_intake_completed CHECK (status <> 'COMPLETED' OR completed_at IS NOT NULL)
);

CREATE TABLE withdrawal_request (
    id                  bigserial PRIMARY KEY,
    depositor_id        bigint            NOT NULL REFERENCES depositor(id) ON DELETE RESTRICT,
    batch_id            bigint            NOT NULL REFERENCES batch(id)     ON DELETE RESTRICT,
    reason              text              NOT NULL,
    desired_date        date              NOT NULL,
    status              withdrawal_status NOT NULL DEFAULT 'SUBMITTED',
    submitted_at        timestamp       NOT NULL DEFAULT now(),
    updated_at          timestamp       NOT NULL DEFAULT now(),
    curator_id          bigint            REFERENCES employee(id) ON DELETE SET NULL,
    curator_decision_at timestamp,
    admin_id            bigint            REFERENCES employee(id) ON DELETE SET NULL,
    admin_decision_at   timestamp,
    rejection_reason    text,
    CONSTRAINT chk_wr_reason   CHECK (btrim(reason) <> ''),
    CONSTRAINT chk_wr_rejected CHECK (status <> 'REJECTED' OR rejection_reason IS NOT NULL),
    CONSTRAINT chk_wr_curator  CHECK (
        status IN ('SUBMITTED', 'CURATOR_REVIEW', 'REJECTED') OR curator_id IS NOT NULL
    ),
    CONSTRAINT chk_wr_admin CHECK (
        status NOT IN ('APPROVED', 'FULFILLED') OR (admin_id IS NOT NULL AND admin_decision_at IS NOT NULL)
    )
);

-- промежуточная таблица для соединения многие ко многим коробка-заявка
CREATE TABLE withdrawal_request_box (
    request_id bigint NOT NULL REFERENCES withdrawal_request(id) ON DELETE CASCADE,
    box_id     bigint NOT NULL REFERENCES box(id)                ON DELETE RESTRICT,
    CONSTRAINT pk_withdrawal_request_box PRIMARY KEY (request_id, box_id)
);

CREATE TABLE withdrawal_session (
    id           bigserial PRIMARY KEY,
    request_id   bigint         NOT NULL UNIQUE REFERENCES withdrawal_request(id) ON DELETE CASCADE,
    curator_id   bigint         NOT NULL        REFERENCES employee(id)           ON DELETE RESTRICT,
    planned_date date           NOT NULL,
    status       session_status NOT NULL DEFAULT 'PLANNED',
    completed_at timestamp,
    updated_at          timestamp       NOT NULL DEFAULT now(),
    CONSTRAINT chk_ws_completed CHECK (status <> 'COMPLETED' OR completed_at IS NOT NULL)
);

-- соединение сессия-коробка
CREATE TABLE withdrawal_session_box (
    session_id bigint NOT NULL REFERENCES withdrawal_session(id) ON DELETE CASCADE,
    box_id     bigint NOT NULL REFERENCES box(id)                ON DELETE RESTRICT,
    CONSTRAINT pk_withdrawal_session_box PRIMARY KEY (session_id, box_id)
);

-- пропускная система

CREATE TABLE vault_pass (
    id                bigserial PRIMARY KEY,
    code              varchar(40) NOT NULL UNIQUE,
    employee_id       bigint      REFERENCES employee(id)       ON DELETE SET NULL,
    issued_by         bigint      NOT NULL REFERENCES employee(id) ON DELETE RESTRICT,
    intake_session_id bigint      REFERENCES intake_session(id) ON DELETE SET NULL,
    status            pass_status NOT NULL DEFAULT 'ACTIVE',
    valid_from        timestamp NOT NULL DEFAULT now(),
    valid_to          timestamp,
    comment           text,
    revoked_by        bigint      REFERENCES employee(id) ON DELETE SET NULL,
    revoked_at        timestamp,
    created_at        timestamp NOT NULL DEFAULT now(),
    updated_at          timestamp       NOT NULL DEFAULT now(),
    CONSTRAINT chk_pass_period  CHECK (valid_to IS NULL OR valid_to > valid_from),
    CONSTRAINT chk_pass_revoked CHECK (
        status <> 'REVOKED' OR (revoked_by IS NOT NULL AND revoked_at IS NOT NULL)
    )
);
-- пропуск-камера таблица-соединение многие ко многим
CREATE TABLE pass_chamber (
    pass_id    bigint NOT NULL REFERENCES vault_pass(id) ON DELETE CASCADE,
    chamber_id bigint NOT NULL REFERENCES chamber(id)    ON DELETE CASCADE,
    CONSTRAINT pk_pass_chamber PRIMARY KEY (pass_id, chamber_id)
);

-- непосредственно событие доступа
CREATE TABLE access_event (
    id            bigserial PRIMARY KEY,
    pass_id       bigint           NOT NULL REFERENCES vault_pass(id) ON DELETE RESTRICT,
    employee_id   bigint           REFERENCES employee(id) ON DELETE SET NULL,
    chamber_id    bigint           NOT NULL REFERENCES chamber(id) ON DELETE RESTRICT,
    direction     access_direction NOT NULL,
    occurred_at   timestamp      NOT NULL DEFAULT now(),
    comment       text,
    registered_by bigint           REFERENCES employee(id) ON DELETE SET NULL
);

COMMIT;

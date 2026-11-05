-- ORLEU V1: identity, tenancy, catalog, scheduling, bookings, ledger, audit
CREATE EXTENSION IF NOT EXISTS btree_gist;

CREATE TABLE users (
    id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    email            varchar(254) NOT NULL,
    phone            varchar(20),
    password_hash    varchar(255) NOT NULL,
    full_name        varchar(200) NOT NULL,
    locale           varchar(5) NOT NULL DEFAULT 'ru' CHECK (locale IN ('kk','ru','en')),
    status           varchar(20) NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE','DISABLED')),
    failed_attempts  int NOT NULL DEFAULT 0,
    locked_until     timestamptz,
    created_at       timestamptz NOT NULL DEFAULT now(),
    updated_at       timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX users_email_uq ON users (lower(email));
CREATE UNIQUE INDEX users_phone_uq ON users (phone) WHERE phone IS NOT NULL;

CREATE TABLE refresh_tokens (
    id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id      uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token_hash   varchar(64) NOT NULL UNIQUE,
    user_agent   varchar(300),
    expires_at   timestamptz NOT NULL,
    revoked_at   timestamptz,
    created_at   timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX refresh_tokens_user_idx ON refresh_tokens (user_id);

CREATE TABLE subscription_plans (
    code           varchar(30) PRIMARY KEY,
    name           varchar(100) NOT NULL,
    max_branches   int NOT NULL CHECK (max_branches > 0),
    max_employees  int NOT NULL CHECK (max_employees > 0),
    price_monthly  numeric(14,2) NOT NULL DEFAULT 0 CHECK (price_monthly >= 0),
    currency       varchar(3) NOT NULL DEFAULT 'KZT',
    active         boolean NOT NULL DEFAULT true
);
INSERT INTO subscription_plans (code, name, max_branches, max_employees, price_monthly) VALUES
    ('FREE', 'Free', 1, 3, 0),
    ('PRO',  'Pro', 20, 200, 0);  -- PRO price is a placeholder: pricing is a business decision, set via admin

CREATE TABLE businesses (
    id                        uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    slug                      varchar(60) NOT NULL UNIQUE CHECK (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
    name                      varchar(200) NOT NULL,
    business_type             varchar(40) NOT NULL,
    description               text,
    country                   varchar(2) NOT NULL DEFAULT 'KZ',
    city                      varchar(100),
    address                   varchar(300),
    phone                     varchar(20),
    email                     varchar(254),
    currency                  varchar(3) NOT NULL DEFAULT 'KZT',
    timezone                  varchar(64) NOT NULL DEFAULT 'Asia/Almaty',
    plan_code                 varchar(30) NOT NULL DEFAULT 'FREE' REFERENCES subscription_plans(code),
    published                 boolean NOT NULL DEFAULT false,
    onboarding_step           int NOT NULL DEFAULT 1,
    deposit_percent           numeric(5,2) NOT NULL DEFAULT 0 CHECK (deposit_percent BETWEEN 0 AND 100),
    auto_confirm              boolean NOT NULL DEFAULT true,
    min_notice_minutes        int NOT NULL DEFAULT 60 CHECK (min_notice_minutes >= 0),
    max_advance_days          int NOT NULL DEFAULT 60 CHECK (max_advance_days BETWEEN 1 AND 730),
    payment_hold_minutes      int NOT NULL DEFAULT 15 CHECK (payment_hold_minutes BETWEEN 1 AND 1440),
    created_at                timestamptz NOT NULL DEFAULT now(),
    updated_at                timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE memberships (
    id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id      uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    business_id  uuid NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    role         varchar(30) NOT NULL CHECK (role IN ('BUSINESS_OWNER','BUSINESS_ADMIN','BRANCH_MANAGER','STAFF','ACCOUNTANT','RECEPTIONIST')),
    status       varchar(20) NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE','DEACTIVATED')),
    created_at   timestamptz NOT NULL DEFAULT now(),
    UNIQUE (user_id, business_id)
);
CREATE INDEX memberships_business_idx ON memberships (business_id);

CREATE TABLE branches (
    id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id  uuid NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    name         varchar(200) NOT NULL,
    address      varchar(300),
    phone        varchar(20),
    timezone     varchar(64) NOT NULL,
    active       boolean NOT NULL DEFAULT true,
    created_at   timestamptz NOT NULL DEFAULT now(),
    UNIQUE (id, business_id)
);
CREATE INDEX branches_business_idx ON branches (business_id);

CREATE TABLE branch_hours (
    id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    branch_id    uuid NOT NULL REFERENCES branches(id) ON DELETE CASCADE,
    day_of_week  smallint NOT NULL CHECK (day_of_week BETWEEN 1 AND 7), -- ISO: 1=Mon
    open_time    time NOT NULL,
    close_time   time NOT NULL,
    CHECK (close_time > open_time),
    UNIQUE (branch_id, day_of_week)
);

CREATE TABLE services (
    id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id      uuid NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    name             varchar(200) NOT NULL,
    description      text,
    category         varchar(100),
    duration_minutes int NOT NULL CHECK (duration_minutes BETWEEN 5 AND 1440),
    buffer_minutes   int NOT NULL DEFAULT 0 CHECK (buffer_minutes BETWEEN 0 AND 240),
    price            numeric(14,2) NOT NULL CHECK (price >= 0),
    deposit_percent  numeric(5,2) CHECK (deposit_percent BETWEEN 0 AND 100), -- NULL = use business default
    online_bookable  boolean NOT NULL DEFAULT true,
    active           boolean NOT NULL DEFAULT true,
    created_at       timestamptz NOT NULL DEFAULT now(),
    UNIQUE (id, business_id)
);
CREATE INDEX services_business_idx ON services (business_id);

CREATE TABLE employees (
    id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id  uuid NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    user_id      uuid REFERENCES users(id) ON DELETE SET NULL,
    display_name varchar(200) NOT NULL,
    active       boolean NOT NULL DEFAULT true,
    created_at   timestamptz NOT NULL DEFAULT now(),
    UNIQUE (id, business_id)
);
CREATE INDEX employees_business_idx ON employees (business_id);

-- composite FKs guarantee that assignments never cross tenants
CREATE TABLE employee_branches (
    employee_id  uuid NOT NULL,
    branch_id    uuid NOT NULL,
    business_id  uuid NOT NULL,
    PRIMARY KEY (employee_id, branch_id),
    FOREIGN KEY (employee_id, business_id) REFERENCES employees(id, business_id) ON DELETE CASCADE,
    FOREIGN KEY (branch_id, business_id) REFERENCES branches(id, business_id) ON DELETE CASCADE
);
CREATE TABLE employee_services (
    employee_id  uuid NOT NULL,
    service_id   uuid NOT NULL,
    business_id  uuid NOT NULL,
    PRIMARY KEY (employee_id, service_id),
    FOREIGN KEY (employee_id, business_id) REFERENCES employees(id, business_id) ON DELETE CASCADE,
    FOREIGN KEY (service_id, business_id) REFERENCES services(id, business_id) ON DELETE CASCADE
);
CREATE TABLE employee_time_off (
    id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id  uuid NOT NULL,
    employee_id  uuid NOT NULL,
    starts_at    timestamptz NOT NULL,
    ends_at      timestamptz NOT NULL,
    reason       varchar(200),
    CHECK (ends_at > starts_at),
    FOREIGN KEY (employee_id, business_id) REFERENCES employees(id, business_id) ON DELETE CASCADE
);
CREATE INDEX employee_time_off_idx ON employee_time_off (employee_id, starts_at);

CREATE TABLE customers (
    id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id      uuid NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    full_name        varchar(200) NOT NULL,
    phone            varchar(20) NOT NULL CHECK (phone ~ '^\+[1-9][0-9]{7,14}$'),
    email            varchar(254),
    notes            text,
    marketing_opt_in boolean NOT NULL DEFAULT false,
    blocked          boolean NOT NULL DEFAULT false,
    created_at       timestamptz NOT NULL DEFAULT now(),
    UNIQUE (business_id, phone),
    UNIQUE (id, business_id)
);

CREATE TABLE bookings (
    id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id      uuid NOT NULL,
    branch_id        uuid NOT NULL,
    service_id       uuid NOT NULL,
    employee_id      uuid NOT NULL,
    customer_id      uuid NOT NULL,
    starts_at        timestamptz NOT NULL,
    ends_at          timestamptz NOT NULL,
    blocked_until    timestamptz NOT NULL,           -- ends_at + service buffer
    status           varchar(20) NOT NULL CHECK (status IN
        ('PENDING','AWAITING_PAYMENT','CONFIRMED','CHECKED_IN','IN_PROGRESS','COMPLETED','CANCELLED','NO_SHOW','EXPIRED')),
    price            numeric(14,2) NOT NULL CHECK (price >= 0),
    deposit_amount   numeric(14,2) NOT NULL CHECK (deposit_amount >= 0),
    currency         varchar(3) NOT NULL,
    hold_expires_at  timestamptz,
    notes            text,
    source           varchar(20) NOT NULL DEFAULT 'STAFF' CHECK (source IN ('STAFF','PUBLIC')),
    version          bigint NOT NULL DEFAULT 0,
    created_at       timestamptz NOT NULL DEFAULT now(),
    updated_at       timestamptz NOT NULL DEFAULT now(),
    CHECK (ends_at > starts_at AND blocked_until >= ends_at),
    CHECK (deposit_amount <= price),
    FOREIGN KEY (branch_id, business_id)   REFERENCES branches(id, business_id),
    FOREIGN KEY (service_id, business_id)  REFERENCES services(id, business_id),
    FOREIGN KEY (employee_id, business_id) REFERENCES employees(id, business_id),
    FOREIGN KEY (customer_id, business_id) REFERENCES customers(id, business_id),
    UNIQUE (id, business_id),
    -- Hard guarantee against double booking: no two active bookings of one employee may overlap.
    CONSTRAINT bookings_no_employee_overlap EXCLUDE USING gist (
        employee_id WITH =,
        tstzrange(starts_at, blocked_until, '[)') WITH &&
    ) WHERE (status IN ('PENDING','AWAITING_PAYMENT','CONFIRMED','CHECKED_IN','IN_PROGRESS'))
);
CREATE INDEX bookings_business_time_idx ON bookings (business_id, starts_at);
CREATE INDEX bookings_employee_time_idx ON bookings (employee_id, starts_at);
CREATE INDEX bookings_customer_idx ON bookings (customer_id);
CREATE INDEX bookings_hold_idx ON bookings (hold_expires_at) WHERE status = 'AWAITING_PAYMENT';

CREATE TABLE booking_status_history (
    id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id  uuid NOT NULL,
    booking_id   uuid NOT NULL,
    from_status  varchar(20),
    to_status    varchar(20) NOT NULL,
    actor_user_id uuid,
    reason       varchar(300),
    created_at   timestamptz NOT NULL DEFAULT now(),
    FOREIGN KEY (booking_id, business_id) REFERENCES bookings(id, business_id) ON DELETE CASCADE
);
CREATE INDEX booking_status_history_idx ON booking_status_history (booking_id);

-- Immutable financial ledger: append-only (enforced by trigger below).
CREATE TABLE ledger_entries (
    id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id      uuid NOT NULL,
    booking_id       uuid NOT NULL,
    entry_type       varchar(20) NOT NULL CHECK (entry_type IN ('PAYMENT','REFUND')),
    amount           numeric(14,2) NOT NULL CHECK (amount > 0),
    currency         varchar(3) NOT NULL,
    method           varchar(20) NOT NULL CHECK (method IN ('CASH','BANK_TRANSFER','CARD_MANUAL')),
    idempotency_key  varchar(100) NOT NULL,
    provider_ref     varchar(200),
    created_by       uuid,
    created_at       timestamptz NOT NULL DEFAULT now(),
    FOREIGN KEY (booking_id, business_id) REFERENCES bookings(id, business_id),
    UNIQUE (business_id, idempotency_key)
);
CREATE INDEX ledger_booking_idx ON ledger_entries (booking_id);
CREATE INDEX ledger_business_time_idx ON ledger_entries (business_id, created_at);

CREATE FUNCTION ledger_immutable() RETURNS trigger AS $$
BEGIN
    RAISE EXCEPTION 'ledger_entries is append-only';
END;
$$ LANGUAGE plpgsql;
CREATE TRIGGER ledger_no_update BEFORE UPDATE OR DELETE ON ledger_entries
    FOR EACH ROW EXECUTE FUNCTION ledger_immutable();
CREATE TRIGGER ledger_no_truncate BEFORE TRUNCATE ON ledger_entries
    FOR EACH STATEMENT EXECUTE FUNCTION ledger_immutable();

CREATE TABLE audit_logs (
    id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id   uuid,
    actor_user_id uuid,
    action        varchar(60) NOT NULL,
    entity_type   varchar(40),
    entity_id     uuid,
    details       jsonb,
    created_at    timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX audit_business_time_idx ON audit_logs (business_id, created_at);

-- V2: customer self-service (manage token, cancellation window), transactional outbox, in-app notifications
ALTER TABLE businesses ADD COLUMN cancellation_deadline_hours int NOT NULL DEFAULT 24
    CHECK (cancellation_deadline_hours BETWEEN 0 AND 720);

-- SHA-256 hex of a 256-bit random token; the raw token is shown to the customer once.
ALTER TABLE bookings ADD COLUMN manage_token_hash varchar(64);
CREATE UNIQUE INDEX bookings_manage_token_uq ON bookings (manage_token_hash) WHERE manage_token_hash IS NOT NULL;

CREATE TABLE outbox_events (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id     uuid NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    event_type      varchar(60) NOT NULL,
    booking_id      uuid,
    dedupe_key      varchar(200) NOT NULL UNIQUE,
    status          varchar(10) NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING','DONE','DEAD')),
    attempts        int NOT NULL DEFAULT 0,
    next_attempt_at timestamptz NOT NULL DEFAULT now(),
    last_error      varchar(500),
    created_at      timestamptz NOT NULL DEFAULT now(),
    processed_at    timestamptz
);
CREATE INDEX outbox_due_idx ON outbox_events (next_attempt_at) WHERE status = 'PENDING';

CREATE TABLE notifications (
    id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id  uuid NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    event_id     uuid NOT NULL UNIQUE REFERENCES outbox_events(id),  -- one notification per event: no duplicates
    event_type   varchar(60) NOT NULL,
    booking_id   uuid,
    read_at      timestamptz,
    created_at   timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX notifications_business_idx ON notifications (business_id, created_at DESC);

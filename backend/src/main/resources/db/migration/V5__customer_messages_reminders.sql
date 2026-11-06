-- V5: reminder setting, customer-message locale, and the customer message log.
ALTER TABLE businesses ADD COLUMN reminder_hours int NOT NULL DEFAULT 24 CHECK (reminder_hours BETWEEN 0 AND 168);
ALTER TABLE businesses ADD COLUMN customer_locale varchar(2) NOT NULL DEFAULT 'ru' CHECK (customer_locale IN ('kk','ru','en'));

-- Rendered customer-facing messages, one per outbox event. No SMS/e-mail provider is wired yet, so rows stay
-- NOT_SENT; a future sender picks them up and moves them to SENT/FAILED. Nothing here claims delivery.
CREATE TABLE customer_messages (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id     uuid NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    event_id        uuid NOT NULL UNIQUE REFERENCES outbox_events(id),
    booking_id      uuid,
    message_type    varchar(40) NOT NULL,
    locale          varchar(2) NOT NULL,
    recipient_phone varchar(20) NOT NULL,
    body            text NOT NULL,
    status          varchar(12) NOT NULL DEFAULT 'NOT_SENT' CHECK (status IN ('NOT_SENT','SENT','FAILED')),
    created_at      timestamptz NOT NULL DEFAULT now(),
    sent_at         timestamptz
);
CREATE INDEX customer_messages_business_idx ON customer_messages (business_id, created_at DESC);

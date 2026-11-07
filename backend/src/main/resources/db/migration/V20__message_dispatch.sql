-- Delivery of customer messages through a sender behind an interface (see MessageSender). Until a real provider exists only the FAKE
-- test sender can be switched on, and never in the prod profile. Statuses stay NOT_SENT / SENT / FAILED: SENT means "the sender accepted it".
ALTER TABLE customer_messages
    ADD COLUMN channel             varchar(10) NOT NULL DEFAULT 'SMS' CHECK (channel IN ('SMS','EMAIL','WHATSAPP')),
    ADD COLUMN attempts            int NOT NULL DEFAULT 0 CHECK (attempts >= 0),
    ADD COLUMN next_attempt_at     timestamptz,                 -- NULL = due now; also used as a short lease while an attempt is in flight
    ADD COLUMN last_error          varchar(200),
    ADD COLUMN provider_message_id varchar(100);
CREATE INDEX customer_messages_due_idx ON customer_messages (next_attempt_at) WHERE status = 'NOT_SENT';

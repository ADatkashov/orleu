-- Short-lived system messages to ONE person (e-mail / SMS): password-reset links now, login codes later. Unlike customer_messages they are not tied to a
-- booking. The body can hold a secret (reset token), so it is wiped as soon as the message is SENT, FAILED or past expires_at; expired messages are never sent.
CREATE TABLE system_messages (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    channel             varchar(10) NOT NULL CHECK (channel IN ('EMAIL','SMS')),
    recipient           varchar(254) NOT NULL,
    subject             varchar(200),
    body                text,                                  -- NULL once delivered / failed / expired
    purpose             varchar(30) NOT NULL,
    status              varchar(12) NOT NULL DEFAULT 'NOT_SENT' CHECK (status IN ('NOT_SENT','SENT','FAILED')),
    attempts            int NOT NULL DEFAULT 0,
    next_attempt_at     timestamptz,
    last_error          varchar(200),
    provider_message_id varchar(100),
    expires_at          timestamptz NOT NULL,
    created_at          timestamptz NOT NULL DEFAULT now(),
    sent_at             timestamptz,
    CHECK (status = 'NOT_SENT' OR body IS NULL)
);
CREATE INDEX system_messages_due_idx ON system_messages (next_attempt_at) WHERE status = 'NOT_SENT';

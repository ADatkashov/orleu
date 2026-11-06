-- V7: support tickets between a business and the platform team.
CREATE TABLE support_tickets (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id     uuid NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    created_by      uuid NOT NULL REFERENCES users(id),
    subject         varchar(200) NOT NULL,
    category        varchar(12) NOT NULL DEFAULT 'OTHER' CHECK (category IN ('BILLING','TECHNICAL','ACCOUNT','OTHER')),
    -- OPEN = waiting for the platform team, ANSWERED = the platform team replied, CLOSED = finished
    status          varchar(10) NOT NULL DEFAULT 'OPEN' CHECK (status IN ('OPEN','ANSWERED','CLOSED')),
    created_at      timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz NOT NULL DEFAULT now(),
    UNIQUE (id, business_id)
);
CREATE INDEX support_tickets_business_idx ON support_tickets (business_id, updated_at DESC);
CREATE INDEX support_tickets_status_idx ON support_tickets (status, updated_at DESC);

CREATE TABLE support_messages (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    ticket_id       uuid NOT NULL,
    business_id     uuid NOT NULL,
    author_user_id  uuid NOT NULL REFERENCES users(id),
    from_platform   boolean NOT NULL,
    body            varchar(4000) NOT NULL CHECK (length(btrim(body)) > 0),
    created_at      timestamptz NOT NULL DEFAULT now(),
    FOREIGN KEY (ticket_id, business_id) REFERENCES support_tickets(id, business_id) ON DELETE CASCADE
);
CREATE INDEX support_messages_ticket_idx ON support_messages (ticket_id, created_at);

-- Refund approval workflow. A business may set a threshold: a refund ABOVE it recorded by someone without the REFUND_APPROVE
-- permission (owner/admin) does not touch the ledger; it becomes a pending request that an approver accepts or rejects.
-- NULL threshold = off (every refund is recorded immediately, as before).
ALTER TABLE businesses ADD COLUMN refund_approval_threshold numeric(14,2) CHECK (refund_approval_threshold IS NULL OR refund_approval_threshold >= 0);

CREATE TABLE refund_requests (
    id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id      uuid NOT NULL,
    booking_id       uuid NOT NULL,
    amount           numeric(14,2) NOT NULL CHECK (amount > 0),
    currency         varchar(3) NOT NULL,
    method           varchar(20) NOT NULL CHECK (method IN ('CASH','BANK_TRANSFER','CARD_MANUAL')),
    provider_ref     varchar(200),
    status           varchar(10) NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING','APPROVED','REJECTED')),
    idempotency_key  varchar(100) NOT NULL,
    requested_by     uuid NOT NULL,
    decided_by       uuid,
    decided_at       timestamptz,
    decision_note    varchar(500),
    created_at       timestamptz NOT NULL DEFAULT now(),
    FOREIGN KEY (booking_id, business_id) REFERENCES bookings(id, business_id),
    UNIQUE (business_id, idempotency_key),
    CHECK ((status = 'PENDING') = (decided_by IS NULL))
);
CREATE INDEX refund_requests_business_status_idx ON refund_requests (business_id, status, created_at);

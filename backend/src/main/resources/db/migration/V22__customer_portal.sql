-- Customer portal inside ONE business: a customer proves they own the phone number with a one-time SMS code and then sees and cancels their own bookings.
-- Codes are stored hashed, expire in 10 minutes and allow 5 wrong attempts; sessions are random tokens stored hashed. Everything is scoped by business AND customer.
CREATE TABLE portal_otps (
    id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id  uuid NOT NULL,
    customer_id  uuid NOT NULL,
    code_hash    varchar(64) NOT NULL,
    attempts     int NOT NULL DEFAULT 0,
    expires_at   timestamptz NOT NULL,
    used_at      timestamptz,
    created_at   timestamptz NOT NULL DEFAULT now(),
    FOREIGN KEY (customer_id, business_id) REFERENCES customers(id, business_id) ON DELETE CASCADE
);
CREATE INDEX portal_otps_customer_idx ON portal_otps (customer_id, created_at DESC);

CREATE TABLE portal_sessions (
    id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id  uuid NOT NULL,
    customer_id  uuid NOT NULL,
    token_hash   varchar(64) NOT NULL UNIQUE,
    expires_at   timestamptz NOT NULL,
    revoked_at   timestamptz,
    created_at   timestamptz NOT NULL DEFAULT now(),
    FOREIGN KEY (customer_id, business_id) REFERENCES customers(id, business_id) ON DELETE CASCADE
);
CREATE INDEX portal_sessions_customer_idx ON portal_sessions (customer_id);

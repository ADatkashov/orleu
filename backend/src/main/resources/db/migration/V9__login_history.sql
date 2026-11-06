-- V9: per-user sign-in history (security audit trail shown to the user; purged after 90 days).
CREATE TABLE login_events (
    id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    outcome     varchar(20) NOT NULL CHECK (outcome IN ('SUCCESS','FAILED_PASSWORD','FAILED_MFA','LOCKED')),
    mfa_used    boolean NOT NULL DEFAULT false,
    ip          varchar(45),
    user_agent  varchar(300),
    device_key  varchar(64) NOT NULL,   -- SHA-256 of the user agent with version numbers removed: "same kind of device"
    new_device  boolean NOT NULL DEFAULT false,
    occurred_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX login_events_user_time_idx ON login_events (user_id, occurred_at DESC);

-- V3: platform roles, business suspension, subscription period + history
ALTER TABLE users ADD COLUMN platform_role varchar(30)
    CHECK (platform_role IN ('SUPER_ADMIN','PLATFORM_SUPPORT','PLATFORM_ANALYST'));
CREATE INDEX users_platform_role_idx ON users (platform_role) WHERE platform_role IS NOT NULL;

ALTER TABLE businesses ADD COLUMN status varchar(20) NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE','SUSPENDED'));
ALTER TABLE businesses ADD COLUMN suspended_reason varchar(300);
-- NULL = no expiry (FREE or manually granted without end date)
ALTER TABLE businesses ADD COLUMN plan_expires_at timestamptz;

CREATE TABLE subscription_events (
    id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id   uuid NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    from_plan     varchar(30),
    to_plan       varchar(30) NOT NULL,
    reason        varchar(300),
    expires_at    timestamptz,
    actor_user_id uuid,            -- NULL = system (expiry job)
    created_at    timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX subscription_events_biz_idx ON subscription_events (business_id, created_at DESC);

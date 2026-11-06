-- V8: TOTP multi-factor authentication. The TOTP secret is stored encrypted (AES-256-GCM, key from configuration), recovery codes
-- only as SHA-256 hashes. last_used_step prevents replaying a code inside its validity window.
CREATE TABLE user_mfa (
    user_id        uuid PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    secret_cipher  bytea NOT NULL,
    enabled        boolean NOT NULL DEFAULT false,
    last_used_step bigint NOT NULL DEFAULT 0,
    created_at     timestamptz NOT NULL DEFAULT now(),
    enabled_at     timestamptz
);

CREATE TABLE mfa_recovery_codes (
    id        uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id   uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    code_hash varchar(64) NOT NULL,
    used_at   timestamptz,
    UNIQUE (user_id, code_hash)
);

-- Second step of a login: an opaque, short-lived, single-use token (NOT a JWT, so it can never be accepted as an access token).
CREATE TABLE mfa_challenges (
    id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token_hash  varchar(64) NOT NULL UNIQUE,
    user_agent  varchar(300),
    attempts    int NOT NULL DEFAULT 0,
    expires_at  timestamptz NOT NULL,
    used_at     timestamptz,
    created_at  timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX mfa_challenges_user_idx ON mfa_challenges (user_id);

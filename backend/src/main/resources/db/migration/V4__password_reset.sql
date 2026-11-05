-- V4: password reset tokens (single use, short lived, stored hashed)
CREATE TABLE password_reset_tokens (
    id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token_hash  varchar(64) NOT NULL UNIQUE,
    expires_at  timestamptz NOT NULL,
    used_at     timestamptz,
    created_at  timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX password_reset_user_idx ON password_reset_tokens (user_id);

-- Why a refresh token was revoked. Only ROTATED tokens presented again are treated as theft (family revocation);
-- tokens revoked by logout / password change / session revocation are simply rejected.
ALTER TABLE refresh_tokens ADD COLUMN revoked_reason varchar(20);

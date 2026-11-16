-- Issue #15: additive account recovery, email proof and login sessions.
-- Run ONLY on hhk-staging after green CI and a recoverable offsite backup.
BEGIN;
ALTER TABLE app_accounts ADD COLUMN email_verified_at TIMESTAMPTZ;
ALTER TABLE account_sessions
  ADD COLUMN device_label TEXT NOT NULL DEFAULT 'Thiết bị đăng nhập',
  ADD COLUMN last_used_at TIMESTAMPTZ NOT NULL DEFAULT now();
CREATE TABLE account_action_tokens (
  id UUID PRIMARY KEY,
  account_id UUID NOT NULL REFERENCES app_accounts(id) ON DELETE CASCADE,
  kind TEXT NOT NULL CHECK (kind IN ('verify','reset','email_change')),
  token_hash BYTEA NOT NULL UNIQUE CHECK (octet_length(token_hash)=32),
  target_email TEXT,
  expires_at TIMESTAMPTZ NOT NULL,
  used_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CHECK ((kind='email_change')=(target_email IS NOT NULL))
);
CREATE INDEX idx_account_action_owner ON account_action_tokens(account_id,kind,created_at DESC);
CREATE INDEX idx_account_action_expiry ON account_action_tokens(expires_at) WHERE used_at IS NULL;
CREATE TABLE account_action_throttle (
  key TEXT PRIMARY KEY,
  hits INTEGER NOT NULL DEFAULT 0,
  window_started TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TABLE account_security_audit (
  id BIGSERIAL PRIMARY KEY,
  account_id UUID NOT NULL REFERENCES app_accounts(id) ON DELETE CASCADE,
  event TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_account_audit_owner ON account_security_audit(account_id,created_at DESC);
INSERT INTO hhk_schema_migrations(version,source_path)
VALUES ('0004','db-prisma/migrations/0004_account_security.sql')
ON CONFLICT (version) DO NOTHING;
COMMIT;

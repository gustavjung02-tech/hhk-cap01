-- HHK staging-first account ownership. Apply only after green CI, never implicitly on deployment.
-- No progress, child identity, or private raw license keys live in this schema.
BEGIN;

CREATE TABLE app_accounts (
  id UUID PRIMARY KEY,
  email TEXT NOT NULL UNIQUE,
  password_salt BYTEA NOT NULL CHECK (octet_length(password_salt) = 16),
  password_hash BYTEA NOT NULL CHECK (octet_length(password_hash) = 64),
  failed_logins INTEGER NOT NULL DEFAULT 0 CHECK (failed_logins >= 0),
  locked_until TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CHECK (email = lower(email))
);

CREATE TABLE account_sessions (
  id UUID PRIMARY KEY,
  account_id UUID NOT NULL REFERENCES app_accounts(id) ON DELETE CASCADE,
  token_hash BYTEA NOT NULL UNIQUE CHECK (octet_length(token_hash) = 32),
  expires_at TIMESTAMPTZ NOT NULL,
  revoked_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_account_sessions_owner ON account_sessions(account_id);
CREATE INDEX idx_account_sessions_expires ON account_sessions(expires_at);

ALTER TABLE licenses ADD COLUMN account_id UUID REFERENCES app_accounts(id);
CREATE INDEX idx_licenses_account ON licenses(account_id, issued_at DESC);

INSERT INTO hhk_schema_migrations(version,source_path)
VALUES ('0003','db-prisma/migrations/0003_accounts.sql')
ON CONFLICT (version) DO NOTHING;

COMMIT;

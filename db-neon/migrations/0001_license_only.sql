-- Học Hứng Khởi: no child learning records, no XP, no AI/chat, only keys and redemptions.
BEGIN;

CREATE TABLE IF NOT EXISTS print_batches (
  id UUID PRIMARY KEY,
  batch_code TEXT NOT NULL UNIQUE,
  notebooks_per_pack SMALLINT NOT NULL DEFAULT 20 CHECK (notebooks_per_pack=20),
  quantity_packs INTEGER NOT NULL CHECK (quantity_packs > 0),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS reward_campaigns (
  id UUID PRIMARY KEY,
  campaign_code TEXT NOT NULL UNIQUE,
  active BOOLEAN NOT NULL DEFAULT false,
  policy JSONB NOT NULL DEFAULT '{}'::jsonb,
  policy_version INTEGER NOT NULL CHECK(policy_version>0),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- QR code carries a token. Store only its hash; never publish raw tokens in DB dumps.
CREATE TABLE IF NOT EXISTS claim_tokens (
  id UUID PRIMARY KEY,
  batch_id UUID NOT NULL REFERENCES print_batches(id),
  token_hash BYTEA NOT NULL UNIQUE CHECK(octet_length(token_hash)=32),
  campaign_id UUID REFERENCES reward_campaigns(id),
  status TEXT NOT NULL DEFAULT 'unclaimed' CHECK(status IN ('unclaimed','redeemed','disabled')),
  redeemed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CHECK ((status='redeemed') = (redeemed_at IS NOT NULL))
);
CREATE INDEX IF NOT EXISTS idx_claim_batch ON claim_tokens(batch_id);

-- Public activation code is random; only hash is persisted.
CREATE TABLE IF NOT EXISTS licenses (
  id UUID PRIMARY KEY,
  token_id UUID UNIQUE REFERENCES claim_tokens(id),
  license_hash BYTEA NOT NULL UNIQUE CHECK(octet_length(license_hash)=32),
  source TEXT NOT NULL CHECK(source IN ('book_gift','retail','manual')),
  entitled_grades SMALLINT[] NOT NULL DEFAULT '{}'::smallint[],
  valid_from TIMESTAMPTZ NOT NULL DEFAULT now(),
  valid_until TIMESTAMPTZ,
  max_devices SMALLINT NOT NULL DEFAULT 1 CHECK(max_devices BETWEEN 1 AND 10),
  status TEXT NOT NULL DEFAULT 'issued' CHECK(status IN ('issued','active','revoked','expired')),
  issued_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CHECK(valid_until IS NULL OR valid_until > valid_from)
);
CREATE INDEX IF NOT EXISTS idx_license_status ON licenses(status);

CREATE TABLE IF NOT EXISTS device_activations (
  id UUID PRIMARY KEY,
  license_id UUID NOT NULL REFERENCES licenses(id),
  device_public_key_hash BYTEA NOT NULL CHECK(octet_length(device_public_key_hash)=32),
  active BOOLEAN NOT NULL DEFAULT true,
  activated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  revoked_at TIMESTAMPTZ,
  UNIQUE(license_id,device_public_key_hash),
  CHECK ((NOT active) OR (revoked_at IS NULL))
);
CREATE INDEX IF NOT EXISTS idx_device_active ON device_activations(license_id) WHERE active;

CREATE TABLE IF NOT EXISTS license_audit (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  license_id UUID REFERENCES licenses(id),
  claim_token_id UUID REFERENCES claim_tokens(id),
  operation TEXT NOT NULL,
  outcome TEXT NOT NULL,
  occurred_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb
);

COMMIT;

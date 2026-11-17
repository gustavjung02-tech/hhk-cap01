-- HHK: generic issuance of QR claim tokens; no product, pack or quantity assumptions.
-- Historical migrations are immutable; this one converts existing staging rows.
BEGIN;

ALTER TABLE print_batches RENAME TO claim_batches;
ALTER TABLE claim_batches RENAME COLUMN quantity_packs TO token_count;
ALTER TABLE claim_batches DROP COLUMN notebooks_per_pack;
ALTER TABLE claim_batches RENAME CONSTRAINT print_batches_pkey TO claim_batches_pkey;
ALTER TABLE claim_batches RENAME CONSTRAINT print_batches_batch_code_key TO claim_batches_batch_code_key;
ALTER TABLE claim_batches RENAME CONSTRAINT print_batches_quantity_packs_check
  TO claim_batches_token_count_check;

-- Preserve the source of existing licenses without rewriting prior audit.
ALTER TABLE licenses DROP CONSTRAINT licenses_source_check;
ALTER TABLE licenses ADD CONSTRAINT licenses_source_check
  CHECK (source IN ('qr_claim','book_gift','retail','manual'));

INSERT INTO hhk_schema_migrations(version,source_path)
VALUES ('0005','db-prisma/migrations/0005_generic_claim_batches.sql')
ON CONFLICT (version) DO NOTHING;

COMMIT;

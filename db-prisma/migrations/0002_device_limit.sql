-- HHK staging: server-side device capacity enforcement and migration registry.
-- No student profiles, XP, or user content. Apply only after 0001_license_only.
BEGIN;

CREATE TABLE IF NOT EXISTS hhk_schema_migrations (
  version TEXT PRIMARY KEY,
  source_path TEXT NOT NULL,
  applied_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
INSERT INTO hhk_schema_migrations (version, source_path)
VALUES ('0001', 'db-prisma/migrations/0001_license_only.sql')
ON CONFLICT (version) DO NOTHING;

-- Each activation locks its parent license row, serializing concurrent slots,
-- including accidental/direct SQL inserts that bypass the API.
CREATE OR REPLACE FUNCTION hhk_check_device_limit() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE
  allowed_slots integer;
  occupied_slots integer;
BEGIN
  IF NOT NEW.active THEN
    RETURN NEW;
  END IF;
  SELECT max_devices INTO allowed_slots
  FROM licenses WHERE id = NEW.license_id FOR UPDATE;
  IF allowed_slots IS NULL THEN
    RAISE EXCEPTION 'license not found' USING ERRCODE = '23503';
  END IF;
  SELECT count(*) INTO occupied_slots
  FROM device_activations
  WHERE license_id = NEW.license_id
    AND active
    AND id <> NEW.id;
  IF occupied_slots >= allowed_slots THEN
    RAISE EXCEPTION 'device quota exceeded' USING ERRCODE = '23514';
  END IF;
  RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS trg_hhk_device_limit ON device_activations;
CREATE TRIGGER trg_hhk_device_limit
BEFORE INSERT OR UPDATE OF active, license_id ON device_activations
FOR EACH ROW EXECUTE FUNCTION hhk_check_device_limit();

-- Don't allow an administrator to reduce a license limit below existing slots.
CREATE OR REPLACE FUNCTION hhk_check_license_limit() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE occupied_slots integer;
BEGIN
  SELECT count(*) INTO occupied_slots
  FROM device_activations WHERE license_id = NEW.id AND active;
  IF occupied_slots > NEW.max_devices THEN
    RAISE EXCEPTION 'existing active devices exceed new limit'
      USING ERRCODE = '23514';
  END IF;
  RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS trg_hhk_license_limit ON licenses;
CREATE TRIGGER trg_hhk_license_limit
BEFORE UPDATE OF max_devices ON licenses
FOR EACH ROW EXECUTE FUNCTION hhk_check_license_limit();

INSERT INTO hhk_schema_migrations (version, source_path)
VALUES ('0002', 'db-prisma/migrations/0002_device_limit.sql')
ON CONFLICT (version) DO NOTHING;
COMMIT;

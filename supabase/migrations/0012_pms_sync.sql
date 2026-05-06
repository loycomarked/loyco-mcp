-- 0012_pms_sync.sql
-- PMS import audit + raw payload retention + per-row error log.

CREATE TABLE pms_imports (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_group_id      uuid REFERENCES chain_groups(id) ON DELETE SET NULL,
  hotel_id            uuid REFERENCES hotels(id) ON DELETE SET NULL,
  pms_code            pms_system_code NOT NULL,
  source_kind         text NOT NULL,                          -- 'file' | 'api' | 'webhook' | 'manual'
  source_identifier   text,                                   -- file name, API endpoint, etc.
  status              pms_import_status NOT NULL DEFAULT 'queued',
  rows_total          int,
  rows_succeeded      int NOT NULL DEFAULT 0,
  rows_failed         int NOT NULL DEFAULT 0,
  started_at          timestamptz,
  finished_at         timestamptz,
  initiated_by        uuid REFERENCES admin_users(id) ON DELETE SET NULL,
  metadata            jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at          timestamptz NOT NULL DEFAULT now(),
  updated_at          timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX pms_imports_chain_started_idx ON pms_imports(chain_group_id, started_at DESC);
CREATE INDEX pms_imports_status_idx ON pms_imports(status);

CREATE TABLE pms_raw_payloads (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  import_id       uuid NOT NULL REFERENCES pms_imports(id) ON DELETE CASCADE,
  pms_code        pms_system_code NOT NULL,
  source_id       text,                                       -- e.g., reservation number, transaction id, member id at source
  payload         jsonb NOT NULL,
  payload_hash    text,                                       -- sha256 of payload for dedup
  ingested_at     timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE pms_raw_payloads ALTER COLUMN payload SET STORAGE EXTENDED;

CREATE INDEX pms_raw_payloads_import_idx ON pms_raw_payloads(import_id);
CREATE INDEX pms_raw_payloads_source_idx ON pms_raw_payloads(pms_code, source_id);
CREATE INDEX pms_raw_payloads_payload_gin ON pms_raw_payloads USING gin (payload jsonb_path_ops);

CREATE TABLE pms_sync_errors (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  import_id       uuid NOT NULL REFERENCES pms_imports(id) ON DELETE CASCADE,
  row_index       int,
  error_message   text NOT NULL,
  error_code      text,
  raw_row         jsonb,
  occurred_at     timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX pms_sync_errors_import_idx ON pms_sync_errors(import_id);

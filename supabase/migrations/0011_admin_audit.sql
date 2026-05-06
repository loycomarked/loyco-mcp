-- 0011_admin_audit.sql
-- Adminportal user profiles, hotel assignments, and audit log.
-- auth.users is the authentication source; admin_users is the profile (ADR-0015).

CREATE TABLE admin_users (
  id                 uuid PRIMARY KEY,                              -- = auth.users.id
  display_name       text,
  email              text,
  app_role           app_role NOT NULL,
  chain_group_id     uuid REFERENCES chain_groups(id) ON DELETE SET NULL,
  is_active          boolean NOT NULL DEFAULT true,
  last_login_at      timestamptz,
  metadata           jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at         timestamptz NOT NULL DEFAULT now(),
  updated_at         timestamptz NOT NULL DEFAULT now(),
  -- loyco_admin doesn't need a chain; everyone else does
  CHECK (app_role = 'loyco_admin' OR chain_group_id IS NOT NULL)
);

CREATE TABLE admin_user_hotel_assignments (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  admin_user_id   uuid NOT NULL REFERENCES admin_users(id) ON DELETE CASCADE,
  hotel_id        uuid NOT NULL REFERENCES hotels(id) ON DELETE CASCADE,
  assigned_at     timestamptz NOT NULL DEFAULT now(),
  assigned_by     uuid REFERENCES admin_users(id) ON DELETE SET NULL,
  UNIQUE (admin_user_id, hotel_id)
);

CREATE INDEX admin_user_hotel_assignments_user_idx
  ON admin_user_hotel_assignments(admin_user_id);
CREATE INDEX admin_user_hotel_assignments_hotel_idx
  ON admin_user_hotel_assignments(hotel_id);

CREATE TABLE audit_log (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  occurred_at     timestamptz NOT NULL DEFAULT now(),
  actor_user_id   uuid,                                  -- nullable for system events
  actor_role      app_role,
  action          audit_action NOT NULL,
  table_name      text NOT NULL,
  record_id       uuid,
  chain_group_id  uuid REFERENCES chain_groups(id) ON DELETE SET NULL,
  before_value    jsonb,
  after_value     jsonb,
  context         jsonb NOT NULL DEFAULT '{}'::jsonb,
  CHECK (action IN ('insert','update','delete','login','logout','role_change','manual_adjust'))
);

CREATE INDEX audit_log_occurred_at_idx ON audit_log (occurred_at DESC);
CREATE INDEX audit_log_actor_idx ON audit_log (actor_user_id, occurred_at DESC);
CREATE INDEX audit_log_table_record_idx ON audit_log (table_name, record_id);
CREATE INDEX audit_log_chain_idx ON audit_log (chain_group_id, occurred_at DESC);

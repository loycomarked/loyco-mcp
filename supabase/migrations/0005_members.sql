-- 0005_members.sql
-- Members + their identifiers, consents, tier history, attributes.
-- Members are scoped per chain (ADR-0009).

CREATE TABLE members (
  id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_group_id           uuid NOT NULL REFERENCES chain_groups(id) ON DELETE RESTRICT,
  program_id               uuid NOT NULL REFERENCES loyalty_programs(id) ON DELETE RESTRICT,
  auth_user_id             uuid,                                 -- nullable; future link to auth.users
  member_number            text,                                 -- chain-issued display number; nullable for anonymous OTA-pulled placeholders
  first_name               text,
  last_name                text,
  full_name                text GENERATED ALWAYS AS (
    NULLIF(trim(coalesce(first_name,'') || ' ' || coalesce(last_name,'')), '')
  ) STORED,
  email                    text,                                 -- canonical (lowercased)
  email_raw                text,
  phone_e164               text,                                 -- canonical E.164 form
  phone_raw                text,
  birth_date               date,                                 -- nullable; legacy data uses 1800-01-01 placeholder which we coerce to NULL on import
  gender                   member_gender NOT NULL DEFAULT 'unknown',
  preferred_language       text NOT NULL DEFAULT 'nb',
  country_code             char(2) REFERENCES regions(code),
  city                     text,
  postal_code              text,
  address_line1            text,
  address_line2            text,
  joined_at                timestamptz NOT NULL DEFAULT now(),
  status                   member_status NOT NULL DEFAULT 'active',
  current_tier_id          uuid REFERENCES tiers(id) ON DELETE SET NULL,
  recruitment_source       text,                                 -- e.g., 'StayNTouchIntegration', 'widget_xxx', 'AuthOtp'
  recruitment_hotel_id     uuid REFERENCES hotels(id) ON DELETE SET NULL,
  recruited_via_ota        boolean NOT NULL DEFAULT false,
  recruitment_ota_source   text,                                 -- e.g., 'Booking.com'
  program_tag              text,                                 -- e.g., '364Silver', '268plus' from real exports
  program_tag_alias        text,
  region                   text,                                 -- legacy free-text region label (e.g. 'NO', 'SE')
  external_membership_raw  jsonb,                                -- raw 'External Membership' JSON array preserved verbatim
  searchable_tsv           tsvector,
  metadata                 jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at               timestamptz NOT NULL DEFAULT now(),
  updated_at               timestamptz NOT NULL DEFAULT now(),
  UNIQUE (chain_group_id, member_number),
  CHECK (email IS NULL OR email = lower(email))
);

-- Per-chain uniqueness on email and phone, case-insensitive on email
CREATE UNIQUE INDEX members_chain_email_uniq
  ON members (chain_group_id, lower(email)) WHERE email IS NOT NULL;
CREATE UNIQUE INDEX members_chain_phone_uniq
  ON members (chain_group_id, phone_e164) WHERE phone_e164 IS NOT NULL;

-- searchable_tsv is maintained via trigger so members can be full-text searched
CREATE OR REPLACE FUNCTION lc_members_tsv_update() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  NEW.searchable_tsv :=
       setweight(to_tsvector('simple', coalesce(NEW.first_name, '')), 'A')
    || setweight(to_tsvector('simple', coalesce(NEW.last_name, '')),  'A')
    || setweight(to_tsvector('simple', coalesce(NEW.email, '')),      'B')
    || setweight(to_tsvector('simple', coalesce(NEW.phone_e164, '')), 'B')
    || setweight(to_tsvector('simple', coalesce(NEW.member_number, '')), 'B')
    || setweight(to_tsvector('simple', coalesce(NEW.city, '')),       'C');
  NEW.updated_at := now();
  RETURN NEW;
END $$;

CREATE TRIGGER members_tsv_trigger
  BEFORE INSERT OR UPDATE ON members
  FOR EACH ROW EXECUTE FUNCTION lc_members_tsv_update();

CREATE TABLE member_external_ids (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  member_id   uuid NOT NULL REFERENCES members(id) ON DELETE CASCADE,
  id_type     external_id_type NOT NULL,
  id_value    text NOT NULL,
  is_valid    boolean NOT NULL DEFAULT true,
  valid_from  timestamptz,
  metadata    jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at  timestamptz NOT NULL DEFAULT now(),
  UNIQUE (id_type, id_value)
);

CREATE INDEX member_external_ids_member_idx ON member_external_ids(member_id);

CREATE TABLE member_consents (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  member_id     uuid NOT NULL REFERENCES members(id) ON DELETE CASCADE,
  consent_type  consent_type NOT NULL,
  granted       boolean NOT NULL,
  granted_at    timestamptz NOT NULL DEFAULT now(),
  source        text,                          -- e.g., 'signup_widget', 'pms_import', 'admin_manual'
  ip_address    inet,
  user_agent    text,
  notes         text,
  metadata      jsonb NOT NULL DEFAULT '{}'::jsonb
);

-- Helper view: latest consent per (member, type)
CREATE INDEX member_consents_member_type_time_idx
  ON member_consents (member_id, consent_type, granted_at DESC);

CREATE TABLE member_tier_history (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  member_id         uuid NOT NULL REFERENCES members(id) ON DELETE CASCADE,
  from_tier_id      uuid REFERENCES tiers(id),
  to_tier_id        uuid NOT NULL REFERENCES tiers(id),
  change_reason     tier_change_reason NOT NULL,
  effective_at      timestamptz NOT NULL DEFAULT now(),
  changed_by        uuid,                       -- references auth.users for manual; null for automatic
  notes             text,
  context           jsonb NOT NULL DEFAULT '{}'::jsonb,    -- snapshot: counted_points, counted_nights, period_window, etc.
  created_at        timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX member_tier_history_member_time_idx
  ON member_tier_history (member_id, effective_at DESC);

CREATE TABLE member_attributes (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  member_id   uuid NOT NULL REFERENCES members(id) ON DELETE CASCADE,
  attr_key    text NOT NULL,
  attr_value  jsonb NOT NULL,
  source      text,                            -- 'manual' | 'segment_evaluation' | 'pms_import' | ...
  set_by      uuid,
  set_at      timestamptz NOT NULL DEFAULT now(),
  expires_at  timestamptz,
  UNIQUE (member_id, attr_key)
);

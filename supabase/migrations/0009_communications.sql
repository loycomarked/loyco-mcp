-- 0009_communications.sql
-- Unified communications log (SMS + email + push) per ADR-0011, plus reusable templates.

CREATE TABLE communication_templates (
  id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_group_id     uuid NOT NULL REFERENCES chain_groups(id) ON DELETE CASCADE,
  code               text NOT NULL,
  name               text NOT NULL,
  channel            comm_channel NOT NULL,
  category           comm_category NOT NULL,
  subject_template   text,
  body_template      text NOT NULL,
  language           text NOT NULL DEFAULT 'nb',
  is_active          boolean NOT NULL DEFAULT true,
  metadata           jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at         timestamptz NOT NULL DEFAULT now(),
  updated_at         timestamptz NOT NULL DEFAULT now(),
  UNIQUE (chain_group_id, channel, code, language)
);

CREATE TABLE communications (
  id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_group_id       uuid NOT NULL REFERENCES chain_groups(id) ON DELETE CASCADE,
  hotel_id             uuid REFERENCES hotels(id) ON DELETE SET NULL,
  member_id            uuid REFERENCES members(id) ON DELETE SET NULL,
  channel              comm_channel NOT NULL,
  direction            comm_direction NOT NULL DEFAULT 'outbound',
  category             comm_category NOT NULL,
  status               comm_status NOT NULL DEFAULT 'queued',
  template_id          uuid REFERENCES communication_templates(id) ON DELETE SET NULL,
  campaign_id          uuid,                              -- FK added in marketing migration
  automation_run_id    uuid,                              -- FK added in marketing migration
  -- Address fields (nullable, channel-typed)
  to_email             text,
  to_phone             text,
  from_email           text,
  from_phone           text,
  sender_label         text,                              -- e.g. 'FirstHotels', '18335532709'
  -- Content
  subject              text,
  body                 text,
  language             text NOT NULL DEFAULT 'nb',
  -- Timing
  queued_at            timestamptz,
  sent_at              timestamptz,
  delivered_at         timestamptz,
  failed_at            timestamptz,
  opened_at            timestamptz,
  clicked_at           timestamptz,
  -- Provider
  provider             text,
  external_message_id  text,
  failure_reason       text,
  -- SMS specifics (kept inline to match real export shape)
  sms_logical_count    int,
  sms_real_count       int,
  scandinavia_flag     boolean,
  -- Misc
  cost_amount          numeric(14,4),
  cost_currency        char(3) REFERENCES currencies(code),
  metadata             jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at           timestamptz NOT NULL DEFAULT now(),
  updated_at           timestamptz NOT NULL DEFAULT now(),
  CHECK (channel <> 'email' OR (to_email IS NOT NULL OR direction = 'inbound')),
  CHECK (channel <> 'sms'   OR (to_phone IS NOT NULL OR direction = 'inbound'))
);

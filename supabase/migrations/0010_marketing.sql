-- 0010_marketing.sql
-- Engage module: campaigns, recipients, segments, automations.

CREATE TABLE segments (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_group_id      uuid NOT NULL REFERENCES chain_groups(id) ON DELETE CASCADE,
  code                text NOT NULL,
  name                text NOT NULL,
  description         text,
  -- Audience definition as a rule tree (jsonb). Stored declaratively so a future visual builder can render it.
  -- Engine semantics defined later in code; schema is data-only.
  definition          jsonb NOT NULL DEFAULT '{"type":"all"}'::jsonb,
  is_dynamic          boolean NOT NULL DEFAULT true,    -- false = static snapshot
  estimated_size      int,                              -- last computed audience size
  last_computed_at    timestamptz,
  is_active           boolean NOT NULL DEFAULT true,
  metadata            jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at          timestamptz NOT NULL DEFAULT now(),
  updated_at          timestamptz NOT NULL DEFAULT now(),
  UNIQUE (chain_group_id, code)
);

CREATE TABLE campaigns (
  id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_group_id           uuid NOT NULL REFERENCES chain_groups(id) ON DELETE CASCADE,
  code                     text NOT NULL,
  name                     text NOT NULL,
  channel                  comm_channel NOT NULL,
  status                   campaign_status NOT NULL DEFAULT 'draft',
  segment_id               uuid REFERENCES segments(id) ON DELETE SET NULL,
  template_id              uuid REFERENCES communication_templates(id) ON DELETE SET NULL,
  start_date               date,
  end_date                 date,
  scheduled_send_at        timestamptz,
  -- Aggregates (denormalized for fast list views; truth is in campaign_recipients)
  recipient_count          int NOT NULL DEFAULT 0,
  delivered_count          int NOT NULL DEFAULT 0,
  opened_count             int NOT NULL DEFAULT 0,
  clicked_count            int NOT NULL DEFAULT 0,
  bounced_count            int NOT NULL DEFAULT 0,
  attributed_bookings      int NOT NULL DEFAULT 0,
  attributed_revenue       numeric(14,2) NOT NULL DEFAULT 0,
  attributed_revenue_ccy   char(3) REFERENCES currencies(code),
  metadata                 jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at               timestamptz NOT NULL DEFAULT now(),
  updated_at               timestamptz NOT NULL DEFAULT now(),
  UNIQUE (chain_group_id, code),
  CHECK (end_date IS NULL OR start_date IS NULL OR end_date >= start_date)
);

CREATE TABLE campaign_recipients (
  id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  campaign_id        uuid NOT NULL REFERENCES campaigns(id) ON DELETE CASCADE,
  member_id          uuid NOT NULL REFERENCES members(id) ON DELETE CASCADE,
  communication_id   uuid REFERENCES communications(id) ON DELETE SET NULL,
  status             comm_status NOT NULL DEFAULT 'queued',
  sent_at            timestamptz,
  delivered_at       timestamptz,
  opened_at          timestamptz,
  clicked_at         timestamptz,
  bounced_at         timestamptz,
  unsubscribed_at    timestamptz,
  attributed_booking_id uuid REFERENCES bookings(id) ON DELETE SET NULL,
  attributed_revenue numeric(14,2),
  attributed_currency char(3) REFERENCES currencies(code),
  metadata           jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at         timestamptz NOT NULL DEFAULT now(),
  UNIQUE (campaign_id, member_id)
);

CREATE INDEX campaign_recipients_member_idx ON campaign_recipients(member_id);

-- Now that campaigns exists, add the FK from communications.campaign_id
ALTER TABLE communications
  ADD CONSTRAINT communications_campaign_fk
  FOREIGN KEY (campaign_id) REFERENCES campaigns(id) ON DELETE SET NULL;

CREATE TABLE automations (
  id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_group_id       uuid NOT NULL REFERENCES chain_groups(id) ON DELETE CASCADE,
  code                 text NOT NULL,
  name                 text NOT NULL,
  description          text,
  trigger_type         automation_trigger NOT NULL,
  trigger_config       jsonb NOT NULL DEFAULT '{}'::jsonb,    -- e.g. {"delay_minutes": 30, "filters": {...}}
  status               automation_status NOT NULL DEFAULT 'draft',
  segment_id           uuid REFERENCES segments(id) ON DELETE SET NULL,
  metadata             jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at           timestamptz NOT NULL DEFAULT now(),
  updated_at           timestamptz NOT NULL DEFAULT now(),
  UNIQUE (chain_group_id, code)
);

CREATE TABLE automation_steps (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  automation_id   uuid NOT NULL REFERENCES automations(id) ON DELETE CASCADE,
  step_index      int NOT NULL,                         -- 0-based ordering
  action_type     automation_action_type NOT NULL,
  template_id     uuid REFERENCES communication_templates(id) ON DELETE SET NULL,
  params          jsonb NOT NULL DEFAULT '{}'::jsonb,    -- e.g. {"wait_minutes": 60} for 'wait', {"tag": "vip"} for 'add_tag'
  is_active       boolean NOT NULL DEFAULT true,
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now(),
  UNIQUE (automation_id, step_index)
);

CREATE TABLE automation_runs (
  id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  automation_id        uuid NOT NULL REFERENCES automations(id) ON DELETE CASCADE,
  member_id            uuid REFERENCES members(id) ON DELETE SET NULL,
  trigger_event        jsonb NOT NULL DEFAULT '{}'::jsonb,
  status               automation_run_status NOT NULL DEFAULT 'queued',
  current_step_index   int,
  started_at           timestamptz NOT NULL DEFAULT now(),
  finished_at          timestamptz,
  error_message        text,
  created_at           timestamptz NOT NULL DEFAULT now(),
  updated_at           timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX automation_runs_automation_status_idx ON automation_runs(automation_id, status);
CREATE INDEX automation_runs_member_idx ON automation_runs(member_id);

-- Now add the FK from communications.automation_run_id
ALTER TABLE communications
  ADD CONSTRAINT communications_automation_run_fk
  FOREIGN KEY (automation_run_id) REFERENCES automation_runs(id) ON DELETE SET NULL;

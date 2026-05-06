-- 0004_loyalty_config.sql
-- Loyalty program configuration: programs, tiers, thresholds, benefits, points rules, rewards.
-- All scoped to a chain. Per ADR-0006 these are fully chain-configurable.

CREATE TABLE loyalty_programs (
  id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_group_id       uuid NOT NULL REFERENCES chain_groups(id) ON DELETE CASCADE,
  slug                 text NOT NULL,
  name                 text NOT NULL,
  description          text,
  points_currency      char(3) NOT NULL REFERENCES currencies(code),     -- "1 point = 1 unit of this currency"
  points_expiry_months int CHECK (points_expiry_months IS NULL OR points_expiry_months > 0),
  is_active            boolean NOT NULL DEFAULT true,
  metadata             jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at           timestamptz NOT NULL DEFAULT now(),
  updated_at           timestamptz NOT NULL DEFAULT now(),
  UNIQUE (chain_group_id, slug)
);

CREATE TABLE tiers (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  program_id          uuid NOT NULL REFERENCES loyalty_programs(id) ON DELETE CASCADE,
  chain_group_id      uuid NOT NULL REFERENCES chain_groups(id) ON DELETE CASCADE,
  code                text NOT NULL,                  -- e.g., 'bronze', 'silver', 'gold', 'platinum', 'black'
  name                text NOT NULL,                  -- display name
  sort_order          int  NOT NULL,                  -- 1 = lowest, ascending
  multiplier_default  numeric(5,2) NOT NULL DEFAULT 1.00 CHECK (multiplier_default >= 0),
  color_hex           text,
  icon_url            text,
  is_default_initial  boolean NOT NULL DEFAULT false, -- the tier a new member starts on
  is_active           boolean NOT NULL DEFAULT true,
  metadata            jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at          timestamptz NOT NULL DEFAULT now(),
  updated_at          timestamptz NOT NULL DEFAULT now(),
  UNIQUE (program_id, code),
  UNIQUE (program_id, sort_order)
);

CREATE UNIQUE INDEX tiers_one_initial_per_program
  ON tiers (program_id) WHERE is_default_initial = true;

CREATE TABLE tier_thresholds (
  id                          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tier_id                     uuid NOT NULL REFERENCES tiers(id) ON DELETE CASCADE,
  metric                      tier_metric NOT NULL,     -- points | nights | revenue
  min_value                   numeric(14,2) NOT NULL CHECK (min_value >= 0),
  qualifying_period_months    int NOT NULL DEFAULT 12 CHECK (qualifying_period_months > 0),
  valid_from                  date NOT NULL DEFAULT '1970-01-01',
  valid_to                    date,
  metadata                    jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at                  timestamptz NOT NULL DEFAULT now(),
  updated_at                  timestamptz NOT NULL DEFAULT now(),
  CHECK (valid_to IS NULL OR valid_to >= valid_from),
  UNIQUE (tier_id, metric, valid_from)
);

CREATE TABLE tier_benefits (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tier_id     uuid NOT NULL REFERENCES tiers(id) ON DELETE CASCADE,
  benefit_key text NOT NULL,                            -- machine-readable, e.g. 'late_checkout', 'free_drink', 'priority_checkin'
  label       text NOT NULL,                            -- human display
  description text,
  value       jsonb NOT NULL DEFAULT '{}'::jsonb,       -- structured params (e.g., {"hours": 2})
  is_active   boolean NOT NULL DEFAULT true,
  sort_order  int NOT NULL DEFAULT 0,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now(),
  UNIQUE (tier_id, benefit_key)
);

CREATE TABLE points_rules (
  id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  program_id               uuid NOT NULL REFERENCES loyalty_programs(id) ON DELETE CASCADE,
  chain_group_id           uuid NOT NULL REFERENCES chain_groups(id) ON DELETE CASCADE,
  hotel_id                 uuid REFERENCES hotels(id) ON DELETE CASCADE,        -- NULL = applies to all hotels in program
  channel                  booking_channel,                                      -- NULL = any channel
  market_segment_code      text,                                                 -- NULL = any segment
  rate_group_code          text,                                                 -- NULL = any rate group
  percent_of_payment       numeric(5,2) NOT NULL CHECK (percent_of_payment >= 0 AND percent_of_payment <= 100),
  tier_multiplier_override jsonb,                                                -- e.g., {"silver": 1.2, "gold": 1.5} overrides tier defaults
  priority                 int NOT NULL DEFAULT 0,                               -- higher wins on ties
  valid_from               date NOT NULL DEFAULT '1970-01-01',
  valid_to                 date,
  description              text,
  is_active                boolean NOT NULL DEFAULT true,
  created_at               timestamptz NOT NULL DEFAULT now(),
  updated_at               timestamptz NOT NULL DEFAULT now(),
  CHECK (valid_to IS NULL OR valid_to >= valid_from)
);

CREATE TABLE rewards (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  program_id          uuid NOT NULL REFERENCES loyalty_programs(id) ON DELETE CASCADE,
  chain_group_id      uuid NOT NULL REFERENCES chain_groups(id) ON DELETE CASCADE,
  code                text NOT NULL,
  name                text NOT NULL,
  description         text,
  reward_type         reward_type NOT NULL,
  cost_points         int NOT NULL CHECK (cost_points > 0),
  cost_currency_amount numeric(14,2),
  cost_currency       char(3) REFERENCES currencies(code),
  min_tier_id         uuid REFERENCES tiers(id),                  -- NULL = any tier
  hotel_id            uuid REFERENCES hotels(id) ON DELETE CASCADE,    -- NULL = available across program
  inventory_remaining int,                                          -- NULL = unlimited
  valid_from          date,
  valid_to            date,
  image_url           text,
  metadata            jsonb NOT NULL DEFAULT '{}'::jsonb,
  is_active           boolean NOT NULL DEFAULT true,
  created_at          timestamptz NOT NULL DEFAULT now(),
  updated_at          timestamptz NOT NULL DEFAULT now(),
  UNIQUE (program_id, code),
  CHECK (valid_to IS NULL OR valid_from IS NULL OR valid_to >= valid_from)
);

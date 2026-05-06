-- 0008_points.sql
-- Points ledger (single source of truth for balances), redemptions, balance MV.

CREATE TABLE point_transactions (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_group_id      uuid NOT NULL REFERENCES chain_groups(id) ON DELETE RESTRICT,
  program_id          uuid NOT NULL REFERENCES loyalty_programs(id) ON DELETE RESTRICT,
  member_id           uuid NOT NULL REFERENCES members(id) ON DELETE CASCADE,
  type                point_transaction_type NOT NULL,
  status              point_transaction_status NOT NULL DEFAULT 'posted',
  -- positive = credit, negative = debit
  points_delta        int NOT NULL,
  -- Source linkage
  source_transaction_id uuid REFERENCES transactions(id) ON DELETE SET NULL,
  source_booking_id     uuid REFERENCES bookings(id) ON DELETE SET NULL,
  rule_id             uuid REFERENCES points_rules(id) ON DELETE SET NULL,
  reward_redemption_id uuid,                                        -- FK added below
  -- Tier multiplier and percent applied (for traceability)
  applied_percent     numeric(5,2),
  applied_multiplier  numeric(5,2),
  applied_tier_id     uuid REFERENCES tiers(id) ON DELETE SET NULL,
  -- Time
  occurred_at         timestamptz NOT NULL DEFAULT now(),
  effective_at        timestamptz NOT NULL DEFAULT now(),
  expires_at          timestamptz,
  -- Manual adjustments
  reason              text,
  performed_by        uuid,
  metadata            jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at          timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX point_transactions_member_time_idx
  ON point_transactions (member_id, occurred_at DESC);
CREATE INDEX point_transactions_member_status_idx
  ON point_transactions (member_id) WHERE status = 'posted';
CREATE INDEX point_transactions_chain_time_idx
  ON point_transactions (chain_group_id, occurred_at DESC);
CREATE INDEX point_transactions_expires_at_idx
  ON point_transactions (expires_at) WHERE expires_at IS NOT NULL AND status = 'posted';

CREATE TABLE point_redemptions (
  id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_group_id           uuid NOT NULL REFERENCES chain_groups(id) ON DELETE RESTRICT,
  member_id                uuid NOT NULL REFERENCES members(id) ON DELETE CASCADE,
  reward_id                uuid NOT NULL REFERENCES rewards(id) ON DELETE RESTRICT,
  points_spent             int NOT NULL CHECK (points_spent > 0),
  redemption_date          timestamptz NOT NULL DEFAULT now(),
  fulfilled_at             timestamptz,
  related_booking_id       uuid REFERENCES bookings(id) ON DELETE SET NULL,
  status                   text NOT NULL DEFAULT 'fulfilled',  -- 'pending' | 'fulfilled' | 'cancelled' | 'expired'
  notes                    text,
  metadata                 jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at               timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE point_transactions
  ADD CONSTRAINT point_transactions_redemption_fk
  FOREIGN KEY (reward_redemption_id) REFERENCES point_redemptions(id) ON DELETE SET NULL;

CREATE INDEX point_redemptions_member_idx ON point_redemptions(member_id);
CREATE INDEX point_redemptions_reward_idx ON point_redemptions(reward_id);

-- Materialized view: current balance + pending + expiring within 30 days, per member.
CREATE MATERIALIZED VIEW points_balances_mv AS
SELECT
  m.id AS member_id,
  m.chain_group_id,
  m.program_id,
  COALESCE(SUM(pt.points_delta) FILTER (WHERE pt.status = 'posted'), 0)::int AS balance_posted,
  COALESCE(SUM(pt.points_delta) FILTER (WHERE pt.status = 'pending'), 0)::int AS balance_pending,
  COALESCE(SUM(pt.points_delta) FILTER (
    WHERE pt.status = 'posted'
      AND pt.expires_at IS NOT NULL
      AND pt.expires_at <= (now() + interval '30 days')
  ), 0)::int AS expiring_30d,
  MAX(pt.occurred_at) AS last_activity_at
FROM members m
LEFT JOIN point_transactions pt ON pt.member_id = m.id
GROUP BY m.id, m.chain_group_id, m.program_id;

CREATE UNIQUE INDEX points_balances_mv_member_idx ON points_balances_mv(member_id);
CREATE INDEX points_balances_mv_chain_idx ON points_balances_mv(chain_group_id);

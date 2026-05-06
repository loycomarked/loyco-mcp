-- 07_points.sql
-- One earn_release per earning transaction; pending earns for in_house bookings; ~50 manual adjustments;
-- Reward redemptions for ~5% of high-tier members + companion debit point_transactions.
-- Refresh balance MV at end.

SELECT setseed(0.47);

INSERT INTO point_transactions (
  chain_group_id, program_id, member_id, type, status, points_delta,
  source_transaction_id, source_booking_id,
  applied_percent, applied_multiplier, applied_tier_id,
  occurred_at, effective_at, expires_at, reason, metadata
)
SELECT
  tx.chain_group_id, m.program_id, tx.member_id,
  'earn_release'::point_transaction_type, 'posted'::point_transaction_status,
  ROUND(tx.bonus_earned_amount)::int,
  tx.id, tx.booking_id,
  tx.bonus_percent_at_posting, COALESCE(t.multiplier_default, 1.0), m.current_tier_id,
  tx.posting_date::timestamptz + interval '23 hours',
  tx.posting_date::timestamptz + interval '23 hours',
  CASE WHEN lp.points_expiry_months IS NOT NULL
    THEN tx.posting_date::timestamptz + (lp.points_expiry_months || ' months')::interval
    ELSE NULL END,
  'Bonus earned on transaction',
  jsonb_build_object('source','seed_auto','transaction_external_id', tx.external_transaction_id)
FROM transactions tx
JOIN members m ON m.id = tx.member_id
JOIN loyalty_programs lp ON lp.id = m.program_id
LEFT JOIN tiers t ON t.id = m.current_tier_id
WHERE tx.bonus_earned_amount > 0 AND tx.status='posted' AND tx.transaction_type='charge';

WITH adj_targets AS (
  SELECT m.id AS member_id, m.chain_group_id, m.program_id, m.current_tier_id
  FROM members m WHERE random() < 0.025 LIMIT 50
)
INSERT INTO point_transactions (
  chain_group_id, program_id, member_id, type, status, points_delta,
  applied_tier_id, occurred_at, effective_at, reason, performed_by, metadata
)
SELECT a.chain_group_id, a.program_id, a.member_id,
  'manual_adjustment'::point_transaction_type, 'posted'::point_transaction_status,
  CASE WHEN random() < 0.5 THEN (500 + (random()*2000)::int) ELSE -(200 + (random()*800)::int) END,
  a.current_tier_id, now() - (random()*200)::int * interval '1 day', now() - (random()*200)::int * interval '1 day',
  (ARRAY['goodwill_credit','complaint_compensation','correction','referral_bonus'])[1 + floor(random()*4)::int],
  NULL, jsonb_build_object('source','seed_manual')
FROM adj_targets a;

WITH redeemers AS (
  SELECT m.id AS member_id, m.chain_group_id, m.program_id, m.current_tier_id, m.joined_at
  FROM members m JOIN tiers t ON t.id = m.current_tier_id
  WHERE t.sort_order >= 2 AND m.status = 'active' AND random() < 0.10
),
chosen_rewards AS (
  SELECT r.member_id, r.chain_group_id, r.program_id, r.current_tier_id, r.joined_at,
    rw.id AS reward_id, rw.cost_points,
    row_number() OVER (PARTITION BY r.member_id ORDER BY random()) AS rn
  FROM redeemers r
  JOIN rewards rw ON rw.program_id = r.program_id AND rw.is_active
)
INSERT INTO point_redemptions (chain_group_id, member_id, reward_id, points_spent, redemption_date, fulfilled_at, status, metadata)
SELECT cr.chain_group_id, cr.member_id, cr.reward_id, cr.cost_points,
  cr.joined_at + (random() * (extract(epoch from now() - cr.joined_at)))::int * interval '1 second',
  cr.joined_at + (random() * (extract(epoch from now() - cr.joined_at)))::int * interval '1 second' + interval '1 day',
  'fulfilled', '{"source":"seed"}'::jsonb
FROM chosen_rewards cr WHERE cr.rn = 1;

INSERT INTO point_transactions (
  chain_group_id, program_id, member_id, type, status, points_delta,
  reward_redemption_id, applied_tier_id, occurred_at, effective_at, reason, metadata
)
SELECT pr.chain_group_id, m.program_id, pr.member_id,
  'redeem'::point_transaction_type, 'posted'::point_transaction_status, -pr.points_spent,
  pr.id, m.current_tier_id, pr.redemption_date, pr.redemption_date,
  'Reward redemption: ' || rw.name,
  jsonb_build_object('reward_code', rw.code)
FROM point_redemptions pr
JOIN members m ON m.id = pr.member_id
JOIN rewards rw ON rw.id = pr.reward_id;

INSERT INTO point_transactions (
  chain_group_id, program_id, member_id, type, status, points_delta,
  source_transaction_id, source_booking_id, applied_percent, applied_multiplier, applied_tier_id,
  occurred_at, effective_at, reason, metadata
)
SELECT tx.chain_group_id, m.program_id, tx.member_id,
  'earn_pending'::point_transaction_type, 'pending'::point_transaction_status,
  ROUND(tx.bonus_earned_amount)::int,
  tx.id, tx.booking_id, tx.bonus_percent_at_posting, COALESCE(t.multiplier_default, 1.0), m.current_tier_id,
  tx.posting_date::timestamptz + interval '23 hours', tx.posting_date::timestamptz + interval '23 hours',
  'Bonus pending — booking still active', jsonb_build_object('source','seed_pending')
FROM transactions tx
JOIN bookings b ON b.id = tx.booking_id
JOIN members m ON m.id = tx.member_id
LEFT JOIN tiers t ON t.id = m.current_tier_id
WHERE tx.bonus_earned_amount > 0 AND b.status = 'in_house';

REFRESH MATERIALIZED VIEW CONCURRENTLY points_balances_mv;

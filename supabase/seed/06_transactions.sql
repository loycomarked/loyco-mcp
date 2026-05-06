-- 06_transactions.sql
-- One transaction per booking with status in (checked_out, in_house, cancelled, no_show).
-- Bonus calculation derived from chain × tier × channel lookup.
-- transaction_lines: 1 main 'Accommodation' line per tx + ~30% with F&B/Spa extra line.
-- 30% of transactions show different original_currency vs posted_currency (multi-currency stay).

SELECT setseed(0.46);

WITH bonus_lookup AS (
  SELECT * FROM (VALUES
    ('a1111111-0000-0000-0000-000000000001','bronze',  'direct',    2.0),
    ('a1111111-0000-0000-0000-000000000001','silver',  'direct',    5.0),
    ('a1111111-0000-0000-0000-000000000001','gold',    'direct',    10.0),
    ('a1111111-0000-0000-0000-000000000001','platinum','direct',    15.0),
    ('a1111111-0000-0000-0000-000000000001','black',   'direct',    18.0),
    ('a1111111-0000-0000-0000-000000000001','bronze',  'corporate', 3.0),
    ('a1111111-0000-0000-0000-000000000001','silver',  'corporate', 3.6),
    ('a1111111-0000-0000-0000-000000000001','gold',    'corporate', 4.5),
    ('a1111111-0000-0000-0000-000000000001','platinum','corporate', 5.4),
    ('a1111111-0000-0000-0000-000000000001','black',   'corporate', 6.0),
    ('a1111111-0000-0000-0000-000000000002','bronze',  'direct',    3.0),
    ('a1111111-0000-0000-0000-000000000002','silver',  'direct',    5.0),
    ('a1111111-0000-0000-0000-000000000002','gold',    'direct',    8.0),
    ('a1111111-0000-0000-0000-000000000002','platinum','direct',    12.0),
    ('a1111111-0000-0000-0000-000000000002','bronze',  'corporate', 5.0),
    ('a1111111-0000-0000-0000-000000000002','silver',  'corporate', 5.0),
    ('a1111111-0000-0000-0000-000000000002','gold',    'corporate', 5.0),
    ('a1111111-0000-0000-0000-000000000002','platinum','corporate', 5.0),
    ('a1111111-0000-0000-0000-000000000003','explorer','direct',    5.0),
    ('a1111111-0000-0000-0000-000000000003','voyager', 'direct',    8.0),
    ('a1111111-0000-0000-0000-000000000003','aurora',  'direct',    12.0),
    ('a1111111-0000-0000-0000-000000000003','midnight','direct',    15.0),
    ('a1111111-0000-0000-0000-000000000004','standard','direct',    2.0),
    ('a1111111-0000-0000-0000-000000000004','frequent','direct',    4.0),
    ('a1111111-0000-0000-0000-000000000004','elite',   'direct',    6.0),
    ('a1111111-0000-0000-0000-000000000004','executive','direct',   10.0),
    ('a1111111-0000-0000-0000-000000000004','standard','corporate', 4.0),
    ('a1111111-0000-0000-0000-000000000004','frequent','corporate', 5.0),
    ('a1111111-0000-0000-0000-000000000004','elite',   'corporate', 6.0),
    ('a1111111-0000-0000-0000-000000000004','executive','corporate',8.0),
    ('a1111111-0000-0000-0000-000000000005','circle',     'direct', 5.0),
    ('a1111111-0000-0000-0000-000000000005','inner-circle','direct',10.0)
  ) AS t(chain_id, tier_code, channel, pct)
),
src AS (
  SELECT b.*, t.code AS tier_code,
    random() AS r_fx, random() AS r_orig_pick, random() AS r_gc, random() AS r_extra
  FROM bookings b
  LEFT JOIN members m ON m.id = b.member_id
  LEFT JOIN tiers t ON t.id = m.current_tier_id
  WHERE b.status IN ('checked_out','in_house','cancelled','no_show')
    AND COALESCE(b.paid_amount, b.total_amount) > 0
),
fx AS (
  SELECT s.*,
    CASE WHEN s.r_orig_pick < 0.30 THEN (ARRAY['NOK','SEK','DKK','EUR','USD'])[1 + floor(s.r_fx*5)::int] ELSE NULL END AS orig_ccy,
    CASE WHEN s.r_orig_pick < 0.30 THEN ROUND((0.85 + s.r_fx * 0.30)::numeric, 4) ELSE NULL END AS fx_rate_picked,
    CASE WHEN s.r_orig_pick < 0.30 THEN COALESCE(s.check_out_at::date, s.arrival_date) - (s.r_fx * 30)::int ELSE NULL END AS fx_date_picked,
    bl.pct AS bonus_pct
  FROM src s
  LEFT JOIN bonus_lookup bl ON bl.chain_id::uuid = s.chain_group_id AND bl.tier_code = s.tier_code AND bl.channel = s.channel::text
)
INSERT INTO transactions (
  chain_group_id, hotel_id, booking_id, member_id, external_transaction_id, external_reference,
  transaction_type, status, posting_date, transaction_date,
  posted_amount, posted_currency, original_amount, original_currency, fx_rate, fx_rate_date,
  paid_amount, bonus_percent_at_posting, bonus_earned_amount, bonus_released_amount,
  giftcard_applied_amount, is_ota, segment_label, metadata
)
SELECT
  fx.chain_group_id, fx.hotel_id, fx.id, fx.member_id,
  '4' || substring(md5(fx.id::text), 1, 12), NULL,
  CASE fx.status WHEN 'cancelled' THEN 'refund' ELSE 'charge' END::transaction_type,
  'posted'::transaction_status,
  COALESCE(fx.check_out_at::date, fx.cancelled_at::date, fx.arrival_date),
  fx.arrival_date,
  CASE WHEN fx.status = 'cancelled' THEN COALESCE(-fx.paid_amount * 0.5, 0) ELSE COALESCE(fx.paid_amount, fx.total_amount) END,
  fx.currency,
  CASE WHEN fx.fx_rate_picked IS NOT NULL THEN ROUND((COALESCE(fx.paid_amount, fx.total_amount) / fx.fx_rate_picked)::numeric, 2) ELSE NULL END,
  fx.orig_ccy, fx.fx_rate_picked, fx.fx_date_picked, COALESCE(fx.paid_amount, 0),
  CASE WHEN fx.member_id IS NULL OR fx.channel = 'ota' THEN 0 ELSE COALESCE(fx.bonus_pct, 0) END,
  CASE WHEN fx.member_id IS NULL OR fx.channel = 'ota' OR fx.status = 'cancelled' THEN 0
       ELSE ROUND((COALESCE(fx.paid_amount, 0) * COALESCE(fx.bonus_pct, 0) / 100)::numeric, 2) END,
  CASE WHEN fx.status = 'checked_out' AND fx.member_id IS NOT NULL AND fx.channel <> 'ota' THEN
    ROUND((COALESCE(fx.paid_amount, 0) * COALESCE(fx.bonus_pct, 0) / 100)::numeric, 2) ELSE 0 END,
  CASE WHEN fx.r_gc < 0.05 AND fx.status='checked_out' THEN ROUND((fx.r_extra*500)::numeric, 2) ELSE 0 END,
  fx.channel = 'ota',
  CASE fx.channel WHEN 'ota' THEN 'OTA' WHEN 'direct' THEN 'Direct' WHEN 'corporate' THEN 'Corporate' ELSE 'Other' END,
  jsonb_build_object('seed','true','booking_status', fx.status::text)
FROM fx;

INSERT INTO transaction_lines (transaction_id, product_type, line_info, quantity, unit_amount, amount, currency, bonus_factor, product_code)
SELECT tx.id, 'Accommodation',
  'RoomType:' || ((100 + (length(tx.external_transaction_id) * 13)) % 9999)::text,
  GREATEST(b.nights, 1)::numeric,
  CASE WHEN b.nights > 0 THEN ROUND((tx.posted_amount / b.nights)::numeric, 2) ELSE tx.posted_amount END,
  ROUND((tx.posted_amount * 0.92)::numeric, 2),
  tx.posted_currency, 1.0,
  'ROOM-' || (length(tx.external_transaction_id) % 100)::text
FROM transactions tx JOIN bookings b ON b.id = tx.booking_id;

INSERT INTO transaction_lines (transaction_id, product_type, line_info, quantity, unit_amount, amount, currency, bonus_factor, product_code)
SELECT tx.id, (ARRAY['Food','Beverage','Spa'])[1 + floor(random()*3)::int],
  NULL, 1::numeric,
  ROUND((tx.posted_amount * 0.08)::numeric, 2),
  ROUND((tx.posted_amount * 0.08)::numeric, 2),
  tx.posted_currency, 0.5, NULL
FROM transactions tx JOIN bookings b ON b.id = tx.booking_id
WHERE b.status = 'checked_out' AND random() < 0.30;

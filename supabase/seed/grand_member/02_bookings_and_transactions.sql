-- ====================================================================
-- Grand Member re-seed — Part 2 of 3: bookings + room_stays + segments + history + transactions + lines
-- Run AFTER part 1.
-- Estimated runtime: 30–90 seconds (the heaviest part).
-- Member/non-member split: 65/35. Non-member rate ~0.65-0.95×, members ~0.85-1.35×. Non-member nights weighted to 1-3.
-- ====================================================================

SELECT setseed(0.44);

-- ===== 2.1 Bookings (40 000 across 15 hotels) =====
WITH hotels_per_chain AS (
  SELECT chain_group_id,
         array_agg(id ORDER BY id) AS hotel_ids,
         array_agg(default_currency ORDER BY id) AS ccys,
         array_agg(default_pms ORDER BY id) AS pmss,
         count(*)::int AS sz
  FROM hotels
  WHERE chain_group_id = 'a1111111-aaaa-aaaa-aaaa-000000000001'
  GROUP BY chain_group_id
),
members_arr AS (
  SELECT array_agg(id ORDER BY id) AS member_ids, count(*)::int AS sz FROM members
),
gs AS (
  SELECT n FROM generate_series(1, 40000) AS n
),
generated AS (
  SELECT
    g.n,
    'a1111111-aaaa-aaaa-aaaa-000000000001'::uuid AS chain_id,
    h.hotel_ids, h.ccys, h.pmss, h.sz AS hotel_sz,
    m.member_ids, m.sz AS member_sz,
    random() AS r1, random() AS r2, random() AS r3, random() AS r4, random() AS r5, random() AS r6, random() AS r7,
    -- arrival_date in 2023-05-01 .. 2027-05-01 with rough weekly seasonality bump
    (date '2023-05-01' + ((g.n * 73) % 1462) +
       CASE WHEN ((g.n) % 7) IN (0,1,2) THEN 0 ELSE (random() * 7)::int END
    ) AS raw_date_seed
  FROM gs g
  CROSS JOIN hotels_per_chain h
  CROSS JOIN members_arr m
),
prepared AS (
  SELECT g.*,
    g.hotel_ids[1 + ((g.n + 7) % g.hotel_sz)] AS hotel_id_pick,
    g.ccys[1 + ((g.n + 7) % g.hotel_sz)] AS hotel_ccy,
    g.pmss[1 + ((g.n + 7) % g.hotel_sz)] AS hotel_pms,
    -- 65% have a member, 35% non-member (ADR-0018)
    (g.r1 < 0.65) AS is_member,
    CASE WHEN g.r1 < 0.65 THEN g.member_ids[1 + ((g.n * 13 + 17) % g.member_sz)] ELSE NULL END AS member_id_pick,
    -- channel mix
    CASE
      WHEN g.r2 < 0.55 THEN 'ota'
      WHEN g.r2 < 0.82 THEN 'direct'
      WHEN g.r2 < 0.92 THEN 'corporate'
      WHEN g.r2 < 0.96 THEN 'group'
      ELSE 'walk_in'
    END::booking_channel AS channel_pick,
    g.raw_date_seed AS arrival_pick,
    -- Non-members get shorter stays (90% 1-3 nights), members get the original distribution
    CASE
      WHEN g.r1 >= 0.65 THEN
        CASE WHEN random() < 0.85 THEN 1 + (random() * 2)::int ELSE 3 + (random() * 4)::int END
      ELSE
        CASE WHEN random() < 0.65 THEN 1 + (random() * 2)::int
             WHEN random() < 0.90 THEN 3 + (random() * 4)::int
             ELSE 5 + (random() * 9)::int END
    END AS nights_pick
  FROM generated g
),
status_assigned AS (
  SELECT p.*, p.arrival_pick + p.nights_pick AS departure_pick,
    CASE
      WHEN p.arrival_pick > current_date THEN
        CASE WHEN p.r3 < 0.05 THEN 'cancelled' ELSE 'upcoming' END
      WHEN p.arrival_pick + p.nights_pick > current_date AND p.arrival_pick <= current_date THEN
        CASE WHEN p.r3 < 0.10 THEN 'cancelled' ELSE 'in_house' END
      ELSE
        CASE
          WHEN p.r3 < 0.12 THEN 'cancelled'
          WHEN p.r3 < 0.14 THEN 'no_show'
          ELSE 'checked_out'
        END
    END::booking_status AS status_pick
  FROM prepared p
),
final AS (
  SELECT s.*,
    -- Per-night base rate: 2200 NOK for NO/SE/DK hotels, scaled per hotel currency for foreign
    -- Member bookings: 0.85-1.35× base. Non-member: 0.65-0.95× base.
    ROUND((
      CASE s.hotel_ccy::text
        WHEN 'NOK' THEN 2200
        WHEN 'SEK' THEN 2400
        WHEN 'DKK' THEN 1800
        WHEN 'EUR' THEN 220
        WHEN 'ISK' THEN 28000
        ELSE 2200
      END
      * s.nights_pick
      * CASE WHEN s.is_member THEN (0.85 + s.r4 * 0.50) ELSE (0.65 + s.r4 * 0.30) END
    )::numeric, 2) AS total_pick,
    (1000000 + s.n)::text AS resv_no_pick
  FROM status_assigned s
)
INSERT INTO bookings (
  chain_group_id, hotel_id, member_id,
  pms_code, pms_reservation_no, pms_confirmation_code,
  channel, status, arrival_date, departure_date, check_in_at, check_out_at,
  num_guests, num_rooms, total_amount, currency, paid_amount,
  reservation_source_label, is_member_booking, returning_member, cancelled_at, booked_at, metadata
)
SELECT
  f.chain_id, f.hotel_id_pick, f.member_id_pick, f.hotel_pms, f.resv_no_pick,
  upper(substring(md5(f.resv_no_pick) for 8)),
  f.channel_pick, f.status_pick, f.arrival_pick, f.departure_pick,
  CASE WHEN f.status_pick IN ('in_house','checked_out') THEN f.arrival_pick + interval '14 hours' + (f.r5 * interval '6 hours') ELSE NULL END,
  CASE WHEN f.status_pick = 'checked_out' THEN f.departure_pick + interval '11 hours' + (f.r6 * interval '2 hours') ELSE NULL END,
  1 + (f.r5 * 3)::int,
  CASE WHEN f.r6 < 0.05 THEN 2 ELSE 1 END,
  f.total_pick, f.hotel_ccy,
  CASE WHEN f.status_pick IN ('checked_out','in_house') THEN f.total_pick ELSE 0 END,
  CASE f.hotel_pms WHEN 'stayntouch' THEN 'StayNTouchIntegration' WHEN 'mews' THEN 'ChannelManager' WHEN 'protel_air' THEN 'ProtelAirPMSintegration' WHEN 'visbook' THEN 'VisbookIntegration' ELSE 'OtherIntegration' END,
  f.is_member,
  CASE WHEN f.is_member AND f.r7 < 0.40 THEN true WHEN f.is_member THEN false ELSE NULL END,
  CASE WHEN f.status_pick = 'cancelled' THEN f.arrival_pick - (1 + (f.r4 * 30)::int) * interval '1 day' ELSE NULL END,
  f.arrival_pick - (7 + (f.r3 * 60)::int) * interval '1 day',
  jsonb_build_object('seed','true','n', f.n,'is_member', f.is_member)
FROM final f;

-- ===== 2.2 Room stays =====
INSERT INTO room_stays (booking_id, hotel_id, room_number, room_type_code, room_type_name, arrival_date, departure_date, guests_count, rate_amount_per_night, currency, metadata)
SELECT b.id, b.hotel_id,
  ((100 + (b.num_rooms * 50) + (length(b.pms_reservation_no) * 17)) % 999)::text,
  CASE ((length(b.pms_reservation_no) * 7) % 5) WHEN 0 THEN 'STD' WHEN 1 THEN 'SUP' WHEN 2 THEN 'DLX' WHEN 3 THEN 'JRSTE' ELSE 'STE' END,
  CASE ((length(b.pms_reservation_no) * 7) % 5) WHEN 0 THEN 'Standard' WHEN 1 THEN 'Superior' WHEN 2 THEN 'Deluxe' WHEN 3 THEN 'Junior Suite' ELSE 'Suite' END,
  b.arrival_date, b.departure_date, b.num_guests,
  CASE WHEN b.nights > 0 AND b.total_amount IS NOT NULL THEN ROUND((b.total_amount / b.nights)::numeric, 2) ELSE NULL END,
  b.currency, '{}'::jsonb
FROM bookings b;

INSERT INTO room_stays (booking_id, hotel_id, room_number, room_type_code, room_type_name, arrival_date, departure_date, guests_count, rate_amount_per_night, currency)
SELECT b.id, b.hotel_id,
  ((200 + (length(b.pms_reservation_no) * 11)) % 999)::text, 'STD','Standard',
  b.arrival_date, b.departure_date, b.num_guests,
  CASE WHEN b.nights > 0 AND b.total_amount IS NOT NULL THEN ROUND((b.total_amount / b.nights)::numeric * 0.85, 2) ELSE NULL END,
  b.currency
FROM bookings b WHERE b.num_rooms >= 2;

-- ===== 2.3 Booking segments (~75% of bookings) =====
INSERT INTO booking_segments (booking_id, market_segment_code, market_segment_label, rate_group_code, rate_code, source_code, business_segment, channel_manager, travel_agency, origin, service_name)
SELECT b.id,
  CASE b.channel WHEN 'ota' THEN 'OTA' WHEN 'direct' THEN 'WEB' WHEN 'corporate' THEN 'CGN' WHEN 'group' THEN 'GRP' ELSE 'WLK' END,
  CASE b.channel WHEN 'ota' THEN 'OTA - Online travel agency' WHEN 'direct' THEN 'WEB - Direct chain web booking' WHEN 'corporate' THEN 'CGN - Corporate groups on negotiated rates' WHEN 'group' THEN 'GRP - Group block reservation' ELSE 'WLK - Walk-in guest' END,
  CASE b.channel
    WHEN 'ota'    THEN (ARRAY['OTA 48 timer','NRF-WEB','OTA Flex','OTA NRF'])[1 + (length(b.pms_reservation_no) % 4)]
    WHEN 'direct' THEN (ARRAY['BAR','MEMBER','LASTMINUTE','EARLYBIRD'])[1 + (length(b.pms_reservation_no) % 4)]
    WHEN 'corporate' THEN 'CORP-NEGO' WHEN 'group' THEN 'GROUP-NEGO' ELSE NULL END,
  CASE b.channel
    WHEN 'ota'    THEN (ARRAY['Flex Booking','NonRef Booking','Advance Purchase'])[1 + (length(b.pms_reservation_no) % 3)]
    WHEN 'direct' THEN (ARRAY['Standard Rate','Member Rate','Advance Saver'])[1 + (length(b.pms_reservation_no) % 3)]
    WHEN 'corporate' THEN 'Negotiated Corporate' WHEN 'group' THEN 'Group Block' ELSE 'Walk-in Rate' END,
  CASE b.channel WHEN 'corporate' THEN 'Company direct' WHEN 'direct' THEN 'Brand.com' WHEN 'ota' THEN 'Channel Manager' ELSE NULL END,
  CASE b.channel WHEN 'ota' THEN 'Unqualified discount rate' WHEN 'direct' THEN 'Rack rate' WHEN 'corporate' THEN 'Negotiated rate' WHEN 'group' THEN 'Group rate' ELSE 'Other' END,
  CASE WHEN b.channel = 'ota' THEN (ARRAY['Booking.com','Expedia','Hotels.com','Agoda','Trip.com'])[1 + (length(b.pms_reservation_no) % 5)] ELSE NULL END,
  CASE WHEN b.channel = 'corporate' THEN (ARRAY['BCD Travel','American Express GBT','CWT','Egencia','HRG'])[1 + (length(b.pms_reservation_no) % 5)] ELSE NULL END,
  CASE b.channel WHEN 'ota' THEN 'ChannelManager' WHEN 'direct' THEN 'Direct' WHEN 'walk_in' THEN 'Walk-In' ELSE 'Direct' END,
  'Accommodation'
FROM bookings b WHERE random() < 0.75;

-- ===== 2.4 Booking status history =====
INSERT INTO booking_status_history (booking_id, from_status, to_status, occurred_at)
SELECT b.id, NULL, 'upcoming'::booking_status, b.booked_at FROM bookings b WHERE b.booked_at IS NOT NULL;

INSERT INTO booking_status_history (booking_id, from_status, to_status, occurred_at)
SELECT b.id, 'upcoming'::booking_status, b.status,
  CASE b.status WHEN 'cancelled' THEN b.cancelled_at WHEN 'in_house' THEN b.check_in_at WHEN 'no_show' THEN b.arrival_date::timestamptz + interval '23 hours' WHEN 'checked_out' THEN b.check_in_at ELSE NULL END
FROM bookings b WHERE b.status <> 'upcoming';

INSERT INTO booking_status_history (booking_id, from_status, to_status, occurred_at)
SELECT b.id, 'in_house'::booking_status, 'checked_out'::booking_status, b.check_out_at
FROM bookings b WHERE b.status = 'checked_out';

-- ===== 2.5 Transactions (one per non-cancelled-without-deposit booking + cancelled with refund) =====
SELECT setseed(0.46);

WITH bonus_lookup AS (
  SELECT * FROM (VALUES
    ('bronze',  'direct',    2.0),
    ('silver',  'direct',    5.0),
    ('gold',    'direct',    10.0),
    ('platinum','direct',    15.0),
    ('black',   'direct',    18.0),
    ('bronze',  'corporate', 3.0),
    ('silver',  'corporate', 3.6),
    ('gold',    'corporate', 4.5),
    ('platinum','corporate', 5.4),
    ('black',   'corporate', 6.0)
  ) AS t(tier_code, channel, pct)
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
  LEFT JOIN bonus_lookup bl ON bl.tier_code = s.tier_code AND bl.channel = s.channel::text
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
  jsonb_build_object('seed','true','booking_status', fx.status::text,'is_member_booking', (fx.member_id IS NOT NULL))
FROM fx;

-- ===== 2.6 Transaction lines =====
INSERT INTO transaction_lines (transaction_id, product_type, line_info, quantity, unit_amount, amount, currency, bonus_factor, product_code)
SELECT tx.id, 'Accommodation',
  'RoomType:' || ((100 + (length(tx.external_transaction_id) * 13)) % 9999)::text,
  GREATEST(b.nights, 1)::numeric,
  CASE WHEN b.nights > 0 THEN ROUND((tx.posted_amount / b.nights)::numeric, 2) ELSE tx.posted_amount END,
  ROUND((tx.posted_amount * 0.92)::numeric, 2),
  tx.posted_currency, 1.0,
  'ROOM-' || (length(tx.external_transaction_id) % 100)::text
FROM transactions tx JOIN bookings b ON b.id = tx.booking_id;

-- F&B/Spa lines: members 30%, non-members 15% (lower add-on usage)
INSERT INTO transaction_lines (transaction_id, product_type, line_info, quantity, unit_amount, amount, currency, bonus_factor, product_code)
SELECT tx.id, (ARRAY['Food','Beverage','Spa'])[1 + floor(random()*3)::int],
  NULL, 1::numeric,
  ROUND((tx.posted_amount * 0.08)::numeric, 2),
  ROUND((tx.posted_amount * 0.08)::numeric, 2),
  tx.posted_currency, 0.5, NULL
FROM transactions tx JOIN bookings b ON b.id = tx.booking_id
WHERE b.status = 'checked_out' AND
      ((b.member_id IS NOT NULL AND random() < 0.30) OR (b.member_id IS NULL AND random() < 0.15));

-- Sanity check
SELECT
  (SELECT count(*) FROM bookings) AS bookings,
  (SELECT count(*) FROM bookings WHERE member_id IS NOT NULL) AS member_bookings,
  (SELECT count(*) FROM bookings WHERE member_id IS NULL) AS non_member_bookings,
  (SELECT count(*) FROM room_stays) AS room_stays,
  (SELECT count(*) FROM booking_segments) AS segments,
  (SELECT count(*) FROM booking_status_history) AS status_history,
  (SELECT count(*) FROM transactions) AS transactions,
  (SELECT count(*) FROM transactions WHERE member_id IS NOT NULL) AS member_txs,
  (SELECT count(*) FROM transactions WHERE member_id IS NULL) AS non_member_txs,
  (SELECT round(avg(posted_amount))::int FROM transactions WHERE member_id IS NOT NULL AND status='posted' AND transaction_type='charge') AS avg_member_tx,
  (SELECT round(avg(posted_amount))::int FROM transactions WHERE member_id IS NULL AND status='posted' AND transaction_type='charge') AS avg_non_member_tx,
  (SELECT count(*) FROM transaction_lines) AS lines;

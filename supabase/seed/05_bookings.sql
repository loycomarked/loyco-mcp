-- 05_bookings.sql
-- 40 000 bookings (18k/12k/5k/4k/1k per chain) spanning 2023-05 to 2027-05.
-- Channel mix: 60% OTA, 25% direct, 10% corporate, 3% group, 2% walk-in.
-- Status mix: ~85% checked_out for past, ~95% upcoming for future, ~12% cancellations, ~2% no_show.
-- Then room_stays (1+ per booking), booking_segments (~75%), booking_status_history.

SELECT setseed(0.44);

WITH chain_size AS (
  SELECT * FROM (VALUES
    ('a1111111-0000-0000-0000-000000000001'::uuid, 18000, 2200, 'NOK', 100),
    ('a1111111-0000-0000-0000-000000000002'::uuid, 12000, 1800, 'NOK', 200),
    ('a1111111-0000-0000-0000-000000000003'::uuid,  5000, 5000, 'NOK', 300),
    ('a1111111-0000-0000-0000-000000000004'::uuid,  4000, 1900, 'SEK', 400),
    ('a1111111-0000-0000-0000-000000000005'::uuid,  1000, 4500, 'DKK', 500)
  ) AS t(chain_id, total_bookings, base_rate, base_ccy, chain_offset)
),
gs AS (SELECT cs.chain_id, cs.base_rate, cs.base_ccy, cs.chain_offset, n FROM chain_size cs, LATERAL generate_series(1, cs.total_bookings) AS n),
hotels_per_chain AS (
  SELECT chain_group_id, array_agg(id ORDER BY id) AS hotel_ids,
         array_agg(default_currency ORDER BY id) AS ccys,
         array_agg(default_pms ORDER BY id) AS pmss,
         count(*)::int AS sz
  FROM hotels GROUP BY chain_group_id
),
members_per_chain AS (SELECT chain_group_id, array_agg(id ORDER BY id) AS member_ids, count(*)::int AS sz FROM members GROUP BY chain_group_id),
generated AS (
  SELECT g.chain_id, g.n, g.chain_offset, g.base_rate, g.base_ccy,
    h.hotel_ids, h.ccys, h.pmss, h.sz AS hotel_sz, m.member_ids, m.sz AS member_sz,
    random() AS r1, random() AS r2, random() AS r3, random() AS r4, random() AS r5, random() AS r6, random() AS r7,
    (date '2023-05-01' + ((g.n + g.chain_offset * 73) % 1462) +
       CASE WHEN ((g.n) % 7) IN (0,1,2) THEN 0 ELSE (random() * 7)::int END) AS raw_date_seed,
    CASE WHEN random() < 0.65 THEN 1 + (random() * 2)::int
         WHEN random() < 0.90 THEN 3 + (random() * 4)::int
         ELSE 5 + (random() * 9)::int END AS nights_pick
  FROM gs g
  JOIN hotels_per_chain h ON h.chain_group_id = g.chain_id
  LEFT JOIN members_per_chain m ON m.chain_group_id = g.chain_id
),
prepared AS (
  SELECT g.*,
    g.hotel_ids[1 + ((g.n + g.chain_offset) % g.hotel_sz)] AS hotel_id_pick,
    g.ccys[1 + ((g.n + g.chain_offset) % g.hotel_sz)] AS hotel_ccy,
    g.pmss[1 + ((g.n + g.chain_offset) % g.hotel_sz)] AS hotel_pms,
    CASE WHEN g.r1 < 0.80 AND g.member_sz IS NOT NULL THEN g.member_ids[1 + ((g.n * 13 + g.chain_offset * 17) % g.member_sz)] ELSE NULL END AS member_id_pick,
    CASE WHEN g.r2 < 0.60 THEN 'ota' WHEN g.r2 < 0.85 THEN 'direct' WHEN g.r2 < 0.95 THEN 'corporate' WHEN g.r2 < 0.98 THEN 'group' ELSE 'walk_in' END::booking_channel AS channel_pick,
    g.raw_date_seed AS arrival_pick
  FROM generated g
),
status_assigned AS (
  SELECT p.*, p.arrival_pick + p.nights_pick AS departure_pick,
    CASE
      WHEN p.arrival_pick > current_date THEN CASE WHEN p.r3 < 0.05 THEN 'cancelled' ELSE 'upcoming' END
      WHEN p.arrival_pick + p.nights_pick > current_date AND p.arrival_pick <= current_date THEN
        CASE WHEN p.r3 < 0.10 THEN 'cancelled' ELSE 'in_house' END
      ELSE CASE WHEN p.r3 < 0.12 THEN 'cancelled' WHEN p.r3 < 0.14 THEN 'no_show' ELSE 'checked_out' END
    END::booking_status AS status_pick
  FROM prepared p
),
final AS (
  SELECT s.*, ROUND((s.base_rate * s.nights_pick * (0.7 + s.r4 * 0.7))::numeric, 2) AS total_pick,
    (1000000 + s.chain_offset * 1000000 + s.n)::text AS resv_no_pick
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
  f.member_id_pick IS NOT NULL,
  CASE WHEN f.member_id_pick IS NOT NULL AND f.r7 < 0.40 THEN true WHEN f.member_id_pick IS NOT NULL THEN false ELSE NULL END,
  CASE WHEN f.status_pick = 'cancelled' THEN f.arrival_pick - (1 + (f.r4 * 30)::int) * interval '1 day' ELSE NULL END,
  f.arrival_pick - (7 + (f.r3 * 60)::int) * interval '1 day',
  jsonb_build_object('seed','true','n', f.n)
FROM final f;

-- Room stays (1 per booking; multi-room get a 2nd row)
SELECT setseed(0.45);

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

-- booking_segments for ~75% of bookings
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

-- booking_status_history transitions
INSERT INTO booking_status_history (booking_id, from_status, to_status, occurred_at)
SELECT b.id, NULL, 'upcoming'::booking_status, b.booked_at FROM bookings b WHERE b.booked_at IS NOT NULL;

INSERT INTO booking_status_history (booking_id, from_status, to_status, occurred_at)
SELECT b.id, 'upcoming'::booking_status, b.status,
  CASE b.status WHEN 'cancelled' THEN b.cancelled_at WHEN 'in_house' THEN b.check_in_at WHEN 'no_show' THEN b.arrival_date::timestamptz + interval '23 hours' WHEN 'checked_out' THEN b.check_in_at ELSE NULL END
FROM bookings b WHERE b.status <> 'upcoming';

INSERT INTO booking_status_history (booking_id, from_status, to_status, occurred_at)
SELECT b.id, 'in_house'::booking_status, 'checked_out'::booking_status, b.check_out_at
FROM bookings b WHERE b.status = 'checked_out';

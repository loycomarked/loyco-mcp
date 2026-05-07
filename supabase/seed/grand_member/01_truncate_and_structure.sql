-- ====================================================================
-- Grand Member re-seed — Part 1 of 3: TRUNCATE + structure + members + ancillary
-- Paste this entire file into Supabase SQL Editor and run.
-- Estimated runtime: 5–15 seconds.
-- ====================================================================

-- ===== 1.1 TRUNCATE all data tables (keeps currencies, regions, pms_systems) =====
TRUNCATE
  audit_log,
  pms_sync_errors, pms_raw_payloads, pms_imports,
  automation_runs, automation_steps, automations,
  campaign_recipients, campaigns,
  segments,
  communications, communication_templates,
  point_redemptions, point_transactions,
  transaction_lines, transactions,
  booking_status_history, booking_segments, room_stays, bookings,
  member_attributes, member_tier_history, member_consents, member_external_ids, members,
  rewards, points_rules, tier_benefits, tier_thresholds, tiers, loyalty_programs,
  admin_user_hotel_assignments, admin_users,
  hotel_pms_connections, hotels,
  chain_groups,
  currency_rates
RESTART IDENTITY CASCADE;

-- ===== 1.2 Disable audit triggers during bulk seed (re-enabled at end of part 3) =====
ALTER TABLE members DISABLE TRIGGER members_audit;
ALTER TABLE bookings DISABLE TRIGGER bookings_audit;
ALTER TABLE point_transactions DISABLE TRIGGER point_transactions_manual_audit;
ALTER TABLE tiers DISABLE TRIGGER tiers_audit;
ALTER TABLE tier_thresholds DISABLE TRIGGER tier_thresholds_audit;
ALTER TABLE tier_benefits DISABLE TRIGGER tier_benefits_audit;
ALTER TABLE points_rules DISABLE TRIGGER points_rules_audit;
ALTER TABLE member_tier_history DISABLE TRIGGER member_tier_history_audit;
ALTER TABLE admin_users DISABLE TRIGGER admin_users_audit;
ALTER TABLE admin_user_hotel_assignments DISABLE TRIGGER admin_user_hotel_assignments_audit;

-- ===== 1.3 Single chain: Grand Member =====
INSERT INTO chain_groups (id, slug, name, legal_name, default_currency, reporting_currency, default_locale, headquarters_country, brand_color_hex, support_email, support_phone, founded_at, status) VALUES
  ('a1111111-aaaa-aaaa-aaaa-000000000001'::uuid, 'grand-member', 'Grand Member', 'Grand Hotels Norden AS', 'NOK','NOK','nb-NO','NO','#A8201A','support@grandmember.example','+4790000001','1995-04-12','active');

-- ===== 1.4 Single program: Grand Member =====
INSERT INTO loyalty_programs (id, chain_group_id, slug, name, description, points_currency, points_expiry_months, is_active) VALUES
  ('c3300001-aaaa-aaaa-aaaa-000000000001'::uuid, 'a1111111-aaaa-aaaa-aaaa-000000000001', 'grand-member', 'Grand Member', 'Grand Hotels Norden loyalty program — earn on direct stays, get more from every visit', 'NOK', 24, true);

-- ===== 1.5 Five tiers: Bronze → Silver → Gold → Platinum → Black =====
INSERT INTO tiers (id, program_id, chain_group_id, code, name, sort_order, multiplier_default, color_hex, is_default_initial, is_active) VALUES
  ('d4400001-aaaa-aaaa-aaaa-000000000001'::uuid, 'c3300001-aaaa-aaaa-aaaa-000000000001', 'a1111111-aaaa-aaaa-aaaa-000000000001', 'bronze',   'Bronze',   1, 1.0, '#CD7F32', true,  true),
  ('d4400001-aaaa-aaaa-aaaa-000000000002'::uuid, 'c3300001-aaaa-aaaa-aaaa-000000000001', 'a1111111-aaaa-aaaa-aaaa-000000000001', 'silver',   'Silver',   2, 1.2, '#C0C0C0', false, true),
  ('d4400001-aaaa-aaaa-aaaa-000000000003'::uuid, 'c3300001-aaaa-aaaa-aaaa-000000000001', 'a1111111-aaaa-aaaa-aaaa-000000000001', 'gold',     'Gold',     3, 1.5, '#FFD700', false, true),
  ('d4400001-aaaa-aaaa-aaaa-000000000004'::uuid, 'c3300001-aaaa-aaaa-aaaa-000000000001', 'a1111111-aaaa-aaaa-aaaa-000000000001', 'platinum', 'Platinum', 4, 1.8, '#E5E4E2', false, true),
  ('d4400001-aaaa-aaaa-aaaa-000000000005'::uuid, 'c3300001-aaaa-aaaa-aaaa-000000000001', 'a1111111-aaaa-aaaa-aaaa-000000000001', 'black',    'Black',    5, 2.2, '#0A0A0A', false, true);

INSERT INTO tier_thresholds (tier_id, metric, min_value, qualifying_period_months) VALUES
  ('d4400001-aaaa-aaaa-aaaa-000000000002', 'points', 5000,   12),
  ('d4400001-aaaa-aaaa-aaaa-000000000003', 'points', 15000,  12),
  ('d4400001-aaaa-aaaa-aaaa-000000000004', 'points', 40000,  12),
  ('d4400001-aaaa-aaaa-aaaa-000000000005', 'points', 100000, 12),
  ('d4400001-aaaa-aaaa-aaaa-000000000003', 'nights', 20,     12),
  ('d4400001-aaaa-aaaa-aaaa-000000000004', 'nights', 50,     12);

INSERT INTO tier_benefits (tier_id, benefit_key, label, description, value, sort_order) VALUES
  ('d4400001-aaaa-aaaa-aaaa-000000000001', 'free_wifi', 'Free Wi-Fi', 'Complimentary high-speed Wi-Fi', '{}'::jsonb, 1),
  ('d4400001-aaaa-aaaa-aaaa-000000000002', 'late_checkout', 'Late checkout to 14:00', NULL, '{"hours":2}'::jsonb, 2),
  ('d4400001-aaaa-aaaa-aaaa-000000000002', 'welcome_drink', 'Welcome drink', NULL, '{}'::jsonb, 3),
  ('d4400001-aaaa-aaaa-aaaa-000000000003', 'late_checkout_15', 'Late checkout to 15:00', NULL, '{"hours":3}'::jsonb, 1),
  ('d4400001-aaaa-aaaa-aaaa-000000000003', 'room_upgrade', 'Room upgrade when available', NULL, '{}'::jsonb, 2),
  ('d4400001-aaaa-aaaa-aaaa-000000000003', 'priority_checkin', 'Priority check-in', NULL, '{}'::jsonb, 3),
  ('d4400001-aaaa-aaaa-aaaa-000000000004', 'exec_lounge', 'Executive lounge access', NULL, '{}'::jsonb, 1),
  ('d4400001-aaaa-aaaa-aaaa-000000000004', 'breakfast_included', 'Breakfast included', NULL, '{}'::jsonb, 2),
  ('d4400001-aaaa-aaaa-aaaa-000000000005', 'concierge', 'Personal concierge', NULL, '{}'::jsonb, 1),
  ('d4400001-aaaa-aaaa-aaaa-000000000005', 'gift_card_annual', 'Annual NOK 2 000 gift card', NULL, '{"amount":2000,"currency":"NOK"}'::jsonb, 2);

INSERT INTO points_rules (program_id, chain_group_id, hotel_id, channel, percent_of_payment, tier_multiplier_override, priority, description) VALUES
  ('c3300001-aaaa-aaaa-aaaa-000000000001','a1111111-aaaa-aaaa-aaaa-000000000001', NULL, 'direct',    5.0,
   '{"bronze":0.4,"silver":1.0,"gold":2.0,"platinum":3.0,"black":3.6}'::jsonb, 100, 'Direct earn (yields 2/5/10/15/18% by tier)'),
  ('c3300001-aaaa-aaaa-aaaa-000000000001','a1111111-aaaa-aaaa-aaaa-000000000001', NULL, 'corporate', 3.0,
   '{"bronze":1.0,"silver":1.2,"gold":1.5,"platinum":1.8,"black":2.0}'::jsonb, 100, 'Corporate negotiated rates'),
  ('c3300001-aaaa-aaaa-aaaa-000000000001','a1111111-aaaa-aaaa-aaaa-000000000001', NULL, 'group',     1.0,
   NULL, 100, 'Group bookings flat 1%'),
  ('c3300001-aaaa-aaaa-aaaa-000000000001','a1111111-aaaa-aaaa-aaaa-000000000001', NULL, 'ota',       0.0,
   NULL, 200, 'OTA bookings excluded from earning');

INSERT INTO rewards (program_id, chain_group_id, code, name, description, reward_type, cost_points, min_tier_id, hotel_id, valid_from, valid_to, is_active) VALUES
  ('c3300001-aaaa-aaaa-aaaa-000000000001','a1111111-aaaa-aaaa-aaaa-000000000001','gm-free-night',        'Free Grand Member night',                'One free standard night at any Grand avdeling','free_night',     12000, NULL, NULL, '2024-01-01','2027-12-31', true),
  ('c3300001-aaaa-aaaa-aaaa-000000000001','a1111111-aaaa-aaaa-aaaa-000000000001','gm-late-checkout',     'Guaranteed late checkout 16:00',         NULL,                                              'late_checkout',     800, 'd4400001-aaaa-aaaa-aaaa-000000000002', NULL, NULL, NULL, true),
  ('c3300001-aaaa-aaaa-aaaa-000000000001','a1111111-aaaa-aaaa-aaaa-000000000001','gm-room-upgrade',      'Room upgrade voucher',                   NULL,                                              'room_upgrade',     3500, 'd4400001-aaaa-aaaa-aaaa-000000000003', NULL, NULL, NULL, true),
  ('c3300001-aaaa-aaaa-aaaa-000000000001','a1111111-aaaa-aaaa-aaaa-000000000001','gm-restaurant-500',    'NOK 500 restaurant credit',              NULL,                                              'gift_card',        5000, NULL, NULL, NULL, NULL, true),
  ('c3300001-aaaa-aaaa-aaaa-000000000001','a1111111-aaaa-aaaa-aaaa-000000000001','gm-spa-experience',    'Spa experience for two',                 'Two-hour spa treatment for two guests',          'experience',        9000, 'd4400001-aaaa-aaaa-aaaa-000000000003', NULL, NULL, NULL, true),
  ('c3300001-aaaa-aaaa-aaaa-000000000001','a1111111-aaaa-aaaa-aaaa-000000000001','gm-suite-upgrade',     'Suite upgrade for one stay',             NULL,                                              'room_upgrade',    15000, 'd4400001-aaaa-aaaa-aaaa-000000000004', NULL, NULL, NULL, true),
  ('c3300001-aaaa-aaaa-aaaa-000000000001','a1111111-aaaa-aaaa-aaaa-000000000001','gm-airport-lounge',    'Airport lounge pass',                    NULL,                                              'experience',        2500, NULL, NULL, NULL, NULL, true),
  ('c3300001-aaaa-aaaa-aaaa-000000000001','a1111111-aaaa-aaaa-aaaa-000000000001','gm-anniversary-pkg',   'Anniversary package (champagne + dinner)', NULL,                                            'experience',        7500, 'd4400001-aaaa-aaaa-aaaa-000000000003', NULL, NULL, NULL, true);

-- ===== 1.6 Fifteen avdelinger (Grand <city>) =====
INSERT INTO hotels (id, chain_group_id, slug, name, brand_property_code, status, address_line1, postal_code, city, country_code, timezone, latitude, longitude, room_count, opening_date, default_currency, default_pms, contact_email) VALUES
  ('b2200001-aaaa-aaaa-aaaa-000000000001'::uuid, 'a1111111-aaaa-aaaa-aaaa-000000000001', 'grand-oslo',       'Grand Oslo',       'GO', 'active', 'Karl Johans gate 31', '0159',  'Oslo',       'NO','Europe/Oslo',       59.9139,10.7522, 220, '1995-04-12','NOK','stayntouch','oslo@grandmember.example'),
  ('b2200001-aaaa-aaaa-aaaa-000000000002'::uuid, 'a1111111-aaaa-aaaa-aaaa-000000000001', 'grand-bergen',     'Grand Bergen',     'GB', 'active', 'Bryggen 14',          '5003',  'Bergen',     'NO','Europe/Oslo',       60.3970,5.3220,  140, '1998-06-01','NOK','stayntouch','bergen@grandmember.example'),
  ('b2200001-aaaa-aaaa-aaaa-000000000003'::uuid, 'a1111111-aaaa-aaaa-aaaa-000000000001', 'grand-trondheim',  'Grand Trondheim',  'GT', 'active', 'Munkegata 26',        '7011',  'Trondheim',  'NO','Europe/Oslo',       63.4305,10.3951, 110, '2001-03-15','NOK','mews',      'trondheim@grandmember.example'),
  ('b2200001-aaaa-aaaa-aaaa-000000000004'::uuid, 'a1111111-aaaa-aaaa-aaaa-000000000001', 'grand-stavanger',  'Grand Stavanger',  'GS', 'active', 'Skagenkaien 28',      '4006',  'Stavanger',  'NO','Europe/Oslo',       58.9700,5.7331,  185, '2004-05-15','NOK','protel_air','stavanger@grandmember.example'),
  ('b2200001-aaaa-aaaa-aaaa-000000000005'::uuid, 'a1111111-aaaa-aaaa-aaaa-000000000001', 'grand-tromso',     'Grand Tromsø',     'GTR','active', 'Sjøgata 19',          '9008',  'Tromsø',     'NO','Europe/Oslo',       69.6492,18.9553, 140, '2009-11-22','NOK','mews',      'tromso@grandmember.example'),
  ('b2200001-aaaa-aaaa-aaaa-000000000006'::uuid, 'a1111111-aaaa-aaaa-aaaa-000000000001', 'grand-stockholm',  'Grand Stockholm',  'GST','active', 'Vasagatan 45',        '111 20','Stockholm',  'SE','Europe/Stockholm',  59.3293,18.0686, 180, '2003-09-10','SEK','stayntouch','stockholm@grandmember.example'),
  ('b2200001-aaaa-aaaa-aaaa-000000000007'::uuid, 'a1111111-aaaa-aaaa-aaaa-000000000001', 'grand-goteborg',   'Grand Göteborg',   'GG', 'active', 'Kungsportsavenyn 21', '411 36','Göteborg',   'SE','Europe/Stockholm',  57.7089,11.9746, 130, '2007-05-22','SEK','stayntouch','goteborg@grandmember.example'),
  ('b2200001-aaaa-aaaa-aaaa-000000000008'::uuid, 'a1111111-aaaa-aaaa-aaaa-000000000001', 'grand-malmo',      'Grand Malmö',      'GM', 'active', 'Stortorget 7',        '211 22','Malmö',      'SE','Europe/Stockholm',  55.6050,13.0038, 95,  '2009-08-12','SEK','mews',      'malmo@grandmember.example'),
  ('b2200001-aaaa-aaaa-aaaa-000000000009'::uuid, 'a1111111-aaaa-aaaa-aaaa-000000000001', 'grand-uppsala',    'Grand Uppsala',    'GU', 'active', 'Bangårdsgatan 12',    '753 20','Uppsala',    'SE','Europe/Stockholm',  59.8586,17.6389, 110, '2013-02-14','SEK','protel_air','uppsala@grandmember.example'),
  ('b2200001-aaaa-aaaa-aaaa-000000000010'::uuid, 'a1111111-aaaa-aaaa-aaaa-000000000001', 'grand-kobenhavn',  'Grand København',  'GK', 'active', 'Vesterbrogade 4',     '1620',  'København',  'DK','Europe/Copenhagen', 55.6761,12.5683, 200, '2011-04-04','DKK','stayntouch','kobenhavn@grandmember.example'),
  ('b2200001-aaaa-aaaa-aaaa-000000000011'::uuid, 'a1111111-aaaa-aaaa-aaaa-000000000001', 'grand-aarhus',     'Grand Aarhus',     'GA', 'active', 'Havnegade 10',        '8000',  'Aarhus',     'DK','Europe/Copenhagen', 56.1572,10.2107, 105, '2014-10-01','DKK','stayntouch','aarhus@grandmember.example'),
  ('b2200001-aaaa-aaaa-aaaa-000000000012'::uuid, 'a1111111-aaaa-aaaa-aaaa-000000000001', 'grand-odense',     'Grand Odense',     'GOD','active', 'Vestergade 9',        '5000',  'Odense',     'DK','Europe/Copenhagen', 55.4038,10.4024, 75,  '2017-09-20','DKK','visbook',   'odense@grandmember.example'),
  ('b2200001-aaaa-aaaa-aaaa-000000000013'::uuid, 'a1111111-aaaa-aaaa-aaaa-000000000001', 'grand-helsinki',   'Grand Helsinki',   'GH', 'active', 'Mannerheimintie 2',   '00100', 'Helsinki',   'FI','Europe/Helsinki',   60.1699,24.9384, 150, '2018-02-18','EUR','mews',      'helsinki@grandmember.example'),
  ('b2200001-aaaa-aaaa-aaaa-000000000014'::uuid, 'a1111111-aaaa-aaaa-aaaa-000000000001', 'grand-reykjavik',  'Grand Reykjavík',  'GR', 'active', 'Tryggvagata 10',      '101',   'Reykjavík',  'IS','Atlantic/Reykjavik',64.1466,-21.9426,90,  '2014-06-21','ISK','protel_air','reykjavik@grandmember.example'),
  ('b2200001-aaaa-aaaa-aaaa-000000000015'::uuid, 'a1111111-aaaa-aaaa-aaaa-000000000001', 'grand-akureyri',   'Grand Akureyri',   'GAK','active', 'Strandgata 53',       '600',   'Akureyri',   'IS','Atlantic/Reykjavik',65.6835,-18.0878,55,  '2017-05-18','ISK','mews',      'akureyri@grandmember.example');

INSERT INTO hotel_pms_connections (hotel_id, pms_code, external_property_id, external_program_id, is_active, last_synced_at, connection_metadata)
SELECT h.id, h.default_pms,
  (2400 + row_number() OVER (ORDER BY h.brand_property_code))::text,
  '364',
  true,
  now() - (random() * interval '24 hours'),
  jsonb_build_object('environment','seed','property_name', h.name)
FROM hotels h WHERE h.default_pms IS NOT NULL;

-- ===== 1.7 Currency rates (monthly NOK<->{SEK,DKK,EUR,USD,GBP,ISK,CHF} 2023-01 .. 2027-12) =====
WITH months AS (
  SELECT generate_series('2023-01-01'::date, '2027-12-01'::date, interval '1 month')::date AS d
), pairs AS (
  SELECT * FROM (VALUES
    ('NOK','SEK', 0.97, 0.06),('NOK','DKK', 0.65, 0.04),('NOK','EUR', 0.087, 0.005),('NOK','USD', 0.094, 0.008),('NOK','GBP', 0.075, 0.005),('NOK','ISK', 12.6, 0.8),('NOK','CHF', 0.083, 0.005),
    ('SEK','NOK', 1.04, 0.06),('DKK','NOK', 1.54, 0.08),('EUR','NOK', 11.5, 0.4),('USD','NOK', 10.7, 0.5),('GBP','NOK', 13.4, 0.4),('ISK','NOK', 0.079, 0.005),
    ('SEK','EUR', 0.087, 0.004),('DKK','EUR', 0.134, 0.001),('EUR','SEK', 11.5, 0.4),('EUR','DKK', 7.46, 0.05),('SEK','DKK', 0.66, 0.03),('DKK','SEK', 1.51, 0.07)
  ) AS t(from_ccy, to_ccy, base, jitter)
)
INSERT INTO currency_rates (from_ccy, to_ccy, rate_date, rate, source)
SELECT p.from_ccy::char(3), p.to_ccy::char(3), m.d,
  ROUND((p.base + (random() - 0.5) * 2 * p.jitter)::numeric, 6), 'seed'
FROM pairs p CROSS JOIN months m
ON CONFLICT (from_ccy, to_ccy, rate_date) DO NOTHING;

-- ===== 1.8 Members (2 000 all in Grand Member) =====
SELECT setseed(0.42);

WITH name_pool AS (
  SELECT row_number() OVER () AS idx, first_name, last_name, country_code, gender FROM (VALUES
    ('Erik','Hansen','NO','male'),('Jan','Olsen','NO','male'),('Lars','Johansen','NO','male'),('Per','Larsen','NO','male'),('Magnus','Andersen','NO','male'),('Anders','Nilsen','NO','male'),('Henrik','Pedersen','NO','male'),('Mikael','Kristiansen','NO','male'),('Karl','Berg','NO','male'),('Johan','Lien','NO','male'),
    ('Anna','Solberg','NO','female'),('Linnea','Bakken','NO','female'),('Maria','Strand','NO','female'),('Kristin','Lund','NO','female'),('Sofia','Karlsen','NO','female'),('Emma','Hansen','NO','female'),('Astrid','Berg','NO','female'),('Sara','Andersen','NO','female'),('Ida','Nilsen','NO','female'),('Ingrid','Olsen','NO','female'),
    ('Rasmus','Andersson','SE','male'),('Niklas','Johansson','SE','male'),('Daniel','Karlsson','SE','male'),('Tobias','Nilsson','SE','male'),('Oscar','Eriksson','SE','male'),('Viktor','Larsson','SE','male'),('Linus','Olsson','SE','male'),('Markus','Persson','SE','male'),('Adam','Svensson','SE','male'),('Filip','Gustafsson','SE','male'),
    ('Hanna','Andersson','SE','female'),('Julia','Johansson','SE','female'),('Elin','Karlsson','SE','female'),('Cecilia','Eriksson','SE','female'),('Lotta','Larsson','SE','female'),('Mia','Persson','SE','female'),('Eva','Olsson','SE','female'),('Petra','Nilsson','SE','female'),('Therese','Svensson','SE','female'),('Karin','Gustafsson','SE','female'),
    ('Søren','Jensen','DK','male'),('Kasper','Nielsen','DK','male'),('Jakob','Hansen','DK','male'),('Mikkel','Pedersen','DK','male'),('Anders','Christensen','DK','male'),
    ('Mette','Larsen','DK','female'),('Pernille','Sørensen','DK','female'),('Camilla','Andersen','DK','female'),('Heidi','Christensen','DK','female'),('Anne','Jensen','DK','female'),
    ('Jussi','Korhonen','FI','male'),('Antti','Virtanen','FI','male'),('Mikko','Mäkinen','FI','male'),('Kari','Nieminen','FI','male'),('Pekka','Hämäläinen','FI','male'),
    ('Elina','Heikkinen','FI','female'),('Heli','Laine','FI','female'),('Liisa','Koskinen','FI','female'),('Sanna','Järvinen','FI','female'),('Tiina','Saari','FI','female'),
    ('Björn','Jónsson','IS','male'),('Guðmundur','Sigurðsson','IS','male'),('Jón','Guðmundsson','IS','male'),('Sigurður','Ásgeirsson','IS','male'),
    ('Helga','Magnúsdóttir','IS','female'),('Lilja','Þórðardóttir','IS','female'),('Birna','Björnsdóttir','IS','female'),('Sólveig','Jónsdóttir','IS','female')
  ) AS t(first_name, last_name, country_code, gender)
),
pool_size AS (SELECT count(*)::int AS sz FROM name_pool),
chain_const AS (
  SELECT 'a1111111-aaaa-aaaa-aaaa-000000000001'::uuid AS chain_id,
         'c3300001-aaaa-aaaa-aaaa-000000000001'::uuid AS program_id,
         ARRAY[
           'd4400001-aaaa-aaaa-aaaa-000000000001',
           'd4400001-aaaa-aaaa-aaaa-000000000002',
           'd4400001-aaaa-aaaa-aaaa-000000000003',
           'd4400001-aaaa-aaaa-aaaa-000000000004',
           'd4400001-aaaa-aaaa-aaaa-000000000005'
         ]::uuid[] AS tier_ids,
         ARRAY[55,25,12,5,3]::int[] AS tier_weights
),
generated AS (
  SELECT n,
    cc.chain_id, cc.program_id, cc.tier_ids, cc.tier_weights,
    ((n * 7 + 31) % (SELECT sz FROM pool_size)) + 1 AS pool_idx,
    random() AS r1, random() AS r2, random() AS r3, random() AS r4, random() AS r5, random() AS r6
  FROM generate_series(1, 2000) AS gs(n) CROSS JOIN chain_const cc
),
joined AS (
  SELECT g.*, np.first_name, np.last_name, np.country_code, np.gender AS gender_str
  FROM generated g JOIN name_pool np ON np.idx = g.pool_idx
),
extracted AS (
  SELECT j.*,
    (SELECT j.tier_ids[i] FROM generate_subscripts(j.tier_weights, 1) AS i
       WHERE (SELECT sum(j.tier_weights[k]) FROM generate_subscripts(j.tier_weights, 1) AS k WHERE k <= i) >= (j.r1 * 100)
       ORDER BY i ASC LIMIT 1) AS picked_tier_id
  FROM joined j
)
INSERT INTO members (
  chain_group_id, program_id, member_number, first_name, last_name, email, email_raw, phone_e164, phone_raw, birth_date, gender,
  preferred_language, country_code, city, postal_code, joined_at, status, current_tier_id,
  recruitment_source, recruitment_hotel_id, recruited_via_ota, recruitment_ota_source, program_tag, region, external_membership_raw
)
SELECT
  e.chain_id, e.program_id, format('GM-%s', lpad(e.n::text, 7, '0')),
  e.first_name, e.last_name,
  lower(extensions.unaccent(e.first_name) || '.' || regexp_replace(extensions.unaccent(e.last_name), ' ','-','g') || e.n || '@example.' ||
    CASE e.country_code WHEN 'NO' THEN 'no' WHEN 'SE' THEN 'se' WHEN 'DK' THEN 'dk' WHEN 'FI' THEN 'fi' WHEN 'IS' THEN 'is' ELSE 'com' END),
  e.first_name || ' ' || e.last_name,
  CASE e.country_code
    WHEN 'NO' THEN '+47'  || (40000000 + ((e.n*97) % 60000000))::text
    WHEN 'SE' THEN '+46'  || (700000000 + ((e.n*73) % 100000000))::text
    WHEN 'DK' THEN '+45'  || (20000000 + ((e.n*113) % 70000000))::text
    WHEN 'FI' THEN '+358' || (400000000 + ((e.n*89) % 90000000))::text
    WHEN 'IS' THEN '+354' || (5000000 + ((e.n*53) % 4000000))::text
  END,
  NULL,
  CASE WHEN e.r2 < 0.05 THEN '1800-01-01'::date ELSE date '1955-01-01' + ((e.r3 * 18250)::int) END,
  e.gender_str::member_gender,
  CASE e.country_code WHEN 'NO' THEN 'nb' WHEN 'SE' THEN 'sv' WHEN 'DK' THEN 'da' WHEN 'FI' THEN 'fi' WHEN 'IS' THEN 'is' ELSE 'en' END,
  e.country_code::char(2),
  CASE e.country_code
    WHEN 'NO' THEN (ARRAY['Oslo','Bergen','Trondheim','Stavanger','Tromsø','Kristiansand','Lillehammer','Bodø','Ålesund','Drammen'])[1 + (e.n % 10)]
    WHEN 'SE' THEN (ARRAY['Stockholm','Göteborg','Malmö','Uppsala','Örebro','Linköping','Lund','Helsingborg','Norrköping','Västerås'])[1 + (e.n % 10)]
    WHEN 'DK' THEN (ARRAY['København','Aarhus','Odense','Aalborg','Frederiksberg','Esbjerg','Randers','Kolding','Vejle','Skagen'])[1 + (e.n % 10)]
    WHEN 'FI' THEN (ARRAY['Helsinki','Espoo','Tampere','Vantaa','Oulu','Turku','Jyväskylä','Lahti','Kuopio','Pori'])[1 + (e.n % 10)]
    WHEN 'IS' THEN (ARRAY['Reykjavík','Akureyri','Vík','Selfoss','Hafnarfjörður','Kópavogur','Akranes','Egilsstaðir','Höfn','Ísafjörður'])[1 + (e.n % 10)]
  END,
  ((1000 + e.n % 9000)::text),
  '2023-01-01'::timestamptz + ((power(e.r4, 0.7) * 850)::int) * interval '1 day' + (e.r5 * interval '1 day'),
  CASE WHEN e.r6 < 0.85 THEN 'active' WHEN e.r6 < 0.95 THEN 'inactive' WHEN e.r6 < 0.98 THEN 'suspended' ELSE 'archived' END::member_status,
  e.picked_tier_id,
  (ARRAY['StayNTouchIntegration','MewsIntegration','ProtelAirPMSintegration','VisbookIntegration','widget_signup','AuthOtp','admin_manual','referral'])[1 + (e.n % 8)],
  NULL,
  e.r2 < 0.30,
  CASE WHEN e.r2 < 0.30 THEN (ARRAY['Booking.com','Expedia','Hotels.com','Agoda','Trip.com'])[1 + ((e.n*11) % 5)] ELSE NULL END,
  '364Member',
  e.country_code,
  CASE WHEN e.r3 < 0.35 THEN
    jsonb_build_array(jsonb_build_object(
      'Type', (ARRAY['FMOldId','SJprioId','GuestConnectId','PMSGuestId'])[1 + ((e.n*7) % 4)],
      'Value', 'LEG' || lpad(((e.n * 19) % 9999999)::text, 7, '0'),
      'ValidFromUtc', (date '2018-01-01' + ((e.r4 * 2000)::int) * interval '1 day')::text,
      'IsValid', 1
    ))
  ELSE NULL END
FROM extracted e;

-- ===== 1.9 Member ancillary (recruitment hotel, external_ids, consents, tier history, attributes) =====
SELECT setseed(0.43);

UPDATE members m
SET recruitment_hotel_id = (SELECT id FROM hotels h WHERE h.chain_group_id = m.chain_group_id ORDER BY md5(m.id::text || h.id::text) LIMIT 1);

INSERT INTO member_external_ids (member_id, id_type, id_value, is_valid, valid_from, metadata)
SELECT m.id,
  CASE jsonb_extract_path_text(elem, 'Type')
    WHEN 'FMOldId'        THEN 'fm_old_id'
    WHEN 'SJprioId'       THEN 'sj_prio_id'
    WHEN 'GuestConnectId' THEN 'guest_connect_id'
    WHEN 'PMSGuestId'     THEN 'pms_guest_id'
    ELSE 'legacy_other'
  END::external_id_type,
  jsonb_extract_path_text(elem, 'Value'),
  (jsonb_extract_path_text(elem, 'IsValid')::int) = 1,
  (jsonb_extract_path_text(elem, 'ValidFromUtc'))::timestamptz,
  jsonb_build_object('source','seed_legacy_migration')
FROM members m, jsonb_array_elements(coalesce(m.external_membership_raw, '[]'::jsonb)) AS elem
ON CONFLICT (id_type, id_value) DO NOTHING;

INSERT INTO member_external_ids (member_id, id_type, id_value, is_valid, valid_from, metadata)
SELECT m.id, 'sj_prio_id'::external_id_type,
  '975' || lpad(((extract(epoch from m.created_at)::bigint) % 9999999999)::text, 13, '0'),
  true, m.joined_at, '{"source":"seed_secondary"}'::jsonb
FROM members m WHERE m.external_membership_raw IS NOT NULL AND random() < 0.7
ON CONFLICT (id_type, id_value) DO NOTHING;

INSERT INTO member_consents (member_id, consent_type, granted, granted_at, source)
SELECT m.id, ct.consent_type::consent_type,
  CASE ct.consent_type
    WHEN 'user_agreement' THEN true
    WHEN 'email'          THEN random() < 0.85
    WHEN 'sms'            THEN random() < 0.75
    WHEN 'offer'          THEN random() < 0.65
  END,
  m.joined_at,
  CASE WHEN m.recruited_via_ota THEN 'pms_import' ELSE 'signup_widget' END
FROM members m
CROSS JOIN (VALUES ('email'),('sms'),('offer'),('user_agreement')) AS ct(consent_type);

INSERT INTO member_tier_history (member_id, from_tier_id, to_tier_id, change_reason, effective_at, context)
SELECT m.id, NULL, m.current_tier_id, 'initial_assignment'::tier_change_reason, m.joined_at,
  jsonb_build_object('reason','member_signup','recruitment_source', m.recruitment_source)
FROM members m WHERE m.current_tier_id IS NOT NULL;

WITH promotable AS (
  SELECT m.id, m.joined_at, m.current_tier_id AS new_tier_id, t.program_id,
    (SELECT t2.id FROM tiers t2 WHERE t2.program_id = t.program_id AND t2.sort_order = t.sort_order - 1) AS prev_tier_id
  FROM members m JOIN tiers t ON t.id = m.current_tier_id
  WHERE t.sort_order > 1 AND random() < 0.40
)
INSERT INTO member_tier_history (member_id, from_tier_id, to_tier_id, change_reason, effective_at, context)
SELECT p.id, p.prev_tier_id, p.new_tier_id,
  (ARRAY['qualified_by_points','qualified_by_nights','qualified_by_revenue']::tier_change_reason[])[1 + floor(random()*3)::int],
  p.joined_at + (60 + (random() * 540)::int) * interval '1 day',
  jsonb_build_object('counted_points', (4000 + random()*60000)::int, 'window_months', 12)
FROM promotable p WHERE p.prev_tier_id IS NOT NULL;

INSERT INTO member_attributes (member_id, attr_key, attr_value, source, set_at)
SELECT m.id, 'vip', 'true'::jsonb, 'segment_evaluation', now()
FROM members m JOIN tiers t ON t.id = m.current_tier_id
WHERE t.sort_order >= 4 AND random() < 0.6
ON CONFLICT (member_id, attr_key) DO NOTHING;

INSERT INTO member_attributes (member_id, attr_key, attr_value, source, set_at)
SELECT m.id, 'high_value_flag', '"watchlist"'::jsonb, 'segment_evaluation', now()
FROM members m JOIN tiers t ON t.id = m.current_tier_id
WHERE t.sort_order >= 4 AND random() < 0.5
ON CONFLICT (member_id, attr_key) DO NOTHING;

-- Sanity check at end of part 1
SELECT
  (SELECT count(*) FROM chain_groups) AS chains,
  (SELECT count(*) FROM hotels) AS hotels,
  (SELECT count(*) FROM loyalty_programs) AS programs,
  (SELECT count(*) FROM tiers) AS tiers,
  (SELECT count(*) FROM points_rules) AS rules,
  (SELECT count(*) FROM rewards) AS rewards,
  (SELECT count(*) FROM currency_rates) AS fx_rates,
  (SELECT count(*) FROM members) AS members,
  (SELECT count(*) FROM member_consents) AS consents,
  (SELECT count(*) FROM member_tier_history) AS tier_history,
  (SELECT count(*) FROM member_external_ids) AS external_ids,
  (SELECT count(*) FROM member_attributes) AS attributes;

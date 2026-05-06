-- 01_tenancy.sql
-- Five chain groups, 25 hotels distributed unevenly, hotel_pms_connections, monthly FX rates.
-- Deterministic via fixed UUIDs for the chain/hotel records so other seed files can reference them.

SELECT setseed(0.42);

-- ===== Chain groups =====
INSERT INTO chain_groups (id, slug, name, legal_name, default_currency, reporting_currency, default_locale, headquarters_country, brand_color_hex, support_email, support_phone, founded_at, status) VALUES
  ('a1111111-0000-0000-0000-000000000001'::uuid, 'first-member-norden',  'First Member Norden',  'First Hotels Norden AS',     'NOK','NOK','nb-NO','NO','#A8201A','support@firstmember.example','+4790000001','1995-04-12','active'),
  ('a1111111-0000-0000-0000-000000000002'::uuid, 'quality-living',        'Quality Living',       'Quality Living Hospitality AS','NOK','NOK','nb-NO','NO','#1F4E79','support@qualityliving.example','+4790000002','2002-09-03','active'),
  ('a1111111-0000-0000-0000-000000000003'::uuid, 'fjord-boutique',        'Fjord Boutique',       'Fjord Boutique ehf.',         'NOK','EUR','en-IS','IS','#0B6E4F','hello@fjordboutique.example','+3545550001','2014-06-21','active'),
  ('a1111111-0000-0000-0000-000000000004'::uuid, 'smart-stays-business',  'Smart Stays Business', 'Smart Stays AB',              'SEK','SEK','sv-SE','SE','#212A3E','info@smartstays.example','+4670000001','2010-11-30','active'),
  ('a1111111-0000-0000-0000-000000000005'::uuid, 'coastal-hideaways',     'Coastal Hideaways',    'Coastal Hideaways ApS',       'DKK','DKK','da-DK','DK','#7C3F00','reception@coastalhideaways.example','+4540000001','2018-03-15','active');

-- ===== Hotels (25 total: 9 + 7 + 5 + 3 + 1) =====
-- chain 1 (First Member Norden): 9 hotels across NO, SE, DK, FI
INSERT INTO hotels (id, chain_group_id, slug, name, brand_property_code, status, address_line1, postal_code, city, country_code, timezone, latitude, longitude, room_count, opening_date, default_currency, default_pms, contact_email) VALUES
  ('b2200001-0000-0000-0000-000000000001'::uuid, 'a1111111-0000-0000-0000-000000000001', 'first-grand-oslo',     'First Grand Oslo',         'FGO', 'active', 'Karl Johans gate 31', '0159',  'Oslo',       'NO','Europe/Oslo',     59.9139,10.7522, 220, '1995-04-12','NOK','stayntouch','grand.oslo@firstmember.example'),
  ('b2200001-0000-0000-0000-000000000002'::uuid, 'a1111111-0000-0000-0000-000000000001', 'first-bergen-bryggen', 'First Bergen Bryggen',     'FBB', 'active', 'Bryggen 14',          '5003',  'Bergen',     'NO','Europe/Oslo',     60.3970,5.3220,  140, '1998-06-01','NOK','stayntouch','bergen@firstmember.example'),
  ('b2200001-0000-0000-0000-000000000003'::uuid, 'a1111111-0000-0000-0000-000000000001', 'first-trondheim',      'First Trondheim',          'FTR', 'active', 'Munkegata 26',        '7011',  'Trondheim',  'NO','Europe/Oslo',     63.4305,10.3951, 110, '2001-03-15','NOK','mews',      'trondheim@firstmember.example'),
  ('b2200001-0000-0000-0000-000000000004'::uuid, 'a1111111-0000-0000-0000-000000000001', 'first-stockholm-vasa', 'First Stockholm Vasa',     'FSV', 'active', 'Vasagatan 45',        '111 20','Stockholm',  'SE','Europe/Stockholm', 59.3293,18.0686, 180, '2003-09-10','SEK','stayntouch','stockholm@firstmember.example'),
  ('b2200001-0000-0000-0000-000000000005'::uuid, 'a1111111-0000-0000-0000-000000000001', 'first-gothenburg',     'First Gothenburg Avenue',  'FGA', 'active', 'Kungsportsavenyn 21', '411 36','Göteborg',   'SE','Europe/Stockholm', 57.7089,11.9746, 130, '2007-05-22','SEK','stayntouch','gothenburg@firstmember.example'),
  ('b2200001-0000-0000-0000-000000000006'::uuid, 'a1111111-0000-0000-0000-000000000001', 'first-malmo-central',  'First Malmö Central',      'FMC', 'active', 'Stortorget 7',        '211 22','Malmö',      'SE','Europe/Stockholm', 55.6050,13.0038, 95,  '2009-08-12','SEK','mews',      'malmo@firstmember.example'),
  ('b2200001-0000-0000-0000-000000000007'::uuid, 'a1111111-0000-0000-0000-000000000001', 'first-copenhagen-tivoli','First Copenhagen Tivoli','FCT', 'active', 'Vesterbrogade 4',     '1620',  'København',  'DK','Europe/Copenhagen',55.6761,12.5683, 200, '2011-04-04','DKK','stayntouch','copenhagen@firstmember.example'),
  ('b2200001-0000-0000-0000-000000000008'::uuid, 'a1111111-0000-0000-0000-000000000001', 'first-aarhus-port',    'First Aarhus Port',        'FAP', 'active', 'Havnegade 10',        '8000',  'Aarhus',     'DK','Europe/Copenhagen',56.1572,10.2107, 105, '2014-10-01','DKK','mews',      'aarhus@firstmember.example'),
  ('b2200001-0000-0000-0000-000000000009'::uuid, 'a1111111-0000-0000-0000-000000000001', 'first-helsinki-design','First Helsinki Design',    'FHD', 'active', 'Mannerheimintie 2',   '00100', 'Helsinki',   'FI','Europe/Helsinki',  60.1699,24.9384, 150, '2018-02-18','EUR','mews',      'helsinki@firstmember.example');

-- chain 2 (Quality Living): 7 hotels in Norway, all Protel Air
INSERT INTO hotels (id, chain_group_id, slug, name, brand_property_code, status, address_line1, postal_code, city, country_code, timezone, latitude, longitude, room_count, opening_date, default_currency, default_pms, contact_email) VALUES
  ('b2200002-0000-0000-0000-000000000001'::uuid, 'a1111111-0000-0000-0000-000000000002', 'quality-oslo-airport',     'Quality Oslo Airport',     'QOA', 'active', 'Edvard Munchs veg 23', '2061', 'Gardermoen', 'NO','Europe/Oslo', 60.1939,11.1004, 320, '2002-09-03','NOK','protel_air','airport@qualityliving.example'),
  ('b2200002-0000-0000-0000-000000000002'::uuid, 'a1111111-0000-0000-0000-000000000002', 'quality-stavanger',        'Quality Stavanger Harbour','QSH', 'active', 'Skagenkaien 28',       '4006', 'Stavanger',  'NO','Europe/Oslo', 58.9700,5.7331,  185, '2004-05-15','NOK','protel_air','stavanger@qualityliving.example'),
  ('b2200002-0000-0000-0000-000000000003'::uuid, 'a1111111-0000-0000-0000-000000000002', 'quality-tromso',           'Quality Tromsø Aurora',    'QTA', 'active', 'Sjøgata 19',           '9008', 'Tromsø',     'NO','Europe/Oslo', 69.6492,18.9553, 140, '2009-11-22','NOK','protel_air','tromso@qualityliving.example'),
  ('b2200002-0000-0000-0000-000000000004'::uuid, 'a1111111-0000-0000-0000-000000000002', 'quality-kristiansand',     'Quality Kristiansand Bay', 'QKB', 'active', 'Strandgaten 15',       '4612', 'Kristiansand','NO','Europe/Oslo',58.1467,7.9956,  120, '2011-08-08','NOK','protel_air','kristiansand@qualityliving.example'),
  ('b2200002-0000-0000-0000-000000000005'::uuid, 'a1111111-0000-0000-0000-000000000002', 'quality-lillehammer',      'Quality Lillehammer Olympic','QLO','active','Storgata 84',         '2609', 'Lillehammer','NO','Europe/Oslo', 61.1153,10.4663, 95,  '2014-12-10','NOK','protel_air','lillehammer@qualityliving.example'),
  ('b2200002-0000-0000-0000-000000000006'::uuid, 'a1111111-0000-0000-0000-000000000002', 'quality-bodo',             'Quality Bodø Coast',       'QBC', 'active', 'Sjøgata 12',           '8006', 'Bodø',       'NO','Europe/Oslo', 67.2804,14.4049, 80,  '2017-04-19','NOK','protel_air','bodo@qualityliving.example'),
  ('b2200002-0000-0000-0000-000000000007'::uuid, 'a1111111-0000-0000-0000-000000000002', 'quality-alesund-old-town', 'Quality Ålesund Old Town', 'QAO', 'active', 'Apotekergata 1',       '6004', 'Ålesund',    'NO','Europe/Oslo', 62.4722,6.1495,  100, '2020-06-30','NOK','protel_air','alesund@qualityliving.example');

-- chain 3 (Fjord Boutique): 5 hotels in Iceland and Norway
INSERT INTO hotels (id, chain_group_id, slug, name, brand_property_code, status, address_line1, postal_code, city, country_code, timezone, latitude, longitude, room_count, opening_date, default_currency, default_pms, contact_email) VALUES
  ('b2200003-0000-0000-0000-000000000001'::uuid, 'a1111111-0000-0000-0000-000000000003', 'fjord-reykjavik-harbour', 'Fjord Reykjavík Harbour', 'FRH', 'active', 'Tryggvagata 10',  '101', 'Reykjavík',  'IS','Atlantic/Reykjavik', 64.1466,-21.9426, 70, '2014-06-21','ISK','mews','reykjavik@fjordboutique.example'),
  ('b2200003-0000-0000-0000-000000000002'::uuid, 'a1111111-0000-0000-0000-000000000003', 'fjord-akureyri-aurora',   'Fjord Akureyri Aurora',   'FAA', 'active', 'Strandgata 53',   '600', 'Akureyri',   'IS','Atlantic/Reykjavik', 65.6835,-18.0878, 45, '2017-05-18','ISK','mews','akureyri@fjordboutique.example'),
  ('b2200003-0000-0000-0000-000000000003'::uuid, 'a1111111-0000-0000-0000-000000000003', 'fjord-tromso-arctic',     'Fjord Tromsø Arctic',     'FTA', 'active', 'Storgata 80',     '9008','Tromsø',     'NO','Europe/Oslo',       69.6492,18.9553,  55, '2019-09-01','NOK','mews','tromso@fjordboutique.example'),
  ('b2200003-0000-0000-0000-000000000004'::uuid, 'a1111111-0000-0000-0000-000000000003', 'fjord-flam-rail',         'Fjord Flåm Rail',         'FFR', 'active', 'Stasjonsvegen 4', '5742','Flåm',       'NO','Europe/Oslo',       60.8625,7.1149,   38, '2021-04-02','NOK','mews','flam@fjordboutique.example'),
  ('b2200003-0000-0000-0000-000000000005'::uuid, 'a1111111-0000-0000-0000-000000000003', 'fjord-vik-glacier',       'Fjord Vík Glacier',       'FVG', 'active', 'Klettsvegur 1',   '870', 'Vík',        'IS','Atlantic/Reykjavik', 63.4187,-19.0064, 30, '2023-01-10','ISK','mews','vik@fjordboutique.example');

-- chain 4 (Smart Stays Business): 3 hotels in Sweden, Visbook
INSERT INTO hotels (id, chain_group_id, slug, name, brand_property_code, status, address_line1, postal_code, city, country_code, timezone, latitude, longitude, room_count, opening_date, default_currency, default_pms, contact_email) VALUES
  ('b2200004-0000-0000-0000-000000000001'::uuid, 'a1111111-0000-0000-0000-000000000004', 'smart-stockholm-arlanda', 'Smart Stockholm Arlanda', 'SSA', 'active', 'Cederströms slinga 4', '195 60','Märsta',    'SE','Europe/Stockholm', 59.6519,17.9186, 250, '2010-11-30','SEK','visbook','arlanda@smartstays.example'),
  ('b2200004-0000-0000-0000-000000000002'::uuid, 'a1111111-0000-0000-0000-000000000004', 'smart-uppsala-business',  'Smart Uppsala Business',  'SUB', 'active', 'Bangårdsgatan 12',     '753 20','Uppsala',   'SE','Europe/Stockholm', 59.8586,17.6389, 140, '2013-02-14','SEK','visbook','uppsala@smartstays.example'),
  ('b2200004-0000-0000-0000-000000000003'::uuid, 'a1111111-0000-0000-0000-000000000004', 'smart-orebro-conference', 'Smart Örebro Conference', 'SOC', 'active', 'Drottninggatan 27',    '702 12','Örebro',    'SE','Europe/Stockholm', 59.2741,15.2066, 95,  '2018-04-01','SEK','visbook','orebro@smartstays.example');

-- chain 5 (Coastal Hideaways): 1 single-property luxury
INSERT INTO hotels (id, chain_group_id, slug, name, brand_property_code, status, address_line1, postal_code, city, country_code, timezone, latitude, longitude, room_count, opening_date, default_currency, default_pms, contact_email) VALUES
  ('b2200005-0000-0000-0000-000000000001'::uuid, 'a1111111-0000-0000-0000-000000000005', 'coastal-skagen-retreat', 'Coastal Skagen Retreat', 'CSR', 'active', 'Vesterbrogade 1', '9990','Skagen','DK','Europe/Copenhagen', 57.7218,10.5836, 32, '2018-03-15','DKK','stayntouch','retreat@coastalhideaways.example');

-- ===== hotel_pms_connections (one active per hotel, mirroring real PMS property IDs) =====
INSERT INTO hotel_pms_connections (hotel_id, pms_code, external_property_id, external_program_id, is_active, last_synced_at, connection_metadata)
SELECT
  h.id,
  h.default_pms,
  -- mirror PMS-style numeric ids; deterministic via row_number()
  (2400 + row_number() OVER (ORDER BY h.brand_property_code))::text,
  CASE h.chain_group_id::text
    WHEN 'a1111111-0000-0000-0000-000000000001' THEN '364'    -- mirrors First Hotels real program id
    WHEN 'a1111111-0000-0000-0000-000000000002' THEN '268'
    WHEN 'a1111111-0000-0000-0000-000000000003' THEN '510'
    WHEN 'a1111111-0000-0000-0000-000000000004' THEN '633'
    WHEN 'a1111111-0000-0000-0000-000000000005' THEN '742'
  END,
  true,
  now() - (random() * interval '24 hours'),
  jsonb_build_object('environment','seed','property_name', h.name)
FROM hotels h
WHERE h.default_pms IS NOT NULL;

-- ===== Currency rates: monthly NOK<->{SEK,DKK,EUR,USD,GBP,ISK,CHF} from 2023-01 to 2027-12 =====
-- Approximate realistic ranges; lc_to_currency() picks most-recent rate ≤ posting_date.
WITH months AS (
  SELECT generate_series('2023-01-01'::date, '2027-12-01'::date, interval '1 month')::date AS d
), pairs AS (
  SELECT * FROM (VALUES
    ('NOK','SEK', 0.97, 0.06),
    ('NOK','DKK', 0.65, 0.04),
    ('NOK','EUR', 0.087, 0.005),
    ('NOK','USD', 0.094, 0.008),
    ('NOK','GBP', 0.075, 0.005),
    ('NOK','ISK', 12.6, 0.8),
    ('NOK','CHF', 0.083, 0.005),
    ('SEK','NOK', 1.04, 0.06),
    ('DKK','NOK', 1.54, 0.08),
    ('EUR','NOK', 11.5, 0.4),
    ('USD','NOK', 10.7, 0.5),
    ('GBP','NOK', 13.4, 0.4),
    ('ISK','NOK', 0.079, 0.005),
    ('SEK','EUR', 0.087, 0.004),
    ('DKK','EUR', 0.134, 0.001),
    ('EUR','SEK', 11.5, 0.4),
    ('EUR','DKK', 7.46, 0.05),
    ('SEK','DKK', 0.66, 0.03),
    ('DKK','SEK', 1.51, 0.07)
  ) AS t(from_ccy, to_ccy, base, jitter)
)
INSERT INTO currency_rates (from_ccy, to_ccy, rate_date, rate, source)
SELECT
  p.from_ccy::char(3), p.to_ccy::char(3), m.d,
  ROUND((p.base + (random() - 0.5) * 2 * p.jitter)::numeric, 6),
  'seed'
FROM pairs p CROSS JOIN months m
ON CONFLICT (from_ccy, to_ccy, rate_date) DO NOTHING;

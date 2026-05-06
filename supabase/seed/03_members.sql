-- 03_members.sql
-- 2 000 members across 5 chains, weighted 800/500/300/300/100.
-- Realistic Nordic name pool, 5% birth-date placeholder (1800-01-01), 35% with legacy external IDs.
-- Tier distribution per ADR-0004 with chain-specific variations.

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
chain_lookup AS (
  SELECT 1 AS chain_idx, 'a1111111-0000-0000-0000-000000000001'::uuid AS chain_id, 'c3300001-0000-0000-0000-000000000001'::uuid AS program_id,
    ARRAY['d4400001-0000-0000-0000-000000000001','d4400001-0000-0000-0000-000000000002','d4400001-0000-0000-0000-000000000003','d4400001-0000-0000-0000-000000000004','d4400001-0000-0000-0000-000000000005']::uuid[] AS tier_ids,
    ARRAY[55,25,12,5,3]::int[] AS tier_weights
  UNION ALL SELECT 2, 'a1111111-0000-0000-0000-000000000002', 'c3300001-0000-0000-0000-000000000002',
    ARRAY['d4400002-0000-0000-0000-000000000001','d4400002-0000-0000-0000-000000000002','d4400002-0000-0000-0000-000000000003','d4400002-0000-0000-0000-000000000004']::uuid[],
    ARRAY[60,25,11,4]::int[]
  UNION ALL SELECT 3, 'a1111111-0000-0000-0000-000000000003', 'c3300001-0000-0000-0000-000000000003',
    ARRAY['d4400003-0000-0000-0000-000000000001','d4400003-0000-0000-0000-000000000002','d4400003-0000-0000-0000-000000000003','d4400003-0000-0000-0000-000000000004']::uuid[],
    ARRAY[55,25,15,5]::int[]
  UNION ALL SELECT 4, 'a1111111-0000-0000-0000-000000000004', 'c3300001-0000-0000-0000-000000000004',
    ARRAY['d4400004-0000-0000-0000-000000000001','d4400004-0000-0000-0000-000000000002','d4400004-0000-0000-0000-000000000003','d4400004-0000-0000-0000-000000000004']::uuid[],
    ARRAY[60,25,11,4]::int[]
  UNION ALL SELECT 5, 'a1111111-0000-0000-0000-000000000005', 'c3300001-0000-0000-0000-000000000005',
    ARRAY['d4400005-0000-0000-0000-000000000001','d4400005-0000-0000-0000-000000000002']::uuid[],
    ARRAY[80,20]::int[]
),
chain_alloc AS (
  SELECT n,
    CASE WHEN n <= 800 THEN 1 WHEN n <= 1300 THEN 2 WHEN n <= 1600 THEN 3 WHEN n <= 1900 THEN 4 ELSE 5 END AS chain_idx
  FROM generate_series(1, 2000) AS gs(n)
),
generated AS (
  SELECT a.n, a.chain_idx, cl.chain_id, cl.program_id, cl.tier_ids, cl.tier_weights,
    ((a.n * 7 + a.chain_idx * 31) % (SELECT sz FROM pool_size)) + 1 AS pool_idx,
    random() AS r1, random() AS r2, random() AS r3, random() AS r4, random() AS r5, random() AS r6
  FROM chain_alloc a JOIN chain_lookup cl ON cl.chain_idx = a.chain_idx
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
  e.chain_id, e.program_id, format('%s-%s', e.chain_idx, lpad(e.n::text, 7, '0')),
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
  (ARRAY['StayNTouchIntegration','MewsIntegration','ProtelAirPMSintegration','VisbookIntegration','widget_signup','AuthOtp','admin_manual','referral'])[1 + ((e.n * 17 + e.chain_idx) % 8)],
  NULL,
  e.r2 < 0.30,
  CASE WHEN e.r2 < 0.30 THEN (ARRAY['Booking.com','Expedia','Hotels.com','Agoda','Trip.com'])[1 + ((e.n*11) % 5)] ELSE NULL END,
  CASE e.chain_idx WHEN 1 THEN '364Member' WHEN 2 THEN '268Member' WHEN 3 THEN '510Member' WHEN 4 THEN '633Member' WHEN 5 THEN '742Member' END,
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

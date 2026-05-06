-- 09_pms_admin.sql
-- 25 PMS imports (one per active hotel-PMS), 125 raw payloads (5 per import) mirroring real PMS shapes,
-- a few sync_errors for partial/failed imports.
-- 10 admin users (loyco_admin × 2, chain_admin × 5, hotel_staff × 2, analyst × 1) with hardcoded UUIDs
-- so the adminportal can demo logins predictably.

SELECT setseed(0.49);

INSERT INTO pms_imports (chain_group_id, hotel_id, pms_code, source_kind, source_identifier, status, rows_total, rows_succeeded, rows_failed, started_at, finished_at, metadata)
SELECT h.chain_group_id, h.id, h.default_pms,
  (ARRAY['file','api','webhook'])[1 + floor(random()*3)::int],
  CASE h.default_pms
    WHEN 'stayntouch' THEN 'snt-export-' || to_char(now() - (random()*7)::int * interval '1 day','YYYY-MM-DD') || '.csv'
    WHEN 'mews'       THEN 'mews_first_rules_' || to_char(now() - (random()*7)::int * interval '1 day','YYMMDD') || '.xlsx'
    WHEN 'protel_air' THEN 'protelair-batch-' || (1000 + (random()*9000)::int)::text || '.json'
    WHEN 'visbook'    THEN 'visbook-snapshot-' || to_char(now() - (random()*7)::int * interval '1 day','YYYY-MM-DD') || '.json'
    ELSE 'other-feed-' || (random()*100)::int::text END,
  CASE WHEN random()<0.92 THEN 'completed' WHEN random()<0.97 THEN 'partial' ELSE 'failed' END::pms_import_status,
  (200 + (random()*2000)::int), (180 + (random()*1900)::int), (random()*30)::int,
  now() - (random()*7)::int * interval '1 day',
  now() - (random()*7)::int * interval '1 day' + interval '8 minutes',
  jsonb_build_object('environment','seed')
FROM hotels h
WHERE h.default_pms IS NOT NULL;

INSERT INTO pms_raw_payloads (import_id, pms_code, source_id, payload, payload_hash)
SELECT pi.id, pi.pms_code,
  'src-' || (1000000 + (random()*8000000)::int)::text,
  CASE pi.pms_code
    WHEN 'stayntouch' THEN jsonb_build_object(
      'reservation_number', 100000 + (random()*900000)::int,
      'department_id', 2400 + (random()*100)::int,
      'arrival_time', (now() - (random()*30)::int * interval '1 day')::text,
      'departure_time', (now() - (random()*28)::int * interval '1 day')::text,
      'reservation_source','StayNTouchIntegration',
      'transaction_sum', round((1000 + random()*9000)::numeric, 2),
      'currency','NOK')
    WHEN 'mews' THEN jsonb_build_object(
      'enterprise', 'First Hotel Sample','program_id', '364','department_id', '2510',
      'reservation_nr', (1000 + (random()*9000)::int)::text,
      'origin','ChannelManager','channel_manager','Booking.com',
      'business_segment',(ARRAY['Rack rate','Unqualified discount rate','Negotiated rate'])[1 + floor(random()*3)::int],
      'rate_group',(ARRAY['OTA 48 timer','NRF-WEB','Flex Booking'])[1 + floor(random()*3)::int],
      'service_name','Accommodation',
      'bill_amount', round((2000 + random()*5000)::numeric, 2),'bill_currency','NOK',
      'booking_start', 46100 + random()*200,'booking_end',   46105 + random()*200)
    WHEN 'protel_air' THEN jsonb_build_object('reservation_id','PR-' || (random()*999999)::int, 'amount', round((1500 + random()*4000)::numeric,2), 'currency','NOK')
    WHEN 'visbook'    THEN jsonb_build_object('booking_id','VB-' || (random()*999999)::int, 'amount', round((1500 + random()*3500)::numeric,2), 'currency','SEK')
    ELSE '{}'::jsonb
  END,
  md5(random()::text)
FROM pms_imports pi CROSS JOIN generate_series(1,5);

INSERT INTO pms_sync_errors (import_id, row_index, error_message, error_code, raw_row)
SELECT pi.id, (random()*pi.rows_total)::int,
  (ARRAY['unmapped market segment','currency mismatch','duplicate reservation_no','missing guest email'])[1 + floor(random()*4)::int],
  (ARRAY['MAP_MISSING','CCY_MISMATCH','DUP_RESV','MISSING_EMAIL'])[1 + floor(random()*4)::int],
  jsonb_build_object('row_excerpt','seed-error')
FROM pms_imports pi, generate_series(1,3) WHERE pi.status IN ('partial','failed');

-- Admin users (UUIDs hardcoded for demo)
INSERT INTO admin_users (id, display_name, email, app_role, chain_group_id, is_active, last_login_at, metadata) VALUES
  ('e5500001-0000-0000-0000-000000000001'::uuid, 'Loyco Ops (demo)',  'ops@loyco.example',     'loyco_admin',  NULL, true, now() - interval '1 hour',  '{"demo":true}'),
  ('e5500001-0000-0000-0000-000000000002'::uuid, 'Loyco Support',     'support@loyco.example', 'loyco_admin',  NULL, true, now() - interval '4 hours', '{"demo":true}'),
  ('e5500002-0000-0000-0000-000000000001'::uuid, 'First Member Admin','admin@firstmember.example', 'chain_admin','a1111111-0000-0000-0000-000000000001'::uuid, true, now() - interval '2 hours', '{"demo":true}'),
  ('e5500002-0000-0000-0000-000000000002'::uuid, 'Quality Living Admin','admin@qualityliving.example','chain_admin','a1111111-0000-0000-0000-000000000002'::uuid, true, now() - interval '3 hours', '{"demo":true}'),
  ('e5500002-0000-0000-0000-000000000003'::uuid, 'Fjord Boutique Admin','admin@fjordboutique.example','chain_admin','a1111111-0000-0000-0000-000000000003'::uuid, true, now() - interval '6 hours', '{"demo":true}'),
  ('e5500002-0000-0000-0000-000000000004'::uuid, 'Smart Stays Admin', 'admin@smartstays.example','chain_admin','a1111111-0000-0000-0000-000000000004'::uuid, true, now() - interval '8 hours', '{"demo":true}'),
  ('e5500002-0000-0000-0000-000000000005'::uuid, 'Coastal Hideaways Admin','admin@coastalhideaways.example','chain_admin','a1111111-0000-0000-0000-000000000005'::uuid, true, now() - interval '12 hours','{"demo":true}'),
  ('e5500003-0000-0000-0000-000000000001'::uuid, 'Oslo Front Desk',   'oslo.staff@firstmember.example','hotel_staff','a1111111-0000-0000-0000-000000000001'::uuid, true, now() - interval '30 min',  '{"demo":true}'),
  ('e5500003-0000-0000-0000-000000000002'::uuid, 'Stavanger Manager', 'stavanger.mgr@qualityliving.example','hotel_staff','a1111111-0000-0000-0000-000000000002'::uuid, true, now() - interval '20 min','{"demo":true}'),
  ('e5500004-0000-0000-0000-000000000001'::uuid, 'First Member Analyst', 'analyst@firstmember.example','analyst','a1111111-0000-0000-0000-000000000001'::uuid, true, now() - interval '1 day','{"demo":true}');

INSERT INTO admin_user_hotel_assignments (admin_user_id, hotel_id, assigned_by) VALUES
  ('e5500003-0000-0000-0000-000000000001'::uuid, 'b2200001-0000-0000-0000-000000000001'::uuid, 'e5500002-0000-0000-0000-000000000001'::uuid),
  ('e5500003-0000-0000-0000-000000000001'::uuid, 'b2200001-0000-0000-0000-000000000002'::uuid, 'e5500002-0000-0000-0000-000000000001'::uuid),
  ('e5500003-0000-0000-0000-000000000002'::uuid, 'b2200002-0000-0000-0000-000000000002'::uuid, 'e5500002-0000-0000-0000-000000000002'::uuid),
  ('e5500003-0000-0000-0000-000000000002'::uuid, 'b2200002-0000-0000-0000-000000000004'::uuid, 'e5500002-0000-0000-0000-000000000002'::uuid);

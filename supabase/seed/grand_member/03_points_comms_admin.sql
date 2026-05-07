-- ====================================================================
-- Grand Member re-seed — Part 3 of 3: points + redemptions + comms + marketing + PMS + admin
-- Run AFTER part 2.
-- Estimated runtime: 15–30 seconds.
-- Re-enables audit triggers at the end.
-- ====================================================================

SELECT setseed(0.47);

-- ===== 3.1 Earn-release point transactions for all earning member bookings =====
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

-- ===== 3.2 Manual adjustments (~50 random members) =====
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

-- ===== 3.3 Redemptions (~10% of Silver+ active members) =====
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

-- ===== 3.4 Pending earns for in-house bookings =====
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

-- Refresh the balance materialized view
REFRESH MATERIALIZED VIEW points_balances_mv;

-- ===== 3.5 Communication templates (Grand Member, both nb and en) =====
SELECT setseed(0.48);

INSERT INTO communication_templates (chain_group_id, code, name, channel, category, subject_template, body_template, language)
SELECT 'a1111111-aaaa-aaaa-aaaa-000000000001'::uuid, t.code, t.name, t.channel::comm_channel, t.category::comm_category, t.subject_template, t.body_template, lang.code
FROM (VALUES
  ('personal_invitation_sms','Personal Invitation SMS','sms','personal_invitation', NULL,
    'Hi {{first_name}}! Activate your Grand Member profile and get more out of your upcoming stay: {{activation_link}} /Grand Member'),
  ('welcome_email','Welcome to Grand Member','email','transactional','Welcome to Grand Member',
    'Dear {{first_name}}, welcome aboard. You can now earn points on every direct booking at any Grand avdeling.'),
  ('booking_confirmation','Booking Confirmation','email','transactional','Your reservation is confirmed at {{hotel_name}}',
    'Dear {{first_name}}, thank you for booking. Confirmation: {{conf_no}}'),
  ('tier_upgrade','Tier upgrade celebration','email','automation','Congratulations — you are now {{new_tier}}',
    'Dear {{first_name}}, you have unlocked {{new_tier}} status with Grand Member.'),
  ('birthday','Birthday email','email','automation','A little something for your birthday',
    'Hi {{first_name}}! On us: {{birthday_perk}}'),
  ('newsletter','Monthly newsletter','email','marketing_campaign','{{month}} member highlights from Grand Member',
    'Member-only deals across the Nordic Grand avdelinger.'),
  ('winback','Win-back campaign','email','marketing_campaign','We miss you, {{first_name}}',
    'Come back to Grand Member — here are 1 000 bonus points to start.')
) AS t(code, name, channel, category, subject_template, body_template)
CROSS JOIN (VALUES ('nb'),('en')) AS lang(code);

-- ===== 3.6 Personal-invitation SMS for 85% of OTA bookings with member phone =====
INSERT INTO communications (
  chain_group_id, hotel_id, member_id, channel, direction, category, status,
  template_id, to_phone, sender_label, subject, body, language,
  queued_at, sent_at, delivered_at, external_message_id,
  sms_logical_count, sms_real_count, scandinavia_flag, metadata
)
SELECT
  b.chain_group_id, b.hotel_id, b.member_id,
  'sms'::comm_channel, 'outbound'::comm_direction, 'personal_invitation'::comm_category,
  CASE WHEN random() < 0.95 THEN 'delivered' WHEN random() < 0.98 THEN 'failed' ELSE 'sent' END::comm_status,
  (SELECT id FROM communication_templates ct WHERE ct.code = 'personal_invitation_sms' AND ct.language = CASE WHEN random()<0.7 THEN 'nb' ELSE 'en' END LIMIT 1),
  m.phone_e164,
  'GrandMember', NULL,
  'Hi ' || m.first_name || '! Activate your Grand Member profile: https://go.loyall.no/' || substring(md5(b.id::text), 1, 22),
  CASE WHEN m.country_code IN ('NO','SE','DK') THEN 'nb' ELSE 'en' END,
  b.booked_at + interval '5 minutes',
  b.booked_at + interval '6 minutes',
  b.booked_at + interval '6 minutes' + (random()*30)::int * interval '1 second',
  'msg-' || substring(md5(b.id::text || 'inv'), 1, 12),
  1, CASE WHEN random() < 0.85 THEN 1 ELSE 2 END,
  m.country_code IN ('NO','SE','DK'),
  '{}'::jsonb
FROM bookings b
JOIN members m ON m.id = b.member_id
WHERE b.channel = 'ota' AND m.phone_e164 IS NOT NULL AND random() < 0.85;

-- ===== 3.7 Booking confirmation emails for 50% of direct/corporate member bookings =====
INSERT INTO communications (
  chain_group_id, hotel_id, member_id, channel, direction, category, status,
  template_id, to_email, from_email, subject, body, language,
  queued_at, sent_at, delivered_at, external_message_id
)
SELECT
  b.chain_group_id, b.hotel_id, b.member_id,
  'email','outbound','transactional',
  CASE WHEN random()<0.97 THEN 'delivered' WHEN random()<0.99 THEN 'opened' ELSE 'bounced' END::comm_status,
  (SELECT id FROM communication_templates ct WHERE ct.code = 'booking_confirmation' AND ct.language='nb' LIMIT 1),
  m.email,
  'reservations@grandmember.example',
  'Your reservation at ' || h.name || ' is confirmed',
  'Confirmation: ' || b.pms_confirmation_code,
  'nb',
  b.booked_at + interval '1 minute',
  b.booked_at + interval '1 minute',
  b.booked_at + interval '2 minutes',
  'em-' || substring(md5(b.id::text || 'conf'), 1, 12)
FROM bookings b
JOIN members m ON m.id = b.member_id
JOIN hotels h ON h.id = b.hotel_id
WHERE b.channel IN ('direct','corporate') AND m.email IS NOT NULL AND random() < 0.5;

-- ===== 3.8 Segments (5 starter segments) =====
INSERT INTO segments (chain_group_id, code, name, description, definition, is_dynamic, estimated_size, last_computed_at)
SELECT 'a1111111-aaaa-aaaa-aaaa-000000000001'::uuid, s.code, s.name, s.description, s.def::jsonb, true, (300 + (random()*1500)::int), now()
FROM (VALUES
  ('high_value',     'High-value members',        'Top-tier active members',
    '{"type":"and","children":[{"type":"member.tier_sort_order","op":">=","value":3},{"type":"member.status","op":"=","value":"active"}]}'),
  ('churned',        'Churned members',           'No bookings in 12+ months',
    '{"type":"member.is_churned","op":"=","value":true}'),
  ('ota_only',       'OTA-only members',          'Recruited via OTA, no direct bookings yet',
    '{"type":"member.recruited_via_ota","op":"=","value":true}'),
  ('birthday_month', 'Birthday this month',       'Birthday in current calendar month',
    '{"type":"member.birthday_month","op":"=","value":"current"}'),
  ('near_upgrade',   'Close to next tier',        'Within 20% of next tier threshold',
    '{"type":"member.tier_progress_pct","op":">=","value":80}')
) AS s(code, name, description, def);

-- ===== 3.9 Campaigns (4 starter campaigns) =====
INSERT INTO campaigns (chain_group_id, code, name, channel, status, start_date, end_date, segment_id, recipient_count, delivered_count, opened_count, clicked_count)
SELECT 'a1111111-aaaa-aaaa-aaaa-000000000001'::uuid, c.code, c.name, c.channel::comm_channel, c.status::campaign_status,
  c.start_date::date, c.end_date::date,
  (SELECT id FROM segments s WHERE s.code = c.segment_code LIMIT 1),
  (300 + (random()*2500)::int), (200 + (random()*2300)::int),
  (50 + (random()*800)::int), (10 + (random()*200)::int)
FROM (VALUES
  ('newsletter-jan-2026',  'January Newsletter 2026', 'email', 'completed', '2026-01-05','2026-01-05','high_value'),
  ('newsletter-mar-2026',  'March Newsletter 2026',   'email', 'completed', '2026-03-01','2026-03-01','high_value'),
  ('winback-q1-2026',      'Win-back Q1 2026',        'email', 'completed', '2026-02-15','2026-03-15','churned'),
  ('summer-promo-2026',    'Summer Promo 2026',       'email', 'scheduled', '2026-06-01','2026-06-15','ota_only')
) AS c(code, name, channel, status, start_date, end_date, segment_code);

WITH cmp AS (SELECT id, recipient_count FROM campaigns WHERE status = 'completed')
INSERT INTO campaign_recipients (campaign_id, member_id, status, sent_at, delivered_at, opened_at, clicked_at)
SELECT c.id, m.id,
  CASE WHEN random()<0.92 THEN 'delivered' WHEN random()<0.95 THEN 'opened' WHEN random()<0.97 THEN 'clicked' WHEN random()<0.99 THEN 'bounced' ELSE 'failed' END::comm_status,
  now() - (random()*120)::int * interval '1 day',
  now() - (random()*120)::int * interval '1 day' + interval '5 minutes',
  CASE WHEN random()<0.3 THEN now() - (random()*120)::int * interval '1 day' + interval '2 hours' ELSE NULL END,
  CASE WHEN random()<0.06 THEN now() - (random()*120)::int * interval '1 day' + interval '2 hours 30 minutes' ELSE NULL END
FROM cmp c
JOIN LATERAL (SELECT id FROM members m2 ORDER BY md5(m2.id::text || c.id::text) LIMIT LEAST(c.recipient_count, 200)) m ON true;

-- ===== 3.10 Automations (3 starter flows) =====
INSERT INTO automations (id, chain_group_id, code, name, description, trigger_type, status, segment_id, trigger_config)
SELECT gen_random_uuid(), 'a1111111-aaaa-aaaa-aaaa-000000000001'::uuid, a.code, a.name, a.description,
  a.trigger::automation_trigger, a.status::automation_status,
  (SELECT id FROM segments s WHERE s.code = a.segment_code LIMIT 1),
  a.config::jsonb
FROM (VALUES
  ('post-ota-invitation','Post-OTA Invitation','Invite to membership 5 minutes after OTA booking is received','ota_booking_received','active', NULL,
    '{"delay_minutes":5,"filters":{"channel":"ota"}}'),
  ('birthday-greeting',  'Birthday Greeting',  'Send birthday email on guest birthday','birthday','active','birthday_month',
    '{"send_at_local":"09:00"}'),
  ('inactive-winback',   'Inactive Win-back',  'Trigger when member has not booked in 9 months','inactive_member','active','churned',
    '{"days_inactive":270}')
) AS a(code, name, description, trigger, status, segment_code, config);

INSERT INTO automation_steps (automation_id, step_index, action_type, template_id, params)
SELECT a.id, 0,
  CASE
    WHEN a.code = 'post-ota-invitation' THEN 'send_sms'::automation_action_type
    WHEN a.code = 'birthday-greeting'   THEN 'send_email'::automation_action_type
    WHEN a.code = 'inactive-winback'    THEN 'send_email'::automation_action_type
  END,
  (SELECT id FROM communication_templates ct
   WHERE ct.code = CASE
       WHEN a.code = 'post-ota-invitation' THEN 'personal_invitation_sms'
       WHEN a.code = 'birthday-greeting'   THEN 'birthday'
       WHEN a.code = 'inactive-winback'    THEN 'winback'
     END
   AND ct.language='nb' LIMIT 1),
  '{}'::jsonb
FROM automations a;

INSERT INTO automation_runs (automation_id, member_id, trigger_event, status, current_step_index, started_at, finished_at)
SELECT a.id, m.id,
  jsonb_build_object('booking_id', (SELECT id FROM bookings b WHERE b.member_id = m.id ORDER BY random() LIMIT 1)),
  CASE WHEN random()<0.92 THEN 'completed' WHEN random()<0.97 THEN 'failed' ELSE 'queued' END::automation_run_status,
  0,
  now() - (random()*120)::int * interval '1 day',
  now() - (random()*120)::int * interval '1 day' + interval '10 minutes'
FROM automations a
JOIN LATERAL (SELECT id FROM members m2 ORDER BY md5(m2.id::text || a.id::text) LIMIT 50) m ON true;

-- ===== 3.11 PMS imports + raw payloads + sync errors =====
SELECT setseed(0.49);

INSERT INTO pms_imports (chain_group_id, hotel_id, pms_code, source_kind, source_identifier, status, rows_total, rows_succeeded, rows_failed, started_at, finished_at, metadata)
SELECT h.chain_group_id, h.id, h.default_pms,
  (ARRAY['file','api','webhook'])[1 + floor(random()*3)::int],
  CASE h.default_pms
    WHEN 'stayntouch' THEN 'snt-export-' || to_char(now() - (random()*7)::int * interval '1 day','YYYY-MM-DD') || '.csv'
    WHEN 'mews'       THEN 'mews_grand_rules_' || to_char(now() - (random()*7)::int * interval '1 day','YYMMDD') || '.xlsx'
    WHEN 'protel_air' THEN 'protelair-batch-' || (1000 + (random()*9000)::int)::text || '.json'
    WHEN 'visbook'    THEN 'visbook-snapshot-' || to_char(now() - (random()*7)::int * interval '1 day','YYYY-MM-DD') || '.json'
    ELSE 'other-feed-' || (random()*100)::int::text
  END,
  CASE WHEN random()<0.92 THEN 'completed' WHEN random()<0.97 THEN 'partial' ELSE 'failed' END::pms_import_status,
  (200 + (random()*2000)::int), (180 + (random()*1900)::int), (random()*30)::int,
  now() - (random()*7)::int * interval '1 day',
  now() - (random()*7)::int * interval '1 day' + interval '8 minutes',
  jsonb_build_object('environment','seed')
FROM hotels h WHERE h.default_pms IS NOT NULL;

INSERT INTO pms_raw_payloads (import_id, pms_code, source_id, payload, payload_hash)
SELECT pi.id, pi.pms_code,
  'src-' || (1000000 + (random()*8000000)::int)::text,
  CASE pi.pms_code
    WHEN 'stayntouch' THEN jsonb_build_object('reservation_number', 100000 + (random()*900000)::int, 'department_id', 2400 + (random()*100)::int, 'reservation_source','StayNTouchIntegration', 'transaction_sum', round((1000 + random()*9000)::numeric, 2),'currency','NOK')
    WHEN 'mews' THEN jsonb_build_object('enterprise', 'Grand Hotel Sample','program_id', '364','department_id', '2510', 'reservation_nr', (1000 + (random()*9000)::int)::text, 'origin','ChannelManager','channel_manager','Booking.com', 'business_segment',(ARRAY['Rack rate','Unqualified discount rate','Negotiated rate'])[1 + floor(random()*3)::int], 'rate_group',(ARRAY['OTA 48 timer','NRF-WEB','Flex Booking'])[1 + floor(random()*3)::int], 'service_name','Accommodation', 'bill_amount', round((2000 + random()*5000)::numeric, 2),'bill_currency','NOK')
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

-- ===== 3.12 Admin users (Grand Member only) =====
INSERT INTO admin_users (id, display_name, email, app_role, chain_group_id, is_active, last_login_at, metadata) VALUES
  ('e5500001-aaaa-aaaa-aaaa-000000000001'::uuid, 'Loyco Ops (demo)',  'ops@loyco.example',     'loyco_admin',  NULL, true, now() - interval '1 hour',  '{"demo":true}'),
  ('e5500001-aaaa-aaaa-aaaa-000000000002'::uuid, 'Loyco Support',     'support@loyco.example', 'loyco_admin',  NULL, true, now() - interval '4 hours', '{"demo":true}'),
  ('e5500002-aaaa-aaaa-aaaa-000000000001'::uuid, 'Grand Member Admin','admin@grandmember.example','chain_admin','a1111111-aaaa-aaaa-aaaa-000000000001'::uuid, true, now() - interval '2 hours', '{"demo":true}'),
  ('e5500003-aaaa-aaaa-aaaa-000000000001'::uuid, 'Oslo Front Desk',   'oslo@grandmember.example','hotel_staff','a1111111-aaaa-aaaa-aaaa-000000000001'::uuid, true, now() - interval '30 min',  '{"demo":true}'),
  ('e5500003-aaaa-aaaa-aaaa-000000000002'::uuid, 'Stockholm Manager', 'stockholm@grandmember.example','hotel_staff','a1111111-aaaa-aaaa-aaaa-000000000001'::uuid, true, now() - interval '20 min','{"demo":true}'),
  ('e5500003-aaaa-aaaa-aaaa-000000000003'::uuid, 'København Manager', 'kobenhavn@grandmember.example','hotel_staff','a1111111-aaaa-aaaa-aaaa-000000000001'::uuid, true, now() - interval '15 min','{"demo":true}'),
  ('e5500004-aaaa-aaaa-aaaa-000000000001'::uuid, 'Grand Member Analyst', 'analyst@grandmember.example','analyst','a1111111-aaaa-aaaa-aaaa-000000000001'::uuid, true, now() - interval '1 day','{"demo":true}');

INSERT INTO admin_user_hotel_assignments (admin_user_id, hotel_id, assigned_by) VALUES
  ('e5500003-aaaa-aaaa-aaaa-000000000001'::uuid, 'b2200001-aaaa-aaaa-aaaa-000000000001'::uuid, 'e5500002-aaaa-aaaa-aaaa-000000000001'::uuid),
  ('e5500003-aaaa-aaaa-aaaa-000000000001'::uuid, 'b2200001-aaaa-aaaa-aaaa-000000000002'::uuid, 'e5500002-aaaa-aaaa-aaaa-000000000001'::uuid),
  ('e5500003-aaaa-aaaa-aaaa-000000000002'::uuid, 'b2200001-aaaa-aaaa-aaaa-000000000006'::uuid, 'e5500002-aaaa-aaaa-aaaa-000000000001'::uuid),
  ('e5500003-aaaa-aaaa-aaaa-000000000002'::uuid, 'b2200001-aaaa-aaaa-aaaa-000000000007'::uuid, 'e5500002-aaaa-aaaa-aaaa-000000000001'::uuid),
  ('e5500003-aaaa-aaaa-aaaa-000000000003'::uuid, 'b2200001-aaaa-aaaa-aaaa-000000000010'::uuid, 'e5500002-aaaa-aaaa-aaaa-000000000001'::uuid),
  ('e5500003-aaaa-aaaa-aaaa-000000000003'::uuid, 'b2200001-aaaa-aaaa-aaaa-000000000011'::uuid, 'e5500002-aaaa-aaaa-aaaa-000000000001'::uuid);

-- ===== 3.13 Re-enable audit triggers (disabled in part 1) =====
ALTER TABLE members ENABLE TRIGGER members_audit;
ALTER TABLE bookings ENABLE TRIGGER bookings_audit;
ALTER TABLE point_transactions ENABLE TRIGGER point_transactions_manual_audit;
ALTER TABLE tiers ENABLE TRIGGER tiers_audit;
ALTER TABLE tier_thresholds ENABLE TRIGGER tier_thresholds_audit;
ALTER TABLE tier_benefits ENABLE TRIGGER tier_benefits_audit;
ALTER TABLE points_rules ENABLE TRIGGER points_rules_audit;
ALTER TABLE member_tier_history ENABLE TRIGGER member_tier_history_audit;
ALTER TABLE admin_users ENABLE TRIGGER admin_users_audit;
ALTER TABLE admin_user_hotel_assignments ENABLE TRIGGER admin_user_hotel_assignments_audit;

-- ===== 3.14 Final verification =====
SELECT
  (SELECT count(*) FROM chain_groups) AS chains,
  (SELECT count(*) FROM hotels) AS hotels,
  (SELECT count(*) FROM members) AS members,
  (SELECT count(*) FROM bookings) AS bookings,
  (SELECT count(*) FROM bookings WHERE member_id IS NOT NULL) AS member_bookings,
  (SELECT count(*) FROM bookings WHERE member_id IS NULL) AS non_member_bookings,
  (SELECT count(*) FROM transactions) AS transactions,
  (SELECT round(avg(posted_amount))::int FROM transactions WHERE member_id IS NOT NULL AND status='posted' AND transaction_type='charge') AS avg_member_tx_nok,
  (SELECT round(avg(posted_amount))::int FROM transactions WHERE member_id IS NULL AND status='posted' AND transaction_type='charge') AS avg_non_member_tx_nok,
  (SELECT count(*) FROM point_transactions) AS pt_total,
  (SELECT count(*) FROM communications) AS comms,
  (SELECT count(*) FROM segments) AS segments,
  (SELECT count(*) FROM campaigns) AS campaigns,
  (SELECT count(*) FROM automations) AS automations,
  (SELECT count(*) FROM admin_users) AS admin_users;

SELECT chain_name, active_hotels, active_members, bookings_last_365d, bookings_upcoming,
       round(revenue_last_365d_reporting/1000)::text || 'k ' || reporting_currency AS revenue_365d,
       direct_share_pct_last_365d AS direct_pct
FROM chain_overview_view;

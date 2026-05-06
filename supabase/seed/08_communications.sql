-- 08_communications.sql
-- 70 templates (7 per chain × 2 languages), 21998 communications (16495 OTA invitation SMS,
-- 5503 booking confirmation emails), 25 segments (5 per chain), 20 campaigns (4 per chain),
-- 2700 campaign recipients, 15 automations (3 per chain) + steps + 750 runs.

SELECT setseed(0.48);

INSERT INTO communication_templates (chain_group_id, code, name, channel, category, subject_template, body_template, language)
SELECT cg.id, t.code, t.name, t.channel::comm_channel, t.category::comm_category, t.subject_template, t.body_template, lang.code
FROM chain_groups cg
CROSS JOIN (VALUES
  ('personal_invitation_sms','Personal Invitation SMS','sms','personal_invitation', NULL,
    'Hi {{first_name}}! Activate your member profile and get more out of your upcoming stay: {{activation_link}} /{{chain_name}}'),
  ('welcome_email','Welcome to the program','email','transactional','Welcome to {{chain_name}}',
    'Dear {{first_name}}, welcome aboard! You can now earn points on every direct booking.'),
  ('booking_confirmation','Booking Confirmation','email','transactional','Your reservation is confirmed at {{hotel_name}}',
    'Dear {{first_name}}, thank you for booking. Confirmation: {{conf_no}}'),
  ('tier_upgrade','Tier upgrade celebration','email','automation','Congratulations — you are now {{new_tier}}',
    'Dear {{first_name}}, you have unlocked {{new_tier}} status.'),
  ('birthday','Birthday email','email','automation','A little something for your birthday',
    'Hi {{first_name}}! On us: {{birthday_perk}}'),
  ('newsletter','Monthly newsletter','email','marketing_campaign','{{month}} member highlights from {{chain_name}}',
    'Member-only deals, new properties, partner offers.'),
  ('winback','Win-back campaign','email','marketing_campaign','We miss you, {{first_name}}',
    'Come back to {{chain_name}} — here are 1 000 bonus points to start.')
) AS t(code, name, channel, category, subject_template, body_template)
CROSS JOIN (VALUES ('nb'),('en')) AS lang(code);

-- Personal Invitation SMS for 85% of OTA bookings with member phone
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
  (SELECT id FROM communication_templates ct WHERE ct.chain_group_id = b.chain_group_id AND ct.code = 'personal_invitation_sms' AND ct.language = CASE WHEN random()<0.7 THEN 'nb' ELSE 'en' END LIMIT 1),
  m.phone_e164,
  CASE b.chain_group_id::text
    WHEN 'a1111111-0000-0000-0000-000000000001' THEN 'FirstMember'
    WHEN 'a1111111-0000-0000-0000-000000000002' THEN 'QualityClub'
    WHEN 'a1111111-0000-0000-0000-000000000003' THEN 'FjordFriends'
    WHEN 'a1111111-0000-0000-0000-000000000004' THEN 'SmartRewards'
    WHEN 'a1111111-0000-0000-0000-000000000005' THEN 'CoastalCircle'
  END,
  NULL,
  'Hi ' || m.first_name || '! Activate your ' || (CASE b.chain_group_id::text
    WHEN 'a1111111-0000-0000-0000-000000000001' THEN 'First Member'
    WHEN 'a1111111-0000-0000-0000-000000000002' THEN 'Quality Club'
    WHEN 'a1111111-0000-0000-0000-000000000003' THEN 'Fjord Friends'
    WHEN 'a1111111-0000-0000-0000-000000000004' THEN 'Smart Rewards'
    WHEN 'a1111111-0000-0000-0000-000000000005' THEN 'Coastal Circle'
  END) || ' profile: https://go.loyall.no/' || substring(md5(b.id::text), 1, 22),
  CASE WHEN m.country_code IN ('NO','SE','DK') THEN 'nb' ELSE 'en' END,
  b.booked_at + interval '5 minutes',
  b.booked_at + interval '6 minutes',
  b.booked_at + interval '6 minutes' + (random()*30)::int * interval '1 second',
  'msg-' || substring(md5(b.id::text || 'inv'), 1, 12),
  1,
  CASE WHEN random() < 0.85 THEN 1 ELSE 2 END,
  m.country_code IN ('NO','SE','DK'),
  '{}'::jsonb
FROM bookings b
JOIN members m ON m.id = b.member_id
WHERE b.channel = 'ota' AND m.phone_e164 IS NOT NULL AND random() < 0.85;

-- Booking confirmation emails for 50% of direct/corporate bookings with member email
INSERT INTO communications (
  chain_group_id, hotel_id, member_id, channel, direction, category, status,
  template_id, to_email, from_email, subject, body, language,
  queued_at, sent_at, delivered_at, external_message_id
)
SELECT
  b.chain_group_id, b.hotel_id, b.member_id,
  'email','outbound','transactional',
  CASE WHEN random()<0.97 THEN 'delivered' WHEN random()<0.99 THEN 'opened' ELSE 'bounced' END::comm_status,
  (SELECT id FROM communication_templates ct WHERE ct.chain_group_id = b.chain_group_id AND ct.code = 'booking_confirmation' AND ct.language='nb' LIMIT 1),
  m.email,
  'reservations@' || cg.slug || '.example',
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
JOIN chain_groups cg ON cg.id = b.chain_group_id
WHERE b.channel IN ('direct','corporate') AND m.email IS NOT NULL AND random() < 0.5;

-- Segments (5 per chain)
INSERT INTO segments (chain_group_id, code, name, description, definition, is_dynamic, estimated_size, last_computed_at)
SELECT cg.id, s.code, s.name, s.description, s.def::jsonb, true, (300 + (random()*1500)::int), now()
FROM chain_groups cg
CROSS JOIN (VALUES
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

-- Campaigns (4 per chain)
INSERT INTO campaigns (chain_group_id, code, name, channel, status, start_date, end_date, segment_id, recipient_count, delivered_count, opened_count, clicked_count)
SELECT cg.id, c.code || '-' || cg.slug, c.name, c.channel::comm_channel, c.status::campaign_status,
  c.start_date::date, c.end_date::date,
  (SELECT id FROM segments s WHERE s.chain_group_id = cg.id AND s.code = c.segment_code LIMIT 1),
  (300 + (random()*2500)::int), (200 + (random()*2300)::int),
  (50 + (random()*800)::int), (10 + (random()*200)::int)
FROM chain_groups cg
CROSS JOIN (VALUES
  ('newsletter-jan',  'January Newsletter', 'email', 'completed', '2026-01-05','2026-01-05','high_value'),
  ('newsletter-mar',  'March Newsletter',   'email', 'completed', '2026-03-01','2026-03-01','high_value'),
  ('winback-q1',      'Win-back Q1',        'email', 'completed', '2026-02-15','2026-03-15','churned'),
  ('summer-promo',    'Summer Promo',       'email', 'scheduled', '2026-06-01','2026-06-15','ota_only')
) AS c(code, name, channel, status, start_date, end_date, segment_code);

-- Sample campaign recipients (200 members per completed campaign)
WITH cmp AS (SELECT id, chain_group_id, recipient_count FROM campaigns WHERE status = 'completed')
INSERT INTO campaign_recipients (campaign_id, member_id, status, sent_at, delivered_at, opened_at, clicked_at)
SELECT c.id, m.id,
  CASE WHEN random()<0.92 THEN 'delivered' WHEN random()<0.95 THEN 'opened' WHEN random()<0.97 THEN 'clicked' WHEN random()<0.99 THEN 'bounced' ELSE 'failed' END::comm_status,
  now() - (random()*120)::int * interval '1 day',
  now() - (random()*120)::int * interval '1 day' + interval '5 minutes',
  CASE WHEN random()<0.3 THEN now() - (random()*120)::int * interval '1 day' + interval '2 hours' ELSE NULL END,
  CASE WHEN random()<0.06 THEN now() - (random()*120)::int * interval '1 day' + interval '2 hours 30 minutes' ELSE NULL END
FROM cmp c
JOIN LATERAL (SELECT id FROM members m2 WHERE m2.chain_group_id = c.chain_group_id ORDER BY md5(m2.id::text || c.id::text) LIMIT LEAST(c.recipient_count, 200)) m ON true;

-- Automations (3 per chain)
INSERT INTO automations (id, chain_group_id, code, name, description, trigger_type, status, segment_id, trigger_config)
SELECT gen_random_uuid(), cg.id, a.code || '-' || cg.slug, a.name, a.description,
  a.trigger::automation_trigger, a.status::automation_status,
  (SELECT id FROM segments s WHERE s.chain_group_id = cg.id AND s.code = a.segment_code LIMIT 1),
  a.config::jsonb
FROM chain_groups cg
CROSS JOIN (VALUES
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
    WHEN a.code LIKE 'post-ota-invitation%' THEN 'send_sms'::automation_action_type
    WHEN a.code LIKE 'birthday%'            THEN 'send_email'::automation_action_type
    WHEN a.code LIKE 'inactive-winback%'    THEN 'send_email'::automation_action_type
  END,
  (SELECT id FROM communication_templates ct WHERE ct.chain_group_id = a.chain_group_id
     AND ct.code = CASE
       WHEN a.code LIKE 'post-ota-invitation%' THEN 'personal_invitation_sms'
       WHEN a.code LIKE 'birthday%'            THEN 'birthday'
       WHEN a.code LIKE 'inactive-winback%'    THEN 'winback'
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
JOIN LATERAL (SELECT id FROM members m2 WHERE m2.chain_group_id = a.chain_group_id ORDER BY md5(m2.id::text || a.id::text) LIMIT 50) m ON true;

-- 02_loyalty_config.sql
-- Loyalty programs (one per chain), tiers, thresholds, benefits, points rules, rewards.
-- Tier and points config varies per chain per ADR-0006.

-- ===== Loyalty programs =====
INSERT INTO loyalty_programs (id, chain_group_id, slug, name, description, points_currency, points_expiry_months, is_active) VALUES
  ('c3300001-0000-0000-0000-000000000001'::uuid, 'a1111111-0000-0000-0000-000000000001', 'first-member',  'First Member',           'Norden-wide loyalty across First Member properties',         'NOK', 24, true),
  ('c3300001-0000-0000-0000-000000000002'::uuid, 'a1111111-0000-0000-0000-000000000002', 'quality-club',  'Quality Club',           'Quality Living Norway loyalty club',                         'NOK', 36, true),
  ('c3300001-0000-0000-0000-000000000003'::uuid, 'a1111111-0000-0000-0000-000000000003', 'fjord-friends','Fjord Friends',           'Boutique experiences across Iceland and Norway',             'EUR', 24, true),
  ('c3300001-0000-0000-0000-000000000004'::uuid, 'a1111111-0000-0000-0000-000000000004', 'smart-rewards','Smart Rewards',           'Business traveller rewards across Smart Stays',              'SEK', 18, true),
  ('c3300001-0000-0000-0000-000000000005'::uuid, 'a1111111-0000-0000-0000-000000000005', 'coastal-circle','Coastal Circle',         'Invitation-only retreat circle',                              'DKK', NULL, true);

-- ===== Tiers =====
-- First Member: 5 tiers (Bronze, Silver, Gold, Platinum, Black)
INSERT INTO tiers (id, program_id, chain_group_id, code, name, sort_order, multiplier_default, color_hex, is_default_initial, is_active) VALUES
  ('d4400001-0000-0000-0000-000000000001'::uuid, 'c3300001-0000-0000-0000-000000000001', 'a1111111-0000-0000-0000-000000000001', 'bronze',   'Bronze',   1, 1.0, '#CD7F32', true,  true),
  ('d4400001-0000-0000-0000-000000000002'::uuid, 'c3300001-0000-0000-0000-000000000001', 'a1111111-0000-0000-0000-000000000001', 'silver',   'Silver',   2, 1.2, '#C0C0C0', false, true),
  ('d4400001-0000-0000-0000-000000000003'::uuid, 'c3300001-0000-0000-0000-000000000001', 'a1111111-0000-0000-0000-000000000001', 'gold',     'Gold',     3, 1.5, '#FFD700', false, true),
  ('d4400001-0000-0000-0000-000000000004'::uuid, 'c3300001-0000-0000-0000-000000000001', 'a1111111-0000-0000-0000-000000000001', 'platinum', 'Platinum', 4, 1.8, '#E5E4E2', false, true),
  ('d4400001-0000-0000-0000-000000000005'::uuid, 'c3300001-0000-0000-0000-000000000001', 'a1111111-0000-0000-0000-000000000001', 'black',    'Black',    5, 2.2, '#0A0A0A', false, true);

-- Quality Club: 4 tiers
INSERT INTO tiers (id, program_id, chain_group_id, code, name, sort_order, multiplier_default, color_hex, is_default_initial, is_active) VALUES
  ('d4400002-0000-0000-0000-000000000001'::uuid, 'c3300001-0000-0000-0000-000000000002', 'a1111111-0000-0000-0000-000000000002', 'bronze',   'Bronze',   1, 1.0, '#CD7F32', true,  true),
  ('d4400002-0000-0000-0000-000000000002'::uuid, 'c3300001-0000-0000-0000-000000000002', 'a1111111-0000-0000-0000-000000000002', 'silver',   'Silver',   2, 1.25,'#C0C0C0', false, true),
  ('d4400002-0000-0000-0000-000000000003'::uuid, 'c3300001-0000-0000-0000-000000000002', 'a1111111-0000-0000-0000-000000000002', 'gold',     'Gold',     3, 1.5, '#FFD700', false, true),
  ('d4400002-0000-0000-0000-000000000004'::uuid, 'c3300001-0000-0000-0000-000000000002', 'a1111111-0000-0000-0000-000000000002', 'platinum', 'Platinum', 4, 2.0, '#E5E4E2', false, true);

-- Fjord Friends: 4 tiers (premium positioning, higher multipliers)
INSERT INTO tiers (id, program_id, chain_group_id, code, name, sort_order, multiplier_default, color_hex, is_default_initial, is_active) VALUES
  ('d4400003-0000-0000-0000-000000000001'::uuid, 'c3300001-0000-0000-0000-000000000003', 'a1111111-0000-0000-0000-000000000003', 'explorer','Explorer',  1, 1.0, '#7FA5B7', true,  true),
  ('d4400003-0000-0000-0000-000000000002'::uuid, 'c3300001-0000-0000-0000-000000000003', 'a1111111-0000-0000-0000-000000000003', 'voyager', 'Voyager',   2, 1.3, '#3F88C5', false, true),
  ('d4400003-0000-0000-0000-000000000003'::uuid, 'c3300001-0000-0000-0000-000000000003', 'a1111111-0000-0000-0000-000000000003', 'aurora',  'Aurora',    3, 1.6, '#0B6E4F', false, true),
  ('d4400003-0000-0000-0000-000000000004'::uuid, 'c3300001-0000-0000-0000-000000000003', 'a1111111-0000-0000-0000-000000000003', 'midnight','Midnight',  4, 2.0, '#0A0A29', false, true);

-- Smart Rewards: 4 tiers
INSERT INTO tiers (id, program_id, chain_group_id, code, name, sort_order, multiplier_default, color_hex, is_default_initial, is_active) VALUES
  ('d4400004-0000-0000-0000-000000000001'::uuid, 'c3300001-0000-0000-0000-000000000004', 'a1111111-0000-0000-0000-000000000004', 'standard','Standard',  1, 1.0, '#9E9E9E', true,  true),
  ('d4400004-0000-0000-0000-000000000002'::uuid, 'c3300001-0000-0000-0000-000000000004', 'a1111111-0000-0000-0000-000000000004', 'frequent','Frequent',  2, 1.2, '#1976D2', false, true),
  ('d4400004-0000-0000-0000-000000000003'::uuid, 'c3300001-0000-0000-0000-000000000004', 'a1111111-0000-0000-0000-000000000004', 'elite',   'Elite',     3, 1.5, '#FFD700', false, true),
  ('d4400004-0000-0000-0000-000000000004'::uuid, 'c3300001-0000-0000-0000-000000000004', 'a1111111-0000-0000-0000-000000000004', 'executive','Executive',4, 1.8, '#0A0A0A', false, true);

-- Coastal Circle: 2 tiers (single-property, simple)
INSERT INTO tiers (id, program_id, chain_group_id, code, name, sort_order, multiplier_default, color_hex, is_default_initial, is_active) VALUES
  ('d4400005-0000-0000-0000-000000000001'::uuid, 'c3300001-0000-0000-0000-000000000005', 'a1111111-0000-0000-0000-000000000005', 'circle',  'Circle',    1, 1.0, '#7C3F00', true,  true),
  ('d4400005-0000-0000-0000-000000000002'::uuid, 'c3300001-0000-0000-0000-000000000005', 'a1111111-0000-0000-0000-000000000005', 'inner-circle','Inner Circle', 2, 1.5, '#3D1F00', false, true);

-- ===== Tier thresholds (points-based primary, nights-based secondary for First Member) =====
-- First Member: points-based with 5/15/40/100k cumulative for Silver/Gold/Platinum/Black
INSERT INTO tier_thresholds (tier_id, metric, min_value, qualifying_period_months) VALUES
  ('d4400001-0000-0000-0000-000000000002', 'points', 5000,   12),
  ('d4400001-0000-0000-0000-000000000003', 'points', 15000,  12),
  ('d4400001-0000-0000-0000-000000000004', 'points', 40000,  12),
  ('d4400001-0000-0000-0000-000000000005', 'points', 100000, 12),
  ('d4400001-0000-0000-0000-000000000003', 'nights', 20,     12),
  ('d4400001-0000-0000-0000-000000000004', 'nights', 50,     12);

-- Quality Club
INSERT INTO tier_thresholds (tier_id, metric, min_value, qualifying_period_months) VALUES
  ('d4400002-0000-0000-0000-000000000002', 'points', 4000,   12),
  ('d4400002-0000-0000-0000-000000000003', 'points', 12000,  12),
  ('d4400002-0000-0000-0000-000000000004', 'points', 35000,  12),
  ('d4400002-0000-0000-0000-000000000004', 'nights', 40,     12);

-- Fjord Friends (in EUR)
INSERT INTO tier_thresholds (tier_id, metric, min_value, qualifying_period_months) VALUES
  ('d4400003-0000-0000-0000-000000000002', 'points', 600,   12),
  ('d4400003-0000-0000-0000-000000000003', 'points', 2000,  12),
  ('d4400003-0000-0000-0000-000000000004', 'points', 6000,  12);

-- Smart Rewards (in SEK; business stays heavier)
INSERT INTO tier_thresholds (tier_id, metric, min_value, qualifying_period_months) VALUES
  ('d4400004-0000-0000-0000-000000000002', 'points', 4000,   12),
  ('d4400004-0000-0000-0000-000000000003', 'points', 12000,  12),
  ('d4400004-0000-0000-0000-000000000004', 'points', 30000,  12),
  ('d4400004-0000-0000-0000-000000000004', 'nights', 60,     12);

-- Coastal Circle
INSERT INTO tier_thresholds (tier_id, metric, min_value, qualifying_period_months) VALUES
  ('d4400005-0000-0000-0000-000000000002', 'revenue', 30000, 12);

-- ===== Tier benefits =====
INSERT INTO tier_benefits (tier_id, benefit_key, label, description, value, sort_order) VALUES
  ('d4400001-0000-0000-0000-000000000001', 'free_wifi',         'Free Wi-Fi',                'Complimentary high-speed Wi-Fi', '{}'::jsonb, 1),
  ('d4400001-0000-0000-0000-000000000002', 'late_checkout',     'Late checkout to 14:00',    'Subject to availability',         '{"hours":2}'::jsonb, 2),
  ('d4400001-0000-0000-0000-000000000002', 'welcome_drink',     'Welcome drink',             NULL, '{}'::jsonb, 3),
  ('d4400001-0000-0000-0000-000000000003', 'late_checkout_15',  'Late checkout to 15:00',    NULL, '{"hours":3}'::jsonb, 1),
  ('d4400001-0000-0000-0000-000000000003', 'room_upgrade',      'Room upgrade when available', NULL, '{}'::jsonb, 2),
  ('d4400001-0000-0000-0000-000000000003', 'priority_checkin',  'Priority check-in',         NULL, '{}'::jsonb, 3),
  ('d4400001-0000-0000-0000-000000000004', 'exec_lounge',       'Executive lounge access',   NULL, '{}'::jsonb, 1),
  ('d4400001-0000-0000-0000-000000000004', 'breakfast_included','Breakfast included',        NULL, '{}'::jsonb, 2),
  ('d4400001-0000-0000-0000-000000000005', 'concierge',         'Personal concierge',         NULL, '{}'::jsonb, 1),
  ('d4400001-0000-0000-0000-000000000005', 'gift_card_annual',  'Annual NOK 2 000 gift card', NULL, '{"amount":2000,"currency":"NOK"}'::jsonb, 2);

-- Quality Club benefits
INSERT INTO tier_benefits (tier_id, benefit_key, label, description, value, sort_order) VALUES
  ('d4400002-0000-0000-0000-000000000002', 'free_wifi',     'Free Wi-Fi',  NULL, '{}'::jsonb, 1),
  ('d4400002-0000-0000-0000-000000000002', 'late_checkout', 'Late checkout to 13:00', NULL, '{"hours":1}'::jsonb, 2),
  ('d4400002-0000-0000-0000-000000000003', 'breakfast_discount', '50% off breakfast', NULL, '{"discount_pct":50}'::jsonb, 1),
  ('d4400002-0000-0000-0000-000000000004', 'free_breakfast', 'Free breakfast', NULL, '{}'::jsonb, 1),
  ('d4400002-0000-0000-0000-000000000004', 'room_upgrade', 'Room upgrade when available', NULL, '{}'::jsonb, 2);

-- Fjord Friends benefits
INSERT INTO tier_benefits (tier_id, benefit_key, label, description, value, sort_order) VALUES
  ('d4400003-0000-0000-0000-000000000002', 'welcome_pastries', 'Welcome pastries', NULL, '{}'::jsonb, 1),
  ('d4400003-0000-0000-0000-000000000003', 'guided_walk', 'Free guided walk', NULL, '{}'::jsonb, 1),
  ('d4400003-0000-0000-0000-000000000004', 'private_dining_credit', 'Private dining credit', NULL, '{"amount":150,"currency":"EUR"}'::jsonb, 1);

-- Smart Rewards benefits
INSERT INTO tier_benefits (tier_id, benefit_key, label, description, value, sort_order) VALUES
  ('d4400004-0000-0000-0000-000000000002', 'workspace_access', 'Workspace access', NULL, '{}'::jsonb, 1),
  ('d4400004-0000-0000-0000-000000000003', 'late_checkout', 'Late checkout to 14:00', NULL, '{"hours":2}'::jsonb, 1),
  ('d4400004-0000-0000-0000-000000000004', 'meeting_room_credit', 'Annual meeting room credit', NULL, '{"hours":10}'::jsonb, 1);

-- ===== Points rules =====
-- Pattern per chain: per-tier percent for direct, plus a chain-wide OTA exclusion (percent=0).
-- First Member: 2/5/10/15% Bronze→Platinum, 18% Black; OTA 0%.
INSERT INTO points_rules (program_id, chain_group_id, hotel_id, channel, percent_of_payment, tier_multiplier_override, priority, description) VALUES
  ('c3300001-0000-0000-0000-000000000001','a1111111-0000-0000-0000-000000000001', NULL, 'direct',     5.0,
   '{"bronze":0.4, "silver":1.0, "gold":2.0, "platinum":3.0, "black":3.6}'::jsonb, 100, 'Direct booking earn (per-tier multiplier yields 2/5/10/15/18%)'),
  ('c3300001-0000-0000-0000-000000000001','a1111111-0000-0000-0000-000000000001', NULL, 'corporate',  3.0,
   '{"bronze":1.0, "silver":1.2, "gold":1.5, "platinum":1.8, "black":2.0}'::jsonb, 100, 'Corporate negotiated rate'),
  ('c3300001-0000-0000-0000-000000000001','a1111111-0000-0000-0000-000000000001', NULL, 'ota',        0.0,
   NULL, 200, 'OTA bookings excluded from earning (default)'),
  ('c3300001-0000-0000-0000-000000000001','a1111111-0000-0000-0000-000000000001', NULL, 'group',      1.0,
   NULL, 100, 'Group bookings flat 1%');

-- Quality Club: 3/5/8/12% direct
INSERT INTO points_rules (program_id, chain_group_id, hotel_id, channel, percent_of_payment, tier_multiplier_override, priority, description) VALUES
  ('c3300001-0000-0000-0000-000000000002','a1111111-0000-0000-0000-000000000002', NULL, 'direct',    8.0,
   '{"bronze":0.375,"silver":0.625,"gold":1.0,"platinum":1.5}'::jsonb, 100, 'Direct earn (3/5/8/12%)'),
  ('c3300001-0000-0000-0000-000000000002','a1111111-0000-0000-0000-000000000002', NULL, 'corporate', 5.0, NULL, 100, 'Corporate flat 5%'),
  ('c3300001-0000-0000-0000-000000000002','a1111111-0000-0000-0000-000000000002', NULL, 'ota',       0.0, NULL, 200, 'OTA excluded');

-- Fjord Friends: 5/8/12/15% direct
INSERT INTO points_rules (program_id, chain_group_id, hotel_id, channel, percent_of_payment, tier_multiplier_override, priority, description) VALUES
  ('c3300001-0000-0000-0000-000000000003','a1111111-0000-0000-0000-000000000003', NULL, 'direct',    12.0,
   '{"explorer":0.417,"voyager":0.667,"aurora":1.0,"midnight":1.25}'::jsonb, 100, 'Direct earn (5/8/12/15%)'),
  ('c3300001-0000-0000-0000-000000000003','a1111111-0000-0000-0000-000000000003', NULL, 'ota',       0.0, NULL, 200, 'OTA excluded');

-- Smart Rewards: 2/4/6/10% direct
INSERT INTO points_rules (program_id, chain_group_id, hotel_id, channel, percent_of_payment, tier_multiplier_override, priority, description) VALUES
  ('c3300001-0000-0000-0000-000000000004','a1111111-0000-0000-0000-000000000004', NULL, 'direct',    6.0,
   '{"standard":0.333,"frequent":0.667,"elite":1.0,"executive":1.667}'::jsonb, 100, 'Direct earn (2/4/6/10%)'),
  ('c3300001-0000-0000-0000-000000000004','a1111111-0000-0000-0000-000000000004', NULL, 'corporate', 4.0,
   '{"standard":1.0,"frequent":1.25,"elite":1.5,"executive":2.0}'::jsonb, 100, 'Corporate'),
  ('c3300001-0000-0000-0000-000000000004','a1111111-0000-0000-0000-000000000004', NULL, 'ota',       0.0, NULL, 200, 'OTA excluded');

-- Coastal Circle: 5/10% direct
INSERT INTO points_rules (program_id, chain_group_id, hotel_id, channel, percent_of_payment, tier_multiplier_override, priority, description) VALUES
  ('c3300001-0000-0000-0000-000000000005','a1111111-0000-0000-0000-000000000005', NULL, 'direct',    10.0,
   '{"circle":0.5,"inner-circle":1.0}'::jsonb, 100, 'Direct earn (5/10%)'),
  ('c3300001-0000-0000-0000-000000000005','a1111111-0000-0000-0000-000000000005', NULL, 'ota',       0.0, NULL, 200, 'OTA excluded');

-- ===== Rewards =====
-- A handful per chain, varied types
INSERT INTO rewards (program_id, chain_group_id, code, name, description, reward_type, cost_points, min_tier_id, hotel_id, valid_from, valid_to, is_active) VALUES
  ('c3300001-0000-0000-0000-000000000001','a1111111-0000-0000-0000-000000000001','fm-free-night-norden', 'Free night across Norden', 'One free standard night at any First Member hotel', 'free_night', 12000, NULL, NULL, '2024-01-01','2027-12-31',true),
  ('c3300001-0000-0000-0000-000000000001','a1111111-0000-0000-0000-000000000001','fm-late-checkout',     'Guaranteed late checkout 16:00', NULL, 'late_checkout', 800, 'd4400001-0000-0000-0000-000000000002', NULL, NULL, NULL, true),
  ('c3300001-0000-0000-0000-000000000001','a1111111-0000-0000-0000-000000000001','fm-room-upgrade',      'Room upgrade voucher', NULL, 'room_upgrade', 3500, 'd4400001-0000-0000-0000-000000000003', NULL, NULL, NULL, true),
  ('c3300001-0000-0000-0000-000000000001','a1111111-0000-0000-0000-000000000001','fm-restaurant-500',    'NOK 500 restaurant credit', NULL, 'gift_card', 5000, NULL, NULL, NULL, NULL, true),
  ('c3300001-0000-0000-0000-000000000001','a1111111-0000-0000-0000-000000000001','fm-spa-experience',    'Spa experience for two', 'Two-hour spa treatment for two guests', 'experience', 9000, 'd4400001-0000-0000-0000-000000000003', NULL, NULL, NULL, true),
  ('c3300001-0000-0000-0000-000000000002','a1111111-0000-0000-0000-000000000002','qc-free-night',        'Free Quality night',  NULL, 'free_night',  9000, NULL, NULL, NULL, NULL, true),
  ('c3300001-0000-0000-0000-000000000002','a1111111-0000-0000-0000-000000000002','qc-breakfast',         'Free breakfast voucher', NULL, 'amenity', 600, NULL, NULL, NULL, NULL, true),
  ('c3300001-0000-0000-0000-000000000002','a1111111-0000-0000-0000-000000000002','qc-restaurant-300',    'NOK 300 restaurant credit', NULL, 'gift_card', 3000, NULL, NULL, NULL, NULL, true),
  ('c3300001-0000-0000-0000-000000000003','a1111111-0000-0000-0000-000000000003','ff-aurora-experience', 'Northern lights guided experience', NULL, 'experience', 1500, NULL, NULL, NULL, NULL, true),
  ('c3300001-0000-0000-0000-000000000003','a1111111-0000-0000-0000-000000000003','ff-tasting-menu',      'Chef''s tasting menu',    NULL, 'experience', 800, NULL, NULL, NULL, NULL, true),
  ('c3300001-0000-0000-0000-000000000003','a1111111-0000-0000-0000-000000000003','ff-free-night',        'Free Fjord night',     NULL, 'free_night', 1200, NULL, NULL, NULL, NULL, true),
  ('c3300001-0000-0000-0000-000000000004','a1111111-0000-0000-0000-000000000004','sr-meeting-room-2h',   '2-hour meeting room voucher', NULL, 'amenity', 1500, NULL, NULL, NULL, NULL, true),
  ('c3300001-0000-0000-0000-000000000004','a1111111-0000-0000-0000-000000000004','sr-free-night',        'Free Smart night', NULL, 'free_night', 8000, NULL, NULL, NULL, NULL, true),
  ('c3300001-0000-0000-0000-000000000004','a1111111-0000-0000-0000-000000000004','sr-airport-transfer',  'Airport transfer voucher', NULL, 'amenity', 1200, NULL, NULL, NULL, NULL, true),
  ('c3300001-0000-0000-0000-000000000005','a1111111-0000-0000-0000-000000000005','cc-tasting-night',     'Chef''s tasting evening', NULL, 'experience', 4000, NULL, NULL, NULL, NULL, true),
  ('c3300001-0000-0000-0000-000000000005','a1111111-0000-0000-0000-000000000005','cc-suite-upgrade',     'Suite upgrade voucher',  NULL, 'room_upgrade', 6000, NULL, NULL, NULL, NULL, true);

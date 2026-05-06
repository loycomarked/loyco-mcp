-- 04_member_ancillary.sql
-- recruitment_hotel_id backfill, member_external_ids (normalized from JSON), consents,
-- initial tier_history (and a wave of promotion-triggered transitions), member_attributes (vip flags).

SELECT setseed(0.43);

WITH hotels_per_chain AS (
  SELECT chain_group_id, array_agg(id ORDER BY id) AS hotel_ids, count(*)::int AS n FROM hotels GROUP BY chain_group_id
)
UPDATE members m
SET recruitment_hotel_id = h.hotel_ids[1 + (((extract(epoch from m.created_at)::bigint) + length(m.email)) % h.n)]
FROM hotels_per_chain h
WHERE h.chain_group_id = m.chain_group_id;

INSERT INTO member_external_ids (member_id, id_type, id_value, is_valid, valid_from, metadata)
SELECT
  m.id,
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
SELECT
  m.id, 'sj_prio_id'::external_id_type,
  '975' || lpad(((extract(epoch from m.created_at)::bigint) % 9999999999)::text, 13, '0'),
  true, m.joined_at, '{"source":"seed_secondary"}'::jsonb
FROM members m
WHERE m.external_membership_raw IS NOT NULL AND random() < 0.7
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
FROM members m
WHERE m.current_tier_id IS NOT NULL;

WITH promotable AS (
  SELECT m.id, m.joined_at, m.current_tier_id AS new_tier_id, t.program_id,
    (SELECT t2.id FROM tiers t2 WHERE t2.program_id = t.program_id AND t2.sort_order = t.sort_order - 1) AS prev_tier_id
  FROM members m
  JOIN tiers t ON t.id = m.current_tier_id
  WHERE t.sort_order > 1 AND random() < 0.40
)
INSERT INTO member_tier_history (member_id, from_tier_id, to_tier_id, change_reason, effective_at, context)
SELECT
  p.id, p.prev_tier_id, p.new_tier_id,
  (ARRAY['qualified_by_points','qualified_by_nights','qualified_by_revenue']::tier_change_reason[])[1 + floor(random()*3)::int],
  p.joined_at + (60 + (random() * 540)::int) * interval '1 day',
  jsonb_build_object('counted_points', (4000 + random()*60000)::int, 'window_months', 12)
FROM promotable p
WHERE p.prev_tier_id IS NOT NULL;

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

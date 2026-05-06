-- 0016_views.sql
-- Reporting / analytics views (per ROADMAP) + db_dictionary_view for AI/MCP introspection.
-- All views convert revenue to the chain's reporting_currency via lc_to_currency().

-- ===== member_360_view =====
-- One row per member with rollups for adminportal "member detail" + Engage segmentation.

CREATE OR REPLACE VIEW member_360_view AS
SELECT
  m.id                                    AS member_id,
  m.chain_group_id,
  cg.name                                 AS chain_name,
  m.program_id,
  m.member_number,
  m.full_name,
  m.email,
  m.phone_e164,
  m.country_code,
  m.status,
  m.gender,
  m.birth_date,
  m.joined_at,
  m.recruitment_source,
  m.recruited_via_ota,
  m.current_tier_id,
  t.code                                  AS tier_code,
  t.name                                  AS tier_name,
  t.sort_order                            AS tier_sort_order,
  COALESCE(pb.balance_posted, 0)          AS points_balance,
  COALESCE(pb.balance_pending, 0)         AS points_pending,
  COALESCE(pb.expiring_30d, 0)            AS points_expiring_30d,
  pb.last_activity_at                     AS points_last_activity_at,
  bk.bookings_total,
  bk.bookings_completed,
  bk.bookings_cancelled,
  bk.bookings_upcoming,
  bk.first_booking_at,
  bk.last_booking_at,
  bk.next_booking_at,
  bk.nights_total,
  COALESCE(rev.revenue_lifetime_reporting_ccy, 0)  AS revenue_lifetime_reporting,
  cg.reporting_currency                   AS reporting_currency,
  CASE
    WHEN bk.last_booking_at IS NULL THEN true
    WHEN bk.last_booking_at < (now() - interval '12 months')
         AND COALESCE(pb.last_activity_at, '1970-01-01'::timestamptz) < (now() - interval '12 months')
      THEN true
    ELSE false
  END                                     AS is_churned
FROM members m
LEFT JOIN chain_groups cg ON cg.id = m.chain_group_id
LEFT JOIN tiers t        ON t.id = m.current_tier_id
LEFT JOIN points_balances_mv pb ON pb.member_id = m.id
LEFT JOIN LATERAL (
  SELECT
    count(*)                                                    AS bookings_total,
    count(*) FILTER (WHERE status = 'checked_out')              AS bookings_completed,
    count(*) FILTER (WHERE status = 'cancelled')                AS bookings_cancelled,
    count(*) FILTER (WHERE status IN ('upcoming','in_house'))   AS bookings_upcoming,
    min(arrival_date)                                            AS first_booking_at,
    max(arrival_date) FILTER (WHERE status IN ('checked_out','in_house','cancelled','no_show')) AS last_booking_at,
    min(arrival_date) FILTER (WHERE status = 'upcoming' AND arrival_date >= current_date)        AS next_booking_at,
    COALESCE(SUM(nights) FILTER (WHERE status = 'checked_out'), 0) AS nights_total
  FROM bookings b
  WHERE b.member_id = m.id
) bk ON true
LEFT JOIN LATERAL (
  SELECT SUM(lc_to_currency(tx.posted_amount, tx.posted_currency, cg.reporting_currency, tx.posting_date))
         AS revenue_lifetime_reporting_ccy
  FROM transactions tx
  WHERE tx.member_id = m.id
    AND tx.status = 'posted'
    AND tx.transaction_type IN ('charge','adjustment')
) rev ON true;

-- ===== tier_distribution_view =====
CREATE OR REPLACE VIEW tier_distribution_view AS
SELECT
  m.chain_group_id,
  cg.name AS chain_name,
  t.id    AS tier_id,
  t.code  AS tier_code,
  t.name  AS tier_name,
  t.sort_order,
  count(*)                                                      AS member_count,
  count(*) FILTER (WHERE m.status = 'active')                   AS active_member_count,
  round(100.0 * count(*) FILTER (WHERE m.status = 'active')
        / NULLIF(SUM(count(*) FILTER (WHERE m.status = 'active'))
                 OVER (PARTITION BY m.chain_group_id), 0), 2)   AS active_pct
FROM members m
JOIN chain_groups cg ON cg.id = m.chain_group_id
LEFT JOIN tiers t ON t.id = m.current_tier_id
GROUP BY m.chain_group_id, cg.name, t.id, t.code, t.name, t.sort_order;

-- ===== direct_booking_share_view =====
CREATE OR REPLACE VIEW direct_booking_share_view AS
SELECT
  b.chain_group_id,
  cg.name AS chain_name,
  date_trunc('month', b.arrival_date)::date AS month,
  count(*) FILTER (WHERE b.channel = 'direct')                              AS direct_count,
  count(*) FILTER (WHERE b.channel = 'ota')                                 AS ota_count,
  count(*) FILTER (WHERE b.channel = 'corporate')                           AS corporate_count,
  count(*)                                                                  AS total_bookings,
  round(100.0 * count(*) FILTER (WHERE b.channel = 'direct') / NULLIF(count(*), 0), 2) AS direct_share_pct,
  round(100.0 * count(*) FILTER (WHERE b.channel = 'ota')    / NULLIF(count(*), 0), 2) AS ota_share_pct
FROM bookings b
JOIN chain_groups cg ON cg.id = b.chain_group_id
WHERE b.status <> 'cancelled'
GROUP BY b.chain_group_id, cg.name, month;

-- ===== revenue_per_member_view =====
CREATE OR REPLACE VIEW revenue_per_member_view AS
SELECT
  tx.chain_group_id,
  cg.name AS chain_name,
  date_trunc('month', tx.posting_date)::date AS month,
  cg.reporting_currency AS reporting_currency,
  SUM(lc_to_currency(tx.posted_amount, tx.posted_currency, cg.reporting_currency, tx.posting_date)) AS revenue_total_reporting,
  count(DISTINCT tx.member_id) FILTER (WHERE tx.member_id IS NOT NULL) AS active_member_count,
  CASE
    WHEN count(DISTINCT tx.member_id) FILTER (WHERE tx.member_id IS NOT NULL) > 0
    THEN ROUND(
      SUM(lc_to_currency(tx.posted_amount, tx.posted_currency, cg.reporting_currency, tx.posting_date))::numeric
      / count(DISTINCT tx.member_id) FILTER (WHERE tx.member_id IS NOT NULL), 2)
    ELSE NULL
  END AS revenue_per_active_member
FROM transactions tx
JOIN chain_groups cg ON cg.id = tx.chain_group_id
WHERE tx.status = 'posted'
GROUP BY tx.chain_group_id, cg.name, month, cg.reporting_currency;

-- ===== member_growth_view =====
CREATE OR REPLACE VIEW member_growth_view AS
WITH monthly AS (
  SELECT
    m.chain_group_id,
    cg.name AS chain_name,
    date_trunc('month', m.joined_at)::date AS month,
    count(*) AS new_members
  FROM members m
  JOIN chain_groups cg ON cg.id = m.chain_group_id
  GROUP BY m.chain_group_id, cg.name, date_trunc('month', m.joined_at)::date
)
SELECT
  chain_group_id,
  chain_name,
  month,
  new_members,
  SUM(new_members) OVER (PARTITION BY chain_group_id ORDER BY month) AS cumulative_members
FROM monthly;

-- ===== churn_view =====
CREATE OR REPLACE VIEW churn_view AS
SELECT
  m.chain_group_id,
  cg.name AS chain_name,
  count(*) AS members_total,
  count(*) FILTER (WHERE
       (last_b.last_booking_at IS NULL OR last_b.last_booking_at < (now() - interval '12 months'))
   AND (pb.last_activity_at  IS NULL OR pb.last_activity_at  < (now() - interval '12 months'))
  ) AS members_churned,
  round(
    100.0 * count(*) FILTER (WHERE
       (last_b.last_booking_at IS NULL OR last_b.last_booking_at < (now() - interval '12 months'))
   AND (pb.last_activity_at  IS NULL OR pb.last_activity_at  < (now() - interval '12 months'))
    )::numeric / NULLIF(count(*), 0), 2) AS churn_pct
FROM members m
JOIN chain_groups cg ON cg.id = m.chain_group_id
LEFT JOIN points_balances_mv pb ON pb.member_id = m.id
LEFT JOIN LATERAL (
  SELECT max(arrival_date)::timestamptz AS last_booking_at
  FROM bookings b
  WHERE b.member_id = m.id AND b.status IN ('checked_out','in_house')
) last_b ON true
GROUP BY m.chain_group_id, cg.name;

-- ===== clv_view =====
-- Customer lifetime value (gross revenue + points-redeemed-equivalent) in reporting currency.
CREATE OR REPLACE VIEW clv_view AS
SELECT
  m.id AS member_id,
  m.chain_group_id,
  cg.name AS chain_name,
  m.full_name,
  cg.reporting_currency,
  COALESCE(rev.gross_revenue, 0)         AS gross_revenue,
  COALESCE(red.redemption_value, 0)      AS redemption_value,
  COALESCE(rev.gross_revenue, 0) - COALESCE(red.redemption_value, 0) AS net_value,
  COALESCE(bk.bookings_completed, 0)     AS bookings_completed,
  COALESCE(bk.nights_total, 0)           AS nights_total,
  bk.first_booking_at,
  bk.last_booking_at
FROM members m
JOIN chain_groups cg ON cg.id = m.chain_group_id
LEFT JOIN LATERAL (
  SELECT SUM(lc_to_currency(tx.posted_amount, tx.posted_currency, cg.reporting_currency, tx.posting_date)) AS gross_revenue
  FROM transactions tx
  WHERE tx.member_id = m.id AND tx.status = 'posted' AND tx.transaction_type = 'charge'
) rev ON true
LEFT JOIN LATERAL (
  SELECT SUM(pr.points_spent) AS redemption_value     -- 1 point = 1 reporting currency unit by ADR-0006
  FROM point_redemptions pr
  WHERE pr.member_id = m.id AND pr.status = 'fulfilled'
) red ON true
LEFT JOIN LATERAL (
  SELECT count(*) FILTER (WHERE status = 'checked_out') AS bookings_completed,
         SUM(nights) FILTER (WHERE status = 'checked_out') AS nights_total,
         min(arrival_date) AS first_booking_at,
         max(arrival_date) AS last_booking_at
  FROM bookings b
  WHERE b.member_id = m.id
) bk ON true;

-- ===== campaign_performance_view =====
CREATE OR REPLACE VIEW campaign_performance_view AS
SELECT
  c.id                  AS campaign_id,
  c.chain_group_id,
  cg.name               AS chain_name,
  c.name                AS campaign_name,
  c.channel,
  c.status,
  c.start_date,
  c.end_date,
  c.recipient_count,
  count(cr.id)                                                  AS recipients_actual,
  count(*) FILTER (WHERE cr.status IN ('delivered','opened','clicked')) AS delivered,
  count(*) FILTER (WHERE cr.opened_at IS NOT NULL)              AS opened,
  count(*) FILTER (WHERE cr.clicked_at IS NOT NULL)             AS clicked,
  count(*) FILTER (WHERE cr.bounced_at IS NOT NULL)             AS bounced,
  count(*) FILTER (WHERE cr.attributed_booking_id IS NOT NULL)  AS attributed_bookings,
  COALESCE(SUM(lc_to_currency(cr.attributed_revenue, cr.attributed_currency, cg.reporting_currency, c.start_date)), 0) AS attributed_revenue_reporting,
  cg.reporting_currency
FROM campaigns c
JOIN chain_groups cg ON cg.id = c.chain_group_id
LEFT JOIN campaign_recipients cr ON cr.campaign_id = c.id
GROUP BY c.id, cg.name, cg.reporting_currency;

-- ===== chain_overview_view =====
CREATE OR REPLACE VIEW chain_overview_view AS
SELECT
  cg.id                              AS chain_group_id,
  cg.name                            AS chain_name,
  cg.status,
  cg.reporting_currency,
  (SELECT count(*) FROM hotels h WHERE h.chain_group_id = cg.id AND h.status = 'active')   AS active_hotels,
  (SELECT count(*) FROM members m WHERE m.chain_group_id = cg.id AND m.status = 'active')  AS active_members,
  (SELECT count(*) FROM bookings b
     WHERE b.chain_group_id = cg.id
       AND b.arrival_date >= (current_date - interval '365 days')
       AND b.status <> 'cancelled')                                                          AS bookings_last_365d,
  (SELECT count(*) FROM bookings b
     WHERE b.chain_group_id = cg.id
       AND b.arrival_date >= current_date
       AND b.status IN ('upcoming','in_house'))                                              AS bookings_upcoming,
  (SELECT COALESCE(SUM(lc_to_currency(tx.posted_amount, tx.posted_currency, cg.reporting_currency, tx.posting_date)), 0)
     FROM transactions tx
    WHERE tx.chain_group_id = cg.id
      AND tx.posting_date >= (current_date - interval '365 days')
      AND tx.status = 'posted')                                                              AS revenue_last_365d_reporting,
  (SELECT round(100.0 * count(*) FILTER (WHERE channel = 'direct') / NULLIF(count(*), 0), 2)
     FROM bookings WHERE chain_group_id = cg.id
       AND arrival_date >= (current_date - interval '365 days')
       AND status <> 'cancelled')                                                            AS direct_share_pct_last_365d
FROM chain_groups cg;

-- ===== hotel_comparison_view =====
CREATE OR REPLACE VIEW hotel_comparison_view AS
SELECT
  h.id                AS hotel_id,
  h.chain_group_id,
  cg.name             AS chain_name,
  h.name              AS hotel_name,
  h.country_code,
  h.room_count,
  cg.reporting_currency,
  count(b.id) FILTER (WHERE b.status = 'checked_out' AND b.arrival_date >= current_date - interval '365 days') AS bookings_completed_365d,
  COALESCE(SUM(b.nights) FILTER (WHERE b.status = 'checked_out' AND b.arrival_date >= current_date - interval '365 days'), 0) AS nights_365d,
  COALESCE(
    SUM(lc_to_currency(tx.posted_amount, tx.posted_currency, cg.reporting_currency, tx.posting_date))
      FILTER (WHERE tx.status='posted' AND tx.posting_date >= current_date - interval '365 days'),
    0
  ) AS revenue_365d_reporting,
  round(100.0 * count(*) FILTER (WHERE b.channel = 'direct' AND b.status <> 'cancelled' AND b.arrival_date >= current_date - interval '365 days')
              / NULLIF(count(*) FILTER (WHERE b.status <> 'cancelled' AND b.arrival_date >= current_date - interval '365 days'), 0), 2) AS direct_share_pct_365d,
  count(*) FILTER (WHERE b.is_member_booking AND b.status <> 'cancelled' AND b.arrival_date >= current_date - interval '365 days') AS member_bookings_365d
FROM hotels h
JOIN chain_groups cg ON cg.id = h.chain_group_id
LEFT JOIN bookings b ON b.hotel_id = h.id
LEFT JOIN transactions tx ON tx.hotel_id = h.id
GROUP BY h.id, cg.name, cg.reporting_currency;

-- ===== db_dictionary_view =====
-- Self-describing schema for AI/MCP servers. One row per column.
CREATE OR REPLACE VIEW db_dictionary_view AS
SELECT
  c.table_schema,
  c.table_name,
  obj_description(format('%I.%I', c.table_schema, c.table_name)::regclass, 'pg_class') AS table_description,
  c.ordinal_position,
  c.column_name,
  c.data_type,
  c.udt_name,
  c.is_nullable,
  c.column_default,
  col_description(format('%I.%I', c.table_schema, c.table_name)::regclass, c.ordinal_position) AS column_description,
  CASE WHEN pk.column_name IS NOT NULL THEN true ELSE false END AS is_primary_key,
  fk.foreign_table,
  fk.foreign_column
FROM information_schema.columns c
LEFT JOIN (
  SELECT kcu.table_schema, kcu.table_name, kcu.column_name
  FROM information_schema.table_constraints tc
  JOIN information_schema.key_column_usage kcu
    ON kcu.constraint_name = tc.constraint_name
   AND kcu.table_schema = tc.table_schema
  WHERE tc.constraint_type = 'PRIMARY KEY'
) pk
  ON pk.table_schema = c.table_schema
 AND pk.table_name   = c.table_name
 AND pk.column_name  = c.column_name
LEFT JOIN (
  SELECT
    kcu.table_schema, kcu.table_name, kcu.column_name,
    ccu.table_name  AS foreign_table,
    ccu.column_name AS foreign_column
  FROM information_schema.table_constraints tc
  JOIN information_schema.key_column_usage kcu
    ON kcu.constraint_name = tc.constraint_name
   AND kcu.table_schema = tc.table_schema
  JOIN information_schema.constraint_column_usage ccu
    ON ccu.constraint_name = tc.constraint_name
   AND ccu.table_schema = tc.table_schema
  WHERE tc.constraint_type = 'FOREIGN KEY'
) fk
  ON fk.table_schema = c.table_schema
 AND fk.table_name   = c.table_name
 AND fk.column_name  = c.column_name
WHERE c.table_schema = 'public'
ORDER BY c.table_name, c.ordinal_position;

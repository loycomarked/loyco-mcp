-- scripts/verify.sql
-- End-of-phase sanity queries. Re-run after each major change.

\echo '=== Schema inventory ==='
SELECT
  (SELECT count(*) FROM pg_tables    WHERE schemaname='public')                                              AS tables,
  (SELECT count(*) FROM pg_views     WHERE schemaname='public')                                              AS views,
  (SELECT count(*) FROM pg_matviews  WHERE schemaname='public')                                              AS matviews,
  (SELECT count(*) FROM pg_type      WHERE typtype='e' AND typnamespace=(SELECT oid FROM pg_namespace WHERE nspname='public')) AS enums,
  (SELECT count(*) FROM pg_policies  WHERE schemaname='public')                                              AS policies,
  (SELECT count(*) FROM pg_indexes   WHERE schemaname='public')                                              AS indexes,
  (SELECT count(*) FROM pg_proc      WHERE pronamespace=(SELECT oid FROM pg_namespace WHERE nspname='public') AND proname LIKE 'lc_%') AS lc_helpers,
  (SELECT count(*) FROM pg_trigger   WHERE NOT tgisinternal AND tgrelid IN (SELECT oid FROM pg_class WHERE relnamespace=(SELECT oid FROM pg_namespace WHERE nspname='public'))) AS triggers;

\echo '=== Tables missing RLS (should be empty) ==='
SELECT schemaname, tablename
  FROM pg_tables
 WHERE schemaname = 'public'
   AND NOT EXISTS (
     SELECT 1 FROM pg_class c
       JOIN pg_namespace n ON n.oid = c.relnamespace
      WHERE n.nspname = pg_tables.schemaname
        AND c.relname = pg_tables.tablename
        AND c.relrowsecurity
   )
 ORDER BY tablename;

\echo '=== Reference catalogs (must be populated) ==='
SELECT 'currencies'  AS catalog, count(*) FROM currencies
UNION ALL
SELECT 'regions',     count(*) FROM regions
UNION ALL
SELECT 'pms_systems', count(*) FROM pms_systems;

\echo '=== Row counts per data table ==='
SELECT relname AS table_name, n_live_tup AS row_count
  FROM pg_stat_user_tables
 WHERE schemaname = 'public'
 ORDER BY relname;

\echo '=== Reporting views resolvable ==='
SELECT 'member_360_view',           count(*) FROM member_360_view
UNION ALL SELECT 'tier_distribution_view',    count(*) FROM tier_distribution_view
UNION ALL SELECT 'direct_booking_share_view', count(*) FROM direct_booking_share_view
UNION ALL SELECT 'revenue_per_member_view',   count(*) FROM revenue_per_member_view
UNION ALL SELECT 'member_growth_view',        count(*) FROM member_growth_view
UNION ALL SELECT 'churn_view',                count(*) FROM churn_view
UNION ALL SELECT 'clv_view',                  count(*) FROM clv_view
UNION ALL SELECT 'campaign_performance_view', count(*) FROM campaign_performance_view
UNION ALL SELECT 'chain_overview_view',       count(*) FROM chain_overview_view
UNION ALL SELECT 'hotel_comparison_view',     count(*) FROM hotel_comparison_view
UNION ALL SELECT 'db_dictionary_view',        count(*) FROM db_dictionary_view;

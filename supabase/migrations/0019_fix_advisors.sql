-- 0019_fix_advisors.sql
-- Address Supabase advisor lints from Fase 1 verification:
--   1) Views default to SECURITY DEFINER → set security_invoker=true so RLS applies as the querying user
--   2) Functions need explicit search_path to avoid hijacking
--   3) Materialized view is exposed via Data API → revoke from anon/authenticated

-- ===== 1) Make all reporting views security_invoker (so RLS applies) =====
ALTER VIEW member_360_view              SET (security_invoker = true);
ALTER VIEW tier_distribution_view       SET (security_invoker = true);
ALTER VIEW direct_booking_share_view    SET (security_invoker = true);
ALTER VIEW revenue_per_member_view      SET (security_invoker = true);
ALTER VIEW member_growth_view           SET (security_invoker = true);
ALTER VIEW churn_view                   SET (security_invoker = true);
ALTER VIEW clv_view                     SET (security_invoker = true);
ALTER VIEW campaign_performance_view    SET (security_invoker = true);
ALTER VIEW chain_overview_view          SET (security_invoker = true);
ALTER VIEW hotel_comparison_view        SET (security_invoker = true);
ALTER VIEW db_dictionary_view           SET (security_invoker = true);

-- ===== 2) Pin search_path on all lc_* functions =====
ALTER FUNCTION lc_jwt_claim(text)                  SET search_path = public, pg_catalog, extensions;
ALTER FUNCTION lc_current_role()                   SET search_path = public, pg_catalog, extensions;
ALTER FUNCTION lc_current_chain_id()               SET search_path = public, pg_catalog, extensions;
ALTER FUNCTION lc_current_hotel_ids()              SET search_path = public, pg_catalog, extensions;
ALTER FUNCTION lc_is_loyco_admin()                 SET search_path = public, pg_catalog, extensions;
ALTER FUNCTION lc_can_access_chain(uuid)           SET search_path = public, pg_catalog, extensions;
ALTER FUNCTION lc_can_access_hotel(uuid, uuid)     SET search_path = public, pg_catalog, extensions;
ALTER FUNCTION lc_to_currency(numeric, char, char, date) SET search_path = public, pg_catalog, extensions;
ALTER FUNCTION lc_touch_updated_at()               SET search_path = public, pg_catalog, extensions;
ALTER FUNCTION lc_audit_trigger()                  SET search_path = public, pg_catalog, extensions;
ALTER FUNCTION lc_audit_manual_points_only()       SET search_path = public, pg_catalog, extensions;
ALTER FUNCTION lc_members_tsv_update()             SET search_path = public, pg_catalog, extensions;

-- ===== 3) Hide points_balances_mv from Data API =====
-- Materialized views can't have RLS, so we revoke from anon/authenticated.
-- Server-side queries via service_role still work; views that reference it (member_360_view) work because they're owned by postgres.
REVOKE ALL ON points_balances_mv FROM anon, authenticated;

-- 0018_comments.sql
-- Semantic context for AI / MCP servers (ADR-0008).
-- All tables get a description; non-obvious columns get explanations.

-- ===== Tenancy / catalog =====
COMMENT ON TABLE currencies IS 'ISO 4217 currency catalogue (NOK, SEK, DKK, EUR, etc.).';
COMMENT ON TABLE regions IS 'ISO 3166-1 alpha-2 country/region catalogue with default currency mapping.';
COMMENT ON TABLE pms_systems IS 'Catalogue of supported Property Management Systems (StayNTouch, Mews, Protel Air, Visbook).';
COMMENT ON TABLE chain_groups IS 'Hotel chain (Loyco''s primary tenant). All chain-scoped tables RLS-restrict on chain_group_id.';
COMMENT ON COLUMN chain_groups.default_currency IS 'Currency used for the loyalty program by default. Members earn 1 point per 1 unit of this currency.';
COMMENT ON COLUMN chain_groups.reporting_currency IS 'Currency used in chain-level analytics and views.';
COMMENT ON TABLE hotels IS 'Individual hotel ("department" in PMS terminology). Belongs to a chain.';
COMMENT ON COLUMN hotels.brand_property_code IS 'External code at chain level (e.g., "FHR" for First Hotel Royal). Optional.';
COMMENT ON COLUMN hotels.timezone IS 'IANA timezone of the hotel — used to interpret PMS check-in/check-out timestamps.';
COMMENT ON TABLE hotel_pms_connections IS 'Binding between a hotel and the PMS that provides its data feed. Only one active connection per hotel.';
COMMENT ON COLUMN hotel_pms_connections.external_property_id IS 'The hotel''s identifier inside the PMS (e.g., StayNTouch Department ID).';
COMMENT ON TABLE currency_rates IS 'Daily FX rates. Used by lc_to_currency() helper for analytics conversions.';

-- ===== Loyalty config =====
COMMENT ON TABLE loyalty_programs IS 'A loyalty program belongs to a chain. 1:1 in MVP, schema allows 1:N.';
COMMENT ON COLUMN loyalty_programs.points_currency IS 'Currency for which 1 point = 1 unit (typically chain default_currency). FX is applied for foreign-currency stays.';
COMMENT ON COLUMN loyalty_programs.points_expiry_months IS 'Months after which earned points expire. NULL = no expiry.';
COMMENT ON TABLE tiers IS 'Configurable membership tiers (Bronze/Silver/Gold/Platinum or custom like Black). Per ADR-0006, fully customizable per chain.';
COMMENT ON COLUMN tiers.sort_order IS '1 = lowest tier, ascending.';
COMMENT ON COLUMN tiers.multiplier_default IS 'Default points multiplier for members on this tier. Overridable per points_rule via tier_multiplier_override.';
COMMENT ON COLUMN tiers.is_default_initial IS 'True for the tier a new member starts on. Exactly one per program.';
COMMENT ON TABLE tier_thresholds IS 'Qualification rules for entering a tier. Multiple metrics (points, nights, revenue) combinable.';
COMMENT ON COLUMN tier_thresholds.qualifying_period_months IS 'Rolling window over which the metric is summed (typically 12).';
COMMENT ON TABLE tier_benefits IS 'Machine-readable benefits granted by a tier (e.g., late_checkout, free_drink). Adminportal renders these.';
COMMENT ON TABLE points_rules IS 'Per-channel/segment/hotel earning rules. Resolution: most-specific match wins, ties broken by priority DESC.';
COMMENT ON COLUMN points_rules.percent_of_payment IS 'Percent of payment converted to points. Typical values: 2, 5, 10, 15. OTA rules typically 0.';
COMMENT ON COLUMN points_rules.tier_multiplier_override IS 'JSON map { tier_code: multiplier } overriding tiers.multiplier_default.';
COMMENT ON TABLE rewards IS 'Catalog of redeemable rewards (free night, upgrade, gift card, etc.).';

-- ===== Members =====
COMMENT ON TABLE members IS 'Loyalty program members. Scoped per chain (ADR-0009): same person can be a separate member at two chains.';
COMMENT ON COLUMN members.member_number IS 'Chain-issued display number; nullable for placeholders auto-created from anonymous OTA bookings.';
COMMENT ON COLUMN members.email IS 'Lowercased canonical email; unique per chain.';
COMMENT ON COLUMN members.phone_e164 IS 'E.164 international phone number; unique per chain.';
COMMENT ON COLUMN members.recruited_via_ota IS 'True if member signed up after an OTA booking (the conversion-from-OTA narrative).';
COMMENT ON COLUMN members.program_tag IS 'Legacy tag from PMS exports (e.g., "364Silver", "268plus"). Kept for migration fidelity.';
COMMENT ON COLUMN members.external_membership_raw IS 'Raw "External Membership" JSON array from PMS exports — preserved verbatim for re-parsing.';
COMMENT ON COLUMN members.searchable_tsv IS 'Auto-maintained tsvector covering name/email/phone/number/city for adminportal search.';
COMMENT ON TABLE member_external_ids IS 'Legacy / cross-system identifiers (FMOldId, SJprioId, etc.). Mirrors the JSON External Membership field per ADR-0010.';
COMMENT ON TABLE member_consents IS 'Append-only audit of consent grants (email, sms, offer, user_agreement). Latest row per (member, type) is current state.';
COMMENT ON TABLE member_tier_history IS 'State changes for member tier (upgrade/downgrade/manual). Driven by tier_thresholds evaluation or admin override.';
COMMENT ON TABLE member_attributes IS 'Open-ended key-value tags on members (segments, custom flags, computed labels).';

-- ===== Bookings =====
COMMENT ON TABLE bookings IS 'PMS reservation header. Normalized across StayNTouch, Mews, Protel Air, Visbook.';
COMMENT ON COLUMN bookings.channel IS 'High-level booking channel. OTA bookings typically excluded from points earning per default rules.';
COMMENT ON COLUMN bookings.pms_reservation_no IS 'Reservation number in the source PMS. Globally unique together with pms_code.';
COMMENT ON COLUMN bookings.is_member_booking IS 'True if attached to a member at booking time (vs. anonymous guest).';
COMMENT ON COLUMN bookings.returning_member IS 'True if the booker had a prior booking — used for retention analytics.';
COMMENT ON COLUMN bookings.nights IS 'Auto-computed from departure_date - arrival_date. Zero for day-use.';
COMMENT ON TABLE room_stays IS 'Per-room occupancy within a booking (for multi-room reservations).';
COMMENT ON TABLE booking_segments IS 'Rich PMS segment metadata (market segment, rate code, source, channel manager, travel agency). Used for granular reporting.';
COMMENT ON COLUMN booking_segments.market_segment_code IS 'Short PMS code, e.g., "CGN".';
COMMENT ON COLUMN booking_segments.rate_group_code IS 'Mews-style rate group like "OTA 48 timer", "NRF-WEB".';
COMMENT ON COLUMN booking_segments.business_segment IS 'Mews business_segment like "Rack rate", "Unqualified discount rate".';
COMMENT ON TABLE booking_status_history IS 'Status transition log (upcoming → in_house → checked_out / cancelled / no_show).';

-- ===== Transactions =====
COMMENT ON TABLE transactions IS 'Financial postings for bookings. Mirrors Loyco''s 44-column real PMS transactions export shape.';
COMMENT ON COLUMN transactions.posted_amount IS 'Amount in posted_currency (typically chain reporting currency or hotel currency).';
COMMENT ON COLUMN transactions.original_amount IS 'Amount in the currency the guest paid in. Converted via fx_rate to posted_currency.';
COMMENT ON COLUMN transactions.bonus_earned_amount IS 'Loyalty points earned at posting. Stored both here and in point_transactions ledger.';
COMMENT ON COLUMN transactions.bonus_released_amount IS 'Points moved from pending to posted-available status.';
COMMENT ON COLUMN transactions.is_ota IS 'True if booking arrived via an OTA channel manager. OTA transactions typically earn 0 points.';
COMMENT ON COLUMN transactions.mc_kickback_amount IS 'Mastercard cashback amount, if applicable. Out of scope for prototype but preserved.';
COMMENT ON TABLE transaction_lines IS 'Line items inside a transaction (room nights, F&B, spa, etc.). Mirrors PMS order_lines JSON.';
COMMENT ON COLUMN transaction_lines.product_type IS 'Loyco product taxonomy: Merchandise, Accommodation, Food, Beverage, Spa, etc.';
COMMENT ON COLUMN transaction_lines.bonus_factor IS 'Per-line points multiplier. Typically 1.0; lower for excluded products.';

-- ===== Points =====
COMMENT ON TABLE point_transactions IS 'Points ledger — single source of truth for member balances. positive = credit, negative = debit.';
COMMENT ON COLUMN point_transactions.type IS 'earn_pending | earn_release | redeem | manual_adjustment | expire | reverse.';
COMMENT ON COLUMN point_transactions.applied_percent IS 'The percent_of_payment from the matched points_rule, captured for traceability.';
COMMENT ON COLUMN point_transactions.applied_multiplier IS 'The tier multiplier applied when this earn was computed.';
COMMENT ON COLUMN point_transactions.expires_at IS 'When these points expire (if program has expiry). NULL otherwise.';
COMMENT ON TABLE point_redemptions IS 'Reward redemption record. Linked to a point_transactions row of type=redeem for the debit.';
COMMENT ON MATERIALIZED VIEW points_balances_mv IS 'Refresh-able balance snapshot per member: posted, pending, expiring within 30 days. Refresh nightly.';

-- ===== Communications & marketing =====
COMMENT ON TABLE communication_templates IS 'Reusable SMS/email/push templates per chain.';
COMMENT ON TABLE communications IS 'Unified outbound + inbound message log across all channels.';
COMMENT ON COLUMN communications.category IS 'personal_invitation | transactional | marketing_campaign | automation | service.';
COMMENT ON COLUMN communications.sms_logical_count IS 'Logical SMS count (1 message per logical send) — for analytics.';
COMMENT ON COLUMN communications.sms_real_count IS 'Real (billable) SMS segments after concatenation.';
COMMENT ON TABLE segments IS 'Audience definitions (rule trees in JSONB). Used by Engage campaigns and automations.';
COMMENT ON COLUMN segments.is_dynamic IS 'True = re-evaluated each send. False = static snapshot.';
COMMENT ON COLUMN segments.definition IS 'Rule tree: {type:"and", children:[...]}, {type:"member_attr", key, op, value}, etc.';
COMMENT ON TABLE campaigns IS 'Marketing campaigns (Engage). Aggregated counters denormalized for fast list views.';
COMMENT ON TABLE campaign_recipients IS 'Per-member campaign delivery + engagement record. Truth source for campaign analytics.';
COMMENT ON TABLE automations IS 'Trigger-based flows: post-OTA invitation, birthday, tier upgrade, etc.';
COMMENT ON COLUMN automations.trigger_type IS 'Event that starts the flow. Conditions/filters live in trigger_config JSONB.';
COMMENT ON TABLE automation_steps IS 'Ordered actions within an automation (send_sms, send_email, wait, add_tag, adjust_points, webhook).';
COMMENT ON TABLE automation_runs IS 'Per-member execution log of an automation.';

-- ===== Admin / audit =====
COMMENT ON TABLE admin_users IS 'Adminportal user profiles. id matches auth.users(id) — Supabase Auth is identity source (ADR-0015).';
COMMENT ON COLUMN admin_users.app_role IS 'loyco_admin (cross-chain) | chain_admin | hotel_staff | analyst.';
COMMENT ON TABLE admin_user_hotel_assignments IS 'Per-hotel scope for hotel_staff users. Empty list = no access.';
COMMENT ON TABLE audit_log IS 'Append-only audit log for sensitive tables (members, tier history, manual point adjustments, bookings, loyalty config, admin RBAC).';

-- ===== PMS sync =====
COMMENT ON TABLE pms_imports IS 'Audit of every PMS load (file or API). Tracks rows succeeded/failed/total.';
COMMENT ON TABLE pms_raw_payloads IS 'Raw PMS row payloads preserved for re-parse. Indexed with GIN on payload jsonb.';
COMMENT ON TABLE pms_sync_errors IS 'Per-row failures during PMS imports — for ops debugging.';

-- ===== Views =====
COMMENT ON VIEW member_360_view IS 'One row per member with tier, balance, lifetime revenue, booking counts and churn flag. Drives adminportal "Member detail".';
COMMENT ON VIEW tier_distribution_view IS 'Members per tier per chain with active percentage.';
COMMENT ON VIEW direct_booking_share_view IS 'Per chain, per month: direct vs OTA vs corporate booking shares.';
COMMENT ON VIEW revenue_per_member_view IS 'Per chain, per month: total revenue and revenue-per-active-member.';
COMMENT ON VIEW member_growth_view IS 'New members and cumulative growth per chain per month.';
COMMENT ON VIEW churn_view IS 'Per chain: how many members are churned (no booking + no points activity in 12 months).';
COMMENT ON VIEW clv_view IS 'Per member: gross revenue, redemption value, net value, completed bookings, nights total.';
COMMENT ON VIEW campaign_performance_view IS 'Per campaign: deliveries, opens, clicks, attributed bookings + revenue.';
COMMENT ON VIEW chain_overview_view IS 'KPI rollup per chain: hotels, members, last-365d bookings, revenue, direct share.';
COMMENT ON VIEW hotel_comparison_view IS 'KPI rollup per hotel: 365d completed bookings, nights, revenue, direct share, member bookings.';
COMMENT ON VIEW db_dictionary_view IS 'Self-describing schema: every column with its type, PK/FK info, and human description. Used by MCP/AI to discover the database.';

# Roadmap

Phase-based plan. Each phase is run continuously to completion (see autonomy policy in `CLAUDE.md`); pauses happen only at phase boundaries, blockers, or strategic decisions.

---

## Fase 0 — Specs (in progress)

**Goal:** Lock architecture and decisions. No code yet.

- [x] Inspect 9 attached PMS/loyalty exports
- [x] `~/loyco-db/` initialized as git repo
- [x] `ARCHITECTURE.md` — domain model, tables, ER diagram, conventions
- [x] `DECISIONS.md` — ADRs 0001–0017
- [x] `ROADMAP.md` (this file)
- [x] `MEMORY.md` — open questions and observations
- [x] `CLAUDE.md` — autonomy policy and project conventions
- [ ] **PAUSE** — user reviews specs and provides Supabase credentials

**Exit criteria:** signoff + credentials in hand.

---

## Fase 1 — Schema

**Goal:** Working schema in Supabase. Empty tables, all constraints, all RLS policies, all views, all comments.

Migrations created in this order in `supabase/migrations/` (numbered `0001_*.sql`, `0002_*.sql`, ...):

1. `0001_extensions.sql` — `pgcrypto`, `uuid-ossp` (already in Supabase), `pg_trgm`, `unaccent`
2. `0002_enums.sql` — all enum types
3. `0003_tenancy.sql` — `chain_groups`, `hotels`, `pms_systems`, `hotel_pms_connections`, `currencies`, `currency_rates`, `regions`
4. `0004_loyalty_config.sql` — `loyalty_programs`, `tiers`, `tier_thresholds`, `tier_benefits`, `points_rules`, `rewards`
5. `0005_members.sql` — `members`, `member_external_ids`, `member_consents`, `member_tier_history`, `member_attributes`
6. `0006_bookings.sql` — `bookings`, `room_stays`, `booking_segments`, `booking_status_history`
7. `0007_transactions.sql` — `transactions`, `transaction_lines`
8. `0008_points.sql` — `point_transactions`, `point_redemptions`, `points_balances_mv`
9. `0009_communications.sql` — `communications`, `communication_templates`
10. `0010_marketing.sql` — `campaigns`, `campaign_recipients`, `segments`, `automations`, `automation_steps`, `automation_runs`
11. `0011_admin_audit.sql` — `admin_users`, `admin_user_hotel_assignments`, `audit_log`
12. `0012_pms_sync.sql` — `pms_imports`, `pms_raw_payloads`, `pms_sync_errors`
13. `0013_indexes.sql` — secondary indexes (PK/FK already inline)
14. `0014_helpers.sql` — `lc_current_role()`, `lc_current_chain_id()`, `lc_current_hotel_ids()`, `lc_is_loyco_admin()`, `lc_to_reporting_ccy()`, `lc_audit_trigger()`
15. `0015_audit_triggers.sql` — attach trigger to audited tables
16. `0016_views.sql` — all reporting views (`member_360_view`, `tier_distribution_view`, ..., `db_dictionary_view`)
17. `0017_rls.sql` — enable RLS + policies for every tenant-scoped table
18. `0018_comments.sql` — `COMMENT ON` for every table and non-obvious column

Each migration must be idempotent (safe to re-run on a fresh DB) and must not depend on data inserted later.

**Apply strategy:** psql against the Supabase connection pooler URL (or `supabase db push` if user prefers Supabase CLI). I'll choose based on what credentials are provided.

**Verification at end of Fase 1:**
- `\dt` shows all expected tables
- `\dv` shows all views
- `select * from db_dictionary_view limit 5` returns rows
- RLS enabled on every tenant-scoped table (audit query)

**Exit criteria:** schema present, empty, fully constrained, RLS active.

---

## Fase 2 — Seed

**Goal:** Realistic dummy data per ADR-0004.

Seed implementation in `supabase/seed/`:
- `seed.config.ts` — knobs (chain count, member count, ratios, RNG seed)
- `seed.ts` — entrypoint
- `generators/` — one file per domain (chains, hotels, members, bookings, transactions, points, comms, campaigns)
- `pms_mappers/` — fake "raw" PMS rows for `pms_raw_payloads`, mimicking the real exports

Generation order:
1. Reference data: currencies, regions, PMS systems
2. Chains (5) with their default currencies and reporting currencies
3. Hotels (25) distributed across chains
4. PMS connections (each hotel ↔ one PMS)
5. Loyalty programs (1 per chain) + tiers + tier_thresholds + tier_benefits + points_rules
6. Rewards catalogue (per chain)
7. Members (2 000) — distribution per chain weighted by chain size
   - Realistic Nordic names (faker `fi`, `nb`, `sv`, `da` locales)
   - Birth dates with valid ranges (some legacy 1800-01-01 placeholders to mirror real data)
   - Member levels distributed per ADR-0004 target
   - 30-50% have one or more `member_external_ids` (legacy IDs)
   - Recruitment sources mix matching real samples (`StayNTouchIntegration`, `widget_*`, `ProtelAirPMSintegration`, `AuthOtp`, organic)
   - Consent flags realistic (most TRUE, some FALSE)
8. Member tier history (multiple transitions per high-tier member)
9. Bookings (~40 000) — distribution:
   - Channel mix per ADR-0004
   - Date range 2023-05 to 2027-05
   - Seasonality: peak summer (NO/SE), winter holidays, conference seasons
   - Multi-night stays (1–14, log-normal)
   - Cancellation/no-show rates per ADR-0004
   - Some bookings tied to a member, some anonymous (OTA "Is Member = 0")
10. Room stays (1+ per booking)
11. Booking segments (PMS-realistic codes)
12. Transactions (one per completed/cancelled booking with non-zero `paid`)
13. Transaction lines (room nights, F&B if applicable)
14. Point transactions (auto-earn from completed transactions, applying `points_rules` + tier multipliers)
15. Point redemptions (~5% of high-tier members redeem at least once)
16. Manual point adjustments (a handful, with audit trail)
17. Communications (`Personal Invitation` SMS for OTA bookings, transactional emails, marketing emails)
18. Campaigns (~3-5 per chain) + campaign recipients
19. Segments (a starter set per chain: high-value, churned, OTA-only, birthday-this-month, near-tier-upgrade)
20. Automations (post-OTA-invitation, birthday, tier-upgrade-congrats)
21. PMS imports + sample raw payloads (a few per PMS system)
22. Admin users (one per role per chain + Loyco staff) — known email/password for demo

**Realistic scenarios per brief:**
- Members without bookings (~5%)
- OTA-only members (~30%)
- OTA → direct conversions (visible by checking booking history per member)
- VIP / high-LTV (~2%, hand-curated)
- Churned members (~15%, no booking last 12m)
- Members with many cancellations (~3%)
- Seasonal spikes
- Multiple chains
- Multiple hotels per chain
- Different PMS per hotel

**Verification at end of Fase 2:**
- Row counts match targets (chains, hotels, members, bookings, transactions)
- `member_360_view` returns expected metrics for hand-picked test members
- Reporting views are non-empty
- No FK violations, no orphaned rows

**Exit criteria:** seed runs cleanly end-to-end, scenario coverage verified.

---

## Fase 3 — Verification

**Goal:** Prove the database does what the brief asks, without writing a frontend.

- [ ] Sanity SQL pack (`scripts/verify.sql`):
  - Total rows per table
  - Tier distribution per chain
  - Direct vs OTA booking ratio
  - Top-10 members by LTV
  - Churn count per chain
  - Sample point earning calculation walkthrough (one booking, traced from `bookings` → `transactions` → `points_rules` → `point_transactions`)
- [ ] RLS smoke tests (`scripts/rls-tests.sql`):
  - Set JWT to chain_admin of chain A, query members → should only see chain A
  - Set JWT to hotel_staff of hotel X, query bookings → should only see hotel X
  - Set JWT to loyco_admin, query → should see all
  - Set JWT to anon, query → should see nothing on tenant tables
- [ ] Performance check on heaviest views; promote to materialized if a view exceeds ~1s on full seed
- [ ] `db_dictionary_view` spot-checks for AI/MCP-readiness
- [ ] Generate ER diagram PNG from `docs/diagrams/` source for visual review

**Exit criteria:** verify scripts pass, RLS tests pass, all views return sensible data.

---

## Out of scope (later phases)

- Adminportal frontend
- MCP server implementation
- Real PMS API/file ingestion adapters
- Member-facing app + member auth
- Production hardening: PII encryption, retention policies, GDPR right-to-erasure flows
- Real-money payment + Mastercard McKickback
- Point-expiry scheduled job
- Multi-region deployment

---

## Phase pause checkpoint

End of each phase = explicit pause for user review. User may:
- Approve and tell me "next phase"
- Ask for adjustments → I update specs (DECISIONS.md gets new ADRs) and re-do affected work
- Cancel / pivot

Within a phase, I run continuously per the autonomy policy in `CLAUDE.md`.

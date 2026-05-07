# Decision Log

Architectural decision records (ADRs) for the Loyco prototype database. Each ADR is a locked decision until explicitly superseded. Format: Status / Context / Decision / Consequences.

---

## ADR-0001 — Single Supabase project, single Postgres schema

**Status:** Accepted (2026-05-06)

**Context:** Database serves prototype adminportal, MCP queries, analytics, and seed simulation. Multiple isolated projects would complicate cross-tenant analytics and add deployment overhead.

**Decision:** One Supabase project, all tables in `public` schema. Helper functions prefixed `lc_*`. Tenant isolation via RLS, not via schema-per-tenant.

**Consequences:**
- Simpler to query, simpler MCP exposure, simpler RLS reasoning.
- Cross-chain analytics work natively (Loyco-wide views).
- Risk: a buggy RLS policy could leak across chains. Mitigated by required RLS tests in `scripts/rls-tests.sql` before claiming Fase 3 done.

---

## ADR-0002 — Tenant boundary is the chain (not the hotel)

**Status:** Accepted (2026-05-06)

**Context:** Loyco's customers are hotel chains (First Hotels, etc.). A chain owns its loyalty program, members, and rules. Hotels are operating units within a chain.

**Decision:** Primary tenant is `chain_groups`. RLS scopes by `chain_group_id`. Hotels are children. `hotel_staff` users are further restricted to assigned hotels via `admin_user_hotel_assignments`.

**Consequences:**
- Members are chain-scoped: same person can be a separate member at two chains (matches reality).
- Reporting queries default to chain-level rollups.
- Hotels share chain-level loyalty program by default.

---

## ADR-0003 — Admin roles: loyco_admin, chain_admin, hotel_staff, analyst

**Status:** Accepted (2026-05-06)

**Context:** Briefing names "adminbrukere" but doesn't enumerate roles. The four roles below cover Loyco staff (cross-chain), chain owners (full access within their chain), individual hotel teams (subset), and read-only reporting users.

**Decision:** Four roles encoded in JWT `app_role` claim. Members do not have admin login in this phase (they may have a separate member-facing app later).

**Consequences:**
- RLS policies branch on these four values + the helper `lc_is_loyco_admin()`.
- `hotel_staff` requires `hotel_ids` claim populated from `admin_user_hotel_assignments`.
- Adding a future role (e.g., partner read-only) requires migration.

---

## ADR-0004 — Seed scale: 5 chains × 25 hotels × 4 PMS × 2 000 members × ~40 000 bookings × 3y history + 1y future

**Status:** Accepted (2026-05-06)

**Context:** Brief asked for ~2 000 members. Other dimensions chosen to make analytics views interesting without overloading Supabase free tier or making seed runs slow.

**Decision:**
- 5 chain groups (mix: Norwegian, Pan-Nordic, single-hotel boutique, etc.)
- 25 hotels distributed unevenly across chains (1, 3, 5, 7, 9)
- 4 PMS systems used (StayNTouch, Mews, Protel Air, Visbook)
- 2 000 members across all chains, weighted toward larger chains
- ~40 000 bookings spanning 2023-05-01 to 2027-05-01 (3y history + 1y future)
- Booking channel mix: 60% OTA, 25% direct, 10% corporate, 5% other
- Cancellation rate: ~12%; no-show rate: ~2%
- Tier distribution target: 60% Bronze, 25% Silver, 11% Gold, 4% Platinum

**Consequences:**
- Seed script aims for ~30s to <2min runtime.
- Realistic enough to make all 11 reporting views non-trivial.
- Adjustable via `seed.config.ts` constants.

---

## ADR-0005 — Multi-currency stored at the row, no normalization to single currency

**Status:** Accepted (2026-05-06)

**Context:** Real PMS exports show NOK, SEK, DKK, EUR, sometimes mixed within one chain. Normalizing to a single currency loses information and creates rounding artifacts in reporting.

**Decision:**
- Money is always `numeric(14,2)` paired with `currency char(3)` ISO 4217 code.
- `transactions` carries both `original_amount/currency` and `posted_amount/posted_currency` plus `fx_rate` and `fx_rate_date` (mirrors actual export shape).
- `currency_rates(from_ccy, to_ccy, rate_date, rate)` table provides FX history for reporting views.
- Reporting views convert to chain's `reporting_currency` at query time using `currency_rates`.

**Consequences:**
- Slight query complexity; mitigated by helper SQL function `lc_to_reporting_ccy(amount, from_ccy, on_date)`.
- Re-running historical reports in a different reporting currency is possible.

---

## ADR-0006 — Points/tier model fully configurable per chain

**Status:** Accepted (2026-05-06) — confirmed by user message 2026-05-06

**Context:** User explicitly stated points and tier configuration must be per customer (chain). Typical values are 2/5/10/15% of payment with 1 point = 1 unit of local currency. OTA channel typically excluded from earning.

**Decision:**

**Tier configurability:**
- `tiers` table is per-program (i.e., per-chain). Each chain configures its own set.
- Default seed: Bronze / Silver / Gold / Platinum for each chain, but values, names, thresholds, multipliers, and benefits vary across chains.
- Threshold metrics (`tier_thresholds`): `points`, `nights`, `revenue` — chain picks which apply.
- Qualifying period: 12 months by default; configurable per tier.

**Points earning:**
- `points_rules(program_id, hotel_id null, channel enum, market_segment_code text null, percent_of_payment numeric(5,2), tier_multiplier_override jsonb null, valid_from, valid_to, priority int)`.
- `1 point = 1 unit of local currency` is encoded by `percent_of_payment` (e.g., 5.00 → 5 points per 100 NOK).
- OTA exclusion = rule with `channel='ota'` and `percent_of_payment=0` (default seeded for every chain).
- Resolution: most-specific match wins. Tie-break by `priority DESC`.

**Currency for points:**
- Points are denominated in the chain's `default_currency` (1 point = 1 unit of that currency).
- A booking in a different currency converts via `currency_rates` before applying `percent_of_payment`.

**Consequences:**
- Single rules engine handles all chains. Adding a new chain = inserting tier rows + points_rules rows, no code change.
- Easy to demo "what-if" by changing percentages.
- Manual point adjustments still go through `point_transactions(type='manual_adjustment')` for audit.

---

## ADR-0007 — PMS data normalized into common schema; raw payload retained

**Status:** Accepted (2026-05-06)

**Context:** Loyco receives data from StayNTouch, Mews, Protel Air, Visbook. Each has a different shape. We need a common queryable shape but must not lose source fidelity in case mapping is later corrected.

**Decision:**
- All PMS data is mapped into common tables: `bookings`, `room_stays`, `transactions`, `transaction_lines`, `booking_segments`.
- For each imported source row, a `pms_raw_payloads` row stores the original JSON payload, linked to the resulting normalized rows via `source_id`.
- Mapping rules live in seed code (and later in real ingestion code), not in DB. PMS-specific quirks (Excel-serial dates from Mews, JSON arrays from StayNTouch) handled at parse time.
- `pms_imports` table tracks every load: file name, row count, status, started/finished timestamps.

**Consequences:**
- Re-mapping with corrected logic is possible (re-parse from raw_payloads).
- Disk growth: payloads can be large. Mitigated by setting `pms_raw_payloads` storage to `EXTENDED` (TOAST compression).

---

## ADR-0008 — AI/MCP semantic context via `COMMENT ON` and a dictionary view

**Status:** Accepted (2026-05-06)

**Context:** Database will be queried by MCP servers and AI agents. Without semantic context, AI must guess column meanings. PG's built-in `pg_description` table stores `COMMENT ON` annotations.

**Decision:**
- Every table gets a `COMMENT ON TABLE` describing its purpose and tenant scope.
- Every column whose name isn't self-explanatory gets a `COMMENT ON COLUMN`.
- A `db_dictionary_view` view joins `pg_tables` + `pg_attribute` + `pg_description` + `pg_constraint` so an MCP server can fetch a self-describing schema in one query.

**Consequences:**
- Migrations are larger (every table block ends with comments).
- Worth it for MCP/AI quality and onboarding humans.

---

## ADR-0009 — Member uniqueness scoped to chain, not global

**Status:** Accepted (2026-05-06)

**Context:** A guest may be a member of two competing chains (e.g., Nordic Choice and First Hotels). Email and phone are reused across chains. Global UNIQUE on email would force a single membership.

**Decision:**
- `members.email` UNIQUE per `(chain_group_id, lower(email))`.
- `members.phone_e164` UNIQUE per `(chain_group_id, phone_e164)` where not null.
- Cross-chain identity resolution (same person across chains) is a separate, future concern handled in a downstream "person graph", not in this DB.

**Consequences:**
- Honest model of how loyalty programs actually work.
- Cross-chain analytics on "unique persons" is out of scope.

---

## ADR-0010 — Members have legacy external IDs (mirrors `External Membership` JSON)

**Status:** Accepted (2026-05-06)

**Context:** Real Loyco member exports include an `External Membership` JSON array with prior-system IDs (e.g., `FMOldId`, `SJprioId`). Members are often migrated from older platforms.

**Decision:** `member_external_ids(member_id, type, value, valid_from, is_valid, metadata jsonb)` table. One row per legacy ID. Indexed for lookup by `(type, value)`.

**Consequences:**
- Lookup by legacy ID for support/import flows.
- Seed populates 30-50% of members with one or more external IDs to mimic real-world legacy migration.

---

## ADR-0011 — Communications unified into one base table, channel-typed

**Status:** Accepted (2026-05-06)

**Context:** SMS and email messages share most fields (recipient, sent_at, status, template_id, body, campaign_id). Separate tables duplicate logic; a single table simplifies querying member 360 view.

**Decision:**
- `communications(id, chain_group_id, member_id, hotel_id null, channel enum (sms|email|push), subject text null, body text, status enum, sent_at, delivered_at null, template_id null, campaign_id null, automation_run_id null, external_message_id text, metadata jsonb)`.
- Channel-specific columns (subject required for email, sender for SMS) validated via CHECK constraints.

**Consequences:**
- Member timeline is a single SELECT.
- Channel-specific deep features (e.g., SMS billing per segment) live in `metadata` JSONB until they earn a column.

---

## ADR-0012 — Audit log via trigger; not every table audited

**Status:** Accepted (2026-05-06)

**Context:** Brief explicitly asks for audit logs. Auditing every row of every table is overkill and noisy.

**Decision:** Audit only:
- `members` (manual edits)
- `member_tier_history` (insert-only, but audited for actor)
- `point_transactions(type='manual_adjustment')`
- `bookings` (status changes, manual creation)
- `tiers`, `points_rules`, `tier_thresholds`, `tier_benefits` (config changes)
- `admin_users`, `admin_user_hotel_assignments` (RBAC changes)

Implementation: trigger function `lc_audit_trigger()` that writes `audit_log(occurred_at, actor_user_id, actor_role, action, table_name, record_id, before, after, chain_group_id)`.

**Consequences:**
- Targeted audit = easier to query.
- High-volume tables (transactions, communications, point_transactions auto-earnings) intentionally not audited; they're already append-mostly.

---

## ADR-0013 — Seed determinism via fixed Faker seed

**Status:** Accepted (2026-05-06)

**Context:** Demo + AI testing require reproducible data. A new run shouldn't produce different totals.

**Decision:** Seed script sets `faker.seed(42)` and `Math.random` is also seeded. Re-running `pnpm seed` produces byte-identical inserts.

**Consequences:**
- Snapshots, screenshots, and AI prompts can reference specific member IDs and stay valid.
- Adding new seed logic should append, not interleave, to preserve earlier IDs.

---

## ADR-0014 — Booking channel taxonomy

**Status:** Accepted (2026-05-06)

**Context:** Briefing mentions OTA, direct, corporate. Real PMS exports include channel manager (Booking.com, Expedia), travel agency, market segment, source code — overlapping concepts.

**Decision:** Two-level model:
- `bookings.channel` enum (`direct`, `ota`, `corporate`, `group`, `walk_in`, `other`) — high-level.
- `booking_segments` table — full PMS richness: `channel_manager`, `travel_agency`, `market_segment_code`, `rate_group`, `rate_code`, `source_code`, `promotion_code`, `business_segment`.

Channel resolution at PMS-mapping time uses heuristics:
- `channel_manager IN (Booking.com, Expedia, Hotels.com, ...) ` → `ota`
- `source_code = 'Company direct'` or known corporate clients → `corporate`
- Group rate codes → `group`
- Else if booked via chain website / direct phone → `direct`
- Fallback → `other`

**Consequences:**
- Reports use `bookings.channel` for the standard "OTA vs direct" narrative.
- Detailed segment analysis uses `booking_segments`.
- Heuristics live in seed code, documented inline.

---

## ADR-0015 — `auth.users` is the source of truth for admin login; `admin_users` is the profile

**Status:** Accepted (2026-05-06)

**Context:** Supabase ships with `auth.users` for authentication. Adding our own user table risks divergence.

**Decision:**
- Authentication: Supabase Auth (`auth.users`).
- Profile + role + assignments: `admin_users(id uuid PRIMARY KEY REFERENCES auth.users(id), display_name, app_role, chain_group_id, ...)`.
- App role syncs into JWT via Supabase's `auth.jwt_template` or a `before_auth_token` hook (out of scope for prototype; seed populates `app_role` directly in `raw_app_meta_data` for test users).

**Consequences:**
- One source of truth for identity.
- Seed creates auth users with known emails/passwords for each role for demo logins.

---

## ADR-0016 — Reporting via plain views first, materialize only what hurts

**Status:** Accepted (2026-05-06)

**Context:** All listed analytics views can be expressed as SELECT joins. Materializing everything wastes storage and adds refresh complexity. Premature optimization.

**Decision:**
- Implement all 11 analytics views as plain (non-materialized) views.
- `points_balances_mv` is the only materialized view at launch (frequently read, expensive sum across `point_transactions`).
- If a query is too slow during Fase 3 verification, promote that view to materialized + add a refresh schedule.

**Consequences:**
- Simpler initial setup.
- Some views may be slow at higher scale (tested in Fase 3).

---

## ADR-0018 — Single-chain prototype: Grand Member only (supersedes parts of ADR-0002, ADR-0004)

**Status:** Accepted (2026-05-06)

**Context:** User requested the database focus exclusively on a single chain — Grand Member — rather than the original 5-chain spread. Reasoning: prototyping is faster with one customer in scope, the adminportal UX is simpler (no chain switcher), and demos feel more concrete.

User-provided naming:
- "Kjede" → "Program" — the loyalty program is **Grand Member**
- "Department" → "Avdeling" — hotels are presented as departments named **Grand <City>** (Grand Oslo, Grand Bergen, ...)

**Decision:**

**Schema:** Kept multi-tenant-capable (chain_groups + chain_group_id columns + RLS policies) so future chains can be added without schema migration. Practically populated with one chain only.

**Seed (Grand Member exclusive):**
- 1 chain_group: Grand Member
- 1 loyalty_program: Grand Member program
- 5 tiers: Bronze, Silver, Gold, Platinum, Black
- 15 hotels (avdelinger) named Grand <City>: Oslo, Bergen, Trondheim, Stavanger, Tromsø, Stockholm, Göteborg, Malmö, Uppsala, København, Aarhus, Odense, Helsinki, Reykjavík, Akureyri
- 4 PMS systems used (StayNTouch ×6, Mews ×5, Protel Air ×3, Visbook ×1)

**Seed scale (supersedes part of ADR-0004):**
- Hotels: 15 (was 25 across 5 chains)
- Members: 2 000 (unchanged, all in Grand Member)
- Bookings: 40 000 (unchanged)
- **Member vs non-member booking split:** 65% member / 35% non-member (was 80/20). Drives more diverse data.
- **Non-member bookings get lower per-night rate** (~0.65–0.95× base) and **shorter stays** (mostly 1–3 nights), reflecting walk-in / one-time-guest reality. Member bookings stay at ~0.85–1.35× base.
- All bookings (member and non-member) generate transactions per existing logic; only members earn points.

**Consequences:**
- Cleaner demo: every screen shows Grand Member without a chain selector
- Reporting views still work because they group by chain_group_id (which has only one value)
- If Loyco onboards a real second chain later, schema is ready — only seed expansion needed
- Old structural UUIDs (`a1111111-0000-…`, `b22000XX-0000-…`, etc.) replaced with new pattern using `aaaa` band (`a1111111-aaaa-…`) for Grand Member to make the cutover obvious in tools

---

## ADR-0017 — Norwegian-language docs, English schema

**Status:** Accepted (2026-05-06)

**Context:** User's native language is Norwegian. Schema must be globally legible (MCP, AI, future devs).

**Decision:**
- Repo docs (ARCHITECTURE/DECISIONS/ROADMAP/MEMORY/CLAUDE) authored in mixed NO/EN — primarily Norwegian for narrative, English for technical terms and code blocks.
- Schema (table names, column names, enum values, comments) all English.
- Seed-generated content (member names, addresses, hotel names) is realistic Nordic mix matching the real export samples.

**Consequences:**
- Future Loyco engineers read docs comfortably; AI/MCP gets clean English schema.

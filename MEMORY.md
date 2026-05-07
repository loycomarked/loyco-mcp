# Project Memory

Living doc for working assumptions, observations from data, and open questions. Update freely as the project progresses.

---

## Status

- **Grand Member single-chain prototype is live in Supabase** (per ADR-0018, supersedes original 5-chain seed).
- Schema migrations 0001–0019 applied; advisor 0 lints.
- Seed re-run via SQL Editor with `supabase/seed/grand_member/{01,02,03}*.sql`.
- Verified totals: 1 chain × 15 avdelinger × 2 000 members × 40 000 bookings (64.8% member / 35.2% non-member) × 25 880 transactions × 6 309 point_transactions × 16 941 communications.
- Average member transaction is 2.0× the average non-member transaction (NOK 21 547 vs NOK 10 740) — driven by longer member stays + better rate multiplier.

## Open follow-ups

- `hotel_comparison_view` times out due to repeated `lc_to_currency()` lookups. Either add a covering index `(from_ccy, to_ccy, rate_date DESC)` on `currency_rates`, or promote the view to a materialized view refreshed nightly. Low priority — other views still respond fine.
- The legacy 5-chain seed files at `supabase/seed/0[1-9]_*.sql` are kept for historical reference but are NOT current. The active seed lives at `supabase/seed/grand_member/`.
- Schema is multi-tenant-capable; if Loyco onboards a real second chain later, only seed expansion is required (no migrations).

---

## Observations from attached PMS/loyalty exports

### File: `268-1178-members.xlsx` (Program 268, "268plus" / "268start" tags, 1 178 members)
- 29 columns. Owner chain has Norwegian-language tags.
- Birth date placeholder `1800-01-01` for unknown DOBs — must be tolerated in schema (allow NULL).
- `External Membership` is JSON array — confirms ADR-0010.
- `Recruitement Source` (sic — typo in real data) = `widget_frich.loyallfriends.no`, `ProtelAirPMSintegration`, etc.
- `Recruiting Department = -1` is a sentinel for unknown.

### File: `364-204-members.xlsx` (Program 364, First Hotels, 204 members)
- Same column shape as 268.
- `Member Level = N/A` is common — many members ungraded.
- External IDs include `FMOldId` (legacy First Member ID like `FM0086781`) and `SJprioId` (SJ Prio rail loyalty) — multi-system identity.

### File: `departments.xlsx` (Program 364 hotel rollup, 24 rows)
- Year × ProgramId × DepartmentId aggregates.
- Confirms hotel = department; chain = program in Loyco's PMS terminology.
- Has `SumBonusReleasedAmount`, `SumBonusEarnedAmount`, `SumAllTransactions`, percentage shares.

### File: `campaigns.xlsx` (4 campaigns)
- `Title`, `Transactions`, `Revenue`, `Clicks`, `Status` (`COMPLETED`), `StartDate`.
- Campaigns are simple from data side; richness lives in segments and recipients.

### File: `364-8756-sms-history.xlsx` (8 756 SMS)
- `Category = 'Personal Invitation'` is the dominant kind — invitation flow after OTA booking.
- `Sender` is sometimes a hotel name (`FirstHotels`), sometimes a phone number — schema accommodates both.
- `Scandinavia` boolean — Loyco's billing distinction, not modeled in our schema yet (out of scope).
- `Real Count` vs `Logical Count` — SMS billing segmentation; stored in `metadata` JSONB.
- `Status = 'Delivered'` — straightforward enum.

### File: `364-11553-transactions.xlsx` (11 553 transactions, 44 columns)
- Primary source of truth for booking financial data. All schema design choices for `transactions` derive from here.
- `Booking Info` is a JSON array (one entry per "leg" of the stay; same arrival/departure replicated when no leg break).
- `Order Lines` is a JSON array with `ProductType` (Merchandise = room nights), `Quantity`, `Sum`, `LineInfo` (e.g., `RoomType:4421`), `BonusFactor` — drives `transaction_lines` design.
- `OTA = Yes/No` — direct flag, simpler than parsing channel manager.
- `Returning Member = Yes/No` — useful for retention analytics.
- `Currency` (=transaction posted currency) and `Original Currency` + `Original Sum` + `Currency Exchange Rate` + `Currency Exchange Date` — confirms ADR-0005.
- `Bonus Earned`, `Bonus Released`, `Bonus Percentage` — three separate bonus columns. "Earned" = points granted at posting; "Released" = points moved from pending to posted-available; "Percentage" = the rule % applied. We model this as `point_transactions(type IN ('earn_pending', 'release', 'redeem', 'manual_adjustment', 'expire'))`.
- `McKickback Percentage` / `McKickback Sum` — Mastercard cashback fields. Out of scope for prototype but present in real data — leave as `metadata` for now.

### File: `364-325-bookings.xlsx` (325 bookings)
- Smaller than transactions — represents a recent window or a different export.
- Has `Department Timezone` (Europe/Oslo) — important for shift-aware reporting; stored on `hotels`.
- `Reservation Source = 'StayNTouchIntegration'` — channel/PMS hint (this isn't OTA channel, it's the integration label).
- `Is Member = 1/0` — whether the booking was made by a known member.

### File: `364_StayNTouch_2026-04-22.segment_report.csv` (StayNTouch segment report)
- Semicolon-separated.
- Includes `marketsegment` (full text like `CGN - Corporate groups on negotiated rates`), `promotion_code`, `segment_code`, `source_code`.
- Confirms that segment richness lives in a separate "segment report" feed — not embedded in the main bookings export. We'll model it in `booking_segments` regardless.

### File: `mews_first_rules_260401_260501.xlsx` (1 000 rows)
- Mews ⇄ First Hotels reservation feed for one month (Apr 2026).
- Excel-serial dates (`46112.5305...`) — must be converted at parse time.
- Channel manager column (`Booking.com`) directly available.
- `business_segment`, `rate_group`, `rate` — three-level rate taxonomy. Maps to `booking_segments`.
- `enterprise` (hotel display name) — distinct from `department_id`. We resolve to `hotel_id` via lookup.
- File parsed via raw zip/XML because openpyxl chokes on a malformed stylesheet — implementation note for any future re-parse.

### Cross-cutting observations
- "Bonus" in Loyco's vocabulary = "points" (bonuspoeng). Our schema standardizes on "points" in code, but seed UI labels can show "bonus".
- Member level values seen: `Bronze`, `Silver`, `Gold`, `Platinum`, `Black`, `N/A`. "Black" is a chain-specific tier above Platinum, validating ADR-0006 (configurable tiers).
- Several Norwegian/Scandinavian PMS-specific terms surface (e.g., Mews `OTA 48 timer`, `NRF-WEB`, `Flex Booking`, `NonRef Booking`) — these are real-world segment codes preserved verbatim in `booking_segments`.

---

## Open questions (parked, not blocking)

1. **Supabase credentials format** — service role key vs PAT + project ref vs DB connection string. User to choose.
2. **Repo remote** — keep `~/loyco-db/` local-only for now, or push to GitHub? Default: local-only until user requests.
3. **Member-facing app** — out of scope for now; member rows have `auth_user_id NULL` for future link.
4. **Mastercard McKickback** — modeled only as `metadata` JSONB on transactions; full schema later.
5. **Multi-program-per-chain** — schema supports it (FK from program to chain) but seed creates 1:1; can be exercised later.
6. **Currency rate freshness** — seed populates daily rates for the date range, derived from a fixed RNG-seeded series. Real ingestion later.

---

## Working principles

- Spec-first: lock decisions in `DECISIONS.md` before code.
- Continuous execution within phases (see `CLAUDE.md`).
- AI/MCP-friendly schema: comments everywhere, snake_case, enums for finite domains.
- Realism over completeness: seed should make demos feel real, not exhaustively cover every edge case.

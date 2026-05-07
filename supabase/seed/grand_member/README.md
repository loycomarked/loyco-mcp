# Grand Member re-seed

Single-chain prototype seed per **ADR-0018**. Replaces the original 5-chain seed (`supabase/seed/01-09…sql`).

## Run order (Supabase SQL Editor)

Paste each file's contents into a new query in the Supabase Dashboard SQL Editor and click **Run**. Order matters — wait for each part to finish before starting the next.

| File | What it does | Runtime |
|---|---|---|
| `01_truncate_and_structure.sql` | Wipes existing data, disables audit triggers, creates Grand Member chain + program + 5 tiers + 15 hotels + currency rates + 2000 members + ancillary | ~10–20 s |
| `02_bookings_and_transactions.sql` | 40 000 bookings (65% member / 35% non-member), room_stays, segments, status history, 26k+ transactions, transaction lines | ~30–90 s |
| `03_points_comms_admin.sql` | Point transactions (earn + redeem + manual + pending), redemptions, balance MV refresh, 70 templates, ~22k communications, segments, campaigns, automations, PMS imports, admin users — re-enables audit triggers at end | ~15–30 s |

## Volumes

| Concept | Count |
|---|---|
| Chain | 1 (Grand Member) |
| Avdelinger (hotels) | 15: Grand Oslo, Bergen, Trondheim, Stavanger, Tromsø, Stockholm, Göteborg, Malmö, Uppsala, København, Aarhus, Odense, Helsinki, Reykjavík, Akureyri |
| Tiers | 5 (Bronze → Black) |
| Members | 2 000 |
| Bookings | 40 000 |
| Member bookings | ~26 000 (65%) |
| Non-member bookings | ~14 000 (35%) |
| Transactions | ~26 000 |
| Avg member transaction | ~1.5× avg non-member transaction (members stay longer + pay BAR rates) |

## Diversification per ADR-0018

- Member bookings get rate multiplier `0.85–1.35×` base
- Non-member bookings get rate multiplier `0.65–0.95×` base
- Non-member nights weighted toward 1–3 nights (85%) — more walk-in / one-time-guest feel
- Both member and non-member bookings generate transactions (only members earn loyalty points)

## Sanity checks emitted at end of each part

Each file ends with a `SELECT … COUNT(*)…` block. Verify the numbers look right before moving on.

## Re-running

Each part is idempotent on a freshly truncated DB. To re-run:
1. Run part 1 (the TRUNCATE handles the wipe)
2. Run part 2
3. Run part 3

# Seed data

Realistic dummy data per ADR-0004:
- 5 chain groups, 25 hotels, 4 PMS systems
- 2 000 members (Nordic name pool, 5% birth-date placeholder, 35% legacy external IDs)
- 40 000 bookings spanning 2023-05 to 2027-05
- 26 575 transactions (7 021 earning, 8 065 multi-currency)
- 7 163 point_transactions, 73 reward redemptions, 50 manual adjustments
- 21 998 communications (16 495 personal-invitation SMS for OTA bookings + 5 503 confirmation emails)
- 25 segments, 20 campaigns, 2 700 campaign recipients
- 15 automations, 750 automation runs
- 25 PMS imports + 125 raw payloads
- 10 admin users (loyco_admin × 2, chain_admin × 5, hotel_staff × 2, analyst × 1)

## Order of application

| File | Purpose |
|---|---|
| `01_tenancy.sql` | chain_groups, hotels, hotel_pms_connections, currency_rates |
| `02_loyalty_config.sql` | loyalty_programs, tiers, tier_thresholds, tier_benefits, points_rules, rewards |
| `03_members.sql` | 2 000 members with realistic Nordic names |
| `04_member_ancillary.sql` | recruitment_hotel_id, member_external_ids, member_consents, tier_history, attributes |
| `05_bookings.sql` | bookings, room_stays, booking_segments, booking_status_history |
| `06_transactions.sql` | transactions, transaction_lines |
| `07_points.sql` | point_transactions (auto-earn + manual + redemption debits), point_redemptions, refresh balance MV |
| `08_communications.sql` | communication_templates, communications, segments, campaigns, campaign_recipients, automations, automation_steps, automation_runs |
| `09_pms_admin.sql` | pms_imports, pms_raw_payloads, pms_sync_errors, admin_users, admin_user_hotel_assignments |

## Determinism

Each file starts with `SELECT setseed(0.4X)` (X = file index). Re-running on a fresh schema produces identical data.

## How to re-run

These were originally applied via Supabase MCP `execute_sql`. To re-run on a fresh DB:

```bash
# 1. Apply all migrations 0001-0019 (recreates schema)
# 2. Then run each seed file in order:
for f in supabase/seed/0*.sql; do
  psql "$SUPABASE_DB_URL" -f "$f"
done
```

The seed must run after migrations because it references hardcoded UUIDs from migration tables (chain_groups, hotels, tiers).

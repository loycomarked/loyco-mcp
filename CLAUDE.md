# Claude operating notes for `loyco-db`

This file is loaded into Claude's context every session in this repo. Read first.

---

## Project at a glance

Postgres database (Supabase) prototype for Loyco — a hotel-loyalty SaaS. Serves a future adminportal, MCP/AI agents, analytics, and demo data. Multi-tenant on chain (`chain_group_id`), normalized PMS data (StayNTouch, Mews, Protel Air, Visbook), realistic dummy seed.

**Source-of-truth docs:**
- `ARCHITECTURE.md` — domain model, schema overview, conventions
- `DECISIONS.md` — locked ADRs (ADR-0001 onward)
- `ROADMAP.md` — phase-based plan
- `MEMORY.md` — open questions and observations from real data
- `CLAUDE.md` — this file

---

## Autonomy policy

**Run continuously within a phase.** Do not stop at "natural break points" inside a phase to ask "keep going?" — keep going.

**Stop only for:**
- A genuine blocker (out-of-band action: credentials, OAuth, key paste)
- A strategic / taste call (pricing, scope, brand, copy tone) not already settled in `DECISIONS.md`
- The end of a phase as defined in `ROADMAP.md`
- An unrecoverable error needing user input

**Non-obvious mid-phase calls:** capture as a new ADR in `DECISIONS.md` rather than asking. User can push back on specific ADRs.

**Non-destructive commands** (install, migrate, commit, push to a not-shared remote, deploy a preview): just run them.

**Commit + push after each coherent chunk** within a phase. End-of-phase = a final commit + a PAUSE for review.

---

## Conventions

### Files & directories
- `supabase/migrations/NNNN_topic.sql` — numbered, idempotent where reasonable
- `supabase/seed/` — TypeScript seed (deterministic, RNG seed=42 — see ADR-0013)
- `supabase/functions/` — Edge Functions (none in initial phases)
- `scripts/` — verify.sql, rls-tests.sql, ad-hoc utilities
- `docs/diagrams/` — Mermaid sources for ER diagrams

### SQL style
- snake_case identifiers, plural table names, `_id` for FKs, `_at` for timestamps, `_date` for dates, `is_` for booleans, `*_history` for change-log tables
- Every table has `id uuid PRIMARY KEY DEFAULT gen_random_uuid()`, `created_at timestamptz NOT NULL DEFAULT now()`, `updated_at timestamptz NOT NULL DEFAULT now()` unless intentionally append-only
- Every tenant-scoped table has `chain_group_id uuid NOT NULL REFERENCES chain_groups(id) ON DELETE RESTRICT`
- Money: `numeric(14,2)` always paired with `currency char(3)` ISO 4217
- Phone: store E.164 in `phone_e164 text`, raw input in `phone_raw text`
- Email: store lowercased canonical in `email text`, original in `email_raw text` if differing
- Enums for finite domains (channel, status, role, ...)
- Helper functions prefixed `lc_` (`loyco_`)
- Every table gets a `COMMENT ON TABLE`; non-obvious columns get `COMMENT ON COLUMN` (ADR-0008)

### Migrations
- Each migration runs in a single transaction by default — split if size or partition operations require it
- Inserts into reference catalogs (currencies, regions, pms_systems) happen in a dedicated migration, not in `_extensions` or `_enums`
- Never delete or rename a column inside a migration we've already applied to user's Supabase — write a new migration

### Seed
- TypeScript with `pg` and `@faker-js/faker`
- Deterministic: `faker.seed(42)` and own `mulberry32` PRNG for non-faker random choices
- Idempotent on a fresh DB — does not check for existing data, designed to run once after migrations
- `pnpm seed` from repo root; flags via env: `LOYCO_SEED_SCALE=small|medium|full`

### Documentation
- Norwegian narrative + English schema (ADR-0017)
- Update `MEMORY.md` whenever a new working assumption surfaces
- Add an ADR to `DECISIONS.md` for any non-obvious mid-phase call

### Git
- Commit per coherent chunk inside a phase
- Conventional-style messages: `feat:`, `fix:`, `docs:`, `chore:`, `refactor:`
- Default to local-only repo until user asks for a remote

---

## Credentials handling

- Never commit secrets. Use `.env.local` (already in `.gitignore`).
- Service role key, DB password, PAT — paste into `.env.local` as needed; reference via `process.env`.
- For psql one-shots, use `PGPASSWORD=...` env or `~/.pgpass`.

---

## How to verify work

After Fase 1 (schema):
- `psql ... -c '\dt'` shows expected tables
- `select count(*) from pg_policies where schemaname='public'` is non-zero
- Run `scripts/verify.sql` — should return non-error rows

After Fase 2 (seed):
- Row counts match `seed.config.ts` targets
- `select * from member_360_view limit 5` returns sensible data
- Hand-pick 2-3 members and trace booking → transaction → point_transaction by hand

After Fase 3:
- `scripts/rls-tests.sql` passes (negative + positive tests)
- All 11 reporting views return non-empty results

---

## When in doubt

1. Re-read the relevant ADR in `DECISIONS.md`
2. If no ADR applies, write a new one and proceed
3. If the call is strategic (taste, scope), pause and ask the user

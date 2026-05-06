-- 0001_extensions.sql
-- Enable required Postgres extensions. Supabase pre-installs pgcrypto + uuid-ossp
-- in the `extensions` schema; we add pg_trgm + unaccent + btree_gin + citext.

CREATE EXTENSION IF NOT EXISTS pg_trgm WITH SCHEMA extensions;
CREATE EXTENSION IF NOT EXISTS unaccent WITH SCHEMA extensions;
CREATE EXTENSION IF NOT EXISTS btree_gin WITH SCHEMA extensions;
CREATE EXTENSION IF NOT EXISTS citext WITH SCHEMA extensions;

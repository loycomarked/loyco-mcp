-- 0014_helpers.sql
-- Helper functions: JWT/RLS context, FX conversion, audit trigger function, updated_at trigger.
-- All helpers prefixed lc_ to avoid namespace collisions.

-- ===== Identity / RLS context =====

CREATE OR REPLACE FUNCTION lc_jwt_claim(claim text)
RETURNS text LANGUAGE sql STABLE AS $$
  SELECT NULLIF(current_setting('request.jwt.claims', true), '')::jsonb ->> claim;
$$;

CREATE OR REPLACE FUNCTION lc_current_role()
RETURNS app_role LANGUAGE sql STABLE AS $$
  SELECT NULLIF(lc_jwt_claim('app_role'), '')::app_role;
$$;

CREATE OR REPLACE FUNCTION lc_current_chain_id()
RETURNS uuid LANGUAGE sql STABLE AS $$
  SELECT NULLIF(lc_jwt_claim('chain_group_id'), '')::uuid;
$$;

CREATE OR REPLACE FUNCTION lc_current_hotel_ids()
RETURNS uuid[] LANGUAGE sql STABLE AS $$
  SELECT CASE
    WHEN current_setting('request.jwt.claims', true) IS NULL OR current_setting('request.jwt.claims', true) = ''
      THEN ARRAY[]::uuid[]
    ELSE COALESCE(
      ARRAY(
        SELECT jsonb_array_elements_text(
          (current_setting('request.jwt.claims', true)::jsonb)->'hotel_ids'
        )::uuid
      ),
      ARRAY[]::uuid[]
    )
  END;
$$;

CREATE OR REPLACE FUNCTION lc_is_loyco_admin()
RETURNS boolean LANGUAGE sql STABLE AS $$
  SELECT lc_current_role() = 'loyco_admin';
$$;

CREATE OR REPLACE FUNCTION lc_can_access_chain(target_chain uuid)
RETURNS boolean LANGUAGE sql STABLE AS $$
  SELECT lc_is_loyco_admin() OR lc_current_chain_id() = target_chain;
$$;

CREATE OR REPLACE FUNCTION lc_can_access_hotel(target_chain uuid, target_hotel uuid)
RETURNS boolean LANGUAGE sql STABLE AS $$
  SELECT
    lc_is_loyco_admin()
    OR (
      lc_current_chain_id() = target_chain
      AND (
        lc_current_role() <> 'hotel_staff'
        OR target_hotel = ANY(lc_current_hotel_ids())
      )
    );
$$;

-- ===== FX conversion helper =====

CREATE OR REPLACE FUNCTION lc_to_currency(
  p_amount numeric,
  p_from char(3),
  p_to char(3),
  p_on_date date
)
RETURNS numeric LANGUAGE plpgsql STABLE AS $$
DECLARE
  rate numeric;
BEGIN
  IF p_amount IS NULL OR p_from IS NULL OR p_to IS NULL THEN
    RETURN NULL;
  END IF;
  IF p_from = p_to THEN
    RETURN p_amount;
  END IF;
  -- Use most recent rate on or before p_on_date
  SELECT cr.rate INTO rate
    FROM currency_rates cr
   WHERE cr.from_ccy = p_from
     AND cr.to_ccy = p_to
     AND cr.rate_date <= p_on_date
   ORDER BY cr.rate_date DESC
   LIMIT 1;
  IF rate IS NULL THEN
    -- Try inverse rate
    SELECT 1 / cr.rate INTO rate
      FROM currency_rates cr
     WHERE cr.from_ccy = p_to
       AND cr.to_ccy = p_from
       AND cr.rate_date <= p_on_date
     ORDER BY cr.rate_date DESC
     LIMIT 1;
  END IF;
  IF rate IS NULL THEN
    RETURN NULL;
  END IF;
  RETURN round(p_amount * rate, 2);
END $$;

-- ===== updated_at touch trigger =====

CREATE OR REPLACE FUNCTION lc_touch_updated_at() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END $$;

-- Attach to tables that have an updated_at column (skip those that already have a custom trigger like members)
DO $$
DECLARE r record;
BEGIN
  FOR r IN
    SELECT c.table_schema, c.table_name
      FROM information_schema.columns c
     WHERE c.table_schema = 'public'
       AND c.column_name = 'updated_at'
       AND c.table_name NOT IN ('members')   -- members has its own trigger that also touches updated_at
  LOOP
    EXECUTE format(
      'DROP TRIGGER IF EXISTS %I ON %I.%I;',
      r.table_name || '_touch_updated_at', r.table_schema, r.table_name
    );
    EXECUTE format(
      'CREATE TRIGGER %I BEFORE UPDATE ON %I.%I FOR EACH ROW EXECUTE FUNCTION lc_touch_updated_at();',
      r.table_name || '_touch_updated_at', r.table_schema, r.table_name
    );
  END LOOP;
END $$;

-- ===== Audit trigger =====

CREATE OR REPLACE FUNCTION lc_audit_trigger() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE
  v_chain uuid;
  v_actor uuid;
  v_role  app_role;
  v_action audit_action;
  v_record uuid;
  v_before jsonb;
  v_after jsonb;
BEGIN
  v_actor := nullif(lc_jwt_claim('sub'), '')::uuid;
  v_role  := lc_current_role();

  IF TG_OP = 'INSERT' THEN
    v_action := 'insert';
    v_after  := to_jsonb(NEW);
    v_record := (v_after->>'id')::uuid;
    v_chain  := nullif(v_after->>'chain_group_id', '')::uuid;
  ELSIF TG_OP = 'UPDATE' THEN
    v_action := 'update';
    v_before := to_jsonb(OLD);
    v_after  := to_jsonb(NEW);
    v_record := (v_after->>'id')::uuid;
    v_chain  := nullif(v_after->>'chain_group_id', '')::uuid;
  ELSIF TG_OP = 'DELETE' THEN
    v_action := 'delete';
    v_before := to_jsonb(OLD);
    v_record := (v_before->>'id')::uuid;
    v_chain  := nullif(v_before->>'chain_group_id', '')::uuid;
  END IF;

  INSERT INTO audit_log (actor_user_id, actor_role, action, table_name, record_id, chain_group_id, before_value, after_value)
  VALUES (v_actor, v_role, v_action, TG_TABLE_NAME, v_record, v_chain, v_before, v_after);

  IF TG_OP = 'DELETE' THEN
    RETURN OLD;
  ELSE
    RETURN NEW;
  END IF;
END $$;

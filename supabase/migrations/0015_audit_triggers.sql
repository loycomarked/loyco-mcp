-- 0015_audit_triggers.sql
-- Attach lc_audit_trigger() to the audited tables (per ADR-0012).

-- Members & member-tier history
CREATE TRIGGER members_audit
  AFTER INSERT OR UPDATE OR DELETE ON members
  FOR EACH ROW EXECUTE FUNCTION lc_audit_trigger();

CREATE TRIGGER member_tier_history_audit
  AFTER INSERT ON member_tier_history
  FOR EACH ROW EXECUTE FUNCTION lc_audit_trigger();

-- Manual point adjustments only
CREATE OR REPLACE FUNCTION lc_audit_manual_points_only() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  IF (TG_OP = 'INSERT' AND NEW.type = 'manual_adjustment')
     OR (TG_OP = 'UPDATE' AND (OLD.type = 'manual_adjustment' OR NEW.type = 'manual_adjustment'))
     OR (TG_OP = 'DELETE' AND OLD.type = 'manual_adjustment')
  THEN
    PERFORM lc_audit_trigger();
    -- Re-implement audit inline since we cannot directly call a trigger function
    DECLARE
      v_chain uuid;
      v_actor uuid := nullif(lc_jwt_claim('sub'), '')::uuid;
      v_role  app_role := lc_current_role();
      v_action audit_action;
      v_record uuid;
      v_before jsonb;
      v_after jsonb;
    BEGIN
      IF TG_OP = 'INSERT' THEN
        v_action := 'manual_adjust';
        v_after  := to_jsonb(NEW);
        v_record := NEW.id;
        v_chain  := NEW.chain_group_id;
      ELSIF TG_OP = 'UPDATE' THEN
        v_action := 'update';
        v_before := to_jsonb(OLD);
        v_after  := to_jsonb(NEW);
        v_record := NEW.id;
        v_chain  := NEW.chain_group_id;
      ELSIF TG_OP = 'DELETE' THEN
        v_action := 'delete';
        v_before := to_jsonb(OLD);
        v_record := OLD.id;
        v_chain  := OLD.chain_group_id;
      END IF;

      INSERT INTO audit_log (actor_user_id, actor_role, action, table_name, record_id, chain_group_id, before_value, after_value)
      VALUES (v_actor, v_role, v_action, TG_TABLE_NAME, v_record, v_chain, v_before, v_after);
    END;
  END IF;

  IF TG_OP = 'DELETE' THEN
    RETURN OLD;
  ELSE
    RETURN NEW;
  END IF;
END $$;

CREATE TRIGGER point_transactions_manual_audit
  AFTER INSERT OR UPDATE OR DELETE ON point_transactions
  FOR EACH ROW EXECUTE FUNCTION lc_audit_manual_points_only();

-- Bookings
CREATE TRIGGER bookings_audit
  AFTER INSERT OR UPDATE OR DELETE ON bookings
  FOR EACH ROW EXECUTE FUNCTION lc_audit_trigger();

-- Loyalty configuration tables
CREATE TRIGGER tiers_audit
  AFTER INSERT OR UPDATE OR DELETE ON tiers
  FOR EACH ROW EXECUTE FUNCTION lc_audit_trigger();

CREATE TRIGGER tier_thresholds_audit
  AFTER INSERT OR UPDATE OR DELETE ON tier_thresholds
  FOR EACH ROW EXECUTE FUNCTION lc_audit_trigger();

CREATE TRIGGER tier_benefits_audit
  AFTER INSERT OR UPDATE OR DELETE ON tier_benefits
  FOR EACH ROW EXECUTE FUNCTION lc_audit_trigger();

CREATE TRIGGER points_rules_audit
  AFTER INSERT OR UPDATE OR DELETE ON points_rules
  FOR EACH ROW EXECUTE FUNCTION lc_audit_trigger();

-- Admin RBAC
CREATE TRIGGER admin_users_audit
  AFTER INSERT OR UPDATE OR DELETE ON admin_users
  FOR EACH ROW EXECUTE FUNCTION lc_audit_trigger();

CREATE TRIGGER admin_user_hotel_assignments_audit
  AFTER INSERT OR UPDATE OR DELETE ON admin_user_hotel_assignments
  FOR EACH ROW EXECUTE FUNCTION lc_audit_trigger();

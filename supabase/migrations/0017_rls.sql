-- 0017_rls.sql
-- Enable RLS + policies for all tenant-scoped tables.
-- Reference catalogs (currencies, regions, pms_systems, currency_rates) get permissive read for authenticated.
-- service_role always bypasses RLS, so seed and migrations work without restriction.

-- ===== Reference catalogs: read-only to authenticated =====
ALTER TABLE currencies      ENABLE ROW LEVEL SECURITY;
ALTER TABLE regions         ENABLE ROW LEVEL SECURITY;
ALTER TABLE pms_systems     ENABLE ROW LEVEL SECURITY;
ALTER TABLE currency_rates  ENABLE ROW LEVEL SECURITY;

CREATE POLICY currencies_read_all      ON currencies      FOR SELECT TO authenticated USING (true);
CREATE POLICY regions_read_all         ON regions         FOR SELECT TO authenticated USING (true);
CREATE POLICY pms_systems_read_all     ON pms_systems     FOR SELECT TO authenticated USING (true);
CREATE POLICY currency_rates_read_all  ON currency_rates  FOR SELECT TO authenticated USING (true);

-- ===== Chain-scoped tables =====
-- Pattern: full access if loyco_admin or chain matches JWT chain_group_id.

ALTER TABLE chain_groups ENABLE ROW LEVEL SECURITY;
CREATE POLICY chain_groups_access ON chain_groups FOR ALL TO authenticated
  USING (lc_can_access_chain(id))
  WITH CHECK (lc_can_access_chain(id));

ALTER TABLE hotels ENABLE ROW LEVEL SECURITY;
CREATE POLICY hotels_access ON hotels FOR ALL TO authenticated
  USING (lc_can_access_hotel(chain_group_id, id))
  WITH CHECK (lc_can_access_hotel(chain_group_id, id));

ALTER TABLE hotel_pms_connections ENABLE ROW LEVEL SECURITY;
CREATE POLICY hotel_pms_connections_access ON hotel_pms_connections FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM hotels h WHERE h.id = hotel_id AND lc_can_access_hotel(h.chain_group_id, h.id)))
  WITH CHECK (EXISTS (SELECT 1 FROM hotels h WHERE h.id = hotel_id AND lc_can_access_hotel(h.chain_group_id, h.id)));

-- Loyalty config
ALTER TABLE loyalty_programs ENABLE ROW LEVEL SECURITY;
CREATE POLICY loyalty_programs_access ON loyalty_programs FOR ALL TO authenticated
  USING (lc_can_access_chain(chain_group_id)) WITH CHECK (lc_can_access_chain(chain_group_id));

ALTER TABLE tiers ENABLE ROW LEVEL SECURITY;
CREATE POLICY tiers_access ON tiers FOR ALL TO authenticated
  USING (lc_can_access_chain(chain_group_id)) WITH CHECK (lc_can_access_chain(chain_group_id));

ALTER TABLE tier_thresholds ENABLE ROW LEVEL SECURITY;
CREATE POLICY tier_thresholds_access ON tier_thresholds FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM tiers t WHERE t.id = tier_id AND lc_can_access_chain(t.chain_group_id)))
  WITH CHECK (EXISTS (SELECT 1 FROM tiers t WHERE t.id = tier_id AND lc_can_access_chain(t.chain_group_id)));

ALTER TABLE tier_benefits ENABLE ROW LEVEL SECURITY;
CREATE POLICY tier_benefits_access ON tier_benefits FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM tiers t WHERE t.id = tier_id AND lc_can_access_chain(t.chain_group_id)))
  WITH CHECK (EXISTS (SELECT 1 FROM tiers t WHERE t.id = tier_id AND lc_can_access_chain(t.chain_group_id)));

ALTER TABLE points_rules ENABLE ROW LEVEL SECURITY;
CREATE POLICY points_rules_access ON points_rules FOR ALL TO authenticated
  USING (lc_can_access_chain(chain_group_id)) WITH CHECK (lc_can_access_chain(chain_group_id));

ALTER TABLE rewards ENABLE ROW LEVEL SECURITY;
CREATE POLICY rewards_access ON rewards FOR ALL TO authenticated
  USING (lc_can_access_chain(chain_group_id)) WITH CHECK (lc_can_access_chain(chain_group_id));

-- Members
ALTER TABLE members ENABLE ROW LEVEL SECURITY;
CREATE POLICY members_access ON members FOR ALL TO authenticated
  USING (lc_can_access_chain(chain_group_id)) WITH CHECK (lc_can_access_chain(chain_group_id));

ALTER TABLE member_external_ids ENABLE ROW LEVEL SECURITY;
CREATE POLICY member_external_ids_access ON member_external_ids FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM members m WHERE m.id = member_id AND lc_can_access_chain(m.chain_group_id)))
  WITH CHECK (EXISTS (SELECT 1 FROM members m WHERE m.id = member_id AND lc_can_access_chain(m.chain_group_id)));

ALTER TABLE member_consents ENABLE ROW LEVEL SECURITY;
CREATE POLICY member_consents_access ON member_consents FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM members m WHERE m.id = member_id AND lc_can_access_chain(m.chain_group_id)))
  WITH CHECK (EXISTS (SELECT 1 FROM members m WHERE m.id = member_id AND lc_can_access_chain(m.chain_group_id)));

ALTER TABLE member_tier_history ENABLE ROW LEVEL SECURITY;
CREATE POLICY member_tier_history_access ON member_tier_history FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM members m WHERE m.id = member_id AND lc_can_access_chain(m.chain_group_id)))
  WITH CHECK (EXISTS (SELECT 1 FROM members m WHERE m.id = member_id AND lc_can_access_chain(m.chain_group_id)));

ALTER TABLE member_attributes ENABLE ROW LEVEL SECURITY;
CREATE POLICY member_attributes_access ON member_attributes FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM members m WHERE m.id = member_id AND lc_can_access_chain(m.chain_group_id)))
  WITH CHECK (EXISTS (SELECT 1 FROM members m WHERE m.id = member_id AND lc_can_access_chain(m.chain_group_id)));

-- Bookings
ALTER TABLE bookings ENABLE ROW LEVEL SECURITY;
CREATE POLICY bookings_access ON bookings FOR ALL TO authenticated
  USING (lc_can_access_hotel(chain_group_id, hotel_id))
  WITH CHECK (lc_can_access_hotel(chain_group_id, hotel_id));

ALTER TABLE room_stays ENABLE ROW LEVEL SECURITY;
CREATE POLICY room_stays_access ON room_stays FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM hotels h WHERE h.id = hotel_id AND lc_can_access_hotel(h.chain_group_id, h.id)))
  WITH CHECK (EXISTS (SELECT 1 FROM hotels h WHERE h.id = hotel_id AND lc_can_access_hotel(h.chain_group_id, h.id)));

ALTER TABLE booking_segments ENABLE ROW LEVEL SECURITY;
CREATE POLICY booking_segments_access ON booking_segments FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM bookings b WHERE b.id = booking_id AND lc_can_access_hotel(b.chain_group_id, b.hotel_id)))
  WITH CHECK (EXISTS (SELECT 1 FROM bookings b WHERE b.id = booking_id AND lc_can_access_hotel(b.chain_group_id, b.hotel_id)));

ALTER TABLE booking_status_history ENABLE ROW LEVEL SECURITY;
CREATE POLICY booking_status_history_access ON booking_status_history FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM bookings b WHERE b.id = booking_id AND lc_can_access_hotel(b.chain_group_id, b.hotel_id)))
  WITH CHECK (EXISTS (SELECT 1 FROM bookings b WHERE b.id = booking_id AND lc_can_access_hotel(b.chain_group_id, b.hotel_id)));

-- Transactions
ALTER TABLE transactions ENABLE ROW LEVEL SECURITY;
CREATE POLICY transactions_access ON transactions FOR ALL TO authenticated
  USING (lc_can_access_hotel(chain_group_id, hotel_id))
  WITH CHECK (lc_can_access_hotel(chain_group_id, hotel_id));

ALTER TABLE transaction_lines ENABLE ROW LEVEL SECURITY;
CREATE POLICY transaction_lines_access ON transaction_lines FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM transactions t WHERE t.id = transaction_id AND lc_can_access_hotel(t.chain_group_id, t.hotel_id)))
  WITH CHECK (EXISTS (SELECT 1 FROM transactions t WHERE t.id = transaction_id AND lc_can_access_hotel(t.chain_group_id, t.hotel_id)));

-- Points
ALTER TABLE point_transactions ENABLE ROW LEVEL SECURITY;
CREATE POLICY point_transactions_access ON point_transactions FOR ALL TO authenticated
  USING (lc_can_access_chain(chain_group_id)) WITH CHECK (lc_can_access_chain(chain_group_id));

ALTER TABLE point_redemptions ENABLE ROW LEVEL SECURITY;
CREATE POLICY point_redemptions_access ON point_redemptions FOR ALL TO authenticated
  USING (lc_can_access_chain(chain_group_id)) WITH CHECK (lc_can_access_chain(chain_group_id));

-- Communications
ALTER TABLE communication_templates ENABLE ROW LEVEL SECURITY;
CREATE POLICY communication_templates_access ON communication_templates FOR ALL TO authenticated
  USING (lc_can_access_chain(chain_group_id)) WITH CHECK (lc_can_access_chain(chain_group_id));

ALTER TABLE communications ENABLE ROW LEVEL SECURITY;
CREATE POLICY communications_access ON communications FOR ALL TO authenticated
  USING (lc_can_access_chain(chain_group_id)) WITH CHECK (lc_can_access_chain(chain_group_id));

-- Marketing
ALTER TABLE segments ENABLE ROW LEVEL SECURITY;
CREATE POLICY segments_access ON segments FOR ALL TO authenticated
  USING (lc_can_access_chain(chain_group_id)) WITH CHECK (lc_can_access_chain(chain_group_id));

ALTER TABLE campaigns ENABLE ROW LEVEL SECURITY;
CREATE POLICY campaigns_access ON campaigns FOR ALL TO authenticated
  USING (lc_can_access_chain(chain_group_id)) WITH CHECK (lc_can_access_chain(chain_group_id));

ALTER TABLE campaign_recipients ENABLE ROW LEVEL SECURITY;
CREATE POLICY campaign_recipients_access ON campaign_recipients FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM campaigns c WHERE c.id = campaign_id AND lc_can_access_chain(c.chain_group_id)))
  WITH CHECK (EXISTS (SELECT 1 FROM campaigns c WHERE c.id = campaign_id AND lc_can_access_chain(c.chain_group_id)));

ALTER TABLE automations ENABLE ROW LEVEL SECURITY;
CREATE POLICY automations_access ON automations FOR ALL TO authenticated
  USING (lc_can_access_chain(chain_group_id)) WITH CHECK (lc_can_access_chain(chain_group_id));

ALTER TABLE automation_steps ENABLE ROW LEVEL SECURITY;
CREATE POLICY automation_steps_access ON automation_steps FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM automations a WHERE a.id = automation_id AND lc_can_access_chain(a.chain_group_id)))
  WITH CHECK (EXISTS (SELECT 1 FROM automations a WHERE a.id = automation_id AND lc_can_access_chain(a.chain_group_id)));

ALTER TABLE automation_runs ENABLE ROW LEVEL SECURITY;
CREATE POLICY automation_runs_access ON automation_runs FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM automations a WHERE a.id = automation_id AND lc_can_access_chain(a.chain_group_id)))
  WITH CHECK (EXISTS (SELECT 1 FROM automations a WHERE a.id = automation_id AND lc_can_access_chain(a.chain_group_id)));

-- Admin / RBAC
-- admin_users: loyco_admin sees all; chain_admin sees only their chain's; user always sees own row
ALTER TABLE admin_users ENABLE ROW LEVEL SECURITY;
CREATE POLICY admin_users_self_or_scope ON admin_users FOR SELECT TO authenticated
  USING (
    id = (NULLIF(lc_jwt_claim('sub'), ''))::uuid
    OR lc_is_loyco_admin()
    OR lc_can_access_chain(chain_group_id)
  );
CREATE POLICY admin_users_modify ON admin_users FOR ALL TO authenticated
  USING (lc_is_loyco_admin() OR (lc_current_role() = 'chain_admin' AND lc_can_access_chain(chain_group_id)))
  WITH CHECK (lc_is_loyco_admin() OR (lc_current_role() = 'chain_admin' AND lc_can_access_chain(chain_group_id)));

ALTER TABLE admin_user_hotel_assignments ENABLE ROW LEVEL SECURITY;
CREATE POLICY admin_user_hotel_assignments_access ON admin_user_hotel_assignments FOR ALL TO authenticated
  USING (
    lc_is_loyco_admin()
    OR EXISTS (
      SELECT 1 FROM admin_users au
       WHERE au.id = admin_user_id
         AND lc_can_access_chain(au.chain_group_id)
    )
  )
  WITH CHECK (
    lc_is_loyco_admin()
    OR EXISTS (
      SELECT 1 FROM admin_users au
       WHERE au.id = admin_user_id
         AND lc_can_access_chain(au.chain_group_id)
    )
  );

-- Audit log: read-only via API; writes happen via trigger as elevated. Read scoped by chain.
ALTER TABLE audit_log ENABLE ROW LEVEL SECURITY;
CREATE POLICY audit_log_read ON audit_log FOR SELECT TO authenticated
  USING (
    lc_is_loyco_admin()
    OR (chain_group_id IS NOT NULL AND lc_can_access_chain(chain_group_id))
  );

-- PMS sync
ALTER TABLE pms_imports ENABLE ROW LEVEL SECURITY;
CREATE POLICY pms_imports_access ON pms_imports FOR ALL TO authenticated
  USING (chain_group_id IS NULL AND lc_is_loyco_admin() OR lc_can_access_chain(chain_group_id))
  WITH CHECK (chain_group_id IS NULL AND lc_is_loyco_admin() OR lc_can_access_chain(chain_group_id));

ALTER TABLE pms_raw_payloads ENABLE ROW LEVEL SECURITY;
CREATE POLICY pms_raw_payloads_access ON pms_raw_payloads FOR ALL TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM pms_imports pi
       WHERE pi.id = import_id
         AND (pi.chain_group_id IS NULL AND lc_is_loyco_admin() OR lc_can_access_chain(pi.chain_group_id))
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM pms_imports pi
       WHERE pi.id = import_id
         AND (pi.chain_group_id IS NULL AND lc_is_loyco_admin() OR lc_can_access_chain(pi.chain_group_id))
    )
  );

ALTER TABLE pms_sync_errors ENABLE ROW LEVEL SECURITY;
CREATE POLICY pms_sync_errors_access ON pms_sync_errors FOR ALL TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM pms_imports pi
       WHERE pi.id = import_id
         AND (pi.chain_group_id IS NULL AND lc_is_loyco_admin() OR lc_can_access_chain(pi.chain_group_id))
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM pms_imports pi
       WHERE pi.id = import_id
         AND (pi.chain_group_id IS NULL AND lc_is_loyco_admin() OR lc_can_access_chain(pi.chain_group_id))
    )
  );

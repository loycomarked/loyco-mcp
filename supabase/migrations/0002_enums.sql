-- 0002_enums.sql
-- All enum types used across the schema. Grouped by domain.

-- Tenancy
CREATE TYPE chain_status AS ENUM ('active', 'paused', 'archived');
CREATE TYPE hotel_status AS ENUM ('active', 'opening', 'closed', 'archived');
CREATE TYPE pms_system_code AS ENUM ('stayntouch', 'mews', 'protel_air', 'visbook', 'other');

-- Members
CREATE TYPE member_status AS ENUM ('active', 'inactive', 'suspended', 'merged', 'archived');
CREATE TYPE member_gender AS ENUM ('male', 'female', 'other', 'unknown');
CREATE TYPE consent_type AS ENUM ('email', 'sms', 'offer', 'user_agreement');
CREATE TYPE external_id_type AS ENUM (
  'fm_old_id',
  'sj_prio_id',
  'guest_connect_id',
  'pms_guest_id',
  'legacy_other'
);

-- Loyalty
CREATE TYPE tier_metric AS ENUM ('points', 'nights', 'revenue');
CREATE TYPE point_transaction_type AS ENUM (
  'earn_pending',
  'earn_release',
  'redeem',
  'manual_adjustment',
  'expire',
  'reverse'
);
CREATE TYPE point_transaction_status AS ENUM ('pending', 'posted', 'reversed', 'expired');

-- Bookings
CREATE TYPE booking_channel AS ENUM ('direct', 'ota', 'corporate', 'group', 'walk_in', 'travel_agency', 'other');
CREATE TYPE booking_status AS ENUM ('upcoming', 'in_house', 'checked_out', 'cancelled', 'no_show');

-- Transactions
CREATE TYPE transaction_type AS ENUM ('charge', 'refund', 'adjustment', 'gift_card');
CREATE TYPE transaction_status AS ENUM ('pending', 'posted', 'reversed', 'failed');

-- Communications
CREATE TYPE comm_channel AS ENUM ('sms', 'email', 'push');
CREATE TYPE comm_direction AS ENUM ('outbound', 'inbound');
CREATE TYPE comm_status AS ENUM ('queued', 'sent', 'delivered', 'failed', 'bounced', 'opened', 'clicked');
CREATE TYPE comm_category AS ENUM (
  'personal_invitation',
  'transactional',
  'marketing_campaign',
  'automation',
  'service'
);

-- Marketing
CREATE TYPE campaign_status AS ENUM ('draft', 'scheduled', 'sending', 'completed', 'cancelled', 'paused');
CREATE TYPE automation_trigger AS ENUM (
  'ota_booking_received',
  'direct_booking_received',
  'booking_cancelled',
  'check_in',
  'check_out',
  'tier_upgrade',
  'tier_downgrade',
  'birthday',
  'anniversary',
  'points_expiring',
  'inactive_member'
);
CREATE TYPE automation_status AS ENUM ('draft', 'active', 'paused', 'archived');
CREATE TYPE automation_run_status AS ENUM ('queued', 'running', 'completed', 'failed', 'skipped');
CREATE TYPE automation_action_type AS ENUM (
  'send_sms',
  'send_email',
  'send_push',
  'wait',
  'add_tag',
  'remove_tag',
  'adjust_points',
  'webhook'
);

-- Admin / RBAC
CREATE TYPE app_role AS ENUM ('loyco_admin', 'chain_admin', 'hotel_staff', 'analyst');
CREATE TYPE audit_action AS ENUM ('insert', 'update', 'delete', 'login', 'logout', 'role_change', 'manual_adjust');

-- PMS sync
CREATE TYPE pms_import_status AS ENUM ('queued', 'running', 'completed', 'failed', 'partial');

-- Tier reason (why a member was promoted/demoted)
CREATE TYPE tier_change_reason AS ENUM (
  'qualified_by_points',
  'qualified_by_nights',
  'qualified_by_revenue',
  'manual_override',
  'demoted_lapsed',
  'initial_assignment'
);

-- Reward types
CREATE TYPE reward_type AS ENUM (
  'free_night',
  'discount_percent',
  'discount_amount',
  'late_checkout',
  'room_upgrade',
  'amenity',
  'gift_card',
  'experience'
);

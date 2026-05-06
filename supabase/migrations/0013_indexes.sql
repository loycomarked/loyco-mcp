-- 0013_indexes.sql
-- Secondary indexes beyond PK/FK and per-table indexes already created.

-- Members
CREATE INDEX members_chain_status_idx ON members(chain_group_id, status);
CREATE INDEX members_joined_at_idx ON members(joined_at DESC);
CREATE INDEX members_current_tier_idx ON members(current_tier_id, status);
CREATE INDEX members_program_idx ON members(program_id);
CREATE INDEX members_recruitment_hotel_idx ON members(recruitment_hotel_id);
CREATE INDEX members_searchable_tsv_gin ON members USING gin (searchable_tsv);
CREATE INDEX members_email_trgm ON members USING gin (email extensions.gin_trgm_ops) WHERE email IS NOT NULL;
CREATE INDEX members_full_name_trgm ON members USING gin (full_name extensions.gin_trgm_ops) WHERE full_name IS NOT NULL;

-- Hotels
CREATE INDEX hotels_chain_status_idx ON hotels(chain_group_id, status);

-- Bookings
CREATE INDEX bookings_member_arrival_idx ON bookings(member_id, arrival_date DESC);
CREATE INDEX bookings_hotel_arrival_idx ON bookings(hotel_id, arrival_date);
CREATE INDEX bookings_chain_arrival_idx ON bookings(chain_group_id, arrival_date);
CREATE INDEX bookings_channel_status_idx ON bookings(channel, status);
CREATE INDEX bookings_status_idx ON bookings(status);
CREATE INDEX bookings_arrival_idx ON bookings(arrival_date);
CREATE INDEX bookings_check_in_idx ON bookings(check_in_at) WHERE check_in_at IS NOT NULL;

-- Booking segments
CREATE INDEX booking_segments_market_segment_idx ON booking_segments(market_segment_code);
CREATE INDEX booking_segments_channel_manager_idx ON booking_segments(channel_manager);
CREATE INDEX booking_segments_rate_group_idx ON booking_segments(rate_group_code);

-- Transactions
CREATE INDEX transactions_member_posting_idx ON transactions(member_id, posting_date DESC);
CREATE INDEX transactions_booking_idx ON transactions(booking_id);
CREATE INDEX transactions_chain_posting_idx ON transactions(chain_group_id, posting_date);
CREATE INDEX transactions_hotel_posting_idx ON transactions(hotel_id, posting_date);
CREATE INDEX transactions_status_idx ON transactions(status);
CREATE INDEX transactions_is_ota_idx ON transactions(is_ota);

-- Communications
CREATE INDEX communications_member_sent_idx ON communications(member_id, sent_at DESC);
CREATE INDEX communications_chain_sent_idx ON communications(chain_group_id, sent_at DESC);
CREATE INDEX communications_channel_status_idx ON communications(channel, status);
CREATE INDEX communications_campaign_idx ON communications(campaign_id);
CREATE INDEX communications_automation_run_idx ON communications(automation_run_id);
CREATE INDEX communications_category_idx ON communications(category);

-- Campaigns
CREATE INDEX campaigns_chain_status_idx ON campaigns(chain_group_id, status);
CREATE INDEX campaigns_start_date_idx ON campaigns(start_date);

-- Currency rates lookups (for FX conversion in views)
CREATE INDEX currency_rates_pair_idx ON currency_rates(from_ccy, to_ccy);

-- Loyalty config lookups
CREATE INDEX points_rules_program_priority_idx ON points_rules(program_id, priority DESC) WHERE is_active = true;
CREATE INDEX points_rules_hotel_idx ON points_rules(hotel_id) WHERE hotel_id IS NOT NULL;
CREATE INDEX tier_thresholds_tier_metric_idx ON tier_thresholds(tier_id, metric);

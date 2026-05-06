-- 0006_bookings.sql
-- Bookings (= PMS reservations), per-room stays, segment metadata, status history.

CREATE TABLE bookings (
  id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_group_id           uuid NOT NULL REFERENCES chain_groups(id) ON DELETE RESTRICT,
  hotel_id                 uuid NOT NULL REFERENCES hotels(id) ON DELETE RESTRICT,
  member_id                uuid REFERENCES members(id) ON DELETE SET NULL,
  pms_code                 pms_system_code NOT NULL,
  pms_reservation_no       text NOT NULL,
  pms_confirmation_code    text,
  channel                  booking_channel NOT NULL DEFAULT 'other',
  status                   booking_status NOT NULL DEFAULT 'upcoming',
  arrival_date             date NOT NULL,
  departure_date           date NOT NULL,
  check_in_at              timestamptz,
  check_out_at             timestamptz,
  nights                   int GENERATED ALWAYS AS (greatest((departure_date - arrival_date)::int, 0)) STORED,
  num_guests               int CHECK (num_guests IS NULL OR num_guests > 0),
  num_rooms                int CHECK (num_rooms IS NULL OR num_rooms > 0),
  total_amount             numeric(14,2),
  currency                 char(3) REFERENCES currencies(code),
  paid_amount              numeric(14,2),
  reservation_source_label text,                              -- raw label from PMS, e.g. 'StayNTouchIntegration', 'ChannelManager'
  is_member_booking        boolean NOT NULL DEFAULT false,
  returning_member         boolean,
  cancelled_at             timestamptz,
  cancellation_reason      text,
  booked_at                timestamptz,                       -- when the reservation was made
  metadata                 jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at               timestamptz NOT NULL DEFAULT now(),
  updated_at               timestamptz NOT NULL DEFAULT now(),
  CHECK (departure_date >= arrival_date),
  UNIQUE (pms_code, pms_reservation_no)
);

CREATE TABLE room_stays (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id      uuid NOT NULL REFERENCES bookings(id) ON DELETE CASCADE,
  hotel_id        uuid NOT NULL REFERENCES hotels(id) ON DELETE CASCADE,
  room_number     text,
  room_type_code  text,
  room_type_name  text,
  arrival_date    date NOT NULL,
  departure_date  date NOT NULL,
  guests_count    int CHECK (guests_count IS NULL OR guests_count > 0),
  rate_amount_per_night numeric(14,2),
  currency        char(3) REFERENCES currencies(code),
  metadata        jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at      timestamptz NOT NULL DEFAULT now(),
  CHECK (departure_date >= arrival_date)
);

CREATE INDEX room_stays_booking_idx ON room_stays(booking_id);

CREATE TABLE booking_segments (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id            uuid NOT NULL UNIQUE REFERENCES bookings(id) ON DELETE CASCADE,
  market_segment_code   text,                                  -- e.g. 'CGN'
  market_segment_label  text,                                  -- e.g. 'CGN - Corporate groups on negotiated rates'
  rate_group_code       text,                                  -- e.g. 'OTA 48 timer', 'NRF-WEB'
  rate_code             text,                                  -- e.g. 'Flex Booking', 'NonRef Booking'
  source_code           text,                                  -- e.g. 'Company direct'
  promotion_code        text,
  business_segment      text,                                  -- e.g. 'Rack rate', 'Unqualified discount rate'
  channel_manager       text,                                  -- e.g. 'Booking.com'
  travel_agency         text,
  origin                text,                                  -- e.g. 'ChannelManager', 'Direct', 'Walk-In'
  service_name          text,                                  -- e.g. 'Accommodation', 'Spa Package'
  metadata              jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at            timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE booking_status_history (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id    uuid NOT NULL REFERENCES bookings(id) ON DELETE CASCADE,
  from_status   booking_status,
  to_status     booking_status NOT NULL,
  occurred_at   timestamptz NOT NULL DEFAULT now(),
  changed_by    uuid,                                          -- nullable; null for PMS-driven changes
  notes         text,
  context       jsonb NOT NULL DEFAULT '{}'::jsonb
);

CREATE INDEX booking_status_history_booking_time_idx
  ON booking_status_history (booking_id, occurred_at DESC);

-- 0007_transactions.sql
-- Financial transactions tied to bookings, with line items mirroring real PMS exports.

CREATE TABLE transactions (
  id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_group_id           uuid NOT NULL REFERENCES chain_groups(id) ON DELETE RESTRICT,
  hotel_id                 uuid NOT NULL REFERENCES hotels(id) ON DELETE RESTRICT,
  booking_id               uuid REFERENCES bookings(id) ON DELETE SET NULL,
  member_id                uuid REFERENCES members(id) ON DELETE SET NULL,
  external_transaction_id  text,                                     -- PMS-side transaction id (Loyco's "Transaction ID" column)
  external_reference       text,                                     -- additional reference if any
  transaction_type         transaction_type NOT NULL DEFAULT 'charge',
  status                   transaction_status NOT NULL DEFAULT 'posted',
  posting_date             date NOT NULL,
  transaction_date         date NOT NULL,
  -- Currency model per ADR-0005
  posted_amount            numeric(14,2) NOT NULL,
  posted_currency          char(3) NOT NULL REFERENCES currencies(code),
  original_amount          numeric(14,2),
  original_currency        char(3) REFERENCES currencies(code),
  fx_rate                  numeric(14,6),
  fx_rate_date             date,
  paid_amount              numeric(14,2),
  -- Bonus / point info embedded at transaction grain (mirrors real export)
  bonus_percent_at_posting numeric(5,2),
  bonus_earned_amount      numeric(14,2),
  bonus_released_amount    numeric(14,2) NOT NULL DEFAULT 0,
  giftcard_applied_amount  numeric(14,2) NOT NULL DEFAULT 0,
  -- Channel + segment + Mastercard cashback (kept for richness)
  is_ota                   boolean NOT NULL DEFAULT false,
  segment_label            text,
  mc_kickback_percent      numeric(5,2),
  mc_kickback_amount       numeric(14,2),
  metadata                 jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at               timestamptz NOT NULL DEFAULT now(),
  updated_at               timestamptz NOT NULL DEFAULT now(),
  UNIQUE (chain_group_id, external_transaction_id)
);

CREATE TABLE transaction_lines (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  transaction_id  uuid NOT NULL REFERENCES transactions(id) ON DELETE CASCADE,
  product_type    text NOT NULL,                       -- e.g. 'Merchandise', 'Accommodation', 'Food', 'Beverage', 'Spa'
  line_info       text,                                -- e.g. 'RoomType:4421'
  quantity        numeric(14,4) NOT NULL DEFAULT 1,
  unit_amount     numeric(14,4),
  amount          numeric(14,2) NOT NULL,
  currency        char(3) NOT NULL REFERENCES currencies(code),
  bonus_factor    numeric(8,4) NOT NULL DEFAULT 1,
  product_code    text,
  metadata        jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at      timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX transaction_lines_transaction_idx ON transaction_lines(transaction_id);

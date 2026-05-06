-- 0003_tenancy.sql
-- Tenant boundary tables + reference catalogs (currencies, regions, PMS systems).

CREATE TABLE currencies (
  code            char(3)   PRIMARY KEY,
  name            text      NOT NULL,
  symbol          text,
  decimals        smallint  NOT NULL DEFAULT 2,
  created_at      timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE regions (
  code               char(2) PRIMARY KEY,
  name               text NOT NULL,
  default_currency   char(3) REFERENCES currencies(code),
  created_at         timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE pms_systems (
  code               pms_system_code PRIMARY KEY,
  display_name       text NOT NULL,
  vendor_url         text,
  supported_features jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at         timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE chain_groups (
  id                       uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  slug                     text        NOT NULL UNIQUE,
  name                     text        NOT NULL,
  legal_name               text,
  default_currency         char(3)     NOT NULL REFERENCES currencies(code),
  reporting_currency       char(3)     NOT NULL REFERENCES currencies(code),
  default_locale           text        NOT NULL DEFAULT 'nb-NO',
  headquarters_country     char(2)     REFERENCES regions(code),
  status                   chain_status NOT NULL DEFAULT 'active',
  brand_color_hex          text,
  logo_url                 text,
  support_email            text,
  support_phone            text,
  founded_at               date,
  metadata                 jsonb       NOT NULL DEFAULT '{}'::jsonb,
  created_at               timestamptz NOT NULL DEFAULT now(),
  updated_at               timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE hotels (
  id                       uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_group_id           uuid        NOT NULL REFERENCES chain_groups(id) ON DELETE RESTRICT,
  slug                     text        NOT NULL,
  name                     text        NOT NULL,
  brand_property_code      text,             -- external code at chain level (e.g., "First Hotel Royal" -> "FHR")
  status                   hotel_status NOT NULL DEFAULT 'active',
  address_line1            text,
  address_line2            text,
  postal_code              text,
  city                     text,
  country_code             char(2)     REFERENCES regions(code),
  timezone                 text        NOT NULL DEFAULT 'Europe/Oslo',
  latitude                 numeric(9,6),
  longitude                numeric(9,6),
  room_count               int         CHECK (room_count IS NULL OR room_count >= 0),
  opening_date             date,
  default_currency         char(3)     NOT NULL REFERENCES currencies(code),
  default_pms              pms_system_code,
  contact_email            text,
  contact_phone            text,
  metadata                 jsonb       NOT NULL DEFAULT '{}'::jsonb,
  created_at               timestamptz NOT NULL DEFAULT now(),
  updated_at               timestamptz NOT NULL DEFAULT now(),
  UNIQUE (chain_group_id, slug)
);

CREATE TABLE hotel_pms_connections (
  id                    uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  hotel_id              uuid        NOT NULL REFERENCES hotels(id) ON DELETE CASCADE,
  pms_code              pms_system_code NOT NULL REFERENCES pms_systems(code),
  external_property_id  text        NOT NULL,    -- the ID this hotel has inside that PMS
  external_program_id   text,                    -- e.g., StayNTouch program/group id
  is_active             boolean     NOT NULL DEFAULT true,
  last_synced_at        timestamptz,
  connection_metadata   jsonb       NOT NULL DEFAULT '{}'::jsonb,
  created_at            timestamptz NOT NULL DEFAULT now(),
  updated_at            timestamptz NOT NULL DEFAULT now(),
  UNIQUE (pms_code, external_property_id)
);

CREATE UNIQUE INDEX hotel_pms_connections_one_active_per_hotel
  ON hotel_pms_connections (hotel_id) WHERE is_active = true;

CREATE TABLE currency_rates (
  from_ccy    char(3) NOT NULL REFERENCES currencies(code),
  to_ccy      char(3) NOT NULL REFERENCES currencies(code),
  rate_date   date    NOT NULL,
  rate        numeric(14,6) NOT NULL CHECK (rate > 0),
  source      text    NOT NULL DEFAULT 'seed',
  created_at  timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (from_ccy, to_ccy, rate_date)
);

-- Reference catalog seed (currencies + regions + pms systems) lives with structure
-- because it's required immediately by all chain/hotel rows. ISO 4217 subset.
INSERT INTO currencies (code, name, symbol, decimals) VALUES
  ('NOK', 'Norwegian Krone',     'kr', 2),
  ('SEK', 'Swedish Krona',       'kr', 2),
  ('DKK', 'Danish Krone',        'kr', 2),
  ('EUR', 'Euro',                '€',  2),
  ('USD', 'US Dollar',           '$',  2),
  ('GBP', 'Pound Sterling',      '£',  2),
  ('ISK', 'Icelandic Krona',     'kr', 0),
  ('CHF', 'Swiss Franc',         'CHF',2)
ON CONFLICT (code) DO NOTHING;

INSERT INTO regions (code, name, default_currency) VALUES
  ('NO', 'Norway',  'NOK'),
  ('SE', 'Sweden',  'SEK'),
  ('DK', 'Denmark', 'DKK'),
  ('FI', 'Finland', 'EUR'),
  ('IS', 'Iceland', 'ISK'),
  ('DE', 'Germany', 'EUR'),
  ('GB', 'United Kingdom', 'GBP'),
  ('US', 'United States',  'USD'),
  ('NL', 'Netherlands',    'EUR'),
  ('PL', 'Poland',         'EUR'),
  ('ES', 'Spain',          'EUR'),
  ('IT', 'Italy',          'EUR'),
  ('FR', 'France',         'EUR'),
  ('BE', 'Belgium',        'EUR'),
  ('AT', 'Austria',        'EUR'),
  ('CH', 'Switzerland',    'CHF')
ON CONFLICT (code) DO NOTHING;

INSERT INTO pms_systems (code, display_name, vendor_url) VALUES
  ('stayntouch', 'Stayntouch',  'https://www.stayntouch.com'),
  ('mews',       'Mews',        'https://www.mews.com'),
  ('protel_air', 'Protel Air',  'https://www.protel.net'),
  ('visbook',    'Visbook',     'https://www.visbook.com'),
  ('other',      'Other / Unknown', NULL)
ON CONFLICT (code) DO NOTHING;

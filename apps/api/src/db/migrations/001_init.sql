-- 001_init.sql : core schema for Ardh Sainik Canteen Store Mart
-- Money columns are NUMERIC(12,2). Coins are integers. All timestamps are timestamptz (UTC).

CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ---------------------------------------------------------------- helpers
CREATE OR REPLACE FUNCTION forbid_mutation() RETURNS trigger AS $$
BEGIN
  RAISE EXCEPTION '% is append-only (% not allowed)', TG_TABLE_NAME, TG_OP USING ERRCODE = '42501';
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION touch_updated_at() RETURNS trigger AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ---------------------------------------------------------------- settings
CREATE TABLE settings (
  key         text PRIMARY KEY,
  value       jsonb NOT NULL,
  updated_at  timestamptz NOT NULL DEFAULT now(),
  updated_by  uuid
);

-- ---------------------------------------------------------------- users & auth
CREATE TABLE users (
  id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  phone                    text NOT NULL UNIQUE,
  name                     text,
  email                    text,
  language                 text NOT NULL DEFAULT 'en' CHECK (language IN ('en','hi')),
  status                   text NOT NULL DEFAULT 'active' CHECK (status IN ('active','blocked','deleted')),
  deletion_requested_at    timestamptz,
  deleted_at               timestamptz,
  created_at               timestamptz NOT NULL DEFAULT now(),
  updated_at               timestamptz NOT NULL DEFAULT now(),
  -- deleted accounts keep a non-identifying placeholder ('deleted:<id>') instead of the real number
  CHECK (status = 'deleted' OR phone ~ '^[6-9][0-9]{9}$')
);
CREATE TRIGGER users_touch BEFORE UPDATE ON users FOR EACH ROW EXECUTE FUNCTION touch_updated_at();

CREATE TABLE auth_otps (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  phone       text NOT NULL,
  code_hash   text NOT NULL,
  expires_at  timestamptz NOT NULL,
  attempts    int NOT NULL DEFAULT 0,
  consumed_at timestamptz,
  ip          text,
  created_at  timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX auth_otps_phone_created ON auth_otps (phone, created_at DESC);

CREATE TABLE refresh_tokens (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token_hash  text NOT NULL UNIQUE,
  device      text,
  expires_at  timestamptz NOT NULL,
  revoked_at  timestamptz,
  created_at  timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX refresh_tokens_user ON refresh_tokens (user_id);

CREATE TABLE device_tokens (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token       text NOT NULL UNIQUE,
  platform    text NOT NULL DEFAULT 'android',
  created_at  timestamptz NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------- admin users
CREATE TABLE admin_users (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  email           text NOT NULL UNIQUE,
  name            text NOT NULL,
  password_hash   text NOT NULL,
  role            text NOT NULL CHECK (role IN ('owner','manager','staff')),
  extra_permissions text[] NOT NULL DEFAULT '{}',
  status          text NOT NULL DEFAULT 'active' CHECK (status IN ('active','disabled')),
  failed_logins   int NOT NULL DEFAULT 0,
  locked_until    timestamptz,
  last_login_at   timestamptz,
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now()
);
CREATE TRIGGER admin_users_touch BEFORE UPDATE ON admin_users FOR EACH ROW EXECUTE FUNCTION touch_updated_at();

-- ---------------------------------------------------------------- delivery zones & addresses
CREATE TABLE delivery_zones (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name        text NOT NULL UNIQUE,
  name_hi     text,
  pincodes    text[] NOT NULL DEFAULT '{}',
  -- how an address in this zone is priced when road distance is unavailable (or when overrides are enabled)
  fee_mode    text NOT NULL DEFAULT 'base' CHECK (fee_mode IN ('base','far','custom')),
  custom_fee  numeric(12,2) CHECK (custom_fee IS NULL OR custom_fee >= 0),
  min_order   numeric(12,2) CHECK (min_order IS NULL OR min_order >= 0),
  sort_order  int NOT NULL DEFAULT 0,
  is_active   boolean NOT NULL DEFAULT true,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now(),
  CHECK (fee_mode <> 'custom' OR custom_fee IS NOT NULL)
);
CREATE TRIGGER delivery_zones_touch BEFORE UPDATE ON delivery_zones FOR EACH ROW EXECUTE FUNCTION touch_updated_at();

CREATE TABLE addresses (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  label       text NOT NULL DEFAULT 'Home',
  full_name   text NOT NULL,
  phone       text NOT NULL CHECK (phone ~ '^[6-9][0-9]{9}$'),
  line1       text NOT NULL,
  line2       text,
  landmark    text,
  city        text NOT NULL DEFAULT 'Loharu',
  state       text NOT NULL DEFAULT 'Haryana',
  pincode     text NOT NULL CHECK (pincode ~ '^[1-9][0-9]{5}$'),
  latitude    numeric(9,6) CHECK (latitude BETWEEN -90 AND 90),
  longitude   numeric(9,6) CHECK (longitude BETWEEN -180 AND 180),
  zone_id     uuid REFERENCES delivery_zones(id) ON DELETE SET NULL,
  is_default  boolean NOT NULL DEFAULT false,
  deleted_at  timestamptz,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now(),
  CHECK ((latitude IS NULL) = (longitude IS NULL))
);
CREATE INDEX addresses_user ON addresses (user_id) WHERE deleted_at IS NULL;
CREATE UNIQUE INDEX addresses_one_default ON addresses (user_id) WHERE is_default AND deleted_at IS NULL;
CREATE TRIGGER addresses_touch BEFORE UPDATE ON addresses FOR EACH ROW EXECUTE FUNCTION touch_updated_at();

-- ---------------------------------------------------------------- catalogue
CREATE TABLE categories (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  parent_id   uuid REFERENCES categories(id) ON DELETE RESTRICT,
  name        text NOT NULL,
  name_hi     text,
  slug        text NOT NULL UNIQUE,
  description text,
  image_url   text,
  sort_order  int NOT NULL DEFAULT 0,
  is_active   boolean NOT NULL DEFAULT true,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now(),
  CHECK (parent_id IS NULL OR parent_id <> id)
);
CREATE INDEX categories_parent ON categories (parent_id, sort_order);
CREATE TRIGGER categories_touch BEFORE UPDATE ON categories FOR EACH ROW EXECUTE FUNCTION touch_updated_at();

CREATE TABLE products (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sku                 text NOT NULL UNIQUE,
  barcode             text,
  name                text NOT NULL,
  name_hi             text,
  brand               text,
  category_id         uuid NOT NULL REFERENCES categories(id) ON DELETE RESTRICT,
  subcategory_id      uuid REFERENCES categories(id) ON DELETE RESTRICT,
  description         text,
  unit                text NOT NULL DEFAULT 'pc',
  pack_size           text,
  mrp                 numeric(12,2) NOT NULL CHECK (mrp >= 0),
  price               numeric(12,2) NOT NULL CHECK (price >= 0),
  tax_rate            numeric(5,2) NOT NULL DEFAULT 0 CHECK (tax_rate >= 0 AND tax_rate <= 100),
  hsn_code            text,
  stock_qty           int NOT NULL DEFAULT 0 CHECK (stock_qty >= 0),
  reserved_qty        int NOT NULL DEFAULT 0 CHECK (reserved_qty >= 0),
  low_stock_threshold int NOT NULL DEFAULT 5 CHECK (low_stock_threshold >= 0),
  max_per_order       int CHECK (max_per_order IS NULL OR max_per_order > 0),
  is_active           boolean NOT NULL DEFAULT true,
  is_featured         boolean NOT NULL DEFAULT false,
  coins_eligible      boolean NOT NULL DEFAULT true,
  offers_eligible     boolean NOT NULL DEFAULT true,
  is_sample           boolean NOT NULL DEFAULT false,
  search_text         text GENERATED ALWAYS AS (
                        lower(coalesce(name,'') || ' ' || coalesce(name_hi,'') || ' ' || coalesce(brand,'') || ' ' || sku || ' ' || coalesce(barcode,''))
                      ) STORED,
  created_at          timestamptz NOT NULL DEFAULT now(),
  updated_at          timestamptz NOT NULL DEFAULT now(),
  CHECK (price <= mrp),
  CHECK (reserved_qty <= stock_qty)
);
CREATE INDEX products_category ON products (category_id) WHERE is_active;
CREATE INDEX products_subcategory ON products (subcategory_id) WHERE is_active;
CREATE INDEX products_search_trgm ON products USING gin (search_text gin_trgm_ops);
CREATE INDEX products_barcode ON products (barcode) WHERE barcode IS NOT NULL;
CREATE INDEX products_featured ON products (is_featured) WHERE is_active AND is_featured;
CREATE TRIGGER products_touch BEFORE UPDATE ON products FOR EACH ROW EXECUTE FUNCTION touch_updated_at();

CREATE TABLE product_images (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id  uuid NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  url         text NOT NULL,
  thumb_url   text,
  alt         text,
  sort_order  int NOT NULL DEFAULT 0,
  created_at  timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX product_images_product ON product_images (product_id, sort_order);

-- stock_qty = physically on hand. reserved_qty = promised to open orders. available = stock_qty - reserved_qty.
CREATE TABLE stock_movements (
  id              bigserial PRIMARY KEY,
  product_id      uuid NOT NULL REFERENCES products(id) ON DELETE RESTRICT,
  type            text NOT NULL CHECK (type IN ('adjustment','reserve','release','fulfil','import','opening','return')),
  qty_delta       int NOT NULL DEFAULT 0,        -- change in on-hand stock
  reserved_delta  int NOT NULL DEFAULT 0,        -- change in reserved stock
  stock_after     int NOT NULL,
  reserved_after  int NOT NULL,
  reason          text,
  order_id        uuid,
  admin_id        uuid REFERENCES admin_users(id),
  created_at      timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX stock_movements_product ON stock_movements (product_id, created_at DESC);
CREATE TRIGGER stock_movements_immutable BEFORE UPDATE OR DELETE ON stock_movements FOR EACH ROW EXECUTE FUNCTION forbid_mutation();

-- ---------------------------------------------------------------- promotions
CREATE TABLE coupons (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code             text NOT NULL CHECK (code = upper(code) AND code ~ '^[A-Z0-9_-]{3,20}$'),
  title            text NOT NULL,
  description      text,
  discount_type    text NOT NULL CHECK (discount_type IN ('percent','fixed')),
  discount_value   numeric(12,2) NOT NULL CHECK (discount_value > 0),
  min_spend        numeric(12,2) NOT NULL DEFAULT 0 CHECK (min_spend >= 0),
  max_discount     numeric(12,2) CHECK (max_discount IS NULL OR max_discount > 0),
  starts_at        timestamptz NOT NULL,
  ends_at          timestamptz NOT NULL,
  usage_limit      int CHECK (usage_limit IS NULL OR usage_limit > 0),
  per_user_limit   int NOT NULL DEFAULT 1 CHECK (per_user_limit > 0),
  used_count       int NOT NULL DEFAULT 0 CHECK (used_count >= 0),
  category_ids     uuid[] NOT NULL DEFAULT '{}',   -- empty = all categories
  product_ids      uuid[] NOT NULL DEFAULT '{}',   -- empty = all products
  first_order_only boolean NOT NULL DEFAULT false,
  festival         text,
  is_public        boolean NOT NULL DEFAULT false,   -- listed in the customer app with its terms
  is_active        boolean NOT NULL DEFAULT true,
  created_at       timestamptz NOT NULL DEFAULT now(),
  updated_at       timestamptz NOT NULL DEFAULT now(),
  CHECK (ends_at > starts_at),
  CHECK (discount_type <> 'percent' OR discount_value <= 100)
);
CREATE UNIQUE INDEX coupons_code_unique ON coupons (code);
CREATE TRIGGER coupons_touch BEFORE UPDATE ON coupons FOR EACH ROW EXECUTE FUNCTION touch_updated_at();

CREATE TABLE banners (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title       text NOT NULL,
  subtitle    text,
  image_url   text,
  festival    text,
  terms       text,
  link_type   text NOT NULL DEFAULT 'none' CHECK (link_type IN ('none','category','product','coupon')),
  link_ref    text,
  starts_at   timestamptz,
  ends_at     timestamptz,
  sort_order  int NOT NULL DEFAULT 0,
  is_active   boolean NOT NULL DEFAULT true,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now()
);
CREATE TRIGGER banners_touch BEFORE UPDATE ON banners FOR EACH ROW EXECUTE FUNCTION touch_updated_at();

-- ---------------------------------------------------------------- orders
CREATE SEQUENCE order_no_seq START 1;

CREATE TABLE orders (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_no              text NOT NULL UNIQUE,
  user_id               uuid NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  idempotency_key       text NOT NULL,
  status                text NOT NULL CHECK (status IN (
                          'pending_payment','placed','accepted','packing','ready_for_dispatch','out_for_delivery','delivered',
                          'ready_for_pickup','collected','cancelled','rejected','refund_pending','refunded')),
  fulfilment_type       text NOT NULL CHECK (fulfilment_type IN ('delivery','pickup')),
  payment_method        text NOT NULL CHECK (payment_method IN ('cod','online')),
  payment_status        text NOT NULL CHECK (payment_status IN (
                          'cod_pending','cod_collected','pending','paid','failed','refund_pending','refunded','partially_refunded')),
  address_id            uuid REFERENCES addresses(id) ON DELETE SET NULL,
  address_snapshot      jsonb,
  customer_name         text,
  customer_phone        text NOT NULL,
  -- delivery calculation snapshot (kept so the original invoice never changes)
  distance_km           numeric(8,2),
  distance_method       text,
  zone_id               uuid REFERENCES delivery_zones(id) ON DELETE SET NULL,
  zone_name             text,
  delivery_fee_rule     text,
  -- money
  mrp_total             numeric(12,2) NOT NULL,
  subtotal              numeric(12,2) NOT NULL,
  coupon_id             uuid REFERENCES coupons(id) ON DELETE SET NULL,
  coupon_code           text,
  coupon_discount       numeric(12,2) NOT NULL DEFAULT 0,
  first_order_discount  numeric(12,2) NOT NULL DEFAULT 0,
  coins_redeemed        int NOT NULL DEFAULT 0,
  coin_discount         numeric(12,2) NOT NULL DEFAULT 0,
  delivery_fee          numeric(12,2) NOT NULL DEFAULT 0,
  tax_included          numeric(12,2) NOT NULL DEFAULT 0,
  total                 numeric(12,2) NOT NULL,
  coins_to_earn         int NOT NULL DEFAULT 0,
  coins_credited_at     timestamptz,
  min_order_value       numeric(12,2) NOT NULL,
  pricing_snapshot      jsonb NOT NULL,
  customer_note         text,
  cancel_reason         text,
  cancelled_by          text,
  payment_expires_at    timestamptz,
  stock_state           text NOT NULL DEFAULT 'reserved' CHECK (stock_state IN ('reserved','fulfilled','released')),
  placed_at             timestamptz NOT NULL DEFAULT now(),
  updated_at            timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, idempotency_key),
  CHECK (total >= 0),
  CHECK (fulfilment_type = 'delivery' OR delivery_fee = 0)
);
CREATE INDEX orders_user ON orders (user_id, placed_at DESC);
CREATE INDEX orders_status ON orders (status, placed_at DESC);
CREATE INDEX orders_placed_at ON orders (placed_at DESC);
CREATE INDEX orders_payment_expiry ON orders (payment_expires_at) WHERE status = 'pending_payment';
-- DB-enforced: a customer can hold at most one live first-order discount
CREATE UNIQUE INDEX orders_one_first_order_discount ON orders (user_id)
  WHERE first_order_discount > 0 AND status NOT IN ('cancelled','rejected','refunded');
CREATE TRIGGER orders_touch BEFORE UPDATE ON orders FOR EACH ROW EXECUTE FUNCTION touch_updated_at();

CREATE TABLE order_items (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id         uuid NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  product_id       uuid REFERENCES products(id) ON DELETE SET NULL,
  category_id      uuid,
  sku              text NOT NULL,
  name             text NOT NULL,
  brand            text,
  unit             text,
  pack_size        text,
  image_url        text,
  mrp              numeric(12,2) NOT NULL,
  unit_price       numeric(12,2) NOT NULL,
  qty              int NOT NULL CHECK (qty > 0),
  line_total       numeric(12,2) NOT NULL,         -- unit_price * qty, before order-level discounts
  discount_alloc   numeric(12,2) NOT NULL DEFAULT 0, -- share of coupon/first-order/coins discount
  net_total        numeric(12,2) NOT NULL,         -- line_total - discount_alloc
  tax_rate         numeric(5,2) NOT NULL DEFAULT 0,
  tax_amount       numeric(12,2) NOT NULL DEFAULT 0,
  coins_eligible   boolean NOT NULL DEFAULT true
);
CREATE INDEX order_items_order ON order_items (order_id);
CREATE INDEX order_items_product ON order_items (product_id);

CREATE TABLE order_status_history (
  id           bigserial PRIMARY KEY,
  order_id     uuid NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  from_status  text,
  to_status    text NOT NULL,
  note         text,
  actor_type   text NOT NULL CHECK (actor_type IN ('customer','admin','system','payment')),
  actor_id     uuid,
  created_at   timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX order_status_history_order ON order_status_history (order_id, created_at);
CREATE TRIGGER order_status_history_immutable BEFORE UPDATE OR DELETE ON order_status_history FOR EACH ROW EXECUTE FUNCTION forbid_mutation();

CREATE TABLE coupon_redemptions (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  coupon_id   uuid NOT NULL REFERENCES coupons(id) ON DELETE RESTRICT,
  user_id     uuid NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  order_id    uuid NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  amount      numeric(12,2) NOT NULL,
  status      text NOT NULL DEFAULT 'active' CHECK (status IN ('active','released')),
  created_at  timestamptz NOT NULL DEFAULT now(),
  UNIQUE (coupon_id, order_id)
);
CREATE INDEX coupon_redemptions_user ON coupon_redemptions (coupon_id, user_id) WHERE status = 'active';

-- ---------------------------------------------------------------- payments
CREATE TABLE payments (
  id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id             uuid NOT NULL REFERENCES orders(id) ON DELETE RESTRICT,
  provider             text NOT NULL,
  provider_order_id    text UNIQUE,
  provider_payment_id  text UNIQUE,
  amount               numeric(12,2) NOT NULL CHECK (amount > 0),
  currency             text NOT NULL DEFAULT 'INR',
  status               text NOT NULL DEFAULT 'created' CHECK (status IN ('created','pending','paid','failed','refunded','partially_refunded')),
  method               text,
  failure_reason       text,
  mode                 text NOT NULL DEFAULT 'sandbox' CHECK (mode IN ('sandbox','live')),
  is_primary           boolean NOT NULL DEFAULT false,   -- the payment that settled the order; extra payments are refunded and never change order state
  created_at           timestamptz NOT NULL DEFAULT now(),
  updated_at           timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX payments_one_primary ON payments (order_id) WHERE is_primary;
CREATE INDEX payments_order ON payments (order_id);
CREATE TRIGGER payments_touch BEFORE UPDATE ON payments FOR EACH ROW EXECUTE FUNCTION touch_updated_at();

CREATE TABLE payment_events (
  id            bigserial PRIMARY KEY,
  provider      text NOT NULL,
  event_id      text NOT NULL,
  event_type    text NOT NULL,
  payload       jsonb NOT NULL,
  processed_at  timestamptz,
  result        text,
  created_at    timestamptz NOT NULL DEFAULT now(),
  UNIQUE (provider, event_id)
);

CREATE TABLE refunds (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  payment_id          uuid NOT NULL REFERENCES payments(id) ON DELETE RESTRICT,
  order_id            uuid NOT NULL REFERENCES orders(id) ON DELETE RESTRICT,
  amount              numeric(12,2) NOT NULL CHECK (amount > 0),
  status              text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','processing','processed','failed')),
  provider_refund_id  text UNIQUE,
  reason              text,
  created_by          uuid REFERENCES admin_users(id),
  created_at          timestamptz NOT NULL DEFAULT now(),
  updated_at          timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX refunds_order ON refunds (order_id);
CREATE TRIGGER refunds_touch BEFORE UPDATE ON refunds FOR EACH ROW EXECUTE FUNCTION touch_updated_at();

-- ---------------------------------------------------------------- coins wallet
CREATE TABLE wallets (
  user_id     uuid PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  balance     int NOT NULL DEFAULT 0 CHECK (balance >= 0),
  updated_at  timestamptz NOT NULL DEFAULT now()
);

-- Immutable ledger. `ref` is a unique idempotency reference such as 'order:<uuid>:earn'.
CREATE TABLE wallet_transactions (
  id             bigserial PRIMARY KEY,
  user_id        uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  type           text NOT NULL CHECK (type IN ('earn','redeem','redeem_refund','earn_reversal','expire','adjust')),
  coins          int NOT NULL CHECK (coins <> 0),
  balance_after  int NOT NULL CHECK (balance_after >= 0),
  order_id       uuid REFERENCES orders(id) ON DELETE SET NULL,
  ref            text NOT NULL UNIQUE,
  note           text,
  admin_id       uuid REFERENCES admin_users(id),
  created_at     timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX wallet_transactions_user ON wallet_transactions (user_id, id DESC);
CREATE TRIGGER wallet_transactions_immutable BEFORE UPDATE OR DELETE ON wallet_transactions FOR EACH ROW EXECUTE FUNCTION forbid_mutation();

-- Coin lots track expiry. remaining is the only mutable field; it never goes below zero.
CREATE TABLE coin_lots (
  id           bigserial PRIMARY KEY,
  user_id      uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  source_txn   bigint NOT NULL REFERENCES wallet_transactions(id),
  coins        int NOT NULL CHECK (coins > 0),
  remaining    int NOT NULL CHECK (remaining >= 0 AND remaining <= coins),
  expires_at   timestamptz,
  created_at   timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX coin_lots_user_open ON coin_lots (user_id, expires_at NULLS LAST, id) WHERE remaining > 0;

-- ---------------------------------------------------------------- notifications, audit, imports
CREATE TABLE notifications (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  type        text NOT NULL,
  title       text NOT NULL,
  body        text NOT NULL,
  data        jsonb NOT NULL DEFAULT '{}',
  push_status text NOT NULL DEFAULT 'not_sent' CHECK (push_status IN ('not_sent','sent','failed','skipped')),
  read_at     timestamptz,
  created_at  timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX notifications_user ON notifications (user_id, created_at DESC);

CREATE TABLE audit_logs (
  id          bigserial PRIMARY KEY,
  actor_type  text NOT NULL CHECK (actor_type IN ('admin','customer','system')),
  actor_id    uuid,
  action      text NOT NULL,
  entity      text,
  entity_id   text,
  before      jsonb,
  after       jsonb,
  ip          text,
  created_at  timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX audit_logs_created ON audit_logs (created_at DESC);
CREATE INDEX audit_logs_entity ON audit_logs (entity, entity_id);
CREATE TRIGGER audit_logs_immutable BEFORE UPDATE OR DELETE ON audit_logs FOR EACH ROW EXECUTE FUNCTION forbid_mutation();

CREATE TABLE import_jobs (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  admin_id      uuid REFERENCES admin_users(id),
  filename      text NOT NULL,
  status        text NOT NULL DEFAULT 'previewed' CHECK (status IN ('previewed','applied','cancelled','failed')),
  options       jsonb NOT NULL DEFAULT '{}',
  total_rows    int NOT NULL DEFAULT 0,
  valid_rows    int NOT NULL DEFAULT 0,
  invalid_rows  int NOT NULL DEFAULT 0,
  create_count  int NOT NULL DEFAULT 0,
  update_count  int NOT NULL DEFAULT 0,
  unchanged_count int NOT NULL DEFAULT 0,
  plan          jsonb NOT NULL DEFAULT '[]',   -- validated rows with action + diff, applied on confirm
  created_at    timestamptz NOT NULL DEFAULT now(),
  applied_at    timestamptz
);

CREATE TABLE import_errors (
  id        bigserial PRIMARY KEY,
  job_id    uuid NOT NULL REFERENCES import_jobs(id) ON DELETE CASCADE,
  row_no    int NOT NULL,
  field     text,
  message   text NOT NULL,
  raw       jsonb
);
CREATE INDEX import_errors_job ON import_errors (job_id, row_no);

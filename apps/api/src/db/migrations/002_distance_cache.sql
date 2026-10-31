-- Cache of Google/OSRM road distances so the same store->address pair is never billed twice.
-- Key: store point (6 dp) + destination rounded to 5 dp (~1 m) + provider method. Entries expire (checked at read time, 90 days).
CREATE TABLE IF NOT EXISTS distance_cache (
  store_lat  numeric(9,6) NOT NULL,
  store_lng  numeric(9,6) NOT NULL,
  dest_lat   numeric(8,5) NOT NULL,
  dest_lng   numeric(8,5) NOT NULL,
  method     text         NOT NULL,
  meters     integer      NOT NULL CHECK (meters >= 0),
  created_at timestamptz  NOT NULL DEFAULT now(),
  PRIMARY KEY (store_lat, store_lng, dest_lat, dest_lng, method)
);
CREATE INDEX IF NOT EXISTS distance_cache_created_idx ON distance_cache (created_at);

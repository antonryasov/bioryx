-- BIORYX: отдельная база D1, не использовать базу старого магазина.
CREATE TABLE IF NOT EXISTS products (
  id TEXT PRIMARY KEY,
  sku TEXT NOT NULL DEFAULT '',
  name TEXT NOT NULL,
  category TEXT NOT NULL CHECK (category IN ('protein','creatine','sets')),
  description TEXT NOT NULL DEFAULT '',
  price INTEGER NOT NULL CHECK (price >= 0),
  stock INTEGER NOT NULL DEFAULT 0 CHECK (stock >= 0),
  image TEXT NOT NULL DEFAULT '',
  active INTEGER NOT NULL DEFAULT 0 CHECK (active IN (0, 1)),
  sort_order INTEGER NOT NULL DEFAULT 100,
  updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE INDEX IF NOT EXISTS products_listing ON products(active, sort_order, name);

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
CREATE TABLE IF NOT EXISTS orders (
 id TEXT PRIMARY KEY, created_at TEXT NOT NULL DEFAULT (datetime('now')),
 customer_name TEXT NOT NULL, phone TEXT NOT NULL, city TEXT NOT NULL, address TEXT NOT NULL DEFAULT '',
 delivery TEXT NOT NULL CHECK(delivery IN ('pickup','courier','cdek')),
 payment TEXT NOT NULL CHECK(payment IN ('cash','sbp')),
 comment TEXT NOT NULL DEFAULT '', total INTEGER NOT NULL DEFAULT 0,
 status TEXT NOT NULL DEFAULT 'new', payment_status TEXT NOT NULL DEFAULT 'unpaid', consent INTEGER NOT NULL CHECK(consent=1)
);
CREATE TABLE IF NOT EXISTS order_items (
 id INTEGER PRIMARY KEY AUTOINCREMENT, order_id TEXT NOT NULL REFERENCES orders(id), product_id TEXT NOT NULL,
 name TEXT NOT NULL, price INTEGER NOT NULL, qty INTEGER NOT NULL CHECK(qty BETWEEN 1 AND 20)
);
CREATE TABLE IF NOT EXISTS outbox (
 id INTEGER PRIMARY KEY AUTOINCREMENT, order_id TEXT NOT NULL UNIQUE, state TEXT NOT NULL DEFAULT 'pending',
 attempts INTEGER NOT NULL DEFAULT 0, created_at TEXT NOT NULL DEFAULT (datetime('now')), last_error TEXT NOT NULL DEFAULT ''
);
CREATE INDEX IF NOT EXISTS idx_order_items_order ON order_items(order_id);
CREATE INDEX IF NOT EXISTS idx_orders_created ON orders(created_at);
CREATE INDEX IF NOT EXISTS idx_outbox_pending ON outbox(state,id);
CREATE TRIGGER IF NOT EXISTS reserve_stock BEFORE INSERT ON order_items BEGIN
 SELECT CASE WHEN NOT EXISTS (SELECT 1 FROM products WHERE id=NEW.product_id AND active=1 AND stock>=NEW.qty AND price=NEW.price AND name=NEW.name)
 THEN RAISE(ABORT, 'product_unavailable') END;
 UPDATE products SET stock=stock-NEW.qty WHERE id=NEW.product_id;
END;
-- Вымышленные товары; удалить или заменить до реальных продаж.
INSERT OR IGNORE INTO products (id,sku,name,category,description,price,stock,image,active) VALUES ('demo-protein-vanilla', 'DEMO-P01', 'WHEY / ВАНИЛЬ', 'protein', 'Демонстрационный протеин · 900 г', 3290, 12, 'assets/protein.png', 1);
INSERT OR IGNORE INTO products (id,sku,name,category,description,price,stock,image,active) VALUES ('demo-protein-chocolate', 'DEMO-P02', 'WHEY / ШОКОЛАД', 'protein', 'Демонстрационный протеин · 900 г', 3290, 10, 'assets/protein.png', 1);
INSERT OR IGNORE INTO products (id,sku,name,category,description,price,stock,image,active) VALUES ('demo-creatine', 'DEMO-C01', 'CREATINE / MONO', 'creatine', 'Демонстрационный креатин · 300 г', 1990, 15, 'assets/creatine.png', 1);
INSERT OR IGNORE INTO products (id,sku,name,category,description,price,stock,image,active) VALUES ('demo-creatine-micronized', 'DEMO-C02', 'CREATINE / MICRO', 'creatine', 'Демонстрационный креатин · 250 г', 1790, 8, 'assets/creatine.png', 1);
INSERT OR IGNORE INTO products (id,sku,name,category,description,price,stock,image,active) VALUES ('demo-set-start', 'DEMO-S01', 'СТАРТ / НАБОР', 'sets', 'Демонстрационный набор для старта', 4790, 5, 'assets/set.png', 1);
INSERT OR IGNORE INTO products (id,sku,name,category,description,price,stock,image,active) VALUES ('demo-set-mass', 'DEMO-S02', 'МАССА / НАБОР', 'sets', 'Демонстрационный набор для набора массы', 6490, 5, 'assets/set.png', 1);

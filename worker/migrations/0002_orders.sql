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

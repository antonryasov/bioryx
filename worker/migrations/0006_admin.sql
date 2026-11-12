-- Только для BIORYX D1. Повторный запуск не удаляет данные.
CREATE TABLE IF NOT EXISTS bx_admin_login_attempts (
 ip_hash TEXT PRIMARY KEY,
 count INTEGER NOT NULL DEFAULT 0,
 window_start INTEGER NOT NULL
);
CREATE TABLE IF NOT EXISTS bx_order_audit (
 id INTEGER PRIMARY KEY AUTOINCREMENT,
 order_id TEXT NOT NULL REFERENCES orders(id),
 action TEXT NOT NULL,
 old_value TEXT NOT NULL DEFAULT '',
 new_value TEXT NOT NULL DEFAULT '',
 created_at TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE INDEX IF NOT EXISTS bx_order_audit_order ON bx_order_audit(order_id, created_at DESC);
CREATE TRIGGER IF NOT EXISTS bx_admin_status_audit AFTER UPDATE OF status ON orders
WHEN OLD.status != NEW.status BEGIN
 INSERT INTO bx_order_audit(order_id,action,old_value,new_value) VALUES(NEW.id,'status',OLD.status,NEW.status);
END;
CREATE TRIGGER IF NOT EXISTS bx_admin_payment_audit AFTER UPDATE OF payment_status ON orders
WHEN OLD.payment_status != NEW.payment_status BEGIN
 INSERT INTO bx_order_audit(order_id,action,old_value,new_value) VALUES(NEW.id,'payment',OLD.payment_status,NEW.payment_status);
END;

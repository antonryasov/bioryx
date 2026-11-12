-- BIORYX: после миграций 0004–0011. Команды не удаляют данные магазина.
-- Контекст события задаётся и удаляется в одной транзакционной D1 batch.
CREATE TABLE IF NOT EXISTS bx_admin_event_context (
 entity_key TEXT PRIMARY KEY,
 operation_id TEXT NOT NULL,
 kind TEXT NOT NULL CHECK(kind IN ('status','payment','points','level')),
 body TEXT NOT NULL DEFAULT '',
 notify INTEGER NOT NULL DEFAULT 0 CHECK(notify IN (0,1))
);
CREATE TRIGGER IF NOT EXISTS bx_admin_status_notification AFTER UPDATE OF status ON orders
WHEN OLD.status != NEW.status BEGIN
 INSERT OR IGNORE INTO bx_notifications(id,customer_id,body)
 SELECT 'status:'||e.operation_id,x.customer_id,e.body
 FROM bx_admin_event_context e JOIN bx_order_owners x ON x.order_id=NEW.id
 WHERE e.entity_key='order:'||NEW.id AND e.kind='status' AND e.notify=1;
END;
CREATE TRIGGER IF NOT EXISTS bx_admin_payment_notification AFTER UPDATE OF payment,payment_status ON orders
WHEN OLD.payment != NEW.payment OR OLD.payment_status != NEW.payment_status BEGIN
 INSERT OR IGNORE INTO bx_notifications(id,customer_id,body)
 SELECT 'payment:'||e.operation_id,x.customer_id,e.body
 FROM bx_admin_event_context e JOIN bx_order_owners x ON x.order_id=NEW.id
 WHERE e.entity_key='order:'||NEW.id AND e.kind='payment' AND e.notify=1;
END;
CREATE TRIGGER IF NOT EXISTS bx_admin_points_notification AFTER INSERT ON bx_loyalty_ledger
WHEN NEW.kind='adjustment' BEGIN
 INSERT OR IGNORE INTO bx_notifications(id,customer_id,body)
 SELECT 'adjustment:'||e.operation_id,NEW.customer_id,e.body FROM bx_admin_event_context e
 WHERE e.entity_key='customer:'||NEW.customer_id AND e.kind='points' AND e.notify=1;
END;
CREATE TRIGGER IF NOT EXISTS bx_admin_level_insert AFTER INSERT ON bx_customer_levels BEGIN
 INSERT INTO bx_level_audit(customer_id,old_level,new_level) VALUES(NEW.customer_id,'auto',NEW.level);
 INSERT OR IGNORE INTO bx_notifications(id,customer_id,body)
 SELECT 'level:'||e.operation_id,NEW.customer_id,e.body FROM bx_admin_event_context e
 WHERE e.entity_key='customer:'||NEW.customer_id AND e.kind='level' AND e.notify=1;
END;
CREATE TRIGGER IF NOT EXISTS bx_admin_level_update AFTER UPDATE OF level ON bx_customer_levels
WHEN OLD.level != NEW.level BEGIN
 INSERT INTO bx_level_audit(customer_id,old_level,new_level) VALUES(NEW.customer_id,OLD.level,NEW.level);
 INSERT OR IGNORE INTO bx_notifications(id,customer_id,body)
 SELECT 'level:'||e.operation_id,NEW.customer_id,e.body FROM bx_admin_event_context e
 WHERE e.entity_key='customer:'||NEW.customer_id AND e.kind='level' AND e.notify=1;
END;
CREATE TRIGGER IF NOT EXISTS bx_admin_level_delete AFTER DELETE ON bx_customer_levels BEGIN
 INSERT INTO bx_level_audit(customer_id,old_level,new_level) VALUES(OLD.customer_id,OLD.level,'auto');
 INSERT OR IGNORE INTO bx_notifications(id,customer_id,body)
 SELECT 'level:'||e.operation_id,OLD.customer_id,e.body FROM bx_admin_event_context e
 WHERE e.entity_key='customer:'||OLD.customer_id AND e.kind='level' AND e.notify=1;
END;

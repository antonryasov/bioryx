-- Только текущая база BIORYX с миграциями 0004–0009. Сделайте резервную копию.
CREATE TABLE IF NOT EXISTS bx_customer_levels (
 customer_id TEXT PRIMARY KEY REFERENCES bx_customers(id),
 level TEXT NOT NULL CHECK(level IN ('start','progress','power','peak')),
 updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE TABLE IF NOT EXISTS bx_level_audit (
 id INTEGER PRIMARY KEY AUTOINCREMENT, customer_id TEXT NOT NULL REFERENCES bx_customers(id),
 old_level TEXT NOT NULL DEFAULT 'auto', new_level TEXT NOT NULL,
 created_at TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE TABLE IF NOT EXISTS bx_notification_flags (
 entity_key TEXT PRIMARY KEY, enabled INTEGER NOT NULL CHECK(enabled IN (0,1))
);
CREATE TABLE IF NOT EXISTS bx_notifications (
 id TEXT PRIMARY KEY, customer_id TEXT NOT NULL REFERENCES bx_customers(id),
 body TEXT NOT NULL, state TEXT NOT NULL DEFAULT 'pending' CHECK(state IN ('pending','sending','sent','failed')),
 attempts INTEGER NOT NULL DEFAULT 0, last_error TEXT NOT NULL DEFAULT '',
 created_at TEXT NOT NULL DEFAULT (datetime('now')), updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE INDEX IF NOT EXISTS bx_notifications_pending ON bx_notifications(state,created_at);
CREATE TRIGGER IF NOT EXISTS bx_notify_ledger AFTER INSERT ON bx_loyalty_ledger
WHEN NEW.kind IN ('welcome','earn','redeem','restore')
 AND COALESCE((SELECT enabled FROM bx_notification_flags WHERE entity_key='order:'||NEW.order_id),1)=1
BEGIN
 INSERT OR IGNORE INTO bx_notifications(id,customer_id,body)
 VALUES('ledger:'||NEW.id,NEW.customer_id,
  CASE NEW.kind
   WHEN 'welcome' THEN '✦ BIORYX CLUB' || char(10) || char(10) || 'Добро пожаловать! Вам начислено ' || NEW.points || ' приветственных баллов.' || char(10) || '1 балл = 1 ₽. Ваш путь начинается здесь.'
   WHEN 'earn' THEN '✦ BIORYX CLUB' || char(10) || char(10) || 'За доставленный заказ начислено +' || NEW.points || ' баллов.' || char(10) || 'Спасибо, что выбираете BIORYX!'
   WHEN 'redeem' THEN '✦ BIORYX CLUB' || char(10) || char(10) || 'Для оплаты заказа списано ' || (-NEW.points) || ' баллов.'
   ELSE '✦ BIORYX CLUB' || char(10) || char(10) || 'После отмены заказа возвращено +' || NEW.points || ' баллов.' END);
END;
CREATE TRIGGER IF NOT EXISTS bx_admin_payment_method_audit AFTER UPDATE OF payment ON orders
WHEN OLD.payment != NEW.payment BEGIN
 INSERT INTO bx_order_audit(order_id,action,old_value,new_value) VALUES(NEW.id,'payment_method',OLD.payment,NEW.payment);
END;
-- Переопределение уровня влияет на будущий кэшбэк. Историю операций не пересчитываем.
DROP TRIGGER IF EXISTS bx_delivery_cashback;
CREATE TRIGGER IF NOT EXISTS bx_delivery_cashback AFTER UPDATE OF status ON orders
WHEN NEW.status='delivered' AND OLD.status!='delivered' BEGIN
 INSERT OR IGNORE INTO bx_loyalty_ledger(id,customer_id,order_id,kind,points,operation_key,note)
 SELECT 'earn:'||NEW.id, f.customer_id,NEW.id,'earn',
 CAST(NEW.total * (COALESCE((SELECT CASE level WHEN 'start' THEN 5 WHEN 'progress' THEN 10 WHEN 'power' THEN 25 WHEN 'peak' THEN 50 END FROM bx_customer_levels WHERE customer_id=f.customer_id), CASE
 WHEN COALESCE((SELECT SUM(o.total) FROM orders o JOIN bx_order_finance x ON x.order_id=o.id WHERE x.customer_id=f.customer_id AND o.status='delivered' AND o.id!=NEW.id),0)>=80000 THEN 50
 WHEN COALESCE((SELECT SUM(o.total) FROM orders o JOIN bx_order_finance x ON x.order_id=o.id WHERE x.customer_id=f.customer_id AND o.status='delivered' AND o.id!=NEW.id),0)>=40000 THEN 25
 WHEN COALESCE((SELECT SUM(o.total) FROM orders o JOIN bx_order_finance x ON x.order_id=o.id WHERE x.customer_id=f.customer_id AND o.status='delivered' AND o.id!=NEW.id),0)>=15000 THEN 10 ELSE 5 END))/100 AS INTEGER),
 'earn:'||NEW.id,'Кэшбэк за доставленный заказ, без доставки'
 FROM bx_order_finance f WHERE f.order_id=NEW.id AND f.customer_id IS NOT NULL AND NEW.total>=1
 AND CAST(NEW.total*(COALESCE((SELECT CASE level WHEN 'start' THEN 5 WHEN 'progress' THEN 10 WHEN 'power' THEN 25 WHEN 'peak' THEN 50 END FROM bx_customer_levels WHERE customer_id=f.customer_id), CASE
 WHEN COALESCE((SELECT SUM(o.total) FROM orders o JOIN bx_order_finance x ON x.order_id=o.id WHERE x.customer_id=f.customer_id AND o.status='delivered' AND o.id!=NEW.id),0)>=80000 THEN 50
 WHEN COALESCE((SELECT SUM(o.total) FROM orders o JOIN bx_order_finance x ON x.order_id=o.id WHERE x.customer_id=f.customer_id AND o.status='delivered' AND o.id!=NEW.id),0)>=40000 THEN 25
 WHEN COALESCE((SELECT SUM(o.total) FROM orders o JOIN bx_order_finance x ON x.order_id=o.id WHERE x.customer_id=f.customer_id AND o.status='delivered' AND o.id!=NEW.id),0)>=15000 THEN 10 ELSE 5 END))/100 AS INTEGER)>0;
END;
-- Автоматическое повышение уровня после доставленного заказа.
CREATE TRIGGER IF NOT EXISTS bx_notify_level_after_delivery AFTER UPDATE OF status ON orders
WHEN OLD.status!='delivered' AND NEW.status='delivered'
 AND COALESCE((SELECT enabled FROM bx_notification_flags WHERE entity_key='order:'||NEW.id),1)=1
BEGIN
 INSERT OR IGNORE INTO bx_notifications(id,customer_id,body)
 SELECT 'level:auto:'||NEW.id,f.customer_id,
 '✦ BIORYX CLUB' || char(10) || char(10) || 'Ваш уровень вырос: ' ||
 CASE WHEN (SELECT COALESCE(SUM(o.total),0) FROM orders o JOIN bx_order_finance x ON x.order_id=o.id WHERE x.customer_id=f.customer_id AND o.status='delivered')>=80000 THEN 'ПИК'
 WHEN (SELECT COALESCE(SUM(o.total),0) FROM orders o JOIN bx_order_finance x ON x.order_id=o.id WHERE x.customer_id=f.customer_id AND o.status='delivered')>=40000 THEN 'СИЛА'
 ELSE 'ПРОГРЕСС' END || '!' || char(10) || 'Спасибо, что выбираете BIORYX!'
 FROM bx_order_finance f WHERE f.order_id=NEW.id AND f.customer_id IS NOT NULL
 AND NOT EXISTS(SELECT 1 FROM bx_customer_levels WHERE customer_id=f.customer_id)
 AND ((SELECT COALESCE(SUM(o.total),0) FROM orders o JOIN bx_order_finance x ON x.order_id=o.id WHERE x.customer_id=f.customer_id AND o.status='delivered')>=15000 AND (SELECT COALESCE(SUM(o.total),0) FROM orders o JOIN bx_order_finance x ON x.order_id=o.id WHERE x.customer_id=f.customer_id AND o.status='delivered' AND o.id!=NEW.id)<15000
 OR (SELECT COALESCE(SUM(o.total),0) FROM orders o JOIN bx_order_finance x ON x.order_id=o.id WHERE x.customer_id=f.customer_id AND o.status='delivered')>=40000 AND (SELECT COALESCE(SUM(o.total),0) FROM orders o JOIN bx_order_finance x ON x.order_id=o.id WHERE x.customer_id=f.customer_id AND o.status='delivered' AND o.id!=NEW.id)<40000
 OR (SELECT COALESCE(SUM(o.total),0) FROM orders o JOIN bx_order_finance x ON x.order_id=o.id WHERE x.customer_id=f.customer_id AND o.status='delivered')>=80000 AND (SELECT COALESCE(SUM(o.total),0) FROM orders o JOIN bx_order_finance x ON x.order_id=o.id WHERE x.customer_id=f.customer_id AND o.status='delivered' AND o.id!=NEW.id)<80000);
END;

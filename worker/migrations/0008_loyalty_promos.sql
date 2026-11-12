-- BIORYX: выполнить после 0004–0007. Не меняет и не удаляет старые заказы.
-- Сначала создайте и проверьте резервную копию D1.
CREATE TABLE IF NOT EXISTS bx_promos (
 code TEXT PRIMARY KEY,
 title TEXT NOT NULL,
 percent INTEGER NOT NULL CHECK(percent BETWEEN 1 AND 100),
 active INTEGER NOT NULL DEFAULT 1 CHECK(active IN (0,1)),
 created_at TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE TABLE IF NOT EXISTS bx_order_finance (
 order_id TEXT PRIMARY KEY REFERENCES orders(id),
 customer_id TEXT REFERENCES bx_customers(id),
 gross INTEGER NOT NULL CHECK(gross >= 0),
 promo_code TEXT NOT NULL DEFAULT '',
 promo_percent INTEGER NOT NULL DEFAULT 0 CHECK(promo_percent BETWEEN 0 AND 100),
 discount INTEGER NOT NULL DEFAULT 0 CHECK(discount >= 0),
 points_used INTEGER NOT NULL DEFAULT 0 CHECK(points_used >= 0),
 created_at TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE TRIGGER IF NOT EXISTS bx_welcome AFTER INSERT ON bx_customers BEGIN
 INSERT OR IGNORE INTO bx_loyalty_ledger(id,customer_id,kind,points,operation_key,note)
 VALUES('welcome:'||NEW.id,NEW.id,'welcome',500,'welcome:'||NEW.id,'Приветственные баллы');
END;
CREATE TRIGGER IF NOT EXISTS bx_finance_guard BEFORE INSERT ON bx_order_finance BEGIN
 SELECT CASE WHEN NOT EXISTS(SELECT 1 FROM orders WHERE id=NEW.order_id AND total=NEW.gross AND status='new')
 THEN RAISE(ABORT,'bad_gross') END;
 SELECT CASE WHEN NEW.promo_code='' AND (NEW.promo_percent!=0 OR NEW.discount!=0)
 THEN RAISE(ABORT,'bad_promo') END;
 SELECT CASE WHEN NEW.promo_code!='' AND NOT EXISTS(SELECT 1 FROM bx_promos WHERE code=NEW.promo_code AND active=1 AND percent=NEW.promo_percent)
 THEN RAISE(ABORT,'invalid_promo') END;
 SELECT CASE WHEN NEW.discount != CAST(NEW.gross*NEW.promo_percent/100 AS INTEGER) OR NEW.points_used>NEW.gross-NEW.discount
 THEN RAISE(ABORT,'bad_discount') END;
 SELECT CASE WHEN NEW.points_used>0 AND (NEW.customer_id IS NULL OR NOT EXISTS(SELECT 1 FROM bx_order_owners WHERE order_id=NEW.order_id AND customer_id=NEW.customer_id))
 THEN RAISE(ABORT,'customer_required') END;
 SELECT CASE WHEN NEW.points_used>0 AND NEW.points_used > COALESCE((SELECT SUM(points) FROM bx_loyalty_ledger WHERE customer_id=NEW.customer_id),0)
 THEN RAISE(ABORT,'insufficient_points') END;
END;
CREATE TRIGGER IF NOT EXISTS bx_finance_apply AFTER INSERT ON bx_order_finance BEGIN
 UPDATE orders SET total=NEW.gross-NEW.discount-NEW.points_used WHERE id=NEW.order_id;
 INSERT INTO bx_loyalty_ledger(id,customer_id,order_id,kind,points,operation_key,note)
 SELECT 'redeem:'||NEW.order_id,NEW.customer_id,NEW.order_id,'redeem',-NEW.points_used,'redeem:'||NEW.order_id,'Оплата баллами'
 WHERE NEW.points_used>0;
END;
CREATE TRIGGER IF NOT EXISTS bx_delivery_guard BEFORE UPDATE OF status ON orders
WHEN NEW.status='delivered' AND OLD.status!='delivered' BEGIN
 SELECT CASE WHEN NEW.payment_status!='paid' THEN RAISE(ABORT,'confirm_payment_first') END;
END;
CREATE TRIGGER IF NOT EXISTS bx_delivered_immutable BEFORE UPDATE OF status ON orders
WHEN OLD.status='delivered' AND NEW.status!='delivered' BEGIN
 SELECT RAISE(ABORT,'delivered_order_requires_refund_workflow');
END;
CREATE TRIGGER IF NOT EXISTS bx_delivery_cashback AFTER UPDATE OF status ON orders
WHEN NEW.status='delivered' AND OLD.status!='delivered' BEGIN
 INSERT OR IGNORE INTO bx_loyalty_ledger(id,customer_id,order_id,kind,points,operation_key,note)
 SELECT 'earn:'||NEW.id, f.customer_id,NEW.id,'earn',
 CAST(NEW.total * (CASE
 WHEN COALESCE((SELECT SUM(o.total) FROM orders o JOIN bx_order_finance x ON x.order_id=o.id WHERE x.customer_id=f.customer_id AND o.status='delivered' AND o.id!=NEW.id),0)>=80000 THEN 50
 WHEN COALESCE((SELECT SUM(o.total) FROM orders o JOIN bx_order_finance x ON x.order_id=o.id WHERE x.customer_id=f.customer_id AND o.status='delivered' AND o.id!=NEW.id),0)>=40000 THEN 25
 WHEN COALESCE((SELECT SUM(o.total) FROM orders o JOIN bx_order_finance x ON x.order_id=o.id WHERE x.customer_id=f.customer_id AND o.status='delivered' AND o.id!=NEW.id),0)>=15000 THEN 10 ELSE 5 END)/100 AS INTEGER),
 'earn:'||NEW.id,'Кэшбэк за доставленный заказ, без доставки'
 FROM bx_order_finance f WHERE f.order_id=NEW.id AND f.customer_id IS NOT NULL AND NEW.total>=1
 AND CAST(NEW.total*(CASE
 WHEN COALESCE((SELECT SUM(o.total) FROM orders o JOIN bx_order_finance x ON x.order_id=o.id WHERE x.customer_id=f.customer_id AND o.status='delivered' AND o.id!=NEW.id),0)>=80000 THEN 50
 WHEN COALESCE((SELECT SUM(o.total) FROM orders o JOIN bx_order_finance x ON x.order_id=o.id WHERE x.customer_id=f.customer_id AND o.status='delivered' AND o.id!=NEW.id),0)>=40000 THEN 25
 WHEN COALESCE((SELECT SUM(o.total) FROM orders o JOIN bx_order_finance x ON x.order_id=o.id WHERE x.customer_id=f.customer_id AND o.status='delivered' AND o.id!=NEW.id),0)>=15000 THEN 10 ELSE 5 END)/100 AS INTEGER)>0;
END;
CREATE TRIGGER IF NOT EXISTS bx_cancel_points AFTER UPDATE OF status ON orders
WHEN OLD.status!='cancelled' AND NEW.status='cancelled' BEGIN
 INSERT OR IGNORE INTO bx_loyalty_ledger(id,customer_id,order_id,kind,points,operation_key,note)
 SELECT 'restore:'||NEW.id,customer_id,NEW.id,'restore',points_used,'restore:'||NEW.id,'Возврат баллов после отмены'
 FROM bx_order_finance WHERE order_id=NEW.id AND customer_id IS NOT NULL AND points_used>0;
END;
INSERT OR IGNORE INTO bx_loyalty_ledger(id,customer_id,kind,points,operation_key,note)
SELECT 'welcome:'||id,id,'welcome',500,'welcome:'||id,'Приветственные баллы' FROM bx_customers;

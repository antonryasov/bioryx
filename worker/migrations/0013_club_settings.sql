-- BIORYX: выполнять после 0012 и резервного копирования. Действующие настройки по умолчанию не изменяются.
CREATE TABLE IF NOT EXISTS bx_club_levels (
 id TEXT PRIMARY KEY CHECK(id IN ('start','progress','power','peak')),
 title TEXT NOT NULL CHECK(length(title) BETWEEN 1 AND 60),
 threshold INTEGER NOT NULL CHECK(threshold>=0),
 cashback INTEGER NOT NULL CHECK(cashback BETWEEN 0 AND 100)
);
INSERT OR IGNORE INTO bx_club_levels(id,title,threshold,cashback) VALUES
 ('start','СТАРТ',0,5),('progress','ПРОГРЕСС',15000,10),('power','СИЛА',40000,25),('peak','ПИК',80000,50);
CREATE TABLE IF NOT EXISTS bx_club_settings (id INTEGER PRIMARY KEY CHECK(id=1),redeem_percent INTEGER NOT NULL CHECK(redeem_percent BETWEEN 0 AND 100));
INSERT OR IGNORE INTO bx_club_settings(id,redeem_percent) VALUES(1,100);
CREATE TABLE IF NOT EXISTS bx_club_settings_audit (id INTEGER PRIMARY KEY AUTOINCREMENT, snapshot TEXT NOT NULL, created_at TEXT NOT NULL DEFAULT(datetime('now')));
DROP TRIGGER IF EXISTS bx_club_redeem_limit;
CREATE TRIGGER bx_club_redeem_limit BEFORE INSERT ON bx_order_finance BEGIN
 SELECT CASE WHEN NEW.points_used > CAST((NEW.gross-NEW.discount)*COALESCE((SELECT redeem_percent FROM bx_club_settings WHERE id=1),100)/100 AS INTEGER) THEN RAISE(ABORT,'club_redeem_limit') END;
END;
DROP TRIGGER IF EXISTS bx_cashback_recalculate;
CREATE TRIGGER bx_cashback_recalculate AFTER UPDATE OF status,payment_status ON orders
WHEN NEW.status='delivered' AND NEW.payment_status='paid' AND (OLD.status!='delivered' OR OLD.payment_status!='paid') BEGIN
 INSERT INTO bx_loyalty_ledger(id,customer_id,order_id,kind,points,operation_key,note)
 SELECT lower(hex(randomblob(16))),f.customer_id,NEW.id,'earn',CAST(NEW.total * COALESCE(
 (SELECT l.cashback FROM bx_customer_levels x JOIN bx_club_levels l ON l.id=x.level WHERE x.customer_id=f.customer_id),
 (SELECT l.cashback FROM bx_club_levels l WHERE l.threshold <= (SELECT COALESCE(SUM(o.total),0) FROM orders o JOIN bx_order_finance x ON x.order_id=o.id WHERE x.customer_id=f.customer_id AND o.status='delivered' AND o.payment_status='paid' AND o.id!=NEW.id) ORDER BY l.threshold DESC LIMIT 1),0)/100 AS INTEGER),lower(hex(randomblob(16))),'Кэшбэк за доставленный и оплаченный заказ'
 FROM bx_order_finance f WHERE f.order_id=NEW.id AND f.customer_id IS NOT NULL AND CAST(NEW.total * COALESCE(
 (SELECT l.cashback FROM bx_customer_levels x JOIN bx_club_levels l ON l.id=x.level WHERE x.customer_id=f.customer_id),
 (SELECT l.cashback FROM bx_club_levels l WHERE l.threshold <= (SELECT COALESCE(SUM(o.total),0) FROM orders o JOIN bx_order_finance x ON x.order_id=o.id WHERE x.customer_id=f.customer_id AND o.status='delivered' AND o.payment_status='paid' AND o.id!=NEW.id) ORDER BY l.threshold DESC LIMIT 1),0)/100 AS INTEGER)>0;
END;
DROP TRIGGER IF EXISTS bx_auto_level_transitions;
CREATE TRIGGER bx_auto_level_transitions AFTER UPDATE OF status,payment_status ON orders
WHEN (OLD.status='delivered' AND OLD.payment_status='paid') != (NEW.status='delivered' AND NEW.payment_status='paid')
 AND COALESCE((SELECT enabled FROM bx_notification_flags WHERE entity_key='order:'||NEW.id),1)=1 BEGIN
 INSERT INTO bx_notifications(id,customer_id,body)
 SELECT 'auto-level:'||lower(hex(randomblob(16))),f.customer_id,'✦ BIORYX CLUB'||char(10)||char(10)||'Ваш уровень обновлён: '||
 (SELECT title FROM bx_club_levels WHERE threshold <= (SELECT COALESCE(SUM(o.total),0) FROM orders o JOIN bx_order_finance x ON x.order_id=o.id WHERE x.customer_id=f.customer_id AND o.status='delivered' AND o.payment_status='paid') ORDER BY threshold DESC LIMIT 1)||'.'
 FROM bx_order_finance f WHERE f.order_id=NEW.id AND f.customer_id IS NOT NULL AND NOT EXISTS(SELECT 1 FROM bx_customer_levels WHERE customer_id=f.customer_id)
 AND (SELECT COUNT(*) FROM bx_club_levels t WHERE t.threshold>0 AND
 ((SELECT COALESCE(SUM(o.total),0) FROM orders o JOIN bx_order_finance x ON x.order_id=o.id WHERE x.customer_id=f.customer_id AND o.status='delivered' AND o.payment_status='paid')>=t.threshold) !=
 (((SELECT COALESCE(SUM(o.total),0) FROM orders o JOIN bx_order_finance x ON x.order_id=o.id WHERE x.customer_id=f.customer_id AND o.status='delivered' AND o.payment_status='paid') - CASE WHEN NEW.status='delivered' AND NEW.payment_status='paid' THEN NEW.total ELSE 0 END + CASE WHEN OLD.status='delivered' AND OLD.payment_status='paid' THEN OLD.total ELSE 0 END)>=t.threshold))>0;
END;

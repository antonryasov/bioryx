-- BIORYX. Выполнять после 0004–0010, только после резервного копирования.
-- Миграция не выполняет банковский возврат и не изменяет существующие заказы.
DROP TRIGGER IF EXISTS bioryx_cancel_guard;
DROP TRIGGER IF EXISTS bioryx_cancel_restock;
DROP TRIGGER IF EXISTS bx_delivered_immutable;
DROP TRIGGER IF EXISTS bx_delivery_guard;
DROP TRIGGER IF EXISTS bx_cancel_points;
DROP TRIGGER IF EXISTS bx_delivery_cashback;
DROP TRIGGER IF EXISTS bx_notify_level_after_delivery;
DROP TRIGGER IF EXISTS bx_notify_ledger;

-- Для возобновления отменённого заказа товар необходимо снова зарезервировать.
CREATE TRIGGER IF NOT EXISTS bx_reopen_stock_guard BEFORE UPDATE OF status ON orders
WHEN OLD.status='cancelled' AND NEW.status!='cancelled' BEGIN
 SELECT CASE WHEN EXISTS(
  SELECT 1 FROM order_items i LEFT JOIN products p ON p.id=i.product_id
  WHERE i.order_id=NEW.id GROUP BY i.product_id
  HAVING p.id IS NULL OR p.stock < SUM(i.qty)
 ) THEN RAISE(ABORT,'insufficient_stock_to_reopen') END;
END;
CREATE TRIGGER IF NOT EXISTS bx_stock_transitions AFTER UPDATE OF status ON orders
WHEN (OLD.status='cancelled' AND NEW.status!='cancelled') OR (OLD.status!='cancelled' AND NEW.status='cancelled') BEGIN
 UPDATE products SET stock=stock + CASE WHEN NEW.status='cancelled' THEN 1 ELSE -1 END *
 (SELECT COALESCE(SUM(qty),0) FROM order_items WHERE order_id=NEW.id AND product_id=products.id)
 WHERE id IN (SELECT product_id FROM order_items WHERE order_id=NEW.id);
END;
-- При отмене/возобновлении приводим фактическое списание к нулю/первоначальной сумме.
CREATE TRIGGER IF NOT EXISTS bx_redemption_transitions AFTER UPDATE OF status ON orders
WHEN (OLD.status='cancelled' AND NEW.status!='cancelled') OR (OLD.status!='cancelled' AND NEW.status='cancelled') BEGIN
 INSERT INTO bx_loyalty_ledger(id,customer_id,order_id,kind,points,operation_key,note)
 SELECT lower(hex(randomblob(16))),f.customer_id,NEW.id,
 CASE WHEN NEW.status='cancelled' THEN 'restore' ELSE 'redeem' END,
 CASE WHEN NEW.status='cancelled' THEN -COALESCE((SELECT SUM(l.points) FROM bx_loyalty_ledger l WHERE l.order_id=NEW.id AND l.kind IN ('redeem','restore')),0)
 ELSE -f.points_used-COALESCE((SELECT SUM(l.points) FROM bx_loyalty_ledger l WHERE l.order_id=NEW.id AND l.kind IN ('redeem','restore')),0) END,
 lower(hex(randomblob(16))),CASE WHEN NEW.status='cancelled' THEN 'Возврат баллов после отмены' ELSE 'Повторное списание при возобновлении заказа' END
 FROM bx_order_finance f WHERE f.order_id=NEW.id AND f.customer_id IS NOT NULL AND f.points_used>0
 AND CASE WHEN NEW.status='cancelled' THEN -COALESCE((SELECT SUM(l.points) FROM bx_loyalty_ledger l WHERE l.order_id=NEW.id AND l.kind IN ('redeem','restore')),0)>0
 ELSE -f.points_used-COALESCE((SELECT SUM(l.points) FROM bx_loyalty_ledger l WHERE l.order_id=NEW.id AND l.kind IN ('redeem','restore')),0)<0 END;
END;
-- Уходим из состояния «доставлен и оплачен»: отменяем именно уже начисленный кэшбэк.
CREATE TRIGGER IF NOT EXISTS bx_cashback_reverse AFTER UPDATE OF status,payment_status ON orders
WHEN OLD.status='delivered' AND OLD.payment_status='paid' AND (NEW.status!='delivered' OR NEW.payment_status!='paid') BEGIN
 INSERT INTO bx_loyalty_ledger(id,customer_id,order_id,kind,points,operation_key,note)
 SELECT lower(hex(randomblob(16))),f.customer_id,NEW.id,'reversal',
 -COALESCE((SELECT SUM(l.points) FROM bx_loyalty_ledger l WHERE l.order_id=NEW.id AND l.kind IN ('earn','reversal')),0),
 lower(hex(randomblob(16))),'Корректировка кэшбэка при изменении заказа'
 FROM bx_order_finance f WHERE f.order_id=NEW.id AND f.customer_id IS NOT NULL
 AND COALESCE((SELECT SUM(l.points) FROM bx_loyalty_ledger l WHERE l.order_id=NEW.id AND l.kind IN ('earn','reversal')),0)>0;
END;
-- Входим в состояние «доставлен и оплачен»: начисляем по актуальному уровню.
CREATE TRIGGER IF NOT EXISTS bx_cashback_recalculate AFTER UPDATE OF status,payment_status ON orders
WHEN NEW.status='delivered' AND NEW.payment_status='paid' AND (OLD.status!='delivered' OR OLD.payment_status!='paid') BEGIN
 INSERT INTO bx_loyalty_ledger(id,customer_id,order_id,kind,points,operation_key,note)
 SELECT lower(hex(randomblob(16))),f.customer_id,NEW.id,'earn',
 CAST(NEW.total * COALESCE((SELECT CASE level WHEN 'start' THEN 5 WHEN 'progress' THEN 10 WHEN 'power' THEN 25 WHEN 'peak' THEN 50 END FROM bx_customer_levels WHERE customer_id=f.customer_id),
 CASE WHEN (SELECT COALESCE(SUM(o.total),0) FROM orders o JOIN bx_order_finance x ON x.order_id=o.id WHERE x.customer_id=f.customer_id AND o.status='delivered' AND o.payment_status='paid' AND o.id!=NEW.id)>=80000 THEN 50
 WHEN (SELECT COALESCE(SUM(o.total),0) FROM orders o JOIN bx_order_finance x ON x.order_id=o.id WHERE x.customer_id=f.customer_id AND o.status='delivered' AND o.payment_status='paid' AND o.id!=NEW.id)>=40000 THEN 25
 WHEN (SELECT COALESCE(SUM(o.total),0) FROM orders o JOIN bx_order_finance x ON x.order_id=o.id WHERE x.customer_id=f.customer_id AND o.status='delivered' AND o.payment_status='paid' AND o.id!=NEW.id)>=15000 THEN 10 ELSE 5 END)/100 AS INTEGER),
 lower(hex(randomblob(16))),'Кэшбэк за доставленный и оплаченный заказ'
 FROM bx_order_finance f WHERE f.order_id=NEW.id AND f.customer_id IS NOT NULL AND
 CAST(NEW.total * COALESCE((SELECT CASE level WHEN 'start' THEN 5 WHEN 'progress' THEN 10 WHEN 'power' THEN 25 WHEN 'peak' THEN 50 END FROM bx_customer_levels WHERE customer_id=f.customer_id),
 CASE WHEN (SELECT COALESCE(SUM(o.total),0) FROM orders o JOIN bx_order_finance x ON x.order_id=o.id WHERE x.customer_id=f.customer_id AND o.status='delivered' AND o.payment_status='paid' AND o.id!=NEW.id)>=80000 THEN 50
 WHEN (SELECT COALESCE(SUM(o.total),0) FROM orders o JOIN bx_order_finance x ON x.order_id=o.id WHERE x.customer_id=f.customer_id AND o.status='delivered' AND o.payment_status='paid' AND o.id!=NEW.id)>=40000 THEN 25
 WHEN (SELECT COALESCE(SUM(o.total),0) FROM orders o JOIN bx_order_finance x ON x.order_id=o.id WHERE x.customer_id=f.customer_id AND o.status='delivered' AND o.payment_status='paid' AND o.id!=NEW.id)>=15000 THEN 10 ELSE 5 END)/100 AS INTEGER)>0;
END;
CREATE TRIGGER IF NOT EXISTS bx_notify_ledger AFTER INSERT ON bx_loyalty_ledger
WHEN NEW.kind IN ('welcome','earn','redeem','restore','reversal')
 AND COALESCE((SELECT enabled FROM bx_notification_flags WHERE entity_key='order:'||NEW.order_id),1)=1 BEGIN
 INSERT OR IGNORE INTO bx_notifications(id,customer_id,body) VALUES('ledger:'||NEW.id,NEW.customer_id,
 CASE NEW.kind
 WHEN 'welcome' THEN '✦ BIORYX CLUB'||char(10)||char(10)||'Добро пожаловать! Начислено +'||NEW.points||' баллов.'
 WHEN 'earn' THEN '✦ BIORYX CLUB'||char(10)||char(10)||'Начислено +'||NEW.points||' баллов за заказ. Спасибо, что выбираете BIORYX!'
 WHEN 'redeem' THEN '✦ BIORYX CLUB'||char(10)||char(10)||'Списано '||(-NEW.points)||' баллов за заказ.'
 WHEN 'reversal' THEN '✦ BIORYX CLUB'||char(10)||char(10)||'После изменения заказа ранее начисленный кэшбэк скорректирован на '||NEW.points||' баллов.'
 ELSE '✦ BIORYX CLUB'||char(10)||char(10)||'После отмены заказа возвращено +'||NEW.points||' баллов.' END);
END;
CREATE TRIGGER IF NOT EXISTS bx_auto_level_transitions AFTER UPDATE OF status,payment_status ON orders
WHEN (OLD.status='delivered' AND OLD.payment_status='paid') != (NEW.status='delivered' AND NEW.payment_status='paid')
 AND COALESCE((SELECT enabled FROM bx_notification_flags WHERE entity_key='order:'||NEW.id),1)=1 BEGIN
 INSERT INTO bx_notifications(id,customer_id,body)
 SELECT 'auto-level:'||lower(hex(randomblob(16))),f.customer_id,
 '✦ BIORYX CLUB'||char(10)||char(10)||'Ваш уровень обновлён: '||
 CASE WHEN (SELECT COALESCE(SUM(o.total),0) FROM orders o JOIN bx_order_finance x ON x.order_id=o.id WHERE x.customer_id=f.customer_id AND o.status='delivered' AND o.payment_status='paid')>=80000 THEN 'ПИК'
 WHEN (SELECT COALESCE(SUM(o.total),0) FROM orders o JOIN bx_order_finance x ON x.order_id=o.id WHERE x.customer_id=f.customer_id AND o.status='delivered' AND o.payment_status='paid')>=40000 THEN 'СИЛА'
 WHEN (SELECT COALESCE(SUM(o.total),0) FROM orders o JOIN bx_order_finance x ON x.order_id=o.id WHERE x.customer_id=f.customer_id AND o.status='delivered' AND o.payment_status='paid')>=15000 THEN 'ПРОГРЕСС' ELSE 'СТАРТ' END||'.'
 FROM bx_order_finance f WHERE f.order_id=NEW.id AND f.customer_id IS NOT NULL AND NOT EXISTS(SELECT 1 FROM bx_customer_levels WHERE customer_id=f.customer_id)
 AND (SELECT COUNT(*) FROM (SELECT 15000 AS threshold UNION ALL SELECT 40000 UNION ALL SELECT 80000) t
 WHERE ((SELECT COALESCE(SUM(o.total),0) FROM orders o JOIN bx_order_finance x ON x.order_id=o.id WHERE x.customer_id=f.customer_id AND o.status='delivered' AND o.payment_status='paid') >= t.threshold) !=
 (((SELECT COALESCE(SUM(o.total),0) FROM orders o JOIN bx_order_finance x ON x.order_id=o.id WHERE x.customer_id=f.customer_id AND o.status='delivered' AND o.payment_status='paid')
 - CASE WHEN NEW.status='delivered' AND NEW.payment_status='paid' THEN NEW.total ELSE 0 END
 + CASE WHEN OLD.status='delivered' AND OLD.payment_status='paid' THEN OLD.total ELSE 0 END) >= t.threshold))>0;
END;

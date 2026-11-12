-- BIORYX, после 0015. Снимки подарков привязаны к заказам и не меняются при редактировании акции.
CREATE TABLE IF NOT EXISTS bx_promo_no_discount (code TEXT PRIMARY KEY REFERENCES bx_promos(code));
CREATE TABLE IF NOT EXISTS bx_promo_gifts (
 code TEXT PRIMARY KEY REFERENCES bx_promos(code), product_id TEXT NOT NULL DEFAULT '',
 qty INTEGER NOT NULL DEFAULT 0 CHECK(qty BETWEEN 0 AND 20), description TEXT NOT NULL DEFAULT '',
 CHECK((product_id='' AND qty=0) OR (product_id!='' AND qty BETWEEN 1 AND 20)),
 CHECK(product_id!='' OR length(description)>0)
);
CREATE TABLE IF NOT EXISTS bx_promo_expectations (
 order_id TEXT PRIMARY KEY REFERENCES orders(id),code TEXT NOT NULL,product_id TEXT NOT NULL,qty INTEGER NOT NULL,description TEXT NOT NULL, no_discount INTEGER NOT NULL CHECK(no_discount IN (0,1))
);
CREATE TABLE IF NOT EXISTS bx_order_gifts (
 order_id TEXT PRIMARY KEY REFERENCES orders(id), product_id TEXT NOT NULL DEFAULT '',
 product_name TEXT NOT NULL DEFAULT '', qty INTEGER NOT NULL DEFAULT 0, description TEXT NOT NULL DEFAULT ''
);
DROP TRIGGER IF EXISTS bx_finance_guard;
CREATE TRIGGER bx_finance_guard BEFORE INSERT ON bx_order_finance BEGIN
 SELECT CASE WHEN NOT EXISTS(SELECT 1 FROM orders WHERE id=NEW.order_id AND total=NEW.gross AND status='new') THEN RAISE(ABORT,'bad_gross') END;
 SELECT CASE WHEN NEW.promo_code='' AND (NEW.promo_percent!=0 OR NEW.discount!=0) THEN RAISE(ABORT,'bad_promo') END;
 SELECT CASE WHEN NEW.promo_code!='' AND NOT EXISTS(
 SELECT 1 FROM bx_promos p LEFT JOIN bx_promo_amounts a ON a.code=p.code LEFT JOIN bx_promo_no_discount n ON n.code=p.code
 WHERE p.code=NEW.promo_code AND p.active=1 AND ((n.code IS NOT NULL AND a.code IS NULL AND NEW.promo_percent=0) OR (n.code IS NULL AND a.code IS NOT NULL AND NEW.promo_percent=0) OR (n.code IS NULL AND a.code IS NULL AND p.percent=NEW.promo_percent))
 ) THEN RAISE(ABORT,'invalid_promo') END;
 SELECT CASE WHEN NEW.promo_code!='' AND NEW.discount != CASE WHEN EXISTS(SELECT 1 FROM bx_promo_no_discount WHERE code=NEW.promo_code) THEN 0 ELSE COALESCE((SELECT min(NEW.gross,a.amount) FROM bx_promo_amounts a WHERE a.code=NEW.promo_code),CAST(NEW.gross*NEW.promo_percent/100 AS INTEGER)) END THEN RAISE(ABORT,'bad_discount') END;
 SELECT CASE WHEN NEW.points_used>NEW.gross-NEW.discount THEN RAISE(ABORT,'bad_discount') END;
 SELECT CASE WHEN NEW.points_used>0 AND (NEW.customer_id IS NULL OR NOT EXISTS(SELECT 1 FROM bx_order_owners WHERE order_id=NEW.order_id AND customer_id=NEW.customer_id)) THEN RAISE(ABORT,'customer_required') END;
 SELECT CASE WHEN NEW.points_used>0 AND NEW.points_used > COALESCE((SELECT SUM(points) FROM bx_loyalty_ledger WHERE customer_id=NEW.customer_id),0) THEN RAISE(ABORT,'insufficient_points') END;
 SELECT CASE WHEN NEW.promo_code!='' AND (EXISTS(SELECT 1 FROM bx_promo_gifts WHERE code=NEW.promo_code) OR EXISTS(SELECT 1 FROM bx_promo_no_discount WHERE code=NEW.promo_code) OR EXISTS(SELECT 1 FROM bx_promo_expectations WHERE order_id=NEW.order_id)) AND NOT EXISTS (
 SELECT 1 FROM bx_promo_expectations e LEFT JOIN bx_promo_gifts g ON g.code=NEW.promo_code LEFT JOIN bx_promo_no_discount n ON n.code=NEW.promo_code
 WHERE e.order_id=NEW.order_id AND e.code=NEW.promo_code AND e.product_id=COALESCE(g.product_id,'') AND e.qty=COALESCE(g.qty,0) AND e.description=COALESCE(g.description,'') AND e.no_discount=CASE WHEN n.code IS NULL THEN 0 ELSE 1 END
 ) THEN RAISE(ABORT,'promo_gift_changed') END;
END;
DROP TRIGGER IF EXISTS bx_promo_snapshot;
CREATE TRIGGER bx_promo_snapshot AFTER INSERT ON bx_order_finance WHEN NEW.promo_code!='' AND NOT EXISTS(SELECT 1 FROM bx_promo_no_discount WHERE code=NEW.promo_code) BEGIN
 INSERT INTO bx_promo_order_snapshots(order_id,kind,value) SELECT NEW.order_id,CASE WHEN a.code IS NULL THEN 'percent' ELSE 'fixed' END,COALESCE(a.amount,NEW.promo_percent) FROM bx_promos p LEFT JOIN bx_promo_amounts a ON a.code=p.code WHERE p.code=NEW.promo_code;
END;
CREATE TRIGGER IF NOT EXISTS bx_promo_gift_add AFTER INSERT ON bx_order_finance WHEN NEW.promo_code!='' BEGIN
 INSERT INTO bx_order_gifts(order_id,product_id,product_name,qty,description)
 SELECT NEW.order_id,g.product_id,COALESCE((SELECT name FROM products WHERE id=g.product_id),''),g.qty,g.description FROM bx_promo_gifts g WHERE g.code=NEW.promo_code;
END;
CREATE TRIGGER IF NOT EXISTS bx_gift_reserve_guard BEFORE INSERT ON bx_order_gifts WHEN NEW.product_id!='' BEGIN
 SELECT CASE WHEN NOT EXISTS(SELECT 1 FROM products WHERE id=NEW.product_id AND active=1 AND stock>=NEW.qty AND name=NEW.product_name) THEN RAISE(ABORT,'gift_unavailable') END;
END;
CREATE TRIGGER IF NOT EXISTS bx_gift_reserve AFTER INSERT ON bx_order_gifts WHEN NEW.product_id!='' BEGIN
 UPDATE products SET stock=stock-NEW.qty WHERE id=NEW.product_id;
END;
-- Проверяется совокупный остаток подарка и всех купленных единиц того же товара.
CREATE TRIGGER IF NOT EXISTS bx_gift_reopen_guard BEFORE UPDATE OF status ON orders WHEN OLD.status='cancelled' AND NEW.status!='cancelled' BEGIN
 SELECT CASE WHEN EXISTS(SELECT 1 FROM bx_order_gifts g LEFT JOIN products p ON p.id=g.product_id WHERE g.order_id=NEW.id AND g.product_id!='' AND (p.id IS NULL OR p.stock < g.qty+COALESCE((SELECT sum(i.qty) FROM order_items i WHERE i.order_id=NEW.id AND i.product_id=g.product_id),0))) THEN RAISE(ABORT,'insufficient_stock_to_reopen_gift') END;
END;
CREATE TRIGGER IF NOT EXISTS bx_gift_stock_transitions AFTER UPDATE OF status ON orders WHEN (OLD.status='cancelled' AND NEW.status!='cancelled') OR (OLD.status!='cancelled' AND NEW.status='cancelled') BEGIN
 UPDATE products SET stock=stock+CASE WHEN NEW.status='cancelled' THEN 1 ELSE -1 END*(SELECT g.qty FROM bx_order_gifts g WHERE g.order_id=NEW.id AND g.product_id=products.id) WHERE id IN (SELECT product_id FROM bx_order_gifts WHERE order_id=NEW.id AND product_id!='');
END;

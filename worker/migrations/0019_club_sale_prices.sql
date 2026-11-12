-- BIORYX: после 0018. Закрытая цена — для конкретного товара и конкретного уровня.
CREATE TABLE IF NOT EXISTS bx_club_sale_prices (
 product_id TEXT NOT NULL REFERENCES products(id),level TEXT NOT NULL REFERENCES bx_club_levels(id),
 sale_price INTEGER NOT NULL CHECK(sale_price BETWEEN 1 AND 10000000),
 start_date TEXT NOT NULL DEFAULT '',end_date TEXT NOT NULL DEFAULT '',
 active INTEGER NOT NULL DEFAULT 1 CHECK(active IN (0,1)),updated_at TEXT NOT NULL DEFAULT(datetime('now')),
 PRIMARY KEY(product_id,level)
);
CREATE TABLE IF NOT EXISTS bx_order_sale_lines (
 order_id TEXT NOT NULL REFERENCES orders(id),product_id TEXT NOT NULL,level TEXT NOT NULL,
 base_price INTEGER NOT NULL CHECK(base_price>0),sale_price INTEGER NOT NULL CHECK(sale_price>0 AND sale_price<base_price),qty INTEGER NOT NULL CHECK(qty BETWEEN 1 AND 20),
 PRIMARY KEY(order_id,product_id)
);
CREATE TRIGGER IF NOT EXISTS bx_sale_line_guard BEFORE INSERT ON bx_order_sale_lines BEGIN
 SELECT CASE WHEN NOT EXISTS(
 SELECT 1 FROM order_items i JOIN products p ON p.id=i.product_id JOIN bx_order_owners ow ON ow.order_id=i.order_id
 JOIN bx_club_sale_prices s ON s.product_id=i.product_id AND s.level=NEW.level
 WHERE i.order_id=NEW.order_id AND i.product_id=NEW.product_id AND i.price=NEW.base_price AND i.qty=NEW.qty AND p.price=NEW.base_price AND p.active=1
 AND s.active=1 AND s.sale_price=NEW.sale_price AND s.sale_price<p.price
 AND (s.start_date='' OR date('now')>=s.start_date) AND (s.end_date='' OR date('now')<=s.end_date)
 AND s.level=COALESCE((SELECT level FROM bx_customer_levels WHERE customer_id=ow.customer_id),
 (SELECT l.id FROM bx_club_levels l WHERE l.threshold<=COALESCE((SELECT SUM(o.total) FROM orders o JOIN bx_order_finance f ON f.order_id=o.id WHERE f.customer_id=ow.customer_id AND o.status='delivered' AND o.payment_status='paid'),0) ORDER BY l.threshold DESC LIMIT 1))
 ) THEN RAISE(ABORT,'club_sale_changed') END;
END;
CREATE TRIGGER IF NOT EXISTS bx_sale_finance_guard BEFORE INSERT ON bx_order_finance BEGIN
 SELECT CASE WHEN EXISTS(SELECT 1 FROM bx_order_sale_lines WHERE order_id=NEW.order_id) AND (NEW.customer_id IS NULL OR NOT EXISTS(SELECT 1 FROM bx_order_owners WHERE order_id=NEW.order_id AND customer_id=NEW.customer_id)) THEN RAISE(ABORT,'club_sale_customer_required') END;
 SELECT CASE WHEN EXISTS(
 SELECT 1 FROM order_items i JOIN products p ON p.id=i.product_id JOIN bx_order_owners ow ON ow.order_id=i.order_id
 JOIN bx_club_sale_prices s ON s.product_id=i.product_id
 WHERE i.order_id=NEW.order_id AND s.active=1 AND s.sale_price<p.price
 AND (s.start_date='' OR date('now')>=s.start_date) AND (s.end_date='' OR date('now')<=s.end_date)
 AND s.level=COALESCE((SELECT level FROM bx_customer_levels WHERE customer_id=ow.customer_id),
 (SELECT l.id FROM bx_club_levels l WHERE l.threshold<=COALESCE((SELECT SUM(o.total) FROM orders o JOIN bx_order_finance f ON f.order_id=o.id WHERE f.customer_id=ow.customer_id AND o.status='delivered' AND o.payment_status='paid'),0) ORDER BY l.threshold DESC LIMIT 1))
 AND NOT EXISTS(SELECT 1 FROM bx_order_sale_lines x WHERE x.order_id=i.order_id AND x.product_id=i.product_id AND x.sale_price=s.sale_price AND x.base_price=i.price AND x.qty=i.qty AND x.level=s.level)
 ) THEN RAISE(ABORT,'club_sale_quote_missing') END;
END;

DROP TRIGGER IF EXISTS bx_finance_guard;
CREATE TRIGGER bx_finance_guard BEFORE INSERT ON bx_order_finance BEGIN
 SELECT CASE WHEN NOT EXISTS(SELECT 1 FROM orders WHERE id=NEW.order_id AND total=NEW.gross AND status='new') THEN RAISE(ABORT,'bad_gross') END;
 SELECT CASE WHEN NEW.promo_code='' AND (NEW.promo_percent!=0 OR NEW.discount!=0) THEN RAISE(ABORT,'bad_promo') END;
 SELECT CASE WHEN NEW.promo_code!='' AND NOT EXISTS(
 SELECT 1 FROM bx_promos p LEFT JOIN bx_promo_amounts a ON a.code=p.code LEFT JOIN bx_promo_no_discount n ON n.code=p.code
 WHERE p.code=NEW.promo_code AND p.active=1 AND ((n.code IS NOT NULL AND a.code IS NULL AND NEW.promo_percent=0) OR (n.code IS NULL AND a.code IS NOT NULL AND NEW.promo_percent=0) OR (n.code IS NULL AND a.code IS NULL AND p.percent=NEW.promo_percent))
 ) THEN RAISE(ABORT,'invalid_promo') END;
 SELECT CASE WHEN NEW.promo_code!='' AND NEW.discount != CASE WHEN EXISTS(SELECT 1 FROM bx_promo_no_discount WHERE code=NEW.promo_code) THEN 0 ELSE COALESCE((SELECT min((NEW.gross-COALESCE((SELECT SUM((x.base_price-x.sale_price)*x.qty) FROM bx_order_sale_lines x WHERE x.order_id=NEW.order_id),0)),a.amount) FROM bx_promo_amounts a WHERE a.code=NEW.promo_code),CAST((NEW.gross-COALESCE((SELECT SUM((x.base_price-x.sale_price)*x.qty) FROM bx_order_sale_lines x WHERE x.order_id=NEW.order_id),0))*NEW.promo_percent/100 AS INTEGER)) END THEN RAISE(ABORT,'bad_discount') END;
 SELECT CASE WHEN NEW.points_used>(NEW.gross-COALESCE((SELECT SUM((x.base_price-x.sale_price)*x.qty) FROM bx_order_sale_lines x WHERE x.order_id=NEW.order_id),0))-NEW.discount THEN RAISE(ABORT,'bad_discount') END;
 SELECT CASE WHEN NEW.points_used>0 AND (NEW.customer_id IS NULL OR NOT EXISTS(SELECT 1 FROM bx_order_owners WHERE order_id=NEW.order_id AND customer_id=NEW.customer_id)) THEN RAISE(ABORT,'customer_required') END;
 SELECT CASE WHEN NEW.points_used>0 AND NEW.points_used > COALESCE((SELECT SUM(points) FROM bx_loyalty_ledger WHERE customer_id=NEW.customer_id),0) THEN RAISE(ABORT,'insufficient_points') END;
 SELECT CASE WHEN NEW.promo_code!='' AND (EXISTS(SELECT 1 FROM bx_promo_gifts WHERE code=NEW.promo_code) OR EXISTS(SELECT 1 FROM bx_promo_no_discount WHERE code=NEW.promo_code) OR EXISTS(SELECT 1 FROM bx_promo_expectations WHERE order_id=NEW.order_id)) AND NOT EXISTS (
 SELECT 1 FROM bx_promo_expectations e LEFT JOIN bx_promo_gifts g ON g.code=NEW.promo_code LEFT JOIN bx_promo_no_discount n ON n.code=NEW.promo_code
 WHERE e.order_id=NEW.order_id AND e.code=NEW.promo_code AND e.product_id=COALESCE(g.product_id,'') AND e.qty=COALESCE(g.qty,0) AND e.description=COALESCE(g.description,'') AND e.no_discount=CASE WHEN n.code IS NULL THEN 0 ELSE 1 END
 ) THEN RAISE(ABORT,'promo_gift_changed') END;
END;

DROP TRIGGER IF EXISTS bx_club_redeem_limit;
CREATE TRIGGER bx_club_redeem_limit BEFORE INSERT ON bx_order_finance BEGIN
 SELECT CASE WHEN NEW.points_used>CAST(((NEW.gross-COALESCE((SELECT SUM((x.base_price-x.sale_price)*x.qty) FROM bx_order_sale_lines x WHERE x.order_id=NEW.order_id),0))-NEW.discount)*COALESCE((SELECT redeem_percent FROM bx_club_settings WHERE id=1),100)/100 AS INTEGER) THEN RAISE(ABORT,'club_redeem_limit') END;
END;
DROP TRIGGER IF EXISTS bx_finance_apply;
CREATE TRIGGER bx_finance_apply AFTER INSERT ON bx_order_finance BEGIN
 UPDATE orders SET total=(NEW.gross-COALESCE((SELECT SUM((x.base_price-x.sale_price)*x.qty) FROM bx_order_sale_lines x WHERE x.order_id=NEW.order_id),0))-NEW.discount-NEW.points_used WHERE id=NEW.order_id;
 INSERT INTO bx_loyalty_ledger(id,customer_id,order_id,kind,points,operation_key,note)
 SELECT 'redeem:'||NEW.order_id,NEW.customer_id,NEW.order_id,'redeem',-NEW.points_used,'redeem:'||NEW.order_id,'Оплата баллами' WHERE NEW.points_used>0;
END;

-- BIORYX: после 0017. Если уровни не указаны, акция публичная.
CREATE TABLE IF NOT EXISTS bx_promo_levels (
 code TEXT NOT NULL REFERENCES bx_promos(code),
 level TEXT NOT NULL REFERENCES bx_club_levels(id),
 PRIMARY KEY(code,level)
);
CREATE TABLE IF NOT EXISTS bx_order_promo_access (
 order_id TEXT PRIMARY KEY REFERENCES orders(id),
 code TEXT NOT NULL,
 customer_id TEXT NOT NULL REFERENCES bx_customers(id),
 level TEXT NOT NULL
);
CREATE TRIGGER IF NOT EXISTS bx_promo_level_guard BEFORE INSERT ON bx_order_finance
WHEN NEW.promo_code!='' AND EXISTS(SELECT 1 FROM bx_promo_levels WHERE code=NEW.promo_code) BEGIN
 SELECT CASE WHEN NEW.customer_id IS NULL OR NOT EXISTS(SELECT 1 FROM bx_order_owners WHERE order_id=NEW.order_id AND customer_id=NEW.customer_id) OR NOT EXISTS(
  SELECT 1 FROM bx_promo_levels a WHERE a.code=NEW.promo_code AND a.level=COALESCE(
   (SELECT level FROM bx_customer_levels WHERE customer_id=NEW.customer_id),
   (SELECT l.id FROM bx_club_levels l WHERE l.threshold<=COALESCE((SELECT sum(o.total) FROM orders o JOIN bx_order_finance f ON f.order_id=o.id WHERE f.customer_id=NEW.customer_id AND o.status='delivered' AND o.payment_status='paid' AND o.id!=NEW.order_id),0) ORDER BY l.threshold DESC LIMIT 1)
  )
 ) THEN RAISE(ABORT,'promo_level_not_allowed') END;
END;
CREATE TRIGGER IF NOT EXISTS bx_promo_level_snapshot AFTER INSERT ON bx_order_finance
WHEN NEW.promo_code!='' AND EXISTS(SELECT 1 FROM bx_promo_levels WHERE code=NEW.promo_code) BEGIN
 INSERT INTO bx_order_promo_access(order_id,code,customer_id,level)
 SELECT NEW.order_id,NEW.promo_code,NEW.customer_id,COALESCE(
  (SELECT level FROM bx_customer_levels WHERE customer_id=NEW.customer_id),
  (SELECT l.id FROM bx_club_levels l WHERE l.threshold<=COALESCE((SELECT sum(o.total) FROM orders o JOIN bx_order_finance f ON f.order_id=o.id WHERE f.customer_id=NEW.customer_id AND o.status='delivered' AND o.payment_status='paid' AND o.id!=NEW.order_id),0) ORDER BY l.threshold DESC LIMIT 1)
 );
END;

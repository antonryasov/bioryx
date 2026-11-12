-- BIORYX: после 0016. Доставка по-прежнему рассчитывается вручную, кроме зафиксированного преимущества.
CREATE TABLE IF NOT EXISTS bx_promo_shipping (
 code TEXT PRIMARY KEY REFERENCES bx_promos(code),
 methods TEXT NOT NULL CHECK(methods IN ('courier','cdek','both'))
);
CREATE TABLE IF NOT EXISTS bx_shipping_expectations (
 order_id TEXT PRIMARY KEY REFERENCES orders(id),
 code TEXT NOT NULL, methods TEXT NOT NULL CHECK(methods IN ('','courier','cdek','both'))
);
CREATE TABLE IF NOT EXISTS bx_order_shipping_benefits (
 order_id TEXT PRIMARY KEY REFERENCES orders(id),
 code TEXT NOT NULL, delivery TEXT NOT NULL,
 methods TEXT NOT NULL CHECK(methods IN ('courier','cdek','both')),
 free_shipping INTEGER NOT NULL CHECK(free_shipping IN (0,1))
);
CREATE TRIGGER IF NOT EXISTS bx_shipping_conditions_guard BEFORE INSERT ON bx_order_finance WHEN NEW.promo_code!='' BEGIN

 SELECT CASE WHEN (EXISTS(SELECT 1 FROM bx_promo_shipping WHERE code=NEW.promo_code) OR EXISTS(SELECT 1 FROM bx_shipping_expectations WHERE order_id=NEW.order_id)) AND NOT EXISTS(
 SELECT 1 FROM bx_shipping_expectations e LEFT JOIN bx_promo_shipping s ON s.code=NEW.promo_code
 WHERE e.order_id=NEW.order_id AND e.code=NEW.promo_code AND e.methods=COALESCE(s.methods,'')
 ) THEN RAISE(ABORT,'promo_shipping_changed') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM bx_promo_no_discount WHERE code=NEW.promo_code) AND NOT EXISTS(SELECT 1 FROM bx_promo_gifts WHERE code=NEW.promo_code) AND NOT EXISTS(
 SELECT 1 FROM bx_promo_shipping s JOIN orders o ON o.id=NEW.order_id WHERE s.code=NEW.promo_code AND ((s.methods='both' AND o.delivery IN ('courier','cdek')) OR s.methods=o.delivery)
 ) THEN RAISE(ABORT,'promo_shipping_not_applicable') END;
END;
CREATE TRIGGER IF NOT EXISTS bx_shipping_benefit_snapshot AFTER INSERT ON bx_order_finance WHEN NEW.promo_code!='' BEGIN
 INSERT INTO bx_order_shipping_benefits(order_id,code,delivery,methods,free_shipping)
 SELECT NEW.order_id,NEW.promo_code,o.delivery,s.methods,CASE WHEN (s.methods='both' AND o.delivery IN ('courier','cdek')) OR s.methods=o.delivery THEN 1 ELSE 0 END
 FROM bx_promo_shipping s JOIN orders o ON o.id=NEW.order_id WHERE s.code=NEW.promo_code;
END;

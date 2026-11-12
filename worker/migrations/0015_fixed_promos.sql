-- BIORYX: после 0014. Отсутствие строки bx_promo_amounts означает прежнюю процентную скидку.
CREATE TABLE IF NOT EXISTS bx_promo_amounts (
 code TEXT PRIMARY KEY REFERENCES bx_promos(code),
 amount INTEGER NOT NULL CHECK(amount BETWEEN 1 AND 10000000)
);
CREATE TABLE IF NOT EXISTS bx_promo_order_snapshots (
 order_id TEXT PRIMARY KEY REFERENCES orders(id),
 kind TEXT NOT NULL CHECK(kind IN ('percent','fixed')),
 value INTEGER NOT NULL CHECK(value>=1)
);
DROP TRIGGER IF EXISTS bx_finance_guard;
CREATE TRIGGER bx_finance_guard BEFORE INSERT ON bx_order_finance BEGIN
 SELECT CASE WHEN NOT EXISTS(SELECT 1 FROM orders WHERE id=NEW.order_id AND total=NEW.gross AND status='new') THEN RAISE(ABORT,'bad_gross') END;
 SELECT CASE WHEN NEW.promo_code='' AND (NEW.promo_percent!=0 OR NEW.discount!=0) THEN RAISE(ABORT,'bad_promo') END;
 SELECT CASE WHEN NEW.promo_code!='' AND NOT EXISTS(
  SELECT 1 FROM bx_promos p LEFT JOIN bx_promo_amounts a ON a.code=p.code
  WHERE p.code=NEW.promo_code AND p.active=1 AND ((a.code IS NULL AND p.percent=NEW.promo_percent) OR (a.code IS NOT NULL AND NEW.promo_percent=0))
 ) THEN RAISE(ABORT,'invalid_promo') END;
 SELECT CASE WHEN NEW.promo_code!='' AND NEW.discount != COALESCE(
  (SELECT min(NEW.gross,a.amount) FROM bx_promo_amounts a WHERE a.code=NEW.promo_code),
  CAST(NEW.gross*NEW.promo_percent/100 AS INTEGER)
 ) THEN RAISE(ABORT,'bad_discount') END;
 SELECT CASE WHEN NEW.points_used>NEW.gross-NEW.discount THEN RAISE(ABORT,'bad_discount') END;
 SELECT CASE WHEN NEW.points_used>0 AND (NEW.customer_id IS NULL OR NOT EXISTS(SELECT 1 FROM bx_order_owners WHERE order_id=NEW.order_id AND customer_id=NEW.customer_id)) THEN RAISE(ABORT,'customer_required') END;
 SELECT CASE WHEN NEW.points_used>0 AND NEW.points_used > COALESCE((SELECT SUM(points) FROM bx_loyalty_ledger WHERE customer_id=NEW.customer_id),0) THEN RAISE(ABORT,'insufficient_points') END;
END;
CREATE TRIGGER IF NOT EXISTS bx_promo_snapshot AFTER INSERT ON bx_order_finance WHEN NEW.promo_code!='' BEGIN
 INSERT INTO bx_promo_order_snapshots(order_id,kind,value)
 SELECT NEW.order_id,CASE WHEN a.code IS NULL THEN 'percent' ELSE 'fixed' END,COALESCE(a.amount,NEW.promo_percent)
 FROM bx_promos p LEFT JOIN bx_promo_amounts a ON a.code=p.code WHERE p.code=NEW.promo_code;
END;

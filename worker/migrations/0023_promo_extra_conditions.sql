-- BIORYX после 0022. Лимиты считают все сохранённые заказы, включая отменённые.
CREATE TABLE IF NOT EXISTS bx_promo_extra (
 code TEXT PRIMARY KEY REFERENCES bx_promos(code),
 require_login INTEGER NOT NULL DEFAULT 0 CHECK(require_login IN (0,1)),
 first_linked_order INTEGER NOT NULL DEFAULT 0 CHECK(first_linked_order IN (0,1)),
 max_per_customer INTEGER NOT NULL DEFAULT 0 CHECK(max_per_customer BETWEEN 0 AND 10000000),
 required_product TEXT NOT NULL DEFAULT '',
 min_quantity INTEGER NOT NULL DEFAULT 0 CHECK(min_quantity BETWEEN 0 AND 20),
 CHECK((required_product='' AND min_quantity=0) OR (required_product!='' AND min_quantity BETWEEN 1 AND 20))
);
CREATE INDEX IF NOT EXISTS bx_finance_promo_customer ON bx_order_finance(promo_code,customer_id);
CREATE TRIGGER IF NOT EXISTS bx_promo_extra_guard BEFORE INSERT ON bx_order_finance
WHEN NEW.promo_code!='' BEGIN
 SELECT CASE WHEN EXISTS(SELECT 1 FROM bx_promo_extra x WHERE x.code=NEW.promo_code
  AND (x.require_login=1 OR x.first_linked_order=1 OR x.max_per_customer>0)
  AND (NEW.customer_id IS NULL OR NOT EXISTS(SELECT 1 FROM bx_order_owners ow WHERE ow.order_id=NEW.order_id AND ow.customer_id=NEW.customer_id)))
 THEN RAISE(ABORT,'promo_login_required') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM bx_promo_extra x WHERE x.code=NEW.promo_code AND x.first_linked_order=1
  AND EXISTS(SELECT 1 FROM bx_order_owners ow WHERE ow.customer_id=NEW.customer_id AND ow.order_id!=NEW.order_id))
 THEN RAISE(ABORT,'promo_first_linked_order_only') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM bx_promo_extra x WHERE x.code=NEW.promo_code AND x.max_per_customer>0
  AND (SELECT COUNT(*) FROM bx_order_finance f WHERE f.promo_code=NEW.promo_code AND f.customer_id=NEW.customer_id)>=x.max_per_customer)
 THEN RAISE(ABORT,'promo_customer_limit') END;
 SELECT CASE WHEN EXISTS(SELECT 1 FROM bx_promo_extra x WHERE x.code=NEW.promo_code AND x.required_product!=''
  AND COALESCE((SELECT SUM(i.qty) FROM order_items i WHERE i.order_id=NEW.order_id AND i.product_id=x.required_product),0)<x.min_quantity)
 THEN RAISE(ABORT,'promo_required_product') END;
END;
CREATE TRIGGER IF NOT EXISTS bx_extra_audit_insert AFTER INSERT ON bx_promo_extra BEGIN
 INSERT INTO bx_config_audit(module,entity,entity_key,action,old_json,new_json) VALUES('promo','bx_promo_extra',NEW.code,'insert',NULL,json_object('require_login',NEW.require_login,'first_linked_order',NEW.first_linked_order,'max_per_customer',NEW.max_per_customer,'required_product',NEW.required_product,'min_quantity',NEW.min_quantity));
END;
CREATE TRIGGER IF NOT EXISTS bx_extra_audit_update AFTER UPDATE ON bx_promo_extra WHEN OLD.require_login IS NOT NEW.require_login OR OLD.first_linked_order IS NOT NEW.first_linked_order OR OLD.max_per_customer IS NOT NEW.max_per_customer OR OLD.required_product IS NOT NEW.required_product OR OLD.min_quantity IS NOT NEW.min_quantity BEGIN
 INSERT INTO bx_config_audit(module,entity,entity_key,action,old_json,new_json) VALUES('promo','bx_promo_extra',NEW.code,'update',json_object('require_login',OLD.require_login,'first_linked_order',OLD.first_linked_order,'max_per_customer',OLD.max_per_customer,'required_product',OLD.required_product,'min_quantity',OLD.min_quantity),json_object('require_login',NEW.require_login,'first_linked_order',NEW.first_linked_order,'max_per_customer',NEW.max_per_customer,'required_product',NEW.required_product,'min_quantity',NEW.min_quantity));
END;

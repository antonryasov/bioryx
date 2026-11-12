-- BIORYX после 0020. Себестоимость в целых рублях; NULL означает «неизвестно», не ноль.
CREATE TABLE IF NOT EXISTS bx_product_costs (
 product_id TEXT PRIMARY KEY REFERENCES products(id),
 unit_cost INTEGER CHECK(unit_cost IS NULL OR unit_cost BETWEEN 0 AND 10000000),
 updated_at TEXT NOT NULL DEFAULT(datetime('now'))
);
CREATE TABLE IF NOT EXISTS bx_order_cost_lines (
 id INTEGER PRIMARY KEY AUTOINCREMENT,
 order_id TEXT NOT NULL REFERENCES orders(id),
 kind TEXT NOT NULL CHECK(kind IN ('sold','gift_product','gift_other')),
 source_key TEXT NOT NULL, name TEXT NOT NULL,
 qty INTEGER NOT NULL CHECK(qty>0),
 unit_cost INTEGER CHECK(unit_cost IS NULL OR unit_cost BETWEEN 0 AND 10000000),
 updated_at TEXT NOT NULL DEFAULT(datetime('now')),
 UNIQUE(order_id,kind,source_key)
);
CREATE INDEX IF NOT EXISTS bx_order_cost_order ON bx_order_cost_lines(order_id);
INSERT OR IGNORE INTO bx_order_cost_lines(order_id,kind,source_key,name,qty,unit_cost)
 SELECT order_id,'sold',CAST(id AS TEXT),name,qty,NULL FROM order_items;
INSERT OR IGNORE INTO bx_order_cost_lines(order_id,kind,source_key,name,qty,unit_cost)
 SELECT order_id,'gift_product',product_id,product_name,qty,NULL FROM bx_order_gifts WHERE product_id!='';
INSERT OR IGNORE INTO bx_order_cost_lines(order_id,kind,source_key,name,qty,unit_cost)
 SELECT order_id,'gift_other','description',description,1,NULL FROM bx_order_gifts WHERE description!='';
CREATE TRIGGER IF NOT EXISTS bx_cost_sold_snapshot AFTER INSERT ON order_items BEGIN
 INSERT INTO bx_order_cost_lines(order_id,kind,source_key,name,qty,unit_cost)
 VALUES(NEW.order_id,'sold',CAST(NEW.id AS TEXT),NEW.name,NEW.qty,(SELECT unit_cost FROM bx_product_costs WHERE product_id=NEW.product_id));
END;
CREATE TRIGGER IF NOT EXISTS bx_cost_gift_snapshot AFTER INSERT ON bx_order_gifts BEGIN
 INSERT INTO bx_order_cost_lines(order_id,kind,source_key,name,qty,unit_cost)
 SELECT NEW.order_id,'gift_product',NEW.product_id,NEW.product_name,NEW.qty,(SELECT unit_cost FROM bx_product_costs WHERE product_id=NEW.product_id) WHERE NEW.product_id!='';
 INSERT INTO bx_order_cost_lines(order_id,kind,source_key,name,qty,unit_cost)
 SELECT NEW.order_id,'gift_other','description',NEW.description,1,NULL WHERE NEW.description!='';
END;
CREATE TRIGGER IF NOT EXISTS bx_cost_catalog_insert AFTER INSERT ON bx_product_costs BEGIN
 INSERT INTO bx_config_audit(module,entity,entity_key,action,old_json,new_json) VALUES('cost','bx_product_costs',NEW.product_id,'insert',NULL,json_object('product_id',NEW.product_id,'unit_cost',NEW.unit_cost));
END;
CREATE TRIGGER IF NOT EXISTS bx_cost_catalog_update AFTER UPDATE OF unit_cost ON bx_product_costs WHEN OLD.unit_cost IS NOT NEW.unit_cost BEGIN
 INSERT INTO bx_config_audit(module,entity,entity_key,action,old_json,new_json) VALUES('cost','bx_product_costs',NEW.product_id,'update',json_object('product_id',OLD.product_id,'unit_cost',OLD.unit_cost),json_object('product_id',NEW.product_id,'unit_cost',NEW.unit_cost));
END;
CREATE TRIGGER IF NOT EXISTS bx_cost_order_update AFTER UPDATE OF unit_cost ON bx_order_cost_lines WHEN OLD.unit_cost IS NOT NEW.unit_cost BEGIN
 INSERT INTO bx_config_audit(module,entity,entity_key,action,old_json,new_json) VALUES('cost','bx_order_cost_lines',NEW.order_id||':'||NEW.id,'update',json_object('name',OLD.name,'qty',OLD.qty,'unit_cost',OLD.unit_cost),json_object('name',NEW.name,'qty',NEW.qty,'unit_cost',NEW.unit_cost));
END;

-- BIORYX: после 0019. Журнал начинается с момента установки этой миграции.
-- Триггеры выполняются в транзакции изменения; отдельные пользователи-администраторы не различаются.
CREATE TABLE IF NOT EXISTS bx_config_audit (
 id INTEGER PRIMARY KEY AUTOINCREMENT, created_at TEXT NOT NULL DEFAULT(datetime('now')),
 module TEXT NOT NULL, entity TEXT NOT NULL, entity_key TEXT NOT NULL,
 action TEXT NOT NULL CHECK(action IN ('insert','update','delete')),
 old_json TEXT, new_json TEXT
);
CREATE INDEX IF NOT EXISTS bx_config_audit_module_id ON bx_config_audit(module,id DESC);

CREATE TRIGGER IF NOT EXISTS bx_audit_bx_promos_insert AFTER INSERT ON bx_promos BEGIN
 INSERT INTO bx_config_audit(module,entity,entity_key,action,old_json,new_json) VALUES('promo','bx_promos',NEW.code,'insert',NULL,json_object('code',NEW.code,'title',NEW.title,'percent',NEW.percent,'active',NEW.active));
END;

CREATE TRIGGER IF NOT EXISTS bx_audit_bx_promos_update AFTER UPDATE ON bx_promos WHEN OLD.code IS NOT NEW.code OR OLD.title IS NOT NEW.title OR OLD.percent IS NOT NEW.percent OR OLD.active IS NOT NEW.active BEGIN
 INSERT INTO bx_config_audit(module,entity,entity_key,action,old_json,new_json) VALUES('promo','bx_promos',NEW.code,'update',json_object('code',OLD.code,'title',OLD.title,'percent',OLD.percent,'active',OLD.active),json_object('code',NEW.code,'title',NEW.title,'percent',NEW.percent,'active',NEW.active));
END;

CREATE TRIGGER IF NOT EXISTS bx_audit_bx_promos_delete AFTER DELETE ON bx_promos BEGIN
 INSERT INTO bx_config_audit(module,entity,entity_key,action,old_json,new_json) VALUES('promo','bx_promos',OLD.code,'delete',json_object('code',OLD.code,'title',OLD.title,'percent',OLD.percent,'active',OLD.active),NULL);
END;

CREATE TRIGGER IF NOT EXISTS bx_audit_bx_promo_rules_insert AFTER INSERT ON bx_promo_rules BEGIN
 INSERT INTO bx_config_audit(module,entity,entity_key,action,old_json,new_json) VALUES('promo','bx_promo_rules',NEW.code,'insert',NULL,json_object('code',NEW.code,'start_date',NEW.start_date,'end_date',NEW.end_date,'min_goods',NEW.min_goods,'max_uses',NEW.max_uses));
END;

CREATE TRIGGER IF NOT EXISTS bx_audit_bx_promo_rules_update AFTER UPDATE ON bx_promo_rules WHEN OLD.code IS NOT NEW.code OR OLD.start_date IS NOT NEW.start_date OR OLD.end_date IS NOT NEW.end_date OR OLD.min_goods IS NOT NEW.min_goods OR OLD.max_uses IS NOT NEW.max_uses BEGIN
 INSERT INTO bx_config_audit(module,entity,entity_key,action,old_json,new_json) VALUES('promo','bx_promo_rules',NEW.code,'update',json_object('code',OLD.code,'start_date',OLD.start_date,'end_date',OLD.end_date,'min_goods',OLD.min_goods,'max_uses',OLD.max_uses),json_object('code',NEW.code,'start_date',NEW.start_date,'end_date',NEW.end_date,'min_goods',NEW.min_goods,'max_uses',NEW.max_uses));
END;

CREATE TRIGGER IF NOT EXISTS bx_audit_bx_promo_rules_delete AFTER DELETE ON bx_promo_rules BEGIN
 INSERT INTO bx_config_audit(module,entity,entity_key,action,old_json,new_json) VALUES('promo','bx_promo_rules',OLD.code,'delete',json_object('code',OLD.code,'start_date',OLD.start_date,'end_date',OLD.end_date,'min_goods',OLD.min_goods,'max_uses',OLD.max_uses),NULL);
END;

CREATE TRIGGER IF NOT EXISTS bx_audit_bx_promo_amounts_insert AFTER INSERT ON bx_promo_amounts BEGIN
 INSERT INTO bx_config_audit(module,entity,entity_key,action,old_json,new_json) VALUES('promo','bx_promo_amounts',NEW.code,'insert',NULL,json_object('code',NEW.code,'amount',NEW.amount));
END;

CREATE TRIGGER IF NOT EXISTS bx_audit_bx_promo_amounts_update AFTER UPDATE ON bx_promo_amounts WHEN OLD.code IS NOT NEW.code OR OLD.amount IS NOT NEW.amount BEGIN
 INSERT INTO bx_config_audit(module,entity,entity_key,action,old_json,new_json) VALUES('promo','bx_promo_amounts',NEW.code,'update',json_object('code',OLD.code,'amount',OLD.amount),json_object('code',NEW.code,'amount',NEW.amount));
END;

CREATE TRIGGER IF NOT EXISTS bx_audit_bx_promo_amounts_delete AFTER DELETE ON bx_promo_amounts BEGIN
 INSERT INTO bx_config_audit(module,entity,entity_key,action,old_json,new_json) VALUES('promo','bx_promo_amounts',OLD.code,'delete',json_object('code',OLD.code,'amount',OLD.amount),NULL);
END;

CREATE TRIGGER IF NOT EXISTS bx_audit_bx_promo_no_discount_insert AFTER INSERT ON bx_promo_no_discount BEGIN
 INSERT INTO bx_config_audit(module,entity,entity_key,action,old_json,new_json) VALUES('promo','bx_promo_no_discount',NEW.code,'insert',NULL,json_object('code',NEW.code));
END;

CREATE TRIGGER IF NOT EXISTS bx_audit_bx_promo_no_discount_update AFTER UPDATE ON bx_promo_no_discount WHEN OLD.code IS NOT NEW.code BEGIN
 INSERT INTO bx_config_audit(module,entity,entity_key,action,old_json,new_json) VALUES('promo','bx_promo_no_discount',NEW.code,'update',json_object('code',OLD.code),json_object('code',NEW.code));
END;

CREATE TRIGGER IF NOT EXISTS bx_audit_bx_promo_no_discount_delete AFTER DELETE ON bx_promo_no_discount BEGIN
 INSERT INTO bx_config_audit(module,entity,entity_key,action,old_json,new_json) VALUES('promo','bx_promo_no_discount',OLD.code,'delete',json_object('code',OLD.code),NULL);
END;

CREATE TRIGGER IF NOT EXISTS bx_audit_bx_promo_gifts_insert AFTER INSERT ON bx_promo_gifts BEGIN
 INSERT INTO bx_config_audit(module,entity,entity_key,action,old_json,new_json) VALUES('promo','bx_promo_gifts',NEW.code,'insert',NULL,json_object('code',NEW.code,'product_id',NEW.product_id,'qty',NEW.qty,'description',NEW.description));
END;

CREATE TRIGGER IF NOT EXISTS bx_audit_bx_promo_gifts_update AFTER UPDATE ON bx_promo_gifts WHEN OLD.code IS NOT NEW.code OR OLD.product_id IS NOT NEW.product_id OR OLD.qty IS NOT NEW.qty OR OLD.description IS NOT NEW.description BEGIN
 INSERT INTO bx_config_audit(module,entity,entity_key,action,old_json,new_json) VALUES('promo','bx_promo_gifts',NEW.code,'update',json_object('code',OLD.code,'product_id',OLD.product_id,'qty',OLD.qty,'description',OLD.description),json_object('code',NEW.code,'product_id',NEW.product_id,'qty',NEW.qty,'description',NEW.description));
END;

CREATE TRIGGER IF NOT EXISTS bx_audit_bx_promo_gifts_delete AFTER DELETE ON bx_promo_gifts BEGIN
 INSERT INTO bx_config_audit(module,entity,entity_key,action,old_json,new_json) VALUES('promo','bx_promo_gifts',OLD.code,'delete',json_object('code',OLD.code,'product_id',OLD.product_id,'qty',OLD.qty,'description',OLD.description),NULL);
END;

CREATE TRIGGER IF NOT EXISTS bx_audit_bx_promo_shipping_insert AFTER INSERT ON bx_promo_shipping BEGIN
 INSERT INTO bx_config_audit(module,entity,entity_key,action,old_json,new_json) VALUES('promo','bx_promo_shipping',NEW.code,'insert',NULL,json_object('code',NEW.code,'methods',NEW.methods));
END;

CREATE TRIGGER IF NOT EXISTS bx_audit_bx_promo_shipping_update AFTER UPDATE ON bx_promo_shipping WHEN OLD.code IS NOT NEW.code OR OLD.methods IS NOT NEW.methods BEGIN
 INSERT INTO bx_config_audit(module,entity,entity_key,action,old_json,new_json) VALUES('promo','bx_promo_shipping',NEW.code,'update',json_object('code',OLD.code,'methods',OLD.methods),json_object('code',NEW.code,'methods',NEW.methods));
END;

CREATE TRIGGER IF NOT EXISTS bx_audit_bx_promo_shipping_delete AFTER DELETE ON bx_promo_shipping BEGIN
 INSERT INTO bx_config_audit(module,entity,entity_key,action,old_json,new_json) VALUES('promo','bx_promo_shipping',OLD.code,'delete',json_object('code',OLD.code,'methods',OLD.methods),NULL);
END;

CREATE TRIGGER IF NOT EXISTS bx_audit_bx_promo_levels_insert AFTER INSERT ON bx_promo_levels BEGIN
 INSERT INTO bx_config_audit(module,entity,entity_key,action,old_json,new_json) VALUES('promo','bx_promo_levels',NEW.code||':'||NEW.level,'insert',NULL,json_object('code',NEW.code,'level',NEW.level));
END;

CREATE TRIGGER IF NOT EXISTS bx_audit_bx_promo_levels_update AFTER UPDATE ON bx_promo_levels WHEN OLD.code IS NOT NEW.code OR OLD.level IS NOT NEW.level BEGIN
 INSERT INTO bx_config_audit(module,entity,entity_key,action,old_json,new_json) VALUES('promo','bx_promo_levels',NEW.code||':'||NEW.level,'update',json_object('code',OLD.code,'level',OLD.level),json_object('code',NEW.code,'level',NEW.level));
END;

CREATE TRIGGER IF NOT EXISTS bx_audit_bx_promo_levels_delete AFTER DELETE ON bx_promo_levels BEGIN
 INSERT INTO bx_config_audit(module,entity,entity_key,action,old_json,new_json) VALUES('promo','bx_promo_levels',OLD.code||':'||OLD.level,'delete',json_object('code',OLD.code,'level',OLD.level),NULL);
END;

CREATE TRIGGER IF NOT EXISTS bx_audit_bx_club_sale_prices_insert AFTER INSERT ON bx_club_sale_prices BEGIN
 INSERT INTO bx_config_audit(module,entity,entity_key,action,old_json,new_json) VALUES('sale','bx_club_sale_prices',NEW.product_id||':'||NEW.level,'insert',NULL,json_object('product_id',NEW.product_id,'level',NEW.level,'sale_price',NEW.sale_price,'start_date',NEW.start_date,'end_date',NEW.end_date,'active',NEW.active));
END;

CREATE TRIGGER IF NOT EXISTS bx_audit_bx_club_sale_prices_update AFTER UPDATE ON bx_club_sale_prices WHEN OLD.product_id IS NOT NEW.product_id OR OLD.level IS NOT NEW.level OR OLD.sale_price IS NOT NEW.sale_price OR OLD.start_date IS NOT NEW.start_date OR OLD.end_date IS NOT NEW.end_date OR OLD.active IS NOT NEW.active BEGIN
 INSERT INTO bx_config_audit(module,entity,entity_key,action,old_json,new_json) VALUES('sale','bx_club_sale_prices',NEW.product_id||':'||NEW.level,'update',json_object('product_id',OLD.product_id,'level',OLD.level,'sale_price',OLD.sale_price,'start_date',OLD.start_date,'end_date',OLD.end_date,'active',OLD.active),json_object('product_id',NEW.product_id,'level',NEW.level,'sale_price',NEW.sale_price,'start_date',NEW.start_date,'end_date',NEW.end_date,'active',NEW.active));
END;

CREATE TRIGGER IF NOT EXISTS bx_audit_bx_club_sale_prices_delete AFTER DELETE ON bx_club_sale_prices BEGIN
 INSERT INTO bx_config_audit(module,entity,entity_key,action,old_json,new_json) VALUES('sale','bx_club_sale_prices',OLD.product_id||':'||OLD.level,'delete',json_object('product_id',OLD.product_id,'level',OLD.level,'sale_price',OLD.sale_price,'start_date',OLD.start_date,'end_date',OLD.end_date,'active',OLD.active),NULL);
END;

CREATE TRIGGER IF NOT EXISTS bx_audit_bx_club_levels_insert AFTER INSERT ON bx_club_levels BEGIN
 INSERT INTO bx_config_audit(module,entity,entity_key,action,old_json,new_json) VALUES('club','bx_club_levels',NEW.id,'insert',NULL,json_object('id',NEW.id,'title',NEW.title,'threshold',NEW.threshold,'cashback',NEW.cashback));
END;

CREATE TRIGGER IF NOT EXISTS bx_audit_bx_club_levels_update AFTER UPDATE ON bx_club_levels WHEN OLD.id IS NOT NEW.id OR OLD.title IS NOT NEW.title OR OLD.threshold IS NOT NEW.threshold OR OLD.cashback IS NOT NEW.cashback BEGIN
 INSERT INTO bx_config_audit(module,entity,entity_key,action,old_json,new_json) VALUES('club','bx_club_levels',NEW.id,'update',json_object('id',OLD.id,'title',OLD.title,'threshold',OLD.threshold,'cashback',OLD.cashback),json_object('id',NEW.id,'title',NEW.title,'threshold',NEW.threshold,'cashback',NEW.cashback));
END;

CREATE TRIGGER IF NOT EXISTS bx_audit_bx_club_levels_delete AFTER DELETE ON bx_club_levels BEGIN
 INSERT INTO bx_config_audit(module,entity,entity_key,action,old_json,new_json) VALUES('club','bx_club_levels',OLD.id,'delete',json_object('id',OLD.id,'title',OLD.title,'threshold',OLD.threshold,'cashback',OLD.cashback),NULL);
END;

CREATE TRIGGER IF NOT EXISTS bx_audit_bx_club_settings_insert AFTER INSERT ON bx_club_settings BEGIN
 INSERT INTO bx_config_audit(module,entity,entity_key,action,old_json,new_json) VALUES('club','bx_club_settings',NEW.id,'insert',NULL,json_object('id',NEW.id,'redeem_percent',NEW.redeem_percent));
END;

CREATE TRIGGER IF NOT EXISTS bx_audit_bx_club_settings_update AFTER UPDATE ON bx_club_settings WHEN OLD.id IS NOT NEW.id OR OLD.redeem_percent IS NOT NEW.redeem_percent BEGIN
 INSERT INTO bx_config_audit(module,entity,entity_key,action,old_json,new_json) VALUES('club','bx_club_settings',NEW.id,'update',json_object('id',OLD.id,'redeem_percent',OLD.redeem_percent),json_object('id',NEW.id,'redeem_percent',NEW.redeem_percent));
END;

CREATE TRIGGER IF NOT EXISTS bx_audit_bx_club_settings_delete AFTER DELETE ON bx_club_settings BEGIN
 INSERT INTO bx_config_audit(module,entity,entity_key,action,old_json,new_json) VALUES('club','bx_club_settings',OLD.id,'delete',json_object('id',OLD.id,'redeem_percent',OLD.redeem_percent),NULL);
END;

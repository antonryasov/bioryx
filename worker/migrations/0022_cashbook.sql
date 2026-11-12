-- BIORYX после 0021: ручной журнал денежных операций, не банковская интеграция.
CREATE TABLE IF NOT EXISTS bx_cashbook (
 id TEXT PRIMARY KEY,
 event_date TEXT NOT NULL,
 kind TEXT NOT NULL CHECK(kind IN ('sale_receipt','customer_refund','supplier_payment','delivery_cost','fees','taxes','marketing','rent','payroll','other_expense','other_receipt','owner_in','owner_out')),
 amount INTEGER NOT NULL CHECK(amount BETWEEN 1 AND 100000000),
 description TEXT NOT NULL DEFAULT '',order_id TEXT REFERENCES orders(id),
 voided INTEGER NOT NULL DEFAULT 0 CHECK(voided IN (0,1)),
 version TEXT NOT NULL,created_at TEXT NOT NULL DEFAULT(datetime('now')),updated_at TEXT NOT NULL DEFAULT(datetime('now'))
);
CREATE INDEX IF NOT EXISTS bx_cashbook_date ON bx_cashbook(event_date,id);
CREATE TRIGGER IF NOT EXISTS bx_cashbook_audit_insert AFTER INSERT ON bx_cashbook BEGIN
 INSERT INTO bx_config_audit(module,entity,entity_key,action,old_json,new_json) VALUES('finance','bx_cashbook',NEW.id,'insert',NULL,json_object('event_date',NEW.event_date,'kind',NEW.kind,'amount',NEW.amount,'description',NEW.description,'order_id',NEW.order_id,'voided',NEW.voided));
END;
CREATE TRIGGER IF NOT EXISTS bx_cashbook_audit_update AFTER UPDATE ON bx_cashbook
WHEN OLD.event_date IS NOT NEW.event_date OR OLD.kind IS NOT NEW.kind OR OLD.amount IS NOT NEW.amount OR OLD.description IS NOT NEW.description OR OLD.order_id IS NOT NEW.order_id OR OLD.voided IS NOT NEW.voided BEGIN
 INSERT INTO bx_config_audit(module,entity,entity_key,action,old_json,new_json) VALUES('finance','bx_cashbook',NEW.id,'update',json_object('event_date',OLD.event_date,'kind',OLD.kind,'amount',OLD.amount,'description',OLD.description,'order_id',OLD.order_id,'voided',OLD.voided),json_object('event_date',NEW.event_date,'kind',NEW.kind,'amount',NEW.amount,'description',NEW.description,'order_id',NEW.order_id,'voided',NEW.voided));
END;

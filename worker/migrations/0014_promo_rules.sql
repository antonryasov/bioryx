-- BIORYX: после 0013. Существующие промокоды без записи в bx_promo_rules работают без ограничений.
-- Даты — календарные даты UTC включительно. Применение считается навсегда, даже при отмене.
CREATE TABLE IF NOT EXISTS bx_promo_rules (
 code TEXT PRIMARY KEY REFERENCES bx_promos(code),
 start_date TEXT NOT NULL DEFAULT '',
 end_date TEXT NOT NULL DEFAULT '',
 min_goods INTEGER NOT NULL DEFAULT 0 CHECK(min_goods>=0),
 max_uses INTEGER NOT NULL DEFAULT 0 CHECK(max_uses>=0),
 updated_at TEXT NOT NULL DEFAULT(datetime('now'))
);
CREATE INDEX IF NOT EXISTS bx_finance_promo_code ON bx_order_finance(promo_code);
CREATE TRIGGER IF NOT EXISTS bx_promo_conditions_guard BEFORE INSERT ON bx_order_finance
WHEN NEW.promo_code!='' BEGIN
 SELECT CASE WHEN EXISTS (SELECT 1 FROM bx_promo_rules r WHERE r.code=NEW.promo_code AND (
  (r.start_date!='' AND date('now')<r.start_date) OR
  (r.end_date!='' AND date('now')>r.end_date) OR
  NEW.gross<r.min_goods OR
  (r.max_uses>0 AND (SELECT count(*) FROM bx_order_finance f WHERE f.promo_code=NEW.promo_code)>=r.max_uses)
 )) THEN RAISE(ABORT,'promo_conditions_failed') END;
END;

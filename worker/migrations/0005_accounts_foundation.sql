-- Основа BIORYX Club. Отдельные таблицы с префиксом bx_. Не активирует ни вход, ни баллы.
-- Запускать только в отдельной тестовой BIORYX D1 после резервного копирования.
CREATE TABLE IF NOT EXISTS bx_customers (
  id TEXT PRIMARY KEY,
  telegram_id TEXT NOT NULL UNIQUE,
  telegram_username TEXT NOT NULL DEFAULT '',
  display_name TEXT NOT NULL DEFAULT '',
  phone TEXT NOT NULL DEFAULT '',
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE TABLE IF NOT EXISTS bx_sessions (
  token_hash TEXT PRIMARY KEY,
  customer_id TEXT NOT NULL REFERENCES bx_customers(id),
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  expires_at TEXT NOT NULL,
  revoked_at TEXT
);
CREATE INDEX IF NOT EXISTS bx_sessions_customer ON bx_sessions(customer_id);
CREATE TABLE IF NOT EXISTS bx_login_challenges (
  code_hash TEXT PRIMARY KEY,
  customer_id TEXT NOT NULL REFERENCES bx_customers(id),
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  expires_at TEXT NOT NULL,
  consumed_at TEXT,
  attempts INTEGER NOT NULL DEFAULT 0 CHECK (attempts >= 0)
);
CREATE TABLE IF NOT EXISTS bx_order_owners (
  order_id TEXT PRIMARY KEY REFERENCES orders(id),
  customer_id TEXT NOT NULL REFERENCES bx_customers(id),
  linked_at TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE INDEX IF NOT EXISTS bx_owner_orders ON bx_order_owners(customer_id, linked_at DESC);
CREATE TABLE IF NOT EXISTS bx_loyalty_ledger (
  id TEXT PRIMARY KEY,
  customer_id TEXT NOT NULL REFERENCES bx_customers(id),
  order_id TEXT REFERENCES orders(id),
  kind TEXT NOT NULL CHECK(kind IN ('welcome','earn','redeem','restore','reversal','adjustment')),
  points INTEGER NOT NULL CHECK(points != 0),
  operation_key TEXT NOT NULL UNIQUE,
  note TEXT NOT NULL DEFAULT '',
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE INDEX IF NOT EXISTS bx_ledger_customer ON bx_loyalty_ledger(customer_id, created_at DESC);
CREATE TABLE IF NOT EXISTS bx_customer_messages (
  id TEXT PRIMARY KEY,
  order_id TEXT NOT NULL REFERENCES orders(id),
  customer_id TEXT NOT NULL REFERENCES bx_customers(id),
  direction TEXT NOT NULL CHECK(direction IN ('customer','seller')),
  body TEXT NOT NULL,
  telegram_update_id TEXT UNIQUE,
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE INDEX IF NOT EXISTS bx_messages_order ON bx_customer_messages(order_id,created_at);
CREATE TABLE IF NOT EXISTS bx_news_consent (
  customer_id TEXT PRIMARY KEY REFERENCES bx_customers(id),
  subscribed INTEGER NOT NULL DEFAULT 0 CHECK(subscribed IN (0,1)),
  updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE TABLE IF NOT EXISTS bx_admin_audit (
  id TEXT PRIMARY KEY,
  actor TEXT NOT NULL,
  action TEXT NOT NULL,
  order_id TEXT REFERENCES orders(id),
  details TEXT NOT NULL DEFAULT '',
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE INDEX IF NOT EXISTS bx_audit_order ON bx_admin_audit(order_id,created_at);

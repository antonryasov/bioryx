CREATE TABLE IF NOT EXISTS bx_bot_context (
 customer_id TEXT PRIMARY KEY REFERENCES bx_customers(id),
 order_id TEXT NOT NULL REFERENCES orders(id),
 updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);

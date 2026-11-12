CREATE TABLE IF NOT EXISTS bx_news_jobs (
 id TEXT PRIMARY KEY,
 body TEXT NOT NULL,
 created_at TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE TABLE IF NOT EXISTS bx_news_queue (
 id INTEGER PRIMARY KEY AUTOINCREMENT,
 job_id TEXT NOT NULL REFERENCES bx_news_jobs(id),
 customer_id TEXT NOT NULL REFERENCES bx_customers(id),
 state TEXT NOT NULL DEFAULT 'pending' CHECK(state IN ('pending','sending','sent','failed','skipped')),
 attempts INTEGER NOT NULL DEFAULT 0,
 updated_at TEXT NOT NULL DEFAULT (datetime('now')),
 UNIQUE(job_id,customer_id)
);
CREATE INDEX IF NOT EXISTS bx_news_queue_state ON bx_news_queue(state,id);

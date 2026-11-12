-- BIORYX: ограничение попыток ввода одноразового кода. Никакие существующие данные не удаляются.
CREATE TABLE IF NOT EXISTS bx_login_code_attempts (
 id TEXT PRIMARY KEY,
 ip_hash TEXT NOT NULL,
 created_at TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE INDEX IF NOT EXISTS bx_login_code_attempts_ip_time ON bx_login_code_attempts(ip_hash,created_at);
CREATE TRIGGER IF NOT EXISTS bx_login_code_rate_guard BEFORE INSERT ON bx_login_code_attempts
WHEN (SELECT COUNT(*) FROM bx_login_code_attempts WHERE ip_hash=NEW.ip_hash AND created_at>datetime('now','-15 minutes'))>=15
BEGIN SELECT RAISE(ABORT,'login_rate_limited'); END;

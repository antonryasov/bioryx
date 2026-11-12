"""Локальные SQLite-проверки миграций и финансовых инвариантов (не проверка Cloudflare/Telegram)."""
import sqlite3
from pathlib import Path
root = Path(__file__).resolve().parents[1]
c = sqlite3.connect(':memory:')
c.execute('PRAGMA foreign_keys = ON')
for f in sorted((root / 'worker/migrations').glob('*.sql')):
    c.executescript(f.read_text())
c.executescript((root / 'worker/migrations/0010_admin_controls_notifications.sql').read_text())
c.execute("INSERT INTO bx_customers(id,telegram_id) VALUES('a','1')")
assert c.execute('SELECT count(*) FROM bx_notifications').fetchone()[0] == 1
c.execute("INSERT INTO bx_customer_levels(customer_id,level) VALUES('a','peak')")
c.execute("INSERT INTO orders(id,customer_name,phone,city,delivery,payment,consent,total) VALUES('o','A','7','Грозный','pickup','cash',1,1000)")
c.execute("INSERT INTO bx_order_owners(order_id,customer_id) VALUES('o','a')")
c.execute("INSERT INTO bx_order_finance(order_id,customer_id,gross) VALUES('o','a',1000)")
c.execute("UPDATE orders SET payment_status='paid' WHERE id='o'")
c.execute("INSERT INTO bx_notification_flags VALUES('order:o',0)")
c.execute("UPDATE orders SET status='delivered' WHERE id='o'")
c.execute("DELETE FROM bx_notification_flags WHERE entity_key='order:o'")
assert c.execute("SELECT points FROM bx_loyalty_ledger WHERE kind='earn'").fetchone()[0] == 500
assert c.execute('SELECT count(*) FROM bx_notifications').fetchone()[0] == 1
c.execute("UPDATE orders SET status='delivered' WHERE id='o'")
assert c.execute("SELECT count(*) FROM bx_loyalty_ledger WHERE kind='earn'").fetchone()[0] == 1
try:
    c.execute("UPDATE orders SET status='new' WHERE id='o'")
    raise AssertionError('Delivered order was reopened')
except sqlite3.IntegrityError:
    pass
c.execute("INSERT INTO bx_customers(id,telegram_id) VALUES('b','2')")
c.execute("INSERT INTO orders(id,customer_name,phone,city,delivery,payment,consent,total) VALUES('q','A','7','Грозный','pickup','cash',1,15000)")
c.execute("INSERT INTO bx_order_owners(order_id,customer_id) VALUES('q','b')")
c.execute("INSERT INTO bx_order_finance(order_id,customer_id,gross) VALUES('q','b',15000)")
c.execute("UPDATE orders SET payment_status='paid' WHERE id='q'")
c.execute("INSERT INTO bx_notification_flags VALUES('order:q',1)")
c.execute("UPDATE orders SET status='delivered' WHERE id='q'")
c.execute("INSERT INTO bx_notifications(id,customer_id,body) SELECT 'status:q',customer_id,'status' FROM bx_order_owners WHERE order_id='q' AND changes()=1")
assert c.execute("SELECT count(*) FROM bx_notifications WHERE id='status:q'").fetchone()[0] == 1
assert c.execute("SELECT count(*) FROM bx_notifications WHERE id='level:auto:q'").fetchone()[0] == 1
assert c.execute("SELECT points FROM bx_loyalty_ledger WHERE order_id='q' AND kind='earn'").fetchone()[0] == 750
print('PASS: повтор миграции, ручной уровень и кэшбэк, запрет дублей, уведомления, автоматическое повышение')

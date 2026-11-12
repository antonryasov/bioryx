"""Проверка правил клуба на SQLite: не заменяет тест Cloudflare D1."""
import sqlite3
from pathlib import Path
r=Path(__file__).resolve().parents[1]; c=sqlite3.connect(':memory:');c.execute('PRAGMA foreign_keys=ON')
for f in sorted((r/'worker/migrations').glob('*.sql')):c.executescript(f.read_text())
c.executescript((r/'worker/migrations/0013_club_settings.sql').read_text())
c.execute("UPDATE bx_club_levels SET title='КЛУБ',cashback=17 WHERE id='start'")
c.execute("UPDATE bx_club_levels SET threshold=500,cashback=20,title='ВТОРОЙ' WHERE id='progress'")
c.execute("UPDATE bx_club_settings SET redeem_percent=10 WHERE id=1")
c.execute("INSERT INTO bx_customers(id,telegram_id) VALUES('c','1')")
c.execute("INSERT INTO orders(id,customer_name,phone,city,delivery,payment,consent,total) VALUES('o','A','7','Грозный','pickup','cash',1,1000)")
c.execute("INSERT INTO bx_order_owners(order_id,customer_id) VALUES('o','c')")
try:
 c.execute("INSERT INTO bx_order_finance(order_id,customer_id,gross,points_used) VALUES('o','c',1000,101)")
 raise AssertionError('лимит списания не проверен')
except sqlite3.IntegrityError as e: assert 'club_redeem_limit' in str(e)
c.execute("INSERT INTO bx_order_finance(order_id,customer_id,gross,points_used) VALUES('o','c',1000,100)")
c.execute("UPDATE orders SET status='delivered',payment_status='paid' WHERE id='o'")
get=lambda q:c.execute(q).fetchone()[0]
assert get("SELECT points FROM bx_loyalty_ledger WHERE order_id='o' AND kind='earn'")==153
assert 'ВТОРОЙ' in get("SELECT body FROM bx_notifications WHERE customer_id='c' AND id LIKE 'auto-level:%' LIMIT 1")
c.execute("UPDATE orders SET payment_status='unpaid' WHERE id='o'")
assert get("SELECT sum(points) FROM bx_loyalty_ledger WHERE order_id='o' AND kind IN ('earn','reversal')")==0
c.execute("UPDATE orders SET payment_status='paid' WHERE id='o'")
assert get("SELECT sum(points) FROM bx_loyalty_ledger WHERE order_id='o' AND kind IN ('earn','reversal')")==153
c.execute("INSERT INTO bx_customer_levels(customer_id,level) VALUES('c','peak')")
c.execute("UPDATE bx_club_levels SET cashback=30 WHERE id='peak'")
c.execute("UPDATE orders SET status='new' WHERE id='o'");c.execute("UPDATE orders SET status='delivered' WHERE id='o'")
assert get("SELECT sum(points) FROM bx_loyalty_ledger WHERE order_id='o' AND kind IN ('earn','reversal')")==270
c.execute("INSERT INTO bx_club_settings_audit(snapshot) SELECT json_object('levels',json((SELECT json_group_array(json_object('id',id,'title',title,'threshold',threshold,'cashback',cashback)) FROM bx_club_levels)),'redeemPercent',(SELECT redeem_percent FROM bx_club_settings WHERE id=1))")
assert get("SELECT json_extract(snapshot,'$.redeemPercent') FROM bx_club_settings_audit")==10
print('PASS: повтор миграции, лимит, автоуровень, кэшбэк, ручной уровень, сторно и аудит')

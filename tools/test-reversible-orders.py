"""Локальный тест: не заменяет проверку настоящего D1 и Telegram."""
import sqlite3
from pathlib import Path
r=Path(__file__).resolve().parents[1]
c=sqlite3.connect(':memory:');c.execute('PRAGMA foreign_keys=ON')
for f in sorted((r/'worker/migrations').glob('*.sql')):c.executescript(f.read_text())
c.executescript((r/'worker/migrations/0011_reversible_orders.sql').read_text())
c.execute("INSERT INTO bx_customers(id,telegram_id) VALUES('c','1')")
c.execute("INSERT INTO orders(id,customer_name,phone,city,delivery,payment,consent,total) VALUES('o','A','7','Грозный','pickup','cash',1,1990)")
c.execute("INSERT INTO bx_order_owners(order_id,customer_id) VALUES('o','c')")
c.execute("INSERT INTO order_items(order_id,product_id,name,price,qty) SELECT 'o',id,name,price,1 FROM products WHERE id='demo-creatine'")
c.execute("INSERT INTO bx_order_finance(order_id,customer_id,gross,points_used) VALUES('o','c',1990,200)")
val=lambda q:c.execute(q).fetchone()[0]
balance=lambda:val("SELECT SUM(points) FROM bx_loyalty_ledger WHERE customer_id='c'")
stock=lambda:val("SELECT stock FROM products WHERE id='demo-creatine'")
assert balance()==300 and stock()==14
c.execute("UPDATE orders SET status='delivered' WHERE id='o'");assert balance()==300
c.execute("UPDATE orders SET payment_status='paid' WHERE id='o'");assert balance()==389
c.execute("UPDATE orders SET payment_status='unpaid' WHERE id='o'");assert balance()==300
c.execute("UPDATE orders SET payment_status='paid' WHERE id='o'");assert balance()==389
c.execute("UPDATE orders SET status='cancelled' WHERE id='o'");assert balance()==500 and stock()==15
c.execute("UPDATE orders SET status='cancelled' WHERE id='o'");assert balance()==500 and stock()==15
c.execute("UPDATE orders SET status='new' WHERE id='o'");assert balance()==300 and stock()==14
c.execute("UPDATE orders SET status='delivered' WHERE id='o'");assert balance()==389
c.execute("UPDATE orders SET status='cancelled' WHERE id='o'");c.execute("UPDATE products SET stock=0 WHERE id='demo-creatine'")
try:c.execute("UPDATE orders SET status='new' WHERE id='o'");raise AssertionError('insufficient stock accepted')
except sqlite3.IntegrityError as e:assert 'insufficient_stock' in str(e)
c.execute("INSERT INTO bx_customers(id,telegram_id) VALUES('b','2')")
c.execute("INSERT INTO orders(id,customer_name,phone,city,delivery,payment,consent,total) VALUES('q','B','7','Грозный','pickup','cash',1,15000)")
c.execute("INSERT INTO bx_order_owners(order_id,customer_id) VALUES('q','b')")
c.execute("INSERT INTO bx_order_finance(order_id,customer_id,gross) VALUES('q','b',15000)")
c.execute("UPDATE orders SET payment_status='paid',status='delivered' WHERE id='q'")
assert val("SELECT count(*) FROM bx_notifications WHERE customer_id='b' AND id LIKE 'auto-level:%'")==1
c.execute("UPDATE orders SET status='new' WHERE id='q'")
assert val("SELECT count(*) FROM bx_notifications WHERE customer_id='b' AND id LIKE 'auto-level:%'")==2
print('PASS: повтор миграции, переключение оплаты и статусов, кэшбэк, возврат и резерв баллов/товаров, повышение/понижение уровня')

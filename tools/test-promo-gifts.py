"""Локальные SQLite-проверки подарков и откатов; не заменяют тесты D1."""
from pathlib import Path
import sqlite3
r=Path(__file__).resolve().parents[1];c=sqlite3.connect(':memory:');c.execute('PRAGMA foreign_keys=ON')
for f in sorted((r/'worker/migrations').glob('*.sql')):c.executescript(f.read_text())
c.executescript((r/'worker/migrations/0016_promo_gifts.sql').read_text())
c.execute("INSERT INTO bx_promos(code,title,percent) VALUES('GIFT','Подарок',1)")
c.execute("INSERT INTO bx_promo_no_discount(code) VALUES('GIFT')")
c.execute("INSERT INTO bx_promo_gifts(code,product_id,qty,description) VALUES('GIFT','demo-creatine',2,'Открытка')")
stock=lambda:c.execute("SELECT stock FROM products WHERE id='demo-creatine'").fetchone()[0]
c.execute("UPDATE products SET stock=5 WHERE id='demo-creatine'")
c.execute("INSERT INTO orders(id,customer_name,phone,city,delivery,payment,consent,total) VALUES('o','A','7','Грозный','pickup','cash',1,1990)")
c.execute("INSERT INTO order_items(order_id,product_id,name,price,qty) SELECT 'o',id,name,price,1 FROM products WHERE id='demo-creatine'")
try:c.execute("INSERT INTO bx_order_finance(order_id,gross,promo_code,promo_percent,discount) VALUES('o',1990,'GIFT',0,0)");raise AssertionError('нет проверки согласованных условий')
except sqlite3.IntegrityError as e:assert 'promo_gift_changed' in str(e)
c.execute("INSERT INTO bx_promo_expectations VALUES('o','GIFT','demo-creatine',2,'Открытка',1)")
c.execute("INSERT INTO bx_order_finance(order_id,gross,promo_code,promo_percent,discount) VALUES('o',1990,'GIFT',0,0)")
assert stock()==2,stock()
assert c.execute("SELECT product_id,qty,description FROM bx_order_gifts WHERE order_id='o'").fetchone()==('demo-creatine',2,'Открытка')
c.execute("UPDATE bx_promo_gifts SET description='Новая' WHERE code='GIFT'")
assert c.execute("SELECT description FROM bx_order_gifts WHERE order_id='o'").fetchone()[0]=='Открытка'
c.execute("UPDATE orders SET status='cancelled' WHERE id='o'");assert stock()==5
c.execute("UPDATE products SET stock=2 WHERE id='demo-creatine'")
try:c.execute("UPDATE orders SET status='new' WHERE id='o'");raise AssertionError('не проверен общий остаток подарка и товара')
except sqlite3.IntegrityError as e:assert 'insufficient_stock_to_reopen' in str(e)
assert stock()==2 and c.execute("select status from orders where id='o'").fetchone()[0]=='cancelled'
c.execute("UPDATE products SET stock=3 WHERE id='demo-creatine'");c.execute("UPDATE orders SET status='new' WHERE id='o'");assert stock()==0
c.execute("UPDATE orders SET status='cancelled' WHERE id='o'");assert stock()==3
# Failure of gift reservation rolls back order, purchased item, finance and inventory together.
c.execute("UPDATE bx_promo_gifts SET qty=3 WHERE code='GIFT'");c.commit()
try:
 c.execute('BEGIN');c.execute("INSERT INTO orders(id,customer_name,phone,city,delivery,payment,consent,total) VALUES('bad','A','7','Грозный','pickup','cash',1,1990)")
 c.execute("INSERT INTO order_items(order_id,product_id,name,price,qty) SELECT 'bad',id,name,price,1 FROM products WHERE id='demo-creatine'")
 c.execute("INSERT INTO bx_promo_expectations VALUES('bad','GIFT','demo-creatine',3,'Новая',1)")
 c.execute("INSERT INTO bx_order_finance(order_id,gross,promo_code,promo_percent,discount) VALUES('bad',1990,'GIFT',0,0)")
 raise AssertionError('недостаток подарочного товара не обнаружен')
except sqlite3.IntegrityError as e:
 assert 'gift_unavailable' in str(e);c.rollback()
assert stock()==3 and c.execute("SELECT count(*) FROM orders WHERE id='bad'").fetchone()[0]==0
print('PASS: подарок, сохранение снимка, резерв, отмена, общий остаток при возобновлении, откат')

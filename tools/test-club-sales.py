"""SQLite-проверка закрытых цен, не заменяет живую D1."""
from pathlib import Path
import sqlite3
r=Path(__file__).resolve().parents[1];c=sqlite3.connect(':memory:');c.execute('pragma foreign_keys=ON')
for f in sorted((r/'worker/migrations').glob('*.sql')):c.executescript(f.read_text())
c.executescript((r/'worker/migrations/0019_club_sale_prices.sql').read_text())
c.execute("INSERT INTO bx_customers(id,telegram_id) VALUES('c','1'),('d','2')")
c.execute("INSERT INTO bx_customer_levels(customer_id,level) VALUES('c','progress')")
c.execute("INSERT INTO bx_club_sale_prices(product_id,level,sale_price) VALUES('demo-creatine','progress',990)")
c.execute("INSERT INTO bx_promos(code,title,percent) VALUES('SALE','акция',10)")
def order(id,cid='c'):
 c.execute("INSERT INTO orders(id,customer_name,phone,city,delivery,payment,consent,total) VALUES(?,'A','7','Грозный','pickup','cash',1,1990)",(id,))
 if cid:c.execute("INSERT INTO bx_order_owners(order_id,customer_id) VALUES(?,?)",(id,cid))
 c.execute("INSERT INTO order_items(order_id,product_id,name,price,qty) SELECT ?,id,name,price,1 FROM products WHERE id='demo-creatine'",(id,))
def line(id,level='progress',price=990):c.execute("INSERT INTO bx_order_sale_lines VALUES(?,'demo-creatine',?,1990,?,1)",(id,level,price))
def finance(id,cid='c',discount=99,points=100,code='SALE',percent=10):c.execute("INSERT INTO bx_order_finance(order_id,customer_id,gross,promo_code,promo_percent,discount,points_used) VALUES(?,?,1990,?,?,?,?)",(id,cid,code,percent,discount,points))
def fail(fn,term):
 try:fn()
 except sqlite3.IntegrityError as e:assert term in str(e),(str(e),term);return
 raise AssertionError('Ожидалась ошибка '+term)
order('one');fail(lambda:finance('one',discount=199),'club_sale_quote_missing')
line('one');fail(lambda:finance('one',discount=199),'bad_discount');finance('one')
assert c.execute("SELECT total FROM orders WHERE id='one'").fetchone()[0]==791
assert c.execute("SELECT points FROM bx_loyalty_ledger WHERE kind='redeem' AND order_id='one'").fetchone()[0]==-100
c.execute("UPDATE orders SET status='cancelled' WHERE id='one'");assert c.execute("SELECT sum(points) FROM bx_loyalty_ledger WHERE customer_id='c'").fetchone()[0]==500
order('other','d');fail(lambda:line('other'),'club_sale_changed')
order('guest',None);fail(lambda:line('guest'),'club_sale_changed')
order('mismatch');line('mismatch');fail(lambda:finance('mismatch',cid='d',points=0),'club_sale_customer_required')
order('changed');line('changed');c.execute("UPDATE bx_club_sale_prices SET sale_price=900 WHERE product_id='demo-creatine' AND level='progress'");fail(lambda:finance('changed'),'club_sale_quote_missing')
assert c.execute("SELECT sale_price FROM bx_order_sale_lines WHERE order_id='one'").fetchone()[0]==990
print('PASS: закрытая цена, проверка уровня и владельца, изменение условий, промокод после клубной скидки, баллы и история')

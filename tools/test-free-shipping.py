"""SQLite tests, not a real D1 / carrier integration test."""
from pathlib import Path
import sqlite3
r=Path(__file__).resolve().parents[1];c=sqlite3.connect(':memory:');c.execute('pragma foreign_keys=ON')
for f in sorted((r/'worker/migrations').glob('*.sql')):c.executescript(f.read_text())
c.executescript((r/'worker/migrations/0017_free_shipping.sql').read_text())
c.execute("INSERT INTO bx_promos(code,title,percent) VALUES('SHIP','Доставка',1),('BOTH','Скидка',10)")
c.execute("INSERT INTO bx_promo_no_discount(code) VALUES('SHIP')")
c.execute("INSERT INTO bx_promo_shipping(code,methods) VALUES('SHIP','cdek'),('BOTH','both')")
def order(id,delivery,code='SHIP',ship='cdek',no=1):
 c.execute("INSERT INTO orders(id,customer_name,phone,city,delivery,payment,consent,total) VALUES(?,'A','7','Грозный',?,'sbp',1,1000)",(id,delivery))
 c.execute("INSERT INTO bx_promo_expectations VALUES(?,?, '',0,'',?)",(id,code,no))
 c.execute("INSERT INTO bx_shipping_expectations VALUES(?,?,?)",(id,code,ship))
def fin(id,code='SHIP',pct=0,disc=0):c.execute("INSERT INTO bx_order_finance(order_id,gross,promo_code,promo_percent,discount) VALUES(?,1000,?,?,?)",(id,code,pct,disc))
def fail(fn,term):
 try:fn()
 except sqlite3.IntegrityError as e:assert term in str(e),(str(e),term);return
 raise AssertionError('Unexpectedly passed: '+term)
order('pickup','pickup');fail(lambda:fin('pickup'),'promo_shipping_not_applicable')
order('courier','courier');fail(lambda:fin('courier'),'promo_shipping_not_applicable')
order('cdek','cdek');fin('cdek')
assert c.execute("SELECT methods,free_shipping FROM bx_order_shipping_benefits WHERE order_id='cdek'").fetchone()==('cdek',1)
c.execute("UPDATE bx_promo_shipping SET methods='both' WHERE code='SHIP'")
assert c.execute("SELECT methods FROM bx_order_shipping_benefits WHERE order_id='cdek'").fetchone()[0]=='cdek'
order('changed','cdek',ship='cdek');fail(lambda:fin('changed'),'promo_shipping_changed')
order('mix','pickup',code='BOTH',ship='both',no=0);fin('mix',code='BOTH',pct=10,disc=100)
assert c.execute("SELECT free_shipping FROM bx_order_shipping_benefits WHERE order_id='mix'").fetchone()[0]==0
order('mix2','courier',code='BOTH',ship='both',no=0);fin('mix2',code='BOTH',pct=10,disc=100)
assert c.execute("SELECT free_shipping FROM bx_order_shipping_benefits WHERE order_id='mix2'").fetchone()[0]==1
print('PASS: условия доставки, выбор способа, снимок, неверная доставка, смена акции, сочетание со скидкой')

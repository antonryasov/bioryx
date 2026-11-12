"""SQLite-проверка фиксированных скидок; настоящий D1 и Telegram не заменяет."""
from pathlib import Path
import sqlite3
r=Path(__file__).resolve().parents[1];c=sqlite3.connect(':memory:');c.execute('PRAGMA foreign_keys=ON')
for f in sorted((r/'worker/migrations').glob('*.sql')):c.executescript(f.read_text())
c.executescript((r/'worker/migrations/0015_fixed_promos.sql').read_text())
c.execute("INSERT INTO bx_promos(code,title,percent) VALUES('FIX','fixed',1),('PCT','percentage',10)")
c.execute("INSERT INTO bx_promo_amounts(code,amount) VALUES('FIX',250)")
c.execute("INSERT INTO bx_promo_rules(code,min_goods,max_uses) VALUES('FIX',200,2)")
c.execute("INSERT INTO bx_customers(id,telegram_id) VALUES('c','1')")
def order(id,total):
 c.execute("INSERT INTO orders(id,customer_name,phone,city,delivery,payment,consent,total) VALUES(?,'A','7','Грозный','pickup','cash',1,?)",(id,total));c.execute("INSERT INTO bx_order_owners(order_id,customer_id) VALUES(?,'c')",(id,))
def ins(id,total,pct,discount,points=0,code='FIX'):
 c.execute("INSERT INTO bx_order_finance(order_id,customer_id,gross,promo_code,promo_percent,discount,points_used) VALUES(?,'c',?,?,?,?,?)",(id,total,code,pct,discount,points))
def fail(call,term):
 try:call()
 except sqlite3.IntegrityError as e:assert term in str(e);return
 raise AssertionError('неожиданно разрешено '+term)
order('a',1000);fail(lambda:ins('a',1000,0,100),'bad_discount');ins('a',1000,0,250,100)
assert c.execute("SELECT total FROM orders WHERE id='a'").fetchone()[0]==650
assert c.execute("SELECT kind,value FROM bx_promo_order_snapshots WHERE order_id='a'").fetchone()==('fixed',250)
order('b',200);ins('b',200,0,200);assert c.execute("SELECT total FROM orders WHERE id='b'").fetchone()[0]==0
order('c',1000);fail(lambda:ins('c',1000,0,250),'promo_conditions_failed')
c.execute("DELETE FROM bx_promo_amounts WHERE code='FIX'")
assert c.execute("SELECT kind,value FROM bx_promo_order_snapshots WHERE order_id='a'").fetchone()==('fixed',250)
order('d',1000);ins('d',1000,10,100,0,'PCT')
assert c.execute("SELECT kind,value FROM bx_promo_order_snapshots WHERE order_id='d'").fetchone()==('percent',10)
print('PASS: фиксированная скидка, ограничения, списание баллов, предел суммы, неизменяемый снимок и процентная скидка')

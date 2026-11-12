"""Проверки закрытых акций в SQLite; не заменяют тест настоящей D1."""
from pathlib import Path
import sqlite3,re,ast
r=Path(__file__).resolve().parents[1]; c=sqlite3.connect(':memory:');c.execute('pragma foreign_keys=ON')
for f in sorted((r/'worker/migrations').glob('*.sql')):c.executescript(f.read_text())
c.executescript((r/'worker/migrations/0018_promo_club_access.sql').read_text())
c.execute("UPDATE bx_club_levels SET threshold=1000 WHERE id='progress'")
c.execute("INSERT INTO bx_customers(id,telegram_id) VALUES('a','1'),('b','2')")
c.execute("INSERT INTO bx_promos(code,title,percent) VALUES('OPEN','Публичная',10),('SECRET','Закрытая',10)")
c.execute("INSERT INTO bx_promo_levels(code,level) VALUES('SECRET','progress')")
src=(r/'worker/src/index.js').read_text();section=src[src.index('async function visiblePromos'):src.index('const LEVEL_TITLES')]
def literal(name):return ast.literal_eval(re.search(r'const '+name+r'=("(?:[^"\\]|\\.)*"|\'(?:[^\'\\]|\\.)*\')',section).group(1))
sql=literal('sql');pub=literal('publicFilter');auth=literal('customerFilter')
def visible(cid=None):return [row[0] for row in c.execute(sql.replace('__VISIBILITY__',auth if cid else pub)+' LIMIT 50',(cid,cid) if cid else ())]
assert visible()==['OPEN'] and visible('a')==['OPEN']
def order(id,cid=None):
 c.execute("INSERT INTO orders(id,customer_name,phone,city,delivery,payment,consent,total) VALUES(?,'A','7','Грозный','pickup','cash',1,1000)",(id,))
 if cid:c.execute("INSERT INTO bx_order_owners(order_id,customer_id) VALUES(?,?)",(id,cid))
def promo(id,cid=None):c.execute("INSERT INTO bx_order_finance(order_id,customer_id,gross,promo_code,promo_percent,discount) VALUES(?,?,1000,'SECRET',10,100)",(id,cid))
def reject(id,cid):
 try:promo(id,cid)
 except sqlite3.IntegrityError as e:assert 'promo_level_not_allowed' in str(e);return
 raise AssertionError('Недопустимый доступ')
order('guest');reject('guest',None)
order('first','a');reject('first','a')
c.execute("INSERT INTO bx_customer_levels(customer_id,level) VALUES('a','progress')")
assert set(visible('a'))=={'OPEN','SECRET'}
promo('first','a');assert c.execute("SELECT level FROM bx_order_promo_access WHERE order_id='first'").fetchone()[0]=='progress'
c.execute("UPDATE bx_customer_levels SET level='peak' WHERE customer_id='a'")
assert visible('a')==['OPEN'];order('peak','a');reject('peak','a')
# Накапливаем покупки и проверяем автоматический уровень второго клиента.
order('paid','b');c.execute("INSERT INTO bx_order_finance(order_id,customer_id,gross) VALUES('paid','b',1000)")
c.execute("UPDATE orders SET status='delivered',payment_status='paid' WHERE id='paid'")
assert set(visible('b'))=={'OPEN','SECRET'};order('auto','b');promo('auto','b')
assert c.execute("SELECT level FROM bx_order_promo_access WHERE order_id='auto'").fetchone()[0]=='progress'
c.execute("UPDATE orders SET status='cancelled' WHERE id='paid'");assert visible('b')==['OPEN'];order('after','b');reject('after','b')
print('PASS: публичное и приватное отображение, гость, авто- и ручной уровень, точный уровень, снимок и понижение')

"""Local SQLite snapshots and contribution report checks, not a D1 integration test."""
from pathlib import Path
import sqlite3,json,re
r=Path(__file__).resolve().parents[1];c=sqlite3.connect(':memory:');c.execute('pragma foreign_keys=ON')
files=sorted((r/'worker/migrations').glob('*.sql'))
for f in files:
 if f.name.startswith('0021'):break
 c.executescript(f.read_text())
def order(id):
 c.execute("INSERT INTO orders(id,customer_name,phone,city,delivery,payment,consent,total) VALUES(?,'A','7','Грозный','pickup','cash',1,1990)",(id,))
 c.execute("INSERT INTO order_items(order_id,product_id,name,price,qty) SELECT ?,id,name,price,1 FROM products WHERE id='demo-creatine'",(id,))
 c.execute("INSERT INTO bx_order_finance(order_id,gross) VALUES(?,1990)",(id,))
 c.execute("UPDATE orders SET status='delivered',payment_status='paid' WHERE id=?",(id,))
order('legacy')
c.executescript((r/'worker/migrations/0021_cost_accounting.sql').read_text());c.executescript((r/'worker/migrations/0021_cost_accounting.sql').read_text())
assert c.execute("SELECT unit_cost FROM bx_order_cost_lines WHERE order_id='legacy'").fetchone()[0] is None
c.execute("INSERT INTO bx_product_costs(product_id,unit_cost) VALUES('demo-creatine',500)")
order('new');assert c.execute("SELECT unit_cost FROM bx_order_cost_lines WHERE order_id='new'").fetchone()[0]==500
c.execute("UPDATE bx_product_costs SET unit_cost=700 WHERE product_id='demo-creatine'")
assert c.execute("SELECT unit_cost FROM bx_order_cost_lines WHERE order_id='new'").fetchone()[0]==500
c.execute("INSERT INTO bx_order_gifts(order_id,product_id,product_name,qty,description) VALUES('new','demo-creatine','CREATINE / MONO',1,'Пакет')")
assert c.execute("SELECT unit_cost FROM bx_order_cost_lines WHERE order_id='new' AND kind='gift_product'").fetchone()[0]==700
assert c.execute("SELECT unit_cost FROM bx_order_cost_lines WHERE order_id='new' AND kind='gift_other'").fetchone()[0] is None
src=(r/'worker/src/index.js').read_text();sql=json.loads(re.search(r'const COST_ORDERS_QUERY=("(?:[^"\\]|\\.)*");',src).group(1))
rows={x[0]:x for x in c.execute(sql,('2000-01-01','2099-12-31')).fetchall()}
assert rows['legacy'][4]==0 and rows['new'][4]==0
c.execute("UPDATE bx_order_cost_lines SET unit_cost=0 WHERE order_id='new' AND kind='gift_other'")
rows={x[0]:x for x in c.execute(sql,('2000-01-01','2099-12-31')).fetchall()}
assert rows['new'][3:]==(1200,1),rows['new']
assert rows['legacy'][4]==0
c.execute("UPDATE bx_order_cost_lines SET unit_cost=900 WHERE order_id='legacy' AND kind='sold'")
rows={x[0]:x for x in c.execute(sql,('2000-01-01','2099-12-31')).fetchall()};assert rows['legacy'][3:]==(900,1)
assert c.execute("SELECT COUNT(*) FROM bx_config_audit WHERE module='cost' AND entity='bx_order_cost_lines'").fetchone()[0]==2
print('PASS: старые значения неизвестны, снимки текущих затрат, неизвестный подарок, ноль, расчёт покрытия и аудит правок')

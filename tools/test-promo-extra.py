"""Прицельная проверка SQL-ограничений акций; локальный SQLite не заменяет D1."""
import sqlite3
from pathlib import Path
r=Path(__file__).resolve().parents[1]; c=sqlite3.connect(':memory:');c.execute('PRAGMA foreign_keys=ON')
for f in sorted((r/'worker/migrations').glob('*.sql')): c.executescript(f.read_text())
c.executescript((r/'worker/migrations/0023_promo_extra_conditions.sql').read_text())
c.execute("INSERT INTO products(id,name,category,price,stock,active) VALUES('req','Нужный','protein',100,100,1)")
c.execute("INSERT INTO bx_customers(id,telegram_id) VALUES('c','1'),('d','2')")
c.execute("INSERT INTO bx_promos(code,title,percent) VALUES('TEST','Тест',10)")
c.execute("INSERT INTO bx_promo_extra(code,require_login,first_linked_order,max_per_customer,required_product,min_quantity) VALUES('TEST',1,1,1,'req',2)")
def order(i,customer=None,qty=0):
 c.execute("INSERT INTO orders(id,customer_name,phone,city,delivery,payment,consent,total) VALUES(?,'A','7','Грозный','pickup','cash',1,1000)",(i,))
 if customer:c.execute('INSERT INTO bx_order_owners(order_id,customer_id) VALUES(?,?)',(i,customer))
 if qty:c.execute("INSERT INTO order_items(order_id,product_id,name,price,qty) VALUES(?,'req','Нужный',100,?)",(i,qty))
def finance(i,customer=None):c.execute("INSERT INTO bx_order_finance(order_id,customer_id,gross,promo_code,promo_percent,discount) VALUES(?, ?,1000,'TEST',10,100)",(i,customer))
def blocked(i,customer,err):
 try:finance(i,customer)
 except sqlite3.IntegrityError as e:assert err in str(e),str(e);return
 raise AssertionError(err)
order('guest',qty=2);blocked('guest',None,'promo_login_required')
order('small','c',1);blocked('small','c','promo_required_product')
c.execute("DELETE FROM bx_order_owners WHERE order_id='small'")
order('ok','c',2);finance('ok','c');c.execute("UPDATE orders SET status='cancelled' WHERE id='ok'")
order('again','c',2);blocked('again','c','promo_first_linked_order_only')
c.execute("UPDATE bx_promo_extra SET first_linked_order=0 WHERE code='TEST'");blocked('again','c','promo_customer_limit')
order('other','d',2);finance('other','d')
assert c.execute("SELECT COUNT(*) FROM bx_config_audit WHERE entity='bx_promo_extra'").fetchone()[0]>=2
print('PASS: новые условия, отмена, разные покупатели, аудит и повтор миграции')

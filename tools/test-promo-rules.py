"""Проверка ограничений промо в SQLite. Не заменяет реальные D1 и Telegram."""
import sqlite3
from pathlib import Path
root=Path(__file__).resolve().parents[1]
c=sqlite3.connect(':memory:');c.execute('PRAGMA foreign_keys=ON')
for f in sorted((root/'worker/migrations').glob('*.sql')): c.executescript(f.read_text())
c.executescript((root/'worker/migrations/0014_promo_rules.sql').read_text())
c.execute("INSERT INTO bx_promos(code,title,percent) VALUES('CODE','Тест',10)")
c.execute("INSERT INTO bx_promo_rules(code,start_date,end_date,min_goods,max_uses) VALUES('CODE',date('now'),date('now'),1000,1)")
def order(id,total):
 c.execute("INSERT INTO orders(id,customer_name,phone,city,delivery,payment,consent,total) VALUES(?,'A','7','Грозный','pickup','cash',1,?)",(id,total))
def finance(id,total):
 c.execute("INSERT INTO bx_order_finance(order_id,gross,promo_code,promo_percent,discount) VALUES(?,?,'CODE',10,?)",(id,total,total//10))
def blocked(id,total):
 try: finance(id,total)
 except sqlite3.IntegrityError as e: assert 'promo_conditions_failed' in str(e);return
 raise AssertionError('недопустимый промокод применён')
order('low',999);blocked('low',999)
order('first',1000);finance('first',1000)
order('second',1000);blocked('second',1000)
c.execute("UPDATE orders SET status='cancelled' WHERE id='first'");blocked('second',1000)
c.execute("UPDATE bx_promo_rules SET max_uses=0,start_date=date('now','+1 day') WHERE code='CODE'");blocked('second',1000)
c.execute("UPDATE bx_promo_rules SET start_date='',end_date=date('now','-1 day') WHERE code='CODE'");blocked('second',1000)
c.execute("UPDATE bx_promo_rules SET start_date='',end_date='',max_uses=0 WHERE code='CODE'");finance('second',1000)
c.execute("INSERT INTO bx_promos(code,title,percent) VALUES('OLD','Старый',5)");order('legacy',1000);c.execute("INSERT INTO bx_order_finance(order_id,gross,promo_code,promo_percent,discount) VALUES('legacy',1000,'OLD',5,50)")
print('PASS: повтор миграции, минимум, UTC даты включительно, общий лимит, отмена и старый промокод')

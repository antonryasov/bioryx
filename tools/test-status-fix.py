"""Проверка SQLite-триггеров; не заменяет проверку в настоящем Cloudflare D1."""
from pathlib import Path
import sqlite3
c=sqlite3.connect(':memory:');c.execute('pragma foreign_keys=ON')
root=Path(__file__).resolve().parents[1]
for f in sorted((root/'worker/migrations').glob('*.sql')):c.executescript(f.read_text())
c.executescript((root/'worker/migrations/0012_atomic_notifications.sql').read_text())
c.execute("insert into bx_customers(id,telegram_id) values('c','1')")
c.execute("insert into orders(id,customer_name,phone,city,delivery,payment,consent,total) values('o','A','7','Грозный','pickup','cash',1,1000)")
c.execute("insert into bx_order_owners(order_id,customer_id) values('o','c')")
c.execute("insert into bx_order_finance(order_id,customer_id,gross) values('o','c',1000)")
c.execute("insert into bx_notification_flags values('order:o',1)")
c.execute("insert into bx_admin_event_context values('order:o','op1','status','new status',1)")
before=c.total_changes
c.execute("update orders set status='confirmed' where id='o' and status='new' and payment_status='unpaid'")
assert c.total_changes-before>=3
assert c.execute("select count(*) from bx_notifications where id='status:op1'").fetchone()[0]==1
c.execute("delete from bx_admin_event_context where entity_key='order:o'")
c.execute("delete from bx_notification_flags where entity_key='order:o'")
c.execute("insert into bx_admin_event_context values('customer:c','op2','level','level change',1)")
c.execute("insert into bx_customer_levels(customer_id,level) values('c','peak')")
assert c.execute("select count(*) from bx_notifications where id='level:op2'").fetchone()[0]==1
assert c.execute("select count(*) from bx_level_audit where customer_id='c'").fetchone()[0]==1
c.execute("delete from bx_admin_event_context where entity_key='customer:c'")
c.execute("insert into bx_admin_event_context values('customer:c','op3','points','points',0)")
c.execute("insert into bx_loyalty_ledger(id,customer_id,kind,points,operation_key,note) values('op3','c','adjustment',20,'adj:op3','')")
assert c.execute("select count(*) from bx_notifications where id='adjustment:op3'").fetchone()[0]==0
print('PASS: изменение статуса с дополнительными записями триггеров, уведомление уровня и отключение уведомлений')

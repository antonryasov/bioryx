"""SQL reports against SQLite. Real D1 and Telegram are not covered."""
from pathlib import Path
import sqlite3,re
r=Path(__file__).resolve().parents[1];c=sqlite3.connect(':memory:');c.row_factory=sqlite3.Row;c.execute('PRAGMA foreign_keys=ON')
for f in sorted((r/'worker/migrations').glob('*.sql')):c.executescript(f.read_text())
c.execute("INSERT INTO bx_customers(id,telegram_id) VALUES('a','1'),('b','2')")
def order(oid,cid,dt):
 c.execute("INSERT INTO orders(id,customer_name,phone,city,delivery,payment,consent,total,created_at) VALUES(?,'A','7','Грозный','pickup','cash',1,1000,?)",(oid,dt))
 if cid:c.execute('INSERT INTO bx_order_owners(order_id,customer_id) VALUES(?,?)',(oid,cid))
 c.execute('INSERT INTO bx_order_finance(order_id,customer_id,gross) VALUES(?,?,1000)',(oid,cid))
 c.execute("UPDATE orders SET status='delivered',payment_status='paid' WHERE id=?",(oid,))
order('old','a','2026-02-02 12:00:00');order('repeat','a','2026-03-02 12:00:00');order('repeat2','a','2026-03-03 12:00:00');order('first','b','2026-03-04 12:00:00');order('guest',None,'2026-03-05 12:00:00')
src=(r/'worker/src/index.js').read_text();section=src[src.index("if(path==='business-report'"):src.index("if(path==='sales-analysis'")]
def q(kind):
 m=re.search(r'\b'+kind+r':\{columns:\[(.*?)\],sql:"([^"]+)"',section);assert m,kind
 cols=re.findall(r"'([^']+)'",m.group(1));sql=m.group(2);cur=c.execute(sql,('2026-03-01','2026-03-31') if '?' in sql else ());assert [z[0] for z in cur.description]==cols;return [dict(x) for x in cur]
ret={x['customer_type']:x for x in q('retention')}
assert ret['first']['customers']==1 and ret['repeat']['customers']==1 and ret['repeat']['orders']==2 and ret['unlinked']['customers'] is None and ret['unlinked']['orders']==1,ret
adjust=q('adjustments');assert sum(x['orders'] for x in adjust)==4 and sum(x['net_paid_goods_rub'] for x in adjust)==4000,adjust
balances=q('balances');assert sum(x['customers'] for x in balances)==2,balances
print('PASS: реальный SQL новых отчётов, повторные/новые покупатели, непривязанные заказы, скидки и балансы')

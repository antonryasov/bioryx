"""Ручной журнал денежных операций; SQLite не заменяет настоящий D1."""
from pathlib import Path
import sqlite3,re
r=Path(__file__).resolve().parents[1];c=sqlite3.connect(':memory:');c.row_factory=sqlite3.Row;c.execute('PRAGMA foreign_keys=ON')
for f in sorted((r/'worker/migrations').glob('*.sql')):c.executescript(f.read_text())
c.executescript((r/'worker/migrations/0022_cashbook.sql').read_text())
create="INSERT INTO bx_cashbook(id,event_date,kind,amount,description,order_id,voided,version) VALUES(?,?,?,?,?,?,0,?) ON CONFLICT(id) DO NOTHING"
# NULL is required for an optional foreign key.
def add(id,kind,amount,date='2026-03-05'):return c.execute(create,(id,date,kind,amount,'',None,'v1'))
add('a','sale_receipt',1000);add('b','customer_refund',100);add('c','supplier_payment',400);add('d','owner_in',300);add('e','owner_out',50)
count=lambda:c.execute("SELECT count(*) FROM bx_config_audit WHERE module='finance'").fetchone()[0]
assert count()==5
add('a','sale_receipt',1000);assert count()==5
c.execute("UPDATE bx_cashbook SET voided=1,version='v2' WHERE id='c' AND version='v1'");assert count()==6
assert c.execute("UPDATE bx_cashbook SET amount=1 WHERE id='c' AND version='v1'").rowcount==0
src=(r/'worker/src/index.js').read_text();sect=src[src.index("if(path==='cashbook'&&req.method==='GET')"):src.index("if(path==='cashbook'&&req.method==='POST')")];m=re.search(r'env.DB.prepare\("(SELECT COALESCE\(SUM\(CASE WHEN voided=0.*?)"\)',sect);assert m
v=c.execute(m.group(1),('2026-03-01','2026-03-31')).fetchone();assert tuple(v)==(1000,100,300,50),tuple(v)
report=src[src.index("if(path==='business-report'"):src.index("if(path==='sales-analysis'")];m=re.search(r'cashbook:\{columns:\[(.*?)\],sql:"([^"]+)"',report);assert m
rows=c.execute(m.group(2),('2026-03-01','2026-03-31')).fetchall();assert len(rows)==4 and sum(x['signed_amount_rub'] for x in rows)==1150
c.commit();c.execute('BEGIN');c.execute("UPDATE bx_cashbook SET amount=999 WHERE id='a'");assert count()==7;c.rollback();assert count()==6 and c.execute("SELECT amount FROM bx_cashbook WHERE id='a'").fetchone()[0]==1000
print('PASS: повтор миграции, идемпотентность, аудит и откат, аннулирование, версия, денежное движение и CSV')

"""Local SQLite audit checks, not real Cloudflare D1."""
import sqlite3,json
from pathlib import Path
r=Path(__file__).resolve().parents[1];c=sqlite3.connect(':memory:');c.execute('PRAGMA foreign_keys=ON')
for f in sorted((r/'worker/migrations').glob('*.sql')):c.executescript(f.read_text())
c.executescript((r/'worker/migrations/0020_config_audit.sql').read_text())
c.execute("INSERT INTO bx_promos(code,title,percent,active) VALUES('PROMO','Скидка',10,1)")
c.execute("INSERT INTO bx_promo_levels(code,level) VALUES('PROMO','start')")
c.execute("INSERT INTO bx_promo_rules(code,min_goods,max_uses) VALUES('PROMO',1000,5)")
c.execute("UPDATE bx_promos SET title='Новое название' WHERE code='PROMO'")
row=c.execute("SELECT old_json,new_json FROM bx_config_audit WHERE entity='bx_promos' AND action='update'").fetchone()
assert json.loads(row[0])['title']=='Скидка' and json.loads(row[1])['title']=='Новое название'
c.execute("DELETE FROM bx_promo_levels WHERE code='PROMO' AND level='start'")
assert c.execute("SELECT count(*) FROM bx_config_audit WHERE entity='bx_promo_levels' AND action='delete'").fetchone()[0]==1
c.execute("UPDATE bx_club_levels SET title='НОВЫЙ',cashback=15 WHERE id='start'")
c.execute("INSERT INTO bx_club_sale_prices(product_id,level,sale_price) VALUES('demo-creatine','start',990)")
c.execute("UPDATE bx_club_sale_prices SET active=0 WHERE product_id='demo-creatine'")
assert c.execute("SELECT count(*) FROM bx_config_audit WHERE module='sale'").fetchone()[0]==2
assert c.execute("SELECT count(*) FROM bx_config_audit WHERE module='club'").fetchone()[0]==1
before=c.execute('SELECT count(*) FROM bx_config_audit').fetchone()[0]
c.execute("UPDATE bx_club_levels SET title=title WHERE id='start'")
assert c.execute('SELECT count(*) FROM bx_config_audit').fetchone()[0]==before
c.commit();c.execute('BEGIN');c.execute("UPDATE bx_promos SET active=0 WHERE code='PROMO'");assert c.execute('SELECT count(*) FROM bx_config_audit').fetchone()[0]==before+1;c.rollback()
assert c.execute('SELECT count(*) FROM bx_config_audit').fetchone()[0]==before and c.execute("SELECT active FROM bx_promos WHERE code='PROMO'").fetchone()[0]==1
print('PASS: повтор миграции, аудит акций/уровней/цен, старое и новое значение, отсутствие пустых изменений, откат')

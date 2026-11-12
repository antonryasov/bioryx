# Локальный демонстрационный сервер панели: только вымышленные данные, без D1 и Telegram.
from http.server import BaseHTTPRequestHandler, HTTPServer
import json
from pathlib import Path
from urllib.parse import urlsplit,parse_qs
orders=[{'id':'a2f01c88-1111-4111-a111-222222222222','customer_name':'Амина М.','created_at':'2026-11-12 11:34','status':'new','payment_status':'unpaid','total':3290,'phone':'+7 900 000-00-00','city':'Грозный','address':'','delivery':'pickup','payment':'cash','comment':''},{'id':'b8139ef2-1111-4111-a111-222222222222','customer_name':'Магомед А.','created_at':'2026-11-11 16:12','status':'packing','payment_status':'paid','total':4790,'phone':'+7 900 000-00-00','city':'Грозный','address':'','delivery':'courier','payment':'sbp','comment':''},{'id':'c410ab21-1111-4111-a111-222222222222','customer_name':'Лейла Д.','created_at':'2026-11-10 13:06','status':'delivered','payment_status':'paid','total':1990,'phone':'+7 900 000-00-00','city':'Грозный','address':'','delivery':'cdek','payment':'sbp','comment':''}]
products=json.loads(Path('data/products.json').read_text())
customers=[{'id':'client-1','display_name':'Амина','telegram_username':'amina_demo','created_at':'2026-11-01 10:00','balance':610,'spent':3290,'subscribed':1},{'id':'client-2','display_name':'Магомед','telegram_username':'magomed_demo','created_at':'2026-10-20','balance':850,'spent':16900,'subscribed':0}]
promos=[{'code':'BIORYX10','title':'Первый шаг','percent':10,'active':1}]
class H(BaseHTTPRequestHandler):
 def do_GET(self):
  u=urlsplit(self.path);p=u.path.split('/')[-1];q=parse_qs(u.query)
  if u.path in ['/','/admin','/admin/']:
   html=Path('worker/admin.html').read_text().replace('<div class="breadcrumb">','<div class="breadcrumb"><strong style="color:#5a48ea">ДЕМО · ВЫМЫШЛЕННЫЕ ДАННЫЕ</strong> &nbsp; ');b=html.encode();self.send_response(200);self.send_header('Content-Type','text/html; charset=utf-8');self.end_headers();self.wfile.write(b);return
  data={'me':{'ok':True},'summary':{'orders':{'total':26,'new_orders':4,'paid_goods':86490},'products':{'total':6},'customers':{'total':18},'days':[{'day':'2026-11-10','orders':3},{'day':'2026-11-11','orders':4},{'day':'2026-11-12','orders':2}]},'orders':{'orders':orders},'products':{'products':products},'customers':{'customers':customers},'promos':{'promos':promos}}
  if p=='order':
   o=next((x for x in orders if x['id']==q.get('id',[''])[0]),orders[0]);data[p]={'order':o,'items':[{'name':'WHEY / ВАНИЛЬ','qty':1,'price':3290}],'messages':[{'direction':'customer','body':'Здравствуйте! Когда можно забрать заказ?','created_at':'2026-11-12 12:00'}],'finance':{'gross':3290,'promo_code':'','discount':0,'points_used':0},'audit':[]}
  if p=='customer':
   c=next((x for x in customers if x['id']==q.get('id',[''])[0]),customers[0]);data[p]={'customer':{**c,'phone':''},'orders':orders[:1],'history':[{'kind':'welcome','note':'Приветственные баллы','points':500,'created_at':'2026-11-01'}]}
  self.send_response(200 if p in data else 404);self.send_header('Content-Type','application/json; charset=utf-8');self.end_headers();self.wfile.write(json.dumps(data.get(p,{'error':'Демо: недоступно'}),ensure_ascii=False).encode())
 def do_POST(self):
  self.send_response(200);self.send_header('Content-Type','application/json');self.end_headers();self.wfile.write(b'{"ok":true}')
HTTPServer(('0.0.0.0',8002),H).serve_forever()

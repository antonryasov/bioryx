// BIORYX: Cloudflare Worker + D1. Оплата и доставка подтверждаются продавцом вручную.
const sendJson=(data,status=200,headers={})=>Response.json(data,{status,headers:{'cache-control':'no-store',...headers}});
function cors(req,env){try{let origin=new URL(env.SITE_URL).origin;if(req.headers.get('Origin')===origin)return {'access-control-allow-origin':origin,'vary':'Origin','access-control-allow-methods':'GET, POST, OPTIONS','access-control-allow-headers':'content-type'}}catch{}return {}}
async function tg(token,method,data){const r=await fetch('https://api.telegram.org/bot'+token+'/'+method,{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify(data)});const d=await r.json();if(!r.ok||!d.ok)throw Error('telegram_error');return d.result}
const clip=(x,n)=>typeof x==='string'?x.trim().slice(0,n):'';
async function notify(env,id){
 if(!env.OWNER_BOT_TOKEN||!env.OWNER_CHAT_ID)return;
 const row=await env.DB.prepare('SELECT * FROM orders WHERE id=?').bind(id).first();if(!row)return;
 const items=(await env.DB.prepare('SELECT name,price,qty FROM order_items WHERE order_id=?').bind(id).all()).results;
 const names={pickup:'Самовывоз, Грозный',courier:'Курьер, Грозный',cdek:'СДЭК'};
 let text='🛒 BIORYX — новый заказ\n№ '+row.id+'\n\n'+items.map(x=>`${x.name} × ${x.qty} — ${x.price*x.qty} ₽`).join('\n')+'\n\nТовары: '+row.total+' ₽\nДоставка: стоимость уточняется\nПолучение: '+names[row.delivery]+'\nОплата: '+(row.payment==='cash'?'наличными':'СБП, не подтверждена')+'\nИмя: '+row.customer_name+'\nТелефон: '+row.phone+'\nГород: '+row.city+'\nАдрес/ПВЗ: '+row.address+'\nКомментарий: '+row.comment;
 try{await tg(env.OWNER_BOT_TOKEN,'sendMessage',{chat_id:env.OWNER_CHAT_ID,text});await env.DB.prepare("UPDATE outbox SET state='sent', attempts=attempts+1,last_error='' WHERE order_id=?").bind(id).run()}
 catch{await env.DB.prepare("UPDATE outbox SET attempts=attempts+1,last_error='telegram_error' WHERE order_id=?").bind(id).run()}
}
async function createOrder(req,env,ctx){
 if(!env.DB)return sendJson({error:'База не подключена'},503,cors(req,env));
 if(!env.OWNER_BOT_TOKEN||!env.OWNER_CHAT_ID)return sendJson({error:'Уведомления владельцу не настроены'},503,cors(req,env));
 let body;try{if(Number(req.headers.get('content-length')||0)>20000)throw Error();const text=await req.text();if(text.length>20000)throw Error();body=JSON.parse(text)}catch{return sendJson({error:'Некорректный запрос'},400,cors(req,env))}
 const id=clip(body.id,36), name=clip(body.name,100),phone=clip(body.phone,30),city=clip(body.city,100),address=clip(body.address,250),comment=clip(body.comment,500),delivery=body.delivery,payment=body.payment;
 if(!/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(id)||name.length<2||phone.replace(/\D/g,'').length<10||!city||!['pickup','courier','cdek'].includes(delivery)||!['cash','sbp'].includes(payment)||(payment==='cash'&&delivery==='cdek')||(delivery!=='pickup'&&!address)||((delivery==='pickup'||delivery==='courier')&&city.toLowerCase()!=='грозный')||body.consent!==true||!Array.isArray(body.items)||body.items.length<1||body.items.length>30)return sendJson({error:'Проверьте поля заказа и способ оплаты'},400,cors(req,env));
 const existing=await env.DB.prepare('SELECT id FROM orders WHERE id=?').bind(id).first();if(existing)return sendJson({ok:true,id,duplicate:true},200,cors(req,env));
 const seen=new Set(),items=[];
 for(const item of body.items){if(typeof item.id!=='string'||item.id.length>100||seen.has(item.id)||!Number.isInteger(item.price)||item.price<=0||!Number.isInteger(item.qty)||item.qty<1||item.qty>20)return sendJson({error:'Некорректная корзина'},400,cors(req,env));seen.add(item.id);const p=await env.DB.prepare('SELECT id,name,price,stock FROM products WHERE id=? AND active=1').bind(item.id).first();if(!p||p.stock<item.qty||!Number.isInteger(p.price)||p.price<=0||p.price!==item.price)return sendJson({error:'Товар недоступен или его остаток изменился. Обновите каталог.'},409,cors(req,env));items.push({...p,qty:item.qty})}
 const total=items.reduce((a,x)=>a+x.price*x.qty,0);if(!Number.isSafeInteger(total)||total>10000000)return sendJson({error:'Недопустимая сумма'},400,cors(req,env));
 let statements=[env.DB.prepare('INSERT INTO orders(id,customer_name,phone,city,address,delivery,payment,comment,total,consent) VALUES(?,?,?,?,?,?,?,?,?,1)').bind(id,name,phone,city,address,delivery,payment,comment,total)];
 for(const p of items)statements.push(env.DB.prepare('INSERT INTO order_items(order_id,product_id,name,price,qty) VALUES(?,?,?,?,?)').bind(id,p.id,p.name,p.price,p.qty));
 statements.push(env.DB.prepare('INSERT INTO outbox(order_id) VALUES(?)').bind(id));
 try{await env.DB.batch(statements)}catch(e){const existing=await env.DB.prepare('SELECT id FROM orders WHERE id=?').bind(id).first();if(existing)return sendJson({ok:true,id,duplicate:true},200,cors(req,env));return sendJson({error:'Цена или наличие изменились. Обновите каталог и попробуйте снова.'},409,cors(req,env))}
 ctx.waitUntil(notify(env,id).catch(()=>{}));return sendJson({ok:true,id,total},200,cors(req,env));
}
export default {
 async fetch(req,env,ctx){
  const url=new URL(req.url), headers=cors(req,env);
  if(req.method==='OPTIONS')return new Response(null,{status:204,headers});
  if(url.pathname==='/setup'&&req.method==='GET')return new Response(`<!doctype html><html lang="ru"><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>Настройка BIORYX</title><body style="font:16px system-ui;max-width:600px;margin:40px auto;padding:20px"><h1>Настройка BIORYX</h1><p>Введите SETUP_SECRET. После настройки удалите этот секрет из Worker.</p><input id="secret" type="password" placeholder="SETUP_SECRET"><p><button onclick="go('owner')">Узнать chat ID владельца</button> <button onclick="go('webhook')">Подключить клиентского бота</button> <button onclick="go('retry')">Повторить уведомления</button></p><pre id="out" style="white-space:pre-wrap"></pre><script>async function go(action){let out=document.getElementById('out');out.textContent='Выполняется...';try{let r=await fetch('/setup',{method:'POST',headers:{'content-type':'application/json','x-setup-secret':document.getElementById('secret').value},body:JSON.stringify({action})});out.textContent=JSON.stringify(await r.json(),null,2)}catch(e){out.textContent='Ошибка соединения'}}</script></body></html>`,{headers:{'content-type':'text/html; charset=utf-8','cache-control':'no-store','x-robots-tag':'noindex'}});
  if(url.pathname==='/health')return sendJson({ok:true,db:!!env.DB},200,headers);
  if(url.pathname==='/catalog'&&req.method==='GET'){if(!env.DB)return sendJson({error:'catalog_not_configured'},503,headers);try{const d=await env.DB.prepare('SELECT id,sku,name,category,description,price,stock,image FROM products WHERE active=1 ORDER BY sort_order,name LIMIT 500').all();return sendJson({products:d.results||[]},200,headers)}catch{return sendJson({error:'catalog_unavailable'},503,headers)}}
  if(url.pathname==='/order'&&req.method==='POST'){if(!headers['access-control-allow-origin'])return sendJson({error:'Недопустимый источник'},403);return createOrder(req,env,ctx);}
  if(url.pathname==='/telegram'&&req.method==='POST'){
   if(!env.WEBHOOK_SECRET||!env.CUSTOMER_BOT_TOKEN||req.headers.get('X-Telegram-Bot-Api-Secret-Token')!==env.WEBHOOK_SECRET)return new Response('Unauthorized',{status:401});
   let u;try{u=await req.json()}catch{return new Response('Bad request',{status:400})};const m=u.message;if(m?.chat?.type==='private'&&m.text?.startsWith('/start')){const keyboard=[];try{const site=new URL(env.SITE_URL);if(site.protocol==='https:')keyboard.push([{text:'Открыть каталог',url:new URL('catalog.html',site.href.endsWith('/')?site.href:site.href+'/').href}])}catch{};try{await tg(env.CUSTOMER_BOT_TOKEN,'sendMessage',{chat_id:m.chat.id,text:'Привет! Это BIORYX. Выбирайте товары на сайте. По вопросам заказа свяжитесь с продавцом.',reply_markup:{inline_keyboard:keyboard}})}catch{return new Response('Telegram unavailable',{status:502})}}return new Response('ok');
  }
  // Одноразовая настройка из собственного браузера с секретом, удалить SETUP_SECRET после настройки.
  if(url.pathname==='/setup'&&req.method==='POST'){
   if(!env.SETUP_SECRET||req.headers.get('x-setup-secret')!==env.SETUP_SECRET)return sendJson({error:'unauthorized'},401);
   let data;try{data=await req.json()}catch{return sendJson({error:'bad request'},400)}
   try{if(data.action==='owner'){const updates=await tg(env.OWNER_BOT_TOKEN,'getUpdates',{limit:100});return sendJson({chats:updates.filter(x=>x.message?.chat?.type==='private').map(x=>({id:String(x.message.chat.id),name:x.message.chat.first_name||''}))})}
   if(data.action==='webhook'){if(!env.CUSTOMER_BOT_TOKEN||!env.WEBHOOK_SECRET)return sendJson({error:'missing bot secrets'},400);await tg(env.CUSTOMER_BOT_TOKEN,'setWebhook',{url:url.origin+'/telegram',secret_token:env.WEBHOOK_SECRET});return sendJson({ok:true})}
   if(data.action==='retry'){const q=await env.DB.prepare("SELECT order_id FROM outbox WHERE state='pending' ORDER BY id LIMIT 20").all();for(const row of q.results)await notify(env,row.order_id);return sendJson({ok:true,checked:q.results.length})}
   }catch{return sendJson({error:'setup_failed'},500)}return sendJson({error:'unknown action'},400)
  }
  return new Response('Not found',{status:404});
 },
 async scheduled(event,env,ctx){if(!env.DB)return;const q=await env.DB.prepare("SELECT order_id FROM outbox WHERE state='pending' ORDER BY id LIMIT 20").all();for(const row of q.results)await notify(env,row.order_id)}
};

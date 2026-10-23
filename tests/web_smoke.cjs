const { chromium } = require('playwright');
const fs = require('node:fs');
const path = require('node:path');
const http = require('node:http');
const assert = require('node:assert/strict');
const root = path.resolve(__dirname,'..');
const build = path.join(root,'build/web');
const output = path.join(root,'docs/screenshots');
const errors=[]; const checks=[];
const types={'.html':'text/html','.wasm':'application/wasm','.js':'text/javascript','.pck':'application/octet-stream','.png':'image/png'};
let server, browser, page;
function check(name,value,details={}) { assert.ok(value,`${name}: ${JSON.stringify(details)}`); checks.push({name,details}); console.log('PASS',name); }
async function state() { return page.evaluate(()=>window.__klaxQA); }
async function shot(name) { await page.screenshot({path:path.join(output,name+'.png')}); }
async function hold(key,ms) { await page.keyboard.down(key); await page.waitForTimeout(ms); await page.keyboard.up(key); }
async function click(text){ await page.waitForFunction(t=>window.__klaxQA?.buttons.some(b=>b.text.includes(t)&&!b.disabled),text,{timeout:10000});const b=(await state()).buttons.find(b=>b.text.includes(text)&&!b.disabled);await page.mouse.click(b.x,b.y);await page.waitForTimeout(300); }
(async()=>{
 fs.mkdirSync(output,{recursive:true});
 server=http.createServer((req,res)=>{
  const target=path.resolve(build,'.'+new URL(req.url,'http://localhost').pathname.replace(/\/$/,'/index.html'));
  if(!target.startsWith(build+path.sep)){res.writeHead(403);return res.end();}
  res.setHeader('Content-Type',types[path.extname(target)]||'application/octet-stream');
  fs.createReadStream(target).on('error',()=>{res.statusCode=404;res.end();}).pipe(res);
 });
 await new Promise(r=>server.listen(0,'127.0.0.1',r));
 browser=await chromium.launch({executablePath:process.env.CHROMIUM_EXECUTABLE||undefined,headless:true,args:['--no-sandbox','--disable-dev-shm-usage','--use-angle=swiftshader','--enable-unsafe-swiftshader',...(process.env.CHROMIUM_SINGLE_PROCESS?['--single-process','--in-process-gpu']:[])]});
 page=await browser.newPage({viewport:{width:1280,height:800}});
 page.on('pageerror',e=>errors.push(e.message));
 page.on('console',m=>{if(process.env.WEB_DEBUG)console.log('BROWSER',m.text());if(/SCRIPT ERROR:|Parse Error:|ERROR:/.test(m.text())) errors.push(m.text());});
 await page.goto(`http://127.0.0.1:${server.address().port}/?qa=1`);
 await page.waitForFunction(()=>window.__klaxQA?.mode==='HUB',{timeout:60000});
 await page.waitForTimeout(800); await shot('01-carrier');
 await page.keyboard.press('Enter');
 await page.waitForFunction(()=>window.__klaxQA?.mode==='FIELD',{timeout:45000});
 await page.waitForTimeout(800); await shot('02-landing');
 let a=await state(); check('Native WebGL campaign launches',a.creatures===15,a);
 await hold('d',750); await hold('w',1900);
 let b=await state(); check('Keyboard moves researcher',Math.hypot(b.x-a.x,b.z-a.z)>3,{before:[a.x,a.z],after:[b.x,b.z]});
 await page.keyboard.down('e');
 await page.waitForFunction(()=>Object.values(window.__klaxQA?.research||{}).some(r=>r.scanned),null,{timeout:20000});
 await page.keyboard.up('e'); await page.waitForTimeout(200);
 let scanned=await state(); check('Holding E records a specimen',Object.values(scanned.research).some(r=>r.scanned),scanned);
 await shot('03-survey');
 for(let i=0;i<30;i++){
  let s=await state(); if(s.target_distance<3.3)break;
  const dx=s.target_x-s.x,dz=s.target_z-s.z;
  if(Math.abs(dx)>1)await hold(dx>0?'d':'a',220);
  if(Math.abs(dz)>1)await hold(dz>0?'s':'w',220);
 }
 await page.keyboard.press('f'); await page.waitForTimeout(200);
 check('Normal movement and F collect live sample',(await state()).cargo===1,await state());
 await page.keyboard.press('b');await page.waitForTimeout(250);
 check('Field station creates a sample console',(await state()).points.filter(p=>p.kind==='deposit').length===2);
 const beforeDeposit=(await state()).science;
 await page.keyboard.press('e');await page.waitForTimeout(250);
 check('E deposits samples without leaving the field',(await state()).mode==='FIELD'&&(await state()).cargo===0&&(await state()).deposited===1&&(await state()).samples.length===1,await state());
 await page.keyboard.press('e');await page.waitForTimeout(200);
 check('Repeated deposit awards no duplicate research',(await state()).science===beforeDeposit+4);
 await shot('10-sample-deposit');
 await page.keyboard.press('Tab'); await page.waitForTimeout(200);
 check('Tactical mode responds to keyboard',(await state()).tactical);
 await page.keyboard.press('q'); await page.waitForTimeout(250); await shot('04-tactical');
 await page.keyboard.press('Tab');
 await page.keyboard.press('Escape'); await page.waitForTimeout(250);
 let p=await state(); await page.waitForTimeout(650); let p2=await state();
 check('Pause freezes expedition clock',p2.paused&&Math.abs(p2.field_time-p.field_time)<0.04,{before:p.field_time,after:p2.field_time});
 await page.keyboard.press('Escape'); await page.waitForTimeout(200);
 await page.keyboard.press('j'); await page.waitForTimeout(250); await shot('05-journal');
 check('Field journal opens',(await state()).mode==='JOURNAL');
 await page.keyboard.press('Escape'); await page.waitForTimeout(250);
 check('Journal returns to expedition',(await state()).mode==='FIELD');
 for(let i=0;i<45;i++){
  let s=await state(); if(Math.hypot(s.x,s.z)<7.5)break;
  if(Math.abs(s.x)>1)await hold(s.x>0?'a':'d',230);
  if(Math.abs(s.z)>1)await hold(s.z>0?'w':'s',230);
 }
 await page.keyboard.press('x');
 await page.waitForFunction(()=>window.__klaxQA?.mode==='HUB',null,{timeout:10000});
 check('Lander extraction commits sample',(await state()).samples.length===1,await state());
 await page.keyboard.press('Escape'); await page.waitForTimeout(200);
 await shot('06-return');
 await click('Specimen lab'); await shot('07-laboratory');
 await click('Begin assay'); await shot('08-assay');
 check('Assay opens by mouse',(await state()).mode==='ASSAY');
 await page.keyboard.press('Escape'); await page.waitForTimeout(250);
 check('Escape cancels assay without losing specimen',(await state()).mode==='LAB'&&(await state()).samples.length===1);
 await click('Begin assay'); const researchBefore=(await state()).science;
 await click('Analyze now');
 check('Lab analysis awards permanent research',(await state()).mode==='LAB'&&(await state()).science>researchBefore);
 await page.waitForTimeout(1800); await page.reload(); await page.waitForFunction(()=>window.__klaxQA?.mode==='HUB',null,{timeout:60000});
 check('Browser reload restores analyzed specimen',Object.values((await state()).research).some(r=>r.analyzed));
 await click('DEPLOY EXPEDITION');
 await page.waitForFunction(()=>window.__klaxQA?.mode==='FIELD',null,{timeout:10000});
 await page.keyboard.press('r'); await page.waitForTimeout(200);
 check('R boards nearby rover',(await state()).mounted);
 const beforeDrive=await state(); await page.keyboard.down('Shift'); await hold('w',1300); await page.keyboard.up('Shift');
 check('Rover throttle and boost move the vehicle',Math.abs((await state()).z-beforeDrive.z)>4,await state());
 await shot('09-rover');
 await page.keyboard.press('r');await page.waitForTimeout(200);check('R dismounts rover',!(await state()).mounted);
 await page.keyboard.press('c');await page.waitForTimeout(200);
 check('C toggles crouched traversal',(await state()).crouched);
 await page.keyboard.press('c');await page.waitForTimeout(200);
 check('C returns to standing in open ground',!(await state()).crouched);
 check('No browser or engine errors',errors.length===0,errors);
 fs.writeFileSync(path.join(root,'docs/web-verification-v0.2.json'),JSON.stringify({passed:true,checks,errors},null,2)+'\n');
 console.log('WEB_SMOKE_OK',checks.length);
})().catch(async e=>{console.error(e);if(page) await shot('failure').catch(()=>{});fs.writeFileSync(path.join(root,'docs/web-verification-v0.2.json'),JSON.stringify({passed:false,checks,errors,error:e.message},null,2)+'\n');process.exitCode=1;}).finally(async()=>{if(browser)await browser.close();if(server)await new Promise(r=>server.close(r));});

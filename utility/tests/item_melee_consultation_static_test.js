// Node estándar. Desde character-sheet: node utility/tests/item_melee_consultation_static_test.js
const fs=require('fs'),zlib=require('zlib'),assert=require('assert'),crypto=require('crypto');
const base='graphics/frames/items/deafault/';
const expected={
  'item_background_arma_cc.png':[651,433,true], 'item_background.png':[650,433,false],
  'item_border_arma_cc.png':[200,201,true], 'item_border.png':[164,165,true],
  'item_task_selected.png':[168,32,false], 'item_titulos_arma_cc.png':[392,25,true],
  'item_titulos_perfil_arma_cc.png':[393,24,true], 'item_perfil_arma_cc.png':[393,52,true],
};
// Decodifica alpha real: tener canal RGBA no implica tener píxeles transparentes.
for(const [name,[width,height,transparent]] of Object.entries(expected)){
  const b=fs.readFileSync(base+name);assert.equal(b.readUInt32BE(16),width);assert.equal(b.readUInt32BE(20),height);
  assert.equal(b[24],8);assert.equal(b[25],6);assert.equal(b[28],0);
  let p=8,parts=[];while(p<b.length){const n=b.readUInt32BE(p);if(b.toString('ascii',p+4,p+8)==='IDAT')parts.push(b.subarray(p+8,p+8+n));p+=n+12;}
  const data=zlib.inflateSync(Buffer.concat(parts)),stride=width*4;let previous=Buffer.alloc(stride),hasAlpha=false;
  for(let y=0;y<height;y++){
    const filter=data[y*(stride+1)],row=Buffer.from(data.subarray(y*(stride+1)+1,(y+1)*(stride+1)));assert(filter<=4);
    for(let x=0;x<stride;x++){
      const a=x>=4?row[x-4]:0,u=previous[x],c=x>=4?previous[x-4]:0;let v=0;
      if(filter===1)v=a;else if(filter===2)v=u;else if(filter===3)v=Math.floor((a+u)/2);
      else if(filter===4){const q=a+u-c,pa=Math.abs(q-a),pb=Math.abs(q-u),pc=Math.abs(q-c);v=pa<=pb&&pa<=pc?a:pb<=pc?u:c;}
      row[x]=(row[x]+v)&255;if(x%4===3&&row[x]<255)hasAlpha=true;
    }
    if(name==='item_perfil_arma_cc.png'&&y===20)assert(row[50*4+3]<255,'El relleno debe ser visible bajo el interior del PNG');
    previous=row;
  }assert.equal(hasAlpha,transparent,name);
}
const view=fs.readFileSync('campaign/record_item_melee_consultation_aptus.xml','utf8');
const graphics=fs.readFileSync('graphics/graphics_aptus_item_consultation.xml','utf8');
const instance=fs.readFileSync('campaign/record_inventory_item_aptus.xml','utf8');
const manifest=fs.readFileSync('extension.xml','utf8');
for(const xml of [view,graphics,instance,manifest]){
  const stack=[];const clean=xml.replace(/<!--[\s\S]*?-->|<!\[CDATA\[[\s\S]*?\]\]>|<\?[\s\S]*?\?>/g,'');
  for(const tag of clean.match(/<[^>]*>/g)||[]){const name=tag.match(/^<\/?([\w.-]+)/)?.[1];assert(name,tag);
    if(tag.startsWith('</'))assert.equal(stack.pop(),name);else if(!tag.endsWith('/>'))stack.push(name);
  }assert.equal(stack.length,0);
}
for(const xml of [view,graphics])for(const [,file]of xml.matchAll(/file="([^"]+)"/g))assert(fs.existsSync(file),file);
assert(manifest.includes('source="graphics/graphics_aptus_item_consultation.xml"'));
assert(manifest.includes('source="campaign/record_item_melee_consultation_aptus.xml"'));
assert(view.includes('22,21,192,192')&&view.includes('<drawmode>fit</drawmode>'));
assert(instance.includes('18,45,157,157')&&instance.includes('0,34,650,399'));
assert(instance.includes('onInstanceCreated() window.onConsultationCreated()'));
assert(view.includes('<bounds>0,0,393,52</bounds>')); 
assert(view.includes('<bounds>239,46,393,24</bounds>')&&view.includes('aptus_item_columns'));
assert(!view.includes('name="delete_button"')&&!view.includes('name="delete_art"'));
assert(view.includes('6,29,381,19')&&view.includes('239,349,392,28'));
assert.equal([...view.matchAll(/<static>Perfil<\/static>/g)].length,1);
assert.equal([...view.matchAll(/<static>Habilidad<\/static>/g)].length,1);
assert(view.includes('<target>description</target>')&&view.includes('<target>blocks</target>'));
const main=fs.readFileSync('scripts/record_inventory_item_aptus.lua','utf8');
assert(main.includes('melee_weapon={ class="aptus_item_melee_view"'));
assert(main.includes('restoreEditorControls();')&&main.includes('consult_background.sendToBack()'));
const script=fs.readFileSync('scripts/item_melee_consultation_aptus.lua','utf8');
const block=fs.readFileSync('scripts/item_melee_block_aptus.lua','utf8');
for(const source of [script,block])assert(!/DB\.(setValue|createChild|createNode|deleteNode|deleteChild|copyNode)/.test(source));
assert(script.includes('APTUSEquipmentManager.getCollections(node)'));
assert(script.includes('APTUSQualityManager.summary(profile.qualities)')&&script.includes('APTUSQualityManager.details(profile.qualities)'));
assert(script.indexOf('general.configure')>script.indexOf('for _, key in ipairs(keys)'));
assert(script.includes('"damage", ""')&&script.includes('"critical", ""'));
assert(!script.includes('for i = 1, 4'));
console.log('OK: 8 PNG (dimensiones/alpha real), XML, referencias, imágenes fit, scrolls, filas y lectura sin escrituras.');

// Huellas de los originales inspeccionados, para detectar alteraciones posteriores.
const hashes={
  "item_perfil_arma_cc.png": "7c35aff41c0e3aa0606ae69586c6e15beafbad2e43b2dc460d40e6f471c4679e",
  "item_background.png": "b3a1640927d923fec24b762ededa818726cc4d97c2cf3ecb2b2dcc66a40d8b18",
  "item_background_arma_cc.png": "0358f73ffafb8592e4cead5149cbd8450de1c68de9d65e07bbccc312ec591152",
  "item_border.png": "3d1000da792a586b8c7666ccce94325c858030b3419a51c36dfe47a0948a38ed",
  "item_border_arma_cc.png": "ec703e8d70b88822f878fc970f343999ff539749457b97bbefb189606d9e798d",
  "item_task_selected.png": "273b63c76fd8e8c3c01dfef85de45ddc8df306f0bb84e3754d22937d437e047f",
  "item_titulos_arma_cc.png": "cc1a3fac6816cb1e4a3dedd837c6dc2208cb6962b7e3d2b070ff895c18cbd70c",
  "item_titulos_perfil_arma_cc.png": "957a48ea7c397b8a2a9ccf033aa5193bf54facbf4e4e12a0dc73cae4fab146cd"
};
for(const [name,hash]of Object.entries(hashes))assert.equal(crypto.createHash("sha256").update(fs.readFileSync(base+name)).digest("hex"),hash,name);
console.log("OK: originales PNG sin alteración (SHA-256).");

assert(graphics.includes('name="aptus_item_melee_profile" file="graphics/frames/items/deafault/item_perfil_arma_cc.png"'));
assert((view.match(/<icon>aptus_item_columns<\/icon>/g)||[]).length===1);
assert(!block.includes('multilinespacing')&&block.includes('qualityWidget.setMaxWidth(381)'));
assert(!script.includes('requestDelete')&&!script.includes('delete_button'));
console.log('OK: cabecera negra única, tarjetas 393x52, cualidades acotadas y consulta sin Eliminar.');

// Regresión de composición: exigir la ruta simple conocida, sin referencias invisibles.
function validateStableLayout(xml,resources){
 assert(!xml.includes('profile_horizontal'));
 assert(!xml.includes('aptus_melee_section_frame')&&!resources.includes('aptus_melee_section_frame'));
 assert(!xml.includes('profile_fill')&&!xml.includes('<backcolor>'));
 const rectangle=(name)=>{
  const body=xml.match(new RegExp('<([\\w_]+) name="'+name+'">([\\s\\S]*?)</\\1>'))?.[2];
  assert(body,name);const match=body.match(/<bounds>([\d,]+)<\/bounds>/);assert(match,name+' necesita dimensiones explícitas');
  assert(!body.includes('<invisible')&&!body.includes('<anchored'),name);
  return [match[1].split(',').map(Number),body];
 };
 for(const [name,rect,icon] of [
  ['profile_section',[239,19,392,25],'aptus_item_section'],
  ['column_background',[239,46,393,24],'aptus_item_columns'],
  ['blocks',[239,72,393,269],null],
  ['profile_art',[0,0,393,52],'aptus_item_melee_profile'],
  ['section_art',[0,0,392,25],'aptus_item_section']]){
  const [actual,body]=rectangle(name);assert.deepEqual(actual,rect,name);
  if(icon)assert(body.includes('<icon>'+icon+'</icon>'),name+' recurso directo');
 }
 assert(rectangle('blocks')[1].includes('<class>aptus_item_melee_block</class>'));
 assert.deepEqual(rectangle('blocks_scroll')[0],[632,72,12,269]);
 for(const [name,rect]of [['profile_section_text',[249,21,380,21]],['heading_profile',[249,48,100,20]],['section_title',[10,2,380,21]],
  ['profile_name',[6,6,100,20]],['skill',[115,6,89,20]],['damage',[214,6,74,20]],['critical',[299,6,86,20]],['profile_qualities',[6,29,381,19]]])assert.deepEqual(rectangle(name)[0],rect,name);
 assert(xml.includes('<margins control="0,0,0,6" />'));
}
validateStableLayout(view,graphics);
// Confirmar que la comprobación rechaza las causas estructurales de esta regresión.
assert.throws(()=>validateStableLayout(view.replace('<bounds>239,72,393,269</bounds>','<anchored to="profile_horizontal" height="269" />'),graphics));
assert.throws(()=>validateStableLayout(view.replace('<bounds>239,72,393,269</bounds>','<bounds>239,72,0,0</bounds>'),graphics));
assert.throws(()=>validateStableLayout(view.replace('<icon>aptus_item_section</icon>','<frame name="aptus_melee_section_frame" />'),graphics));
assert(!block.includes('profile_fill'));
console.log('OK estático: iconos originales y bounds explícitos recuperados; pruebas negativas detectan anclajes nuevos, lista colapsada y marco sustituto. No ejecuta FGU.');

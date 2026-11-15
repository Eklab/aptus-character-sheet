// Comprobaciones de estructura; no ejecuta Lua ni el renderizado nativo.
const fs=require('fs'),assert=require('assert'),read=p=>fs.readFileSync(p,'utf8');
const manager=read('scripts/manager_aptus_inventory.lua');
const calculation=manager.slice(manager.indexOf('local function calculateContainerLoads('),manager.indexOf('-- No rellena valores ausentes:'));
assert(calculation.includes('item.content_load > item.capacity_load'));
assert(calculation.includes('item.reduction_active = item.is_container and item.parent_id == ""'));
assert(calculation.includes('elseif item.content_load <= item.capacity_load then effective = item.own_load')); 
assert(calculation.includes('accumulated[parent.id] = accumulated[parent.id] + gross'));
assert(calculation.includes('for _, item in ipairs(result.roots) do'));
assert(calculation.includes('while index <= #queue do'));
assert(calculation.includes('result.total_load = complete and total or nil'));
assert(!/DB\.(setValue|createNode|createChild|deleteNode|deleteChild)/.test(calculation));
assert(manager.includes('calculateContainerLoads(result, nodes)'));
assert(manager.includes('math.ceil(count / every) * load'));
const row=read('scripts/char_equipment_row_aptus.lua');
assert(row.includes('capacityWidget.setColor(item.hide_contents and "FFB8B8B8" or (item.overloaded and "FFFF4040" or nil))'));
assert(row.includes('nameWidget.setColor(item.hide_contents and "FFB8B8B8" or nil)'));
assert(!row.includes('item_name.setColor'));
assert(row.includes('capacityWidget.setMaxWidth(math.max(1, available - 15))'));
assert(row.includes('nameWidget.setMaxWidth(math.max(1, available - capacityWidth - 3))'));
assert(row.includes('nameWidget.setText((item.name:gsub'));
const view=read('scripts/char_equipment_aptus.lua');
assert(view.includes('APTUSInventoryManager.getLoadStatus(getDatabaseNode(), inventory)')); 
assert(view.includes('load_hint.setValue(status.state')); 
assert(view.indexOf('APTUSInventoryManager.getLoadStatus(')<view.indexOf('local searchText'));
assert(view.includes('load_fill.setVisible(false)'));
const test=read('utility/tests/inventory_container_load_test.lua');
assert(test.includes('m.getCharacterInventory(character)'));
for(const call of ['m.createFromTemplate(','m.setQuantity(','m.removeUnits(','m.transfer('])assert(test.includes(call));
assert(test.includes('{{0,2},{1,2},{4,2},{5,2},{6,8},{7,9}}'));
assert(test.includes('view.total_load==8')&&test.includes('view.total_load==5'));
assert(test.includes('test.writes()==writes'));
assert(read('utility/tests/inventory_create_test.lua').includes('loadfile("utility/tests/inventory_container_load_test.lua")'));
console.log('OK estático: cálculo iterativo sin escrituras, reducción completa, suma de raíces, indicador rojo aislado y panel independiente de filtros; suite funcional preparada.');

assert(calculation.includes('local capacity = 2 + strength * 2'));
assert(calculation.includes('attributes.fue.effective'));
for(const boundary of ['ratio < 0.5','ratio < 1','ratio < 1.5','ratio < 2'])assert(calculation.includes(boundary));
assert(calculation.includes('math.min(1, ratio / 2)'));
for(const color of ['FF6EA66F','FFE59A36','FFFF4040'])assert(calculation.includes(color));
assert(view.includes('watch(DB.getPath(node, "attributes.fue.effective"), event)'));
assert(view.includes('load_fill.setBackColor(status.color)'));
assert(view.includes('280 - fillHeight'));
assert(test.includes('for strength=0,4 do') && test.includes('find(view,a).content_load==6'));
console.log('OK estático: capacidad desde FUE efectiva, cinco estados, barra saturada, actualizaciones DB y almacenaje sin encadenamiento.');

const xml=read('campaign/record_char_equipment_aptus.xml');
assert(xml.includes('<bounds>543,100,7,180</bounds>'));
assert(xml.includes('<bounds>536,310,95,32</bounds>'));
assert(view.includes('DB.removeHandler(handler.path, handler.event, refreshPreview)'));
assert(!/DB\.(setValue|createChild|deleteNode)/.test(view.slice(view.indexOf('function refreshPreview()'))));

const graphics=read('graphics/graphics_aptus_char_equipment.xml');
for(const [dir,sex] of [['hombre','male'],['Mujer','female']])for(const n of [0,50,100,150,200]){
 const path='graphics/themes/lane/auxiliary/icons/Carga/'+dir+'/carga_skins_'+n+'.png';
 assert(graphics.includes('name="aptus_load_'+sex+'_'+n+'" file="'+path+'"'));
 const png=fs.readFileSync(path);assert.equal(png.readUInt32BE(16),70);assert.equal(png.readUInt32BE(20),110);
}
assert(xml.includes('<bounds>554,165,70,110</bounds>'));
assert(xml.includes('<bounds>541,189,11,2</bounds>'));
assert(view.includes('watch(DB.getPath(node, "gender"), event)'));
assert(view.includes('load_silhouette.setIcon(status.icon or "")'));
assert(calculation.includes('gender == "femenino" and "female_" or "male_"'));
for(const state of ['LIGERO','CARGADO','SOBRECARGADO','LASTRADO','INMOVILIZADO'])assert(calculation.includes('"'+state+'"'));
console.log('OK estático: cinco estados, diez PNG 70×110, selección por gender, marca 100 % y barra 0–200 %.');

// Consecuencias exclusivamente visuales; no recalculan intervalos ni escriben en DB.
const consequences=view.match(/local tLoadConsequences = \{([\s\S]*?)\n\};/)[1];
const rules={};
for(const m of consequences.matchAll(/(\w+) = \{ ([^}]+) \}/g))rules[m[1]]=[...m[2].matchAll(/"([^"]*)"/g)].map(v=>v[1]);
assert.deepStrictEqual(rules,{SOBRECARGADO:['AGI -1d'],LASTRADO:['AGI -2d','MOV 1/2'],INMOVILIZADO:['AGI -2d','MOV 0']});
assert(!rules.LIGERO && !rules.CARGADO);
assert(view.includes('local consequences = tLoadConsequences[status.state] or {}'));
for(const n of [1,2]) {
 assert(view.includes('load_penalty_'+n+'.setValue(consequences['+n+'] or "")'));
 assert(view.includes('load_penalty_'+n+'.setColor(status.color'));
 const block=xml.match(new RegExp('<stringcontrol name="load_penalty_'+n+'">([\\s\\S]*?)</stringcontrol>'));
 assert(block && block[1].includes('<font>aptus_load_penalty</font>'));
}
const bounds=name=>xml.match(new RegExp('<(?:stringcontrol|genericcontrol) name="'+name+'">\\s*<bounds>([^<]+)</bounds>'))[1].split(',').map(Number);
const one=bounds('load_penalty_1'),two=bounds('load_penalty_2'),silhouette=bounds('load_silhouette'),bar=bounds('load_track');
assert.equal(one[0]+one[2]/2,silhouette[0]+silhouette[2]/2);
assert.equal(two[0]+two[2]/2,silhouette[0]+silhouette[2]/2);
assert(one[1]+one[3]<=two[1] && two[1]+two[3]<=silhouette[1]);
assert(bar[0]+bar[2]<one[0]);
assert.equal(silhouette[1]+silhouette[3],275);
assert(xml.includes('<bounds>547,280,74,30</bounds>'));
assert(!view.includes('Movimiento a la mitad'));
console.log('OK estático: reglas informativas por estado, dos líneas alineadas sobre silueta 70×110, sin solapamientos geométricos y tooltip coherente.');

for(const [name,size] of [['aptus_load_penalty',19],['aptus_load_state',14],['aptus_load_value',24]]){
 const definition=graphics.match(new RegExp('<font name="'+name+'">([\\s\\S]*?)</font>'))[1];
 assert(definition.includes('file="fonts/RobotoCondensed-Regular.ttf"') && definition.includes('size="'+size+'"'));
 assert(definition.includes('#E9D5AF'));
}
const stateBlock=xml.match(/<stringcontrol name="load_hint">([\s\S]*?)<\/stringcontrol>/)[1];
assert(stateBlock.includes('<font>aptus_load_state</font>') && stateBlock.includes('<center />'));
const stateBounds=bounds('load_hint');assert.equal(stateBounds[0]+stateBounds[2]/2,583.5);
assert.equal(stateBounds[1],310);
const valueBlock=xml.match(/<stringcontrol name="load_value">([\s\S]*?)<\/stringcontrol>/)[1];
assert(valueBlock.includes('<font>aptus_load_value</font>') && valueBlock.includes('<center />'));
assert(graphics.match(/<font name="aptus_inventory_text">([\s\S]*?)<\/font>/)[1].includes('size="12"'));
assert.deepStrictEqual(one,[554,111,70,24]);assert.deepStrictEqual(two,[554,137,70,24]);
console.log('OK estático: fuentes locales regulares de 19/24/14 px, estado centrado en 95 px y separación vertical conservada.');

const valueBounds=bounds('load_value');
assert(silhouette[1]+silhouette[3]<=valueBounds[1]);
assert(valueBounds[1]+valueBounds[3]<=stateBounds[1]);
assert.equal(valueBounds[0]+valueBounds[2]/2,584);
assert(stateBounds[1]+stateBounds[3]<=365);

// Métricas TTF reales: avance sin kerning y altura hhea; no simula el rasterizador FGU.
const font=fs.readFileSync('fonts/RobotoCondensed-Regular.ttf'),tables={};
for(let i=0;i<font.readUInt16BE(4);i++){
 const o=12+i*16;tables[font.toString('ascii',o,o+4)]=font.readUInt32BE(o+8);
}
const units=font.readUInt16BE(tables.head+18),metrics=font.readUInt16BE(tables.hhea+34);
let cmap;
for(let i=0;i<font.readUInt16BE(tables.cmap+2);i++){
 const o=tables.cmap+4+i*8,sub=tables.cmap+font.readUInt32BE(o+4);
 if(font.readUInt16BE(sub)===4)cmap=sub;
}
assert(cmap,'Se requiere cmap formato 4 para comprobar estos textos latinos');
const segments=font.readUInt16BE(cmap+6)/2,ends=cmap+14,starts=ends+segments*2+2,deltas=starts+segments*2,ranges=deltas+segments*2;
function textAdvance(text,size){
 let total=0;
 for(const char of text){
  const code=char.charCodeAt(0);let glyph=0;
  for(let i=0;i<segments;i++){
   if(code>font.readUInt16BE(ends+i*2))continue;
   if(code<font.readUInt16BE(starts+i*2))break;
   const range=font.readUInt16BE(ranges+i*2),delta=font.readInt16BE(deltas+i*2);
   glyph=range?font.readUInt16BE(ranges+i*2+range+2*(code-font.readUInt16BE(starts+i*2))):code;
   if(glyph||!range)glyph=(glyph+delta)&65535;
   break;
  }
  assert(glyph,'Glifo ausente: '+char);
  total+=font.readUInt16BE(tables.hmtx+Math.min(glyph,metrics-1)*4);
 }
 return total*size/units;
}
for(const [text,size,box] of [['AGI -2d',19,one],['MOV 1/2',19,two],['22 / 6',24,valueBounds],['SOBRECARGADO',14,stateBounds],['INMOVILIZADO',14,stateBounds]]){
 const width=textAdvance(text,size);
 const lineHeight=(font.readInt16BE(tables.hhea+4)-font.readInt16BE(tables.hhea+6)+font.readInt16BE(tables.hhea+8))*size/units;
 assert(Math.ceil(width)<=box[2],text+' excede el ancho');
 assert(Math.ceil(lineHeight)<=box[3],text+' excede el alto');
 console.log(text+': avance '+width.toFixed(2)+' / '+box[2]+' px, altura '+lineHeight.toFixed(2)+' / '+box[3]+' px');
}

// Centros exactos de las tres marcas, desde abajo sobre los 180 px útiles.
for(const [name,fraction] of [['load_half_capacity_mark',0.25],['load_capacity_mark',0.5],['load_one_half_capacity_mark',0.75]]){
 const mark=bounds(name);
 assert.equal(mark[0]+mark[2]/2,bar[0]+bar[2]/2);
 assert.deepStrictEqual(mark.slice(2),[11,2]);
 assert.equal((bar[1]+bar[3]-(mark[1]+mark[3]/2))/bar[3],fraction);
 const control=xml.match(new RegExp('<genericcontrol name="'+name+'">([\\s\\S]*?)</genericcontrol>'))[1];
 assert(control.includes('<backcolor>FFE9D5AF</backcolor>'));
 assert(!/<invisible|<string|<static/.test(control));
 assert(!view.includes(name+'.setVisible'));
 assert(xml.indexOf('name="'+name+'"')>xml.indexOf('name="load_fill"'),'Marcas declaradas sobre el relleno');
}
assert.equal((xml.match(/name="load_(?:half_capacity|one_half_capacity|capacity)_mark"/g)||[]).length,3);
console.log('OK estático: tres marcas 11×2 beige centradas al 25/50/75 % desde abajo, después del relleno, sin condiciones de visibilidad.');

// Comprobación estática de la composición local; no ejecuta FGU.
const fs=require('fs'),assert=require('assert');
const xml=fs.readFileSync('campaign/inventory_quantity_aptus.xml','utf8');
assert.equal((xml.match(/<windowclass /g)||[]).length,1);
assert(xml.includes('<frame>aptus_lane_aux_recordsheet</frame>'));
assert(xml.includes('<size width="400" height="180" />'));
assert(xml.includes('<windowtitlebar_utilitybox name="title">'));
assert(xml.includes('<static>MODIFICAR CANTIDAD</static>'));
assert(xml.includes('<windowmenubar_utilitybox name="menubar" />'));
assert(xml.includes('<windowmenu><simple /></windowmenu>'));
assert(xml.includes('file="scripts/inventory_quantity_aptus.lua"'));
assert(xml.includes('name="aptus_lane_aux_groupbox"'));
const control=name=>xml.match(new RegExp('<([\\w_]+) name="'+name+'">([\\s\\S]*?)</\\1>'))?.[2];
const bounds=name=>{const match=control(name)?.match(/<bounds>([\d,]+)<\/bounds>/);assert(match,name);return match[1].split(',').map(Number);};
const [px,py,pw,ph]=bounds('content_panel');
assert.deepEqual(bounds('caption'),[36,49,328,32]);
assert.deepEqual(bounds('quantity'),[px+(pw-100)/2,80,100,22]);
for(const name of ['caption','quantity','problem']){
 const [x,y,w,h]=bounds(name);assert(x>px&&y>py&&x+w<px+pw&&y+h<py+ph,name);
}
for(const name of ['accept','cancel']){
 const [x,y,w,h]=bounds(name);assert(y>=py+ph&&x>=0&&x+w<=400&&y+h<=180,name);
 assert.deepEqual(bounds(name),bounds(name+'_art'));
 assert(control(name).includes('<font>aptus_equipment_compact</font>'));
 assert(control(name+'_art').includes('<icon>aptus_equipment_button_secondary</icon>'));
}
assert(bounds('accept')[0]+bounds('accept')[2]<bounds('cancel')[0]);
assert(control('accept').includes('window.confirm()'));
assert(control('cancel').includes('window.close()'));
assert(!/DB\.|callback|setValue|confirm\s*\(\)\s*[;\n]/.test(xml.replace(/window\.confirm\(\);/g,'')));
const stack=[];
for(const tag of xml.replace(/<\?[\s\S]*?\?>|<!--[\s\S]*?-->/g,'').match(/<[^>]*>/g)||[]){
 const name=tag.match(/^<\/?([\w.-]+)/)?.[1];assert(name);
 if(tag.startsWith('</'))assert.equal(stack.pop(),name);else if(!tag.endsWith('/>'))stack.push(name);
}assert.equal(stack.length,0);
const lane=fs.readFileSync('graphics/graphics_aptus_lane.xml','utf8');
assert(lane.includes('name="aptus_lane_aux_recordsheet"')&&lane.includes('name="aptus_lane_aux_groupbox"'));
const titleFrame=lane.match(/<framedef name="aptus_lane_aux_windowtitle">([\s\S]*?)<\/framedef>/)?.[1];
assert(titleFrame);
assert(titleFrame.includes('<bitmap file="graphics/themes/lane/auxiliary/frames/recordsheet_title.png" />'));
assert(titleFrame.includes('<offset>40,37,40,0</offset>'));
assert(control('title').includes('<frame merge="replace" name="aptus_lane_aux_windowtitle" offset="30,0,30,0" />'));
assert(!control('title').includes('<script'));
assert(control('title').includes('<anchored height="37" />'));
assert.equal((control('title').match(/<anchored/g)||[]).length,1);
assert(!lane.includes('<framedef name="windowtitle">'));
const png=fs.readFileSync('graphics/themes/lane/auxiliary/frames/recordsheet_title.png');
assert.equal(png.subarray(0,8).toString('hex'),'89504e470d0a1a0a');
assert.equal(png.readUInt32BE(16),150);assert.equal(png.readUInt32BE(20),37);
const consumers=[];
for(const name of fs.readdirSync('campaign').filter(name=>name.endsWith('.xml'))){
 if(fs.readFileSync('campaign/'+name,'utf8').includes('aptus_lane_aux_windowtitle'))consumers.push(name);
}
assert.deepEqual(consumers.sort(),['inventory_location_aptus.xml','inventory_quantity_aptus.xml','inventory_state_aptus.xml']);
const graphics=fs.readFileSync('graphics/graphics_aptus_equipment.xml','utf8');
assert(graphics.includes('name="aptus_equipment_button_secondary"'));
const core=fs.readFileSync('/references/corerpg/common/template_windows.xml','utf8');
assert(core.includes('name="windowtitlebar_utilitybox"')&&core.includes('name="windowmenubar_utilitybox"'));
assert(core.includes('height="30"'));
console.log('OK estático: ventana local 400×180, título/cierre nativos, panel LANE, controles dentro del panel y botones legibles fuera; eventos originales conservados.');
console.log('OK estático: prueba local de altura 37 px, PNG 150×37, frame 40/37/40/0 y márgenes 30/0/30/0 conservados; renderizado pendiente en FGU.');

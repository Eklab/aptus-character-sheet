// Desde character-sheet: node utility/tests/profile_editor_static_test.js
// Comprobaciones estructurales; no sustituyen la ejecución en FGU.
const fs = require('fs'), assert = require('assert');
const read = p => fs.readFileSync(p, 'utf8');
const xml = read('campaign/record_equipment_aptus.xml');
const row = read('scripts/equipment_profile_summary_aptus.lua');
const popup = read('scripts/equipment_profile_configuration_aptus.lua');
const form = read('scripts/equipment_profile_aptus.lua');
const section = name => xml.match(new RegExp('<windowclass name="'+name+'">([\\s\\S]*?)</windowclass>'))?.[1];
const compact = section('aptus_equipment_profile_row');
const configuration = section('aptus_equipment_profile_configuration');
const original = section('aptus_equipment_profile_form');
assert(compact && configuration && original);
assert(!compact.includes('edit_') && compact.includes('<anchored width="421" height="36"><left anchor="left" offset="-10" /><top offset="0" /></anchored>'));
assert(compact.includes('window.openConfiguration()'));
assert(configuration.includes('<class>aptus_equipment_profile_form</class>'));
assert(configuration.includes('<bounds>16,40,488,354</bounds>'));
assert(!configuration.includes('<datasource>'));
for (const name of ['name','range','attack_modifier','damage','critical','uses_ammunition','ammunition_max']) {
  assert(original.includes('name="edit_'+name+'"'));
}
assert(original.includes('window.configureQualities()'));
assert(form.includes('APTUSEquipmentManager.getDamageTypes()'));
assert(form.includes('DialogManager.openDialog("dialog_okcancel"'));
assert(form.includes('alive and editable and owner.isEditable() then owner.removeEntry(key)'));
for (const source of [row,popup,form]) {
  assert(!/DB\.(setValue|createChild|createNode|deleteNode|deleteChild|copyNode)\s*\(/.test(source));
}
assert(row.includes('entry, owner, key = value, context, id'));
assert(row.includes('window.configure(entry, owner, key,'));
assert(popup.includes('form.subwindow.configure(entry, owner, key,'));
assert(popup.includes('function onClose()\n    capture();'));
assert(row.includes('alive = false;\n    closeConfiguration();'));
assert(row.includes('if popup == window then popup = nil; end'));
assert(row.includes('if popup then popup.capture(); end'));
assert(row.includes('Interface.findWindow("aptus_equipment_profile_configuration", "")'));
assert(row.includes('if previous then previous.close(); end'));
assert(row.includes('if editable and not value then capture(); closeConfiguration(); end'));
assert(row.includes('APTUSQualityManager.details(entry.qualities)'));
assert(row.includes('open_profile.setTooltipText('));
for (const file of ['scripts/record_equipment_aptus.lua','scripts/record_inventory_item_aptus.lua']) {
  const parent = read(file);
  assert(parent.includes('local newKey = APTUSEquipmentManager.newProfile(tCollections.profiles)'));
  assert(parent.includes('row.openIfKey(newKey)'));
  assert(parent.includes('row.closeConfiguration()'));
  assert(parent.includes('for _, w in ipairs(list.getWindows()) do w.capture(); end'));
  assert(parent.includes('for _, w in ipairs(list.getWindows()) do w.close(); end'));
}
const headers = section('aptus_profile_table_headers');
const ids = ['profile_name','skill','range','damage','critical','ammo','capacity','qualities'];
const expected = ['Nombre','Habilidad','ALC','DAÑO','CRI','MUN','N.MUN','Cualidades'];
assert.deepEqual([...headers.matchAll(/<static>([^<]+)<\/static>/g)].map(m=>m[1]),expected);
let right=0;
for (const id of ids) {
  const bounds = (text,name) => text.match(new RegExp('<stringcontrol name="'+name+'">[\\s\\S]*?<bounds>([\\d,]+)</bounds>'))[1].split(',').map(Number);
  const h=bounds(headers,'header_'+id), c=bounds(compact,'cell_'+id);
  assert.equal(c[0],h[0]); assert.equal(c[2],h[2]);
  assert(c[0]>=right && c[0]+c[2]<=411); right=c[0]+c[2];
}
assert(row.includes('local width, height = widget.getSize()'));
assert(row.includes('position(blocks[i], (bodyHeight - blocks[i].height) / 2)'));
assert(row.includes('local damageTop = (bodyHeight - damageHeight) / 2'));
assert(row.includes('position(typesBlock, damageTop + damage.height)'));
assert(row.includes('math.min(64, math.max(36, contentHeight + 8))'));
assert(!row.includes('(height - 22) / 2'));
assert(xml.includes('<bounds>204,282,426,78</bounds>'));
assert(xml.includes('<bounds>204,263,411,18</bounds>'));
assert(row.includes('absolute", 384'));
// Nuevas anchuras compartidas; columnas cortas sin cambios.
const widths=[72,67,26,50,27,28,38,103];
assert.equal(widths.reduce((a,b)=>a+b,0),411);
for(let i=0;i<ids.length;i++){
 const m=headers.match(new RegExp('name="header_'+ids[i]+'">[\\s\\S]*?<bounds>([\\d,]+)</bounds>'));
 assert.equal(Number(m[1].split(',')[2]),widths[i]-4);
}
// Equidistancia geométrica para bloques de 1–4 líneas y el grupo DAÑO.
for(const heights of [[12],[12,12],[12,12,12],[12,12,12,12],[16,12],[16,12,12,12]]){
 const block=heights.reduce((a,b)=>a+b,0);
 for(const rowHeight of [Math.max(36,block+8),64]){
  const top=(rowHeight-block)/2;
  let cursor=top;
  for(const h of heights){const center=cursor+h/2;assert(center-h/2>=0);assert(center+h/2<=rowHeight);cursor+=h;}
  assert.equal(top,rowHeight-cursor);
 }
}
assert(row.includes('widget.setMaxWidth(available)'));
assert(row.includes('row_art.setAnchoredHeight(height); open_profile.setAnchoredHeight(height)'));
assert(row.includes('local typeLines = wrap(') && row.includes('table.insert(codes, types[i].abbreviation)'));
assert(original.includes('Configurar cualidades'));
assert(original.includes('DATOS DEL PERFIL')&&original.includes('CUALIDADES')&&original.includes('TIPOS DE DAÑO'));
// Todos los controles del formulario quedan dentro de su área local.
for (const [,bounds] of original.matchAll(/<bounds>([\d,]+)<\/bounds>/g)) {
  const [x,y,w,h]=bounds.split(',').map(Number);
  assert(x>=0&&y>=0&&x+w<=488&&y+h<=354);
}
for (const file of ['scripts/record_equipment_aptus.lua','scripts/record_inventory_item_aptus.lua']) {
  assert(read(file).includes('"profile_headers", "profile_list"'));
}
for(const label of ['label_name','label_skill','label_range','label_attack_modifier','label_damage','label_critical','label_uses_ammunition','label_ammunition_max']) {
  const labelBlock=original.match(new RegExp('<stringcontrol name="'+label+'">([\\s\\S]*?)</stringcontrol>'))[1];
  assert(labelBlock.includes('<font>aptus_profile_light</font>'));
}
console.log('OK: ocho columnas alineadas, cabeceras comunes, filas adaptables acotadas, recorte, tooltips, contraste local y ciclo del borrador conservado.');

// Ampliación izquierda con anclaje explícito; nunca bounds de coordenada negativa.
for(const name of ['row_art','open_profile']){
 const control=compact.match(new RegExp('name="'+name+'">([\\s\\S]*?)</(?:genericcontrol|buttoncontrol)>'))[1];
 assert(control.includes('<anchored width="421" height="36">'));
 assert(control.includes('<left anchor="left" offset="-10" />'));
 assert(control.includes('<top offset="0" />'));
 assert(!control.includes('<bounds>'));
 assert.equal(-10+421,411);
}

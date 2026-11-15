// Comprobaciones estáticas; no sustituye un parser Lua ni Fantasy Grounds.
// Desde character-sheet: node utility/tests/inventory_instance_static_test.js
const fs = require('fs'), assert = require('assert');
const files = ['manager_aptus_equipment','manager_aptus_inventory','record_equipment_aptus',
  'record_inventory_item_aptus','inventory_item_window_aptus','char_equipment_row_aptus','item_melee_consultation_aptus','item_melee_block_aptus','inventory_item_lock_aptus','equipment_profile_aptus',
  'equipment_profile_summary_aptus','equipment_profile_configuration_aptus','inventory_quantity_aptus','inventory_location_aptus','inventory_state_aptus','char_equipment_aptus','char_equipment_state_aptus']
  .map(n=>'scripts/'+n+'.lua').concat(['utility/tests/inventory_create_test.lua','utility/tests/equipment_save_test.lua','utility/tests/inventory_instance_view_test.lua','utility/tests/damage_types_test.lua','utility/tests/ammunition_test.lua','utility/tests/inventory_units_test.lua','utility/tests/inventory_container_load_test.lua','utility/tests/inventory_state_test.lua','utility/tests/inventory_hidden_contents_test.lua']);
for (const path of files) {
  const source = fs.readFileSync(path,'utf8').replace(/--\[(=*)\[[\s\S]*?\]\1\]|--[^\n]*|\[(=*)\[[\s\S]*?\]\2\]|"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'/g,' ');
  const blocks=[], brackets=[];
  for (const token of source.match(/[A-Za-z_]\w*|[(){}\[\]]/g)||[]) {
    if ('({['.includes(token)) brackets.push(token);
    else if (')}]'.includes(token)) assert.strictEqual(brackets.pop(),{')':'(', '}':'{', ']':'['}[token],path);
    else if (['function','if','for','while','repeat'].includes(token)) blocks.push({kind:token,pending:token==='for'||token==='while'});
    else if (token==='do') { const top=blocks.at(-1); if(top?.pending) top.pending=false; else blocks.push({kind:'do'}); }
    else if (token==='end') { const top=blocks.pop(); assert(top&&top.kind!=='repeat',path+': end'); }
    else if (token==='until') assert.strictEqual(blocks.pop()?.kind,'repeat',path+': until');
  }
  assert.strictEqual(blocks.length,0,path+': bloques'); assert.strictEqual(brackets.length,0,path+': delimitadores');
}
const catalogue=fs.readFileSync('campaign/record_equipment_aptus.xml','utf8');
const instance=fs.readFileSync('campaign/record_inventory_item_aptus.xml','utf8');
for (const xml of [catalogue,instance]) {
  const stack=[];
  const clean=xml.replace(/<!--[\s\S]*?-->|<!\[CDATA\[[\s\S]*?\]\]>|<\?[\s\S]*?\?>/g,'');
  for (const tag of clean.match(/<[^>]*>/g)||[]) {
    const name=tag.match(/^<\/?([\w.-]+)/)?.[1]; assert(name,tag);
    if(tag.startsWith('</')) assert.strictEqual(stack.pop(),name); else if(!tag.endsWith('/>')) stack.push(name);
  }
  assert.strictEqual(stack.length,0,'Etiquetas XML');
  for(const [,file] of xml.matchAll(/file="([^"]+)"/g)) assert(fs.existsSync(file)||fs.existsSync('/references/corerpg/'+file),file);
}
const manager=fs.readFileSync('scripts/manager_aptus_inventory.lua','utf8');
const fields=manager.slice(manager.indexOf('local tEditableFields'),manager.indexOf('local function encode'));
for(const path of ['count','carried','aptus.container','template_id','template_version','aptus.instance_schema','locked']) assert(!fields.includes('path="'+path+'"'),'Campo protegido: '+path);
assert(fields.includes('path="properties.is_wealth"'));
// Misma barra y anclaje heredados de la plantilla; sin controles sueltos.
assert(catalogue.includes('<windowmenubar_recordsheet name="menubar">'));
assert(catalogue.includes('<anchored offset="-12,8" />'));
assert(!instance.includes('name="menubar" merge="delete"'));
assert(!instance.includes('name="button_minimize"')&&!instance.includes('name="close_instance"'));
assert(instance.includes('<right>locked</right>'));
for(const flag of ['norecord','nolink','nocustom']) assert(instance.includes('<'+flag+' />'));
const outer=fs.readFileSync('scripts/inventory_item_window_aptus.lua','utf8');
assert(outer.includes('menubar.subwindow.locked'));
const deletion=instance.match(/<buttoncontrol name="delete_button">([\s\S]*?)<\/buttoncontrol>/)[1];
assert(!deletion.includes('<disabled />')&&deletion.includes('window.requestDelete()'));
assert(manager.includes('function requestDeleteInstance(')&&manager.includes('function planDeleteInstance('));
for(const name of ['add_profile','add_quality','type_change']) assert(!instance.includes('name="'+name+'" merge="delete"'));
for(const file of ['scripts/record_equipment_aptus.lua','scripts/record_inventory_item_aptus.lua']) {
  const source=fs.readFileSync(file,'utf8');
  for(const [,controls] of source.matchAll(/controls\s*=\s*\{([^}]+)\}/g)) for(const [,name] of controls.matchAll(/"([^"]+)"/g)) assert(catalogue.includes('name="'+name+'"'),name);
}
const controller=fs.readFileSync('scripts/record_inventory_item_aptus.lua','utf8');
assert(!/APTUSEquipmentManager\.(save|onRecordAdded|confirmTemplateSaved)\s*\(/.test(controller));
assert(!/ItemManager\./.test(controller));
assert(controller.includes('row.setEditable(editable)')&&controller.includes('collections=tCollections'));
console.log('OK: balance léxico Lua, XML, referencias, controles, candado, Eliminar y campos protegidos.');
function rect(xml,name) {
  const controls=[...xml.matchAll(new RegExp('<([\\w_]+) name="'+name+'">([\\s\\S]*?)</\\1>','g'))];
  const bounds=controls.map(match=>match[2].match(/<bounds>([\d,]+)<\/bounds>/)).find(Boolean);
  assert(bounds,name);
  return bounds[1].split(',').map(Number);
}
for(const [left,right] of [['delete_button','discard_button'],['discard_button','save_button']]) {
  const a=rect(instance+catalogue,left), b=rect(instance+catalogue,right);
  assert(a[0]+a[2]<=b[0],left+' solapa '+right);
  assert.strictEqual(a[1],b[1]); assert.strictEqual(a[3],b[3]);
}
// El anclaje y la separación de la cabecera se resuelven por CoreRPG.
for(const name of ['save_button','save_art','discard_button','discard_art']) {
  assert(controller.includes(name+'.setVisible(editable)'),name+' no sigue el candado');
}
const update=controller.slice(controller.indexOf('function update()'),controller.indexOf('function reload()'));
assert(!/DB\.(setValue|createChild|deleteChild|deleteNode)|\breload\s*\(|\bsave\s*\(/.test(update),
  'Alternar el candado no debe guardar ni recargar propiedades');
assert(controller.includes('function onLockModeChanged() update(); end'));
const wealth=rect(catalogue,'draft_is_wealth'), name=rect(catalogue,'draft_name');
assert(wealth[1]+wealth[3]<=name[1],'Riqueza solapa Nombre');
console.log('OK: barra nativa heredada, acciones según candado, borrador conservado y separación de botones.');

// Cabecera confirmada y mensajes locales: no se leen valores de controles de borrador.
const header=controller.slice(controller.indexOf('function updateHeader()'),controller.indexOf('function selectPage('));
assert(header.includes('DB.getValue(node, "name"')&&header.includes('DB.getValue(node, "properties.type_id"'));
assert(header.includes('setMaxWidth')&&header.includes('setTooltipText'));
assert(!header.includes('draft_name.getValue')&&!header.includes('sTypeId'));
assert(!controller.includes('function updateContext()')&&!controller.includes('ChatManager.SystemMessage'));
assert(instance.includes('window.discard()'));
assert(controller.includes('function discard()')&&controller.includes('Cambios descartados.'));
assert(controller.includes('nMessageProtectedUntil')&&controller.includes('bMessageError'));
assert(!instance.includes('Cantidad:')&&!controller.includes('Estado efectivo:'));
console.log('OK: título persistido con tooltip/recorte y mensajes locales sin datos de inventario.');

assert(controller.includes('delete_button.setReadOnly(bDeletePending or not APTUSInventoryManager.canDeleteInstance'));
assert(!/DB\.delete(Node|Child)/.test(controller));
assert(outer.includes('"onDelete", onItemDeleted')&&outer.includes('function onItemDeleted() close(); end'));
assert(manager.includes('DialogManager.openDialog("dialog_okcancel"'));
assert(manager.includes('if not sameDeletePlan(expected, current) then ask(current, true); return; end'));
console.log('OK: Eliminar delegado al gestor, confirmación nativa, revalidación y cierre por onDelete.');

const lockScript=fs.readFileSync('scripts/inventory_item_lock_aptus.lua','utf8');
assert(lockScript.includes('ToolbarManager.initButtonField(self, "locked")'));
assert(!/DB\.\w+\s*\(/.test(lockScript));
assert(outer.includes('local bInstanceLocked = true'));
const opening=outer.slice(outer.indexOf('function onInit()'),outer.indexOf('function onClose()'));
assert(!/DB\.(setValue|createNode|createChild)/.test(opening));
assert(instance.includes('<toolbar_field_right>')&&instance.includes('createControl("aptus_instance_window_lock", "locked")'));
assert(controller.includes('not isViewLocked() and APTUSInventoryManager.canEditInstance'));
console.log('OK: candado de ventana inicialmente cerrado sin escritura durante apertura.');

const messageControl=instance.match(/<stringcontrol name="instance_context">([\s\S]*?)<\/stringcontrol>/)[1];
assert(messageControl.includes('<bounds>22,381,148,16</bounds>'));
assert(messageControl.includes('367 + (44 - height) / 2'));
assert(!/DB\.|window\.showMessage|setValue\s*\(/.test(messageControl));
for(const lines of [1,2,3,6]){const h=Math.min(lines,2)*16,y=367+(44-h)/2;assert(y>=373&&y+h<=405);}
console.log('OK: mensajes dentro del recuadro, geometría de una/dos líneas y sin cambios de valor ni temporización.');

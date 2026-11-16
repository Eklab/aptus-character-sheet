// Desde Character Sheet: node utility/tests/inventory_location_static_test.js
// No ejecuta Lua ni simula el motor de FGU.
const fs=require('fs'),assert=require('assert'),read=p=>fs.readFileSync(p,'utf8');
const xml=read('campaign/record_char_equipment_aptus.xml');
const row=read('scripts/char_equipment_row_aptus.lua');
const manager=read('scripts/manager_aptus_inventory.lua');
const options=manager.slice(manager.indexOf('function getLocationOptions('),manager.indexOf('function requestLocation('));
const request=manager.slice(manager.indexOf('function requestLocation('));
assert(options.includes('destination(character, item.node, node, context) ~= nil'));
assert(options.includes('getCharacterInventory(character, context)'));
assert(options.includes('Raíz del inventario'));
assert(options.includes('table.concat(parts, " / ")'));
assert(request.includes('window.requestSelectionByData(selection)'));
assert(request.includes('getInstanceEditToken(node) ~= expected'));
assert(request.includes('getInstanceCharacter(parent) ~= character'));
assert(request.includes('link.linkrecord == DB.getPath(character)'));
assert(request.includes('transfer(node, character, nil, parent, nil, context)'));
assert(!/DB\.(setValue|createNode|createChild|deleteChild|deleteNode)/.test(options+request));
for(const [name,bounds] of [['location_selector','285,4,116,15'],['location','295,2,93,20']]){
 const body=xml.match(new RegExp('<([\\w_]+) name="'+name+'">([\\s\\S]*?)</\\1>'))[2];
 assert(body.includes('<bounds>'+bounds+'</bounds>'));
 assert(body.includes('window.chooseLocation()'));
 assert(!body.includes('<disabled'));
}
assert(xml.includes('<icon>aptus_equipo_selector</icon>'));
assert(row.includes('APTUSInventoryManager.requestLocation(node,'));
assert(viewRefreshBatch());
function viewRefreshBatch(){
 const view=read('scripts/char_equipment_aptus.lua');
 return view.includes('if APTUSInventoryManager.isUpdatingInventory() then bRefreshPending = true; return; end') && view.includes('addOperationListener(flushInventoryRefresh)');
}
const test=read('utility/tests/inventory_units_test.lua');
assert(test.includes('m.getLocationOptions(')&&test.includes('m.requestLocation('));
assert(test.includes('Miguel García')&&test.includes('==120'));
assert(test.includes('beforeCycle')&&test.includes('beforeStale'));
console.log('OK estático: selector nativo, geometría intacta, validación común, mismo personaje, callback obsoleto protegido y movimientos delegados sin escrituras directas.');

const location=read('campaign/inventory_location_aptus.xml');
assert(read('extension.xml').includes('source="campaign/inventory_location_aptus.xml"'));
assert(location.includes('name="aptus_inventory_location" copy="select_dialog"'));
assert(location.includes('name="aptus_inventory_location_entry" copy="select_dialog_entry"'));
assert(location.includes('<frame merge="replace">aptus_lane_aux_recordsheet</frame>'));
assert(location.includes('name="aptus_lane_aux_windowtitle" offset="30,0,30,0"'));
assert(location.includes('<anchored height="37" />'));
assert(location.includes('<static>UBICACIÓN DEL OBJETO</static>'));
for(const name of ['text','list']){
 const body=location.match(new RegExp('<(?:stringc_content_framed_groupbox_top|list_content_framed_groupbox) name="'+name+'">([\\s\\S]*?)</(?:stringc_content_framed_groupbox_top|list_content_framed_groupbox)>'))[1];
 assert(body.includes('<frame merge="delete" />'));
}
assert(location.includes('super.onValueChanged();'));
assert(location.includes('setTooltipText(getValue())'));
assert(location.includes('"FFFFFFFF" or "FFE9D5AF"'));
assert(!/DB\.(setValue|createChild|deleteNode)/.test(location));
assert(!location.includes('<placement>') && !location.includes('utility/scripts/dialog_select.lua'));
console.log('OK estático: variante local LANE sin paneles blancos; selección, enlaces, botones y tamaño nativos heredados; rutas con tooltip y resaltado local.');

const stack=[];
for(const tag of location.replace(/<!--[\s\S]*?-->|<\?[\s\S]*?\?>/g,'').match(/<[^>]*>/g)||[]){
 const name=tag.match(/^<\/?([\w.-]+)/)[1];
 if(tag.startsWith('</'))assert.equal(stack.pop(),name);else if(!tag.endsWith('/>'))stack.push(name);
}
assert.equal(stack.length,0,'XML de la ventana local equilibrado');
const native=read('/references/corerpg/utility/utility_dialog_select.xml');
assert(native.includes('<size width="400" height="400" />'));
assert(native.includes('file="utility/scripts/dialog_select.lua"'));
assert(native.includes('<windowmenubar_utilitybox name="menubar" />'));
assert(native.includes('<class>dialog_buttons_okcancel</class>'));
assert(!location.includes('function onClickRelease'), 'Mantener el clic nativo de las filas');

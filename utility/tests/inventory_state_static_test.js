// Estático: no ejecuta Lua ni el motor de Fantasy Grounds.
const fs=require('fs'),assert=require('assert'),read=p=>fs.readFileSync(p,'utf8');
const manager=read('scripts/manager_aptus_inventory.lua'),view=read('scripts/char_equipment_aptus.lua');
const row=read('scripts/char_equipment_row_aptus.lua'),indicator=read('scripts/char_equipment_state_aptus.lua');
const xml=read('campaign/inventory_state_aptus.xml'),dialog=read('scripts/inventory_state_aptus.lua');
assert(read('extension.xml').includes('source="campaign/inventory_state_aptus.xml"'));
assert(manager.includes('[0] = "Sin equipar", [1] = "Transportado", [2] = "Equipado"'));
assert(manager.includes('item.effective_carried = item.parent_id == "" and item.carried or 0'));
assert(manager.includes('item.state = item.parent_id == "" and tStates[item.carried] or "Contenido"'));
assert(manager.includes('if item.carried ~= 0 then'));
assert(manager.includes('accumulated[parent.id] = accumulated[parent.id] + gross'));
assert(manager.includes('item.reduction_active = item.is_container and item.parent_id == ""'));
assert(manager.includes('signature(a, carried) == signature(b)'));
assert(manager.includes('snapshot.carried = {kind="number", value=targetCarried}'));
assert(manager.includes('return transfer(node, getInstanceCharacter(node), nil, nil, carried, context)'));
assert(manager.includes('if containerId(node) ~= "" and carried == 0 then return node; end'));
assert(manager.includes('elseif containerId(node) ~= "" then targetCarried = 1'));
assert(manager.includes('if parentId ~= "" then targetCarried = 0'));
assert(manager.includes('getInstanceEditToken(node) ~= expected'));
assert(manager.includes('if change.count ~= change.old then'));
assert(manager.includes('Estado anterior no restaurado')&&manager.includes('Restauración no verificada'));
assert(row.includes('APTUSInventoryManager.requestState(node,'));
assert(indicator.includes('window.chooseState()')&&!indicator.includes('cycleValue'));
assert(indicator.includes('sValue == "Sin equipar" or sValue == "Contenido"'));
assert(!/DB\./.test(indicator+dialog));
assert(!/<datasource|<source|<field\b/.test(xml));
assert(xml.includes('<size width="400" height="180" />'));
assert(xml.includes('aptus_lane_aux_recordsheet')&&xml.includes('aptus_lane_aux_windowtitle'));
assert(xml.includes('<windowmenubar_utilitybox name="menubar" />'));
for(const [state,label] of [[2,'Equipado'],[1,'Transportado'],[0,'Sin equipar']]){
 assert(xml.includes('window.selectState('+state+')'));
 assert(xml.includes('<state text="'+label+'" />'));
 assert(xml.includes('name="current_'+state+'"'));
}
assert.equal((xml.match(/<buttoncontrol /g)||[]).length,3);
assert(xml.includes('aptus_equipo_equipada')&&xml.includes('aptus_equipo_transportado'));
assert(dialog.indexOf('apply = nil;')<dialog.indexOf('if callback then callback(value); end'));
const stack=[];
for(const tag of xml.replace(/<\?[\s\S]*?\?>|<!--[\s\S]*?-->/g,'').match(/<[^>]*>/g)||[]){
 const name=tag.match(/^<\/?([\w.-]+)/)[1];
 if(tag.startsWith('</'))assert.equal(stack.pop(),name);else if(!tag.endsWith('/>'))stack.push(name);
}
assert.equal(stack.length,0);
assert(view.includes('if APTUSInventoryManager.isUpdatingInventory() then bRefreshPending = true; return; end'));
assert(view.includes('addOperationListener(flushInventoryRefresh)')&&view.includes('removeOperationListener(flushInventoryRefresh)'));
assert(manager.includes('pcall(callback)'));
assert(!row.includes('if refresh then refresh(); end'));
assert(read('utility/tests/inventory_create_test.lua').includes('loadfile("utility/tests/inventory_state_test.lua")'));
console.log('OK estático: selección directa LANE, carried 0/1/2, contenidos con guion, carga sólo de raíces activas, traslado/estado coordinados, rollback y refresco agrupado.');

assert(dialog.includes('function onClose() apply = nil; end'));
assert(!read('extension.xml').includes('utility/tests/inventory_state_test.lua'));

// Regresión FGU: setValue() nativo rechaza nombres no incluidos en <values>.
const inventoryXML=read('campaign/record_char_equipment_aptus.xml');
const stateControl=inventoryXML.match(/<button_iconcycler name="state">([\s\S]*?)<\/button_iconcycler>/)[1];
const labels=stateControl.match(/<labels>([^<]+)<\/labels>/)[1].split('|');
const values=stateControl.match(/<values>([^<]+)<\/values>/)[1].split('|');
assert.deepStrictEqual(values,['Equipado','Transportado','Sin equipar','Contenido']);
assert.deepStrictEqual(labels,values,'Las etiquetas no sustituyen los valores admitidos por setValue');
assert(stateControl.includes('<bounds>247,0,32,24</bounds>'));
assert(stateControl.includes('<sourceless />')&&!stateControl.includes('<invisible'));
assert(row.includes('state.setValue(tItem.state or "")'));
assert(row.includes('state.setVisible(not bHideState and tItem.state ~= nil)'));
for(const value of ['Equipado','Transportado']){
 const icon=indicator.match(new RegExp(value+' = "([^"]+)"'))[1];
 const graphics=read('graphics/graphics_aptus_char_equipment.xml');
 const path=graphics.match(new RegExp('<icon name="'+icon+'" file="([^"]+)"'))[1];
 assert(fs.existsSync(path),'Icono no disponible: '+path);
}
const native=read('/references/corerpg/common/scripts/control_select_base.lua');
assert(native.includes('if not self.hasValue(sValue) then'));
assert(native.includes('sValue = "";'));
console.log('OK regresión: los cuatro valores de la fila son admitidos por el control nativo; iconos registrados, guion, bounds y visibilidad conservados.');

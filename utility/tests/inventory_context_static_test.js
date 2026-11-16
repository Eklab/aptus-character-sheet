// Fase 2B.1: contratos/guardas. No ejecuta Lua ni FGU.
const fs=require('fs'),assert=require('assert'),read=p=>fs.readFileSync(p,'utf8');
const manager=read('scripts/manager_aptus_inventory.lua'),character=read('scripts/char_container_aptus.lua');
const view=read('scripts/char_equipment_aptus.lua'),row=read('scripts/char_equipment_row_aptus.lua');
const outer=read('scripts/inventory_item_window_aptus.lua'),editor=read('scripts/record_inventory_item_aptus.lua');
for(const field of ['actor_real','actor_effective','character_path','impersonating','isValid'])assert(character.includes(field+'='));
assert(character.includes('inventoryContextRevision = inventoryContextRevision + 1'));
assert(character.includes('inventoryContextRevision == revision'));
assert(character.includes('contextClosed = true'));
assert(character.includes('Session.IsHost == realHost'));
assert(!/Session\.IsHost\s*=(?!=)/.test(character+manager+view+outer+editor));
const context=character.slice(character.indexOf('function getInventoryContext()'),character.indexOf('function refreshStructureViewer()'));
assert(!/DB\.(setValue|setOwner|create|delete)/.test(context));
for(const api of ['canViewInventory','canAccessInventory','canSelectTransferSource','canSelectTransferDestination','canTransfer'])assert(manager.includes('function '+api+'('));
assert(manager.includes('if context and structureOwner(nodeChar) then local _, host = actor(context); if not host then return false; end end'));
assert(manager.includes('if not host and field(parent, "properties.hide_contents", "number") == 1 then return false; end'));
assert(manager.includes('if viewer then local _, host = actor(viewer); item.viewer_is_host = host; end'));
assert(manager.includes('local owner = DB.getOwner(cursor)'));
assert(manager.includes('if owner and owner ~= "" then return owner == user; end'));
assert(manager.includes('not isContextHost(context) and draft.hide_contents ~= storedHidden'));
for(const name of ['saveInstance','setQuantity','removeUnits','mergeStacks','transfer','createFromTemplate','requestLocation','requestState','requestSetQuantity','requestDeleteInstance']){
 assert(new RegExp('function '+name+'\\([^\\n]*context\\)').test(manager),name+' debe aceptar contexto explícito');
}
for(const call of ['requestSetQuantity(node, actionContext())','mergeStacks(node, actionContext())','end, actionContext())'])assert(row.includes(call));
assert(view.includes('not APTUSInventoryManager.isContextValid(actionContext)'));
assert(view.includes('quantity, nil, actionContext)'));
assert(manager.includes('callback=function(selections, selectionContext, links)'),'No sombrear el contexto capturado en Ubicación');
assert(manager.includes('if not isContextValid(context) or DB.findNode(path) ~= node'));
assert(outer.includes('permissionContext = source, context'));
assert(outer.includes('canManageInstance(getDatabaseNode(), permissionContext)'));
assert(outer.includes('canManageCharacter(APTUSInventoryManager.getInstanceCharacter(node), permissionContext)'));
assert(editor.includes('saveInstance(getDatabaseNode(), draft, sExpected, getActionContext())'));
assert(editor.includes('end, getActionContext())'));
assert(view.includes('context and "aptus_inventory_item_consult"'));
assert(view.includes('if not bStructure then refreshPreview(); end'));
assert(manager.includes('Las transferencias entre inventarios de estructuras y otros inventarios quedan pendientes.'));
assert(!view.includes('requestSimpleTransfer('), 'La UI existente no integra todavía transferencias simples');
assert(read('utility/tests/inventory_create_test.lua').includes('loadfile("utility/tests/inventory_context_test.lua")'));
assert(!read('extension.xml').includes('inventory_context_test.lua'));
const test=read('utility/tests/inventory_context_test.lua');
for(const item of ['m.saveInstance','m.setQuantity','m.setState','m.requestLocation','m.requestDeleteInstance','m.requestSetQuantity','m.requestState','m.canTransfer','m.canAccessInventory'])assert(test.includes(item));
assert(test.includes('callback("ok")')&&test.includes('callback(20)'));
console.log('OK estático 2B.1: contexto local con revisión, actores, autorización independiente de edición, guardas de escritura y diálogos, sin OOB ni transferencias nuevas.');

assert(character.includes('context.onInvalidate = function(callback)'));
assert(manager.includes('if Interface.findWindow(class, "") ~= window then return; end'));
assert(manager.includes('if queue[i] == selection then'));
assert(manager.includes('table.remove(queue, i)'));
assert(manager.includes('trackContextDialog(context, window, "aptus_inventory_location", selection)'));

// Sólo estructura/conexiones: no ejecuta Lua ni FGU.
const fs=require('fs'),assert=require('assert'),read=p=>fs.readFileSync(p,'utf8');
const model=read('scripts/manager_aptus_structure.lua'),permissions=read('scripts/manager_aptus_location_permissions.lua');
const inventory=read('scripts/manager_aptus_inventory.lua'),view=read('scripts/char_equipment_aptus.lua');
const config=read('scripts/location_configuration_aptus.lua'),configXML=read('campaign/record_location_permissions_aptus.xml');
const vehicle=read('campaign/record_structure_aptus.xml'),narrative=read('campaign/record_location_aptus.xml');
assert(model.includes('local sRoot = "aptus_structures"'));
assert(model.includes('local sRecordType = "aptus_structure"'));
assert(model.includes('DB.getValue(node, "type", "")'));
assert(!/visible_to_players|resources_access|setVisibleToPlayers|setResourcesAccess/.test(model));
assert(model.includes('APTUSLocationPermissions.hasAccess(node, Session.UserName)'));
assert(model.includes('isFeatureActive(node, "storage")'));
assert(model.includes('return v and getCategory(v) == "locations" and "aptus_location" or sRecordType'));
assert(model.includes('local sClass = sCategory == "locations" and "aptus_structure_type_locations" or "aptus_structure_type_vehicles"'));
assert(permissions.includes('getCategory(node) == "locations" or APTUSStructureManager.getCategory(node) == "vehicles"'));
assert(permissions.includes('local sPrivate = "aptus_location_permissions"'));
for(const tab of ['general','permissions','storage'])assert(configXML.includes('name="tab_'+tab+'"'));
assert(config.includes('features.storage.enabled') && config.includes('isFeatureActive(getDatabaseNode(), "storage")'));
assert(config.includes('tab_storage.setReadOnly(not enabled)'));
assert(config.includes('storage_page.setValue("aptus_structure_inventory", getDatabasePath())'));
assert(vehicle.includes('<class>aptus_location_configuration_content</class>'));
assert(read('campaign/record_structure_inventory_aptus.xml').includes('name="aptus_location_storage" copy="aptus_structure_inventory"'));
assert(!narrative.includes('copy="aptus_structure_inventory"'), 'La copia necesita una base previamente definida');
assert(inventory.includes('function getInventoryOwner(node)'));
assert(inventory.includes('function canManageInventory(nodeChar, context)'));
assert(inventory.includes('initialCarried = structureOwner(nodeChar) and 0 or 1'));
assert(inventory.includes('Las estructuras no utilizan Estado de personaje'));
assert(inventory.includes('not sameCharacter and (structureOwner(character) or structureOwner(getInventoryOwner(node)))'));
assert(inventory.includes('getInstanceCharacter(parent) ~= character'));
assert(inventory.includes('linkclass=structureOwner(character) and "aptus_structure" or "charsheet"'));
assert(view.includes('if not bStructure then\n    local status'));
assert(view.includes('bStructure, self)'));
const xml=read('campaign/record_structure_inventory_aptus.xml');
assert(xml.includes('file="scripts/char_equipment_aptus.lua"'));
assert(xml.includes('copy="aptus_char_equipment_row"'));
assert(!/name="load_(?:track|fill|value|hint|silhouette)|name="heading_state"/.test(xml));
assert(xml.includes('<button_iconcycler name="state"><invisible /></button_iconcycler>'));
assert(!xml.includes('<datasource>'));
assert(read('extension.xml').includes('source="campaign/record_structure_inventory_aptus.xml"'));
// Comprueba XML y referencias reales de todos los archivos de interfaz afectados.
for(const path of ['campaign/record_structure_inventory_aptus.xml','campaign/record_location_permissions_aptus.xml','campaign/record_location_aptus.xml','campaign/record_structure_aptus.xml']){
 const source=read(path),stack=[];
 for(const tag of source.replace(/<!--[\s\S]*?-->|<\?[\s\S]*?\?>/g,'').match(/<[^>]*>/g)||[]){
  const name=tag.match(/^<\/?([\w.-]+)/)[1];
  if(tag.startsWith('</'))assert.equal(stack.pop(),name,path);else if(!tag.endsWith('/>'))stack.push(name);
 }
 assert.equal(stack.length,0,path);
 for(const [,file]of source.matchAll(/file="([^"]+)"/g))assert(fs.existsSync(file)||fs.existsSync('/references/corerpg/'+file));
}
console.log('OK estático: entidades/fichas/permisos preservados, tercera pestaña compartida, motor único, activación original, sin Estado/CARGA ni transferencias nuevas.');

const extension=read('extension.xml');
assert(extension.indexOf('source="campaign/record_char_equipment_aptus.xml"')<extension.indexOf('source="campaign/record_structure_inventory_aptus.xml"'));
assert(xml.indexOf('name="aptus_structure_inventory"')<xml.indexOf('name="aptus_location_storage" copy='));

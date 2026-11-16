// Pruebas estáticas; no ejecutan FGU ni Lua.
const fs=require('fs'),assert=require('assert'),read=p=>fs.readFileSync(p,'utf8');
const top=read('scripts/char_container_aptus.lua'),button=read('scripts/char_structure_preview_button.lua');
const browser=read('scripts/char_equipment_structures_aptus.lua'),model=read('scripts/manager_aptus_structure.lua');
const manager=read('scripts/manager_aptus_inventory.lua'),view=read('scripts/char_equipment_aptus.lua');
const row=read('scripts/char_equipment_row_aptus.lua'),xml=read('campaign/record_char_equipment_structures_aptus.xml');
assert(top.includes('local previewPlayer = false'));
assert(top.includes('DB.getOwner(getDatabaseNode())'));
assert(top.includes('mode="player_preview",username=owner'));
assert(top.includes('mode="player",username=Session.UserName'));
assert(top.includes('DB.addHandler(viewerPath, "onObserverUpdate", refreshStructureViewer)'));
assert(top.includes('DB.removeHandler(viewerPath, "onObserverUpdate", refreshStructureViewer)'));
assert(button.includes('Session.IsHost and owner ~= "" and owner ~= Session.UserName'));
assert(button.includes('Impersonar jugador ('));
assert(button.includes('viewer.mode == "player_preview"'));
assert(!/DB\.(setValue|setOwner|setPublic|addHolder|createChild|deleteNode)/.test(top+button+browser));
assert(!/Session\.IsHost\s*=(?!=)/.test(top+button+browser+model));
assert(model.includes('APTUSLocationPermissions.hasVisibility(node, getViewerUsername(viewer))'));
assert(model.includes('APTUSLocationPermissions.hasAccess(node, getViewerUsername(viewer))'));
assert(model.includes('function getResourceGroups(category, viewer, onlyWithResources)'));
assert(model.includes('getVisibleStructures(category, viewer)'));
assert(model.includes('inventory = APTUSInventoryManager.getViewedInventory(node, viewer)'));
assert(model.includes('if not onlyWithResources or #inventory.items > 0 then'));
assert(model.includes('Almacenaje no disponible.'));
assert(model.includes('Sin acceso a los recursos.'));
assert(!/DB\.(setValue|createChild|deleteNode)/.test(model.slice(model.indexOf('function getResourceGroups'))));
assert(manager.includes('if item.visible_to_user then'));
assert(manager.includes('if key ~= "children" then copy[key] = value; end'));
assert(manager.includes('copy.children = {}'));
assert(manager.includes('if viewer then local _, host = actor(viewer); item.viewer_is_host = host; end'));
assert(view.includes('{"locations", "vehicles"}'));
assert(view.indexOf('for _, root in ipairs(inventory.roots)')<view.indexOf('getResourceGroups(category, viewer, nView == 1)'));
assert(view.includes('if nView == 1 or nView == 2 then'));
assert(view.includes('createWindowWithClass("aptus_structure_inventory_consult_row")'));
assert(view.includes('createWindowWithClass("aptus_inventory_structure_group")'));
assert(view.includes('getCharacterInventory(getDatabaseNode(), getActionContext())'));
assert(view.includes('root .. ".*.inventorylist.*." .. field'));
assert(view.includes('if handler.callback then DB.removeHandler'));
assert(view.includes('preview_scrollbar.setVisible(contentHeight > height)'));
assert(row.includes('nNameLeft = groupBranch and 18 or 0'));
assert(row.includes('elseif groupBranch.following then segment(5, 0, 1, nRowHeight)'));
assert(view.includes('nextRoot=rootIndex<#blocks'));
assert(view.includes('APTUSLocationPermissions.subscribe(refreshPreview)'));
assert(view.includes('APTUSLocationPermissions.unsubscribe(refreshPreview)'));
assert(!view.includes('structure_browser'));
assert(!xml.includes('comboboxc') && !xml.includes('subwindow'));
assert(!read('campaign/record_char_equipment_aptus.xml').includes('structure_browser'));
assert(!/DB\.(setValue|createChild|deleteNode)/.test(browser));
assert(browser.includes('function onDrop() return true; end'));
for(const method of ['onMenuSelection','startInventoryDrag','editQuantity','chooseLocation','chooseState']){
 assert(new RegExp('function '+method+'\\([^\\n]*\\)\\n    if bReadOnly then return false; end').test(row));
}
assert(row.includes('if bReadOnly then return; end\n    registerMenuItem'));
assert(row.includes('showAdmin = Session.IsHost and tItem.viewer_is_host ~= false'));
assert(xml.includes('copy="aptus_char_equipment_row"'));
for(const control of ['location_selector'])assert(xml.includes('name="'+control+'"><invisible /><disabled />'));
assert(xml.includes('name="aptus_inventory_structure_group"'));
assert(!/<datasource>|<stringfield|<numberfield/.test(xml), 'Las cabeceras no tienen campos persistentes');
assert(read('/references/corerpg/desktop/scripts/desktop_dock_category.lua').includes('createWindowWithClass('));
const header=read('campaign/record_char_header_aptus.xml');
assert(header.includes('name="aptus_impersonate_button"'));
const impersonate=header.match(/<buttoncontrol name="aptus_impersonate_button">([\s\S]*?)<\/buttoncontrol>/)[1];
assert(impersonate.includes('<anchored to="header_background" width="51" height="48">'));
assert(impersonate.includes('<right offset="-26" />'));
assert(impersonate.includes('<top offset="53" />'));
assert(header.indexOf('name="header_background"')<header.indexOf('name="aptus_impersonate_button"'));
assert(!/to="aptus_(minimize|close)_button"/.test(impersonate));
assert(header.includes('<bounds>558,0,51,48</bounds>'));
assert(header.includes('<bounds>594,0,51,48</bounds>'));
const impersonateLeft=653-26-51;
assert.equal(impersonateLeft+51/2,((558+51/2)+(594+51/2))/2);
assert.equal(53-48,5, 'Separación vertical sin solapamientos con los CTA superiores');
assert(header.includes('normal="aptus_impersonar_off" pressed="aptus_impersonar_off"'));
assert(button.includes('setIcons(icon, icon)'));
assert(!button.includes('setColor('), 'Los PNG conservan su diseño sin tintado');
for(const state of ['off','on']){
 const icon='aptus_impersonar_'+state,path='graphics/icons/'+icon+'.png';
 assert(read('graphics/graphics_aptus_composition.xml').includes('<icon name="'+icon+'" file="'+path+'" />'));
 assert(button.includes('"'+icon+'"'));
 const png=fs.readFileSync(path);
 assert.equal(png.readUInt32BE(16),51);assert.equal(png.readUInt32BE(20),48);
}
for(const path of ['campaign/record_char_equipment_structures_aptus.xml','campaign/record_char_header_aptus.xml','campaign/record_char_equipment_aptus.xml']){
 const data=read(path),stack=[];
 for(const tag of data.replace(/<!--[\s\S]*?-->|<\?[\s\S]*?\?>/g,'').match(/<[^>]*>/g)||[]){
  const name=tag.match(/^<\/?([\w.-]+)/)[1];
  if(tag.startsWith('</'))assert.equal(stack.pop(),name);else if(!tag.endsWith('/>'))stack.push(name);
 }assert.equal(stack.length,0,path);
}
const extension=read('extension.xml');
assert(extension.indexOf('source="campaign/record_structure_inventory_aptus.xml"')<extension.indexOf('source="campaign/record_char_equipment_structures_aptus.xml"'));
assert(!read('campaign/record_location_aptus.xml').includes('aptus_impersonate_button'));
assert(!read('campaign/record_structure_aptus.xml').includes('aptus_impersonate_button'));
console.log('OK estático: consulta común por categoría, contexto local sin escrituras, permisos reutilizados, snapshot podado, guardas de todas las acciones y CTA exclusivo de personaje.');

assert(view.includes('if not bInitialized or bClosed or not preview then return; end'));
assert(read('utility/tests/inventory_create_test.lua').includes('loadfile("utility/tests/structure_consultation_test.lua")'));
assert(!read('extension.xml').includes('structure_consultation_test.lua'));
const fixture=read('utility/tests/structure_consultation_test.lua');
assert(fixture.includes('loadfile("scripts/char_equipment_aptus.lua"'));
assert(fixture.includes('ui.selectView(2)'));
assert(fixture.includes('assert(not seen[w.item.path])'));

// Correcciones Fase 2A: composición común, grupos siempre desplegados y celdas acotadas.
assert(!/collapsedGroups|toggleStructureGroup|isExternalInventoryView|setAnchoredWidth\(483/.test(view));
assert(!/name="toggle"|expand_down/.test(xml+browser));
assert(xml.includes('<bounds>0,1,32,21</bounds>'));
assert(xml.includes('<bounds>34,2,181,20</bounds>'));
for(const [,bounds]of xml.matchAll(/<bounds>([^<]+)<\/bounds>/g)){
 const [x,y,w,h]=bounds.split(',').map(Number);assert(y+h<=24, 'Ningún control reserva una segunda línea vacía');
 assert(x+w<=466, 'La cabecera permanece dentro de la tabla');
}
const select=view.slice(view.indexOf('function selectView('),view.indexOf('-- Recorrido'));
assert(!/setAnchor|setAnchoredWidth|load_/.test(select), 'La distribución no cambia por pestaña');
assert(view.includes('if not bStructure then\n    local status = APTUSInventoryManager.getLoadStatus(getDatabaseNode(), inventory)'));
assert(row.includes('local hidden = item.is_container and item.hide_contents;'));
assert(row.includes('locationWidget.setMaxWidth(width)'));
assert(row.includes('location.setTooltipText(tItem.location)'));
assert(!row.includes('nNameRight = 323'));
assert(browser.includes('branch.setVisible(#group.inventory.items > 0)'));

assert(!xml.includes('name="open_record"'), 'La fila de consulta hereda el icono de inspección de Personaje');
assert(row.includes('return wEquipment.inspectStructureItem(sInstancePath)'));
assert(view.includes('function canInspectStructureItem(path)'));
assert(view.includes('getViewedInventory(owner, viewer)'));
assert(view.includes('for _, item in ipairs(snapshot.items) do if item.path == path then return true; end end'));
assert(view.includes('"aptus_inventory_item" or "aptus_inventory_item_consult"'));
assert(view.includes('window.configureInspection(self, context)'));
assert(view.includes('if existing then existing.close(); end'));
const outer=read('scripts/inventory_item_window_aptus.lua'),editor=read('scripts/record_inventory_item_aptus.lua');
assert(outer.includes('if initialized or (isContextWindow() and not inspectionSource) then return; end'));
assert(outer.includes('inspectionSource.canInspectStructureItem(DB.getPath(getDatabaseNode()))'));
assert(outer.includes('if not canViewInWindow() then close(); return; end'));
assert(editor.includes('APTUSInventoryManager.canEditInstance(getDatabaseNode(), getActionContext())'));
assert(editor.includes('if bClosed or bDeletePending or isInspectionOnly() or not hasCurrentContext() then return; end'));
assert(!/canEditInstance/.test(editor.slice(editor.indexOf('function rebuildCollections()'))));
assert(read('campaign/record_inventory_item_aptus.xml').includes('name="aptus_inventory_item_consult" copy="aptus_inventory_item"'));
assert(read('campaign/record_inventory_item_aptus.xml').includes('<subwindow name="content"><class merge="delete" /></subwindow>'));
assert(view.includes('for path, window in pairs(inspectionWindows) do'));
assert(view.includes('if not window.canViewInWindow() then window.close(); end'));
assert(view.includes('function onStructureViewerChanged()\n    closeInspections();'));
assert(outer.includes('if isInspectionOnly() then content.subwindow.reload();'));
// No hay enlaces navegables a inventarios/contenidos en las fichas reutilizadas.
for(const path of ['campaign/record_inventory_item_aptus.xml','campaign/record_item_melee_consultation_aptus.xml']){
 assert(!/<(?:windowreference|linkcontrol|formattedtextcontrol)\b/.test(read(path)));
}
assert(editor.includes('local bEditable = canEditCurrentInstance()'));
assert(editor.includes('if bClosed or not isAssociationsEditable() then return; end'));
assert(editor.includes('if not canEditCurrentInstance() then return false; end'));
assert(fixture.includes('lastOpened.onInstanceLockChanged(false)'));
assert(fixture.includes('assert(not ui.inspectStructureItem(DB.getPath(child)))'));
assert(read('utility/tests/inventory_instance_view_test.lua').includes('saves==beforeInspectionSaves'));

// Enlaces de cabeceras a fichas existentes, con Visibilidad independiente de Almacenaje.
const open=view.slice(view.indexOf('function openStructure(path)'),view.indexOf('-- Validación de lectura compartida'));
assert(open.includes('APTUSStructureManager.canViewAs(node, viewer)'));
assert(!/canAccess|canConsult|isFeatureActive|setValue|setOwner|setPublic/.test(open));
assert(open.includes('class = "aptus_location"')&&open.includes('class = "aptus_structure"'));
assert(open.includes('Interface.findWindow(class, path)')&&open.includes('Interface.openWindow(class, node)'));
assert(view.includes('header.setGroup(group, self)'));
const control=xml.match(/<genericcontrol name="open_structure">([\s\S]*?)<\/genericcontrol>/)[1];
assert(control.includes('<bounds>441,0,25,24</bounds>'));
assert(read('campaign/record_char_equipment_aptus.xml').includes('<bounds>441,0,25,24</bounds>'));
assert(!/invisible|disabled/.test(control));
assert(browser.includes('return equipment.openStructure(structurePath)'));
assert(browser.includes('w=25, h=24'));
for(const [icon,w,h]of [['aptus_localizacion_view',25,24],['aptus_vehicle_view',27,20]]){
 const path='graphics/icons/'+icon+'.png',png=fs.readFileSync(path);
 assert.equal(png.readUInt32BE(16),w);assert.equal(png.readUInt32BE(20),h);
 assert(read('graphics/graphics_aptus_char_equipment.xml').includes('<icon name="'+icon+'" file="'+path+'" />'));
 assert(browser.includes('"'+icon+'"'));
}

// Cabeceras: misma fuente de objetos, mayúsculas locales y recorte a Nombre.
const groupName=xml.match(/<stringcontrol name="name">([\s\S]*?)<\/stringcontrol>/)[1];
assert(groupName.includes('<font>aptus_inventory_row_text</font>'));
assert(groupName.includes('<bounds>34,2,181,20</bounds>'));
assert(browser.includes('nameWidget.setMaxWidth(width)'));
assert(browser.includes('nameWidget.setPosition("left", textWidth / 2, 0)'));
assert(browser.includes(':upper()'));
assert(browser.includes('["ñ"]="Ñ"')&&browser.includes('["ó"]="Ó"'));
assert(browser.includes('name.setTooltipText(group.name'));

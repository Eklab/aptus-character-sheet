// Ejecutar desde Character Sheet. No simula FGU ni sus anclajes.
const fs=require('fs'),assert=require('assert');
const read=p=>fs.readFileSync(p,'utf8');
const xml=read('campaign/equipment_type_filters_aptus.xml');
const index=read('scripts/equipment_index_type_filter_aptus.lua');
const select=read('scripts/equipment_select_type_filter_aptus.lua');
const manager=read('scripts/manager_aptus_equipment.lua');
const char=read('scripts/char_equipment_aptus.lua');
assert(xml.includes('copy="select_dialog"'));
assert(xml.includes('insertbefore="area_controls"')&&xml.includes('insertbefore="list"'));
assert(xml.includes('Tipo de equipo')&&xml.includes('add("", "Todos")'));
assert(xml.includes('APTUSEquipmentManager.getTypes()'));
assert(!xml.includes('<sub_content_top') && !xml.includes('<subwindow'));
assert(xml.includes('<font>reference-header</font>'));
assert(xml.includes('<aptus_equipment_type_combo name="aptus_type_combo" />'));
assert(index.includes('createControl("aptus_equipment_type_combo", "aptus_type_combo")'));
assert(index.includes('local width = label.getSize()'));
assert(select.includes('aptus_type_combo.setValue("")'));
assert(!select.includes('aptus_type_filter.subwindow'));
// Etiqueta y campo separados; marco inferior a y=59 dentro de la reserva de 64 px.
assert(xml.includes('<top offset="4" />')&&xml.includes('<top offset="34" />'));
assert(4+22<=34-5 && 34+20+5<=64);
assert(!xml.includes('<datasource>'));
assert(index.includes('super.setupCustomFilters()'));
assert(index.includes('if not super.isFilteredRecord(record) then return false; end'));
assert(index.includes('if getRecordType() ~= "aptus_equipment" then return true; end'));
assert(index.includes('createControl("aptus_equipment_index_type_filter"'));
assert(select.includes('super.activateNextSelection()'));
assert(select.includes('row.selected.setValue(0)'));
assert(select.includes('list.applyFilter()'));
assert(index.includes('APTUSEquipmentManager.matchesTypeFilter(record.node, selectedType)'));
assert(select.includes('APTUSEquipmentManager.matchesTypeFilter(DB.findNode(path or ""), selectedType)'));
const common=manager.slice(manager.indexOf('function matchesTypeFilter('),manager.indexOf('function canEdit('));
assert(common.includes('if (selected or "") == "" then return true; end'));
assert(common.includes('DB.getType(child) == "string"'));
assert(common.includes('RecordDataManager.getDataPaths(sType)'));
assert(common.includes('table.sort(options,'));
for(const source of [index,select,common,xml])assert(!/DB\.(createNode|createChild|setValue|deleteNode|deleteChild|copyNode)\s*\(/.test(source));
assert(char.includes('APTUSEquipmentManager.openTemplateSelection(selection)'));
assert(char.includes('pcall(APTUSInventoryManager.createFromTemplate,'));
assert(read('extension.xml').includes('campaign/equipment_type_filters_aptus.xml'));
for(const text of [xml,read('extension.xml')]){
 const stack=[];
 for(const tag of text.replace(/<!--[\s\S]*?-->|<\?[\s\S]*?\?>/g,'').match(/<[^>]*>/g)||[]){
  const name=tag.match(/^<\/?([\w.-]+)/)?.[1];assert(name,tag);
  if(tag.startsWith('</'))assert.equal(stack.pop(),name);else if(!tag.endsWith('/>'))stack.push(name);
 }assert.equal(stack.length,0);
}
for(const [,file] of xml.matchAll(/file="([^"]+)"/g))assert(fs.existsSync(file));
console.log('OK: combobox en ventana principal, etiqueta reference-header, reserva sin solapamientos, filtro común, XML y ausencia de escrituras.');

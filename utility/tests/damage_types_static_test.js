// Comprobaciones disponibles sin Lua/FGU; no simula el motor.
const fs=require('fs'),assert=require('assert');
const model=fs.readFileSync('scripts/manager_aptus_equipment.lua','utf8');
const xml=fs.readFileSync('campaign/record_equipment_aptus.xml','utf8');
const editor=fs.readFileSync('scripts/equipment_profile_aptus.lua','utf8');
const view=fs.readFileSync('scripts/item_melee_consultation_aptus.lua','utf8');
const block=fs.readFileSync('scripts/item_melee_block_aptus.lua','utf8');
const expected=[['bludgeoning','Contundente'],['slashing','Cortante'],['piercing','Perforante'],['fire','Fuego'],['ice','Hielo'],['electric','Eléctrico'],['chemical','Químico'],['radiation','Radiación'],['supernatural','Sobrenatural']];
const definition=model.slice(model.indexOf('local tDamageTypes ='),model.indexOf('local tDamageTypeIds'));
assert.deepEqual([...definition.matchAll(/\{id="([^"]+)", name="([^"]+)", abbreviation="[A-Z]+"\}/g)].map(m=>[m[1],m[2]]),expected);
assert.equal(new Set(expected.map(t=>t[0])).size,9);
assert(model.includes('problem = validateDamageTypes(entry.damage_types)'));
assert(model.includes('local entry = { damage_types={} }'));
const setter=model.slice(model.indexOf('function setProfileDamageType('),model.indexOf('function formatProfileDamageTypes('));
assert(!/DB\.\w+\s*\(/.test(setter));
assert(setter.includes('{kind="number", value=1}')&&setter.includes('profile.damage_types[id] = nil'));
assert(xml.includes('<buttonc_checkbox>')&&xml.includes('window.damageTypeChanged(getName():sub(13), getValue() == 1)'));
assert.equal('damage_type_'.length+1,13);
assert(xml.includes('TIPOS DE DAÑO')&&xml.includes('0,0,1,354'));
assert.deepEqual([...definition.matchAll(/abbreviation="([A-Z]+)"/g)].map(m=>m[1]),['CON','COR','PER','FUE','HIE','ELE','QUI','RAD','SOB']);
assert(editor.includes('updatingDamageTypes = true;')&&editor.includes('not owner.isEditable()'));
assert(editor.includes('APTUSEquipmentManager.getDamageTypes()'));
assert(!/DB\.(setValue|createChild|createNode|deleteNode)/.test(editor));
// Cuadrícula 3 × 3: etiquetas de 12 px dentro del formulario 488 × 354.
for(let index=0;index<9;index++){
  const x=2+(index%3)*134,y=281+Math.floor(index/3)*22;
  assert(x+24+108<=488&&y+20<=348);
}
assert(view.includes('damage_types=APTUSEquipmentManager.formatProfileDamageTypes(profile)'));
assert(block.includes('" · Cualidades: "')&&block.includes('or "Nada"'));
assert(block.includes('profile_qualities.setTooltipText(line ..'));
assert(block.includes('qualityWidget.setMaxWidth(381)'));
const clean=xml.replace(/<!--[\s\S]*?-->|<\?[\s\S]*?\?>/g,'');
const stack=[];
for(const tag of clean.match(/<[^>]*>/g)||[]){const name=tag.match(/^<\/?([\w.-]+)/)?.[1];assert(name);
  if(tag.startsWith('</'))assert.equal(stack.pop(),name);else if(!tag.endsWith('/>'))stack.push(name);
}assert.equal(stack.length,0);
for(const [,file]of xml.matchAll(/file="([^"]+)"/g))assert(fs.existsSync(file)||fs.existsSync('/references/corerpg/'+file),file);
console.log('OK: catálogo único de 9 IDs, validación, casillas nativas 3x3, geometría y texto/tooltip sin escrituras locales.');

// Comprobaciones estáticas: no ejecutan Lua ni el menú nativo de FGU.
const fs = require('fs'), assert = require('assert');
const read = p => fs.readFileSync(p, 'utf8');
const xml = read('campaign/record_char_identity_content_aptus.xml');
const match = xml.match(/<combobox name="gender">([\s\S]*?)<\/combobox>/);
assert(match, 'Sexo debe ser un combobox vinculado a gender');
const control = match[1];
for (const tag of ['labels', 'values']) {
    assert.deepStrictEqual(control.match(new RegExp('<'+tag+'>(.*?)</'+tag+'>'))[1].split('|'), ['Masculino', 'Femenino']);
}
assert(control.includes('<bounds>95,118,56,18</bounds>'));
assert(control.includes('<font>aptus_font_navigation_black</font>'));
assert(!/<(?:sourceless|defaultindex|nodefault|script|source)\b/.test(control));
assert(!xml.includes('<stringfield name="gender">'));
const identity = read('scripts/char_identity_data_aptus.lua');
assert(identity.includes('"name", "age", "gender", "height"'), 'Mantener el candado de Identidad');
const view = read('scripts/char_equipment_aptus.lua');
assert(view.includes('watch(DB.getPath(node, "gender"), event)'));
const manager = read('scripts/manager_aptus_inventory.lua');
assert(manager.includes('field(character, "gender", "string")'));
assert(manager.includes('gender == "femenino" and "female_" or "male_"'));
// Cuando CoreRPG está disponible, verificar las garantías nativas utilizadas.
const nativePath = '/references/corerpg/common/scripts/control_select_base.lua';
if (fs.existsSync(nativePath)) {
    const base = read(nativePath);
    assert(base.includes('sField or getName()'));
    assert(base.includes('DB.setValue(sSource, "string", self.getValue())'));
    const load = base.slice(base.indexOf('function loadSourceData()'), base.indexOf('function saveSourceData()'));
    assert(load.includes('_bUpdatingSource = true') && load.includes('_bUpdatingSource = false'));
    assert(base.includes('if _bUpdatingSource then'));
    assert(!/DB\.(setValue|createChild|deleteNode)/.test(load));
}
console.log('OK estático: dos opciones cerradas, gender string nativo sin valor predeterminado, geometría/fuente/candado conservados y observador de CARGA vigente. Validación funcional pendiente en FGU.');

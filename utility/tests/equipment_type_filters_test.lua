-- Prueba aislada: lua utility/tests/equipment_type_filters_test.lua
-- Sin campaña; comprueba el predicado real y tipos registrados dinámicamente.
local db = {};
function db.getChild(node, path) return node and node[path]; end
function db.getType(node) return node.kind; end
function db.getValue(node) return node.value; end
local model=setmetatable({DB=db},{__index=_G});
assert(loadfile("scripts/manager_aptus_equipment.lua","t",model))();
model.registerType("melee_weapon","Arma CC");
model.registerType("utility","Utilidad");
local melee={["properties.type_id"]={kind="string",value="melee_weapon"}};
local unknown={["properties.type_id"]={kind="string",value="future"}};
local malformed={["properties.type_id"]={kind="number",value=1}};
for _, node in ipairs({melee,unknown,malformed,{}}) do assert(model.matchesTypeFilter(node,"")); end
assert(model.matchesTypeFilter(melee,"melee_weapon"));
assert(not model.matchesTypeFilter(melee,"utility"));
assert(not model.matchesTypeFilter(unknown,"melee_weapon"));
assert(not model.matchesTypeFilter(malformed,"melee_weapon"));
assert(not model.matchesTypeFilter({},"melee_weapon"));
assert(not model.matchesTypeFilter(nil,"melee_weapon"));
assert(not model.matchesTypeFilter(unknown,"future"));
model.registerType("future","Tipo futuro de prueba");
assert(#model.getTypes()==3 and model.getTypes()[3].id=="future");
assert(model.matchesTypeFilter(unknown,"future"));
print("OK: Todos, ausentes, desconocidos, tipos incorrectos y registro dinámico sin DB de escritura.");

-- Prueba aislada: ejecutar desde character-sheet con Lua 5.3/5.4.
-- No incluir en extension.xml. Sólo DB doble en memoria, sin campaña ni archivos escritos.
local function node(path, kind, value)
    return { path = path, kind = kind or "node", value = value, children = {} };
end
local function put(base, path, kind, value)
    local cursor = base;
    local parts = {};
    for part in path:gmatch("[^.]+") do table.insert(parts, part); end
    for i, part in ipairs(parts) do
        cursor.children[part] = cursor.children[part] or node(cursor.path .. "." .. part);
        cursor = cursor.children[part];
        if i == #parts then cursor.kind, cursor.value = kind, value; end
    end
    return cursor;
end
local DB = {};
function DB.getChild(base, path)
    local cursor = base;
    for part in (path or ""):gmatch("[^.]+") do
        cursor = cursor and cursor.children[part];
    end
    return cursor;
end
function DB.getType(n) return n.kind; end
function DB.getPath(n) return n.path; end
function DB.getName(n) return n.path:match("[^.]+$"); end
function DB.getValue(n) return n.value; end
function DB.getChildren(n) return n.children; end
local writes = 0;
local function denyWrite() writes = writes + 1; error("La lectura intentó escribir DB"); end
for _, name in ipairs({ "createNode", "createChild", "setValue", "deleteNode", "deleteChild", "copyNode", "createChildAndCopy" }) do DB[name] = denyWrite; end
local manager = setmetatable({ DB = DB }, { __index = _G });
assert(loadfile("scripts/manager_aptus_inventory.lua", "t", manager))();
local function character() return node("charsheet.id-test"); end
local function item(char, id, name, parent, carried, container, count)
    local n = put(char, "inventorylist." .. id, "node");
    put(n, "name", "string", name);
    put(n, "count", "number", count or 1);
    put(n, "carried", "number", carried or 0);
    put(n, "template_id", "string", "fixture:" .. id);
    put(n, "template_version", "number", 1);
    put(n, "properties.type_id", "string", container and "storage" or "utility");
    put(n, "properties.is_container", "number", container and 1 or 0);
    put(n, "properties.load_every", "number", 1);
    put(n, "properties.load_value", "number", 3);
    put(n, "aptus.instance_schema", "number", 1);
    put(n, "aptus.container", "string", parent or "");
    return n;
end
local function fingerprint(n)
    local keys, values = {}, { n.kind, tostring(n.value) };
    for key in pairs(n.children) do table.insert(keys, key); end
    table.sort(keys);
    for _, key in ipairs(keys) do table.insert(values, key .. "{" .. fingerprint(n.children[key]) .. "}"); end
    return table.concat(values, "|");
end
local function read(char)
    local before = fingerprint(char);
    local result = manager.getCharacterInventory(char);
    assert(fingerprint(char) == before and writes == 0, "Lectura alteró los registros");
    return result;
end
assert(#read(character()).items == 0);
assert(#manager.getCharacterInventory(nil).items == 0);
assert(#manager.getCharacterInventory(node("aptus_structures.id-test")).items == 0);
local char = character();
item(char, "a", "Mochila", "", 1, true);
item(char, "b", "Bolsa", "a", 2, true);
item(char, "c", "Linterna", "b", 0, false, 12);
item(char, "d", "Bolsa", "", 2, true);
item(char, "e", "Linterna", "d", 1, false);
item(char, "f", "Suelo", "", 0, false);
local result = read(char);
assert(#result.items == 6 and #result.roots == 3 and result.ignored == 0);
assert(result.items[3].effective_carried == 0 and result.items[3].state == "Contenido");
assert(result.items[3].location == "Bolsa" and result.items[3].parent_id == "b" and result.items[3].count == 12);
assert(result.items[5].effective_carried == 0 and result.items[5].parent_id == "d", "Se confundieron nombres duplicados");
assert(result.items[6].state == "Sin equipar" and result.items[6].location == "-");
assert(result.items[3].load == 36, "CAR no usa los tramos y cantidad reales de esta pila");
assert(result.items[3].properties.load_value.value == 3);
-- Tras /reload puede faltar el padre vacío: raíz válida sin migración ni escrituras.
local root = DB.getChild(char, "inventorylist.a");
root.children.aptus.children.container = nil;
assert(manager.isInstance(root));
local absent = read(char);
assert(#absent.items == 6 and #absent.roots == 3 and absent.ignored == 0);
assert(absent.items[1].parent_id == "" and absent.items[1].location == "-");
assert(absent.items[3].location == "Bolsa" and absent.items[3].effective_carried == 1);
assert(not DB.getChild(root, "aptus.container"), "Se materializó el padre ausente");
-- Un cambio externo se refleja al releer sin propagarlo a cada hijo.
put(DB.getChild(char, "inventorylist.a"), "carried", "number", 2);
assert(read(char).items[3].effective_carried == 2);
assert(DB.getValue(DB.getChild(char, "inventorylist.c.carried")) == 0);
-- Contratos incompletos/tipos incorrectos/versiones desconocidas: ignorar, no migrar.
local badCases = {
    function(n) n.children.aptus.children.instance_schema = nil; end,
    function(n) put(n, "aptus.instance_schema", "number", 2); end,
    function(n) put(n, "count", "string", "2"); end,
    function(n) put(n, "count", "number", 0); end,
    function(n) put(n, "carried", "number", 3); end,
    function(n) put(n, "template_id", "string", ""); end,
    function(n) put(n, "aptus.container", "number", 0); end,
    function(n) n.children.properties.children.is_container = nil; end,
    function(n) put(n, "properties.type_id", "string", "desconocido"); end,
    function(n) put(n, "properties.is_container", "number", 1); put(n, "count", "number", 2); end,
};
for _, change in ipairs(badCases) do
    local c = character(); local n = item(c, "old", "Heredado", "", 1, false);
    change(n); assert(not manager.isInstance(n));
    local r = read(c); assert(#r.items == 0 and r.ignored == 1 and #r.diagnostics == 1);
end
-- Relaciones inválidas, padre no contenedor y ciclos: también se excluyen dependientes.
local broken = character();
item(broken, "a", "Huérfano", "missing", 1, true);
item(broken, "b", "Hijo huérfano", "a", 1, false);
item(broken, "c", "Ciclo C", "d", 1, true);
item(broken, "d", "Ciclo D", "c", 1, true);
item(broken, "e", "Hijo de ciclo", "c", 1, false);
item(broken, "f", "Autociclo", "f", 1, true);
item(broken, "g", "Raíz sana", "", 2, false);
item(broken, "h", "Padre hoja", "g", 1, false);
local r = read(broken);
assert(#r.items == 1 and r.items[1].id == "g" and r.ignored == 7);
-- Profundidad mayor que dos sin límite artificial ni recursión del grafo.
local deep = character();
for i = 1, 128 do item(deep, string.format("id-%04d", i), "Nivel " .. i,
    i == 1 and "" or string.format("id-%04d", i - 1), i == 1 and 2 or 0, true); end
local d = read(deep);
assert(#d.items == 128 and #d.roots == 1 and d.items[128].effective_carried == 2);
assert(d.items[128].location == "Nivel 127");
assert(writes == 0);
print("APTUS inventario fase 1: contrato, contenidos sin equipar, duplicados, inválidos, ciclos, profundidad y cero escrituras OK");

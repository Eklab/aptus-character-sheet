-- Prueba aislada, NO incluir en extension.xml ni ejecutar en una campaña.
-- Desde character-sheet: lua utility/tests/equipment_save_test.lua (Lua 5.3/5.4).
-- No necesita FGU ni escribe archivos; DB es exclusivamente el doble en memoria.
local nodes, logs, fault, writes = {}, {}, nil, 0;
local function resolve(base, path, create)
    local full = type(base) == "table" and base.path or (base or "");
    if path and path ~= "" then full = full == "" and path or full .. "." .. path; end
    if create then
        local current = "";
        for part in full:gmatch("[^.]+") do
            current = current == "" and part or current .. "." .. part;
            nodes[current] = nodes[current] or { path = current, kind = "node" };
        end
    end
    return nodes[full];
end
local DB = {};
function DB.createNode(path) return resolve(path, nil, true); end
function DB.createChild(node, path) return resolve(node, path, true); end
function DB.getChild(node, path) return resolve(node, path); end
function DB.getPath(node) return node.path; end
function DB.getName(node) return node.path:match("([^.]+)$"); end
function DB.findNode(path) return resolve(path); end
function DB.getType(node) return node.kind; end
function DB.getModule(node) return type(node) == "table" and node.module or ""; end
function DB.isReadOnly(node) return type(node) == "table" and node.readOnly == true; end
function DB.getValue(node, path, default)
    if type(node) == "table" and node.kind ~= "node" and path == nil then return node.value; end
    local child = resolve(node, path);
    if not child then return default; end
    if child.kind == "windowreference" then return child.class, child.value; end
    return child.value;
end
function DB.getChildren(node, path)
    local result = {};
    local parent = resolve(node, path);
    if not parent then return result; end
    local prefix = parent.path .. ".";
    for path, child in pairs(nodes) do
        if path:sub(1, #prefix) == prefix then
            local key = path:sub(#prefix + 1);
            if not key:find("%.") then result[key] = child; end
        end
    end
    return result;
end
DB.getChildrenGlobal = DB.getChildren;
function DB.deleteChild(node, path)
    local child = resolve(node, path);
    if not child then return; end
    local full = child.path;
    local keys = {};
    for key in pairs(nodes) do
        if key == full or key:sub(1, #full + 1) == full .. "." then table.insert(keys, key); end
    end
    for _, key in ipairs(keys) do nodes[key] = nil; end
end
function DB.setValue(node, path, kind, value, target)
    writes = writes + 1;
    local child = resolve(node, path, true);
    if fault then
        local replacement, overrideKind = fault(child.path, kind, value);
        value, kind = replacement, overrideKind or kind;
    end
    child.kind = kind;
    if kind == "windowreference" then child.class, child.value = value, target;
    -- Reproducir números DB en float frente a los enteros de newProfile.
    elseif kind == "number" then child.value = value + 0.0;
    else child.value = value; end
end
local manager = setmetatable({
    DB = DB, Session = { IsHost = true },
    WindowManager = { getReadOnlyState = function() return false; end },
    RecordDataManager = {
        getRecordTypeFromRecordPath = function(path)
            if path:match("^aptus_qualities%.") or path:match("^reference%.aptus_qualities%.") then return "aptus_quality"; end
            return "aptus_equipment";
        end,
        setRecordTypeData = function() end,
    },
    RecordManager = { setRecordAddCallback = function() end },
    ChatManager = { SystemMessage = function(s) table.insert(logs, s); end },
    Debug = { console = function(s) table.insert(logs, s); end },
    Interface = { getString = function() return "Copia"; end },
}, { __index = _G });
assert(loadfile("scripts/manager_aptus_equipment.lua", "t", manager))();
manager.onInit();
local function newTemplate(key)
    local node = DB.createNode("aptus_equipment_templates." .. key);
    manager.onRecordAdded(node);
    return node;
end
local function set(entry, key, kind, value) manager.setEntryValue(entry, key, kind, value); end
local function commit(node, draft)
    local before = DB.getValue(node, "template_version", 0);
    local ok, message = manager.save(node, draft, manager.getEditToken(node));
    assert(ok, message);
    assert(DB.getValue(node, "template_version", 0) == before + 1, "Versión no incrementada una vez");
    local token, count = manager.getEditToken(node), writes;
    ok, message = manager.save(node, manager.getDraft(node), token);
    assert(ok, message);
    assert(manager.getEditToken(node) == token and writes == count, "Guardar sin cambios escribió datos");
end
local function profile(draft, name)
    local key, entry = manager.newProfile(draft.collections.profiles);
    set(entry, "name", "string", name);
    set(entry, "attack_skill_id", "string", "punteria");
    set(entry, "damage", "string", "d6"); set(entry, "critical", "string", "d6");
    set(entry, "range", "string", "25"); set(entry, "uses_ammunition", "number", 1);
    set(entry, "ammunition_max", "number", 10);
    return key, entry;
end
local function quality(collection, id)
    local n = 1; while collection[string.format("ref_%04d", n)] do n = n + 1; end
    local key = string.format("ref_%04d", n);
    local entry = { quality_id = { kind = "string", value = "test:" .. id } };
    collection[key] = entry;
    return key, entry;
end

local node = newTemplate("regression");
local draft = manager.getDraft(node);
draft.name, draft.type_id = "Pistola2", "ranged_weapon";
commit(node, draft); -- 1: generales sin colecciones.
draft = manager.getDraft(node);
quality(draft.collections.qualities, "General"); commit(node, draft); -- 2.
draft = manager.getDraft(node);
local key, entry = profile(draft, "Disparo"); commit(node, draft); -- 3.
draft = manager.getDraft(node); entry = draft.collections.profiles[key]; entry.qualities = {};
quality(entry.qualities, "cargador");
commit(node, draft); -- 4: referencia de cualidad de perfil.
draft = manager.getDraft(node); quality(draft.collections.profiles[key].qualities, "Ocultable");
commit(node, draft); -- 5: varias cualidades anidadas.
draft = manager.getDraft(node); profile(draft, "Segundo perfil"); commit(node, draft); -- 6.
draft = manager.getDraft(node); set(draft.collections.profiles[key], "range", "string", "30");
commit(node, draft); -- 7: edición.
draft = manager.getDraft(node); draft.collections.profiles[key] = nil; commit(node, draft); -- 8.
local token = manager.getEditToken(node);
draft = manager.getDraft(node); profile(draft, "Descartado");
assert(manager.getEditToken(node) == token, "El borrador escribió DB"); -- 9.
assert(manager.validateCollections(manager.getDraft(node).collections) == nil);

-- 10: simular la copia genérica completa de CoreRPG y su callback de alta.
local copy = DB.createNode("aptus_equipment_templates.duplicate");
local original = {};
for path, value in pairs(nodes) do original[path] = value; end
for path, value in pairs(original) do
    if path == node.path or path:sub(1, #node.path + 1) == node.path .. "." then
        local target = copy.path .. path:sub(#node.path + 1);
        nodes[target] = { path = target, kind = value.kind, value = value.value, class = value.class };
    end
end
manager.onRecordAdded(copy);
assert(DB.getValue(copy, "template_id", "") ~= DB.getValue(node, "template_id", ""));
assert(DB.getValue(copy, "template_version", 0) == 1);
assert(manager.fingerprint(copy) == manager.fingerprint(node), "Copia perdió colecciones");
assert(not manager.isTemplateConfirmed(node), "El alta original aún no fue confirmada por la interfaz");
manager.confirmTemplateSaved(node);
assert(manager.isTemplateConfirmed(node));
assert(manager.isTemplateConfirmed(copy), "Una copia persistida debe poder duplicarse");
DB.setValue(copy, "name", "string", DB.getValue(node, "name", "") .. " Copia");
assert(manager.getCopyProblem(node, copy) == nil, "La copia nativa no supera la verificación");
local pending = newTemplate("pending_copy");
assert(not manager.isTemplateConfirmed(pending));
local pendingVersion = DB.getValue(pending, "template_version", 0);
local sameDraft = manager.getDraft(pending);
assert(not manager.hasDraftChanges(pending, sameDraft));
assert(manager.save(pending, sameDraft, manager.getEditToken(pending)));
manager.confirmTemplateSaved(pending);
assert(manager.isTemplateConfirmed(pending) and DB.getValue(pending, "template_version", 0) == pendingVersion);
sameDraft.name = "No incluir en copia";
assert(manager.hasDraftChanges(pending, sameDraft));
sameDraft = manager.getDraft(pending);
quality(sameDraft.collections.qualities, "Sin guardar");
assert(manager.hasDraftChanges(pending, sameDraft));

-- Fallo silencioso en una hoja anidada: no aceptar ni aumentar versión.
draft = manager.getDraft(node); key, entry = profile(draft, "Fallo");
local target = node.path .. ".properties.profiles." .. key .. ".ammunition_max";
local version, before = DB.getValue(node, "template_version", 0), manager.getEditToken(node);
fault = function(path, kind, value)
    if path == target then fault = nil; return value + 1; end
    return value;
end
local ok, message = manager.save(node, draft, before);
assert(not ok and message:find("restaurados y verificados"), message);
assert(manager.getEditToken(node) == before and DB.getValue(node, "template_version", 0) == version);
local found = false;
for _, line in ipairs(logs) do
    if line:find("ammunition_max.value", 1, true) and line:find("esperado=", 1, true) and line:find("recuperado=", 1, true) then found = true; end
end
assert(found, "Falta diagnóstico de la hoja exacta");

-- Un cambio de tipo number -> string no debe superar la integridad.
draft = manager.getDraft(node); key = profile(draft, "Tipo incorrecto");
target = node.path .. ".properties.profiles." .. key .. ".ammunition_max";
fault = function(path, kind, value)
    if path == target then fault = nil; return value, "string"; end
    return value;
end
ok = manager.save(node, draft, before);
assert(not ok and manager.getEditToken(node) == before);

-- Token desactualizado: rechazo antes de cualquier escritura.
draft = manager.getDraft(node); draft.description = "Edición actual"; commit(node, draft);
local count = writes;
ok = manager.save(node, draft, before);
assert(not ok and writes == count);

-- Fallo posterior a escribir versión: restaurarla también, no conservar incremento.
before = manager.getEditToken(node);
version = DB.getValue(node, "template_version", 0);
draft = manager.getDraft(node); draft.description = "Fallo de versión";
fault = function(path, kind, value)
    if path == node.path .. ".template_version" then fault = nil; return value + 1; end
    return value;
end
ok = manager.save(node, draft, before);
assert(not ok and manager.getEditToken(node) == before and DB.getValue(node, "template_version", 0) == version);

-- Si DB corrompe también la restauración sin lanzar error, no anunciar éxito.
local broken = newTemplate("restorefailure");
draft = manager.getDraft(broken); key = profile(draft, "Restauración"); commit(broken, draft);
before, version = manager.getEditToken(broken), DB.getValue(broken, "template_version", 0);
draft = manager.getDraft(broken); set(draft.collections.profiles[key], "ammunition_max", "number", 11);
target = broken.path .. ".properties.profiles." .. key .. ".ammunition_max";
fault = function(path, kind, value) if path == target then return value + 1; end return value; end
ok, message = manager.save(broken, draft, before);
fault = nil;
assert(not ok and message:find("ni verificar la restauración"), message);
assert(DB.getValue(broken, "template_version", 0) == version);

-- Requisitos generales: adición compatible, sin escoger valores de los perfiles.
local legacy = newTemplate("legacy_requirements");
draft = manager.getDraft(legacy);
local p1 = profile(draft, "Antiguo A");
local p2 = profile(draft, "Antiguo B");
assert(draft.collections.profiles[p1].required_fue == nil, "Los perfiles nuevos no tienen requisitos");
commit(legacy, draft);
DB.setValue(legacy, "properties.profiles." .. p1 .. ".required_fue", "number", 3);
DB.setValue(legacy, "properties.profiles." .. p2 .. ".required_fue", "number", 5);
DB.setValue(legacy, "properties.profiles." .. p1 .. ".required_agi", "number", 2);
DB.deleteChild(legacy, "properties.required_fue"); DB.deleteChild(legacy, "properties.required_agi");
local notice = manager.getLegacyRequirements(legacy);
assert(notice and notice:find("Antiguo A", 1, true) and notice:find("Antiguo B", 1, true));
draft = manager.getDraft(legacy);
assert(draft.required_fue == 0 and draft.required_agi == 0, "Se eligió un requisito antiguo arbitrariamente");
before, count = manager.getEditToken(legacy), writes;
ok = manager.save(legacy, draft, before);
assert(ok and writes == count and manager.getEditToken(legacy) == before, "No-op materializó campos nuevos");
draft.description = "Guardar otro campo sin requisitos generales persistidos"; commit(legacy, draft);
assert(not DB.getChild(legacy, "properties.required_fue"));
draft = manager.getDraft(legacy); draft.required_fue, draft.required_agi = 4, 1;
commit(legacy, draft);
assert(DB.getValue(legacy, "properties.required_fue", -1) == 4);
assert(DB.getValue(legacy, "properties.required_agi", -1) == 1);
assert(DB.getValue(legacy, "properties.profiles." .. p1 .. ".required_fue", -1) == 3);
assert(DB.getValue(legacy, "properties.profiles." .. p2 .. ".required_fue", -1) == 5);
assert(DB.getValue(legacy, "properties.profiles." .. p1 .. ".required_agi", -1) == 2);
before, count = manager.getEditToken(legacy), writes;
draft = manager.getDraft(legacy); draft.required_fue = -1;
ok = manager.save(legacy, draft, before);
assert(not ok and writes == count and manager.getEditToken(legacy) == before);
draft.required_fue, draft.required_agi = 4, 1.5;
ok = manager.save(legacy, draft, before);
assert(not ok and writes == count);
-- CUALIDADES: mismo gestor real, catálogo simulado en DB y asociaciones sin copias.
local qualities = setmetatable({
    DB = DB, Session = manager.Session, WindowManager = manager.WindowManager,
    RecordDataManager = manager.RecordDataManager, RecordManager = manager.RecordManager,
    Debug = manager.Debug, ChatManager = manager.ChatManager, APTUSEquipmentManager = manager,
}, { __index = _G });
qualities.RecordDataManager.isRecordTypeDisplayClass = function(t, class) return t == "aptus_quality" and class == t; end
assert(loadfile("scripts/manager_aptus_qualities.lua", "t", qualities))();
qualities.onInit();
local definition = DB.createNode("aptus_qualities.first"); qualities.onRecordAdded(definition);
local qid = DB.getValue(definition, "quality_id", ""); assert(qid ~= "");
local qdraft = qualities.getDraft(definition);
qdraft.name, qdraft.description, qdraft.types = "Precisa", "Descripción inicial", { equipment = true, melee = true };
assert(qualities.save(definition, qdraft, qualities.token(definition)));
local classified = table.concat(qualities.typeValues(definition), "|");
assert(classified:find("Equipo", 1, true) and classified:find("Armas CC", 1, true));
assert(qualities.resolve(qid) == definition);
local drag = { getType = function() return "shortcut"; end,
    getShortcutData = function() return "aptus_quality", definition.path; end };
local links = {};
assert(qualities.addFromDrop(links, drag));
assert(not qualities.addFromDrop(links, drag), "Se duplicó una asociación");
local _, link = next(links); assert(link.quality_id.value == qid and link.name == nil and link.description == nil);
local associations = qualities.clone(links);
associations.extra = { quality_id = { kind = "string", value = "missing" } };
assert(links.extra == nil, "Borrador secundario alteró el original");
local equipped = newTemplate("catalog_references");
draft = manager.getDraft(equipped); draft.collections.qualities = links;
local refProfile, profileData = profile(draft, "Con referencias");
profileData.qualities = qualities.clone(links);
commit(equipped, draft);
before = manager.getEditToken(equipped);
qdraft = qualities.getDraft(definition); qdraft.description = "Descripción actualizada";
assert(qualities.save(definition, qdraft, qualities.token(definition)));
assert(manager.getEditToken(equipped) == before, "Editar catálogo incrementó/cambió EQUIPO");
local title, description = qualities.describe(link);
assert(title == "Precisa" and description == "Descripción actualizada");
assert(qualities.countReferences(qid) >= 2, "No contó referencias generales y de perfil");

-- Una definición duplicada con el mismo ID jamás se resuelve, ni siendo idéntica.
local duplicate = DB.createNode("reference.aptus_qualities.duplicate");
DB.setValue(duplicate, "quality_id", "string", qid);
DB.setValue(duplicate, "name", "string", "Precisa");
assert(qualities.resolve(qid) == nil);
assert(qualities.describe(link) == "Cualidad inaccesible");
DB.deleteChild("reference.aptus_qualities", "duplicate");
assert(qualities.resolve(qid) == definition);

-- Descargar/eliminar definición conserva IDs y no bloquea guardar otros campos.
DB.deleteChild("aptus_qualities", "first");
title, description = qualities.describe(link);
assert(title == "Cualidad inaccesible");
assert(description == "No se encuentra la definición de esta cualidad. Comprueba que el módulo correspondiente esté activado");
draft = manager.getDraft(equipped); draft.description = "Otro cambio con referencia inaccesible"; commit(equipped, draft);
assert(manager.getDraft(equipped).collections.qualities.ref_0001.quality_id.value == qid);
local moduleDefinition = DB.createNode("reference.aptus_qualities.loaded");
DB.setValue(moduleDefinition, "quality_id", "string", qid);
DB.setValue(moduleDefinition, "name", "string", "Precisa recuperada");
DB.setValue(moduleDefinition, "description", "string", "Desde módulo");
moduleDefinition.module = "Prueba";
assert(not qualities.canEdit(moduleDefinition));
assert(qualities.describe(link) == "Precisa recuperada");
local second = DB.createNode("aptus_qualities.second"); qualities.onRecordAdded(second);
assert(DB.getValue(second, "quality_id", "") ~= qid);
-- Contrato único: datos extra en una asociación no son aceptados ni convertidos.
local clean = newTemplate("reference_contract");
draft = manager.getDraft(clean);
local kept = quality(draft.collections.qualities, "keep");
local childKey = profile(draft, "Perfil intacto");
quality(draft.collections.profiles[childKey].qualities, "child_keep");
commit(clean, draft);
local nameBefore = DB.getValue(clean, "name", "");
local damageBefore = DB.getValue(clean, "properties.profiles." .. childKey .. ".damage", "");
-- Datos de prueba fuera del contrato: no deben entrar en el borrador ni copiarse.
DB.setValue(clean, "properties.qualities.unsupported.quality_id", "string", "test:unsupported");
DB.setValue(clean, "properties.qualities.unsupported.name", "string", "No admitir");
DB.setValue(clean, "properties.profiles." .. childKey .. ".qualities.unsupported.quality_id", "string", "test:unsupported_child");
DB.setValue(clean, "properties.profiles." .. childKey .. ".qualities.unsupported.parameters.data", "string", "No admitir");
local filtered = manager.getDraft(clean);
assert(filtered.collections.qualities.unsupported == nil);
assert(filtered.collections.profiles[childKey].qualities.unsupported == nil);
assert(filtered.collections.qualities[kept].quality_id.value == "test:keep");
before = manager.getEditToken(clean);
version = DB.getValue(clean, "template_version", 0);
fault = function(path, kind, value)
    if path == clean.path .. ".properties.profiles." .. childKey .. ".damage" then
        fault = nil; return value .. "_corrupt";
    end
    return value;
end
ok = manager.save(clean, filtered, before);
assert(not ok and manager.getEditToken(clean) == before);
assert(DB.getValue(clean, "template_version", 0) == version);
assert(DB.getChild(clean, "properties.qualities.unsupported"), "Fallo de guardado dejó una retirada parcial");
-- Duplicación genérica: el callback limpia sólo la nueva plantilla.
local targetCopy = DB.createNode("aptus_equipment_templates.contract_copy");
local fixture = {}; for path, value in pairs(nodes) do fixture[path] = value; end
for path, value in pairs(fixture) do
    if path == clean.path or path:sub(1, #clean.path + 1) == clean.path .. "." then
        local target = targetCopy.path .. path:sub(#clean.path + 1);
        nodes[target] = { path = target, kind = value.kind, value = value.value, class = value.class };
    end
end
DB.setValue(targetCopy, "name", "string", nameBefore .. " Copia");
manager.onRecordAdded(targetCopy);
assert(DB.getChild(clean, "properties.qualities.unsupported"), "La copia modificó el original");
assert(not DB.getChild(targetCopy, "properties.qualities.unsupported"));
assert(not DB.getChild(targetCopy, "properties.profiles." .. childKey .. ".qualities.unsupported"));
assert(manager.getCopyProblem(clean, targetCopy) == nil);
assert(DB.getValue(targetCopy, "properties.qualities." .. kept .. ".quality_id", "") == "test:keep");
assert(DB.getValue(targetCopy, "template_version", 0) == 1);
-- Guardar sólo el objeto editado elimina entradas fuera del contrato.
commit(clean, filtered);
assert(not DB.getChild(clean, "properties.qualities.unsupported"));
assert(not DB.getChild(clean, "properties.profiles." .. childKey .. ".qualities.unsupported"));
assert(DB.getValue(clean, "name", "") == nameBefore);
assert(DB.getValue(clean, "properties.profiles." .. childKey .. ".damage", "") == damageBefore);
local invalid = manager.getDraft(clean);
invalid.collections.qualities.invalid = { quality_id = { kind = "string", value = "test:id" }, name = { kind = "string", value = "No permitido" } };
assert(manager.validateCollections(invalid.collections) ~= nil);
-- Riqueza opcional: ausencia equivale a falso sin escribir al consultar.
local wealthTemplate=newTemplate("wealth");
DB.deleteChild(wealthTemplate,"properties.is_wealth");
local wealthWrites=writes;
local wealthDraft=manager.getDraft(wealthTemplate);
assert(wealthDraft.is_wealth==0 and writes==wealthWrites);
assert(not DB.getChild(wealthTemplate,"properties.is_wealth"));
wealthDraft.is_wealth=1; commit(wealthTemplate,wealthDraft);
assert(DB.getValue(wealthTemplate,"properties.is_wealth",0)==1);
wealthDraft=manager.getDraft(wealthTemplate); wealthDraft.is_wealth=2;
wealthWrites=writes;
assert(not manager.save(wealthTemplate,wealthDraft,manager.getEditToken(wealthTemplate)));
assert(writes==wealthWrites);
print("OK: sistema único quality_id, guardado, copia, integridad, catálogo, multiclase e inaccesibles.");

-- Tipos de daño: persistencia de plantilla y compatibilidad con perfiles antiguos.
local damageTemplate=newTemplate("damage_types");
local damageDraft=manager.getDraft(damageTemplate);
local damageKey,damageProfile=manager.newProfile(damageDraft.collections.profiles);
damageProfile.damage_types=nil;
manager.setEntryValue(damageProfile,"damage","string","d6");
manager.setEntryValue(damageProfile,"critical","string","2d8");
commit(damageTemplate,damageDraft);
assert(not DB.getChild(damageTemplate,"properties.profiles."..damageKey..".damage_types"));
local damageWrites=writes;
damageDraft=manager.getDraft(damageTemplate);
assert(manager.formatProfileDamageTypes(damageDraft.collections.profiles[damageKey])=="Tipo: Nada" and writes==damageWrites);
manager.setProfileDamageType(damageDraft.collections.profiles[damageKey],"fire",true);
manager.setProfileDamageType(damageDraft.collections.profiles[damageKey],"slashing",true);
commit(damageTemplate,damageDraft);
assert(DB.getValue(damageTemplate,"properties.profiles."..damageKey..".damage_types.slashing")==1);
assert(DB.getValue(damageTemplate,"properties.profiles."..damageKey..".damage_types.fire")==1);
damageDraft=manager.getDraft(damageTemplate);
assert(manager.formatProfileDamageTypes(damageDraft.collections.profiles[damageKey])=="Tipos: Cortante, Fuego");
local damageBefore=manager.getEditToken(damageTemplate); damageWrites=writes;
manager.setProfileDamageType(damageDraft.collections.profiles[damageKey],"slashing",false);
-- Descartar es releer; el borrador no ha escrito nada.
assert(manager.getEditToken(damageTemplate)==damageBefore and writes==damageWrites);
damageDraft=manager.getDraft(damageTemplate);
assert(manager.hasProfileDamageType(damageDraft.collections.profiles[damageKey],"slashing"));
manager.setProfileDamageType(damageDraft.collections.profiles[damageKey],"slashing",false);
manager.setProfileDamageType(damageDraft.collections.profiles[damageKey],"fire",false);
commit(damageTemplate,damageDraft);
assert(not DB.getChild(damageTemplate,"properties.profiles."..damageKey..".damage_types"));
assert(DB.getValue(damageTemplate,"properties.profiles."..damageKey..".damage")=="d6");
assert(DB.getValue(damageTemplate,"properties.profiles."..damageKey..".critical")=="2d8");
damageDraft=manager.getDraft(damageTemplate);
damageDraft.collections.profiles[damageKey].damage_types={unknown={kind="number",value=1}};
damageWrites=writes;
assert(not manager.save(damageTemplate,damageDraft,manager.getEditToken(damageTemplate)) and writes==damageWrites);
print("OK: tipos de daño de plantilla, legado sin migración, guardado, descarte y campos de daño independientes.");

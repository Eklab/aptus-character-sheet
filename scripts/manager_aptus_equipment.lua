-- Catálogo de equipo y contrato común de perfiles. Sin mecánicas de daño.
local sType = "aptus_equipment";
local sRoot = "aptus_equipment_templates";
local sReference = "reference.aptus_equipment_templates";
local tTypes, tTypeOrder = {}, {};
local tWarnings = {};

local tFields = {
    { key = "name", path = "name", kind = "string", default = "Equipo nuevo" },
    { key = "description", path = "properties.description", kind = "string", default = "" },
    { key = "picture", path = "properties.picture", kind = "token", default = "" },
    { key = "type_id", path = "properties.type_id", kind = "string", default = "utility" },
    { key = "is_wealth", path = "properties.is_wealth", kind = "number", default = 0 },
    { key = "stackable", path = "properties.stackable", kind = "number", default = 0 },
    { key = "max_stack", path = "properties.max_stack", kind = "number", default = 1 },
    { key = "load_every", path = "properties.load_every", kind = "number", default = 1 },
    { key = "load_value", path = "properties.load_value", kind = "number", default = 0 },
    { key = "is_container", path = "properties.is_container", kind = "number", default = 0 },
    { key = "capacity", path = "properties.capacity", kind = "number", default = 0 },
    { key = "pro", path = "properties.defense.pro", kind = "number", default = 0 },
    { key = "def", path = "properties.defense.def", kind = "number", default = 0 },
    { key = "agi", path = "properties.defense.agi", kind = "number", default = 0 },
    { key = "per", path = "properties.defense.per", kind = "number", default = 0 },
    { key = "required_fue", path = "properties.required_fue", kind = "number", default = 0 },
    { key = "required_agi", path = "properties.required_agi", kind = "number", default = 0 },
};

-- Catálogo descriptivo único, en orden de presentación estable.
local tDamageTypes = {
    {id="bludgeoning", name="Contundente", abbreviation="CON"}, {id="slashing", name="Cortante", abbreviation="COR"},
    {id="piercing", name="Perforante", abbreviation="PER"}, {id="fire", name="Fuego", abbreviation="FUE"},
    {id="ice", name="Hielo", abbreviation="HIE"}, {id="electric", name="Eléctrico", abbreviation="ELE"},
    {id="chemical", name="Químico", abbreviation="QUI"}, {id="radiation", name="Radiación", abbreviation="RAD"},
    {id="supernatural", name="Sobrenatural", abbreviation="SOB"},
};
local tDamageTypeIds = {};
-- La carga inicial del script no dispone de ipairs; conservar el orden por índice.
for i = 1, #tDamageTypes do tDamageTypeIds[tDamageTypes[i].id] = true; end
function getDamageTypes()
    local result = {};
    for i = 1, #tDamageTypes do
        local entry = tDamageTypes[i];
        table.insert(result, {id=entry.id, name=entry.name, abbreviation=entry.abbreviation});
    end
    return result;
end
function hasProfileDamageType(profile, id)
    local types = profile and profile.damage_types;
    local value = type(types) == "table" and types[id];
    return type(value) == "table" and value.kind == "number" and value.value == 1;
end
function validateDamageTypes(types)
    if types == nil then return; end
    if type(types) ~= "table" or types.kind then return "Colección de tipos de daño no válida."; end
    for id, entry in pairs(types) do
        if not tDamageTypeIds[id] then return "Tipo de daño desconocido: " .. tostring(id); end
        if type(entry) ~= "table" or entry.kind ~= "number" or entry.value ~= 1 then
            return "La selección de tipo de daño debe ser un número uno: " .. id;
        end
        for key in pairs(entry) do
            if key ~= "kind" and key ~= "value" then return "Selección de daño con campos no admitidos: " .. id; end
        end
    end
end
-- Modifica sólo el árbol del borrador; nunca escribe en DB.
function setProfileDamageType(profile, id, selected)
    if type(profile) ~= "table" or not tDamageTypeIds[id] or type(selected) ~= "boolean"
        or validateDamageTypes(profile.damage_types) then return false; end
    if selected then
        profile.damage_types = profile.damage_types or {};
        profile.damage_types[id] = {kind="number", value=1};
    elseif profile.damage_types then
        profile.damage_types[id] = nil;
        if not next(profile.damage_types) then profile.damage_types = nil; end
    end
    return true;
end
function formatProfileDamageTypes(profile)
    local names = {};
    for i = 1, #tDamageTypes do
        local entry = tDamageTypes[i];
        if hasProfileDamageType(profile, entry.id) then table.insert(names, entry.name); end
    end
    return (#names > 1 and "Tipos: " or "Tipo: ") .. (#names > 0 and table.concat(names, ", ") or "Nada");
end

function getFields() return tFields; end
function registerType(sId, sName)
    if type(sId) ~= "string" or not sId:match("^[a-z][a-z0-9_]*$")
        or type(sName) ~= "string" or sName == "" or tTypes[sId] then return false; end
    tTypes[sId] = sName;
    table.insert(tTypeOrder, sId);
    return true;
end
function getTypes()
    local t = {};
    for _, sId in ipairs(tTypeOrder) do table.insert(t, { id = sId, name = tTypes[sId] }); end
    return t;
end
function getTypeName(sId) return tTypes[sId] or ("Tipo no registrado: " .. sId); end
function getProfileAmmunitionConsumption(profile)
    if getEntryValue(profile, "uses_ammunition", 0) ~= 1 then return 0; end
    return getEntryValue(profile, "ammunition_consumption", 1);
end
function formatProfileAmmunition(profile)
    if getEntryValue(profile, "uses_ammunition", 0) ~= 1 then return ""; end
    return "Munición: " .. tostring(getProfileAmmunitionConsumption(profile)) .. "/"
        .. tostring(getEntryValue(profile, "ammunition_max", 0));
end
function getAmmunitionOptions()
    local options = {};
    for _, option in ipairs(getCatalogueSelectionOptions()) do
        if matchesTypeFilter(DB.findNode(option.linkrecord), "ammunition") then table.insert(options, option); end
    end
    return options;
end
function getProfileAmmunitionName(profile)
    local reference = profile and profile.ammunition_template;
    if not reference then return "Sin asignar"; end
    if type(reference) ~= "table" or reference.kind ~= "windowreference" or reference.class ~= sType or type(reference.path) ~= "string" then return "Referencia incompatible"; end
    local node = DB.findNode(reference.path);
    if not node or not matchesTypeFilter(node, "ammunition") then return "Munición no disponible"; end
    return DB.getValue(node, "name", "Sin nombre");
end

-- Sólo visualización: Todos incluye registros sin tipo o con tipo desconocido.
function matchesTypeFilter(node, selected)
    if (selected or "") == "" then return true; end
    if not node or not tTypes[selected] then return false; end
    local child = DB.getChild(node, "properties.type_id");
    return child and DB.getType(child) == "string" and DB.getValue(child) == selected or false;
end
function openTemplateSelection(data)
    local window = Interface.openWindow("aptus_equipment_select_dialog", "");
    if window then window.requestSelectionByData(data); end
end
-- Lista visual del catálogo, no una autorización de alta. El gestor de inventario
-- mantiene todas sus validaciones al confirmar (incluidos tipos no compatibles).
function getCatalogueSelectionOptions()
    local options, seen = {}, {};
    local paths = RecordDataManager.getDataPaths(sType);
    for i = 1, #paths do
        for _, node in pairs(DB.getChildrenGlobal(paths[i])) do
            local path = DB.getPath(node);
            if not seen[path] then
                seen[path] = true;
                table.insert(options, { text=tostring(DB.getValue(node, "name", "")), linkclass=sType, linkrecord=path });
            end
        end
    end
    table.sort(options, function(a,b) return a.text == b.text and a.linkrecord < b.linkrecord or a.text < b.text; end);
    return options;
end

function canEdit(node)
    return Session.IsHost and node and (DB.getModule(node) or "") == ""
        and not DB.isReadOnly(node) and not WindowManager.getReadOnlyState(node)
        and RecordDataManager.getRecordTypeFromRecordPath(DB.getPath(node)) == sType;
end

-- Serialización ordenada para comparar datos completos, no hashes ni nombres.
local function encode(v)
    if type(v) ~= "table" then
        local s = tostring(v);
        if type(v) == "number" then
            -- DB usa números; Lua puede distinguir enteros de flotantes al imprimir.
            -- Representación round-trip: 0 y 0.0 iguales, sin redondeo deliberado.
            s = v == 0 and "0" or string.format("%.17g", v);
            -- No colapsar enteros de Lua que no sean representables como double.
            if tonumber(s) ~= v then s = tostring(v) .. "i"; end
        end
        return type(v) .. ":" .. #s .. ":" .. s;
    end
    local tKeys, t = {}, {};
    for k in pairs(v) do table.insert(tKeys, k); end
    table.sort(tKeys, function(a, b) return tostring(a) < tostring(b); end);
    for _, k in ipairs(tKeys) do table.insert(t, encode(k) .. encode(v[k])); end
    return "{" .. table.concat(t) .. "}";
end
local function readTree(node)
    if not node then return {}; end
    local t = {};
    for sName, child in pairs(DB.getChildren(node)) do
        local sKind = DB.getType(child);
        if sKind == "node" then
            local branch = readTree(child);
            -- Exportadores pueden omitir colecciones vacías: equivalen a ausentes.
            if next(branch) then t[sName] = branch; end
        elseif sKind == "windowreference" then
            local sClass, sPath = DB.getValue(child);
            t[sName] = { kind = sKind, class = sClass, path = sPath };
        else t[sName] = { kind = sKind, value = DB.getValue(child) }; end
    end
    return t;
end
local function snapshot(node)
    return { name = DB.getValue(node, "name", ""),
        properties = readTree(DB.getChild(node, "properties")) };
end
-- Comparación estructural estricta. Solo la representación entero/float de un
-- mismo número es equivalente; "10", 10 y true siguen siendo valores distintos.
local function firstDifference(expected, actual, path)
    if type(expected) ~= type(actual) then return path, expected, actual; end
    if type(expected) ~= "table" then
        if expected ~= actual then return path, expected, actual; end
        return;
    end
    local keys, seen = {}, {};
    for key in pairs(expected) do table.insert(keys, key); seen[key] = true; end
    for key in pairs(actual) do if not seen[key] then table.insert(keys, key); end end
    table.sort(keys, function(a, b)
        if tostring(a) == tostring(b) then return type(a) < type(b); end
        return tostring(a) < tostring(b);
    end);
    for _, key in ipairs(keys) do
        local sPath, before, after = firstDifference(expected[key], actual[key], path .. "." .. tostring(key));
        if sPath then return sPath, before, after; end
    end
end
local function diagnostic(node, phase, path, expected, actual)
    Debug.console("APTUS EQUIPO [" .. phase .. "] " .. DB.getPath(node)
        .. " | campo=" .. path .. " | esperado=" .. encode(expected)
        .. " | recuperado=" .. encode(actual));
end
local function verify(node, expected, phase)
    local path, before, after = firstDifference(expected, snapshot(node), "plantilla");
    if path then
        diagnostic(node, phase, path, before, after);
        error("Verificación fallida en " .. path);
    end
end
local function readCollections(node)
    return { qualities = readTree(DB.getChild(node, "properties.qualities")),
        profiles = readTree(DB.getChild(node, "properties.profiles")) };
end
-- Único formato admitido: una asociación contiene sólo un quality_id de texto.
-- Lo que no cumple este contrato se ignora, sin convertirlo en otra asociación.
local function referencesOnly(entries)
    local result = {};
    for key, entry in pairs(entries or {}) do
        if type(entry) == "table" and type(entry.quality_id) == "table"
            and entry.quality_id.kind == "string" and type(entry.quality_id.value) == "string"
            and entry.quality_id.value:match("%S") then
            local valid = true;
            for field in pairs(entry) do if field ~= "quality_id" then valid = false; end end
            for field in pairs(entry.quality_id) do if field ~= "kind" and field ~= "value" then valid = false; end end
            if valid then result[key] = entry; end
        end
    end
    return result;
end
function getCollections(node)
    local collections = readCollections(node);
    collections.qualities = referencesOnly(collections.qualities);
    for _, profile in pairs(collections.profiles) do
        if type(profile) == "table" and not profile.kind then
            local refs = referencesOnly(profile.qualities);
            profile.qualities = next(refs) and refs or nil;
        end
    end
    return collections;
end
-- Compatibilidad no destructiva: no inferir requisitos generales desde perfiles.
function getLegacyRequirements(node)
    local lines = {};
    for key, profile in pairs(DB.getChildren(node, "properties.profiles")) do
        local fue = DB.getValue(profile, "required_fue", 0);
        local agi = DB.getValue(profile, "required_agi", 0);
        if fue ~= 0 or agi ~= 0 then
            table.insert(lines, DB.getValue(profile, "name", key)
                .. ": FUE " .. tostring(fue) .. ", AGI " .. tostring(agi));
        end
    end
    if #lines == 0 then return nil; end
    table.sort(lines);
    return "Requisitos antiguos conservados en perfiles, sin uso funcional. No se han trasladado automáticamente."
        .. " El DJ decide los requisitos generales; estos valores quedan sólo como referencia.\n" .. table.concat(lines, "\n");
end
function getEntryValue(t, sKey, default)
    local field = t and t[sKey];
    if type(field) == "table" and field.kind then return field.value; end
    return default;
end
function setEntryValue(t, sKey, sKind, value)
    t[sKey] = { kind = sKind, value = value };
end
function newProfile(t)
    local n = 1;
    while t[string.format("entry_%04d", n)] do n = n + 1; end
    local key = string.format("entry_%04d", n);
    local entry = { damage_types={} };
    setEntryValue(entry, "ammunition_consumption", "number", 1);
    t[key] = entry;
    for k, v in pairs({ profile_id = key, name = "Perfil nuevo", attack_skill_id = "pelea",
        damage = "", critical = "", range = "" }) do setEntryValue(entry, k, "string", v); end
    for _, k in ipairs({ "attack_modifier", "uses_ammunition", "ammunition_max" }) do
        setEntryValue(entry, k, "number", 0);
    end
    return key, entry;
end
local function writeTree(node, t)
    if not node then error("No se pudo crear el nodo de colección"); end
    for key, value in pairs(t) do
        if value.kind == "windowreference" then DB.setValue(node, key, value.kind, value.class, value.path);
        elseif value.kind then DB.setValue(node, key, value.kind, value.value);
        else writeTree(DB.createChild(node, key), value); end
    end
end
local function replaceCollections(node, t)
    for _, key in ipairs({ "qualities", "profiles" }) do
        DB.deleteChild(node, "properties." .. key);
        writeTree(DB.createChild(node, "properties." .. key), t[key]);
    end
end
-- Ignorar nodos vacíos igual que readTree (el exportador puede omitirlos).
local function compact(t)
    local result = {};
    for key, value in pairs(t) do
        if value.kind then result[key] = value;
        else
            local branch = compact(value);
            if next(branch) then result[key] = branch; end
        end
    end
    return result;
end
local function validNumber(v, bInteger, bNonNegative)
    return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge
        and (not bInteger or v == math.floor(v)) and (not bNonNegative or v >= 0);
end
local function validateQualities(t)
    if type(t) ~= "table" or t.kind then return "Colección de cualidades no válida."; end
    local references = {};
    for _, entry in pairs(t) do
        if type(entry) ~= "table" or entry.kind then return "Cualidad no válida."; end
        if not next(referencesOnly({ ref = entry })) then return "Una asociación sólo admite quality_id de texto."; end
        local id = getEntryValue(entry, "quality_id", "");
        if references[id] then return "Una lista no puede repetir la misma referencia de cualidad."; end
        references[id] = true;
    end
end
function validateCollections(t)
    if type(t) ~= "table" or type(t.profiles) ~= "table" or t.profiles.kind then return "Colecciones no válidas."; end
    local problem = validateQualities(t.qualities);
    if problem then return problem; end
    local seen = {};
    for _, entry in pairs(t.profiles) do
        if type(entry) ~= "table" or entry.kind then return "Perfil no válido."; end
        local id, name = getEntryValue(entry, "profile_id", ""), getEntryValue(entry, "name", "");
        if type(id) ~= "string" or not id:match("%S") or seen[id] then return "Perfiles: ID obligatorio y único."; end
        seen[id] = true;
        if type(name) ~= "string" or not name:match("%S") then return "Cada perfil necesita nombre."; end
        local skill = getEntryValue(entry, "attack_skill_id", "pelea");
        if skill ~= "pelea" and skill ~= "punteria" then return "Habilidad de perfil no válida."; end
        if not validNumber(getEntryValue(entry, "attack_modifier", 0)) then return "Modificador de ataque no válido."; end
        for _, key in ipairs({ "ammunition_max" }) do
            if not validNumber(getEntryValue(entry, key, 0), true, true) then return "Debe ser entero no negativo: " .. key; end
        end
        local ammo = getEntryValue(entry, "uses_ammunition", 0);
        if ammo ~= 0 and ammo ~= 1 then return "Estado de munición no válido."; end
        local consumption = entry.ammunition_consumption;
        if consumption and (type(consumption) ~= "table" or consumption.kind ~= "number"
            or not validNumber(consumption.value, true, true)) then return "Consumo de munición no válido."; end
        if ammo == 1 and getProfileAmmunitionConsumption(entry) < 1 then return "El consumo debe ser un entero positivo."; end
        local reference = entry.ammunition_template;
        if reference then
            if type(reference) ~= "table" or reference.kind ~= "windowreference" or reference.class ~= sType
                or type(reference.path) ~= "string" or not reference.path:match("%S") then
                return "Referencia de munición no válida.";
            end
            for key in pairs(reference) do
                if key ~= "kind" and key ~= "class" and key ~= "path" then return "Referencia de munición con campos no admitidos."; end
            end
        end
        problem = validateDamageTypes(entry.damage_types);
        if problem then return problem; end
        problem = validateQualities(entry.qualities or {});
        if problem then return problem; end
    end
end
function fingerprint(node)
    return encode(snapshot(node));
end
function getEditToken(node)
    return encode({ id = DB.getValue(node, "template_id", ""),
        version = DB.getValue(node, "template_version", 0),
        schema = DB.getValue(node, "schema_version", 0), content = fingerprint(node) });
end
function getDraft(node)
    local t = {};
    for _, f in ipairs(tFields) do t[f.key] = DB.getValue(node, f.path, f.default); end
    t.collections = getCollections(node);
    return t;
end
function hasDraftChanges(node, draft)
    for _, f in ipairs(tFields) do
        if DB.getValue(node, f.path, f.default) ~= draft[f.key] then return true; end
    end
    return encode(compact(getCollections(node))) ~= encode(compact(draft.collections));
end
-- Marca privada de alta no confirmada, sin tocar propiedades ni versión exportables.
function isTemplateConfirmed(node)
    if not node or not DB.findNode(DB.getPath(node)) then return false; end
    local id = DB.getValue(node, "template_id", "");
    if id == "" then return false; end
    if (DB.getModule(node) or "") ~= "" then return true; end
    return DB.getValue("aptus_equipment_metadata", "unconfirmed." .. DB.getName(node), "") ~= id;
end
function confirmTemplateSaved(node)
    if not Session.IsHost or not node or (DB.getModule(node) or "") ~= "" then return; end
    if not isTemplateConfirmed(node) then
        DB.deleteChild("aptus_equipment_metadata", "unconfirmed." .. DB.getName(node));
        if not isTemplateConfirmed(node) then error("No se pudo confirmar el alta privada de la plantilla"); end
    end
end
function getCopyProblem(source, target)
    if DB.getValue(target, "template_id", "") == ""
        or DB.getValue(target, "template_id", "") == DB.getValue(source, "template_id", "") then return "Identidad de copia no válida."; end
    if DB.getValue(target, "template_version", 0) ~= 1 then return "La copia no comienza en versión 1."; end
    if DB.getValue(target, "schema_version", 0) ~= DB.getValue(source, "schema_version", 0) then return "Esquema de copia no válido."; end
    local expected = snapshot(source);
    local collections = getCollections(source);
    expected.properties.qualities = next(collections.qualities) and collections.qualities or nil;
    expected.properties.profiles = next(collections.profiles) and collections.profiles or nil;
    if expected.name ~= "" then expected.name = expected.name .. " " .. Interface.getString("masterindex_suffix_duplicate"); end
    -- El callback nativo de alta completa los campos aditivos ausentes en
    -- plantillas antiguas; comparar también esos valores predeterminados.
    for _, f in ipairs(tFields) do
        if not DB.getChild(source, f.path) then
            if f.key == "name" then expected.name = f.default;
            else
                local branch, parts = expected, {};
                for part in f.path:gmatch("[^.]+") do table.insert(parts, part); end
                for i = 1, #parts - 1 do branch[parts[i]] = branch[parts[i]] or {}; branch = branch[parts[i]]; end
                branch[parts[#parts]] = { kind = f.kind, value = f.default };
            end
        end
    end
    local path, before, after = firstDifference(expected, snapshot(target), "plantilla");
    if path then
        diagnostic(target, "copia", path, before, after);
        return "La copia no conserva todas las propiedades.";
    end
end
local function allTemplates()
    local t, seen = {}, {};
    for _, sPath in ipairs({ sRoot, sReference }) do
        for _, node in pairs(DB.getChildrenGlobal(sPath)) do
            local s = DB.getPath(node);
            if not seen[s] then table.insert(t, node); seen[s] = true; end
        end
    end
    return t;
end
function getConflict(node)
    local sId = DB.getValue(node, "template_id", "");
    local nVersion = DB.getValue(node, "template_version", 0);
    if sId == "" then return "Plantilla sin identidad APTUS; no se modifica automáticamente."; end
    if type(nVersion) ~= "number" or nVersion < 1 or nVersion ~= math.floor(nVersion) then return "Versión de plantilla no válida."; end
    local sContent = fingerprint(node);
    for _, other in ipairs(allTemplates()) do
        if DB.getPath(other) ~= DB.getPath(node)
            and DB.getValue(other, "template_id", "") == sId
            and DB.getValue(other, "template_version", 0) == nVersion
            and fingerprint(other) ~= sContent then
            return "Conflicto de ID/versión con " .. DB.getPath(other) .. ". No se fusiona ni corrige automáticamente.";
        end
    end
end
function audit()
    if not Session.IsHost then return; end
    for _, node in ipairs(allTemplates()) do
        local sProblem = getConflict(node);
        local sKey = DB.getPath(node) .. ":" .. (sProblem or "");
        if sProblem and not tWarnings[sKey] then
            tWarnings[sKey] = true;
            ChatManager.SystemMessage("APTUS EQUIPO: " .. sKey);
        end
    end
end

local function newId()
    local meta = DB.createNode("aptus_equipment_metadata");
    local sNamespace = DB.getValue(meta, "namespace", "");
    if sNamespace == "" then
        local t = {};
        for _ = 1, 32 do table.insert(t, string.format("%x", math.random(0, 15))); end
        sNamespace = "aptus_" .. tostring(os.time()) .. "_" .. table.concat(t);
        DB.setValue(meta, "namespace", "string", sNamespace);
    end
    local tUsed = {};
    for _, node in ipairs(allTemplates()) do tUsed[DB.getValue(node, "template_id", "")] = true; end
    local n = DB.getValue(meta, "sequence", 0);
    local sId;
    repeat n = n + 1; sId = sNamespace .. ":" .. tostring(n); until not tUsed[sId];
    DB.setValue(meta, "sequence", "number", n);
    return sId;
end

function onRecordAdded(node, _, bSubRecord)
    if not Session.IsHost or bSubRecord or not node or DB.isReadOnly(node)
        or (DB.getModule(node) or "") ~= "" then return; end
    local bIndependentCopy = DB.getValue(node, "template_id", "") ~= "";
    -- Alta y duplicación genéricas son plantillas nuevas; cargar módulos no llama aquí.
    for _, f in ipairs(tFields) do
        if not DB.getChild(node, f.path) then DB.setValue(node, f.path, f.kind, f.default); end
    end
    DB.createChild(node, "properties.qualities");
    DB.createChild(node, "properties.profiles");
    if bIndependentCopy then replaceCollections(node, getCollections(node)); end
    DB.setValue(node, "schema_version", "number", 1);
    DB.setValue(node, "template_id", "string", newId());
    DB.setValue(node, "template_version", "number", 1);
    if not bIndependentCopy then
        DB.setValue("aptus_equipment_metadata", "unconfirmed." .. DB.getName(node), "string", DB.getValue(node, "template_id", ""));
    end
end

function save(node, tDraft, sExpected)
    if not canEdit(node) then return false, "Sólo el DJ puede editar una plantilla de campaña desbloqueada."; end
    if DB.getValue(node, "schema_version", 0) ~= 1 then return false, "Esquema no compatible; no se sobrescribe."; end
    local sProblem = getConflict(node);
    if sProblem then return false, sProblem; end
    if getEditToken(node) ~= sExpected then return false, "Los datos cambiaron. Descartar y releer antes de editar."; end
    if type(tDraft.name) ~= "string" or not tDraft.name:match("%S") then return false, "El nombre es obligatorio."; end
    if not tTypes[tDraft.type_id] then return false, "Tipo de Equipo no registrado."; end
    for _, f in ipairs(tFields) do
        local v = tDraft[f.key];
        if f.kind == "number" then
            if type(v) ~= "number" or v ~= v or v == math.huge or v == -math.huge then return false, "Valor numérico no válido: " .. f.key; end
        elseif type(v) ~= "string" then return false, "Texto no válido: " .. f.key; end
    end
    for _, k in ipairs({ "stackable", "is_container", "is_wealth" }) do
        if tDraft[k] ~= 0 and tDraft[k] ~= 1 then return false, "Casilla no válida: " .. k; end
    end
    for _, k in ipairs({ "required_fue", "required_agi" }) do
        if type(tDraft[k]) ~= "number" or tDraft[k] < 0 or tDraft[k] ~= math.floor(tDraft[k]) then
            return false, "El requisito debe ser un entero no negativo: " .. k;
        end
    end
    for _, k in ipairs({ "max_stack", "load_every" }) do
        if tDraft[k] < 1 or tDraft[k] ~= math.floor(tDraft[k]) then return false, "Debe ser un entero positivo: " .. k; end
    end
    if tDraft.load_value < 0 or tDraft.capacity < 0 then return false, "CAR y capacidad no pueden ser negativas."; end
    if tDraft.is_container == 1 then tDraft.stackable = 0; tDraft.max_stack = 1; end
    local sCollectionError = validateCollections(tDraft.collections);
    if sCollectionError then return false, sCollectionError; end
    local tCollections = compact(tDraft.collections);
    local bChanged = false;
    for _, f in ipairs(tFields) do
        if DB.getValue(node, f.path, f.default) ~= tDraft[f.key] then bChanged = true; end
    end
    if encode(compact(readCollections(node))) ~= encode(tCollections) then bChanged = true; end
    if not bChanged then return true, "Sin cambios; versión conservada."; end
    local nVersion = DB.getValue(node, "template_version", 1);
    -- Predecir conflictos con otra distribución de la siguiente versión antes de escribir.
    local candidate = { name = tDraft.name, properties = readTree(DB.getChild(node, "properties")) };
    for _, f in ipairs(tFields) do
        if f.key ~= "name" then
            local branch, parts = candidate, {};
            for part in f.path:gmatch("[^.]+") do table.insert(parts, part); end
            for i = 1, #parts - 1 do
                branch[parts[i]] = branch[parts[i]] or {};
                branch = branch[parts[i]];
            end
            -- Un campo aditivo ausente con valor predeterminado no se escribe
            -- en el bucle de persistencia; tampoco debe inventarse en candidate.
            if DB.getChild(node, f.path) or tDraft[f.key] ~= f.default then
                branch[parts[#parts]] = { kind = f.kind, value = tDraft[f.key] };
            end
        end
    end
    candidate.properties.qualities = next(tCollections.qualities or {}) and tCollections.qualities or nil;
    candidate.properties.profiles = next(tCollections.profiles or {}) and tCollections.profiles or nil;
    candidate.properties = compact(candidate.properties);
    for _, other in ipairs(allTemplates()) do
        if DB.getPath(other) ~= DB.getPath(node)
            and DB.getValue(other, "template_id", "") == DB.getValue(node, "template_id", "")
            and DB.getValue(other, "template_version", 0) == nVersion + 1
            and fingerprint(other) ~= encode(candidate) then
            return false, "La siguiente versión entra en conflicto con " .. DB.getPath(other) .. ". No se guarda.";
        end
    end
    local previous = snapshot(node);
    local bOK, sError = pcall(function()
        for _, f in ipairs(tFields) do
            if DB.getValue(node, f.path, f.default) ~= tDraft[f.key] then DB.setValue(node, f.path, f.kind, tDraft[f.key]); end
            local actual = DB.getValue(node, f.path, f.default);
            if actual ~= tDraft[f.key] then
                diagnostic(node, "escritura", f.path, tDraft[f.key], actual);
                error("No se pudo escribir " .. f.key);
            end
        end
        replaceCollections(node, { qualities = tCollections.qualities or {}, profiles = tCollections.profiles or {} });
        verify(node, candidate, "verificación");
        DB.setValue(node, "template_version", "number", nVersion + 1);
        if DB.getValue(node, "template_version", 0) ~= nVersion + 1 then
            diagnostic(node, "versión", "template_version", nVersion + 1, DB.getValue(node, "template_version", 0));
            error("No se pudo escribir la versión");
        end
    end);
    if not bOK then
        Debug.console("APTUS EQUIPO [guardado rechazado] " .. DB.getPath(node) .. " | " .. tostring(sError));
        local bRestored, sRestoreError = pcall(function()
            DB.setValue(node, "template_version", "number", nVersion);
            -- Restaurar el snapshot tipado completo, no valores por defecto que
            -- podrían materializar campos antes ausentes o perder extensiones.
            DB.setValue(node, "name", "string", previous.name);
            DB.deleteChild(node, "properties");
            writeTree(DB.createChild(node, "properties"), previous.properties);
            verify(node, previous, "restauración");
            if DB.getValue(node, "template_version", 0) ~= nVersion then
                diagnostic(node, "restauración", "template_version", nVersion, DB.getValue(node, "template_version", 0));
                error("No se pudo restaurar la versión");
            end
        end);
        if not bRestored then Debug.console("APTUS EQUIPO [restauración fallida] " .. DB.getPath(node) .. " | " .. tostring(sRestoreError)); end
        return false, bRestored and "No se pudo guardar. Datos y versión anteriores restaurados y verificados. Detalle en consola; puedes conservar el borrador o releer."
            or "No se pudo guardar ni verificar la restauración. Revisar el registro y la consola con el DJ.";
    end
    audit();
    return true, "Cambios guardados; versión incrementada una vez.";
end

function onInit()
    registerType("melee_weapon", "Arma CC");
    registerType("ranged_weapon", "Arma de proyectiles");
    registerType("utility", "Utilidad");
    registerType("electronic", "Electrónico");
    registerType("storage", "Almacenaje");
    registerType("protection", "Protección");
    registerType("electromechanical_system", "Sistema electrónico/mecánico");
    registerType("ammunition", "Munición");
    RecordDataManager.setRecordTypeData(sType, {
        aDataMap = { sRoot, sReference }, sRecordDisplayClass = sType,
        sSidebarCategory = "create", tOptions = { bExport = true },
    });
    RecordManager.setRecordAddCallback(sType, onRecordAdded);
end
function onTabletopInit()
    RecordDataManager.setHidden("item", true);
    if Session.IsHost then DB.createNode(sRoot); end
    Module.addEventHandler("onModuleLoad", audit);
    audit();
end
function onClose()
    Module.removeEventHandler("onModuleLoad", audit);
end

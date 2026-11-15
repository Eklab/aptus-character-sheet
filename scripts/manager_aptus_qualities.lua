-- Definiciones únicas y referencias por ID. Sin reglas de combate ni efectos.
local sType, sRoot, sRef = "aptus_quality", "aptus_qualities", "reference.aptus_qualities";
local tTypes, tOrder, tListeners, tWarnings = {}, {}, {}, {};
local tReferenceRoots = { "aptus_equipment_templates", "reference.aptus_equipment_templates", "charsheet", "aptus_structures" };
local sMissing = "No se encuentra la definición de esta cualidad. Comprueba que el módulo correspondiente esté activado";
function registerType(id, name)
    if not id:match("^[a-z][a-z0-9_]*$") or tTypes[id] then return false; end
    tTypes[id] = name; table.insert(tOrder, id); return true;
end
function getTypes()
    local result = {};
    for _, id in ipairs(tOrder) do table.insert(result, { id = id, name = tTypes[id] }); end
    return result;
end
function registerReferenceRoot(path) table.insert(tReferenceRoots, path); end
function getDefinitions()
    local result, seen = {}, {};
    for _, path in ipairs({ sRoot, sRef }) do
        for _, node in pairs(DB.getChildrenGlobal(path)) do
            if not seen[DB.getPath(node)] then seen[DB.getPath(node)] = true; table.insert(result, node); end
        end
    end
    return result;
end
function resolve(id)
    local found;
    for _, node in ipairs(getDefinitions()) do
        if DB.getValue(node, "quality_id", "") == id then
            if found then
                if not tWarnings[id] then
                    tWarnings[id] = true;
                    Debug.console("APTUS CUALIDADES: ID duplicado " .. id .. " | " .. DB.getPath(found) .. " | " .. DB.getPath(node));
                    if Session.IsHost then ChatManager.SystemMessage("CUALIDADES: conflicto de identificador " .. id .. ". No se resuelve de forma ambigua."); end
                end
                return nil;
            end
            found = node;
        end
    end
    if not found and not tWarnings["missing:" .. id] then
        tWarnings["missing:" .. id] = true;
        Debug.console("APTUS CUALIDADES: definición inaccesible | quality_id=" .. id);
    end
    return found;
end
function canEdit(node)
    return Session.IsHost and node and (DB.getModule(node) or "") == "" and not DB.isReadOnly(node)
        and not WindowManager.getReadOnlyState(node)
        and RecordDataManager.getRecordTypeFromRecordPath(DB.getPath(node)) == sType;
end
function typeValues(node)
    local result = {};
    for id in DB.getValue(node, "types", ""):gmatch("[^|]+") do table.insert(result, tTypes[id] or id); end
    return result;
end
function getDraft(node)
    local types = {};
    for id in DB.getValue(node, "types", ""):gmatch("[^|]+") do types[id] = true; end
    return { name = DB.getValue(node, "name", ""), description = DB.getValue(node, "description", ""), types = types };
end
function token(node)
    local values = {};
    for _, key in ipairs({ "quality_id", "name", "description", "types" }) do
        local v = DB.getValue(node, key, ""); table.insert(values, #v .. ":" .. v);
    end
    return table.concat(values, "|");
end
function save(node, draft, expected)
    if not canEdit(node) then return false, "Sólo el DJ puede editar una cualidad de campaña desbloqueada."; end
    if token(node) ~= expected then return false, "La definición cambió; cerrar y reabrir antes de guardar."; end
    if DB.getValue(node, "quality_id", "") == "" then return false, "La cualidad no tiene identidad válida."; end
    if not draft.name:match("%S") then return false, "El nombre es obligatorio."; end
    local ids = {};
    for id, enabled in pairs(draft.types) do if enabled then table.insert(ids, id); end end
    table.sort(ids);
    local previous = getDraft(node);
    local previousTypes = DB.getValue(node, "types", "");
    local ok, err = pcall(function()
        DB.setValue(node, "name", "string", draft.name);
        DB.setValue(node, "description", "string", draft.description);
        DB.setValue(node, "types", "string", table.concat(ids, "|"));
        if DB.getValue(node, "name", "") ~= draft.name or DB.getValue(node, "description", "") ~= draft.description
            or DB.getValue(node, "types", "") ~= table.concat(ids, "|") then error("No se pudo verificar la definición"); end
    end);
    if not ok then
        local restored = pcall(function()
            DB.setValue(node, "name", "string", previous.name);
            DB.setValue(node, "description", "string", previous.description);
            DB.setValue(node, "types", "string", previousTypes);
            if token(node) ~= expected then error("Restauración no verificada"); end
        end);
        Debug.console("APTUS CUALIDADES [guardar] " .. tostring(err));
        return false, restored and "No se pudo guardar; datos anteriores restaurados." or "No se pudo verificar la restauración; revisar consola.";
    end
    notify();
    return true;
end
function onRecordAdded(node)
    if not Session.IsHost or not node or (DB.getModule(node) or "") ~= "" or DB.isReadOnly(node) then return; end
    local meta = DB.createNode("aptus_quality_metadata");
    local ns = DB.getValue(meta, "namespace", "");
    if ns == "" then
        local parts = {};
        for _ = 1, 32 do table.insert(parts, string.format("%x", math.random(0, 15))); end
        ns = "aptus_quality_" .. tostring(os.time()) .. "_" .. table.concat(parts);
        DB.setValue(meta, "namespace", "string", ns);
    end
    local used = {};
    for _, other in ipairs(getDefinitions()) do used[DB.getValue(other, "quality_id", "")] = true; end
    local n, id = DB.getValue(meta, "sequence", 0), nil;
    repeat n = n + 1; id = ns .. ":" .. tostring(n); until not used[id];
    DB.setValue(meta, "sequence", "number", n);
    DB.setValue(node, "quality_id", "string", id);
    if not DB.getChild(node, "name") then DB.setValue(node, "name", "string", "Cualidad nueva"); end
    if not DB.getChild(node, "description") then DB.setValue(node, "description", "string", ""); end
    if not DB.getChild(node, "types") then DB.setValue(node, "types", "string", ""); end
end
function countReferences(id)
    local count, seen = 0, {};
    for _, root in ipairs(tReferenceRoots) do
        local stack = {};
        for _, node in pairs(DB.getChildrenGlobal(root)) do table.insert(stack, node); end
        while #stack > 0 do
            local node = table.remove(stack);
            if not seen[DB.getPath(node)] then
                seen[DB.getPath(node)] = true;
                if DB.getValue(node, "quality_id", "") == id then count = count + 1; end
                for _, child in pairs(DB.getChildren(node)) do if DB.getType(child) == "node" then table.insert(stack, child); end end
            end
        end
    end
    return count;
end
function requestDelete(node)
    if not canEdit(node) then ChatManager.SystemMessage("Desbloquear una cualidad de campaña como DJ para borrarla."); return; end
    local path, id = DB.getPath(node), DB.getValue(node, "quality_id", "");
    local count = countReferences(id);
    DialogManager.openDialog("dialog_okcancel", {
        sTitle = "Borrar cualidad",
        sText = "¿Borrar esta definición? Referencias conocidas: " .. tostring(count)
            .. ". No se eliminarán las asociaciones: pasarán a Cualidad inaccesible. Las referencias de módulos no cargados no pueden contarse.",
        fnCallback = function(result)
            local current = DB.findNode(path);
            if result ~= "ok" or not canEdit(current) or DB.getValue(current, "quality_id", "") ~= id then return; end
            if countReferences(id) > count then requestDelete(current); return; end
            DB.deleteNode(current); notify();
        end,
    });
end
function subscribe(fn) tListeners[fn] = true; end
function unsubscribe(fn) tListeners[fn] = nil; end
function notify()
    local listeners = {}; for fn in pairs(tListeners) do table.insert(listeners, fn); end
    for _, fn in ipairs(listeners) do if tListeners[fn] then fn(); end end
end
function onModulesChanged()
    local seen = {};
    for _, node in ipairs(getDefinitions()) do
        local id = DB.getValue(node, "quality_id", "");
        if id ~= "" and not seen[id] then seen[id] = true; resolve(id); end
    end
    notify();
end
function describe(entry)
    local id = APTUSEquipmentManager.getEntryValue(entry, "quality_id", "");
    local node = resolve(id);
    if not node then return "Cualidad inaccesible", sMissing, nil; end
    return DB.getValue(node, "name", ""), DB.getValue(node, "description", ""), node;
end
function summary(entries)
    local keys, names = {}, {};
    for key in pairs(entries or {}) do table.insert(keys, key); end
    table.sort(keys);
    for _, key in ipairs(keys) do local name = describe(entries[key]); table.insert(names, name); end
    return table.concat(names, ", ");
end
function details(entries)
    local keys, parts = {}, {};
    for key in pairs(entries or {}) do table.insert(keys, key); end
    table.sort(keys);
    for _, key in ipairs(keys) do
        local name, description = describe(entries[key]);
        table.insert(parts, name .. "\n" .. description);
    end
    return table.concat(parts, "\n\n");
end
function clone(entries)
    local result = {};
    for key, value in pairs(entries) do result[key] = type(value) == "table" and clone(value) or value; end
    return result;
end
function associationToken(entries)
    local keys, parts = {}, {};
    for key in pairs(entries) do table.insert(keys, key); end
    table.sort(keys);
    for _, key in ipairs(keys) do
        local value = entries[key];
        local s = type(value) == "table" and associationToken(value) or tostring(value);
        table.insert(parts, #key .. ":" .. key .. #s .. ":" .. s);
    end
    return table.concat(parts, "|");
end
function addFromDrop(entries, draginfo)
    if draginfo.getType() ~= "shortcut" then return false; end
    local class, path = draginfo.getShortcutData();
    if not RecordDataManager.isRecordTypeDisplayClass(sType, class) then return false; end
    local node = DB.findNode(path);
    if not node then return false; end
    if RecordDataManager.getRecordTypeFromRecordPath(path) ~= sType then return false; end
    local id = DB.getValue(node, "quality_id", "");
    if id == "" or not resolve(id) then return false; end
    for _, entry in pairs(entries) do if APTUSEquipmentManager.getEntryValue(entry, "quality_id", "") == id then return false; end end
    local n = 1; while entries[string.format("ref_%04d", n)] do n = n + 1; end
    entries[string.format("ref_%04d", n)] = { quality_id = { kind = "string", value = id } };
    return true;
end
function onInit()
    for _, entry in ipairs({ { "character", "Personaje" }, { "equipment", "Equipo" }, { "melee", "Armas CC" },
        { "ranged", "Armas de proyectiles" }, { "location", "Localizaciones" }, { "vehicle", "Vehículos" } }) do registerType(entry[1], entry[2]); end
    RecordDataManager.setRecordTypeData(sType, { aDataMap = { sRoot, sRef }, sRecordDisplayClass = sType,
        sListDisplayClass = "aptus_quality_indexrow", sSidebarCategory = "create", tOptions = { bExport = true },
        aCustomFilters = { Tipo = { sField = "types", fGetValue = typeValues } },
    });
    RecordManager.setRecordAddCallback(sType, onRecordAdded);
end
function onTabletopInit()
    if Session.IsHost then DB.createNode(sRoot); end
    Module.addEventHandler("onModuleLoad", onModulesChanged); Module.addEventHandler("onModuleUnload", onModulesChanged);
    for _, root in ipairs({ sRoot, sRef }) do
        for _, event in ipairs({ "onChildUpdate", "onChildAdded", "onChildDeleted" }) do DB.addHandler(root, event, notify); end
        for _, pattern in ipairs({ ".*.", ".*@*." }) do
            for _, field in ipairs({ "name", "description", "types", "quality_id" }) do DB.addHandler(root .. pattern .. field, "onUpdate", notify); end
        end
    end
    onModulesChanged();
end
function onClose()
    Module.removeEventHandler("onModuleLoad", onModulesChanged); Module.removeEventHandler("onModuleUnload", onModulesChanged);
    for _, root in ipairs({ sRoot, sRef }) do
        for _, event in ipairs({ "onChildUpdate", "onChildAdded", "onChildDeleted" }) do DB.removeHandler(root, event, notify); end
        for _, pattern in ipairs({ ".*.", ".*@*." }) do
            for _, field in ipairs({ "name", "description", "types", "quality_id" }) do DB.removeHandler(root .. pattern .. field, "onUpdate", notify); end
        end
    end
end

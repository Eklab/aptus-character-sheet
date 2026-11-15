-- Diagnóstico temporal y local al anfitrión. Sin reparaciones ni escrituras DB.
function onInit()
    Comm.registerSlashHandler("aptus_inventory_debug", processCommand, "[charsheet.<id>]");
end

local function report(message)
    Comm.addChatMessage({ text = "[APTUS inventario] " .. message });
end

local function describe(node, path)
    local child = DB.getChild(node, path);
    if not child then return path .. ": existe=no; tipo=<ausente>; valor=<ausente>"; end
    local kind = DB.getType(child);
    local value = "<sin valor escalar>";
    if kind == "string" or kind == "number" then
        value = string.format("%q", tostring(DB.getValue(child)));
    end
    return path .. ": existe=sí; tipo=" .. tostring(kind) .. "; valor=" .. value;
end

local function orderedChildren(node)
    local result = {};
    if node then
        for _, child in pairs(DB.getChildren(node)) do table.insert(result, child); end
    end
    table.sort(result, function(a, b) return DB.getPath(a) < DB.getPath(b); end);
    return result;
end

function processCommand(_, params)
    if not Session.IsHost then
        report("Ejecuta este diagnóstico desde el anfitrión.");
        return;
    end
    local path = StringManager.trim(params or "");
    if path == "" then
        report("No se presupone un personaje activo. Uso: /aptus_inventory_debug charsheet.<id>");
        local characters = orderedChildren(DB.findNode("charsheet"));
        for i = 1, #characters do
            local node = characters[i];
            report(DB.getPath(node) .. " | " .. describe(node, "name"));
        end
        if #characters == 0 then report("No hay personajes disponibles."); end
        return;
    end
    if not path:match("^charsheet%.[^.@]+$") then
        report("Ruta no válida: indica únicamente charsheet.<id>, sin subnodos ni módulos.");
        return;
    end
    local character = DB.findNode(path);
    if not character or DB.getType(character) ~= "node" then
        report("El personaje indicado no existe o no es un registro.");
        return;
    end
    report("Personaje: " .. path .. " | " .. describe(character, "name"));
    local list = DB.getChild(character, "inventorylist");
    if list and DB.getType(list) ~= "node" then
        report("inventorylist existe pero no es una colección; tipo=" .. tostring(DB.getType(list)));
        return;
    end
    local nodes = orderedChildren(list);
    local recognized = 0;
    for i = 1, #nodes do
        local node = nodes[i];
        local valid, reason = APTUSInventoryManager.isInstance(node);
        if valid then recognized = recognized + 1; end
        report("Nodo: " .. DB.getPath(node));
        report(describe(node, "name"));
        report(describe(node, "aptus.container"));
        report(describe(node, "properties.is_container"));
        report("isInstance=" .. tostring(valid) .. "; motivo=" .. (reason or "Aceptado"));
    end
    report("Total=" .. #nodes .. "; reconocidos por isInstance=" .. recognized
        .. "; rechazados por isInstance=" .. (#nodes - recognized));
    local inventory = APTUSInventoryManager.getCharacterInventory(character);
    report("Lector real: incluidos=" .. #inventory.items .. "; omitidos=" .. inventory.ignored);
    for i = 1, #inventory.diagnostics do report("Lector: " .. inventory.diagnostics[i]); end
    if not list then report("inventorylist ausente (no se ha creado)."); end
end

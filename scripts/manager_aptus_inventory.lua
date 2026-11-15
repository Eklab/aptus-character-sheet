-- Modelo común: lectura, propiedades, unidades/apilamiento, traslados y borrado confirmado en UI.
local nSchema = 1;
local tIcons = {
    ammunition = "aptus_utilidad_item",
    melee_weapon = "aptus_arma_cc_item", ranged_weapon = "aptus_arma_proy_item",
    utility = "aptus_utilidad_item", electronic = "aptus_electrico_item",
    storage = "aptus_contenedor_item", protection = "aptus_proteccion_item",
    electromechanical_system = "aptus_mecanico_electrico_item",
};
local tStates = { [0] = "Sin equipar", [1] = "Transportado", [2] = "Equipado" };

local function field(node, path, kind)
    local child = DB.getChild(node, path);
    if not child or DB.getType(child) ~= kind then return nil; end
    return DB.getValue(child);
end
-- Un padre ausente equivale a raíz; un nodo presente de otro tipo sigue siendo incompatible.
-- Normalización exclusivamente en memoria: nunca materializa el campo en DB.
local function containerId(node)
    local child = DB.getChild(node, "aptus.container");
    if not child then return ""; end
    if DB.getType(child) ~= "string" then return nil; end
    return DB.getValue(child);
end
local function integer(value, minimum)
    return type(value) == "number" and value == value and value < math.huge
        and value >= minimum and value == math.floor(value);
end
local function text(value)
    return type(value) == "string" and value:match("%S") ~= nil;
end

-- Lectura por pila, nunca agregada por tipo ni escrita de vuelta a DB.
function getStackLoad(node)
    local count = field(node, "count", "number");
    local every = field(node, "properties.load_every", "number");
    local load = field(node, "properties.load_value", "number");
    if not integer(count, 1) or not integer(every, 1) or type(load) ~= "number"
        or load ~= load or load < 0 or load == math.huge then return nil; end
    local result = math.ceil(count / every) * load;
    return result < math.huge and result or nil;
end

local function capacityValue(item)
    local entry = item.properties and item.properties.capacity;
    local value = entry and entry.kind == "number" and entry.value or nil;
    if type(value) == "number" and value == value and value >= 0 and value < math.huge then return value; end
end

-- Postorden iterativo: los hijos aportan CAR íntegra, sin encadenar Almacenaje.
-- Sólo un contenedor raíz puede reducir su contenido. Todo queda en el snapshot.
local function calculateContainerLoads(result, rawNodes)
    local byId, pending, accumulated, unknown, queue = {}, {}, {}, {}, {};
    for _, item in ipairs(result.items) do
        byId[item.id] = item;
        pending[item.id], accumulated[item.id] = #item.children, 0;
        if #item.children == 0 then table.insert(queue, item); end
    end
    -- Un hijo rechazado no debe aparentar contenido cero en su padre válido.
    for _, node in ipairs(rawNodes) do
        if not byId[DB.getName(node)] then
            local parent = containerId(node);
            if parent and byId[parent] then unknown[parent] = true; end
        end
    end
    local index = 1;
    while index <= #queue do
        local item = queue[index]; index = index + 1;
        local gross = item.own_load;
        if item.is_container then
            item.capacity_load = capacityValue(item);
            if not unknown[item.id] then item.content_load = accumulated[item.id]; end
            item.overloaded = item.content_load ~= nil and item.capacity_load ~= nil
                and item.content_load > item.capacity_load;
            if item.content_load == nil or gross == nil then gross = nil;
            else gross = gross + item.content_load; end
        end
        if gross and gross >= math.huge then gross = nil; end
        item.gross_load = gross;
        item.reduction_active = item.is_container and item.parent_id == "";
        local effective = gross;
        if item.reduction_active then
            if item.content_load == nil then effective = nil;
            elseif item.content_load == 0 then effective = item.own_load;
            elseif item.capacity_load == nil then effective = nil;
            elseif item.content_load <= item.capacity_load then effective = item.own_load; end
        end
        item.effective_load = effective;
        item.load = effective or "—";
        local parent = byId[item.parent_id];
        if parent then
            if gross == nil then unknown[parent.id] = true;
            else
                accumulated[parent.id] = accumulated[parent.id] + gross;
                if accumulated[parent.id] >= math.huge then unknown[parent.id] = true; end
            end
            pending[parent.id] = pending[parent.id] - 1;
            if pending[parent.id] == 0 then table.insert(queue, parent); end
        end
    end
    local total, complete = 0, result.ignored == 0 and #queue == #result.items;
    for _, item in ipairs(result.roots) do
        if item.carried ~= 0 then
            if item.effective_load == nil then complete = false;
            else total = total + item.effective_load; end
        end
    end
    if total >= math.huge then complete = false; end
    result.load_complete = complete;
    result.total_load = complete and total or nil;
end

function getBaseLoadCapacity(strength)
    if type(strength) ~= "number" or strength ~= strength or strength < 0 or strength == math.huge then return nil; end
    local capacity = 2 + strength * 2;
    return capacity < math.huge and capacity or nil;
end
function getLoadCapacity(character)
    -- Punto único de extensión futura para ambientaciones/cualidades. Sin modificadores hoy.
    if not character then return nil; end
    return getBaseLoadCapacity(field(character, "attributes.fue.effective", "number"));
end
function getLoadStatus(character, inventory)
    inventory = inventory or getCharacterInventory(character);
    local capacity, total = getLoadCapacity(character), inventory.total_load;
    local result = { capacity=capacity, total_load=total, complete=false, fraction=0 };
    if capacity == nil or total == nil or inventory.load_complete == false then return result; end
    result.complete = true;
    local ratio = total / capacity;
    result.fraction = math.min(1, ratio / 2);
    if ratio < 0.5 then result.state, result.color, result.skin = "LIGERO", "FF6EA66F", 0;
    elseif ratio < 1 then result.state, result.color, result.skin = "CARGADO", "FF6EA66F", 50;
    elseif ratio < 1.5 then result.state, result.color, result.skin = "SOBRECARGADO", "FFE5CE36", 100;
    elseif ratio < 2 then result.state, result.color, result.skin = "LASTRADO", "FFE59A36", 150;
    else result.state, result.color, result.skin = "INMOVILIZADO", "FFFF4040", 200; end
    local gender = field(character, "gender", "string") or "";
    gender = gender:match("^%s*(.-)%s*$"):lower();
    result.icon = "aptus_load_" .. (gender == "femenino" and "female_" or "male_") .. result.skin;
    return result;
end

-- No rellena valores ausentes: un inventario nativo no se convierte en APTUS.
function isInstance(node)
    if not node or DB.getType(node) ~= "node" then return false, "Registro no válido"; end
    if field(node, "aptus.instance_schema", "number") ~= nSchema then
        return false, "Sin contrato de instancia APTUS 1";
    end
    if not text(field(node, "name", "string")) then return false, "Nombre no válido"; end
    if not integer(field(node, "count", "number"), 1) then return false, "Cantidad no válida"; end
    local carried = field(node, "carried", "number");
    if not integer(carried, 0) or not tStates[carried] then return false, "Estado no válido"; end
    if not text(field(node, "template_id", "string"))
        or not integer(field(node, "template_version", "number"), 1) then
        return false, "Procedencia incompleta";
    end
    local properties = DB.getChild(node, "properties");
    if not properties or DB.getType(properties) ~= "node" then return false, "Propiedades ausentes"; end
    if not tIcons[field(node, "properties.type_id", "string")] then return false, "Tipo no compatible"; end
    local container = field(node, "properties.is_container", "number");
    if container ~= 0 and container ~= 1 then return false, "Indicador de contenedor no válido"; end
    if container == 1 and field(node, "count", "number") ~= 1 then return false, "Contenedor con cantidad distinta de uno"; end
    if containerId(node) == nil then return false, "Relación de contención de tipo incompatible"; end
    return true;
end

-- Snapshot de propiedades: conserva los tipos DB, incluidas las referencias.
-- No resuelve plantillas ni cualidades ni materializa campos predeterminados.
local function readProperties(node)
    local result = {};
    for key, child in pairs(DB.getChildren(node)) do
        local kind = DB.getType(child);
        if kind == "node" then result[key] = readProperties(child);
        elseif kind == "windowreference" then
            local class, path = DB.getValue(child);
            result[key] = { kind = kind, class = class, path = path };
        else result[key] = { kind = kind, value = DB.getValue(child) }; end
    end
    return result;
end

function getCharacterInventory(nodeChar)
    local result = { roots = {}, items = {}, diagnostics = {}, ignored = 0, total_load = 0, load_complete = true };
    if not nodeChar or not DB.getPath(nodeChar):match("^charsheet%.[^.@]+$") then
        table.insert(result.diagnostics, "Se requiere un personaje de campaña");
        result.total_load, result.load_complete = nil, false;
        return result;
    end
    local list = DB.getChild(nodeChar, "inventorylist");
    if not list then return result; end
    if DB.getType(list) ~= "node" then
        table.insert(result.diagnostics, "inventorylist no es una colección");
        result.total_load, result.load_complete = nil, false;
        return result;
    end
    local nodes = {};
    for _, node in pairs(DB.getChildren(list)) do table.insert(nodes, node); end
    table.sort(nodes, function(a, b) return DB.getName(a) < DB.getName(b); end);
    local byId, candidates = {}, {};
    local function reject(id, reason)
        result.ignored = result.ignored + 1;
        table.insert(result.diagnostics, id .. ": " .. reason);
    end
    for _, node in ipairs(nodes) do
        local valid, reason = isInstance(node);
        local id = DB.getName(node);
        if valid then
            local item = {
                id = id, node = node, path = DB.getPath(node),
                name = field(node, "name", "string"), count = field(node, "count", "number"),
                carried = field(node, "carried", "number"),
                template_id = field(node, "template_id", "string"),
                template_version = field(node, "template_version", "number"),
                properties = readProperties(DB.getChild(node, "properties")),
                parent_id = containerId(node),
                is_container = field(node, "properties.is_container", "number") == 1,
                hide_contents = field(node, "properties.is_container", "number") == 1
                    and field(node, "properties.hide_contents", "number") == 1,
                is_wealth = field(node, "properties.is_wealth", "number") == 1,
                icon = tIcons[field(node, "properties.type_id", "string")],
                children = {}, own_load = getStackLoad(node), load = "—", group = 2,
            };
            byId[id] = item;
            table.insert(candidates, item);
        else reject(id, reason); end
    end
    -- Resolución iterativa: ni profundidad artificial ni recursión sobre ciclos.
    -- Un vínculo inválido invalida también su rama; nunca se inventa otra raíz.
    for _, item in ipairs(candidates) do
        if not item.checked then
            local chain, seen, cursor = {}, {}, item;
            local root, problem;
            while cursor and not cursor.checked do
                if seen[cursor.id] then problem = "Ciclo de contención"; break; end
                seen[cursor.id] = true;
                table.insert(chain, cursor);
                if cursor.parent_id == "" then root = cursor; break; end
                local parent = byId[cursor.parent_id];
                if not parent then problem = "Contenedor inexistente o incompatible: " .. cursor.parent_id; break; end
                if not parent.is_container then problem = "El padre no es un contenedor: " .. parent.id; break; end
                cursor = parent;
            end
            if cursor and cursor.checked then root, problem = cursor.root, cursor.problem; end
            for _, entry in ipairs(chain) do
                entry.checked, entry.root, entry.problem = true, root, problem;
            end
        end
    end
    for _, item in ipairs(candidates) do
        if item.problem then reject(item.id, item.problem);
        else
            item.visible_to_user = true;
            if not (Session and Session.IsHost) then
                local ancestor = byId[item.parent_id];
                while ancestor do
                    if ancestor.hide_contents then item.visible_to_user = false; break; end
                    ancestor = byId[ancestor.parent_id];
                end
            end
            item.root_id = item.root.id;
            item.effective_carried = item.parent_id == "" and item.carried or 0;
            item.state = item.parent_id == "" and tStates[item.carried] or "Contenido";
            item.location = item.parent_id == "" and "-" or byId[item.parent_id].name;
            table.insert(result.items, item);
            if item.parent_id == "" then table.insert(result.roots, item);
            else table.insert(byId[item.parent_id].children, item); end
        end
    end
    calculateContainerLoads(result, nodes);
    -- No expone las referencias circulares usadas sólo al resolver el grafo.
    for _, item in ipairs(result.items) do item.checked, item.root = nil, nil; end
    return result;
end

-- Fase 2: creación desde plantilla y propiedades particulares; estructura protegida.
local tEditableFields = {
    { key="name", path="name", kind="string", default="" },
    { key="type_id", path="properties.type_id", kind="string", default="utility" },
    { key="stackable", path="properties.stackable", kind="number", default=0 },
    { key="max_stack", path="properties.max_stack", kind="number", default=1 },
    { key="is_container", path="properties.is_container", kind="number", default=0 },
    { key="is_wealth", path="properties.is_wealth", kind="number", default=0 },
    { key="hide_contents", path="properties.hide_contents", kind="number", default=0 },
    { key="description", path="properties.description", kind="string", default="" },
    { key="picture", path="properties.picture", kind="token", default="" },
    { key="load_every", path="properties.load_every", kind="number", default=1 },
    { key="load_value", path="properties.load_value", kind="number", default=0 },
    { key="capacity", path="properties.capacity", kind="number", default=0 },
    { key="pro", path="properties.defense.pro", kind="number", default=0 },
    { key="def", path="properties.defense.def", kind="number", default=0 },
    { key="agi", path="properties.defense.agi", kind="number", default=0 },
    { key="per", path="properties.defense.per", kind="number", default=0 },
    { key="required_fue", path="properties.required_fue", kind="number", default=0 },
    { key="required_agi", path="properties.required_agi", kind="number", default=0 },
};

local function encode(value)
    if type(value) ~= "table" then
        local s = type(value) == "number" and string.format("%.17g", value) or tostring(value);
        return type(value) .. ":" .. #s .. ":" .. s;
    end
    local keys, parts = {}, {};
    for key in pairs(value) do table.insert(keys, key); end
    table.sort(keys, function(a,b) return tostring(a) < tostring(b); end);
    for _, key in ipairs(keys) do table.insert(parts, encode(key) .. encode(value[key])); end
    return "{" .. table.concat(parts) .. "}";
end

function canManageCharacter(nodeChar)
    return nodeChar ~= nil and DB.getPath(nodeChar):match("^charsheet%.[^.@]+$") ~= nil
        and DB.findNode(DB.getPath(nodeChar)) == nodeChar and (DB.getModule(nodeChar) or "") == ""
        and not DB.isReadOnly(nodeChar) and not WindowManager.getReadOnlyState(nodeChar)
        and (Session.IsHost or DB.isOwner(nodeChar));
end

function getInstanceCharacter(node)
    if not node or not DB.getPath(node):match("^charsheet%.[^.@]+%.inventorylist%.[^.@]+$") then return nil; end
    local list = DB.getParent(node);
    return list and DB.getParent(list);
end

-- Restricción de interfaz, no altera permisos DB ni la sincronización.
function isItemVisible(node)
    if not node then return false; end
    if Session and Session.IsHost then return true; end
    local list, cursor, seen = DB.getParent(node), node, {};
    while cursor do
        local id = containerId(cursor);
        if id == "" then return true; end
        if not id or seen[id] then return false; end
        seen[id] = true;
        cursor = DB.getChild(list, id);
        if not cursor then return false; end
        if field(cursor, "properties.is_container", "number") == 1
            and field(cursor, "properties.hide_contents", "number") == 1 then return false; end
    end
    return false;
end

function canViewInstance(node)
    return getInstanceCharacter(node) ~= nil and DB.findNode(DB.getPath(node)) == node and isInstance(node) and isItemVisible(node);
end

function canEditInstance(node)
    if not canViewInstance(node) or not canManageCharacter(getInstanceCharacter(node))
        or DB.isReadOnly(node) or WindowManager.getReadOnlyState(node) then return false; end
    for _, key in ipairs({ "qualities", "profiles" }) do
        local branch = DB.getChild(node, "properties." .. key);
        if branch and (DB.getType(branch) ~= "node" or DB.isReadOnly(branch)) then return false; end
    end
    if APTUSEquipmentManager.validateCollections(getInstanceCollections(node)) then return false; end
    for _, f in ipairs(tEditableFields) do
        local child = DB.getChild(node, f.path);
        if child then
            if DB.getType(child) ~= f.kind or DB.isReadOnly(child) then return false; end
            local v = DB.getValue(child);
            if f.kind == "number" and (type(v) ~= "number" or v ~= v or v == math.huge or v == -math.huge) then return false; end
        end
    end
    return true;
end

function getTemplateProblem(node)
    if not node or DB.findNode(DB.getPath(node)) ~= node
        or RecordDataManager.getRecordTypeFromRecordPath(DB.getPath(node)) ~= "aptus_equipment" then
        return "El enlace no corresponde a una plantilla APTUS disponible.";
    end
    if field(node, "schema_version", "number") ~= 1
        or not text(field(node, "template_id", "string"))
        or not integer(field(node, "template_version", "number"), 1)
        or not text(field(node, "name", "string")) then return "Plantilla sin contrato válido."; end
    local props = DB.getChild(node, "properties");
    if not props or DB.getType(props) ~= "node" or not tIcons[field(node, "properties.type_id", "string")] then
        return "Propiedades o tipo de plantilla no compatibles.";
    end
    local container = field(node, "properties.is_container", "number");
    if container ~= 0 and container ~= 1 then return "La plantilla no define correctamente si es contenedor."; end
    if not APTUSEquipmentManager.isTemplateConfirmed(node) then return "Guarda primero la plantilla del catálogo."; end
    local problem = APTUSEquipmentManager.getConflict(node);
    if problem then return problem; end
    for _, f in ipairs(APTUSEquipmentManager.getFields()) do
        local child = DB.getChild(node, f.path);
        if child and DB.getType(child) ~= f.kind then return "Tipo de campo no válido: " .. f.path; end
    end
    local draft = APTUSEquipmentManager.getDraft(node);
    for _, f in ipairs(APTUSEquipmentManager.getFields()) do
        local v = draft[f.key];
        if f.kind == "number" and (type(v) ~= "number" or v ~= v or v == math.huge or v == -math.huge) then
            return "Valor numérico no válido: " .. f.key;
        end
    end
    if draft.is_wealth ~= 0 and draft.is_wealth ~= 1 then return "Riqueza no válido."; end
    if draft.stackable ~= 0 and draft.stackable ~= 1 then return "Apilable no válido."; end
    if not integer(draft.max_stack, 1) or not integer(draft.load_every, 1)
        or not integer(draft.required_fue, 0) or not integer(draft.required_agi, 0)
        or draft.load_value < 0 or draft.capacity < 0 then return "Propiedades numéricas de plantilla no válidas."; end
    if container == 1 and (draft.stackable ~= 0 or draft.max_stack ~= 1) then return "Contenedor apilable no compatible."; end
    return APTUSEquipmentManager.validateCollections(draft.collections);
end

function getTemplateOptions()
    local options, seen = {}, {};
    for _, root in ipairs({ "aptus_equipment_templates", "reference.aptus_equipment_templates" }) do
        for _, node in pairs(DB.getChildrenGlobal(root)) do
            local path = DB.getPath(node);
            if not seen[path] and not getTemplateProblem(node) then
                seen[path] = true;
                table.insert(options, { text = DB.getValue(node, "name", ""), linkclass = "aptus_equipment", linkrecord = path });
            end
        end
    end
    table.sort(options, function(a,b) return a.text == b.text and a.linkrecord < b.linkrecord or a.text < b.text; end);
    return options;
end

local function createSingleFromTemplate(nodeChar, nodeTemplate)
    if not canManageCharacter(nodeChar) then return nil, "No puedes crear objetos en este personaje."; end
    local problem = getTemplateProblem(nodeTemplate);
    if problem then return nil, problem; end
    local list = DB.getChild(nodeChar, "inventorylist");
    if list and (DB.getType(list) ~= "node" or DB.isReadOnly(list)) then return nil, "Inventario no editable."; end
    local before = { name = DB.getValue(nodeTemplate, "name", ""),
        id = DB.getValue(nodeTemplate, "template_id", ""), version = DB.getValue(nodeTemplate, "template_version", 0),
        properties = encode(readProperties(DB.getChild(nodeTemplate, "properties"))) };
    local created, newList;
    local ok, err = pcall(function()
        if not list then list = DB.createChild(nodeChar, "inventorylist"); newList = true; end
        if not list then error("No se pudo crear la colección"); end
        created = DB.createChild(list);
        if not created then error("No se pudo crear la instancia"); end
        -- Carried antes del nombre: evita la propagación nativa por nombres de
        -- location sobre otros objetos heredados. No se llama a ItemManager.
        DB.setValue(created, "count", "number", 1);
        DB.setValue(created, "carried", "number", 1);
        DB.setValue(created, "name", "string", before.name);
        DB.setValue(created, "template_id", "string", before.id);
        DB.setValue(created, "template_version", "number", before.version);
        local props = DB.createChild(created, "properties");
        if not props then error("No se pudo crear properties"); end
        DB.copyNode(DB.getChild(nodeTemplate, "properties"), props);
        DB.setValue(created, "aptus.container", "string", "");
        DB.setValue(created, "aptus.instance_schema", "number", nSchema);
        local valid, reason = isInstance(created);
        if not valid then error(reason); end
        if field(created, "name", "string") ~= before.name or field(created, "count", "number") ~= 1
            or field(created, "carried", "number") ~= 1 or field(created, "aptus.container", "string") ~= ""
            or field(created, "template_id", "string") ~= before.id
            or field(created, "template_version", "number") ~= before.version
            or encode(readProperties(DB.getChild(created, "properties"))) ~= before.properties then
            error("La instancia no conserva los valores iniciales y propiedades esperados");
        end
    end);
    if not ok then
        local clean = pcall(function()
            if created then
                local path = DB.getPath(created);
                DB.deleteNode(created);
                if DB.findNode(path) then error("No se pudo retirar la instancia incompleta"); end
            end
            if newList and list and not next(DB.getChildren(list)) then DB.deleteNode(list); end
        end);
        Debug.console("APTUS inventario [crear] " .. tostring(err));
        return nil, clean and "No se pudo crear el objeto; se retiró la instancia incompleta."
            or "No se pudo verificar la limpieza de la instancia incompleta. Revisar con el DJ.";
    end
    return created;
end

function getEditableFields() return tEditableFields; end
function getInstanceEditToken(node)
    local snapshot = readProperties(node);
    -- El candado es metadato de interfaz; no cambia el borrador ni su revisión.
    snapshot.locked = nil;
    return encode(snapshot);
end
function getInstanceCollections(node)
    return { qualities = readProperties(DB.getChild(node, "properties.qualities")) or {},
        profiles = readProperties(DB.getChild(node, "properties.profiles")) or {} };
end
local function writeInstanceTree(node, tree)
    if not node then error("No se pudo crear la colección de instancia"); end
    for key, value in pairs(tree) do
        if value.kind == "windowreference" then DB.setValue(node, key, value.kind, value.class, value.path);
        elseif value.kind then DB.setValue(node, key, value.kind, value.value);
        else writeInstanceTree(DB.createChild(node, key), value); end
    end
end
local function replaceInstanceCollection(node, key, tree)
    DB.deleteChild(node, "properties." .. key);
    if tree then writeInstanceTree(DB.createChild(node, "properties." .. key), tree); end
end

-- Presentación: la carga acumulada ya viene calculada en el snapshot.
function getContainerDisplayName(item, accumulated)
    if accumulated == nil then accumulated = item.content_load; end
    local capacity = capacityValue(item);
    if item.is_container and type(accumulated) == "number" and accumulated == accumulated
        and accumulated >= 0 and accumulated < math.huge and type(capacity) == "number"
        and capacity == capacity and capacity >= 0 and capacity < math.huge then
        return item.name .. " (" .. tostring(accumulated) .. "/" .. tostring(capacity) .. ")";
    end
    return item.name;
end
function getContainerLoadIndicator(item)
    if not item.is_container then return ""; end
    local capacity = capacityValue(item);
    return " (" .. (item.content_load ~= nil and tostring(item.content_load) or "—")
        .. "/" .. (capacity ~= nil and tostring(capacity) or "—") .. ")";
end
function getInstanceDraft(node)
    local draft = {};
    for _, f in ipairs(tEditableFields) do draft[f.key] = DB.getValue(node, f.path, f.default); end
    draft.collections = getInstanceCollections(node);
    return draft;
end

function saveInstance(node, draft, expected)
    if not canEditInstance(node) then return false, "La instancia no existe o no tienes permiso de edición."; end
    if getInstanceEditToken(node) ~= expected then return false, "El objeto cambió. Releer antes de guardar."; end
    if type(draft) ~= "table" then return false, "Borrador no válido."; end
    local storedHidden = DB.getValue(node, "properties.hide_contents", 0);
    if draft.hide_contents == nil then draft.hide_contents = storedHidden; end
    if not Session.IsHost and draft.hide_contents ~= storedHidden then
        return false, "Sólo el DJ puede modificar Ocultar contenido.";
    end
    if draft.is_container == 0 then draft.hide_contents = 0; end
    local allowed, changes, missing = { collections=true }, {}, {};
    local beforeCollections = getInstanceCollections(node);
    -- Clientes antiguos sin editor de colecciones conservan las asociaciones.
    local collections = draft.collections or beforeCollections;
    local problem = APTUSEquipmentManager.validateCollections(collections);
    if problem then return false, problem; end
    local collectionChanges = {};
    for _, key in ipairs({ "qualities", "profiles" }) do
        if encode(collections[key]) ~= encode(beforeCollections[key]) then
            local branch = DB.getChild(node, "properties." .. key);
            if branch and DB.isReadOnly(branch) then return false, "Colección no editable: " .. key; end
            table.insert(collectionChanges, { key=key, old=branch and beforeCollections[key] or nil });
        end
    end
    for _, f in ipairs(tEditableFields) do
        allowed[f.key] = true;
        local v = draft[f.key];
        if f.kind == "number" then
            if type(v) ~= "number" or v ~= v or v == math.huge or v == -math.huge then return false, "Número no válido: " .. f.key; end
        elseif type(v) ~= "string" then return false, "Texto no válido: " .. f.key; end
        local child = DB.getChild(node, f.path);
        if child and (DB.getType(child) ~= f.kind or DB.isReadOnly(child)) then return false, "Campo no editable: " .. f.path; end
        if DB.getValue(node, f.path, f.default) ~= v then
            table.insert(changes, { field=f, old=child and DB.getValue(child), existed=child ~= nil });
            local prefix = "";
            for part in f.path:gmatch("[^.]+") do
                prefix = prefix == "" and part or prefix .. "." .. part;
                if not DB.getChild(node, prefix) then missing[prefix] = true; end
            end
        end
    end
    for key in pairs(draft) do if not allowed[key] then return false, "Campo protegido o desconocido: " .. tostring(key); end end
    if not tIcons[draft.type_id] then return false, "Tipo de equipo no válido."; end
    for _, key in ipairs({ "stackable", "is_container", "is_wealth", "hide_contents" }) do
        if draft[key] ~= 0 and draft[key] ~= 1 then return false, "Casilla no válida: " .. key; end
    end
    if not integer(draft.max_stack, 1) then return false, "Máximo de pila no válido."; end
    if draft.stackable == 1 and DB.getValue(node, "count", 1) > draft.max_stack then
        return false, "La cantidad supera el nuevo máximo. Ajusta o reparte la cantidad antes de reducir el límite.";
    end
    if draft.is_container == 1 and (DB.getValue(node, "count", 1) ~= 1 or draft.stackable ~= 0 or draft.max_stack ~= 1) then
        return false, "Un contenedor debe tener cantidad uno y no ser apilable.";
    end
    if draft.is_container == 0 then
        for _, sibling in pairs(DB.getChildren(DB.getParent(node))) do
            if containerId(sibling) == DB.getName(node) then
                return false, "No se puede quitar la condición de contenedor mientras tenga objetos asociados.";
            end
        end
    end
    if not text(draft.name) then return false, "El nombre es obligatorio."; end
    if not integer(draft.load_every, 1) or not integer(draft.required_fue, 0) or not integer(draft.required_agi, 0)
        or draft.load_value < 0 or draft.capacity < 0 then return false, "Requisitos y valores CAR/capacidad no válidos."; end
    if #changes == 0 and #collectionChanges == 0 then return true, "Sin cambios."; end
    local ok, err = pcall(function()
        for _, change in ipairs(changes) do
            local f = change.field;
            DB.setValue(node, f.path, f.kind, draft[f.key]);
            if field(node, f.path, f.kind) ~= draft[f.key] then error("No se pudo verificar " .. f.path); end
        end
        for _, change in ipairs(collectionChanges) do
            replaceInstanceCollection(node, change.key, collections[change.key]);
            if encode(readProperties(DB.getChild(node, "properties." .. change.key)) or {}) ~= encode(collections[change.key]) then
                error("No se pudo verificar la colección " .. change.key);
            end
        end
        if not isInstance(node) then error("El objeto dejó de cumplir el contrato"); end
    end);
    if not ok then
        local restored = pcall(function()
            for _, change in ipairs(collectionChanges) do replaceInstanceCollection(node, change.key, change.old); end
            for i = #changes, 1, -1 do
                local c = changes[i];
                if c.existed then DB.setValue(node, c.field.path, c.field.kind, c.old);
                else DB.deleteChild(node, c.field.path); end
            end
            local paths = {};
            for path in pairs(missing) do table.insert(paths, path); end
            table.sort(paths, function(a,b) return #a > #b; end);
            for _, path in ipairs(paths) do
                local child = DB.getChild(node, path);
                if child and DB.getType(child) == "node" and not next(DB.getChildren(child)) then DB.deleteNode(child); end
            end
            if getInstanceEditToken(node) ~= expected then error("Restauración no verificada"); end
        end);
        Debug.console("APTUS inventario [guardar instancia] " .. tostring(err));
        return false, restored and "No se guardó; valores anteriores restaurados." or "No se pudo verificar la restauración. Revisar con el DJ.";
    end
    return true, "Instancia guardada. La plantilla no se ha modificado.";
end

-- Eliminación explícita: permisos de inventario, independientes del candado de propiedades.
function canDeleteInstance(node, internalContents)
    local character = getInstanceCharacter(node);
    if not character or DB.findNode(DB.getPath(character)) ~= character
        or not (internalContents and isInstance(node) or canViewInstance(node)) or (DB.getModule(character) or "") ~= ""
        or DB.isReadOnly(character) or DB.isReadOnly(DB.getParent(node)) or DB.isReadOnly(node) then return false; end
    return Session.IsHost or (DB.isOwner(character) and DB.isOwner(node));
end

-- Incluye enlaces de registros incompatibles: nunca se oculta un posible hijo
-- heredado para acabar borrando su padre y dejarlo huérfano.
local function deleteGraph(list)
    local nodes, children = {}, {};
    for _, node in pairs(DB.getChildren(list)) do
        if DB.getType(node) == "node" then
            local id = DB.getName(node);
            nodes[id] = node;
            local parent = containerId(node);
            if parent == nil then
                return nil, nil, "Hay una relación de contención de tipo incompatible: " .. id .. ". No se puede determinar el contenido con seguridad.";
            end
            if parent and parent ~= "" then
                children[parent] = children[parent] or {};
                table.insert(children[parent], id);
            end
        end
    end
    for _, entries in pairs(children) do table.sort(entries); end
    return nodes, children;
end

-- Plan de sólo lectura. Recorrido iterativo por IDs del mismo inventorylist.
function planDeleteInstance(node)
    if not canDeleteInstance(node) then return nil, "El objeto no existe, no es una instancia APTUS válida o no tienes permiso para eliminarlo."; end
    local list = DB.getParent(node);
    local nodes, children, problem = deleteGraph(list);
    if problem then return nil, problem; end
    local cursor, ancestors = node, {};
    while cursor do
        local id = DB.getName(cursor);
        if ancestors[id] then return nil, "Se ha detectado un ciclo de contención. No se ha eliminado nada."; end
        ancestors[id] = true;
        if not isInstance(cursor) then return nil, "Referencia a un contenedor incompatible: " .. id; end
        local parent = containerId(cursor);
        if parent == "" then break; end
        cursor = nodes[parent];
        if not cursor or field(cursor, "properties.is_container", "number") ~= 1 then
            return nil, "Referencia de contención inválida: " .. parent .. ". No se ha eliminado nada.";
        end
    end
    local plan = { path=DB.getPath(node), character=DB.getPath(getInstanceCharacter(node)),
        name=field(node, "name", "string"), count=field(node, "count", "number"), entries={} };
    local stack, seen, signature = { DB.getName(node) }, {}, {};
    while #stack > 0 do
        local id = table.remove(stack);
        if seen[id] then return nil, "Se ha detectado un ciclo o una relación repetida en el contenido."; end
        seen[id] = true;
        local current = nodes[id];
        if not canDeleteInstance(current, true) then
            return nil, "El contenido incluye un registro incompatible o sin permisos: " .. id .. ". No se ha eliminado nada.";
        end
        local entries = children[id] or {};
        if #entries > 0 and field(current, "properties.is_container", "number") ~= 1 then
            return nil, "Un objeto que no es contenedor tiene contenido asociado: " .. id;
        end
        local entry = { node=current, path=DB.getPath(current), token=getInstanceEditToken(current) };
        table.insert(plan.entries, entry);
        table.insert(signature, {path=entry.path, token=entry.token});
        for i = #entries, 1, -1 do table.insert(stack, entries[i]); end
    end
    plan.token = encode({ path=plan.path, character=plan.character, entries=signature });
    return plan;
end

function getDeleteConfirmation(plan)
    if #plan.entries > 1 then
        return "¿Quieres eliminar " .. plan.name .. " y todos los objetos que contiene? Esta acción también eliminará el contenido de los contenedores interiores.\n\nRegistros afectados: " .. tostring(#plan.entries) .. ".";
    end
    if plan.count > 1 then
        local count = string.format("%.0f", plan.count);
        return "¿Quieres eliminar " .. plan.name .. " ×" .. count .. "? Se eliminarán las " .. count .. " unidades.";
    end
    return "¿Quieres eliminar " .. plan.name .. "?";
end

local function sameDeletePlan(a, b)
    if a.token ~= b.token or #a.entries ~= #b.entries then return false; end
    for i, entry in ipairs(a.entries) do if entry.node ~= b.entries[i].node then return false; end end
    return true;
end

-- Sólo accesible desde la confirmación. Sin transacciones ni reconstrucción de registros.
local function executeDeletePlan(plan)
    local deleted = 0;
    local ok, problem = pcall(function()
        for i = #plan.entries, 1, -1 do
            local entry = plan.entries[i];
            local node = DB.findNode(entry.path);
            if node ~= entry.node or not canDeleteInstance(node, true) or getInstanceEditToken(node) ~= entry.token then
                error("Un registro cambió o perdió sus permisos durante la operación.");
            end
            local _, children, issue = deleteGraph(DB.getParent(node));
            if issue then error(issue); end
            if children[DB.getName(node)] and #children[DB.getName(node)] > 0 then
                error("El contenedor conserva contenido no eliminado; se ha detenido la operación.");
            end
            -- Hojas antes que padres: un fallo conserva los contenedores restantes.
            local removed, err = pcall(DB.deleteNode, node);
            if not DB.findNode(entry.path) then deleted = deleted + 1;
            else error("Fantasy Grounds no ha eliminado el registro solicitado."); end
            if not removed then error(err); end
        end
    end);
    if not ok then
        Debug.console("APTUS inventario [eliminar] " .. tostring(problem));
        return false, "Eliminación interrumpida: " .. tostring(deleted) .. " de " .. tostring(#plan.entries)
            .. " registros eliminados. No se ha continuado. Revisar permisos y contenido antes de volver a intentarlo.", "error";
    end
    return true, "Se han eliminado " .. tostring(deleted) .. " registros.", "deleted";
end

-- Coordinación del diálogo nativo, separada de la planificación y ejecución.
-- notify(ok, mensaje, resultado); isActive permite cancelar si la ficha se cierra.
function requestDeleteInstance(node, notify, isActive)
    local plan, problem = planDeleteInstance(node);
    if not plan then
        if notify then notify(false, problem, "error"); end
        return false;
    end
    local function ask(expected, changed)
        local answered = false;
        DialogManager.openDialog("dialog_okcancel", {
            sTitle="Eliminar instancia de equipo",
            sText=(changed and "El contenido ha cambiado. Revisa y confirma de nuevo la operación actualizada.\n\n" or "") .. getDeleteConfirmation(expected),
            fnCallback=function(result)
                if answered then return; end
                answered = true;
                if isActive and not isActive() then return; end
                if result ~= "ok" then
                    if notify then notify(false, "Eliminación cancelada.", "cancelled"); end
                    return;
                end
                local current, issue = planDeleteInstance(DB.findNode(expected.path));
                if not current then
                    if notify then notify(false, issue, "error"); end
                    return;
                end
                if not sameDeletePlan(expected, current) then ask(current, true); return; end
                local ok, message, outcome = executeDeletePlan(current);
                if notify then notify(ok, message, outcome); end
            end,
        });
    end
    ask(plan, false);
    return true;
end

-- Operaciones de unidades. Sin reglas particulares para ammunition ni normalización al cargar.
local inventoryBusy = false;
local operationListeners = {};
function isUpdatingInventory() return inventoryBusy; end
function addOperationListener(callback) operationListeners[callback] = true; end
function removeOperationListener(callback) operationListeners[callback] = nil; end
local function units(value, minimum)
    return integer(value, minimum) and value <= 9007199254740991;
end
local function mutate(operation)
    if inventoryBusy then return nil, "Hay otra operación de inventario en curso."; end
    inventoryBusy = true;
    local ok, result, problem, nodes = pcall(operation);
    inventoryBusy = false;
    for callback in pairs(operationListeners) do
        local notified, issue = pcall(callback);
        if not notified then Debug.console("APTUS inventario [vista] " .. tostring(issue)); end
    end
    if not ok then Debug.console("APTUS inventario [unidades] " .. tostring(result)); return nil, "Operación interrumpida: " .. tostring(result); end
    return result, problem, nodes;
end
local function writable(node)
    local character = getInstanceCharacter(node);
    if not character or not canManageCharacter(character) or not isInstance(node) or not isItemVisible(node)
        or DB.isReadOnly(node) or DB.isReadOnly(DB.getParent(node)) then return false; end
    local count = DB.getChild(node, "count");
    return count and units(field(node, "count", "number"), 1)
        and not DB.isReadOnly(count) and (Session.IsHost or DB.isOwner(node));
end
local function liveItem(node)
    local character = getInstanceCharacter(node);
    if character then
        for _, item in ipairs(getCharacterInventory(character).items) do if item.node == node then return item; end end
    end
end
local function limit(node)
    local flag = DB.getChild(node, "properties.stackable");
    local stackable = flag and field(node, "properties.stackable", "number") or 0;
    if flag and field(node, "properties.stackable", "number") == nil then return nil, "Tipo del indicador de apilamiento no válido."; end
    if stackable ~= 0 and stackable ~= 1 then return nil, "Indicador de apilamiento no válido."; end
    if stackable == 0 then return false; end
    local maximum = field(node, "properties.max_stack", "number");
    if not units(maximum, 1) or field(node, "properties.is_container", "number") ~= 0 then return nil, "Límite de pila no válido."; end
    return maximum;
end
local function signature(node, carried)
    local data = readProperties(node);
    if carried ~= nil then data.carried = {kind="number", value=carried}; end
    data.count, data.locked = nil, nil;
    if data.aptus then data.aptus.container = nil; end
    return encode(data);
end
function areStackCompatible(a, b, carried)
    if not isInstance(a) or not isInstance(b) then return false; end
    local maximum = limit(a);
    return type(maximum) == "number" and limit(b) == maximum and signature(a, carried) == signature(b);
end
local function destination(character, parent, source)
    if not canManageCharacter(character) then return nil, "No tienes permiso sobre el inventario destino."; end
    local list = DB.getChild(character, "inventorylist");
    if list and (DB.getType(list) ~= "node" or DB.isReadOnly(list)) then return nil, "Inventario destino no editable."; end
    if not parent then return ""; end
    if getInstanceCharacter(parent) ~= character or not writable(parent)
        or field(parent, "properties.is_container", "number") ~= 1 or not liveItem(parent) then
        return nil, "Contenedor destino no válido o sin permisos.";
    end
    local cursor = parent;
    while cursor do
        if cursor == source then return nil, "Un contenedor no puede introducirse en sí mismo ni en sus descendientes."; end
        local id = containerId(cursor);
        if id == "" then break; end
        cursor = DB.getChild(list, id);
    end
    return DB.getName(parent);
end
local function hasChildren(node)
    for _, sibling in pairs(DB.getChildren(DB.getParent(node))) do
        if containerId(sibling) == DB.getName(node) then return true; end
    end
    return false;
end
local function writeCount(node, count)
    DB.setValue(node, "count", "number", count);
    if field(node, "count", "number") ~= count then error("No se pudo verificar la cantidad de " .. DB.getPath(node)); end
end

-- Planifica antes de escribir. Copias primero, cantidades después y baja del único
-- origen al final: un fallo anterior puede restaurarse sin borrar el origen.
local function distribute(source, character, parentId, amount, remaining, keepSource, existingFirst, targetCarried)
    if not writable(source) or not liveItem(source) then return nil, "Objeto origen incompatible, relación inválida o sin permisos."; end
    if hasChildren(source) then return nil, "No se reparten unidades de un objeto con contenido."; end
    local maximum, issue = limit(source);
    if maximum == nil then return nil, issue; end
    local original = field(source, "count", "number");
    local sourcePath = DB.getPath(source);
    local changes, copies, results = {}, {}, {};
    local sourceCount = remaining;
    local left = amount;
    local function allocate(node)
        local old = field(node, "count", "number");
        local base = node == source and 0 or old;
        local take = maximum and math.min(left, math.max(0, maximum - base)) or left;
        if take > 0 then
            table.insert(changes, {node=node, old=old, count=base + take});
            table.insert(results, node); left = left - take;
            if node == source then sourceCount = take; end
        end
    end
    if keepSource and not existingFirst and left > 0 then allocate(source); end
    if maximum then
        local candidates = getCharacterInventory(character).items;
        for _, item in ipairs(candidates) do
            if left > 0 and item.node ~= source and item.parent_id == parentId and writable(item.node)
                and areStackCompatible(source, item.node, targetCarried) then allocate(item.node); end
        end
    end
    if keepSource and existingFirst and left > 0 then allocate(source); end
    while left > 0 do
        local count = maximum and math.min(left, maximum) or left;
        table.insert(copies, count); left = left - count;
    end
    if field(source, "properties.is_container", "number") == 1 and amount + remaining ~= 1 then return nil, "Un contenedor debe conservar cantidad uno."; end
    local deleting = sourceCount == 0;
    if deleting then
        local plan, problem = planDeleteInstance(source);
        if not plan then return nil, problem; end
        if #plan.entries ~= 1 then return nil, "No se pueden eliminar unidades de un contenedor con contenido."; end
    elseif not keepSource then
        table.insert(changes, {node=source, old=original, count=remaining});
    end
    local snapshot = readProperties(source);
    snapshot.aptus.container = {kind="string", value=parentId};
    if targetCarried ~= nil then snapshot.carried = {kind="number", value=targetCarried}; end
    local created, list, newList = {}, DB.getChild(character, "inventorylist"), false;
    local previousParent = containerId(source);
    local parentExisted = DB.getChild(source, "aptus.container") ~= nil;
    local parentChanged, stateChanged = false, false;
    local previousCarried = field(source, "carried", "number");
    if keepSource and not deleting and targetCarried ~= nil and targetCarried ~= previousCarried
        and DB.isReadOnly(DB.getChild(source, "carried")) then return nil, "Estado no editable."; end
    if keepSource and not deleting and previousParent ~= parentId then
        local child = DB.getChild(source, "aptus.container");
        if child and DB.isReadOnly(child) then return nil, "Relación de contención no editable."; end
    end
    local ok, problem = pcall(function()
        if #copies > 0 and not list then list = DB.createChild(character, "inventorylist"); newList = true; end
        if #copies > 0 and not list then error("No se pudo crear el inventario destino"); end
        for _, count in ipairs(copies) do
            local node = DB.createChild(list);
            if not node then error("No se pudo crear una pila"); end
            table.insert(created, node);
            -- Carried antes de name para no activar propagación nativa por nombres.
            local carried = snapshot.carried;
            DB.setValue(node, "carried", "number", carried.value);
            snapshot.carried = nil;
            snapshot.count = {kind="number", value=count};
            writeInstanceTree(node, snapshot);
            snapshot.carried = carried;
            if not isInstance(node) or encode(readProperties(node)) ~= encode(snapshot) then error("Copia de pila no verificada"); end
            table.insert(results, node);
        end
        for _, change in ipairs(changes) do
            if not writable(change.node) or field(change.node, "count", "number") ~= change.old then error("Una pila cambió o perdió permisos"); end
            if change.count ~= change.old then
                change.applied = true;
                writeCount(change.node, change.count);
            end
        end
        if keepSource and not deleting and previousParent ~= parentId then
            parentChanged = true;
            DB.setValue(source, "aptus.container", "string", parentId);
            if containerId(source) ~= parentId then error("Contenedor no verificado"); end
        end
        if keepSource and not deleting and targetCarried ~= nil and targetCarried ~= previousCarried then
            stateChanged = true;
            DB.setValue(source, "carried", "number", targetCarried);
            if field(source, "carried", "number") ~= targetCarried then error("Estado no verificado"); end
        end
        if deleting then
            if not writable(source) or field(source, "count", "number") ~= original then error("El origen cambió antes de finalizar"); end
            -- Una excepción posterior a un borrado efectivo no debe duplicar unidades.
            pcall(DB.deleteNode, source);
            if DB.findNode(sourcePath) then error("No se pudo retirar la pila origen"); end
        end
    end);
    if not ok then
        local restored, rollbackProblem = pcall(function()
            if stateChanged then
                DB.setValue(source, "carried", "number", previousCarried);
                if field(source, "carried", "number") ~= previousCarried then error("Estado anterior no restaurado"); end
            end
            if parentChanged then
                if parentExisted then DB.setValue(source, "aptus.container", "string", previousParent);
                else DB.deleteChild(source, "aptus.container"); end
                if containerId(source) ~= previousParent then error("Contenedor anterior no restaurado"); end
            end
            for i = #changes, 1, -1 do
                local change = changes[i];
                if change.applied and DB.findNode(DB.getPath(change.node)) == change.node then writeCount(change.node, change.old); end
            end
            for i = #created, 1, -1 do
                local path = DB.getPath(created[i]); DB.deleteNode(created[i]);
                if DB.findNode(path) then error("Pila nueva no retirada"); end
            end
            if newList and list and not next(DB.getChildren(list)) then DB.deleteNode(list); end
        end);
        Debug.console("APTUS inventario [reparto] " .. tostring(problem));
        return nil, restored and "Operación cancelada; cantidades restauradas."
            or ("No se pudo verificar la restauración. Revisar con el DJ: " .. tostring(rollbackProblem));
    end
    return results[1] or (not deleting and source) or true, nil, results;
end

function setQuantity(node, quantity)
    return mutate(function()
        if not units(quantity, 0) then return nil, "La cantidad debe ser un entero no negativo representable con exactitud."; end
        if not writable(node) or not liveItem(node) then return nil, "Objeto no editable o con relación inválida."; end
        if hasChildren(node) then return nil, "No se modifica la cantidad de un contenedor con contenido."; end
        return distribute(node, getInstanceCharacter(node), containerId(node), quantity, 0, true, false);
    end);
end
function removeUnits(node, quantity)
    if not writable(node) or not units(quantity, 1) or quantity > field(node, "count", "number") then return nil, "Número de unidades no válido."; end
    return setQuantity(node, field(node, "count", "number") - quantity);
end
function mergeStacks(node)
    return mutate(function()
        if not writable(node) or not liveItem(node) then return nil, "Objeto no editable."; end
        local maximum, problem = limit(node);
        if not maximum then return nil, problem or "El objeto no es apilable."; end
        return distribute(node, getInstanceCharacter(node), containerId(node), field(node, "count", "number"), 0, true, true);
    end);
end
function transfer(node, character, quantity, parent, targetCarried)
    return mutate(function()
        if not writable(node) or not liveItem(node) then return nil, "Objeto origen no editable."; end
        local count = field(node, "count", "number");
        quantity = quantity or count;
        if not units(quantity, 1) or quantity > count then return nil, "Cantidad de traslado no válida."; end
        local parentId, problem = destination(character, parent, node);
        if parentId == nil then return nil, problem; end
        local sameCharacter = getInstanceCharacter(node) == character;
        local previousCarried = field(node, "carried", "number");
        if targetCarried ~= nil and (not integer(targetCarried, 0) or not tStates[targetCarried]) then return nil, "Estado no válido."; end
        if targetCarried == nil then
            if parentId ~= "" then targetCarried = 0;
            elseif containerId(node) ~= "" then targetCarried = 1;
            else targetCarried = previousCarried; end
        end
        if parentId ~= "" and targetCarried ~= 0 then return nil, "Un objeto contenido debe permanecer sin equipar."; end
        if sameCharacter and parentId == containerId(node) and (parentId ~= "" or targetCarried == previousCarried) then return node; end
        if targetCarried ~= previousCarried and DB.isReadOnly(DB.getChild(node, "carried")) then return nil, "Estado no editable."; end
        if sameCharacter and parentId == containerId(node) then
            -- Mismo destino: no fusionar ni escribir al volver a elegirlo.
            local ok = pcall(function()
                DB.setValue(node, "carried", "number", targetCarried);
                if field(node, "carried", "number") ~= targetCarried then error("Estado no verificado"); end
            end);
            if not ok then
                local restored = pcall(function()
                    DB.setValue(node, "carried", "number", previousCarried);
                    if field(node, "carried", "number") ~= previousCarried then error("Estado anterior no restaurado"); end
                end);
                return nil, restored and "No se pudo cambiar el estado; se conserva el anterior." or "Revisar el estado con el DJ: restauración incompleta.";
            end
            return node;
        end
        if hasChildren(node) then
            if not sameCharacter then return nil, "El traslado de contenedores con contenido entre personajes requiere mover su árbol; no se ha modificado nada."; end
            local plan, issue = planDeleteInstance(node);
            if not plan then return nil, issue; end
            if field(node, "properties.is_container", "number") ~= 1 then return nil, "El objeto tiene referencias de contenido incompatibles."; end
            local child = DB.getChild(node, "aptus.container");
            if child and DB.isReadOnly(child) then return nil, "Relación de contención no editable."; end
            local previous, existed = containerId(node), child ~= nil;
            local ok = pcall(function()
                DB.setValue(node, "aptus.container", "string", parentId);
                if containerId(node) ~= parentId then error("Relación no verificada"); end
                if targetCarried ~= previousCarried then DB.setValue(node, "carried", "number", targetCarried); end
                if field(node, "carried", "number") ~= targetCarried then error("Estado no verificado"); end
            end);
            if not ok then
                local restored = pcall(function()
                    if existed then DB.setValue(node, "aptus.container", "string", previous); else DB.deleteChild(node, "aptus.container"); end
                    if field(node, "carried", "number") ~= previousCarried then DB.setValue(node, "carried", "number", previousCarried); end
                    if containerId(node) ~= previous or field(node, "carried", "number") ~= previousCarried then error("Restauración no verificada"); end
                end);
                return nil, restored and "No se pudo mover el contenedor; se conserva su estado y ubicación." or "Revisar el contenedor con el DJ: restauración incompleta.";
            end
            return node;
        end
        return distribute(node, character, parentId, quantity, count - quantity, sameCharacter and quantity == count, true, targetCarried);
    end);
end
function createFromTemplate(character, template, quantity, parent)
    return mutate(function()
        quantity = quantity or 1;
        if not units(quantity, 1) then return nil, "La cantidad debe ser un entero positivo representable con exactitud."; end
        local parentId, problem = destination(character, parent);
        if parentId == nil then return nil, problem; end
        local previousList = DB.getChild(character, "inventorylist");
        local created, issue = createSingleFromTemplate(character, template);
        if not created then return nil, issue; end
        local createdPath = DB.getPath(created);
        -- La primera instancia sirve como snapshot independiente de la plantilla.
        if parentId ~= "" then
            local ok = pcall(function()
                DB.setValue(created, "aptus.container", "string", parentId);
                DB.setValue(created, "carried", "number", 0);
            end);
            if not ok or containerId(created) ~= parentId or field(created, "carried", "number") ~= 0 then DB.deleteNode(created); return nil, "No se pudo asignar el contenedor."; end
        end
        local ok, result, reason, nodes = pcall(distribute, created, character, parentId, quantity, 0, true, true);
        if not ok then reason = "No se pudo preparar el reparto: " .. tostring(result); result = nil; end
        if not result then
            if DB.findNode(createdPath) then DB.deleteNode(created); end
            if DB.findNode(createdPath) then return nil, "No se pudo retirar el alta inicial. Revisar cantidades con el DJ."; end
            local list = DB.getChild(character, "inventorylist");
            if not previousList and list and not next(DB.getChildren(list)) then DB.deleteNode(list); end
            return nil, reason;
        end
        return result, nil, nodes;
    end);
end

-- Adaptadores de interfaz: la cantidad y los movimientos siguen pasando por el gestor.
function requestQuantityInput(title, initial, callback)
    local previous = Interface.findWindow("aptus_inventory_quantity", "");
    if previous then previous.close(); end
    local window = Interface.openWindow("aptus_inventory_quantity", "");
    if window then window.configure(title, initial, callback); end
end
function requestSetQuantity(node)
    if not writable(node) then ChatManager.SystemMessage("Objeto no editable."); return; end
    local path, expected = DB.getPath(node), getInstanceEditToken(node);
    requestQuantityInput("Cantidad total de esta pila (0 solicita su eliminación)", field(node, "count", "number"), function(quantity)
        if DB.findNode(path) ~= node or getInstanceEditToken(node) ~= expected then
            ChatManager.SystemMessage("El objeto cambió; vuelve a abrir el control de cantidad."); return;
        end
        if quantity == 0 then
            requestDeleteInstance(node, function(ok, message) if not ok then ChatManager.SystemMessage(message); end end);
            return;
        end
        local result, problem = setQuantity(node, quantity);
        if not result then ChatManager.SystemMessage(problem); end
    end);
end

-- Opciones exclusivamente del mismo personaje; usa la validación de destino de transfer.
function getLocationOptions(node)
    if not writable(node) or not liveItem(node) then return {}; end
    local character = getInstanceCharacter(node);
    local inventory = getCharacterInventory(character);
    local byId, labels, options = {}, {}, {
        {text="Raíz del inventario", linkclass="charsheet", linkrecord=DB.getPath(character)}
    };
    for _, item in ipairs(inventory.items) do byId[item.id] = item; end
    for _, item in ipairs(inventory.items) do
        if item.is_container and destination(character, item.node, node) ~= nil then
            local parts, cursor = {item.name}, item;
            while cursor.parent_id ~= "" do
                cursor = byId[cursor.parent_id];
                table.insert(parts, 1, cursor.name);
            end
            local label = table.concat(parts, " / ");
            labels[label] = (labels[label] or 0) + 1;
            table.insert(options, {text=label, linkclass="aptus_inventory_item", linkrecord=item.path});
        end
    end
    local occurrence = {};
    for i = 2, #options do
        local label = options[i].text;
        if labels[label] > 1 then
            occurrence[label] = (occurrence[label] or 0) + 1;
            options[i].text = label .. " (" .. occurrence[label] .. ")";
        end
    end
    return options;
end
function requestLocation(node, notify)
    local options = getLocationOptions(node);
    if #options == 0 then if notify then notify(false, "Objeto no editable o sin ubicación válida."); end; return; end
    local character = getInstanceCharacter(node);
    local path, expected = DB.getPath(node), getInstanceEditToken(node);
    Interface.openWindow("aptus_inventory_location", "").requestSelectionByData({
        title="Ubicación del objeto", msg="Selecciona la raíz o un contenedor del mismo personaje.",
        options=options, min=1, max=1,
        callback=function(selections, context, links)
            if DB.findNode(path) ~= node or getInstanceCharacter(node) ~= character or getInstanceEditToken(node) ~= expected then
                if notify then notify(false, "El objeto cambió; vuelve a seleccionar su ubicación."); end
                return;
            end
            local link = links and links[1];
            if not link then return; end
            local parent;
            if link.linkclass == "charsheet" and link.linkrecord == DB.getPath(character) then
                parent = nil;
            elseif link.linkclass == "aptus_inventory_item" then
                parent = DB.findNode(link.linkrecord);
                if not parent or getInstanceCharacter(parent) ~= character then
                    if notify then notify(false, "El contenedor ya no pertenece a este inventario."); end
                    return;
                end
            else
                if notify then notify(false, "Destino incompatible."); end
                return;
            end
            local result, problem = transfer(node, character, nil, parent);
            if notify then notify(result ~= nil, problem); end
        end,
    });
end

-- Selección de Estado: valores persistidos originales, sin migraciones al leer.
function setState(node, carried)
    if not writable(node) or not liveItem(node) then return nil, "Objeto no editable o relación inválida."; end
    if not integer(carried, 0) or not tStates[carried] then return nil, "Estado no válido."; end
    if containerId(node) ~= "" and carried == 0 then return node; end
    return transfer(node, getInstanceCharacter(node), nil, nil, carried);
end
function requestState(node, notify)
    if not writable(node) or not liveItem(node) then
        if notify then notify(false, "Objeto no editable o relación inválida."); end
        return;
    end
    local path, expected = DB.getPath(node), getInstanceEditToken(node);
    local previous = Interface.findWindow("aptus_inventory_state", "");
    if previous then previous.close(); end
    local window = Interface.openWindow("aptus_inventory_state", "");
    if not window then return; end
    local current = containerId(node) == "" and field(node, "carried", "number") or 0;
    window.configure(current, function(carried)
        if DB.findNode(path) ~= node or getInstanceEditToken(node) ~= expected then
            if notify then notify(false, "El objeto cambió; vuelve a seleccionar su estado."); end
            return;
        end
        local result, problem = setState(node, carried);
        if notify then notify(result ~= nil, problem); end
    end);
end

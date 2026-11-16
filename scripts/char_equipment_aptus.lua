-- Vista de inventario: operaciones estructurales delegadas al gestor común.
local nView = 1;
local tHandlers = {};
local bClosed, bCreating = false, false;
local sRevealPath;
local bRefreshPending = false;
local bStructure = false;
local bInitialized = false;
local inspectionWindows = {};

-- Presentación informativa, sin efectos sobre atributos ni tiradas.
local tLoadConsequences = {
    SOBRECARGADO = { "AGI -1d" },
    LASTRADO = { "AGI -2d", "MOV 1/2" },
    INMOVILIZADO = { "AGI -2d", "MOV 0" },
};

local function watch(path, event, callback)
    DB.addHandler(path, event, callback or refreshPreview);
    table.insert(tHandlers, { path = path, event = event, callback=callback });
end

function onContentsVisibilityChanged()
    if Session.IsHost then return; end
    -- Cerrar opciones ya abiertas que puedan contener nombres ahora ocultos.
    for _, class in ipairs({"aptus_inventory_state", "aptus_inventory_quantity"}) do
        local dialog = Interface.findWindow(class, "");
        if dialog then dialog.close(); end
    end
end

function flushInventoryRefresh()
    if bRefreshPending and not bClosed then refreshPreview(); end
end

function onInit()
    APTUSInventoryManager.addOperationListener(flushInventoryRefresh);
    local node = getDatabaseNode();
    bStructure = getClass() == "aptus_structure_inventory" or getClass() == "aptus_location_storage"
        or APTUSInventoryManager.isStructureInventory(node);
    APTUSLocationPermissions.subscribe(refreshPreview);
    if not bStructure then
        load_fill.setVisible(false);
        local root = APTUSStructureManager.getRootPath();
        for _, event in ipairs({"onChildAdded", "onChildDeleted", "onChildUpdate"}) do watch(root, event); end
        for _, field in ipairs({"name", "type", "features.storage.enabled", "inventorylist"}) do
            for _, event in ipairs({"onAdd", "onUpdate", "onDelete", "onChildUpdate", "onChildAdded", "onChildDeleted"}) do
                watch(root .. ".*." .. field, event);
            end
        end
        -- Observar también los campos concretos; no depender de propagación recursiva
        -- de onChildUpdate para cambios de cantidad, ubicación o Almacenaje.
        local fields = {"name", "count", "carried", "template_id", "template_version",
            "properties", "properties.type_id", "properties.is_container", "aptus",
            "aptus.instance_schema", "aptus.container"};
        for _, field in ipairs(APTUSInventoryManager.getEditableFields()) do table.insert(fields, field.path); end
        local seen = {};
        for _, field in ipairs(fields) do
            if not seen[field] then
                seen[field] = true;
                for _, event in ipairs({"onAdd", "onUpdate", "onDelete"}) do
                    watch(root .. ".*.inventorylist.*." .. field, event);
                end
            end
        end
    end
    if node then
        watch(DB.getPath(node), "onObserverUpdate");
        for _, event in ipairs({ "onAdd", "onUpdate", "onDelete" }) do
            if bStructure then watch(DB.getPath(node, "features.storage.enabled"), event);
            else
                watch(DB.getPath(node, "attributes.fue.effective"), event);
                watch(DB.getPath(node, "gender"), event);
            end
        end
        local path = DB.getPath(node, "inventorylist");
        for _, event in ipairs({"onAdd", "onUpdate", "onDelete"}) do
            watch(path .. ".*.properties.hide_contents", event, onContentsVisibilityChanged);
        end
        for _, event in ipairs({ "onAdd", "onDelete", "onChildAdded", "onChildDeleted" }) do watch(path, event); end
        for _, field in ipairs({ "name", "count", "carried", "template_id", "template_version",
            "properties", "properties.type_id", "properties.is_container", "aptus",
            "aptus.instance_schema", "aptus.container" }) do
            for _, event in ipairs({ "onAdd", "onUpdate", "onDelete" }) do watch(path .. ".*." .. field, event); end
        end
        for _, f in ipairs(APTUSInventoryManager.getEditableFields()) do
            if f.key ~= "name" then
                for _, event in ipairs({ "onAdd", "onUpdate", "onDelete" }) do watch(path .. ".*." .. f.path, event); end
            end
        end
    end
    bInitialized = true;
    if bStructure then refreshPreview(); else selectView(1); end
end

function onClose()
    bClosed = true;
    closeInspections();
    APTUSInventoryManager.removeOperationListener(flushInventoryRefresh);
    APTUSLocationPermissions.unsubscribe(refreshPreview);
    for _, handler in ipairs(tHandlers) do
        if handler.callback then DB.removeHandler(handler.path, handler.event, handler.callback);
        else DB.removeHandler(handler.path, handler.event, refreshPreview); end
    end
    tHandlers = {};
end

function selectView(n)
    nView = n;
    for i=1,5 do
        self["filter_label_" .. (i-1)].setFont(i == n and "aptus_font_location_underline" or "aptus_inventory_text");
    end
    heading_state.setVisible(n ~= 3 and n ~= 4);
    refreshPreview();
end

-- Recorrido en profundidad iterativo. Conserva ascendientes de coincidencias
-- e incluye descendientes de un nombre coincidente, como la maqueta anterior.
local function visibleGroup(root, searchText)
    local entries, stack = {}, { { item = root } };
    while #stack > 0 do
        local entry = table.remove(stack);
        local index = #entries + 1;
        local parent = entry.parent and entries[entry.parent];
        entry.match = searchText == "" or string.find(entry.item.name:lower(), searchText, 1, true) ~= nil;
        entry.ancestorMatch = parent and (parent.match or parent.ancestorMatch) or false;
        entry.visible = entry.match or entry.ancestorMatch;
        table.insert(entries, entry);
        for i = #entry.item.children, 1, -1 do
            if entry.item.children[i].visible_to_user then
                table.insert(stack, { item = entry.item.children[i], parent = index });
            end
        end
    end
    for i = #entries, 1, -1 do
        local entry = entries[i];
        if entry.visible and entry.parent then entries[entry.parent].visible = true; end
    end
    local rows = {};
    for _, entry in ipairs(entries) do if entry.visible then table.insert(rows, entry.item); end end
    return rows;
end

function refreshPreview()
    if not bInitialized or bClosed or not preview then return; end
    if APTUSInventoryManager.isUpdatingInventory() then bRefreshPending = true; return; end
    bRefreshPending = false;
    for path, window in pairs(inspectionWindows) do
        if not window.canViewInWindow() then window.close(); end
    end
    add_equipment.setVisible(nView <= 2 and APTUSInventoryManager.canManageCharacter(getDatabaseNode(), getActionContext()));
    preview.closeAll();
    preview_notice.setVisible(true);
    local inventory = APTUSInventoryManager.getCharacterInventory(getDatabaseNode(), getActionContext());
    if not bStructure then
    local status = APTUSInventoryManager.getLoadStatus(getDatabaseNode(), inventory);
    load_value.setValue((status.total_load ~= nil and tostring(status.total_load) or "—")
        .. " / " .. (status.capacity ~= nil and tostring(status.capacity) or "—"));
    load_hint.setValue(status.state or "Incompleta");
    load_silhouette.setIcon(status.icon or "");
    load_silhouette.setVisible(status.complete);
    load_hint.setColor(status.color or "FFE9D5AF");
    local consequences = tLoadConsequences[status.state] or {};
    load_penalty_1.setValue(consequences[1] or "");
    load_penalty_2.setValue(consequences[2] or "");
    load_penalty_1.setColor(status.color or "FFE9D5AF");
    load_penalty_2.setColor(status.color or "FFE9D5AF");
    local fillHeight = math.floor(180 * status.fraction + 0.5);
    load_fill.setAnchor("top", "", "top", "absolute", 280 - fillHeight);
    load_fill.setAnchoredHeight(fillHeight);
    if status.color then load_fill.setBackColor(status.color); end
    load_fill.setVisible(status.complete and fillHeight > 0);
    local detail = status.complete and ("CAR: " .. tostring(status.total_load) .. " / " .. tostring(status.capacity) .. " · " .. status.state)
        or "Datos incompletos de FUE, carga o Almacenaje. No se estima el estado.";
    if #consequences > 0 then detail = detail .. "\nRegla: " .. table.concat(consequences, " / ") .. "."; end
    detail = detail .. "\nIndicador informativo: no modifica AGI, Defensa ni Movimiento.";
    load_value.setTooltipText(detail); load_hint.setTooltipText(detail);
    end
    local searchText = StringManager.trim(search.getValue()):lower();
    local nRows, contentHeight, wFirstRow, wReveal = 0, 0, nil, nil;
    if nView == 1 or nView == 2 then
        for _, root in ipairs(inventory.roots) do
            local rows = visibleGroup(root, searchText);
            for i, item in ipairs(rows) do
                local w = preview.createWindow();
                wFirstRow = wFirstRow or w;
                if item.path == sRevealPath then wReveal = w; end
                nRows = nRows + 1;contentHeight = contentHeight + 24;
                w.setPreview(item, i > 1, i < #rows, i == 1 and #rows > 1, bStructure, self);
            end
        end
    end
    if not bStructure and (nView == 1 or nView == 3 or nView == 4) then
        local top = WindowManager.getTopWindow(self);
        local viewer = top.getStructureViewer();
        local categories = nView == 1 and {"locations", "vehicles"} or {nView == 3 and "locations" or "vehicles"};
        for _, category in ipairs(categories) do
            for _, group in ipairs(APTUSStructureManager.getResourceGroups(category, viewer, nView == 1)) do
                local matches, blocks = {}, {};
                local groupMatch = searchText == "" or string.find(group.name:lower(), searchText, 1, true) ~= nil;
                for _, root in ipairs(group.inventory.roots) do
                    local rows = visibleGroup(root, groupMatch and "" or searchText);
                    if #rows > 0 then table.insert(blocks, rows); end
                end
                for rootIndex, rows in ipairs(blocks) do
                    for i, item in ipairs(rows) do
                        table.insert(matches, {item=item, descendant=i>1, following=i<#rows,
                            hasDescendants=i==1 and #rows>1, nextRoot=rootIndex<#blocks});
                    end
                end
                if groupMatch or #matches > 0 then
                    local header = preview.createWindowWithClass("aptus_inventory_structure_group");
                    wFirstRow = wFirstRow or header;nRows = nRows + 1;
                    contentHeight = contentHeight + 24;
                    header.setGroup(group, self);
                    for _, entry in ipairs(matches) do
                        local w = preview.createWindowWithClass("aptus_structure_inventory_consult_row");
                        w.setPreview(entry.item, entry.descendant, entry.following, entry.hasDescendants, true, self, {following=entry.nextRoot});
                        nRows = nRows + 1;contentHeight = contentHeight + 24;
                    end
                end
            end
        end
    end
    local message = "Sin instancias APTUS compatibles en este inventario.";
    if searchText ~= "" then message = bStructure and "Sin resultados en Almacenaje." or "Sin resultados en el inventario del personaje."; end
    if nView == 3 or nView == 4 then message = "Sin estructuras visibles o sin coincidencias.";
    elseif nView == 5 then message = "Vista pendiente de integración · sólo inventario del personaje."; end
    empty_message.setValue(message);
    empty_message.setVisible(nRows == 0);
    local notice = bStructure and "Almacenaje de la estructura" or "Inventario del personaje · Estado de lectura";
    if #inventory.diagnostics > 0 then notice = notice .. " · avisos: " .. #inventory.diagnostics; end
    if not bStructure and nView == 1 then notice = "Personaje · Localizaciones · Vehículos";
    elseif not bStructure and (nView == 3 or nView == 4) then notice = "Recursos de estructuras · sólo consulta"; end
    preview_notice.setValue(notice);
    preview_notice.setTooltipText(table.concat(inventory.diagnostics, "\n"));
    local _, height = preview.getSize();
    preview_scrollbar.setVisible(contentHeight > height);
    if wReveal or wFirstRow then preview.scrollToWindow(wReveal or wFirstRow); end
    sRevealPath = nil;
end

-- Ambas interacciones terminan aquí y en una única operación del gestor.
function createFromCatalogue(path, quantity, parent, context)
    context = context or getActionContext();
    if bClosed or bCreating or nView > 2 or not APTUSInventoryManager.isContextValid(context) then return; end
    bCreating = true;
    local ok, node, reason = pcall(APTUSInventoryManager.createFromTemplate, getDatabaseNode(), DB.findNode(path), quantity, parent, context);
    bCreating = false;
    if not ok then
        Debug.console("APTUS inventario [solicitud de alta] " .. tostring(node));
        ChatManager.SystemMessage("No se pudo crear la instancia. Revisar consola y permisos.");
        return;
    end
    if not node then ChatManager.SystemMessage(reason); return; end
    if search.getValue() ~= "" then search.setValue(""); end
    sRevealPath = DB.getPath(node);
    refreshPreview();
end

function addFromCatalogue()
    local actionContext = getActionContext();
    if bClosed or nView > 2 or not APTUSInventoryManager.canManageCharacter(getDatabaseNode(), getActionContext()) then return; end
    local options = APTUSEquipmentManager.getCatalogueSelectionOptions();
    if #options == 0 then ChatManager.SystemMessage("No hay plantillas APTUS válidas disponibles. Comprueba catálogo y módulos."); return; end
    local selection = { title="Añadir equipo", msg="Selecciona una plantilla para crear una instancia independiente.",
        options=options, min=1, max=1, showmodule=true,
        callback=function(selections, context, links)
            if bClosed or not APTUSInventoryManager.isContextValid(actionContext) then return; end
            local link = links and links[1];
            if link and link.linkclass == "aptus_equipment" then
                APTUSInventoryManager.requestQuantityInput("Unidades que se añadirán al inventario", 1,
                    function(quantity) if not bClosed then createFromCatalogue(link.linkrecord, quantity, nil, actionContext); end end, actionContext);
            end
        end,
    };
    APTUSEquipmentManager.openTemplateSelection(selection);
    APTUSInventoryManager.trackContextDialog(actionContext, Interface.findWindow("aptus_equipment_select_dialog", ""),
        "aptus_equipment_select_dialog", selection);
end

function dropFromCatalogue(draginfo, parent)
    if draginfo.getType() ~= "shortcut" then return true; end
    -- Consumir enlaces rechazados: no dejar que un ancestro ejecute ItemManager.
    if bClosed or nView > 2 or not APTUSInventoryManager.canManageCharacter(getDatabaseNode(), getActionContext()) then return true; end
    local class, path = draginfo.getShortcutData();
    if class == "aptus_inventory_item" then
        local result, reason = APTUSInventoryManager.transfer(DB.findNode(path), getDatabaseNode(), nil, parent, nil, getActionContext());
        if not result then ChatManager.SystemMessage(reason); end
        refreshPreview(); return true;
    end
    if class ~= "aptus_equipment" then
        ChatManager.SystemMessage("Sólo se admiten plantillas o instancias APTUS.");
        return true;
    end
    createFromCatalogue(path, 1, parent);
    return true;
end

function onDrop(x, y, draginfo)
    return dropFromCatalogue(draginfo);
end

function update() refreshPreview(); end

function getActionContext()
    if bClosed then return {aptus_inventory_context=true, isValid=function() return false; end}; end
    if bStructure then return nil; end
    local top = WindowManager.getTopWindow(self);
    return top.getInventoryContext and top.getInventoryContext() or nil;
end
function isReadOnlyInventory() return false; end
function canInspectItem(path, context)
    return not bClosed and (not context or APTUSInventoryManager.isContextValid(context))
        and APTUSInventoryManager.canViewInstance(DB.findNode(path), context);
end
function openStructure(path)
    if bClosed or bStructure or not path then return false; end
    local node = DB.findNode(path);
    local viewer = getActionContext() or WindowManager.getTopWindow(self).getStructureViewer();
    -- Visibilidad, no Acceso a recursos: también permite fichas con Almacenaje desactivado/vacío.
    if not node or not APTUSStructureManager.canViewAs(node, viewer) then return false; end
    local category = APTUSStructureManager.getCategory(node);
    local class;
    if category == "locations" then class = "aptus_location";
    elseif category == "vehicles" then class = "aptus_structure";
    else return false; end
    -- La ficha independiente conserva la identidad y permisos reales, también en Impersonar.
    local existing = Interface.findWindow(class, path);
    if existing then existing.bringToFront(); else Interface.openWindow(class, node); end
    return true;
end
-- Validación de lectura compartida por apertura y refresco de la ficha consultada.
function canInspectStructureItem(path)
    if bClosed or bStructure or not path then return false; end
    local node = DB.findNode(path);
    local owner = node and APTUSInventoryManager.getInventoryOwner(node);
    if not owner or not APTUSInventoryManager.isStructureInventory(owner) then return false; end
    local viewer = WindowManager.getTopWindow(self).getStructureViewer();
    local snapshot = APTUSInventoryManager.getViewedInventory(owner, viewer);
    for _, item in ipairs(snapshot.items) do if item.path == path then return true; end end
    return false;
end
function closeInspections()
    local windows = inspectionWindows;inspectionWindows = {};
    for _, window in pairs(windows) do window.close(); end
end
function forgetInspection(path, window)
    if inspectionWindows[path] == window then inspectionWindows[path] = nil; end
end
function inspectStructureItem(path) return inspectItem(path, true); end
function inspectItem(path, external)
    local context = getActionContext();
    if external then
        if not canInspectStructureItem(path) then return false; end
    elseif not canInspectItem(path, context) then return false; end
    local viewer = WindowManager.getTopWindow(self).getStructureViewer();
    local class = context and "aptus_inventory_item_consult"
        or (APTUSStructureManager.isHostViewer(viewer) and "aptus_inventory_item" or "aptus_inventory_item_consult");
    local existing = Interface.findWindow(class, path);
    if class == "aptus_inventory_item" then
        if existing then existing.bringToFront(); else Interface.openWindow(class, path); end
        return true;
    end
    -- Una clase/ruta nativa identifica una ventana. Nunca mezclar contextos al reutilizarla.
    if existing then existing.close(); end
    local window = Interface.openWindow(class, path);
    if not window then return false; end
    inspectionWindows[path] = window;
    window.configureInspection(self, context);
    return true;
end
function onStructureViewerChanged()
    closeInspections();
    if not bStructure then refreshPreview(); end
end

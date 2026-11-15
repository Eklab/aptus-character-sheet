-- Vista de inventario: operaciones estructurales delegadas al gestor común.
local nView = 1;
local tHandlers = {};
local bClosed, bCreating = false, false;
local sRevealPath;
local bRefreshPending = false;

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
    -- El primer refresco utiliza sólo la carga y FUE reales.
    load_fill.setVisible(false);
    local node = getDatabaseNode();
    if node then
        watch(DB.getPath(node), "onObserverUpdate");
        for _, event in ipairs({ "onAdd", "onUpdate", "onDelete" }) do
            watch(DB.getPath(node, "attributes.fue.effective"), event);
            watch(DB.getPath(node, "gender"), event);
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
    selectView(1);
end

function onClose()
    bClosed = true;
    APTUSInventoryManager.removeOperationListener(flushInventoryRefresh);
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
    if bClosed or not preview then return; end
    if APTUSInventoryManager.isUpdatingInventory() then bRefreshPending = true; return; end
    bRefreshPending = false;
    add_equipment.setVisible(nView <= 2 and APTUSInventoryManager.canManageCharacter(getDatabaseNode()));
    preview.closeAll();
    local inventory = APTUSInventoryManager.getCharacterInventory(getDatabaseNode());
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
    local searchText = StringManager.trim(search.getValue()):lower();
    local nRows, wFirstRow, wReveal = 0, nil, nil;
    if nView == 1 or nView == 2 then
        for _, root in ipairs(inventory.roots) do
            local rows = visibleGroup(root, searchText);
            for i, item in ipairs(rows) do
                local w = preview.createWindow();
                wFirstRow = wFirstRow or w;
                if item.path == sRevealPath then wReveal = w; end
                nRows = nRows + 1;
                w.setPreview(item, i > 1, i < #rows, i == 1 and #rows > 1, false, self);
            end
        end
    end
    local message = "Sin instancias APTUS compatibles en este inventario.";
    if searchText ~= "" then message = "Sin resultados en el inventario del personaje."; end
    if nView >= 3 then message = "Vista pendiente de integración · sólo inventario del personaje."; end
    empty_message.setValue(message);
    empty_message.setVisible(nRows == 0);
    local notice = "Inventario del personaje · Estado de lectura";
    if #inventory.diagnostics > 0 then notice = notice .. " · avisos: " .. #inventory.diagnostics; end
    preview_notice.setValue(notice);
    preview_notice.setTooltipText(table.concat(inventory.diagnostics, "\n"));
    local _, height = preview.getSize();
    preview_scrollbar.setVisible(nRows * 24 > height);
    if wReveal or wFirstRow then preview.scrollToWindow(wReveal or wFirstRow); end
    sRevealPath = nil;
end

-- Ambas interacciones terminan aquí y en una única operación del gestor.
function createFromCatalogue(path, quantity, parent)
    if bClosed or bCreating or nView > 2 then return; end
    bCreating = true;
    local ok, node, reason = pcall(APTUSInventoryManager.createFromTemplate, getDatabaseNode(), DB.findNode(path), quantity, parent);
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
    if bClosed or nView > 2 or not APTUSInventoryManager.canManageCharacter(getDatabaseNode()) then return; end
    local options = APTUSEquipmentManager.getCatalogueSelectionOptions();
    if #options == 0 then ChatManager.SystemMessage("No hay plantillas APTUS válidas disponibles. Comprueba catálogo y módulos."); return; end
    APTUSEquipmentManager.openTemplateSelection({ title="Añadir equipo", msg="Selecciona una plantilla para crear una instancia independiente.",
        options=options, min=1, max=1, showmodule=true,
        callback=function(selections, context, links)
            if bClosed then return; end
            local link = links and links[1];
            if link and link.linkclass == "aptus_equipment" then
                APTUSInventoryManager.requestQuantityInput("Unidades que se añadirán al inventario", 1,
                    function(quantity) if not bClosed then createFromCatalogue(link.linkrecord, quantity); end end);
            end
        end,
    });
end

function dropFromCatalogue(draginfo, parent)
    if draginfo.getType() ~= "shortcut" then return true; end
    -- Consumir enlaces rechazados: no dejar que un ancestro ejecute ItemManager.
    if bClosed or nView > 2 or not APTUSInventoryManager.canManageCharacter(getDatabaseNode()) then return true; end
    local class, path = draginfo.getShortcutData();
    if class == "aptus_inventory_item" then
        local result, reason = APTUSInventoryManager.transfer(DB.findNode(path), getDatabaseNode(), nil, parent);
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

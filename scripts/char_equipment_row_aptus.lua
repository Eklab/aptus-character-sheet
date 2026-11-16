-- Controles de presentación: no se reutiliza char_invitem, que sí gestiona inventario real.
local tSegments = {};
local sInstancePath;
local wEquipment;
local isContainer;
local bReadOnly = false;
local showAdmin = false;
local nameWidget, capacityWidget, hiddenWidget, locationWidget;
local function actionContext() return wEquipment and wEquipment.getActionContext and wEquipment.getActionContext() or nil; end
function onInit()
    bReadOnly = getClass() == "aptus_structure_inventory_consult_row";
    if bReadOnly then return; end
    registerMenuItem("Cambiar cantidad / eliminar unidades", "button_toolbar_link", 7);
    registerMenuItem("Fusionar pilas compatibles", "button_toolbar_link", 8);
    registerMenuItem("Mover a raíz del inventario", "button_toolbar_link", 6);
end
function onMenuSelection(selection)
    if bReadOnly then return false; end
    local node = sInstancePath and DB.findNode(sInstancePath);
    if selection == 7 then APTUSInventoryManager.requestSetQuantity(node, actionContext());
    elseif selection == 8 then
        local result, reason = APTUSInventoryManager.mergeStacks(node, actionContext());
        if not result then ChatManager.SystemMessage(reason); end
    elseif selection == 6 then
        local result, reason = APTUSInventoryManager.transfer(node, APTUSInventoryManager.getInstanceCharacter(node), nil, nil, nil, actionContext());
        if not result then ChatManager.SystemMessage(reason); end
    end
end
function startInventoryDrag(draginfo)
    if bReadOnly then return false; end
    if not sInstancePath then return false; end
    if not APTUSInventoryManager.canViewInstance(DB.findNode(sInstancePath), actionContext()) then return false; end
    draginfo.setType("shortcut");
    draginfo.setShortcutData("aptus_inventory_item", sInstancePath);
    return true;
end

function editQuantity()
    if bReadOnly then return false; end
    local node = sInstancePath and DB.findNode(sInstancePath);
    if not APTUSInventoryManager.canViewInstance(node, actionContext()) then return false; end
    local stackable = DB.getChild(node, "properties.stackable");
    if not stackable or DB.getType(stackable) ~= "number"
        or DB.getValue(stackable) ~= 1 or DB.getValue(node, "properties.is_container", 1) ~= 0 then return false; end
    APTUSInventoryManager.requestSetQuantity(node, actionContext());
    return true;
end

local nNameLeft, nNameRight = 0, 215;
local nStep, nRowHeight, nMiddle = 18, 24, 12;

local function clearSegments()
    for _, c in ipairs(tSegments) do c.destroy(); end
    tSegments = {};
end

-- Recorte explícito antes de crear controles: nunca se dibuja sobre otra columna.
local function segment(x, y, nWidth, nHeight)
    local nRight = math.min(nNameRight, x + nWidth);
    x = math.max(0, x);
    if nRight <= x or nHeight <= 0 then return; end
    local c = createControl("aptus_inventory_tree_segment", "tree_segment_" .. (#tSegments + 1));
    c.setAnchor("left", "", "left", "absolute", x);
    c.setAnchor("top", "", "top", "absolute", y);
    c.setAnchoredWidth(nRight - x);
    c.setAnchoredHeight(nHeight);
    table.insert(tSegments, c);
end

local function drawHierarchy(bDescendant, bFollowing, bHasDescendants, groupBranch)
    clearSegments();
    if groupBranch then
        -- Rama del grupo virtual; los contenedores reales conservan su propia indentación.
        if not bDescendant then
            segment(5, 0, 1, groupBranch.following and nRowHeight or nMiddle + 1);
            segment(5, nMiddle, 13, 1);
        elseif groupBranch.following then segment(5, 0, 1, nRowHeight); end
    end
    local x = nNameLeft + 5;
    if bDescendant then
        segment(x, 0, 1, bFollowing and nRowHeight or nMiddle + 1);
        segment(x, nMiddle, nStep - 5, 1);
    elseif bHasDescendants then
        -- Sale por debajo del icono raíz y enlaza con su primer descendiente.
        segment(x, 22, 1, nRowHeight - 22);
    end
end

local function renderItemName(item, available)
    local hidden = item.is_container and item.hide_contents;
    if hidden and not hiddenWidget then
        hiddenWidget = item_name.addBitmapWidget({icon="padlock_closed", w=12, h=12});
    end
    if hiddenWidget then hiddenWidget.setVisible(hidden); end
    -- Reserva al final: candado de 12 px con 3 px de separación.
    local lockSpace = hidden and 15 or 0;
    available = available - lockSpace;
    if not item.is_container then
        item_name.setValue(item.name);
        if nameWidget then nameWidget.setText(""); capacityWidget.setText(""); end
        return;
    end
    item_name.setValue("");
    if not nameWidget then
        nameWidget = item_name.addTextWidget({font=item_name.getFont(), text=""});
        capacityWidget = item_name.addTextWidget({font=item_name.getFont(), text=""});
    end
    capacityWidget.setText(APTUSInventoryManager.getContainerLoadIndicator(item));
    capacityWidget.setColor(item.hide_contents and "FFB8B8B8" or (item.overloaded and "FFFF4040" or nil));
    capacityWidget.setMaxWidth(math.max(1, available - 15));
    local capacityWidth = capacityWidget.getSize();
    nameWidget.setText((item.name:gsub("[\r\n\t]", " ")));
    nameWidget.setColor(item.hide_contents and "FFB8B8B8" or nil);
    nameWidget.setMaxWidth(math.max(1, available - capacityWidth - 3));
    local nameWidth = nameWidget.getSize();
    nameWidget.setPosition("left", nameWidth / 2, 0);
    capacityWidget.setPosition("left", nameWidth + 3 + capacityWidth / 2, 0);
    if hidden then
        hiddenWidget.setPosition("left", nameWidth + 3 + capacityWidth + 3 + 6, 0);
    end
end

function setPreview(tItem, bDescendant, bFollowing, bHasDescendants, bHideState, owner, groupBranch)
    sInstancePath, wEquipment = tItem.path, owner;
    bReadOnly = bReadOnly or (owner and owner.isReadOnlyInventory and owner.isReadOnlyInventory()) or false;
    showAdmin = Session.IsHost and tItem.viewer_is_host ~= false;
    if getClass() == "aptus_structure_inventory_row" then nNameRight = 163; end
    nNameLeft = groupBranch and 18 or 0;
    isContainer = tItem.is_container;
    type_icon.setIcon(tItem.icon);
    count.setValue(string.format("%.0f", tItem.count));
    state.setReadOnly(true);
    state.setValue(tItem.state or "");
    if getClass() == "aptus_structure_inventory_consult_row" then
        -- El widget nativo limita el texto al ancho de la celda; el tooltip conserva la ruta.
        location.setValue("");
        if not locationWidget then locationWidget = location.addTextWidget({font=location.getFont(), text=""}); end
        local width = location.getSize();
        locationWidget.setText((tItem.location:gsub("[\r\n\t]", " ")));
        locationWidget.setMaxWidth(width);
        local textWidth = locationWidget.getSize();
        locationWidget.setPosition("left", textWidth / 2, 0);
    else location.setValue(tItem.location); end
    load.setValue(tItem.load ~= nil and tostring(tItem.load) or "—");
    drawHierarchy(bDescendant, bFollowing, bHasDescendants, groupBranch);
    -- Única indentación visual de 18 px, sin alterar la jerarquía de datos.
    local nIconLeft = nNameLeft + (bDescendant and nStep or 0);
    local nTextLeft = nIconLeft + 34;
    type_icon.setAnchor("left", "", "left", "absolute", nIconLeft);
    type_icon.setTooltipText(tItem.name);
    item_name.setAnchor("left", "", "left", "absolute", nTextLeft);
    item_name.setAnchoredWidth(nNameRight - nTextLeft);
    renderItemName(tItem, nNameRight - nTextLeft);
    local nameTooltip = tItem.name;
    if tItem.is_container then
        nameTooltip = nameTooltip .. APTUSInventoryManager.getContainerLoadIndicator(tItem)
            .. "\nCAR propia: " .. tostring(tItem.own_load or "—")
            .. " · CAR efectiva: " .. tostring(tItem.effective_load or "—");
    end
    if showAdmin and tItem.hide_contents then nameTooltip = nameTooltip .. "\nContenido oculto para jugadores (indicador administrativo)."; end
    item_name.setTooltipText(nameTooltip);
    -- Localizaciones y vehículos carecen de control de Estado también en Todo.
    state.setVisible(not bHideState and tItem.state ~= nil);
    location.setTooltipText(tItem.location);
end

function openInstance()
    if wEquipment and wEquipment.getActionContext and wEquipment.getActionContext() then
        return wEquipment.inspectItem(sInstancePath, bReadOnly);
    end
    if bReadOnly then
        if wEquipment and wEquipment.inspectStructureItem then return wEquipment.inspectStructureItem(sInstancePath); end
        return false;
    end
    local node = sInstancePath and DB.findNode(sInstancePath);
    if APTUSInventoryManager.canViewInstance(node, actionContext()) then
        local existing = Interface.findWindow("aptus_inventory_item", DB.getPath(node));
        if existing then existing.bringToFront();
        else Interface.openWindow("aptus_inventory_item", node); end
    end
end

function chooseLocation()
    if bReadOnly then return false; end
    local node = sInstancePath and DB.findNode(sInstancePath);
    APTUSInventoryManager.requestLocation(node, function(ok, problem)
        if not ok and problem then ChatManager.SystemMessage(problem); end
        -- Los handlers DB agrupan el refresco al terminar la operación.
    end, actionContext());
end

function onDrop(x, y, draginfo)
    if bReadOnly then return true; end
    if wEquipment then return wEquipment.dropFromCatalogue(draginfo, isContainer and DB.findNode(sInstancePath) or nil); end
    return false;
end

function chooseState()
    if bReadOnly then return false; end
    local node = sInstancePath and DB.findNode(sInstancePath);
    APTUSInventoryManager.requestState(node, function(ok, problem)
        if not ok and problem then ChatManager.SystemMessage(problem); end
    end, actionContext());
end

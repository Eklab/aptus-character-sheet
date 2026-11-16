-- Cabecera virtual de 24 px, siempre desplegada, sin nodo DB ni acciones de inventario.
local structurePath, equipment, viewWidget, nameWidget;
function setGroup(group, owner)
    structurePath, equipment = group.path, owner;
    -- Mayúsculas sólo de presentación; string.upper no convierte los acentos UTF-8.
    local title = group.name:gsub("[\r\n\t]", " "):upper();
    for lower, upper in pairs({["á"]="Á",["é"]="É",["í"]="Í",["ó"]="Ó",["ú"]="Ú",["ü"]="Ü",["ñ"]="Ñ"}) do
        title = title:gsub(lower, upper);
    end
    name.setValue("");
    if not nameWidget then nameWidget = name.addTextWidget({font=name.getFont(), text=""}); end
    nameWidget.setText(title);
    local width = name.getSize();
    nameWidget.setMaxWidth(width);
    local textWidth = nameWidget.getSize();
    nameWidget.setPosition("left", textWidth / 2, 0);
    name.setTooltipText(group.name .. (group.message and ("\n" .. group.message) or ""));
    kind.setIcon(group.category == "locations" and "aptus_localizacion_item" or "aptus_vehicle_item");
    branch.setVisible(#group.inventory.items > 0);
    message.setValue(group.message or "");
    message.setTooltipText(group.message or "");
    message.setVisible(group.message ~= nil);
    location.setVisible(group.message == nil);
    load.setVisible(group.message == nil);
    if viewWidget then viewWidget.destroy(); end
    viewWidget = open_structure.addBitmapWidget({
        icon=group.category == "locations" and "aptus_localizacion_view" or "aptus_vehicle_view", w=25, h=24 });
    open_structure.setTooltipText(group.category == "locations" and "Abrir ficha de Localización" or "Abrir ficha de Vehículo");
end
function openStructure()
    if equipment and structurePath then return equipment.openStructure(structurePath); end
    return false;
end
-- No propagar arrastres ni caídas al inventario del personaje.
function onDragStart() return false; end
function onDrop() return true; end

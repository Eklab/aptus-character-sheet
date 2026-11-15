-- Referencia compartida al perfil del borrador; sin acceso DB.
local entry, owner, key, popup;
local editable, alive = false, true;

function onInit() APTUSQualityManager.subscribe(refreshSummary); end
function onClose()
    alive = false;
    closeConfiguration();
    APTUSQualityManager.unsubscribe(refreshSummary);
end
function configure(value, context, id, _, canEdit)
    entry, owner, key = value, context, id;
    setEditable(canEdit);
    refreshSummary();
end
-- Medición y recorte con widgets nativos; hasta cuatro líneas por fila.
local measureWidget;
local textWidgets = {};
local function width(text)
    if not measureWidget then measureWidget = cell_profile_name.addTextWidget({font="aptus_equipment_compact", text=""}); end
    measureWidget.setText(text);
    local size = measureWidget.getSize();
    measureWidget.setText("");
    return size;
end
local function wrap(text, available, maximum)
    local lines, line = {}, "";
    for word in tostring(text):gmatch("%S+") do
        local candidate = line == "" and word or line .. " " .. word;
        if line ~= "" and width(candidate) > available then
            table.insert(lines, line); line = word;
        else line = candidate; end
    end
    if line ~= "" then table.insert(lines, line); end
    if #lines == 0 then lines[1] = "—"; end
    if #lines > maximum then
        for i = #lines, maximum + 1, -1 do lines[i] = nil; end
        lines[maximum] = lines[maximum] .. "…";
    end
    return lines;
end
local function prepare(control, lines, available, centered, font, maximumHeight)
    local widgets = textWidgets[control];
    if not widgets then widgets = {}; textWidgets[control] = widgets; end
    local block = { lines = {}, height = 0 };
    for i = 1, math.max(#lines, #widgets) do
        if not widgets[i] then widgets[i] = control.addTextWidget({font=font or "aptus_equipment_compact", text=""}); end
        local widget = widgets[i];
        widget.setText(lines[i] or ""); widget.setMaxWidth(available);
        if lines[i] then
            local width, height = widget.getSize();
            table.insert(block.lines, { widget=widget, text=lines[i], x=centered and available / 2 or width / 2, height=height });
            block.height = block.height + height;
        end
    end
    -- Respetar la altura máxima incluso si el motor devuelve métricas mayores.
    local clipped = false;
    while block.height > (maximumHeight or 56) and #block.lines > 1 do
        local removed = table.remove(block.lines);
        removed.widget.setText("");
        block.height = block.height - removed.height;
        clipped = true;
    end
    if clipped then
        local last = block.lines[#block.lines];
        last.widget.setText(last.text .. "…");
        last.widget.setMaxWidth(available);
        local size = last.widget.getSize();
        last.x = centered and available / 2 or size / 2;
    end
    return block;
end
local function position(block, top)
    for i = 1, #block.lines do
        local line = block.lines[i];
        line.widget.setPosition("topleft", line.x, top + line.height / 2);
        top = top + line.height;
    end
end
function refreshSummary()
    if not alive or not entry then return; end
    local function value(name, default)
        local result = APTUSEquipmentManager.getEntryValue(entry, name, default);
        if result == "" and default == "—" then return "—"; end
        return result;
    end
    local skill = value("attack_skill_id", "");
    skill = skill == "pelea" and "Pelea" or (skill == "punteria" and "Puntería" or skill);
    local modifier = value("attack_modifier", 0);
    if modifier ~= 0 then skill = skill .. " " .. (modifier > 0 and "+" or "") .. tostring(modifier) .. "d"; end
    local names, codes = {}, {};
    local types = APTUSEquipmentManager.getDamageTypes();
    for i = 1, #types do
        if APTUSEquipmentManager.hasProfileDamageType(entry, types[i].id) then
            table.insert(codes, types[i].abbreviation); table.insert(names, types[i].name);
        end
    end
    -- Separar códigos por espacios tras la barra permite envolver sin alterar su orden.
    local typeLines = wrap(#codes > 0 and table.concat(codes, "/ ") or "—", 46, 3);
    for i = 1, #typeLines do typeLines[i] = typeLines[i]:gsub("/ ", "/"); end
    local qualityKeys, qualityNames = {}, {};
    for id in pairs(entry.qualities or {}) do table.insert(qualityKeys, id); end
    table.sort(qualityKeys);
    local qualityLines = {};
    for i = 1, #qualityKeys do
        local name = APTUSQualityManager.describe(entry.qualities[qualityKeys[i]]);
        table.insert(qualityNames, name);
        local lines = wrap(name, 72, 4);
        for j = 1, #lines do table.insert(qualityLines, lines[j]); end
    end
    if #qualityLines == 0 then qualityLines = {"Nada"}; end
    if #qualityLines > 4 then
        for i = #qualityLines, 5, -1 do qualityLines[i] = nil; end
        qualityLines[4] = qualityLines[4] .. "…";
    end
    local name = value("name", "");
    local nameLines = wrap(name, 68, 4);
    local ammo = value("uses_ammunition", nil);
    local damage = prepare(cell_damage, {tostring(value("damage", "—"))}, 46, true, "aptus_profile_damage");
    local typesBlock = prepare(cell_types, typeLines, 46, true, nil, 56 - damage.height);
    -- DAÑO es una sola celda: dado y tipos se centran como un bloque indivisible.
    local damageHeight = damage.height + typesBlock.height;
    local blocks = {
        prepare(cell_profile_name, nameLines, 68, false),
        prepare(cell_skill, {skill}, 63, true),
        prepare(cell_range, {tostring(value("range", "—"))}, 22, true),
        prepare(cell_critical, {tostring(value("critical", "—"))}, 23, true),
        prepare(cell_ammo, {ammo == 1 and "Sí" or ""}, 24, true),
        prepare(cell_capacity, {ammo == 1 and tostring(value("ammunition_max", "—")) or ""}, 34, true),
        prepare(cell_qualities, qualityLines, 72, false),
    };
    local contentHeight = damageHeight;
    for i = 1, #blocks do contentHeight = math.max(contentHeight, blocks[i].height); end
    local height = math.min(64, math.max(36, contentHeight + 8));
    local bodyHeight = height;
    ammunition_summary.setVisible(ammo == 1);
    ammunition_summary.setAnchor("top", "", "top", "absolute", ammo == 1 and bodyHeight or 0);
    ammunition_summary.setAnchoredHeight(ammo == 1 and 16 or 1);
    local ammoBlock = prepare(ammunition_summary, ammo == 1 and {APTUSEquipmentManager.formatProfileAmmunition(entry)} or {}, 380, false);
    if ammo == 1 then
        height = height + 16;
        position(ammoBlock, (16 - ammoBlock.height) / 2);
    end
    row_art.setAnchoredHeight(height); open_profile.setAnchoredHeight(height);
    open_art.setAnchor("left", "", "left", "absolute", 384);
    open_art.setAnchor("top", "", "top", "absolute", math.floor((height - 24) / 2));
    open_art.setAnchoredWidth(25); open_art.setAnchoredHeight(24);
    local cells = {cell_profile_name, cell_skill, cell_range, cell_damage, cell_types, cell_critical, cell_ammo, cell_capacity, cell_qualities};
    for i = 1, #cells do
        cells[i].setAnchor("top", "", "top", "absolute", 0);
        cells[i].setAnchoredHeight(bodyHeight);
    end
    for i = 1, #blocks do position(blocks[i], (bodyHeight - blocks[i].height) / 2); end
    local damageTop = (bodyHeight - damageHeight) / 2;
    position(damage, damageTop);
    position(typesBlock, damageTop + damage.height);
    local tooltip = name .. " | " .. skill .. " | ALC: " .. tostring(value("range", "—"))
        .. " | Daño: " .. tostring(value("damage", "—")) .. " | Crítico: " .. tostring(value("critical", "—"))
        .. "\nTipos: " .. (#names > 0 and table.concat(names, ", ") or "Nada")
        .. (ammo == 1 and ("\n" .. APTUSEquipmentManager.formatProfileAmmunition(entry)
            .. " · " .. APTUSEquipmentManager.getProfileAmmunitionName(entry)) or "")
        .. "\nCualidades: " .. (#qualityNames > 0 and table.concat(qualityNames, ", ") or "Nada")
        .. "\n" .. APTUSQualityManager.details(entry.qualities);
    for i = 1, #cells do cells[i].setTooltipText(tooltip); end
    ammunition_summary.setTooltipText(tooltip);
    open_profile.setTooltipText("Configurar perfil de combate\n" .. tooltip);
end
function capture()
    if popup then popup.capture(); end
    refreshSummary();
end
function closeConfiguration()
    if popup then
        local window = popup;
        popup = nil;
        window.close();
    end
end
function setEditable(value)
    if editable and not value then capture(); closeConfiguration(); end
    editable = value == true;
    open_profile.setReadOnly(not editable);
    open_art.setVisible(editable);
end
function openIfKey(id) if id == key then openConfiguration(); end end
function openConfiguration()
    if not alive or not editable or not owner.isEditable() then return; end
    if popup then popup.bringToFront(); return; end
    -- Una configuración activa: cerrar la anterior conserva su borrador y libera sus callbacks.
    local previous = Interface.findWindow("aptus_equipment_profile_configuration", "");
    if previous then previous.close(); end
    local window = Interface.openWindow("aptus_equipment_profile_configuration", "");
    if not window then return; end
    popup = window;
    window.configure(entry, owner, key, function()
        if popup == window then popup = nil; end
        refreshSummary();
    end);
end

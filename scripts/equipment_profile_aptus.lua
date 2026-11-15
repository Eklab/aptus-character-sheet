-- Controles existentes y selección compacta de tipos de daño; los controles siguen perteneciendo al borrador del padre.
local entry, owner, key, editable, alive = nil, nil, nil, false, true;
local damageControls = {};
local updatingDamageTypes = false;
local fields = { { "name", "string", "" }, { "range", "string", "" },
    { "attack_modifier", "number", 0 }, { "damage", "string", "" }, { "critical", "string", "" },
    { "uses_ammunition", "number", 0 }, { "ammunition_max", "number", 0 },
    { "ammunition_consumption", "number", 1 } };
function onInit() APTUSQualityManager.subscribe(refreshQualities); end
function onClose() capture(); alive = false; APTUSQualityManager.unsubscribe(refreshQualities); end
function configure(t, parent, id, _, canEdit)
    entry, owner, key = t, parent, id;
    for _, f in ipairs(fields) do self["edit_" .. f[1]].setValue(APTUSEquipmentManager.getEntryValue(entry, f[1], f[3])); end
    skill_display.setValue(APTUSEquipmentManager.getEntryValue(entry, "attack_skill_id", "pelea") == "pelea" and "Pelea" or "Puntería");
    configureDamageTypes();
    setEditable(canEdit); refreshQualities(); refreshAmmunition();
end
function setEditable(value)
    editable = value == true;
    for _, f in ipairs(fields) do self["edit_" .. f[1]].setReadOnly(not editable); end
    skill_change.setReadOnly(not editable); delete_button.setVisible(editable);
    for _, control in pairs(damageControls) do
        control.setReadOnly(not editable or APTUSEquipmentManager.validateDamageTypes(entry and entry.damage_types) ~= nil);
    end
    updateAmmo();
end
function capture()
    if not entry or not editable then return; end
    for _, f in ipairs(fields) do
        local value = self["edit_" .. f[1]].getValue();
        if value ~= APTUSEquipmentManager.getEntryValue(entry, f[1], f[3]) then APTUSEquipmentManager.setEntryValue(entry, f[1], f[2], value); end
    end
end
function updateAmmo()
    if edit_ammunition_max then edit_ammunition_max.setReadOnly(not editable or edit_uses_ammunition.getValue() ~= 1); end
    local visible = edit_uses_ammunition.getValue() == 1;
    for _, name in ipairs({ "label_ammunition_max", "edit_ammunition_max", "label_ammunition_template",
        "ammunition_name", "ammunition_select", "ammunition_clear", "label_ammunition_consumption", "edit_ammunition_consumption" }) do
        if self[name] then self[name].setVisible(visible); end
    end
    if ammunition_select then ammunition_select.setReadOnly(not editable); ammunition_clear.setReadOnly(not editable); end
end
function refreshAmmunition()
    if not entry then return; end
    local reference = entry.ammunition_template;
    ammunition_name.setValue(APTUSEquipmentManager.getProfileAmmunitionName(entry));
    ammunition_name.setTooltipText(APTUSEquipmentManager.getProfileAmmunitionName(entry)
        .. (type(reference) == "table" and ("\n" .. tostring(reference.path)) or ""));
end
function selectAmmunition()
    if not alive or not editable or not owner.isEditable() or edit_uses_ammunition.getValue() ~= 1 then return; end
    local target = entry;
    DialogManager.requestSelectionDialog({ title="Tipo de munición", msg="Selecciona una plantilla de Munición.",
        options=APTUSEquipmentManager.getAmmunitionOptions(), min=1, max=1, showmodule=true,
        callback=function(selections, context, links)
            if not alive or entry ~= target or not editable or not owner.isEditable() or edit_uses_ammunition.getValue() ~= 1 then return; end
            local link = links and links[1];
            if not link or link.linkclass ~= "aptus_equipment"
                or not APTUSEquipmentManager.matchesTypeFilter(DB.findNode(link.linkrecord), "ammunition") then return; end
            entry.ammunition_template = {kind="windowreference", class=link.linkclass, path=link.linkrecord};
            refreshAmmunition();
        end,
    });
end
function clearAmmunition()
    if not alive or not editable or not owner.isEditable() or edit_uses_ammunition.getValue() ~= 1 then return; end
    entry.ammunition_template = nil; refreshAmmunition();
end
function changeSkill()
    if not editable then return; end
    local skill = APTUSEquipmentManager.getEntryValue(entry, "attack_skill_id", "pelea") == "pelea" and "punteria" or "pelea";
    APTUSEquipmentManager.setEntryValue(entry, "attack_skill_id", "string", skill);
    skill_display.setValue(skill == "pelea" and "Pelea" or "Puntería");
end
function refreshQualities()
    if not entry then return; end
    quality_names.setValue(APTUSQualityManager.summary(entry.qualities));
    quality_names.setTooltipText(APTUSQualityManager.details(entry.qualities));
end
function configureQualities()
    if not entry then return; end
    capture();
    local initial = APTUSQualityManager.associationToken(entry.qualities or {});
    DialogManager.openDialog("aptus_quality_associations", {
        title = "Cualidades del perfil", entries = entry.qualities or {},
        isValid = function() return alive; end,
        editable = function() return alive and editable and owner.isEditable(); end,
        apply = function(values)
            if not alive or not editable or not owner.isEditable()
                or APTUSQualityManager.associationToken(entry.qualities or {}) ~= initial then return false; end
            entry.qualities = values; refreshQualities(); return true;
        end,
    });
end
function dropQuality(draginfo)
    if not entry or not editable or not owner.isEditable() then return false; end
    entry.qualities = entry.qualities or {};
    APTUSQualityManager.addFromDrop(entry.qualities, draginfo); refreshQualities(); return true;
end
function onDrop(x, y, draginfo) return dropQuality(draginfo); end
function remove()
    if not alive or not editable or not owner.isEditable() then return; end
    capture();
    local answered = false;
    DialogManager.openDialog("dialog_okcancel", {
        sTitle = "Eliminar perfil del borrador",
        sText = "¿Eliminar este perfil? El cambio sólo se guardará al guardar el objeto principal.",
        fnCallback = function(result)
            if answered then return; end
            answered = true;
            if result == "ok" and alive and editable and owner.isEditable() then owner.removeEntry(key); end
        end,
    });
end

-- Cuadrícula 3 × 3 dentro del bloque local TIPOS DE DAÑO.
function configureDamageTypes()
    updatingDamageTypes = true;
    for index, damageType in ipairs(APTUSEquipmentManager.getDamageTypes()) do
        local control = damageControls[damageType.id];
        if not control then
            local x = 2 + ((index - 1) % 3) * 134;
            local y = 281 + math.floor((index - 1) / 3) * 22;
            control = createControl("aptus_profile_damage_checkbox", "damage_type_" .. damageType.id);
            control.setAnchor("left", "", "left", "absolute", x);
            control.setAnchor("top", "", "top", "absolute", y);
            control.setAnchoredWidth(20); control.setAnchoredHeight(20);
            control.setTooltipText(damageType.name);
            local label = createControl("aptus_profile_damage_label", "damage_label_" .. damageType.id);
            label.setAnchor("left", "", "left", "absolute", x + 24);
            label.setAnchor("top", "", "top", "absolute", y);
            label.setAnchoredWidth(108); label.setAnchoredHeight(20);
            label.setValue(damageType.name);
            damageControls[damageType.id] = control;
        end
        control.setValue(APTUSEquipmentManager.hasProfileDamageType(entry, damageType.id) and 1 or 0);
    end
    updatingDamageTypes = false;
end
function damageTypeChanged(id, selected)
    if updatingDamageTypes or not entry or not editable or not owner.isEditable() then return; end
    if not APTUSEquipmentManager.setProfileDamageType(entry, id, selected) then configureDamageTypes(); end
end

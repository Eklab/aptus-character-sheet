local selectedType = "";
function setupCustomFilters()
    super.setupCustomFilters();
    if getRecordType() ~= "aptus_equipment" then
        if aptus_type_combo then aptus_type_combo.destroy(); end
        if aptus_type_label then aptus_type_label.destroy(); end
        if aptus_type_filter then aptus_type_filter.destroy(); end
        selectedType = "";
        return;
    end
    if not aptus_type_filter then
        createControl("aptus_equipment_index_type_filter", "aptus_type_filter");
        createControl("aptus_equipment_type_label", "aptus_type_label");
        createControl("aptus_equipment_type_combo", "aptus_type_combo");
    end
    alignEquipmentTypeFilter();
end
function alignEquipmentTypeFilter()
    if getRecordType() ~= "aptus_equipment" or not aptus_type_combo then return; end
    if sub_category.subwindow then
        local label = sub_category.subwindow.label_category;
        if label then
            local width = label.getSize();
            -- Mismo inicio que el selector nativo Group, sin cambiar sus controles.
            aptus_type_combo.setAnchor("left", "aptus_type_filter", "left", "absolute", 20 + width);
        end
    end
end
function onFirstLayout()
    if super.onFirstLayout then super.onFirstLayout(); end
    alignEquipmentTypeFilter();
end
function isFilteredRecord(record)
    if not super.isFilteredRecord(record) then return false; end
    if getRecordType() ~= "aptus_equipment" then return true; end
    return APTUSEquipmentManager.matchesTypeFilter(record.node, selectedType);
end
function onEquipmentTypeFilterChanged(value)
    if getRecordType() ~= "aptus_equipment" then return; end
    if selectedType == (value or "") then return; end
    selectedType = value or "";
    refreshDisplayList(true);
end

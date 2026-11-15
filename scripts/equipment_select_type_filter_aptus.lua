local selectedType = "";
function activateNextSelection()
    if #getSelectionQueue() == 0 then super.activateNextSelection(); return; end
    selectedType = "";
    super.activateNextSelection();
    aptus_type_combo.setValue("");
    list.applyFilter();
end
function matchesEquipmentRow(row)
    local _, path = row.shortcut.getValue();
    return APTUSEquipmentManager.matchesTypeFilter(DB.findNode(path or ""), selectedType);
end
function onEquipmentTypeFilterChanged(value)
    if selectedType == (value or "") then return; end
    selectedType = value or "";
    -- El diálogo nativo recorre también filas ocultas al confirmar: deseleccionarlas.
    for _, row in pairs(list.getWindows()) do
        if not matchesEquipmentRow(row) then row.selected.setValue(0); end
    end
    list.applyFilter();
    onSelectionChanged();
end

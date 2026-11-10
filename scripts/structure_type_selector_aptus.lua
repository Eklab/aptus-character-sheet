function getStructureCategory()
    return getClass() == "aptus_structure_type_locations" and "locations" or "vehicles";
end
function onInit()
    if not Session.IsHost then close(); return; end
    for _, tType in ipairs(APTUSStructureManager.getTypes(getStructureCategory())) do
        type_choice.add(tType.id, tType.name);
    end
end
function confirmCreate()
    if not Session.IsHost then return; end
    local node = APTUSStructureManager.createStructure(type_choice.getValue(), getStructureCategory());
    if not node then
        status.setValue(Interface.getString("aptus_structure_select_valid_type"));
        return;
    end
    close();
    if APTUSStructureManager.getCategory(node) == "locations" then
        -- RecordManager.openRecordWindow no pasa el nodo al resolver la vista.
        local sClass = RecordDataManager.getRecordTypeDisplayClass(APTUSStructureManager.getRecordType(), node);
        Interface.openWindow(sClass, node);
    else
        RecordManager.openRecordWindow(APTUSStructureManager.getRecordType(), node);
    end
end

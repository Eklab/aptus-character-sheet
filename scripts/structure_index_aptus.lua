function getStructureCategory()
    return getClass() == "aptus_locations_index" and "locations" or "vehicles";
end
function onInit()
    super.onInit();
    self.setRecordType(APTUSStructureManager.getRecordType());
    title.setValue(Interface.getString("aptus_structure_" .. getStructureCategory()));
    setTooltipText(Interface.getString("aptus_structure_" .. getStructureCategory()));
    DB.addHandler(APTUSStructureManager.getRootPath() .. ".*.type", "onUpdate", refreshStructureFilter);
end
function onClose()
    DB.removeHandler(APTUSStructureManager.getRootPath() .. ".*.type", "onUpdate", refreshStructureFilter);
    super.onClose();
end
function refreshStructureFilter() self.refreshDisplayList(false); end
function isFilteredRecord(v)
    return APTUSStructureManager.getCategory(v.node) == getStructureCategory() and super.isFilteredRecord(v);
end
function beginCreate()
    APTUSStructureManager.beginCreate(getStructureCategory());
end

function setupButtons()
    super.setupButtons();
    if getStructureCategory() == "vehicles" and Session.IsHost then
        sub_buttons.setValue("masterindex_buttons", "");
        if sub_buttons.subwindow then
            sub_buttons.subwindow.createControl("aptus_button_native_vehicles", "native_vehicles");
        end
    end
end

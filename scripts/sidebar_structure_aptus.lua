-- Adaptación exclusivamente visual: no modifica metadatos ni rutas de vehicle.
function setCategory(sCategory, tButtons)
    if sCategory ~= "campaign" or not Session.IsHost then
        return super.setCategory(sCategory, tButtons);
    end
    local tResult = {};
    for _, tButton in ipairs(tButtons) do
        if tButton.sRecordType ~= "vehicle" and tButton.sClass ~= "aptus_locations_index"
            and tButton.sClass ~= "aptus_vehicles_index" then table.insert(tResult, tButton); end
    end
    table.insert(tResult, { sCategory = "campaign", sClass = "aptus_locations_index", sPath = APTUSStructureManager.getRootPath(), sLabelRes = "aptus_structure_locations", sIcon = "sidebar_icon_recordtype_location" });
    table.insert(tResult, { sCategory = "campaign", sClass = "aptus_vehicles_index", sPath = APTUSStructureManager.getRootPath(), sLabelRes = "aptus_structure_vehicles", sIcon = "sidebar_icon_recordtype_vehicle" });
    table.sort(tResult, DesktopManager.sortSidebarAlphaWithinCategory);
    return super.setCategory(sCategory, tResult);
end

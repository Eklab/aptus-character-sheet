local nodeStructure;
local sFeatureId;
local sEnabledPath;
function setFeature(sId, node)
    sFeatureId, nodeStructure = sId, node;
    sEnabledPath = DB.getPath(node, "features." .. sId .. ".enabled");
    DB.addHandler(sEnabledPath, "onUpdate", refresh);
    DB.addHandler(sEnabledPath, "onDelete", refresh);
    refresh();
end
function refresh()
    local tFeature = APTUSStructureManager.getFeature(sFeatureId);
    if not tFeature then return; end
    feature_name.setValue(tFeature.name);
    local sState = APTUSStructureManager.isFeatureActive(nodeStructure, sFeatureId)
        and Interface.getString("aptus_structure_enabled") or Interface.getString("aptus_structure_disabled");
    feature_status.setValue(tFeature.implemented and sState or (sState .. " — " .. (tFeature.status or Interface.getString("aptus_structure_pending"))));
    toggle.setVisible(tFeature.implemented and APTUSStructureManager.canEdit(nodeStructure));
end
function toggleFeature()
    if not nodeStructure then return; end
    APTUSStructureManager.setFeatureEnabled(nodeStructure, sFeatureId,
        not APTUSStructureManager.isFeatureEnabled(nodeStructure, sFeatureId));
    refresh();
end
function onClose()
    if sEnabledPath then
        DB.removeHandler(sEnabledPath, "onUpdate", refresh);
        DB.removeHandler(sEnabledPath, "onDelete", refresh);
    end
end

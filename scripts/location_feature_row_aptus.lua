local nodeStructure, sFeatureId, sEnabledPath;

function setFeature(sId, node)
    sFeatureId, nodeStructure = sId, node;
    sEnabledPath = DB.getPath(node, "features." .. sId .. ".enabled");
    for _, sEvent in ipairs({ "onAdd", "onUpdate", "onDelete" }) do
        DB.addHandler(sEnabledPath, sEvent, refresh);
    end
    refresh();
end

function refresh()
    local tFeature = APTUSStructureManager.getFeature(sFeatureId);
    if not tFeature then return; end
    local bImplemented = sFeatureId == "storage"
        and APTUSStructureManager.isFeatureImplemented(nodeStructure, sFeatureId);
    feature_name.setValue(tFeature.name);
    toggle.setValue(APTUSStructureManager.isFeatureEnabled(nodeStructure, sFeatureId) and 1 or 0);
    toggle.setVisible(bImplemented);
    toggle.setReadOnly(not bImplemented or not APTUSStructureManager.canEdit(nodeStructure));
    activation_pending.setVisible(not bImplemented);
    if bImplemented then
        feature_status.setValue("Disponible");
    else
        feature_status.setValue(tFeature.status or Interface.getString("aptus_structure_pending"));
    end
end

function toggleFeature()
    if not Session.IsHost or sFeatureId ~= "storage" or not nodeStructure then return; end
    APTUSStructureManager.setFeatureEnabled(nodeStructure, sFeatureId, toggle.getValue() == 1);
    refresh();
end

function onClose()
    if sEnabledPath then
        for _, sEvent in ipairs({ "onAdd", "onUpdate", "onDelete" }) do
            DB.removeHandler(sEnabledPath, sEvent, refresh);
        end
    end
end

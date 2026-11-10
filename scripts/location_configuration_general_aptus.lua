-- Hereda inicialización y limpieza de record_structure_aptus.lua.
-- El filtro es sólo visual y exclusivo de esta página de Localizaciones.
function update()
    if not Session.IsHost then return; end
    local node = getDatabaseNode();
    type_display.setValue(APTUSStructureManager.getTypeName(node));
    for _, w in ipairs(feature_list.getWindows()) do w.close(); end
    for _, sId in ipairs({ "security", "storage", "systems" }) do
        if APTUSStructureManager.getFeature(sId) then
            local w = feature_list.createWindow();
            w.setFeature(sId, node);
        end
    end
end

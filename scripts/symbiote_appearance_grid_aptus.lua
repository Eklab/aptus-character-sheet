local sActivePath;

function onInit()
    sActivePath = DB.getPath(getDatabaseNode(), APTUSSymbioteAppearance.getActiveModePath());
    DB.addHandler(sActivePath, "onUpdate", updateActiveMode);
    DB.addHandler(sActivePath, "onDelete", updateActiveMode);
    updateActiveMode();
end

function onClose()
    if not sActivePath then return; end
    DB.removeHandler(sActivePath, "onUpdate", updateActiveMode);
    DB.removeHandler(sActivePath, "onDelete", updateActiveMode);
end

-- Sólo visualiza el modo; la futura lógica de Simbiontes actualizará active_mode.
function updateActiveMode()
    local sActive = APTUSSymbioteAppearance.getActiveMode(getDatabaseNode());
    for _, sMode in ipairs(APTUSSymbioteAppearance.getModes()) do
        local bActive = (sMode == sActive);
        self[sMode .. "_highlight"].setFrame(bActive and "fieldlight" or "");
        -- Las etiquetas mantienen la fuente blanca de los campos de Datos.
    end
end

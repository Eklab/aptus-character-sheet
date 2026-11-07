-- Ilustración reutilizable: guarda illustration en el nodo raíz de la ficha.
-- El controlador no conoce rutas de pruebas ni de personajes; no modifica portrait/tokens.
local sIllustrationPath;
local sIllustrationAssetPath;

function getIllustrationNode()
    -- CoreRPG resuelve parentcontrol; no se crea un nodo propio para la cabecera.
    return WindowManager.getTopWindow(window).getDatabaseNode();
end

function canEdit()
    local node = getIllustrationNode();
    return node and not WindowManager.getReadOnlyState(node);
end

function onInit()
    local node = getIllustrationNode();
    if node then
        sIllustrationAssetPath = DB.getPath(node, "illustrationasset");
        DB.addHandler(sIllustrationAssetPath, "onUpdate", updateDisplay);
        DB.addHandler(sIllustrationAssetPath, "onDelete", updateDisplay);
        sIllustrationPath = DB.getPath(node, "illustration");
        DB.addHandler(sIllustrationPath, "onUpdate", updateDisplay);
        DB.addHandler(sIllustrationPath, "onDelete", updateDisplay);
    end
    if canEdit() then
        registerMenuItem("Quitar ilustración APTUS", "delete", 6);
    end
    APTUSSkin.subscribe(window, updateDisplay);
end

function onClose()
    APTUSSkin.unsubscribe(window, updateDisplay);
    if sIllustrationAssetPath then
        DB.removeHandler(sIllustrationAssetPath, "onUpdate", updateDisplay);
        DB.removeHandler(sIllustrationAssetPath, "onDelete", updateDisplay);
    end
    if sIllustrationPath then
        DB.removeHandler(sIllustrationPath, "onUpdate", updateDisplay);
        DB.removeHandler(sIllustrationPath, "onDelete", updateDisplay);
    end
end

function updateDisplay()
    -- El fallback es un recurso de interfaz; nunca se guarda en la base de datos.
    setAsset("");
    setIcon(APTUSSkin.getIcon(window, "aptus_character_illustration"));
    setDrawMode("");
    local node = getIllustrationNode();
    if not node then
        return;
    end
    -- Recursos directos de Portraits; illustration sigue siendo windowreference.
    local sPortraitAsset = DB.getValue(node, "illustrationasset", "");
    if sPortraitAsset ~= "" then
        setIcon("");
        setDrawMode("fit");
        setAsset(sPortraitAsset);
        return;
    end
    local sClass, sRecord = DB.getValue(node, "illustration", "", "");
    if (sRecord or "") == "" then
        return;
    end
    if RecordDataManager.getRecordTypeFromDisplayClass(sClass) ~= "image" then
        return;
    end
    local nodeImage = DB.findNode(sRecord);
    if not nodeImage then
        return;
    end
    -- Mismo acceso al recurso de imagen que campaign/scripts/picture_asset.lua.
    local sAsset = DB.getText(nodeImage, "image", "");
    if sAsset ~= "" then
        setIcon("");
        setDrawMode("fit");
        setAsset(sAsset);
    end
end

function onDrop(x, y, draginfo)
    if not canEdit() then
        return false;
    end
    local node = getIllustrationNode();
    local sDragType = draginfo.getType();
    if sDragType == "portrait" then
        -- RecordAssetManager.handlePictureDrop obtiene así el recurso nativo.
        -- No llamar a setCharPortrait: modifica portrait y puede modificar token.
        local sAsset = draginfo.getTokenData();
        if (sAsset or "") == "" then
            return false;
        end
        DB.setValue(node, "illustrationasset", "token", sAsset);
        DB.setValue(node, "illustration", "windowreference", "", "");
        updateDisplay();
        return true;
    end
    if sDragType ~= "shortcut" then
        return false;
    end
    local sClass, sRecord = draginfo.getShortcutData();
    if RecordDataManager.getRecordTypeFromDisplayClass(sClass) ~= "image" then
        return false;
    end
    local nodeImage = DB.findNode(sRecord);
    if not nodeImage or DB.getText(nodeImage, "image", "") == "" then
        return false;
    end
    DB.setValue(node, "illustration", "windowreference", sClass, sRecord);
    DB.setValue(node, "illustrationasset", "token", "");
    updateDisplay();
    return true;
end

function onMenuSelection(selection)
    if selection == 6 and canEdit() then
        DB.setValue(getIllustrationNode(), "illustrationasset", "token", "");
        DB.setValue(getIllustrationNode(), "illustration", "windowreference", "", "");
        updateDisplay();
    end
end

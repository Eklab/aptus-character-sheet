-- Vista y arrastre de un recurso almacenado. No usa setCharPortrait/handlePictureDrop.
local sPath;
local sKind;

function canEdit()
    return not WindowManager.getWindowReadOnlyState(window);
end

function onInit()
    local sMode = appearance_mode and appearance_mode[1];
    sKind = appearance_kind and appearance_kind[1];
    local sField = APTUSSymbioteAppearance.getAssetPath(sMode, sKind);
    if not sField then return; end
    sPath = DB.getPath(window.getDatabaseNode(), sField);
    DB.addHandler(sPath, "onUpdate", updateDisplay);
    DB.addHandler(sPath, "onDelete", updateDisplay);
    registerMenuItem("Quitar " .. sKind .. " almacenado", "delete", 6);
    updateDisplay();
end

function onClose()
    if not sPath then return; end
    DB.removeHandler(sPath, "onUpdate", updateDisplay);
    DB.removeHandler(sPath, "onDelete", updateDisplay);
end

function updateDisplay()
    setAsset("");
    setIcon((sKind == "portrait") and "charlist_base" or "token_empty");
    setDrawMode("");
    local sAsset = sPath and DB.getValue(sPath, "") or "";
    if sAsset ~= "" then
        setIcon("");
        setDrawMode("fit");
        setAsset(sAsset);
    end
end

function onDrop(x, y, draginfo)
    if not sPath or not canEdit() then return false; end
    local sType = draginfo.getType();
    local sAsset;
    if sType == "portrait" or sType == "token" or sType == "image" then
        sAsset = draginfo.getTokenData();
    elseif sType == "shortcut" then
        local sClass, sRecord = draginfo.getShortcutData();
        if RecordDataManager.getRecordTypeFromDisplayClass(sClass) ~= "image" then return false; end
        local nodeImage = DB.findNode(sRecord);
        if nodeImage then sAsset = DB.getText(nodeImage, "image", ""); end
    end
    if (sAsset or "") == "" then return false; end
    DB.setValue(sPath, "token", sAsset);
    return true;
end

function onMenuSelection(selection)
    if selection == 6 and sPath and canEdit() then
        DB.setValue(sPath, "token", "");
    end
end

-- Editor numérico sobre los nodos de texto heredados de CoreRPG.
-- No migra tipos ni escribe al cargar. Confirma cambios al perder el foco.
local sPath;
local sSaved = "";
local bRefreshing = false;

function onInit()
    sPath = DB.getPath(window.getDatabaseNode(), getName());
    DB.addHandler(sPath, "onUpdate", refreshValue);
    DB.addHandler(sPath, "onDelete", refreshValue);
    refreshValue();
end

function refreshValue()
    sSaved = tostring(DB.getValue(sPath, ""));
    bRefreshing = true;
    setValue(sSaved);
    setReadOnly(WindowManager.getWindowReadOnlyState(window));
    bRefreshing = false;
end

function commitValue()
    if bRefreshing or not sPath or getValue() == sSaved then return; end
    if WindowManager.getWindowReadOnlyState(window) then
        refreshValue();
        return;
    end
    local sInput = getValue();
    local sNumeric = sInput:gsub(",", ".");
    local bValid;
    if integeronly then
        bValid = sNumeric:match("^[+-]?%d+$");
    else
        bValid = sNumeric:match("^[+-]?%d+%.?%d*$") or sNumeric:match("^[+-]?%d*%.%d+$");
    end
    local node = DB.findNode(sPath);
    local sType = node and DB.getType(node) or "string";
    -- Un valor antiguo no numérico se conserva hasta una edición válida.
    if not bValid and not (sInput == "" and sType == "string") then
        refreshValue();
        return;
    end
    if sType == "string" then
        DB.setValue(sPath, "string", sInput);
    elseif sType == "number" and tonumber(sNumeric) then
        DB.setValue(sPath, "number", tonumber(sNumeric));
    end
    refreshValue();
end

function onLoseFocus()
    commitValue();
end

function onEnter()
    commitValue();
    return false;
end

function onClose()
    commitValue();
    if sPath then
        DB.removeHandler(sPath, "onUpdate", refreshValue);
        DB.removeHandler(sPath, "onDelete", refreshValue);
    end
end

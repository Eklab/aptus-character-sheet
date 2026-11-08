-- Un solo origen de nombre: texto libre o referencia, nunca una copia de la clase.
local sType = "aptus_dedication_class";
local sCatalog = "aptus_dedication_classes";
local sText = "aptus.identity.dedication.text";
local sClass = "aptus.identity.dedication.class";
-- Un único observador por personaje; las vistas no mantienen estados separados.
local tSubscriptions = {};

function onInit()
    RecordDataManager.setRecordTypeData(sType, {
        aDataMap = { sCatalog }, sRecordDisplayClass = sType,
        sSidebarCategory = "create",
        tOptions = { bExport = true, bNoDuplicate = true, bPicture = true },
    });
    RecordManager.setRecordAddCallback(sType, ensureRecordId);
end

function ensureRecordId(nodeRecord)
    if not Session.IsHost or not nodeRecord or WindowManager.getReadOnlyState(nodeRecord) then return; end
    if DB.getValue(nodeRecord, "id", "") ~= "" then return; end
    local sBase = "dedication_" .. DB.getName(nodeRecord);
    local sId, n = sBase, 2;
    while RecordManager.findRecordByString(sType, "id", sId) do
        sId = sBase .. "_" .. n;
        n = n + 1;
    end
    DB.setValue(nodeRecord, "id", "string", sId);
end

function canEdit(nodeChar)
    return nodeChar and not WindowManager.getReadOnlyState(nodeChar);
end

function getClassRecord(nodeChar)
    local sRecordClass, sRecord = DB.getValue(nodeChar, sClass, "", "");
    local tState = tSubscriptions[DB.getPath(nodeChar)];
    if tState and tState.sourceDeleted and tState.recordClass == sRecordClass and tState.record == sRecord then return nil; end
    if sRecordClass ~= sType or (sRecord or "") == "" then return nil; end
    return DB.findNode(sRecord);
end

function getDisplayName(nodeChar)
    local sRecordClass, sRecord = DB.getValue(nodeChar, sClass, "", "");
    if (sRecord or "") ~= "" then
        local nodeRecord = getClassRecord(nodeChar);
        return nodeRecord and DB.getValue(nodeRecord, "name", "") or "";
    end
    return DB.getValue(nodeChar, sText, "");
end

function setFreeText(nodeChar, sValue)
    if not canEdit(nodeChar) then return false; end
    local sRecordClass, sRecord = DB.getValue(nodeChar, sClass, "", "");
    if (sRecord or "") ~= "" then
        DB.setValue(nodeChar, sClass, "windowreference", "", "");
    end
    if DB.getValue(nodeChar, sText, "") ~= sValue then
        DB.setValue(nodeChar, sText, "string", sValue);
    end
    refresh(nodeChar);
    return true;
end

function assignFromDrop(nodeChar, draginfo)
    if not canEdit(nodeChar) or draginfo.getType() ~= "shortcut" then return false; end
    local sRecordClass, sRecord = draginfo.getShortcutData();
    if sRecordClass ~= sType or RecordDataManager.getRecordTypeFromRecordPath(sRecord) ~= sType then return false; end
    if not DB.findNode(sRecord) then return false; end
    if DB.getValue(nodeChar, sText, "") ~= "" then
        DB.setValue(nodeChar, sText, "string", "");
    end
    DB.setValue(nodeChar, sClass, "windowreference", sRecordClass, sRecord);
    -- También reconcilia una asignación idéntica, aunque DB no emita onUpdate.
    refresh(nodeChar);
    return true;
end

local function removeHandlers(tHandlers)
    for _, tHandler in ipairs(tHandlers) do
        DB.removeHandler(tHandler.path, tHandler.event, tHandler.callback);
    end
end

local function listen(tHandlers, sPath, sEvent, fn)
    DB.addHandler(sPath, sEvent, fn);
    table.insert(tHandlers, { path = sPath, event = sEvent, callback = fn });
end

-- El fan-out se hace en Lua sobre una copia: rebind sólo cambia los handlers
-- de la fuente una vez y después actualiza explícitamente a todos los consumidores.
local function notify(tState)
    local tCallbacks = {};
    for tHandle, fn in pairs(tState.consumers) do
        table.insert(tCallbacks, { handle = tHandle, callback = fn });
    end
    for _, tEntry in ipairs(tCallbacks) do
        if not tEntry.handle.closed then tEntry.callback(); end
    end
end

local function rebind(tState)
    local sRecordClass, sRecord = DB.getValue(tState.node, sClass, "", "");
    if tState.recordClass ~= sRecordClass or tState.record ~= sRecord then
        removeHandlers(tState.sourceHandlers);
        tState.sourceHandlers = {};
        tState.recordClass, tState.record = sRecordClass, sRecord;
        tState.sourceDeleted = false;
        if sRecordClass == sType and (sRecord or "") ~= "" then
            local function sourceChanged()
                tState.sourceDeleted = false;
                notify(tState);
            end
            for _, sField in ipairs({ "name", "description", "special", "picture" }) do
                local sPath = DB.getPath(sRecord, sField);
                listen(tState.sourceHandlers, sPath, "onUpdate", sourceChanged);
                listen(tState.sourceHandlers, sPath, "onDelete", function() notify(tState); end);
            end
            listen(tState.sourceHandlers, sRecord, "onDelete", function()
                tState.sourceDeleted = true;
                notify(tState);
            end);
        end
    end
    notify(tState);
end

function refresh(nodeChar)
    local tState = tSubscriptions[DB.getPath(nodeChar)];
    if tState then rebind(tState); end
end

function subscribe(nodeChar, fn)
    local sCharPath = DB.getPath(nodeChar);
    local tState = tSubscriptions[sCharPath];
    if not tState then
        tState = { node = nodeChar, characterHandlers = {}, sourceHandlers = {}, consumers = {} };
        tSubscriptions[sCharPath] = tState;
        local function referenceChanged() rebind(tState); end
        local sReferencePath = DB.getPath(nodeChar, sClass);
        listen(tState.characterHandlers, sReferencePath, "onUpdate", referenceChanged);
        listen(tState.characterHandlers, sReferencePath, "onDelete", referenceChanged);
        local function textChanged() notify(tState); end
        listen(tState.characterHandlers, DB.getPath(nodeChar, sText), "onUpdate", textChanged);
        listen(tState.characterHandlers, DB.getPath(nodeChar, sText), "onDelete", textChanged);
    end
    local tHandle = { state = tState, characterPath = sCharPath, closed = false };
    tState.consumers[tHandle] = fn;
    rebind(tState);
    return tHandle;
end

function unsubscribe(tHandle)
    if not tHandle or tHandle.closed then return; end
    tHandle.closed = true;
    local tState = tHandle.state;
    tState.consumers[tHandle] = nil;
    if next(tState.consumers) then return; end
    removeHandlers(tState.characterHandlers);
    removeHandlers(tState.sourceHandlers);
    tSubscriptions[tHandle.characterPath] = nil;
end

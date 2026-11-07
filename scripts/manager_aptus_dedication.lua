-- Un solo origen de nombre: texto libre o referencia, nunca una copia de la clase.
local sType = "aptus_dedication_class";
local sCatalog = "aptus_dedication_classes";
local sText = "aptus.identity.dedication.text";
local sClass = "aptus.identity.dedication.class";

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

function getClassRecord(nodeChar, tSubscription)
    if tSubscription and tSubscription.sourceDeleted then return nil; end
    local sRecordClass, sRecord = DB.getValue(nodeChar, sClass, "", "");
    if sRecordClass ~= sType or (sRecord or "") == "" then return nil; end
    return DB.findNode(sRecord);
end

function getDisplayName(nodeChar, tSubscription)
    local sRecordClass, sRecord = DB.getValue(nodeChar, sClass, "", "");
    if (sRecord or "") ~= "" then
        local nodeRecord = getClassRecord(nodeChar, tSubscription);
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

-- Los consumidores reciben cambios del personaje y del original sin duplicar DB.
function subscribe(nodeChar, fn)
    local tSubscription = { characterHandlers = {}, sourceHandlers = {}, sourceDeleted = false };
    local function sourceChanged()
        tSubscription.sourceDeleted = false;
        fn();
    end
    local function rebind()
        removeHandlers(tSubscription.sourceHandlers);
        tSubscription.sourceHandlers = {};
        tSubscription.sourceDeleted = false;
        local sRecordClass, sRecord = DB.getValue(nodeChar, sClass, "", "");
        if sRecordClass == sType and (sRecord or "") ~= "" then
            for _, sField in ipairs({ "name", "description", "special", "picture" }) do
                local sPath = DB.getPath(sRecord, sField);
                listen(tSubscription.sourceHandlers, sPath, "onUpdate", sourceChanged);
                listen(tSubscription.sourceHandlers, sPath, "onDelete", fn);
            end
            listen(tSubscription.sourceHandlers, sRecord, "onDelete", function()
                tSubscription.sourceDeleted = true;
                fn();
            end);
        end
        fn();
    end
    local sReferencePath = DB.getPath(nodeChar, sClass);
    listen(tSubscription.characterHandlers, sReferencePath, "onUpdate", rebind);
    listen(tSubscription.characterHandlers, sReferencePath, "onDelete", rebind);
    listen(tSubscription.characterHandlers, DB.getPath(nodeChar, sText), "onUpdate", fn);
    listen(tSubscription.characterHandlers, DB.getPath(nodeChar, sText), "onDelete", fn);
    -- El consumidor refresca después de guardar el handle, para detectar borrados.
    rebind();
    return tSubscription;
end

function unsubscribe(tSubscription)
    if not tSubscription then return; end
    removeHandlers(tSubscription.characterHandlers);
    removeHandlers(tSubscription.sourceHandlers);
end

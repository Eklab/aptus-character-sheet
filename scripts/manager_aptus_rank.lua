-- Sólo almacena y resuelve el rango. No asigna recursos de creación.
local sPath = "aptus.identity.rank";
local tRanks = {
    { id = "novato", label = "Novato" },
    { id = "asentado", label = "Asentado" },
    { id = "competente", label = "Competente" },
};
local fnPreviousRecordAdd;

function onInit()
    fnPreviousRecordAdd = RecordManager.getRecordAddCallback("charsheet");
    RecordManager.setRecordAddCallback("charsheet", onCharacterAdded);
end

function onCharacterAdded(nodeChar, sRecordType, bIsSubRecord)
    local bHandled;
    if fnPreviousRecordAdd then
        bHandled = fnPreviousRecordAdd(nodeChar, sRecordType, bIsSubRecord);
    end
    if not bIsSubRecord and canEdit(nodeChar) and not DB.getChild(nodeChar, sPath) then
        DB.setValue(nodeChar, sPath, "string", "novato");
    end
    return bHandled;
end

function getPath()
    return sPath;
end

function getOptions()
    return tRanks;
end

function getEffectiveId(nodeChar)
    local sValue = DB.getValue(nodeChar, sPath, "");
    for _, tRank in ipairs(tRanks) do
        if tRank.id == sValue then return sValue; end
    end
    return "novato";
end

function getLabel(nodeChar)
    local sEffective = getEffectiveId(nodeChar);
    for _, tRank in ipairs(tRanks) do
        if tRank.id == sEffective then return tRank.label; end
    end
end

function canEdit(nodeChar)
    return nodeChar and not WindowManager.getReadOnlyState(nodeChar);
end

function setRank(nodeChar, sRank)
    if not canEdit(nodeChar) then return false; end
    local bValid = false;
    for _, tRank in ipairs(tRanks) do
        if tRank.id == sRank then bValid = true; break; end
    end
    if not bValid then return false; end
    if DB.getValue(nodeChar, sPath, "") ~= sRank then
        DB.setValue(nodeChar, sPath, "string", sRank);
    end
    return true;
end

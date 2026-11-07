-- Catálogo CoreRPG. Asignar una referencia no aplica reglas ni características.
local sRecordType = "aptus_character_type";
local sCatalogPath = "aptus_character_types";
local sAssignmentPath = "aptus.character_type";
local fnInitializationCheck;
local tInitialTypes = {
    { id = "libre", name = "Libre" },
    { id = "investigador", name = "Investigador" },
    { id = "cazador", name = "Cazador" },
    { id = "agencia", name = "Agencia" },
    { id = "simbionte", name = "Simbionte" },
};

function onInit()
    RecordDataManager.setRecordTypeData(sRecordType, {
        aDataMap = { sCatalogPath },
        sRecordDisplayClass = sRecordType,
        sSidebarCategory = "create",
        tOptions = { bExport = true, bNoDuplicate = true },
    });
    RecordManager.setRecordAddCallback(sRecordType, onRecordAdded);
end

function onTabletopInit()
    if not Session.IsHost then return; end
    local tExisting = {};
    for _, nodeRecord in ipairs(DB.getChildrenGlobal(sCatalogPath)) do
        tExisting[DB.getValue(nodeRecord, "id", "")] = true;
    end
    local nodeCatalog = DB.createNode(sCatalogPath);
    if not nodeCatalog then return; end
    for _, tType in ipairs(tInitialTypes) do
        if not tExisting[tType.id] then
            local nodeRecord = DB.createChild(nodeCatalog);
            if nodeRecord then
                DB.setValue(nodeRecord, "id", "string", tType.id);
                DB.setValue(nodeRecord, "name", "string", tType.name);
                DB.setValue(nodeRecord, "description", "formattedtext", "<p></p>");
                tExisting[tType.id] = true;
            end
        end
    end
end

function onRecordAdded(nodeRecord)
    ensureRecordId(nodeRecord);
end

function ensureRecordId(nodeRecord)
    if not Session.IsHost or not nodeRecord or WindowManager.getReadOnlyState(nodeRecord) then return; end
    if DB.getValue(nodeRecord, "id", "") ~= "" then return; end
    -- El identificador automático de DB es independiente del nombre visible.
    -- No se recalcula al renombrar, exportar o volver a abrir el registro.
    local tUsed = {};
    for _, nodeOther in ipairs(DB.getChildrenGlobal(sCatalogPath)) do
        tUsed[DB.getValue(nodeOther, "id", "")] = true;
    end
    local sBaseId = "custom_" .. DB.getName(nodeRecord);
    local sId, nSuffix = sBaseId, 2;
    while tUsed[sId] do
        sId = sBaseId .. "_" .. nSuffix;
        nSuffix = nSuffix + 1;
    end
    DB.setValue(nodeRecord, "id", "string", sId);
end

function getAssignmentPath()
    return sAssignmentPath;
end

-- Futuro asistente: registrar una función que devuelva true si la creación terminó.
-- No se establece ni deduce ahora ningún nodo de inicialización del personaje.
function setInitializationCheck(fn)
    fnInitializationCheck = fn;
end

function canAssign(nodeChar)
    if not Session.IsHost or not nodeChar or WindowManager.getReadOnlyState(nodeChar) then return false; end
    return not fnInitializationCheck or not fnInitializationCheck(nodeChar);
end

function assignFromDrop(nodeChar, draginfo)
    if not canAssign(nodeChar) or draginfo.getType() ~= "shortcut" then return false; end
    local sClass, sRecord = draginfo.getShortcutData();
    if sClass ~= sRecordType then return false; end
    if RecordDataManager.getRecordTypeFromRecordPath(sRecord) ~= sRecordType then return false; end
    if not DB.findNode(sRecord) then return false; end
    -- Única modificación del personaje: referencia al registro original.
    DB.setValue(nodeChar, sAssignmentPath, "windowreference", sClass, sRecord);
    return true;
end

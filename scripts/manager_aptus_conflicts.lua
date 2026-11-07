-- Lista narrativa. No inicializa fichas existentes al abrirlas.
local sList = "aptus.identity.conflicts";
local sInitialized = "aptus.identity.conflicts_initialized";
local fnPreviousRecordAdd;

function onInit()
    fnPreviousRecordAdd = RecordManager.getRecordAddCallback("charsheet");
    RecordManager.setRecordAddCallback("charsheet", onCharacterAdded);
end

function onCharacterAdded(nodeChar, sRecordType, bIsSubRecord)
    -- Antes de abrir la ficha: un registro usado/copied conserva su lista tal cual.
    if not bIsSubRecord then initializeNewCharacter(nodeChar); end
    if fnPreviousRecordAdd then return fnPreviousRecordAdd(nodeChar, sRecordType, bIsSubRecord); end
end

function getListPath()
    return sList;
end

function canEdit(nodeChar)
    return nodeChar and not WindowManager.getReadOnlyState(nodeChar);
end

function getOrdered(nodeChar)
    local tRows = {};
    for _, nodeRow in pairs(DB.getChildren(nodeChar, sList)) do table.insert(tRows, nodeRow); end
    table.sort(tRows, function(a, b)
        local nA, nB = DB.getValue(a, "order", 0), DB.getValue(b, "order", 0);
        if nA ~= nB then return nA < nB; end
        return DB.getName(a) < DB.getName(b);
    end);
    return tRows;
end

function addConflict(nodeChar)
    if not canEdit(nodeChar) then return nil; end
    local nOrder = 0;
    for _, nodeRow in ipairs(getOrdered(nodeChar)) do
        nOrder = math.max(nOrder, DB.getValue(nodeRow, "order", 0));
    end
    local nodeList = DB.createChild(nodeChar, sList);
    if not nodeList then return nil; end
    local nodeRow = DB.createChild(nodeList);
    if not nodeRow then return nil; end
    DB.setValue(nodeRow, "order", "number", nOrder + 1);
    DB.setValue(nodeRow, "title", "string", "");
    DB.setValue(nodeRow, "description", "string", "");
    return nodeRow;
end

function initializeNewCharacter(nodeChar)
    if not canEdit(nodeChar) then return; end
    if DB.getValue(nodeChar, sInitialized, 0) ~= 0 then return; end
    -- Protege registros importados/copiados y listas existentes, incluso vacías.
    if DB.getValue(nodeChar, "skills_initialized", 0) ~= 0 or DB.getChild(nodeChar, sList) then return; end
    addConflict(nodeChar);
    addConflict(nodeChar);
    DB.setValue(nodeChar, sInitialized, "number", 1);
end

function getHeaderTitles(nodeChar)
    local tTitles = {};
    for _, nodeRow in ipairs(getOrdered(nodeChar)) do
        local sTitle = DB.getValue(nodeRow, "title", "");
        if StringManager.trim(sTitle) ~= "" then
            table.insert(tTitles, sTitle);
            if #tTitles == 3 then break; end
        end
    end
    return tTitles;
end

function subscribe(nodeChar, fn)
    local sPath = DB.getPath(nodeChar, sList);
    local tHandlers = {
        { path = sPath, event = "onChildAdded" },
        { path = sPath, event = "onChildDeleted" },
        { path = sPath .. ".*.title", event = "onUpdate" },
        { path = sPath .. ".*.title", event = "onDelete" },
        { path = sPath .. ".*.order", event = "onUpdate" },
    };
    for _, tHandler in ipairs(tHandlers) do
        tHandler.callback = fn;
        DB.addHandler(tHandler.path, tHandler.event, fn);
    end
    fn();
    return tHandlers;
end

function unsubscribe(tHandlers)
    for _, tHandler in ipairs(tHandlers or {}) do
        DB.removeHandler(tHandler.path, tHandler.event, tHandler.callback);
    end
end

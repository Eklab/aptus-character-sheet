-- Texto de sólo lectura, con asignación por arrastre controlada por el gestor.
local sAssignmentPath;
local sNamePath;

function onInit()
    sAssignmentPath = DB.getPath(window.getDatabaseNode(), APTUSCharacterTypes.getAssignmentPath());
    DB.addHandler(sAssignmentPath, "onUpdate", onReferenceChanged);
    DB.addHandler(sAssignmentPath, "onDelete", onReferenceChanged);
    onReferenceChanged();
end

function onClose()
    if sAssignmentPath then
        DB.removeHandler(sAssignmentPath, "onUpdate", onReferenceChanged);
        DB.removeHandler(sAssignmentPath, "onDelete", onReferenceChanged);
    end
    removeNameHandlers();
end

function removeNameHandlers()
    if not sNamePath then return; end
    DB.removeHandler(sNamePath, "onUpdate", updateDisplay);
    DB.removeHandler(sNamePath, "onDelete", updateDisplay);
    sNamePath = nil;
end

function getAssignedRecord()
    if not sAssignmentPath then return nil; end
    local sClass, sRecord = DB.getValue(sAssignmentPath, "", "");
    if sClass ~= "aptus_character_type" or (sRecord or "") == "" then return nil; end
    return DB.findNode(sRecord);
end

function onReferenceChanged()
    removeNameHandlers();
    local nodeRecord = getAssignedRecord();
    if nodeRecord then
        sNamePath = DB.getPath(nodeRecord, "name");
        DB.addHandler(sNamePath, "onUpdate", updateDisplay);
        DB.addHandler(sNamePath, "onDelete", updateDisplay);
    end
    updateDisplay();
end

function updateDisplay()
    local nodeRecord = getAssignedRecord();
    setValue(nodeRecord and DB.getValue(nodeRecord, "name", "") or "");
end

function onDrop(x, y, draginfo)
    return APTUSCharacterTypes.assignFromDrop(window.getDatabaseNode(), draginfo);
end

function onClickRelease()
    local nodeRecord = getAssignedRecord();
    if not nodeRecord then return false; end
    Interface.openWindow("aptus_character_type", nodeRecord);
    return true;
end

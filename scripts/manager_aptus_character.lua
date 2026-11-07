-- Nombre de presentación inicial; no representa la finalización del personaje.
-- El futuro editor Identidad > Datos del personaje debe usar el mismo campo name.
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
    ensureDefaultName(nodeChar);
    return bHandled;
end

function ensureDefaultName(nodeChar)
    if not nodeChar or WindowManager.getReadOnlyState(nodeChar) then
        return;
    end
    if DB.getValue(nodeChar, "aptus_default_name_assigned", 0) ~= 0 then
        return;
    end
    if DB.getValue(nodeChar, "name", "") ~= "" then
        return;
    end
    DB.setValue(nodeChar, "name", "string", "Nuevo personaje");
    -- Sólo registra esta asignación: no es una marca de creación completada.
    -- Si el usuario borra el nombre después, no se vuelve a imponer el defecto.
    DB.setValue(nodeChar, "aptus_default_name_assigned", "number", 1);
end

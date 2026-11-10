-- Notas compartidas. Sólo escribe el anfitrión: la identidad OOB del remitente
-- no está autenticada por el contrato disponible. No registrar escrituras OOB.
local sListPath = "notes";

function getListPath() return sListPath; end
function supportsPlayerOperations() return false; end

function getStructure(nodeNote)
    if not nodeNote then return nil; end
    local nodeList = DB.getParent(nodeNote);
    if not nodeList or DB.getName(nodeList) ~= sListPath then return nil; end
    local nodeStructure = DB.getParent(nodeList);
    if not APTUSStructureManager.isStructure(nodeStructure) then return nil; end
    return nodeStructure;
end

function canCreate(nodeStructure)
    return Session.IsHost and APTUSStructureManager.isStructure(nodeStructure)
        and not DB.isReadOnly(nodeStructure);
end

function canEdit(nodeNote)
    local nodeStructure = getStructure(nodeNote);
    return nodeStructure ~= nil and canCreate(nodeStructure) and not DB.isReadOnly(nodeNote);
end

function createNote(nodeStructure, sContent)
    if not canCreate(nodeStructure) or type(sContent) ~= "string" then return nil; end
    local nOrder = 0;
    for _, node in pairs(DB.getChildren(nodeStructure, sListPath)) do
        nOrder = math.max(nOrder, DB.getValue(node, "order", 0));
    end
    local nodeList = DB.createChild(nodeStructure, sListPath);
    if not nodeList then return nil; end
    local nodeNote = DB.createChild(nodeList);
    if not nodeNote then return nil; end
    local bOK = pcall(function()
        DB.setValue(nodeNote, "order", "number", nOrder + 1);
        DB.setValue(nodeNote, "content", "string", sContent);
        DB.setValue(nodeNote, "author_kind", "string", "gm");
        DB.setValue(nodeNote, "author_character", "windowreference", "", "");
        local sUser = Session.UserName;
        if not sUser or sUser == "" then sUser = "GM"; end
        DB.setValue(nodeNote, "author_user", "string", sUser);
        DB.setValue(nodeNote, "author_label", "string", "DJ");
    end);
    if not bOK then DB.deleteNode(nodeNote); return nil; end
    -- No publicar ni conceder propiedad: se conserva el acceso de la Estructura.
    return nodeNote;
end

function updateContent(nodeNote, sContent)
    if not canEdit(nodeNote) or type(sContent) ~= "string" then return false; end
    -- Autoría y orden no forman parte del contrato de actualización.
    DB.setValue(nodeNote, "content", "string", sContent);
    return true;
end

function deleteNote(nodeNote)
    if not canEdit(nodeNote) then return false; end
    DB.deleteNode(nodeNote);
    return true;
end

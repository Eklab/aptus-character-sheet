local tPaths = {};
function onInit()
    local node = getDatabaseNode();
    if not node then return; end
    for _, sField in ipairs({ "content", "author_label", "author_kind" }) do
        local sPath = DB.getPath(node, sField);
        table.insert(tPaths, sPath);
        DB.addHandler(sPath, "onUpdate", refresh);
        DB.addHandler(sPath, "onDelete", refresh);
    end
    refresh();
end
function onClose()
    for _, sPath in ipairs(tPaths) do
        DB.removeHandler(sPath, "onUpdate", refresh);
        DB.removeHandler(sPath, "onDelete", refresh);
    end
end
function refresh()
    local node = getDatabaseNode();
    if not node then return; end
    author.setValue(DB.getValue(node, "author_label", ""));
    content_display.setValue(DB.getValue(node, "content", ""));
    local bEdit = APTUSStructureNotesManager.canEdit(node);
    edit_note.setVisible(bEdit);
    idelete.setVisible(bEdit);
end
function editNote()
    local node = getDatabaseNode();
    if not APTUSStructureNotesManager.canEdit(node) then return; end
    Interface.openWindow("aptus_structure_note_editor", node);
end
-- Llamado por button_idelete después de la confirmación nativa de dos pasos.
function delete()
    APTUSStructureNotesManager.deleteNote(getDatabaseNode());
end

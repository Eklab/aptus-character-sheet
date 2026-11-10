local bCreating;
local sTargetPath;
function onInit()
    local node = getDatabaseNode();
    bCreating = APTUSStructureManager.isStructure(node);
    local bAllowed = bCreating and APTUSStructureNotesManager.canCreate(node)
        or (not bCreating and APTUSStructureNotesManager.canEdit(node));
    if not bAllowed then close(); return; end
    sTargetPath = DB.getPath(node);
    author.setValue(bCreating and "DJ" or DB.getValue(node, "author_label", ""));
    draft.setValue(bCreating and "" or DB.getValue(node, "content", ""));
    draft.setFocus();
end
function saveNote()
    local node = sTargetPath and DB.findNode(sTargetPath);
    local bSaved;
    if bCreating then
        bSaved = APTUSStructureNotesManager.createNote(node, draft.getValue()) ~= nil;
    else
        bSaved = APTUSStructureNotesManager.updateContent(node, draft.getValue());
    end
    if bSaved then close(); else status.setValue(Interface.getString("aptus_structure_note_save_failed")); end
end

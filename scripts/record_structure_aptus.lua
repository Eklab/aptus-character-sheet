local sTypePath;
function onInit()
    if feature_list and not Session.IsHost then close(); return; end
    sTypePath = DB.getPath(getDatabaseNode(), "type");
    DB.addHandler(sTypePath, "onUpdate", update);
    DB.addHandler(sTypePath, "onDelete", update);
    update();
end
function onClose()
    if sTypePath then
        DB.removeHandler(sTypePath, "onUpdate", update);
        DB.removeHandler(sTypePath, "onDelete", update);
    end
end
function update()
    local node = getDatabaseNode();
    type_display.setValue(APTUSStructureManager.getTypeName(node));
    local bReadOnly = not APTUSStructureManager.canEdit(node);
    if description then description.setReadOnly(bReadOnly); end
    if picture then picture.setReadOnly(bReadOnly); end
    if picture_idelete then picture_idelete.setVisible(not bReadOnly); end
    if add_note then
        add_note.setVisible(APTUSStructureNotesManager.canCreate(node));
        notes_permission_hint.setVisible(not Session.IsHost);
    end
    if feature_list and Session.IsHost then
        for _, w in ipairs(feature_list.getWindows()) do w.close(); end
        for _, tFeature in ipairs(APTUSStructureManager.getFeatures()) do
            local w = feature_list.createWindow();
            w.setFeature(tFeature.id, node);
        end
    end
end

function addNote()
    local node = getDatabaseNode();
    if not APTUSStructureNotesManager.canCreate(node) then return; end
    Interface.openWindow("aptus_structure_note_editor", node);
end

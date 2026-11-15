local expected, types;
function onInit()
    local draft = APTUSQualityManager.getDraft(getDatabaseNode());
    expected, types = APTUSQualityManager.token(getDatabaseNode()), draft.types;
    identity.setValue(DB.getValue(getDatabaseNode(), "quality_id", ""));
    draft_name.setValue(draft.name); draft_description.setValue(draft.description);
    for i, t in ipairs(APTUSQualityManager.getTypes()) do
        local list = i <= 3 and type_list or type_list_right;
        local w = list.createWindow(); w.configure(t, types);
    end
    update();
end
function update()
    local editable = APTUSQualityManager.canEdit(getDatabaseNode());
    draft_name.setReadOnly(not editable); draft_description.setReadOnly(not editable);
    save_button.setVisible(editable); delete_button.setVisible(editable);
    save_art.setVisible(editable); delete_art.setVisible(editable);
    for _, list in ipairs({ type_list, type_list_right }) do
        for _, w in ipairs(list.getWindows()) do w.enabled.setReadOnly(not editable); end
    end
end
function save()
    local ok, message = APTUSQualityManager.save(getDatabaseNode(), {
        name = draft_name.getValue(), description = draft_description.getValue(), types = types,
    }, expected);
    if not ok then ChatManager.SystemMessage(message); return; end
    expected = APTUSQualityManager.token(getDatabaseNode());
    local parent = WindowManager.getTopWindow(self);
    if parent.onNameUpdated then parent.onNameUpdated(); end
    status.setValue("Cualidad guardada.");
end
function deleteDefinition() APTUSQualityManager.requestDelete(getDatabaseNode()); end

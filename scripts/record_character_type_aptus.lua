function onInit()
    APTUSCharacterTypes.ensureRecordId(getDatabaseNode());
    update();
end

function update()
    local bReadOnly = not Session.IsHost or WindowManager.getWindowReadOnlyState(self);
    description.setReadOnly(bReadOnly);
    id.setReadOnly(true);
end

function onInit()
    APTUSDedication.ensureRecordId(getDatabaseNode());
    update();
end

function update()
    local bReadOnly = not Session.IsHost or WindowManager.getWindowReadOnlyState(self);
    description.setReadOnly(bReadOnly);
    special.setReadOnly(bReadOnly);
    picture.setReadOnly(bReadOnly);
    id.setReadOnly(true);
end

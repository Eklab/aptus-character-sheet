function onInit()
    APTUSSkin.subscribe(self, updateSkin);
    update();
end

function onClose()
    APTUSSkin.unsubscribe(self, updateSkin);
end

function updateSkin()
    local sIcon = APTUSSkin.getIcon(self, "aptus_location_section");
    location_heading.setIcon(sIcon);
    description_heading.setIcon(sIcon);
end

function update()
    local bReadOnly = not APTUSStructureManager.canEdit(getDatabaseNode());
    location.setReadOnly(bReadOnly);
    description.setReadOnly(bReadOnly);
end

function onLockModeChanged()
    update();
end

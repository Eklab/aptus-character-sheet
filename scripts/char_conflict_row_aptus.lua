function onInit()
    onEditModeChanged();
end

function onEditModeChanged()
    local bReadOnly = WindowManager.getWindowReadOnlyState(self);
    title.setReadOnly(bReadOnly);
    description.setReadOnly(bReadOnly);
    idelete.setVisible(not bReadOnly and WindowManager.getEditMode(self, "conflicts_iedit"));
end

-- El botón nativo conserva su confirmación de dos pasos antes de llamar aquí.
function delete()
    if WindowManager.getWindowReadOnlyState(self) then return; end
    if not WindowManager.getEditMode(self, "conflicts_iedit") then return; end
    DB.deleteNode(getDatabaseNode());
end

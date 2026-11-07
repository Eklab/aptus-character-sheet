function onInit()
    onLockModeChanged(WindowManager.getWindowReadOnlyState(self));
end

function onLockModeChanged(bReadOnly)
    add_conflict.setVisible(not bReadOnly);
    conflicts_iedit.setVisible(not bReadOnly);
    if bReadOnly then conflicts_iedit.setValue(0); end
    WindowManager.onEditModeChanged(conflicts);
end

function addConflict()
    local nodeRow = APTUSConflicts.addConflict(getDatabaseNode());
    if not nodeRow then return; end
    conflicts.applySort(true);
    for _, wRow in ipairs(conflicts.getWindows()) do
        if wRow.getDatabasePath() == DB.getPath(nodeRow) then
            conflicts.scrollToWindow(wRow);
            wRow.title.setFocus();
            break;
        end
    end
end

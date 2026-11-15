-- Ventana de instancia: sin menús de alta/copia ni edición de catálogo.
-- onDelete cierra también las fichas abiertas de descendientes eliminados.
local sItemPath, sCharacterPath;
local bInstanceLocked = true;
function isInstanceLocked() return bInstanceLocked; end
function onInstanceLockChanged(locked)
    local node = getDatabaseNode();
    if not APTUSInventoryManager.canManageCharacter(APTUSInventoryManager.getInstanceCharacter(node)) or DB.isReadOnly(node) then
        local button = menubar and menubar.subwindow and menubar.subwindow.locked;
        if button then button.setLocked(bInstanceLocked); end
        return;
    end
    bInstanceLocked = locked;
    -- Sólo un gesto manual actualiza el metadato usado por el gestor existente.
    local value = locked and 1 or 0;
    if DB.getValue(node, "locked", 0) ~= value then DB.setValue(node, "locked", "number", value); end
    onPermissionsChanged();
end
function onPersistedLockChanged()
    bInstanceLocked = DB.getValue(getDatabaseNode(), "locked", 0) ~= 0;
    local button = menubar and menubar.subwindow and menubar.subwindow.locked;
    if button then button.setLocked(bInstanceLocked); end
    onPermissionsChanged();
end
function onInit()
    local node = getDatabaseNode();
    if not APTUSInventoryManager.canViewInstance(node) then close(); return; end
    sItemPath = DB.getPath(node);
    local character = APTUSInventoryManager.getInstanceCharacter(node);
    sCharacterPath = DB.getPath(character);
    DB.addHandler(sItemPath, "onDelete", onItemDeleted);
    DB.addHandler(sItemPath .. ".locked", "onAdd", onPersistedLockChanged);
    DB.addHandler(sItemPath .. ".locked", "onUpdate", onPersistedLockChanged);
    DB.addHandler(sItemPath .. ".locked", "onDelete", onPersistedLockChanged);
    DB.addHandler(sCharacterPath, "onObserverUpdate", onPermissionsChanged);
    DB.addHandler(sCharacterPath .. ".inventorylist", "onChildUpdate", onInventoryChanged);
    for _, field in ipairs({"properties.hide_contents", "properties.is_container", "aptus.container"}) do
        for _, event in ipairs({"onAdd", "onUpdate", "onDelete"}) do
            DB.addHandler(sCharacterPath .. ".inventorylist.*." .. field, event, onInventoryChanged);
        end
    end
    content.setValue("aptus_inventory_item_main", sItemPath);
    super.onInit();
    onPermissionsChanged();
end
function onClose()
    if sItemPath then
        DB.removeHandler(sItemPath, "onDelete", onItemDeleted);
        for _, event in ipairs({ "onAdd", "onUpdate", "onDelete" }) do
            DB.removeHandler(sItemPath .. ".locked", event, onPersistedLockChanged);
        end
    end
    if sCharacterPath then
        for _, field in ipairs({"properties.hide_contents", "properties.is_container", "aptus.container"}) do
            for _, event in ipairs({"onAdd", "onUpdate", "onDelete"}) do
                DB.removeHandler(sCharacterPath .. ".inventorylist.*." .. field, event, onInventoryChanged);
            end
        end
        DB.removeHandler(sCharacterPath, "onObserverUpdate", onPermissionsChanged);
        DB.removeHandler(sCharacterPath .. ".inventorylist", "onChildUpdate", onInventoryChanged);
    end
end
function onItemDeleted() close(); end
function onInventoryChanged()
    if not APTUSInventoryManager.canViewInstance(getDatabaseNode()) then close(); return; end
    if content and content.subwindow then content.subwindow.onPersistentDataChanged(); end
end
function onPermissionsChanged()
    local lock = menubar and menubar.subwindow and menubar.subwindow.locked;
    if lock then
        lock.setReadOnly(not APTUSInventoryManager.canManageCharacter(APTUSInventoryManager.getInstanceCharacter(getDatabaseNode()))
            or DB.isReadOnly(getDatabaseNode()));
    end
    if content and content.subwindow then content.subwindow.update(); end
end

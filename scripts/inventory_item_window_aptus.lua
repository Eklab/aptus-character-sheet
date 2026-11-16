-- Ventana de instancia: sin menús de alta/copia ni edición de catálogo.
-- onDelete cierra también las fichas abiertas de descendientes eliminados.
local sItemPath, sCharacterPath;
local bInstanceLocked = true;
local bStructureOwner = false;
local inspectionSource;
local initialized = false;
local permissionContext;
local windowClosed = false;
function isContextWindow() return getClass() == "aptus_inventory_item_consult"; end
function getActionContext() return permissionContext; end
function isInspectionOnly()
    return isContextWindow() and (windowClosed or not permissionContext
        or not APTUSInventoryManager.canManageInstance(getDatabaseNode(), permissionContext));
end
function canWriteInWindow()
    return not windowClosed and not isInspectionOnly() and APTUSInventoryManager.isContextValid(permissionContext)
        and canViewInWindow();
end
function canViewInWindow()
    if windowClosed then return false; end
    if isContextWindow() then
        if windowClosed or not inspectionSource then return false; end
        if permissionContext then
            return APTUSInventoryManager.isContextValid(permissionContext)
                and inspectionSource.canInspectItem(DB.getPath(getDatabaseNode()), permissionContext);
        end
        return inspectionSource.canInspectStructureItem(DB.getPath(getDatabaseNode()));
    end
    return APTUSInventoryManager.canViewInstance(getDatabaseNode());
end
function configureInspection(source, context)
    if not isContextWindow() or initialized then return; end
    inspectionSource, permissionContext = source, context;
    if not canViewInWindow() then close(); return; end
    onInit();
end
function isInstanceLocked() return isInspectionOnly() or bInstanceLocked; end
function onInstanceLockChanged(locked)
    if not canWriteInWindow() then
        local button = menubar and menubar.subwindow and menubar.subwindow.locked;
        if button then button.setLocked(true); end
        return;
    end
    local node = getDatabaseNode();
    if not APTUSInventoryManager.canManageCharacter(APTUSInventoryManager.getInstanceCharacter(node), permissionContext) or DB.isReadOnly(node) then
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
    if windowClosed then return; end
    if isInspectionOnly() then onPermissionsChanged(); return; end
    bInstanceLocked = DB.getValue(getDatabaseNode(), "locked", 0) ~= 0;
    local button = menubar and menubar.subwindow and menubar.subwindow.locked;
    if button then button.setLocked(bInstanceLocked); end
    onPermissionsChanged();
end
function onInit()
    if initialized or (isContextWindow() and not inspectionSource) then return; end
    local node = getDatabaseNode();
    if not canViewInWindow() then close(); return; end
    initialized = true;
    sItemPath = DB.getPath(node);
    local character = APTUSInventoryManager.getInstanceCharacter(node);
    sCharacterPath = DB.getPath(character);
    bStructureOwner = APTUSInventoryManager.isStructureInventory(character);
    if bStructureOwner then
        APTUSLocationPermissions.subscribe(onPermissionsChanged);
        for _, event in ipairs({"onAdd", "onUpdate", "onDelete"}) do
            DB.addHandler(sCharacterPath .. ".features.storage.enabled", event, onInventoryChanged);
        end
    end
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
    windowClosed = true;
    if inspectionSource then inspectionSource.forgetInspection(DB.getPath(getDatabaseNode()), self);inspectionSource = nil; end
    if bStructureOwner then
        APTUSLocationPermissions.unsubscribe(onPermissionsChanged);
        for _, event in ipairs({"onAdd", "onUpdate", "onDelete"}) do
            DB.removeHandler(sCharacterPath .. ".features.storage.enabled", event, onInventoryChanged);
        end
    end    if sItemPath then
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
    if windowClosed then return; end
    if isContextWindow() then
        if not canViewInWindow() then close(); return; end
    end
    if not APTUSInventoryManager.canViewInstance(getDatabaseNode()) then close(); return; end
    if content and content.subwindow then
        if isInspectionOnly() then content.subwindow.reload();
        else content.subwindow.onPersistentDataChanged(); end
    end
end
function onPermissionsChanged()
    if windowClosed then return; end
    if isInspectionOnly() then
        if not canViewInWindow() then close(); return; end
    end
    if not APTUSInventoryManager.canViewInstance(getDatabaseNode()) then close(); return; end
    local lock = menubar and menubar.subwindow and menubar.subwindow.locked;
    if lock then
        lock.setReadOnly(isInspectionOnly() or not APTUSInventoryManager.canManageCharacter(APTUSInventoryManager.getInstanceCharacter(getDatabaseNode()), permissionContext)
            or DB.isReadOnly(getDatabaseNode()));
        if isInspectionOnly() then lock.setLocked(true); end
    end
    if content and content.subwindow then content.subwindow.update(); end
end

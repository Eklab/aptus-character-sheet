-- Configuración existente compartida. Almacenaje usa la casilla de General.
local sSelectedTab = "general";
local sStoragePath;
function onInit()
    if not Session.IsHost then close(); return; end
    general_page.setValue("aptus_location_configuration_general", getDatabasePath());
    permissions_page.setValue("aptus_location_configuration_permissions", getDatabasePath());
    sStoragePath = DB.getPath(getDatabaseNode(), "features.storage.enabled");
    for _, event in ipairs({"onAdd", "onUpdate", "onDelete"}) do DB.addHandler(sStoragePath, event, refreshStorageTab); end
    selectTab("general");
end
function onClose()
    if sStoragePath then
        for _, event in ipairs({"onAdd", "onUpdate", "onDelete"}) do DB.removeHandler(sStoragePath, event, refreshStorageTab); end
    end
end
function selectTab(name)
    if name ~= "general" and name ~= "permissions" and name ~= "storage" then return; end
    local enabled = APTUSStructureManager.isFeatureActive(getDatabaseNode(), "storage");
    if name == "storage" and not enabled then name = "general"; end
    sSelectedTab = name;
    tab_storage.setReadOnly(not enabled);
    if name == "storage" and not storage_page.subwindow then
        storage_page.setValue("aptus_structure_inventory", getDatabasePath());
    end
    for _, key in ipairs({"general", "permissions", "storage"}) do
        self[key .. "_page"].setVisible(name == key);
        self["active_" .. key].setVisible(name == key);
        self["tab_" .. key].setColor(name == key and "FF000000" or "FF666666");
    end
end
function refreshStorageTab() selectTab(sSelectedTab); end
function update()
    if general_page.subwindow then general_page.subwindow.update(); end
    if permissions_page.subwindow then permissions_page.subwindow.update(); end
    if storage_page.subwindow then storage_page.subwindow.update(); end
    selectTab(sSelectedTab);
end

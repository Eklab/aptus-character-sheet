-- Conserva ambas fichas narrativas y el mismo registro; amplía sus pestañas.
local sStoragePath;
local subscribed = false;
function onInit()
    if APTUSStructureManager.getCategory(getDatabaseNode()) == "locations" then
        local w = Interface.openWindow("aptus_location", getDatabaseNode());
        if w then close(); return; end
    end
    super.onInit();
    sStoragePath = DB.getPath(getDatabaseNode(), "features.storage.enabled");
    for _, event in ipairs({"onAdd", "onUpdate", "onDelete"}) do DB.addHandler(sStoragePath, event, refreshStorageTabs); end
    APTUSLocationPermissions.subscribe(refreshStorageTabs);
    subscribed = true;
end
function getTabsData()
    local data = {{sName="main", sClass="aptus_structure_main", sTextRes="aptus_structure_tab_main", bActivate=true, bScroll=true}};
    if Session.IsHost then table.insert(data,{sName="configuration",sClass="aptus_location_configuration_content",sText="Configuración",bScroll=true}); end
    if APTUSStructureManager.canAccessResources(getDatabaseNode()) then
        table.insert(data,{sName="storage",sClass="aptus_structure_inventory",sText="Almacenaje",bScroll=false});
    end
    return data;
end
function refreshStorageTabs()
    if not tabs then return; end
    local allowed = APTUSStructureManager.canAccessResources(getDatabaseNode());
    local exists = tabs.getTabIndexByName("storage") > 0;
    if allowed ~= exists then
        if not allowed and tabs.getActiveTabName() == "storage" then tabs.activateTabByName("main"); end
        WindowTabManager.populateTabs(self);
    end
end
function onClose()
    if subscribed then APTUSLocationPermissions.unsubscribe(refreshStorageTabs); end
    if sStoragePath then
        for _, event in ipairs({"onAdd", "onUpdate", "onDelete"}) do DB.removeHandler(sStoragePath, event, refreshStorageTabs); end
    end
end

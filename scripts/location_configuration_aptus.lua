-- Navegación de presentación: no persiste la selección ni modifica permisos.
local sSelectedTab = "general";

function onInit()
    if not Session.IsHost then close(); return; end
    general_page.setValue("aptus_location_configuration_general", getDatabasePath());
    permissions_page.setValue("aptus_location_configuration_permissions", getDatabasePath());
    selectTab("general");
end

function selectTab(sName)
    if sName ~= "general" and sName ~= "permissions" then return; end
    sSelectedTab = sName;
    local bGeneral = sName == "general";
    general_page.setVisible(bGeneral);
    permissions_page.setVisible(not bGeneral);
    active_general.setVisible(bGeneral);
    active_permissions.setVisible(not bGeneral);
    tab_general.setColor(bGeneral and "FF000000" or "FF666666");
    tab_permissions.setColor(bGeneral and "FF666666" or "FF000000");
end

function update()
    if general_page.subwindow then general_page.subwindow.update(); end
    if permissions_page.subwindow then permissions_page.subwindow.update(); end
    selectTab(sSelectedTab);
end

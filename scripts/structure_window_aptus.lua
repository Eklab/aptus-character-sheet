-- Puente de presentación: conserva los enlaces aptus_structure ya guardados.
-- Vehículos y tipos desconocidos ejecutan exactamente la ventana anterior.
function onInit()
    if APTUSStructureManager.getCategory(getDatabaseNode()) == "locations" then
        local w = Interface.openWindow("aptus_location", getDatabaseNode());
        if w then close(); return; end
    end
    super.onInit();
end

-- CTA local de la cabecera del personaje, sin escritura de datos.
function onInit() updateViewerUI(); end
function updateViewerUI()
    local top = WindowManager.getTopWindow(window);
    local owner = DB.getOwner(top.getDatabaseNode()) or "";
    local available = Session.IsHost and owner ~= "" and owner ~= Session.UserName;
    setVisible(available);
    setReadOnly(not available);
    setTooltipText("Impersonar jugador (" .. owner .. ")");
    local viewer = top.getStructureViewer and top.getStructureViewer();
    local icon = viewer and viewer.mode == "player_preview" and "aptus_impersonar_on" or "aptus_impersonar_off";
    setIcons(icon, icon);
end
function onButtonPress()
    local top = WindowManager.getTopWindow(window);
    if top.toggleStructureViewer then top.toggleStructureViewer(); end
end

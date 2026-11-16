local previewPlayer = false;
local viewerPath;
local inventoryContextRevision = 0;
local contextClosed = false;
local contextInvalidators = {};
local function invalidateInventoryContext()
    inventoryContextRevision = inventoryContextRevision + 1;
    local callbacks = contextInvalidators;contextInvalidators = {};
    for _, callback in ipairs(callbacks) do pcall(callback); end
end
-- CoreRPG conserva la creación de subventanas y el estado de las pestañas.
function onInit()
    viewerPath = DB.getPath(getDatabaseNode());
    DB.addHandler(viewerPath, "onObserverUpdate", refreshStructureViewer);
    -- Migración diferida de fichas antiguas; sólo escribe con permisos.
    APTUSCharacterManager.ensureDefaultName(getDatabaseNode());
    WindowTabManager.setTabTemplate("charsheet", "aptus_tabs_hidden");
    local tTabs = WindowTabManager.getTabsFromWindow(self);
    local bIdentity, bPrincipal = false, false;
    for _, tTab in ipairs(tTabs) do
        tTab.bActivate = false;
        if tTab.sName == "main" then
            tTab.bScroll = true;
        elseif tTab.sName == "inventory" then
            tTab.sClass = "aptus_char_equipment";
            tTab.bScroll = false;
        elseif tTab.sName == "notes" then
            -- Identidad conserva el nombre de pestaña usado por la navegación.
            tTab.sClass = "aptus_char_identity";
            tTab.bScroll = false;
        elseif tTab.sName == "aptus_identity" then
            bIdentity = true;
        elseif tTab.sName == "aptus_principal" then
            tTab.bActivate = true;
            bPrincipal = true;
        end
    end
    if not bIdentity then
        table.insert(tTabs, {
            sName = "aptus_identity", sClass = "charsheet_overview",
            sText = "Portrait y tokens", bScroll = true,
        });
    end
    if not bPrincipal then
        table.insert(tTabs, 1, {
            sName = "aptus_principal", sClass = "aptus_char_principal",
            sText = "Principal", bActivate = true,
        });
    end
    -- Vinculación explícita, igual que WindowTabManager.updateTabDisplay.
    overview.setValue("aptus_char_header", getDatabasePath());
    super.onInit();
    refreshStructureViewer();

    registerMenuItem("Opciones de ficha", "button_toolbar_link", 8);
    registerMenuItem("Enlace arrastrable del personaje", "button_toolbar_link", 8, 1);
    if Session.IsHost then
        registerMenuItem("Hablar como personaje", "button_toolbar_speak", 8, 2);
    end
    registerMenuItem("Localizar token en el mapa", "button_toolbar_ping", 8, 3);
    registerMenuItem("Portrait y tokens", "button_toolbar_link", 8, 4);
    registerMenuItem("Ventana", "button_toolbar_window_minimize", 8, 5);
    registerMenuItem("Minimizar ficha", "button_toolbar_window_minimize", 8, 5, 1);
    registerMenuItem("Ayuda de CoreRPG", "button_toolbar_help", 8, 5, 2);
    registerMenuItem("Cerrar ficha", "button_toolbar_window_close", 8, 5, 3);
    if ToolbarManager.getButton("charsheet_size") then
        registerMenuItem("Ficha reducida", "button_toolbar_size_down", 8, 5, 4);
    end
    if RecordDataManager.getExportMode("charsheet") then
        registerMenuItem("Exportar personaje", "button_toolbar_export", 8, 8);
    end
end

-- Se ejecuta antes de setValue/activación, también tras recreaciones nativas.
-- Los cuatro bordes son absolutos e independientes del flujo de CoreRPG.
function prepareTabViewport(tTab)
    local c = WindowTabManager.getTabDisplay(self, tTab, true);
    if not c then return; end
    c.setAnchor("top", "", "top", "absolute", 278);
    c.setAnchor("bottom", "", "bottom", "absolute", 0);
    c.setAnchor("left", "", "left", "absolute", 0);
    -- Identidad no necesita barra exterior: su fondo ocupa el ancho completo.
    local nRightOffset = (tTab.sName == "notes" or tTab.sName == "aptus_principal" or tTab.sName == "inventory") and 0 or -20;
    c.setAnchor("right", "", "right", "absolute", nRightOffset);
    local cScroll = WindowTabManager.getTabScrollbar(self, tTab);
    if cScroll then
        cScroll.setAnchor("top", "", "top", "absolute", 278);
        cScroll.setAnchor("bottom", "", "bottom", "absolute", 0);
    end
end

function activateSection(sName)
    if tabs.getTabIndexByName(sName) > 0 then
        tabs.activateTabByName(sName);
    end
end

function onMenuSelection(selection, subselection, subsubselection)
    if selection ~= 8 then
        if super and super.onMenuSelection then
            super.onMenuSelection(selection, subselection, subsubselection);
        end
        return;
    end
    -- Estos manejadores nativos sólo necesitan el campo window del control.
    local tContext = { window = self };
    if subselection == 1 then
        Interface.openWindow("aptus_char_options", getDatabaseNode());
    elseif subselection == 2 and Session.IsHost then
        WindowMenuManager.performMenuChatSpeak(tContext);
    elseif subselection == 3 then
        WindowMenuManager.performMenuTokenFind(tContext);
    elseif subselection == 4 then
        activateSection("aptus_identity");
    elseif subselection == 5 then
        if subsubselection == 1 then
            WindowMenuManager.performMenuMinimize(tContext);
        elseif subsubselection == 2 then
            WindowMenuManager.performMenuHelp(tContext);
        elseif subsubselection == 3 then
            WindowMenuManager.performMenuClose(tContext);
        elseif subsubselection == 4 and ToolbarManager.getButton("charsheet_size") then
            WindowMenuManager.onCharSizeButtonPressed(tContext);
        end
    elseif subselection == 8 and RecordDataManager.getExportMode("charsheet") then
        WindowMenuManager.performMenuExport(tContext);
    end
end

-- La vista heredada conserva Portrait/tokens, pero ya no es un editor de nombre.
function onTabChanged()
    -- La subventana de Identidad se reutiliza al cambiar de pestaña.
    -- Limpia también su estado al salir, sin depender del orden de dibujo.
    local cIdentity = WindowTabManager.getTabDisplay(self, { sName = "notes" });
    if cIdentity and cIdentity.subwindow and cIdentity.subwindow.onSectionVisibilityChanged then
        cIdentity.subwindow.onSectionVisibilityChanged(tabs.getActiveTabName() == "notes");
    end
    if navigation and navigation.subwindow then
        navigation.subwindow.updateActiveTab(tabs.getActiveTabName());
    end
    -- Las barras creadas por el gestor pertenecen sólo a su pestaña activa.
    for _, tTab in ipairs(WindowTabManager.getTabsData(self)) do
        local c = WindowTabManager.getTabDisplay(self, tTab);
        local cScroll = WindowTabManager.getTabScrollbar(self, tTab);
        if cScroll then
            cScroll.setVisible(c and c.isVisible() or false);
        end
    end
    if super and super.onTabChanged then
        super.onTabChanged();
    end
    if aptus_identity and aptus_identity.subwindow and aptus_identity.subwindow.name then
        aptus_identity.subwindow.name.setReadOnly(true);
    end
end

-- Contexto efímero y exclusivo de esta ventana; nunca altera Session ni ownership.
function getStructureViewer()
    if not Session.IsHost then return {mode="player",username=Session.UserName}; end
    local owner = DB.getOwner(getDatabaseNode()) or "";
    if owner == "" or owner == Session.UserName then previewPlayer = false; end
    if previewPlayer then return {mode="player_preview",username=owner}; end
    return {mode="host",username=Session.UserName};
end
function toggleStructureViewer()
    local owner = DB.getOwner(getDatabaseNode()) or "";
    if not Session.IsHost or owner == "" or owner == Session.UserName then return; end
    previewPlayer = not previewPlayer;
    refreshStructureViewer();
end
-- Captura de permisos local. La revisión invalida diálogos incluso al alternar
-- Impersonar dos veces y volver al mismo usuario; nunca se modifica Session.
function getInventoryContext()
    local viewer = getStructureViewer();
    local node, revision = getDatabaseNode(), inventoryContextRevision;
    local realHost = Session.IsHost;
    local owner = realHost and (DB.getOwner(node) or "") or nil;
    local owned = not realHost and DB.isOwner(node);
    local path = DB.getPath(node);
    local real = Session.UserName;
    local mode = viewer.mode;
    local context = {
        aptus_inventory_context=true, actor_real=real, actor_effective=viewer.username,
        character_path=path, impersonating=mode == "player_preview",
        mode=mode, username=viewer.username,
        isValid=function()
            return not contextClosed and inventoryContextRevision == revision
                and DB.findNode(path) == node and Session.UserName == real and Session.IsHost == realHost
                and ((realHost and (DB.getOwner(node) or "") == owner) or (not realHost and DB.isOwner(node) == owned))
                and getStructureViewer().mode == mode;
        end,
    };
    context.onInvalidate = function(callback)
        if context.isValid() then table.insert(contextInvalidators, callback); else callback(); end
    end;
    return context;
end
function refreshStructureViewer()
    invalidateInventoryContext();
    getStructureViewer();
    if overview and overview.subwindow and overview.subwindow.aptus_impersonate_button then
        overview.subwindow.aptus_impersonate_button.updateViewerUI();
    end
    local equipment = WindowTabManager.getTabDisplay(self, {sName="inventory"});
    if equipment and equipment.subwindow and equipment.subwindow.onStructureViewerChanged then
        equipment.subwindow.onStructureViewerChanged();
    end
end
function onClose()
    contextClosed = true;
    invalidateInventoryContext();
    previewPlayer = false;
    if viewerPath then DB.removeHandler(viewerPath, "onObserverUpdate", refreshStructureViewer); end
    if super and super.onClose then super.onClose(); end
end

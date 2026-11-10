local sStoragePath;
local bUpdatingNavigation = false;

function onInit()
    WindowTabManager.setTabTemplate("aptus_location", "aptus_location_tabs_hidden");
    super.onInit();
    APTUSSkin.subscribe(self, updateSkin);
    DB.addHandler(getDatabaseNode(), "onObserverUpdate", updateShare);
    sStoragePath = DB.getPath(getDatabaseNode(), "features.storage.enabled");
    for _, sEvent in ipairs({ "onAdd", "onUpdate", "onDelete" }) do
        DB.addHandler(sStoragePath, sEvent, refreshNavigation);
    end
    APTUSLocationPermissions.subscribe(refreshNavigation);
    updateShare();
    update();
end

function onClose()
    APTUSLocationPermissions.unsubscribe(refreshNavigation);
    if sStoragePath then
        for _, sEvent in ipairs({ "onAdd", "onUpdate", "onDelete" }) do
            DB.removeHandler(sStoragePath, sEvent, refreshNavigation);
        end
    end
    DB.removeHandler(getDatabaseNode(), "onObserverUpdate", updateShare);
    APTUSSkin.unsubscribe(self, updateSkin);
end

function canShowStorage()
    local node = getDatabaseNode();
    return APTUSStructureManager.isFeatureActive(node, "storage")
        and (Session.IsHost or APTUSLocationPermissions.hasAccess(node, Session.UserName));
end

function getTabsData()
    local t = { { sName = "main", sClass = "aptus_location_main", bActivate = true, bScroll = true } };
    if canShowStorage() then
        table.insert(t, { sName = "storage", sClass = "aptus_location_storage", bScroll = true });
    end
    return t;
end

function onTabChanged()
    if not tabs then return; end
    local bStorage = tabs.getTabIndexByName("storage") > 0;
    local bActive = tabs.getActiveTabName() == "storage";
    navigation_storage.setVisible(bStorage);
    navigation_main.setAnchor("left", "", "left", "absolute", bStorage and 108 or 184);
    navigation_active.setAnchor("left", "", "left", "absolute", bStorage and (bActive and 280 or 128) or 204);
    navigation_main.setColor(bActive and "FFAAA090" or "FFE9D5AF");
    navigation_storage.setColor(bActive and "FFE9D5AF" or "FFAAA090");
end

function refreshNavigation()
    if bUpdatingNavigation or not tabs then return; end
    bUpdatingNavigation = true;
    local bAllowed = canShowStorage();
    local bExists = tabs.getTabIndexByName("storage") > 0;
    if bAllowed ~= bExists then
        -- Abandonar y destruir la vista revocada antes de reconstruir las entradas.
        if not bAllowed and tabs.getActiveTabName() == "storage" then tabs.activateTabByName("main"); end
        WindowTabManager.populateTabs(self);
    end
    onTabChanged();
    bUpdatingNavigation = false;
end

function populate()
    WindowTabManager.populate(self);
end

function updateSkin()
    picture_default.setIcon(APTUSSkin.getIcon(self, "aptus_location_default"));
    picture_gradient.setIcon(APTUSSkin.getIcon(self, "aptus_location_gradient"));
    parchment.setIcon(APTUSSkin.getIcon(self, "aptus_location_panel"));
end

function updatePictureFallback()
    picture_default.setVisible((picture.getValue() or "") == "");
end

-- Widget del propio CTA: escala el bitmap completo, sin alterar su interacción.
function setHeaderIcon(c, sIcon)
    local w = c.findWidget("aptus_cta_icon");
    if not w then
        w = c.addBitmapWidget({ name = "aptus_cta_icon", icon = sIcon, w = 27, h = 27 });
    else
        w.setBitmap(sIcon);
    end
    -- Sin clipanchor: setSize escala la imagen en lugar de recortarla.
    w.setSize(27, 27);
end

function updateHeaderIcons()
    setHeaderIcon(link, "aptus_location_link");
    setHeaderIcon(settings, "aptus_location_settings");
    setHeaderIcon(button_minimize, "aptus_location_minimize");
    setHeaderIcon(button_close, "aptus_location_close");
    -- La inicialización nativa asigna iconos al candado; se suprime sólo su dibujo.
    locked.setStateIcons(0, "", "", "");
    locked.setStateIcons(1, "", "", "");
    setHeaderIcon(locked, locked.getValue() == 0 and "aptus_location_unlocked" or "aptus_location_locked");
end

function updateShare()
    -- Reutiliza los tres estados y los tooltips nativos; sólo cambia su dibujo.
    WindowMenuManager.updateMenuShareDisplay(button_share);
    local nAccess = UtilityManager.getNodeAccessLevel(getDatabaseNode());
    local sIcon = nAccess == 0 and "aptus_location_share_off" or "aptus_location_share_on";
    button_share.setFrame(nil);
    button_share.setStateFrame("pressed", nil);
    -- Conserva tooltips nativos; el widget representa el acceso real a 27 × 27.
    button_share.setStateIcons(0, "", "", "");
    setHeaderIcon(button_share, sIcon);
    refreshNavigation();
end

function update()
    updateHeaderIcons();
    local node = getDatabaseNode();
    local bReadOnly = not APTUSStructureManager.canEdit(node);
    name.setReadOnly(bReadOnly);
    -- Refresca permisos y menú contextual mediante el manejador nativo de picture.
    picture.setLockMode();
    locked.setVisible(Session.IsHost and not DB.isReadOnly(node));
    button_share.setVisible(DB.isOwner(node) and RecordDataManager.getShareMode("aptus_structure"));
    settings.setVisible(Session.IsHost);
    updatePictureFallback();
    local c = self.main;
    if c and c.subwindow then c.subwindow.update(); end
    refreshNavigation();
end

function onLockModeChanged()
    update();
end

function openConfiguration()
    if not Session.IsHost then return; end
    Interface.openWindow("aptus_location_configuration", getDatabaseNode());
end

function prepareTabViewport(tTab)
    local c = WindowTabManager.getTabDisplay(self, tTab, true);
    c.setAnchor("left", "", "left", "absolute", 18);
    c.setAnchor("right", "", "right", "absolute", -30);
    c.setAnchor("top", "", "top", "absolute", 343);
    c.setAnchor("bottom", "", "bottom", "absolute", -18);
    local cScroll = WindowTabManager.getTabScrollbar(self, tTab);
    if cScroll then
        cScroll.setAnchor("top", "", "top", "absolute", 343);
        cScroll.setAnchor("bottom", "", "bottom", "absolute", -18);
    end
end

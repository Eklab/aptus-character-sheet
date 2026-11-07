-- Recursos y colocación encapsulados; no cambia el estado de las pestañas.
-- Cada imagen se dibuja a su tamaño original sobre el fondo de 653 x 50.
local tIndicators = {
    main = { icon = "aptus_navigation_active_main", x = 24, y = 9, w = 112, h = 36 },
    combat = { icon = "aptus_navigation_active_combat", x = 125, y = 9, w = 110, h = 35 },
    cualidades = { icon = "aptus_navigation_active_cualidades", x = 226, y = 9, w = 113, h = 34 },
    equipo = { icon = "aptus_navigation_active_equipo", x = 331, y = 9, w = 107, h = 34 },
    identificacion = { icon = "aptus_navigation_active_identificacion", x = 426, y = 9, w = 107, h = 34 },
    simbionte = { icon = "aptus_navigation_active_simbionte", x = 522, y = 9, w = 110, h = 34 },
};

-- Las vistas auxiliares mantienen el indicador de la sección que las contiene.
local tTabSections = {
    aptus_principal = "main",
    main = "main",
    abilities = "main",
    inventory = "equipo",
    notes = "identificacion",
    aptus_identity = "identificacion",
};

function onInit()
    APTUSSkin.subscribe(self, updateSkin);
end

function onClose()
    APTUSSkin.unsubscribe(self, updateSkin);
end

function updateSkin()
    local wChar = WindowManager.getTopWindow(self);
    if wChar.tabs then
        updateActiveTab(wChar.tabs.getActiveTabName());
    else
        updateActiveTab("aptus_principal");
    end
end

function updateActiveTab(sTabName)
    local sSection = tTabSections[sTabName];
    local tIndicator = tIndicators[sSection];
    for sKey in pairs(tIndicators) do
        local cLabel = self["navigation_label_" .. sKey];
        if cLabel then
            local sFont = (sKey == sSection) and "aptus_font_navigation_black" or "aptus_font_navigation_white";
            cLabel.setFont(sFont);
        end
    end
    -- Un único control sustituye el resaltado anterior; una pestaña desconocida
    -- no conserva por error el indicador de otra sección.
    navigation_active.setVisible(false);
    if not tIndicator then
        return;
    end
    navigation_active.setIcon(APTUSSkin.getIcon(self, tIndicator.icon));
    navigation_active.setAnchor("left", "", "left", "absolute", tIndicator.x);
    navigation_active.setAnchor("top", "", "top", "absolute", tIndicator.y);
    navigation_active.setAnchoredWidth(tIndicator.w);
    navigation_active.setAnchoredHeight(tIndicator.h);
    navigation_active.setVisible(true);
end

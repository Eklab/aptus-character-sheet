-- Coordenadas relativas al origen de Identidad (Y=278 en la ficha).
-- Controles de indicador de 117 x 36; PNG intactos, sin selección guardada en DB.
local tSections = {
    datos = { icon = "aptus_identidad_navigation_active_datos", x = 20, y = 37, w = 117, h = 36, class = "aptus_identity_datos" },
    historia = { background = "aptus_identidad_background_historia", icon = "aptus_identidad_navigation_active_historia", x = 20, y = 77, w = 118, h = 44, class = "aptus_identity_historia" },
    dedicacion = { background = "aptus_identidad_background_dedicacion", icon = "aptus_identidad_navigation_active_dedicacion", x = 20, y = 124, w = 118, h = 42, class = "aptus_identity_dedicacion" },
    conflictos = { background = "aptus_identidad_background_conflictos", icon = "aptus_identidad_navigation_active_conflictos", x = 20, y = 170, w = 118, h = 39, class = "aptus_identity_conflictos" },
};

local tCurrentSection;

function onInit()
    for sKey, tSection in pairs(tSections) do
        self["content_" .. sKey].setValue(tSection.class, getDatabasePath());
    end
    selectSection("datos");
    APTUSSkin.subscribe(self, updateSkin);
end

function onClose()
    APTUSSkin.unsubscribe(self, updateSkin);
end

function updateSkin()
    if tCurrentSection then updateIndicator(tCurrentSection); end
end

function selectSection(sKey)
    local tSection = tSections[sKey];
    if not tSection then return; end
    hideLegacyContent();
    for sName in pairs(tSections) do
        self["content_" .. sName].setVisible(sName == sKey);
        local sFont = (sName == sKey) and "aptus_font_navigation_black" or "aptus_font_navigation_white";
        self["label_" .. sName].setFont(sFont);
    end
    updateIndicator(tSection);
end

-- Recursos y colocación encapsulados para una futura selección de skin.
function updateIndicator(tSection)
    tCurrentSection = tSection;
    identity_background.setSkinResource(tSection.background or "aptus_identidad_background_default");
    identity_active.setVisible(false);
    identity_active.setIcon(APTUSSkin.getIcon(self, tSection.icon));
    identity_active.setAnchor("left", "", "left", "absolute", tSection.x);
    identity_active.setAnchor("top", "", "top", "absolute", tSection.y);
    identity_active.setAnchoredWidth(tSection.w);
    identity_active.setAnchoredHeight(tSection.h);
    identity_active.setVisible(true);
end

-- Conserva los contenedores sin activar ni cargar la clase nativa.
-- También oculta una instancia heredada que hubiera quedado abierta.
function hideLegacyContent()
    if legacy_content then legacy_content.setVisible(false); end
    if legacy_scrollbar then legacy_scrollbar.setVisible(false); end
end

function onSectionVisibilityChanged(bVisible)
    hideLegacyContent();
    if bVisible then
        selectSection("datos");
    else
        for sKey in pairs(tSections) do
            self["content_" .. sKey].setVisible(false);
        end
    end
end

-- Reutiliza el controlador original: no mantiene un segundo cálculo de atributos.
local tAttributes = { "fue", "agi", "con", "per", "int", "esp" };
local wLegacy;

function onInit()
    local wChar = WindowManager.getTopWindow(self);
    local nIndex = wChar.tabs.getTabIndexByName("main");
    local tTab = wChar.tabs.getTabData(nIndex);
    if not tTab then return; end
    -- CoreRPG carga las pestañas bajo demanda. Inicializar sin activarla conserva
    -- sus observadores de base/efectos incluso antes de visitar la vista antigua.
    wChar.prepareTabViewport(tTab);
    WindowTabManager.updateTabDisplay(wChar, tTab, true);
    local cLegacy = WindowTabManager.getTabDisplay(wChar, tTab);
    -- sub_content_hidden no tiene fastinit: setValue por sí solo no fuerza
    -- la carga. Activar el contenedor durante esta misma llamada inicializa
    -- el controlador original, sin seleccionar la pestaña antigua.
    WindowTabManager.setTabDisplayVisible(wChar, tTab, true);
    wLegacy = cLegacy and cLegacy.subwindow;
    WindowTabManager.setTabDisplayVisible(wChar, tTab, false);
    for _, sAttribute in ipairs(tAttributes) do
        local cRow = self["attribute_" .. sAttribute];
        cRow.setValue("aptus_principal_attribute_row",
            DB.getPath(getDatabaseNode(), "attributes." .. sAttribute));
        -- Vincular no activa la subventana. Cada fila debe quedar visible.
        cRow.setVisible(true);
    end
    skills_content.setValue("aptus_principal_skills", getDatabasePath());
    skills_content.setVisible(true);
end

function openAttributesEditor()
    if wLegacy then wLegacy.openAttributesEditor(); end
end

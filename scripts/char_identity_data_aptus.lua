-- Los campos usan directamente el nodo del personaje compartido por Identidad.
-- TEMPORAL DEPURACIÓN: retirar este selector al implementar el cambio definitivo.
local DEBUG_MODE_MENU = 5;
local tDebugModeValues = { "latente", "vinculado", "liberado", "avatar", "" };
function onInit()
    onLockModeChanged(WindowManager.getWindowReadOnlyState(self));
    -- Configuraciones siempre visibles; no aplica recursos al actor activo.
    portrait.setVisible(false);
    symbiote_appearances.setValue("aptus_symbiote_appearance_grid", getDatabasePath());
    symbiote_appearances.setVisible(true);
    registerDebugModeMenu();
end

function onLockModeChanged(bReadOnly)
    WindowManager.callSafeControlsSetLockMode(self,
        { "name", "age", "gender", "height", "weight", "appearance", "notes" }, bReadOnly);
end

-- Se registra en la ventana aptus_identity_datos, no en el control de un recurso.
function registerDebugModeMenu()
    if not Session.IsHost then return; end
    registerMenuItem("Depuración temporal: modo del simbionte", "tokenbag", DEBUG_MODE_MENU);
    registerMenuItem("Activar Latente", "tokenbag", DEBUG_MODE_MENU, 1);
    registerMenuItem("Activar Vinculado", "tokenbag", DEBUG_MODE_MENU, 2);
    registerMenuItem("Activar Liberado", "tokenbag", DEBUG_MODE_MENU, 3);
    registerMenuItem("Activar Avatar", "tokenbag", DEBUG_MODE_MENU, 4);
    registerMenuItem("Desactivar modo", "delete", DEBUG_MODE_MENU, 5);
    registerMenuItem("Prueba aislada: Portrait → Portrait (chat)", "arrowright", DEBUG_MODE_MENU, 6);
end

function onMenuSelection(selection, subselection, ...)
    if selection ~= DEBUG_MODE_MENU then
        if super and super.onMenuSelection then
            super.onMenuSelection(selection, subselection, ...);
        end
        return;
    end
    -- Comprobar también al ejecutar: los clientes no pueden utilizar el selector.
    if not Session.IsHost then return; end
    if subselection == 6 then
        APTUSAppearanceChatTest.send(getDatabaseNode());
        return;
    end
    local sMode = tDebugModeValues[subselection];
    local nodeChar = getDatabaseNode();
    if sMode == nil or not nodeChar then return; end
    -- Única escritura; los handlers globales detectarán el cambio de modo.
    DB.setValue(nodeChar, APTUSSymbioteAppearance.getActiveModePath(), "string", sMode);
end

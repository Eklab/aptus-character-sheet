-- Configuraciones por modo y sincronización de la representación nativa.
local sBase = "aptus.symbioteappearance";
local tModes = { "latente", "vinculado", "liberado", "avatar" };

function getModes()
    return tModes;
end

function getAssetPath(sMode, sKind)
    if not StringManager.contains(tModes, sMode) then return nil; end
    if sKind ~= "portrait" and sKind ~= "token" then return nil; end
    return sBase .. ".modes." .. sMode .. "." .. sKind;
end

function getActiveModePath()
    return sBase .. ".active_mode";
end

function getActiveMode(nodeChar)
    local sMode = DB.getValue(nodeChar, getActiveModePath(), "");
    if not StringManager.contains(tModes, sMode) then return ""; end
    return sMode;
end


-- Autoridad única en el director: los cambios recibidos de clientes pasan por DB.
-- Los handlers globales funcionan aunque no esté abierta la ficha.
local tHandlers = {};
local tLastActiveModes = {};

local function addHandler(sPath, fn, sEvent)
    sEvent = sEvent or "onUpdate";
    DB.addHandler(sPath, sEvent, fn);
    table.insert(tHandlers, { path = sPath, event = sEvent, callback = fn });
end

local function getCharacterFromField(nodeField)
    if not nodeField then return nil; end
    local sCharPath = DB.getPath(nodeField):match("^(charsheet%.[^.]+)");
    return sCharPath and DB.findNode(sCharPath) or nil;
end

function onTabletopInit()
    onClose();
    if not Session.IsHost then return; end
    -- Memoriza la campaña cargada antes de observar cambios: sin mensajes iniciales.
    for _, nodeChar in pairs(DB.getChildren("charsheet")) do
        tLastActiveModes[DB.getPath(nodeChar)] = getActiveMode(nodeChar);
    end
    addHandler("charsheet.*." .. getActiveModePath(), onActiveModeChanged);
    addHandler("charsheet.*." .. getActiveModePath(), onActiveModeDeleted, "onDelete");
    for _, sMode in ipairs(tModes) do
        for _, sKind in ipairs({ "portrait", "token" }) do
            local sModeName, sResourceKind = sMode, sKind;
            addHandler("charsheet.*." .. getAssetPath(sModeName, sResourceKind),
                function(nodeField)
                    onStoredResourceChanged(nodeField, sModeName, sResourceKind);
                end);
        end
    end
    -- Reapertura de campaña: sólo aplica modos válidos y recursos no vacíos.
    for _, nodeChar in pairs(DB.getChildren("charsheet")) do
        applyCurrentMode(nodeChar);
    end
end

function onClose()
    for _, tHandler in ipairs(tHandlers) do
        DB.removeHandler(tHandler.path, tHandler.event, tHandler.callback);
    end
    tHandlers = {};
    tLastActiveModes = {};
end

function onActiveModeChanged(nodeField)
    local nodeChar = getCharacterFromField(nodeField);
    applyCurrentMode(nodeChar);
    notifyActiveModeChanged(nodeChar);
end

function onActiveModeDeleted(nodeField)
    -- onDelete conserva el path del campo aunque el nodo ya no sea localizable.
    if not Session.IsHost or not nodeField then return; end
    local sCharPath = DB.getPath(nodeField):match("^(charsheet%.[^.]+)");
    if sCharPath then tLastActiveModes[sCharPath] = ""; end
end

function notifyActiveModeChanged(nodeChar)
    if not Session.IsHost or not nodeChar then return; end
    local sCharPath = DB.getPath(nodeChar);
    local sMode = getActiveMode(nodeChar);
    local sPrevious = tLastActiveModes[sCharPath] or "";
    -- Actualiza también para vacío/inválido: reactivar el mismo modo sí es un cambio.
    tLastActiveModes[sCharPath] = sMode;
    if sMode == "" or sMode == sPrevious then return; end
    ChatManager.sendMessage(string.format("%s ha cambiado a modo: %s",
        DB.getValue(nodeChar, "name", ""), string.upper(sMode)));
    -- Segundo mensaje, inmediatamente después del texto y desde el mismo host.
    sendPortraitTransition(nodeChar, sPrevious, sMode);
end

-- Composición nativa validada mediante la prueba aislada. No aplica apariencias.
function sendPortraitTransition(nodeChar, sPrevious, sMode)
    if not Session.IsHost or not nodeChar then return false; end
    local sBeforePath = getAssetPath(sPrevious, "portrait");
    local sAfterPath = getAssetPath(sMode, "portrait");
    if not sBeforePath or not sAfterPath then return false; end
    local sBefore = DB.getValue(nodeChar, sBeforePath, "");
    local sAfter = DB.getValue(nodeChar, sAfterPath, "");
    -- No sustituir imágenes ausentes por el Portrait nativo ni por otros modos.
    if sBefore == "" or sAfter == "" then return false; end
    Comm.deliverChatMessage({
        type = "aptus_symbiote_transition",
        font = "systemfont",
        sender = "",
        text = "",
        assets = {
            { name = sBefore, w = 48, h = 48 },
            { type = "icon", name = "arrowright", w = 16, h = 16 },
            { name = sAfter, w = 48, h = 48 },
        },
    });
    return true;
end

function onStoredResourceChanged(nodeField, sMode, sKind)
    local nodeChar = getCharacterFromField(nodeField);
    if not nodeChar or getActiveMode(nodeChar) ~= sMode then return; end
    applyStoredResource(nodeChar, sMode, sKind);
end

function applyCurrentMode(nodeChar)
    if not nodeChar then return; end
    local sMode = getActiveMode(nodeChar);
    if sMode == "" then return; end
    -- Si hay Token explícito, deja de depender del Portrait antes de cambiarlo.
    applyStoredResource(nodeChar, sMode, "token");
    applyStoredResource(nodeChar, sMode, "portrait");
end

function applyStoredResource(nodeChar, sMode, sKind)
    if not Session.IsHost or not nodeChar or WindowManager.getReadOnlyState(nodeChar) then return; end
    if getActiveMode(nodeChar) ~= sMode then return; end
    local sField = getAssetPath(sMode, sKind);
    if not sField then return; end
    local sAsset = DB.getValue(nodeChar, sField, "");
    -- Quitar un recurso almacenado no borra la representación nativa.
    if sAsset == "" or DB.getValue(nodeChar, sKind, "") == sAsset then return; end
    if sKind == "portrait" then
        return applyPortrait(nodeChar, sMode, sAsset);
    end
    DB.setValue(nodeChar, "token", "token", sAsset);
end

function applyPortrait(nodeChar, sMode, sAsset)
    -- No escribe token: conserva tanto referencias dinámicas portrait_<id>_token
    -- como Tokens independientes. CoreRPG gestiona sus imágenes derivadas.
    -- Mismo API usado por RecordAssetManager.setCharPortrait, sin su fallback
    -- que asigna token: Portrait y Token se escriben por separado.
    local bOK, sError = pcall(User.setPortrait, nodeChar, sAsset);
    if not bOK then
        Debug.console("[APTUS] Error al aplicar Portrait del modo " .. sMode, sError);
        return;
    end
    DB.setValue(nodeChar, "portrait", "token", sAsset);
end

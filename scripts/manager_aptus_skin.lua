-- Sólo presentación: referencias de catálogo -> ID estable -> recursos registrados.
-- La clave replicada evita compartir el catálogo privado para mostrar la SKIN.
local sVisualPath = "aptus.visual.skin";
local tTypeSkins = {
    libre = "default", investigador = "default", cazador = "cazador",
    agencia = "default", simbionte = "default",
};
local tSkinSuffixes = { default = "", cazador = "_cazador" };
local tSources = {};

local function getWindowNode(w)
    local wTop = WindowManager.getTopWindow(w);
    return wTop and wTop.getDatabaseNode();
end

local function getCharacterFromField(nodeField)
    if not nodeField then return nil; end
    local sPath = DB.getPath(nodeField):match("^(charsheet%.[^.]+)");
    return sPath and DB.findNode(sPath) or nil;
end

local function removeSource(sCharPath)
    local tSource = tSources[sCharPath];
    if not tSource then return; end
    DB.removeHandler(tSource.path, "onUpdate", tSource.update);
    DB.removeHandler(tSource.path, "onDelete", tSource.delete);
    tSources[sCharPath] = nil;
end

local function publishSkin(nodeChar, sSkin)
    if not Session.IsHost or not nodeChar or DB.isReadOnly(nodeChar) then return; end
    if DB.getValue(nodeChar, sVisualPath, "default") ~= sSkin then
        -- Dato visual derivado, nunca fuente de verdad del tipo ni de sus reglas.
        DB.setValue(nodeChar, sVisualPath, "string", sSkin);
    end
end

function onTabletopInit()
    if not Session.IsHost then return; end
    local sTypePath = "charsheet.*." .. APTUSCharacterTypes.getAssignmentPath();
    DB.addHandler(sTypePath, "onUpdate", onTypeChanged);
    DB.addHandler(sTypePath, "onDelete", onTypeDeleted);
    DB.addHandler("charsheet.*", "onDelete", onCharacterDeleted);
    for _, nodeChar in pairs(DB.getChildren("charsheet")) do
        updateCharacterSkin(nodeChar);
    end
end

function onClose()
    if not Session.IsHost then return; end
    local sTypePath = "charsheet.*." .. APTUSCharacterTypes.getAssignmentPath();
    DB.removeHandler(sTypePath, "onUpdate", onTypeChanged);
    DB.removeHandler(sTypePath, "onDelete", onTypeDeleted);
    DB.removeHandler("charsheet.*", "onDelete", onCharacterDeleted);
    local tPaths = {};
    for sPath in pairs(tSources) do table.insert(tPaths, sPath); end
    for _, sPath in ipairs(tPaths) do removeSource(sPath); end
end

function onTypeChanged(nodeField)
    updateCharacterSkin(getCharacterFromField(nodeField));
end

function onTypeDeleted(nodeField)
    local nodeChar = getCharacterFromField(nodeField);
    if not nodeChar then return; end
    removeSource(DB.getPath(nodeChar));
    publishSkin(nodeChar, "default");
end

function onCharacterDeleted(nodeChar)
    removeSource(DB.getPath(nodeChar));
end

function updateCharacterSkin(nodeChar)
    if not Session.IsHost or not nodeChar then return; end
    local sClass, sRecord = DB.getValue(nodeChar, APTUSCharacterTypes.getAssignmentPath(), "", "");
    local sIdPath;
    if sClass == "aptus_character_type" and (sRecord or "") ~= "" then
        sIdPath = DB.getPath(sRecord, "id");
    end
    local sCharPath = DB.getPath(nodeChar);
    local tSource = tSources[sCharPath];
    if tSource and tSource.path ~= sIdPath then
        removeSource(sCharPath);
        tSource = nil;
    end
    if sIdPath and not tSource then
        tSource = {
            path = sIdPath,
            update = function() updateCharacterSkin(nodeChar); end,
            delete = function() publishSkin(nodeChar, "default"); end,
        };
        tSources[sCharPath] = tSource;
        DB.addHandler(sIdPath, "onUpdate", tSource.update);
        DB.addHandler(sIdPath, "onDelete", tSource.delete);
    end
    local sId = sIdPath and DB.getValue(sIdPath, "") or "";
    local sSkin = tTypeSkins[sId] or "default";
    if tSkinSuffixes[sSkin] == nil then sSkin = "default"; end
    publishSkin(nodeChar, sSkin);
end

function getSkin(w)
    local nodeChar = getWindowNode(w);
    local sSkin = nodeChar and DB.getValue(nodeChar, sVisualPath, "default") or "default";
    return tSkinSuffixes[sSkin] ~= nil and sSkin or "default";
end

local function isUsableIcon(sIcon)
    if not Interface.isIcon(sIcon) then return false; end
    local nW, nH = Interface.getIconSize(sIcon);
    return (nW or 0) > 0 and (nH or 0) > 0;
end

function getIcon(w, sResource)
    local sIcon = sResource .. tSkinSuffixes[getSkin(w)];
    if isUsableIcon(sIcon) then return sIcon; end
    -- Fallback por recurso, sin cambiar los recursos globales de otras fichas.
    return isUsableIcon(sResource) and sResource or "";
end

function subscribe(w, fn)
    local nodeChar = getWindowNode(w);
    if nodeChar then
        local sPath = DB.getPath(nodeChar, sVisualPath);
        DB.addHandler(sPath, "onUpdate", fn);
        DB.addHandler(sPath, "onDelete", fn);
    end
    fn();
end

function unsubscribe(w, fn)
    local nodeChar = getWindowNode(w);
    if not nodeChar then return; end
    local sPath = DB.getPath(nodeChar, sVisualPath);
    DB.removeHandler(sPath, "onUpdate", fn);
    DB.removeHandler(sPath, "onDelete", fn);
end
